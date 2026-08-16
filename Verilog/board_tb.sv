`timescale 10ns / 10ps
import defines::*;
module board_tb;
    parameter int WIDTH = 8;
    parameter int NREG = 8;
    parameter int NRAM = 64;
    parameter int PCWIDTH = 8;
    parameter int DEBOUNCE_CYCLES = 1;
    parameter int TICK_FREQ = 25000000; //every 4 clocks so seven seg can keep up
    parameter int CLK_FREQ = 100000000;
    parameter int SEVEN_SEG_FREQ = 100000000;
    parameter int RESET_CYCLES = DEBOUNCE_CYCLES+2; // .1s at 100MHz
    parameter int MIN_DELAY = 4+DEBOUNCE_CYCLES*2; // 2 clock cycles for debouncing
    localparam int TIMEPERTICK = 2*CLK_FREQ/TICK_FREQ;
    int mode_arg;
    enable_mode_t test_mode;
    initial begin
        if (!$value$plusargs("MODE=%s", mode_arg))
            $display("**WARNING** - MODE argument not provided");
        test_mode = enable_mode_t'(mode_arg);

    end
    reg [$clog2(NRAM)-1:0] monitor_address;
    reg clk, reset_btn, step_btn;
    enable_mode_t enable_switches;
    display_mux_t display_mux;
    wire debugenable, debugreset, debugtick, debugstepbtn, debugstep, cpuhalted;
    wire [15:0] led_data;
    seven_segment_t active_segments;
    wire [3:0] active_seven_seg_digit;
    board #(
        .WIDTH(WIDTH),
        .NREG(NREG),
        .NRAM(NRAM),
        .PCWIDTH(PCWIDTH),
        .DEBOUNCE_CYCLES(DEBOUNCE_CYCLES),
        .TICK_FREQ(TICK_FREQ),
        .CLK_FREQ(CLK_FREQ),
        .SEVEN_SEG_FREQ(SEVEN_SEG_FREQ),
        .RESET_CYCLES(RESET_CYCLES)
    )
    basys3 (
        .clk(clk),
        .reset_btn(reset_btn),
        .step_btn(step_btn),
        .enable_switches(enable_switches),
        .display_mux(display_mux),
        .monitor_address(monitor_address),
        .debugenable(debugenable),
        .debugreset(debugreset),
        .debugtick(debugtick),
        .debugstep(debugstep),
        .debugstepbtn(debugstepbtn),
        .cpuhalted(cpuhalted),
        .active_seven_seg_digit(active_seven_seg_digit),
        .active_segments(active_segments)
    );


    always #1 clk = ~clk;
    always @(posedge clk) begin
        #1;
        display_state();
        cycles = cycles+1;
    end
    always @(posedge clk)
    #1 if (debugenable) begin
         case (display_mux)
            DISPLAY_PC: display_mux = DISPLAY_REG;
            DISPLAY_REG: display_mux = DISPLAY_MEM;
            DISPLAY_MEM: display_mux = DISPLAY_IMM;
            DISPLAY_IMM: display_mux = DISPLAY_FLAGS;
            DISPLAY_FLAGS: display_mux = DISPLAY_INSTRUCTION;
            DISPLAY_INSTRUCTION: display_mux = DISPLAY_PC;
            default: display_mux = DISPLAY_PC;
         endcase
    #8 display_seven_seg();
    end
    seven_segment_t d0, d1, d2, d3;
    always @(posedge clk) begin
        case (active_seven_seg_digit)
            4'b1110: d0 <= active_segments;
            4'b1101: d1 <= active_segments;
            4'b1011: d2 <= active_segments;
            4'b0111: d3 <= active_segments;
            default:;
        endcase
    end
    int cycles = 0;
    task static display_state;
        begin
            if (debugreset) $display("cycle: %3d, BOARD BEING RESET", cycles);
            if (cpuhalted) $display("cycle: %3d, cpu is halted", cycles);
            else if (debugenable) begin
                $display("cycle: %3d, enable: %b, step: %b, tick: %b, clkdiv_count: %d, pc: %d",
                cycles, debugenable, debugstepbtn, debugtick, basys3.clk_div.count, basys3.dut.pc);
            end
        end
    endtask

    task static display_seven_seg;
        $display("SEVEN SEGMENT ACTIVE: %s %s %s %s, pc=%0d, displaying: %s",
         d3.name(),d2.name(),d1.name(),d0.name(), basys3.dut.pc, display_mux.name());
    endtask

    task static run_program;
    input enable_mode_t mode;
        begin
            static int i = 0;
            enable_switches = mode;
            $display("MODE: %b", mode);
            while (i < 255 && !cpuhalted) begin
                i = i+1;
                case (mode)
                    TICK_MODE: begin
                       #TIMEPERTICK;
                    end
                    MANUAL_MODE: begin
                        step_btn = 1;
                        #MIN_DELAY;
                        step_btn = 0;
                        #MIN_DELAY;
                    end
                    TURBO_MODE: #2;
                    default: #2;
                endcase
            end
            if (cpuhalted) $display("PROGRAM COMPLETED! mode: %b", mode);
            else $display("PROGRAM DID NOT COMPLETE :(");
        end
    endtask

    task automatic dump_state_pc;
        begin
            string pcstr;
            $display("-----DUMPING CPU STATE INTO MEMORY-----");
            $sformat(pcstr, "%0d", basys3.dut.pc);
            if (cpuhalted) pcstr = "HALT";
            basys3.dut.cpu0.dp0.regs.dump_reg_custom(pcstr); //saves file with name pcstr at /Simulator/reg{pcstr}.mem
            basys3.dut.ram0.dump_ram_custom(pcstr);
        end
    endtask
    //always #2 cycles = cycles + 1;
    initial begin
        clk = 0;
        step_btn = 0;
        enable_switches = PAUSE_MODE;
        reset_btn = 0;
        display_mux = DISPLAY_PC;
        monitor_address = 0;
        $readmemb("../machine-code/instructions.mem", basys3.dut.imem0.mem);
        $display("start!");
        assert(debugreset) else $display("Initial reset not active");
        #2
        run_program(test_mode);
        dump_state_pc();
/*         $display("MODE ARG NOT PROVIDED, RUNNING ALL MODES -  output from TURBO_MODE");
        run_program(MANUAL_MODE);
        reset_btn = 1;
        #MIN_DELAY
        reset_btn = 0;
        #MIN_DELAY
        run_program(TICK_MODE);
        reset_btn = 1;
        #MIN_DELAY
        reset_btn = 0;
        #MIN_DELAY
        run_program(TURBO_MODE); */
    $finish;
    end
    initial begin
        #1000 $finish; //incase program fails to end
    end
endmodule
