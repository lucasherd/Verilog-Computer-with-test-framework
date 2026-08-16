import defines::*;

module digit_to_seven_seg(
    input [3:0] digit,
    output seven_segment_t segments
);
    always_comb begin : digit_to_segments
        case (digit)
            4'd0: segments = ZERO;
            4'd1: segments = ONE;
            4'd2: segments = TWO;
            4'd3: segments = THREE;
            4'd4: segments = FOUR;
            4'd5: segments = FIVE;
            4'd6: segments = SIX;
            4'd7: segments = SEVEN;
            4'd8: segments = EIGHT;
            4'd9: segments = NINE;
            4'd14: segments = OFF;
            4'd15: segments = MINUS;
            default: segments = OFF;
        endcase
    end
endmodule

module seven_seg_controller #(parameter int CLK_FREQ=100000000, parameter int TICK_FREQ=1000)
(
    input [15:0] digits,
    input clk,
    input initial_reset, reset,
    output seven_segment_t active_segments, //ACTIVE LOW!
    output logic [3:0] active_digit
);
    wire [6:0] digit_segs[0:3];
    wire tick;
    logic [1:0] digit_sel;
    logic reset_clk;
    logic reset_detected;
    genvar i;
    generate
        for (i = 0; i < 4; i++) begin : g_segment_generator
            digit_to_seven_seg d_to_s (
                .digit(digits[3+4*i:4*i]),
                .segments(digit_segs[i])
            );
        end
    endgenerate

    always_ff @(posedge clk) reset_detected <= initial_reset;
    assign reset_clk = initial_reset & !reset_detected;
    clk_divider #(.CLK_FREQ(CLK_FREQ), .TICK_FREQ(TICK_FREQ)) ssg_divider (
        .clk(clk),
        .reset(reset_clk),
        .tick(tick)
    );

    always_comb begin
        if (reset)
            active_segments = MINUS;
        else
            active_segments = seven_segment_t'(digit_segs[digit_sel]);
    end
    always_ff @(posedge clk) begin
        if (tick) begin //alternate each digit
            case (active_digit)
                4'b1110: begin
                    active_digit <= 4'b1101;
                    digit_sel <= 2'd1;
                end
                4'b1101: begin
                    active_digit <= 4'b1011;
                    digit_sel <= 2'd2;
                end
                4'b1011: begin
                    active_digit <= 4'b0111;
                    digit_sel <= 2'd3;
                end
                4'b0111: begin
                    active_digit <= 4'b1110;
                    digit_sel <= 2'd0;
                end
                default: begin
                    active_digit <= 4'b1110;
                    digit_sel <= 2'd0;
                end

            endcase
        end
    end
endmodule

module monitor #(
    parameter int WIDTH = 8,
    parameter int NREG = 8,
    parameter int NRAM = 64,
    parameter int PCWIDTH = 8,
    parameter int CLK_FREQ = 100000000,
    parameter int TICK_FREQ = 1000
)
(
    input clk, initial_reset, reset,
    input display_mux_t display_mux, //2 bit wide mux (switches)
    input [$clog2(NRAM)-1:0] address,
    input [WIDTH-1:0] reg_data, mem_data, imm_data, cpu_output_data,
    input [4:0] opcode,
    input [3:0] aluflags,
    input enable_mode_t mode_sel, //2 bit mux (switches)
    input  [PCWIDTH-1:0] pc,
    output logic [15:0] led_data,
    output seven_segment_t active_segments,
    output dec_point,
    output logic [3:0] active_digit
);
    logic signed [WIDTH-1:0] active_data;
    wire [3:0] ones, tens, hundreds, minus;
    logic [15:0] seven_seg_digits;
    always_comb begin
        led_data = {14'b0, mode_sel};
        case (display_mux)
            DISPLAY_PC: begin
                active_data = pc;
                led_data[15:11] = opcode;
            end
            DISPLAY_REG: begin
                active_data = reg_data;
                led_data[15:16-$clog2(NRAM)] = address;
            end
            DISPLAY_MEM: begin
                active_data = mem_data;
                led_data[15:16-$clog2(NRAM)] = address;
            end
            DISPLAY_IMM: begin
                active_data = imm_data;
                led_data[15:11] = opcode;
            end
            DISPLAY_FLAGS: begin
                active_data = cpu_output_data;
                led_data[15:12] = aluflags; //carry, Z, N, V
            end
            default: active_data = {WIDTH{1'b0}};
        endcase
    end
    logic [WIDTH:0] magnitude;
    assign magnitude = active_data[WIDTH-1]
                    ? -active_data
                    : active_data;
    assign ones = magnitude % 10;
    assign tens = (magnitude / 10) % 10;
    assign hundreds = magnitude / 100;
    assign minus = (active_data[WIDTH-1]==1'b1)? 4'b1111 : 4'b1110;
    assign seven_seg_digits = {minus, hundreds, tens, ones};
    assign dec_point = 1'b1; //off permanently
    seven_seg_controller #(.CLK_FREQ(CLK_FREQ), .TICK_FREQ(TICK_FREQ)) seg_controller (
        .digits(seven_seg_digits),
        .clk(clk),
        .reset(reset),
        .initial_reset(initial_reset),
        .active_segments(active_segments),
        .active_digit(active_digit)
    );
endmodule

module clk_divider #(
    parameter int CLK_FREQ = 100000000,
    parameter int TICK_FREQ=100000000
    )//100MH
(
    input clk, reset,
    output logic tick);
    localparam int CLKSPERTICK = CLK_FREQ/TICK_FREQ; //100MH
    localparam int WIDTH = (CLKSPERTICK <= 1) ? 1 : $clog2(CLKSPERTICK);
    logic [WIDTH-1:0] count;

    initial count = 0;
    always_ff @(posedge clk) begin
        if (reset) begin
        count <= 0;
        end else if (count>=(CLKSPERTICK-1)) begin
            count <= 0;
        end else begin
            count <= count + 1;
        end
    end
    assign tick = (count >= CLKSPERTICK-1) && !reset; //tick is active when count=CLKPERTICK

    initial begin
    assert (TICK_FREQ > 0)
        else $fatal("TICK_FREQ must be positive");

    assert (TICK_FREQ <= CLK_FREQ)
        else $fatal("TICK_FREQ cannot exceed CLK_FREQ");

    assert (CLK_FREQ % TICK_FREQ == 0)
        else
            $warning(
                "Clock divider is not exact (%0d / %0d). Actual frequency will be slightly lower.",
                CLK_FREQ, TICK_FREQ
            );
end
endmodule

module debouncer #(
    parameter int DEBOUNCE_CYCLES = 1000000 // 10ms at 100MHz
    )(
    input clk, reset, button,
    output logic debounced
);
    logic [$clog2(DEBOUNCE_CYCLES)-1:0] count;
    logic button_meta, button_sync;
    initial begin
        count = 0;
        debounced = 0;
    end
    // Synchronize the button input to the clock domain
    always_ff @(posedge clk) begin
        if (reset) begin
            button_meta <= 0;
            button_sync <= 0;
        end else begin
            button_meta <= button;
            button_sync <= button_meta; //button state from one cycle ago
        end
    end

    // Debounce logic
    always_ff @(posedge clk) begin
        if (reset) begin
            count <= 0;
            debounced <= 0;
        end else if (button_sync == debounced) begin
            count <= 0; // Reset counter if state is stable
        end else begin
            count <= count + 1;
            if (count >= DEBOUNCE_CYCLES) begin
                debounced <= button_sync; // Update debounced state after stable period
                count <= 0; // Reset counter after state change
            end
        end
    end
endmodule

module initial_reset #(int RESET_CYCLES = 10000000) //.1s
 (
    input clk,
    output logic reset = 1
);
    logic [$clog2(RESET_CYCLES)-1:0] count = 0;

    always_ff @(posedge clk) begin
        if (count < RESET_CYCLES) begin
            count <= count + 1;
            reset <= 1;
        end else begin
            reset <= 0;
        end
    end
endmodule


module board #(
    parameter int WIDTH = 8,
    parameter int NREG = 8,
    parameter int NRAM = 64,
    parameter int PCWIDTH = 8,
    parameter int INST_WIDTH = 5+3*$clog2(NREG)+WIDTH,
    parameter int TICK_FREQ = 1,
    parameter int CLK_FREQ = 100000000,
    parameter int SEVEN_SEG_FREQ = 1000,
    parameter int DEBOUNCE_CYCLES = 1000000, // 10ms at 100MHz
    parameter int RESET_CYCLES = 10000000 // .1s at 100MHz
)
(
    input [$clog2(NRAM)-1:0] monitor_address,
    input display_mux_t display_mux,
    input enable_mode_t enable_switches,
    input clk, reset_btn, step_btn,
    output logic [15:0] led_data,
    output seven_segment_t active_segments,
    output dec_point,
    output [3:0] active_seven_seg_digit
);
    wire reset, reset_btn_db, tick, reset_clk_div;
    wire [WIDTH-1:0] monitor_reg_data, monitor_mem_data, monitor_imm_data, cpu_output_data;
    logic debugenable, debugreset, debugtick, debugstep, debugstepbtn, cpuhalted;
    logic step_btn_db, prev_step_btn_db, step, computer_enable;
    enable_mode_t mode_meta = PAUSE_MODE, mode = PAUSE_MODE; //ensure cpu doesnt run instantly
    initial begin
        step = 0;
        prev_step_btn_db = 0;
    end
    clk_divider #(.CLK_FREQ(CLK_FREQ), .TICK_FREQ(TICK_FREQ)) clk_div (
        .clk(clk),
        .reset(reset_clk_div),
        .tick(tick)
    );
    wire initial_reset;
    debouncer #(.DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)) reset_debouncer (
        .clk(clk),
        .reset(initial_reset),
        .button(reset_btn),
        .debounced(reset_btn_db)
    );
    debouncer #(.DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)) step_debouncer (
        .clk(clk),
        .reset(reset),
        .button(step_btn),
        .debounced(step_btn_db)
    );

    initial_reset #(.RESET_CYCLES(RESET_CYCLES)) initial_reset_inst (
        .clk(clk),
        .reset(initial_reset)
    );

    wire [4:0] opcode;
    wire [PCWIDTH-1:0] pc;
    wire [3:0] aluflags;
    computer #(
        .WIDTH(WIDTH),
        .NREG(NREG),
        .NRAM(NRAM),
        .PCWIDTH(PCWIDTH)
    ) dut (
        .clk(clk),
        .reset(reset),
        .enable(computer_enable),
        .monitor_address(monitor_address),
        .monitor_reg_data(monitor_reg_data),
        .monitor_mem_data(monitor_mem_data),
        .debugoutputdata(cpu_output_data),
        .debugimm_data(monitor_imm_data),
        .debugopcode(opcode),
        .aluflags(aluflags), //carry, Z, N, V
        .debugpc(pc),
        .halted(cpuhalted)
    );

    monitor
    #(
        .WIDTH(WIDTH),
        .NREG(NREG),
        .NRAM(NRAM),
        .PCWIDTH(PCWIDTH),
        .CLK_FREQ(CLK_FREQ),
        .TICK_FREQ(SEVEN_SEG_FREQ)
    )
    board_monitor(
        .clk(clk),
        .initial_reset(initial_reset),
        .reset(reset),
        .display_mux(display_mux),
        .address(monitor_address),
        .reg_data(monitor_reg_data),
        .mem_data(monitor_mem_data),
        .imm_data(monitor_imm_data),
        .cpu_output_data(cpu_output_data),
        .opcode(opcode),
        .aluflags(aluflags),
        .mode_sel(mode),
        .pc(pc),
        .led_data(led_data),
        .active_segments(active_segments),
        .dec_point(dec_point),
        .active_digit(active_seven_seg_digit)
    );

    wire tick_mode_flag;
    //combinational logic
    assign tick_mode_flag = mode == TICK_MODE;
    assign reset = reset_btn_db | initial_reset;
    assign reset_clk_div = reset || !tick_mode_flag; //clk div stays at 0 until tick mode is active
    always_comb begin // COMPUTER ENABLE LOGIC
        if (reset) computer_enable = 0;
        else case (mode)
            MANUAL_MODE: computer_enable = step;
            TICK_MODE: computer_enable = tick;
            TURBO_MODE: computer_enable = 1;
            PAUSE_MODE: computer_enable = 0;
            default: computer_enable = 0;
        endcase
    end
    assign debugenable = computer_enable; //debugging in simulation, not in hardware
    assign debugreset = reset;
    assign debugtick = tick;
    assign debugstep = step;
    assign debugstepbtn = step_btn_db;

    //sequential logic

    always_ff @(posedge clk) begin //syncronize switches to clock domain
            mode_meta <= enable_switches;
            mode <= mode_meta;
    end

    always_ff @(posedge clk) begin //pulse step to enable mux
        step <= step_btn_db & ~prev_step_btn_db;
        prev_step_btn_db <= step_btn_db;
    end

endmodule
