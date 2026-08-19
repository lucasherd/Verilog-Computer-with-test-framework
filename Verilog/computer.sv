import defines::*;

module full_adder (input a, input b, input cin, output sum, output cout);
  assign sum = a^b^cin;
  assign cout = (a&b)|(a&cin)|(b&cin);
endmodule


module adderx #(parameter int X = 1) (input [X-1:0] a,b,input cin, output [X-1:0] c,output cout);
  wire [X:0] carry;
  assign carry[0] = cin;
  assign cout = carry[X];
  genvar i;
  generate
    for (i=0;i<X;i=i+1) begin : g_ripple_adder
      full_adder u (.a(a[i]), .b(b[i]), .cin(carry[i]), .sum(c[i]), .cout(carry[i+1]));
    end
  endgenerate
endmodule


module regbank #(parameter int WIDTH = 8, parameter int N = 8)  //REGISTER FILE
  (input clk, clkenable, wenable, reset,
   input [$clog2(N)-1:0] ra,rb,w, monitor_reg_addy, //addresses
   input [WIDTH-1:0] data,
   output [WIDTH-1:0] qa,qb, monitor_reg_data);
  reg [WIDTH-1:0] r [0:N-1];
  int i;
  always @(posedge clk or posedge reset) begin
    if (reset) for (i=0;i<N;i=i+1)
      r[i] <= 0;
    else if (wenable && clkenable) r[w] <= data;
  end
  assign qa = r[ra];
  assign qb = r[rb];
  assign monitor_reg_data = r[monitor_reg_addy];

task static dump_reg_custom;
  input string filename;
  string filepath;
  begin
    filepath = {"Simulator/reg",filename,".mem"};
    $writememb(filepath, r);
  end
endtask
endmodule


module alu #(parameter int WIDTH = 8)
  (
    input [WIDTH-1:0] a,b,
    input [2:0] op,
    output reg [WIDTH-1:0]out,
    output reg carry,
    output reg Z, N, V
  );
  wire [WIDTH-1:0] add_result,and_result,or_result,xor_result,ls_result,rs_result;
  wire add_carry;
  reg cin,didadd,didsub,didand,didor,didxor,didls,didrs;
  reg [WIDTH-1:0] bin;

  //ALU control logic
  always_comb begin
    bin = b;
    {didadd,didsub,didand,didor,didxor,didls,didrs,cin} = 8'd0;
      case (op)
        3'd0: //add
          didadd = 1;
        3'd1: begin //subtract
          didsub = 1;
          bin = ~b;
          cin = 1;
        end
        3'd2: didand = 1; //and
        3'd3: didor = 1;//or
        3'd4: didxor = 1; //xor
        3'd5: didls = 1; // shiftleft
        3'd6: didrs = 1; //shift right
        3'd7: begin //increment
          didadd = 1; //b conversion to one done in datapath
        end
        default: didadd = 1;
      endcase
  end

    //instantiate adder and assign results
  adderx #(WIDTH) adder (.a(a), .b(bin), .cin(cin), .c(add_result), .cout(add_carry));
  assign and_result = a & b;
  assign or_result = a | b;
  assign xor_result = a ^ b;
  assign ls_result = a << b;
  assign rs_result = a >> b;
  //mux results from op
  always @(*) begin
    carry = 0;
    if (didadd || didsub) begin
      carry = add_carry;
      out = add_result;
    end
    else if (didand) out = and_result;
    else if (didor) out = or_result;
    else if (didxor) out = xor_result;
    else if (didls) begin
      out = ls_result;
      carry = a[WIDTH-1];
    end
    else if (didrs) begin
      out = rs_result;
      carry = a[0];
    end
    else begin
      out = {WIDTH{1'b0}};
    end
  end

  //Flags
  assign V = (didadd || didsub) && //Overflow
           (a[WIDTH-1] == bin[WIDTH-1]) &&
            (add_result[WIDTH-1] != a[WIDTH-1]);
  assign Z = out == 0; //Zero
  assign N = out[WIDTH-1]; //Negative number

endmodule




module datapath   //register -> alu -> registers
  #(parameter int WIDTH = 8, parameter int NREG = 8, parameter int NRAM = 8)
  (input clk, enable, reset, writereg, a_sel, ram_addy_sel, do_compare, branch_pc_check, halt,
   input [1:0] b_sel,
   input wb_sel_t wb_sel,
   input [2:0] op,
   input cmp_op_t compareop,
   input [$clog2(NREG)-1:0] ra,rb,w, monitor_reg_addy, //addresses
   input [WIDTH-1:0] immdata, ramdata,
   output [WIDTH-1:0] returndata, a,b, monitor_reg_data,
   output [$clog2(NRAM)-1:0] memaddy,
   output logic Z_status, N_status, V_status, carry_status, take_pc_branch,
   output logic halted
  );
  //constants
  //intermediates
  logic [WIDTH-1:0] qa, qb, amux, bmux;
  logic [WIDTH-1:0] result;
  logic Z_flag, N_flag, V_flag, carry_flag;
  reg compare_result;
  reg [WIDTH-1:0] writemux;

  //control signals
  assign amux = a_sel ? immdata : qa;
  assign memaddy = ram_addy_sel ? immdata[$clog2(NRAM)-1:0] : qa[$clog2(NRAM)-1:0];

  always_comb case (b_sel)
      2'b00: bmux = qb;
      2'b01: bmux = immdata;
      2'b10: bmux = {{WIDTH-1{1'b0}}, 1'b1}; //for increment, bitshift
      default: bmux = qb;
    endcase

  always_comb case (wb_sel)
     WB_ALU: writemux = result;
     WB_BOOL: writemux = compare_result;
     WB_MEM: writemux = ramdata;
     WB_REG: writemux = qb;
     WB_IMM: writemux = immdata;
     default: writemux = result;
   endcase

  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
    Z_status <= 0;
    N_status <= 0;
    V_status <= 0;
    carry_status <= 0;
    end
    else if (do_compare && enable) begin //Latched status flags on compare instruction
    Z_status <= Z_flag;
    N_status <= N_flag;
    V_status <= V_flag;
    carry_status <= carry_flag;
    end
  end

  always_ff @(posedge clk or posedge reset) begin //update halted status
      if (reset) halted <= 0;
      else if (halt && enable) halted <= 1;
  end
  always_comb begin
      case (compareop)
        CMP_NEVER: compare_result = 0;
        CMP_GT: compare_result = ~Z_status & ~N_status;
        CMP_LT: compare_result = N_status;
        CMP_GE: compare_result = ~N_status;
        CMP_LE: compare_result = Z_status | N_status;
        CMP_EQ: compare_result = Z_status;
        CMP_NEQ: compare_result = ~Z_status;
        CMP_ALWAYS: compare_result = 1;
        default: compare_result = 0;
      endcase
  end
  //outputs
  assign a = qa;
  assign b = qb;
  assign returndata = writemux;
  assign take_pc_branch = branch_pc_check & compare_result;

  // make alu
  alu #(WIDTH) alu0 (
    .a(amux), //reg read output goes to alu
    .b(bmux),
    .op(op),
    .out(result),
    .carry(carry_flag),
    .Z(Z_flag),
    .N(N_flag),
    .V(V_flag)
  );

  //make regs
  regbank #(.WIDTH(WIDTH), .N(NREG)) regs (
    .clk(clk),
    .wenable(writereg),
    .clkenable(enable),
    .reset(reset),
    .ra(ra),
    .rb(rb),
    .w(w),
    .data(writemux), // output goes back to reg
    .monitor_reg_addy(monitor_reg_addy),
    .monitor_reg_data(monitor_reg_data),
    .qa(qa),
    .qb(qb)
  );
endmodule


module controlunit #(parameter int NREG=8, parameter int WIDTH=8, parameter int PCWIDTH=6) (
  input [4+3*$clog2(NREG)+WIDTH:0] instruction,
  output logic writereg, writememory, a_sel, ram_addy_sel, do_compare,
  output logic branch_pc_check, jump_pc, halt,
  output logic [1:0] b_sel,
  output logic [2:0] aluop,
  output logic [2:0] compareop,
  output wb_sel_t wb_sel,
  output logic [$clog2(NREG)-1:0] ra, rb, w,
  output logic [WIDTH-1:0] immediate_data,
  output logic [PCWIDTH:0] next_pc
);
  localparam bit [1:0] REG = 2'b00; localparam bit [1:0] IMM = 2'b01;
  localparam bit [1:0] UNO = 2'b10;
  logic [4:0] opcode;
  assign opcode = instruction[4+3*$clog2(NREG)+WIDTH:3*$clog2(NREG)+WIDTH];
  assign ra = instruction[3*$clog2(NREG)-1+WIDTH:2*$clog2(NREG)+WIDTH];
  assign rb = instruction[2*$clog2(NREG)-1+WIDTH:$clog2(NREG)+WIDTH];
  assign w = instruction[$clog2(NREG)-1+WIDTH:WIDTH];
  assign immediate_data = instruction[WIDTH-1:0];
  assign compareop = instruction[3*$clog2(NREG)-1+WIDTH:3*$clog2(NREG)-3+WIDTH];
  assign next_pc = instruction[PCWIDTH:0];
    always @* begin
      aluop = opcode[2:0];
      wb_sel = WB_ALU; b_sel = REG; a_sel=REG;
      ram_addy_sel = REG;
      {writereg, writememory, halt} = 3'd0;
      {do_compare, branch_pc_check, jump_pc} = 3'd0;
      casez (opcode)
        5'b000??, 5'b00100: begin //internal alu
          writereg = 1;
          wb_sel = WB_ALU; //from alu
        end
        5'b001??: begin //internal alu bitwise with 1
          writereg = 1;
          wb_sel = WB_ALU; //from alu
          b_sel = UNO; //1
        end
        5'b01???: begin //immediate with alu
          writereg = 1;
          wb_sel = WB_ALU; //from alu
          b_sel = IMM;
          ram_addy_sel = REG;
          if (aluop==3'd7) begin
            a_sel = 1'b1; //incrememnt immediate
            b_sel = UNO;
          end
        end
        5'b10000: begin //COMPARE and update status flags
          aluop = 3'b001;
          do_compare = 1;
          wb_sel = WB_BOOL; //doesnt write, but outputs comparison result for debugging purposes
        end
        5'b10001: begin //COMPARISON WITH IMMEDIATE
          aluop = 3'b001;
          do_compare = 1;
          b_sel = IMM;
          wb_sel = WB_BOOL;
        end
        5'b10010: begin //set register to comparison output
          writereg = 1;
          wb_sel = WB_BOOL;
        end
        5'b10011: begin //branch with condition
          branch_pc_check = 1;
          wb_sel = WB_BOOL;
        end
        5'b10100: begin //jump unconditionally
          jump_pc = 1;
          wb_sel = WB_BOOL;
        end
        5'b10101: begin
          halt = 1; //halt
        end
        5'b11010: begin //store [address from reg]
          writememory = 1;
          wb_sel = WB_REG;
          ram_addy_sel = REG;
        end
        5'b11011: begin //store [address from immediate]
          writememory = 1;
          wb_sel = WB_REG;
          ram_addy_sel = IMM;
        end
        5'b11100: begin //load from ram with address from reg
          writereg = 1;
          wb_sel = WB_MEM;
          ram_addy_sel = REG;
        end
        5'b11101: begin //load from ram with immediate address
          writereg = 1;
          wb_sel = WB_MEM;
          ram_addy_sel = IMM;
        end
        5'b11110: begin
          writereg = 1; //load immediate to reg
          wb_sel = WB_IMM;
        end
        5'b11111: begin //copy one reg to another
        writereg = 1;
        wb_sel = WB_REG;
        end
        default:;
      endcase
    end
endmodule


module cpu #(parameter int WIDTH=8, parameter int NREG=8,
             parameter int NRAM=64, parameter int PCWIDTH=8) (
  input [4+3*$clog2(NREG)+WIDTH:0] instruction,
  input [$clog2(NREG)-1:0] monitor_reg_addy,
  input [WIDTH-1:0] memr_data,
  input clk, reset, enable,
  output [WIDTH-1:0] cpu_output, dqa, dqb, debugimm,
  output [WIDTH-1:0] monitor_reg_data,
  output [$clog2(NRAM)-1:0] memaddy,
  output wmem, debugwreg, halt, halted,
  output [$clog2(NREG)-1:0] debugra, debugrb, debugw,
  output take_pc_branch, take_pc_jump,
  output [PCWIDTH:0] next_pc,
  output [2:0] debugcompareop,
  output [3:0] flags
);
  wire [2:0] aluop;
  cmp_op_t compareop;
  wb_sel_t wb_sel;
  wire [1:0] b_sel;
  wire wreg, a_sel, ram_addy_sel, do_compare;
  wire branch_pc_check;
  wire [WIDTH-1:0] a,b, immediate_data;
  wire carry, Z_flag, N_flag, V_flag;
  wire [$clog2(NREG)-1:0] ra, rb, w;
  //assign debugging wires
  assign debugwreg = wreg;
  assign debugra = ra;
  assign debugrb = rb;
  assign debugw = w;
  assign dqa = a;
  assign dqb = b;
  assign debugimm = immediate_data;
  assign debugcompareop = compareop;
  assign flags = {carry, Z_flag,N_flag,V_flag}; //carry, Z, N, V

  //instantiate modules
  controlunit #(.NREG(NREG), .WIDTH(WIDTH), .PCWIDTH(PCWIDTH)) control0 (
    .instruction(instruction),
    .ra(ra),
    .rb(rb),
    .w(w),
    .immediate_data(immediate_data),
    .writereg(wreg),
    .writememory(wmem),
    .a_sel(a_sel),
    .b_sel(b_sel),
    .wb_sel(wb_sel),
    .ram_addy_sel(ram_addy_sel),
    .aluop(aluop),
    .compareop(compareop),
    .do_compare(do_compare),
    .branch_pc_check(branch_pc_check),
    .jump_pc(take_pc_jump),
    .next_pc(next_pc),
    .halt(halt)
  );

  datapath #(.WIDTH(WIDTH), .NREG(NREG), .NRAM(NRAM)) dp0 (
    .clk(clk),
    .enable(enable),
    .reset(reset),
    .halt(halt),
    .halted(halted),
    .op(aluop),
    .compareop(compareop),
    .writereg(wreg),
    .a_sel(a_sel),
    .b_sel(b_sel),
    .wb_sel(wb_sel),
    .ram_addy_sel(ram_addy_sel),
    .do_compare(do_compare),
    .branch_pc_check(branch_pc_check),
    .take_pc_branch(take_pc_branch),
    .immdata(immediate_data),
    .ramdata(memr_data),
    .ra(ra),
    .rb(rb),
    .w(w),
    .returndata(cpu_output),
    .memaddy(memaddy),
    .a(a),
    .b(b),
    .carry_status(carry),
    .Z_status(Z_flag),
    .N_status(N_flag),
    .V_status(V_flag),
    .monitor_reg_addy(monitor_reg_addy),
    .monitor_reg_data(monitor_reg_data)
  );

endmodule



module RAM #(parameter int WIDTH=8, parameter int NRAM = 64) (
  input clk, write, reset, enable,
  input [$clog2(NRAM)-1:0] address,
  input [$clog2(NRAM)-1:0] monitor_address,
  input [WIDTH-1:0] write_data,
  output [WIDTH-1:0] read_data,
  output [WIDTH-1:0] monitor_data
);
reg [WIDTH-1:0] mem [0:NRAM-1];

always @(posedge clk or posedge reset) begin
  if (reset) for (int i=0;i<NRAM;i=i+1) mem[i] <= 0;
  else if (write && enable) mem[address] <= write_data;
end
assign monitor_data = mem[monitor_address];
assign read_data = mem[address];

task static dump_ram_custom;
input string filename;
string filepath;
begin
  filepath = {"Simulator/ram",filename,".mem"};
  $writememb(filepath, mem);
end
endtask
endmodule

module program_counter #(parameter int PCWIDTH=8) (
  input clk, enable, reset, branch, jump, halt,
  input signed [PCWIDTH:0] next_pc,
  output logic [PCWIDTH-1:0] pc
);
logic signed [PCWIDTH:0] pc_branch;

always_comb begin
    pc_branch = $signed({1'b0, pc}) + next_pc + 1;
end

initial pc = 0;
  always @(posedge clk) begin
    if (reset) begin
    pc <= 0;
    end
    else if (enable) begin
      if (halt) pc <= pc;
      else if (branch) pc <= pc_branch[PCWIDTH-1:0];
      else if (jump) pc <= next_pc + 1;
      else pc <= pc + 1;
    end
    else pc <= pc;
  end

endmodule

module instruction_memory #(
  parameter int INST_WIDTH=22,
  parameter int PCWIDTH=8,
  parameter int MAX_INST= 2**PCWIDTH
  )
  (
  input [PCWIDTH-1:0] address,
  output [INST_WIDTH-1:0] instruction
);
  logic [INST_WIDTH-1:0] mem [0:MAX_INST-1];
  assign instruction = mem[address];
    
  initial begin
    $readmemb("instructions.mem", mem);
end
endmodule

module computer
 #(
   parameter int WIDTH=4'd8,
   parameter int NREG=4'd8,
   parameter int NRAM=7'd64,
   parameter int PCWIDTH=4'd8,
   parameter int INST_WIDTH= 5+3*$clog2(NREG)+WIDTH
  )
  (
    input clk, reset, enable,
    input [$clog2(NRAM)-1:0] monitor_address,
    output signed [WIDTH-1:0] debugoutputdata, dqa,dqb, debugimm_data,
    output [WIDTH-1:0] monitor_reg_data, monitor_mem_data,
    output [4:0] debugopcode,
    output debugwmem, debugwreg, halted,
    output [PCWIDTH-1:0] debugpc,
    output [2:0] debugcompareop,
    output [3:0] aluflags, //carry, Z, N, V
    output [$clog2(NREG)-1:0] dra, drb, dw,
    output [$clog2(NRAM)-1:0] debugmemaddy,
    output [INST_WIDTH-1:0] debug_inst
  );
  wire [$clog2(NREG)-1:0] monitor_reg_addy;
  wire [WIDTH-1:0] read_mem, cpu_output,debugimm;
  wire write_mem, branch_pc, jump_pc, halt;
  wire [$clog2(NRAM)-1:0] memaddy;
  wire [PCWIDTH-1:0] pc;
  wire [INST_WIDTH-1:0] instruction;
  wire [PCWIDTH:0] next_pc;
  assign debugopcode = instruction[4+3*$clog2(NREG)+WIDTH:3*$clog2(NREG)+WIDTH];
  assign debugwmem = write_mem;
  assign debugoutputdata = cpu_output;
  assign debugmemaddy = memaddy;
  assign debugimm_data = debugimm;
//  assign reset = reset_btn | reset_instruction;
  assign debug_inst = instruction;
  assign debugpc = pc;
  assign monitor_reg_addy = monitor_address[$clog2(NREG)-1:0];

  cpu #(.WIDTH(WIDTH), .NREG(NREG), .NRAM(NRAM), .PCWIDTH(PCWIDTH)) cpu0 (
    .instruction(instruction),
    .memr_data(read_mem),
    .clk(clk),
    .enable(enable),
    .cpu_output(cpu_output),
    .memaddy(memaddy),
    .wmem(write_mem),
    .reset(reset),
    .halt(halt),
    .halted(halted),
    .monitor_reg_addy(monitor_reg_addy),
    .monitor_reg_data(monitor_reg_data),
    .debugwreg(debugwreg),
    .debugcompareop(debugcompareop),
    .flags(aluflags),
    .debugra(dra),
    .debugrb(drb),
    .debugw(dw),
    .dqa(dqa),
    .dqb(dqb),
    .debugimm(debugimm),
    .take_pc_branch(branch_pc),
    .take_pc_jump(jump_pc),
    .next_pc(next_pc)
  );

  RAM #(.WIDTH(WIDTH), .NRAM(NRAM)) ram0 (
    .clk(clk),
    .enable(enable),
    .write(write_mem),
    .reset(reset),
    .address(memaddy),
    .monitor_address(monitor_address),
    .write_data(cpu_output),
    .read_data(read_mem),
    .monitor_data(monitor_mem_data)
  );

  program_counter #(.PCWIDTH(PCWIDTH)) pc0 (
    .clk(clk),
    .enable(enable),
    .reset(reset),
    .halt(halt),
    .branch(branch_pc),
    .jump(jump_pc),
    .next_pc(next_pc),
    .pc(pc)
  );

  instruction_memory #(.INST_WIDTH(INST_WIDTH), .PCWIDTH(PCWIDTH)) imem0 (
    .address(pc),
    .instruction(instruction)
  );

endmodule

