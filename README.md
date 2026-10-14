# 8-Bit SystemVerilog CPU

A custom 8-bit processor designed in SystemVerilog, verified with an automated Python-based test framework, and implemented on a Xilinx Basys 3 FPGA.

This project was started in Summer 2026 as a hands-on exploration of digital design, computer architecture, RTL verification, and FPGA development. The processor uses a custom 32-instruction ISA and was designed from the module level up, including the datapath, control logic, ALU, register file, memory interface, and supporting FPGA hardware.

## Features

- Parameterized 8-bit CPU written in SystemVerilog
- Custom 32-instruction instruction set architecture
- ALU supporting arithmetic, logical, and shift operations
- Comparison operations for conditional program flow
- Register file and external RAM interface
- Program counter and control unit
- Immediate and register-based instructions
- Memory load/store operations
- Conditional branching
- Python assembler and disassembler
- Automated Python/SystemVerilog verification framework
- FPGA implementation on a Xilinx Basys 3
- On-board debugging through push-button controls and a multiplexed seven-segment display

## Architecture

The processor is divided into independent RTL modules for the major architectural components, including:

- **ALU** — performs arithmetic, logical, and shift operations and generates processor status flags
- **Register File** — stores general-purpose processor registers
- **Datapath** — routes operands and writeback data between processor components
- **Control Unit** — decodes instructions and generates the control signals required for execution
- **Program Counter** — tracks program execution and supports changes in control flow
- **Program Memory** — stores machine-code instructions used by the processor
- **RAM Interface** — provides load and store access to external data memory

The design is parameterized so architectural values such as data width and register count can be modified without redesigning the individual modules.

## Instruction Set

The processor implements a custom 32-instruction ISA containing several instruction categories:

- Arithmetic and logical operations
- Immediate arithmetic and logical operations
- Comparison operations
- Memory loads and stores
- Immediate memory operations
- Conditional control-flow instructions
- Processor control instructions

Assembly programs are converted into machine code using the included Python assembler.

## Verification

Verification was a major focus of the project rather than relying only on physical FPGA testing.

A Python-based test framework automates much of the simulation process by:

1. Generating or loading processor test programs
2. Converting assembly programs into machine code
3. Compiling the SystemVerilog design and testbench
4. Running simulations using **Icarus Verilog**
5. Comparing simulated processor outputs against expected results
6. Reporting whether each test passes or fails

Directed and automated tests are used to verify individual processor operations as well as complete programs.

Simulation waveforms can also be inspected with **GTKWave** for cycle-by-cycle RTL debugging.

## Assembler / Disassembler

The project includes Python tools for translating between the processor's custom assembly language and binary machine-code representation.

The assembler supports instruction encoding and program generation, while the disassembler provides a way to translate encoded instructions back into a human-readable format.

Round-trip testing is used to help verify that instructions are encoded and decoded consistently.

## FPGA Implementation

The completed processor was synthesized and implemented using **Xilinx Vivado** for a **Basys 3 FPGA development board**.

The board-level design includes controls for interacting with the processor and a multiplexed seven-segment display that can be used to inspect internal processor state during execution.

Values that can be observed on the FPGA include processor registers, RAM contents, the program counter, and other internal signals.

This allows the same processor design to be tested both through RTL simulation and on physical FPGA hardware.

## Repository Structure

```text
.
├── Implementation/   # Vivado / Basys 3 FPGA implementation files
├── Programming/      # Python assembler, disassembler, and program tools
├── Testing/          # Automated verification framework and testbenches
├── Verilog/          # SystemVerilog processor RTL
└── README.md
```

## Tools

### RTL / FPGA
- SystemVerilog
- Xilinx Vivado
- Icarus Verilog
- GTKWave
- Verible

### Software
- Python
- Git

### Hardware
- Xilinx Basys 3 FPGA
- Artix-7 FPGA

## What I Learned

This project gave me hands-on experience with:

- Designing synchronous digital systems in SystemVerilog
- Developing a processor datapath and control architecture
- Designing and encoding a custom instruction set
- Writing reusable and parameterized RTL
- Creating SystemVerilog testbenches
- Automating hardware verification with Python
- Debugging RTL using simulation and waveform analysis
- Synthesizing and implementing a processor on an FPGA
- Debugging differences between simulated and physical hardware behavior

## Future Development

Possible future improvements include:

- Expanding processor memory and register resources
- Improving the instruction set and control-flow capabilities
- Expanding automated verification coverage
- Improving FPGA debugging and visualization
- Exploring architectural optimizations and more advanced processor designs
