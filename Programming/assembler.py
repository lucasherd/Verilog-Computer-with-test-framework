import tkinter
from tkinter import filedialog



opcodes = {"ADD": "00000", "SUB": "00001", "AND": "00010", "OR": "00011", "XOR": "00100",
           "SHL": "00101", "SHR": "00110", "INC": "00111", "ADDI": "01000", "SUBI": "01001",
           "ANDI": "01010", "ORI": "01011", "XORI": "01100", "SHLI": "01101", "SHRI": "01110", "INCI": "01111",
           "CMP": "10000", "CMPI": "10001", "STORECMP": "10010", "BR": "10011", "JMP": "10100", "HALT": "10101",
           "STORE": "11010", "STOREI": "11011", "LOAD": "11100", "LOADIM": "11101", "LOADI": "11110",
           "RESET": "11111"}
compareops = {"NEVER": "000", "GT": "001", "LT": "010", "GE": "011", "LE": "100",
              "EQ": "101", "NEQ": "110", "ALWAYS": "111"}
INST_FORMATS = {
    'NORMAL':[0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,21,26,27,28,29,30,31],
    'CMP':[16,17],
    'USECMP':[18,19,20]
}

ADDRESS_WIDTH = 3
WIDTH = 8
PCWIDTH = 8
printlines = True
INST_WIDTH = 5 + 3 * ADDRESS_WIDTH + WIDTH

constraints = {"N_REG": 2 ** ADDRESS_WIDTH , "INTEGER_LIMIT": 2 ** WIDTH, "MAX_PROGRAM_SIZE": 2 ** PCWIDTH}


# def b_to_d(n: str):  # converts a binary string number to a int decimal number

def b_to_d(b: str):
    return int(b, 2)

def signed_b_to_d(bin_str):
    bits = len(bin_str)-1
    # Step 1: Convert as if it were unsigned
    val = int(bin_str, 2)
    # Step 2: Check if the sign bit (MSB) is 1
    if bin_str[0] == '1':
        val -= (1 << bits)  # Equivalent to val -= 2**bits
    return val

def d_to_b(n: int, width: int = WIDTH):  # takes an integer and returns its binary equivalent string
    assert n <= 2 ** width, "Integer Overflow Error"
    return f"{n & (2 ** width - 1):0{width}b}"

def choose_form(op):
    for f, codes in INST_FORMATS.items():
        if op in codes:
            return f
    raise ValueError

def assemble_program(program_path=None, program=None, doprint=False, tomachinecode=True):
    if program_path is None and program is None:
        root = tkinter.Tk(baseName='CPU ASSEMBLER')
        program_path = filedialog.askopenfilename(
            title="Select a File",
            initialdir="C:\\Users\\Lucas Herd\\Desktop\\cpuproject\\Programs",
            filetypes=[("Text Files", "*.txt"), ("Assembly Files", "*.asm*")]
        )

    instructions = []
    instruction_num = -1
    line_num = 0
    labels = {}
    zero = '0' * ADDRESS_WIDTH
    bigzero = '0' * WIDTH
    code_unreachable = False
    next_pc = None
    delta = None
    pc_int = None
    if program is None:
        with open(program_path) as file:
            program = file.readlines()
    for line in program:
        line_num += 1
        line = line.strip().split('//')[0]
        parts = line.split(' ')
        if parts[0] == '':
            continue
        elif parts[0][-1] == ":":
            label_name = parts[0][:-1]
            assert label_name not in labels.keys(), "Duplicate Label"
            labels[label_name] = instruction_num
            code_unreachable = False
            continue
        instruction_num += 1
        if code_unreachable:
            print(f"Warning: Unreachable Code on line {line_num}")
        if parts[0] == 'HALT':
            code_unreachable = True
    if doprint:
        print(f' {"LINE":<4} | {"PC":^4} | {"COMMAND":^20} | {"INSTRUCTION":^{INST_WIDTH}} ')
        print('-' * (39 + INST_WIDTH))
    line_num = 0
    instruction_num = -1
    for line in program:
        line = line.strip().split('//')[0]
        parts = line.split(' ')
        line_num += 1
        if parts[0] == '':
            continue
        elif parts[0][-1] == ":":
            if doprint:
                print(f' {line_num:<4} | {"NONE"} | {line[:-1]:^20} | {"NONE":^{INST_WIDTH}} ')
            continue
        instruction_num += 1
        assert instruction_num < constraints['MAX_PROGRAM_SIZE'], 'PROGRAM TOO LARGE :('
        opcode = opcodes.get(parts[0])
        assert opcode is not None, f"Invalid Command: {line} on line {line_num}"
        op_decimal = b_to_d(opcode)
        ra = zero
        rb = zero
        w = zero
        imm = bigzero
        cmpop = "000"
        form = choose_form(op_decimal)
        regs = [part.split(",")[0].replace('r', '') for part in parts[1:] if 'r' in part]
        reg_of_mem_address = [part.split(",")[0].strip("m[r]") for part in parts[1:] if 'm' in part]
        for reg in regs:
            assert reg.strip('m[]').isdigit(), f"Invalid Register: --{reg}-- on line {line_num} --> {line}"
            assert int(reg.strip('m[]')) < constraints.get('N_REG'), f'REGISTER ADDRESS EXCEEDS NUMBER OF REGISTERS'
        if op_decimal < 16 or op_decimal == 18 or (28 <= op_decimal <= 30):
            assert len(regs[-1].strip('[]')) == len(regs[-1])-2, f'{line_num}: {line}: ENCLOSE WRITE REGISTER WITH BRACKETS, e.g. [r0]'
        imm_data = [part.split(",")[0].strip("m[]#") for part in parts[1:] if "#" in part]
        if len(imm_data) > 0 and imm_data[0].startswith('b'):
            imm_data[0] = str(signed_b_to_d(imm_data[0][1:]))
        if op_decimal < 5:
            ra = d_to_b(int(regs[0]), ADDRESS_WIDTH)
            rb = d_to_b(int(regs[1]), ADDRESS_WIDTH)
            w = d_to_b(int(regs[2].strip("[]")), ADDRESS_WIDTH)
        elif op_decimal < 8:
            ra = d_to_b(int(regs[0]), ADDRESS_WIDTH)
            w = d_to_b(int(regs[1].strip("[]")), ADDRESS_WIDTH)
        elif op_decimal < 15:
            ra = d_to_b(int(regs[0]), ADDRESS_WIDTH)
            imm = d_to_b(int(imm_data[0]), WIDTH)
            w = d_to_b(int(regs[1].strip("[]")), ADDRESS_WIDTH)
        elif op_decimal == 15:
            imm = d_to_b(int(imm_data[0]), WIDTH)
            w = d_to_b(int(regs[0].strip("[]")), ADDRESS_WIDTH)
        elif op_decimal == 16:
            ra = d_to_b(int(regs[0]), ADDRESS_WIDTH)
            rb = d_to_b(int(regs[1]), ADDRESS_WIDTH)
        elif op_decimal == 17:
            ra = d_to_b(int(regs[0]), ADDRESS_WIDTH)
            imm = d_to_b(int(imm_data[0]), WIDTH)
        elif op_decimal == 18:
            cmpop = compareops.get(parts[1].strip(','))
            w = d_to_b(int(regs[0].strip("[]")), ADDRESS_WIDTH)
            next_pc = PCWIDTH*'0'
        elif op_decimal == 19:
            cmpop = compareops.get(parts[1].strip(','))
            br_label = parts[2]
            assert br_label in labels.keys(), "Label not found"
            delta = labels.get(br_label) - instruction_num
            w = w[:-1]
            next_pc = d_to_b(delta, PCWIDTH+1)
        elif op_decimal == 20:
            pc_int = labels.get(parts[1])
            w = w[:-1]
            next_pc = d_to_b(pc_int, PCWIDTH+1)
        elif op_decimal == 21:
            pass
        elif op_decimal == 26:
            ra = d_to_b(int(reg_of_mem_address[0]), ADDRESS_WIDTH)
            rb = d_to_b(int(regs[0]), ADDRESS_WIDTH)
        elif op_decimal == 27:
            rb = d_to_b(int(regs[0]), ADDRESS_WIDTH)
            imm = d_to_b(int(imm_data[0]), WIDTH)
        elif op_decimal == 28:
            ra = d_to_b(int(reg_of_mem_address[0]), ADDRESS_WIDTH)
            w = d_to_b(int(regs[1].strip("[]")), ADDRESS_WIDTH)
        elif op_decimal < 31:
            w = d_to_b(int(regs[0].strip("[]")), ADDRESS_WIDTH)
            imm = d_to_b(int(imm_data[0]), WIDTH)
        elif op_decimal == 31:
            pass
        else:
            raise SyntaxWarning
        if form == "NORMAL":
            instructions.append(f'{opcode}{ra}{rb}{w}{imm}\n')
        elif form == "CMP":
            instructions.append(f'{opcode}{ra}{rb}{zero}{imm}\n')
        elif form == "USECMP":
            instructions.append(f'{opcode}{cmpop}{zero}{w}{next_pc}\n')
        else:
            raise ValueError
        if doprint:
            end = f'move {delta + 1}\n' if op_decimal == 19 else f'goto {pc_int + 1}\n' if op_decimal == 20 else '\n'
            print(f' {line_num:<4} | {f"{instruction_num}":^4} | {line:^20} | {instructions[-1][:-1]} ', end=end)
    if tomachinecode:
        name = program_path.split('/')[-1].split('.')[0]
        with open(f'C:\\Users\\Lucas Herd\\Desktop\\cpuproject\\machine-code\\{name}.mem', 'w') as memfile:
            memfile.writelines(instructions)
        with open(f'C:\\Users\\Lucas Herd\\Desktop\\cpuproject\\machine-code\\instructions.mem', 'w') as instfile:
            instfile.writelines(instructions)
    if doprint:
        with open('instructions.mem', 'w') as instructfile:
            instructfile.writelines(instructions)
    return instructions


if __name__ == '__main__':
    assemble_program(doprint=printlines)

