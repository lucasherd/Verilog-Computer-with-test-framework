`timescale 1ns / 1ps
import defines::*;

module computer_tb;
  parameter int WIDTH = 8;
  parameter int NREG = 8;
  parameter int NRAM = 64;
  parameter int PCWIDTH = 8;
  parameter int INST_WIDTH = 5+3*$clog2(NREG)+WIDTH;
  reg clk, reset, enable;
  reg [$clog2(NRAM)-1:0] viewmem;
  reg [$clog2(NREG)-1:0] viewreg;
  wire [INST_WIDTH-1:0] instruction;
  wire [WIDTH-1:0] imm_data;
  wire [WIDTH-1:0] debugoutputdata, dqa,dqb;
  wire debugwmem, debugwreg, halted;
  wire [2:0] debugcompareop;
  wire [4:0] debugop;
  wire [$clog2(NREG)-1:0] dra, drb, drw;
  wire [$clog2(NRAM)-1:0] debugmemaddy;
  wire [PCWIDTH-1:0] pc;
  reg dontprint;
  reg doprint;
    initial begin
        if (!$value$plusargs("DONTPRINT=%s", dontprint))
            dontprint = 0;
        doprint = ~dontprint;
        $display(doprint);
    end
  computer #(.WIDTH(WIDTH), .NREG(NREG), .NRAM(NRAM), .PCWIDTH(PCWIDTH)) dut (
    .debugimm_data(imm_data),
    .clk(clk),
    .enable(enable),
    .reset(reset),
    .debugoutputdata(debugoutputdata),
    .debugwmem(debugwmem),
    .debugmemaddy(debugmemaddy),
    .debugwreg(debugwreg),
    .debugopcode(debugop),
    .debugcompareop(debugcompareop),
    .dra(dra),
    .drb(drb),
    .dw(drw),
    .dqb(dqb),
    .dqa(dqa),
    .debug_inst(instruction),
    .debugpc(pc),
    .halted(halted)
  );
    initial begin
    $readmemb("../machine-code/instructions.mem", dut.imem0.mem);
  end
  always #1 clk = ~clk;
  assign enable = 1; // or some condition based on your design
  task static execute;
    begin
      if (debugwreg) $display("pc: %d, op: %b, ra: 0x%h, rb: 0x%h, IMM: %d, w: 0x%h, result: %d",
      pc, debugop, dra, drb, imm_data, drw, $signed(debugoutputdata));
      else if (debugwmem) $display("pc: %d, Op: %b, memaddy: 0x%h, b: %d, data: %d ",
       pc, debugop, debugmemaddy, $signed(dqb),$signed(debugoutputdata));
      else if (debugop == 5'b10000) $display("pc: %d, op: CMP, ra: 0x%h, rb: 0x%h",
       pc, dra, drb);
      else if (debugop == 5'b10001) $display("pc: %d, op: CMP, ra: 0x%h, IMM: %d",
       pc, dra, imm_data);
      else $display("pc: %d, op: %b,result: %d", pc, debugop, $signed(debugoutputdata));
    end
  endtask
    task automatic dump_state_pc;
        begin
            string pcstr;
            $display("-----DUMPING CPU STATE INTO MEMORY-----");
            $sformat(pcstr, "%0d", pc);
            if (halted) pcstr = "HALT";
            $display(pcstr);
            dut.cpu0.dp0.regs.dump_reg_custom(pcstr);
            dut.ram0.dump_ram_custom(pcstr);
        end
    endtask
  always @(posedge clk) begin
    if (!halted && !reset && doprint) execute();
  end
  initial begin
    static int ran = 0;
    static int i = 0;
    clk = 0;
    reset = 1;
    #2 reset = 0;
    $display("start!");
    $display("CPU PROGRAMMING TEST BEGINNING");
    while (!halted) begin
      #2;
    end
    if (halted) begin
      $display("PC: %d, CPU HALTED", pc);
      $display("PROGRAM COMPLETED");
    end
    else begin
      $display("PC: %d, CPU DID NOT HALT", pc);
      $display("PROGRAM DID NOT COMPLETE");
    end
    dump_state_pc();
    $display("CLOCK CYCLES: %0d",$time/2);
    $display("------CPU PROGRAM TEST END------");
    $finish;
  end
  initial begin
    $dumpfile("Simulator/cpu.vcd");
    $dumpvars(0, computer_tb);
end
  initial begin //prevent infinite loop
    #200000
      dump_state_pc();
      $finish;
  end
endmodule
