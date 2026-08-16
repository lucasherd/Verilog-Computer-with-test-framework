`include "board.sv"
`timescale 10ns / 10ps


module monitor_tb;
localparam int WIDTH = 8;
localparam int NREG = 8;
localparam int NRAM = 64;
localparam int PCWIDTH = 8;

    reg clk, reset, initial_reset;
    display_mux_t display_mux; //2 bit wide mux (switches)
    reg [$clog2(NRAM)-1:0] address;
    reg [WIDTH-1:0] reg_data, mem_data, imm_data, cpu_output_data;
    reg [4:0] opcode;
    enable_mode_t mode_sel; //2 bit mux (switches)
    reg  [PCWIDTH-1:0] pc;
    reg [3:0] aluflags;
    wire [15:0] led_data;
    seven_segment_t active_segments;
    wire [3:0] active_digit;
    int cycles;
    monitor #(.WIDTH(WIDTH), .NREG(NREG), .NRAM(NRAM), .PCWIDTH(PCWIDTH), .TICK_FREQ(100000000)) dut (
        .clk(clk),
        .reset(reset),
        .initial_reset(initial_reset),
        .address(address),
        .display_mux(display_mux),
        .imm_data(imm_data),
        .reg_data(reg_data),
        .mem_data(mem_data),
        .cpu_output_data(cpu_output_data),
        .opcode(opcode),
        .aluflags(aluflags),
        .mode_sel(mode_sel),
        .pc(pc),
        .led_data(led_data),
        .active_segments(active_segments),
        .active_digit(active_digit)
    );
    always #1 clk = ~clk;
    always #2 cycles = cycles + 1;
    reg [1:0] pc_tick;
/*     always_ff @(posedge clk) begin
        if (reset) pc_tick <= 2'd0;
        else pc_tick <= pc_tick + 1'b1;
        if (pc_tick == 2'd3) pc <= pc + 1;
    end */
    seven_segment_t d0, d1, d2, d3;
    always @(posedge clk) begin
        case (active_digit)
            4'b1110: d0 <= active_segments;
            4'b1101: d1 <= active_segments;
            4'b1011: d2 <= active_segments;
            4'b0111: d3 <= active_segments;
            default:;
        endcase
    end

    task static display_seven_seg;
        $display("cycle: %d, SEVEN SEGMENT ACTIVE: %s %s %s %s, pc=%0d, opcode=%b",
         cycles, d3.name(),d2.name(),d1.name(),d0.name(), pc, opcode);
         pc = pc + 1;
    endtask

    task static display_all;
        display_seven_seg();
        $display("LEDS: %b", led_data);
    endtask
    initial begin
        display_mux = DISPLAY_PC;
        address = 0;
        {reg_data, mem_data, imm_data, cpu_output_data} = 0;
        opcode = 0;
        mode_sel = TICK_MODE;
        pc = 0;
        clk = 0;
        reset = 1;
        initial_reset = 1;
        aluflags = 0;
        cycles = 0;
        #12 display_all();
        reset = 0;
        initial_reset = 0;
        address = 8'd3;
        reg_data = 8'd55;
        opcode = 5'b10101;
        #8 display_all();
        mem_data = 8'd200; //actually signed -56
        #8 display_all();
        display_mux = DISPLAY_REG;
        #8 display_all();
        mode_sel = MANUAL_MODE;
        display_mux = DISPLAY_MEM;
        #8 display_all();
        display_mux = DISPLAY_IMM;
        imm_data = 8'd123;
        #8 display_all();
        opcode = 5'b11110;
        #8 display_all();
        $finish;
    end

    initial #100 $finish;
endmodule


