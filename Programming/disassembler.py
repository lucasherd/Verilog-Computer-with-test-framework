from assembler import *
import tkinter
from tkinter import filedialog


op_names = {op: name for name, op in opcodes.items()}
compare_names = {cmpop: name for name, cmpop in compareops.items()}
def map_bits():
    ra = [5,5+ADDRESS_WIDTH]
    rb = [5+ADDRESS_WIDTH,5+2*ADDRESS_WIDTH]
    rw = [5+2*ADDRESS_WIDTH,5+3*ADDRESS_WIDTH]
    imm = [-WIDTH]
    cmpop = [5,8]
    return ra, rb, rw, imm, cmpop

def disassemble_program(instructions_path=None, instructions=None,doprint=False):

    if instructions_path is None and instructions is None:
        root = tkinter.Tk(baseName='CPU ASSEMBLER')
        instructions_path = filedialog.askopenfilename(
            title="Select a File",
            initialdir="C:\\Users\\Lucas Herd\\Desktop\\cpuproject\\machine-code",
            filetypes=[("binary memory Files", "*.mem"), ("Text Files", "*.txt*")]
        )
    program = []
    labelnum = 0
    label_lines = []
    i_num = -1
    line = ''
    label_line_num = 0
    zero = '0'*ADDRESS_WIDTH
    cmpname = None
    _ra, _rb, _rw, _imm, _cmpop = map_bits()
    if instructions is None:
        with open(instructions_path, 'r') as file:
            instructions = file.readlines()
    for i in instructions:
        i = i.strip('\n')
        i_num += 1
        opcode = i[0:5]
        op = b_to_d(opcode)
        form = choose_form(op)
        ra = b_to_d(i[_ra[0]:_ra[1]])
        rb = b_to_d(i[_rb[0]:_rb[1]])
        rw = b_to_d(i[_rw[0]:_rw[1]])
        imm = signed_b_to_d(i[-WIDTH:])
        if form == 'USECMP':
            cmpop = i[_cmpop[0]:_cmpop[1]]
            cmpname = compare_names[cmpop]

        cmd = op_names[opcode]
        #print(f'{ra=}, {rb=}, {rw=}, {imm=}, {cmpname=}')
        if op < 5:
            line = f'{cmd} r{ra}, r{rb}, [r{rw}]'
        elif op < 8:
            line = f'{cmd} r{ra}, [r{rw}]'
        elif op < 15:
            line = f'{cmd} r{ra}, #{imm}, [r{rw}]'
        elif op == 15:
            line = f'{cmd} #{imm}, [r{rw}]'
        elif op == 16:
            line = f'{cmd} r{ra}, r{rb}'
        elif op == 17:
            line = f'{cmd} r{ra}, #{imm}'
        elif op == 18:
            line = f'{cmd} {cmpname}, [r{rw}]'
        elif op == 19:
            label = i_num+imm+1
            #print(f'{imm=}, {label=}')
            if label not in label_lines:
                label_lines.append(label)
            line = f'{cmd} {cmpname}, label{label}'
        elif op == 20:
            label = imm+1
            if label not in label_lines:
                label_lines.append(label)
            line = f'{cmd} label{label}'
        elif op == 21:
            line = cmd
        elif op == 26:
            line = f'{cmd} r{rb}, m[r{ra}]'
        elif op == 27:
            line = f'{cmd} r{rb}, m[#{imm}]'
        elif op == 28:
            line = f'{cmd} m[r{ra}], [r{rw}]'
        elif op == 29:
            line = f'{cmd} m[#{imm}], [r{rw}]'
        elif op == 30:
            line = f'{cmd} #{imm}, [r{rw}]'
        elif op == 31:
            line = cmd
        else:
            raise SyntaxWarning
        line = line + '\n'
        program.append(line)
    label_lines.sort()
    for lbl in label_lines:
        program.insert(lbl+labelnum, f'label{lbl}:\n')
        labelnum += 1
    if doprint:
        for line in program:
            print(line, end='')
    return program

if __name__ == '__main__':
    p = disassemble_program(doprint=True)
    with open('recovered program.txt', 'w') as file:
        file.writelines(p)







