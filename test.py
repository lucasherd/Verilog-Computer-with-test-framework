import os
import json
import pathlib
import subprocess
import sys
import shutil
import time

decodepath = os.path.abspath("C:/Users/Lucas Herd/PycharmProjects/CPU INSTRUCTION ASSEMBLER")
if decodepath not in sys.path:
    sys.path.append(decodepath)
import assembler


class Test:
    def __init__(self, name, displayall=0, update_program=False, suite=False):
        self.name = name
        self.passed = None
        self.info = True
        self.display = self.display_mux(displayall)
        self.program_path = f"Programs/{self.name}.txt"
        self.mem_path = f"machine-code/{self.name}.mem"
        self.results = {}
        self.data = {}
        self.update_program = update_program
        if not suite:
            with open(f"expected/{self.name}.json") as f:
                self.expected = json.load(f)

    def display_mux(self, key):
        assert 0 <= key <= 3, 'display mux key out of bounds, must be 0-2'
        if key == 0:  # none
            self.info = False
            return False
        elif key == 1:  # some
            return False
        elif key == 2:  # some, all on fail
            return self.passed
        elif key == 3:  # all
            return True

    def grade(self):
        """
        Checks each output value and compares it to the expected from testname.json
        :return: None
        """

        failed_tests = {}
        for pc, data in self.expected.items():
            failed_tests[pc] = {}
            self.data[pc] = {}
            for key, val in data.items():
                if isinstance(val, str):
                    self.results[pc][key] = assembler.d_to_b(self.results[pc][key])
                self.data[pc][key] = {"expected": val, "measured": self.results[pc][key]}
                if self.expected[pc][key] != self.results[pc][key]:
                    failed_tests[pc][key] = (self.data[pc][key])

        self.passed = True
        for fails in failed_tests.values():
            if len(fails) > 0:
                self.passed = False
                break
        self.data['RESULT'] = 'PASS' if self.passed else 'FAIL'
        if self.display is None:
            self.display = not self.passed
        if self.display:
            for pc, vals in failed_tests.items():
                for addy, v in vals.items():
                    print(f"FAILED {self.name} AT {pc=}, {addy}: {v}")

    def run(self, top=False, depth=0):
        if top or self.info:
            print(f"Starting {self.name}")
        if os.getcwd().split('\\')[-1] != "cpuproject":
            os.chdir("..")
        if self.update_program:
            assembler.assemble_program(self.program_path)
        else:
            shutil.copyfile(self.mem_path, "machine-code/instructions.mem")
        os.chdir("Verilog")
        os.system("iverilog -g2012 -o Simulator/cpu.out defines.sv computer.sv  computer_tb.sv")  # compile testbench
        start_time = time.time()
        result = subprocess.run(
            ["vvp", "Simulator/cpu.out"],
            capture_output=True,
            text=True)
        runtime = time.time() - start_time
        # print(self.expected)
        results = result.stdout.split("start!")[1].split("\n")[1:-1]
        for pc in self.expected.keys():
            reg_output = {}
            ram_output = {}
            with open(f"Simulator/reg{pc}.mem", 'r') as reg_dump_file:  # decodes output values
                reg_num = 0
                for line in reg_dump_file.readlines():
                    if not line.startswith('//'):
                        reg_output[f"R{reg_num}"] = assembler.signed_b_to_d(line)
                        reg_num += 1
            with open(f"Simulator/ram{pc}.mem", 'r') as ram_dump_file:
                ram_num = 0
                for line in ram_dump_file.readlines():
                    if not line.startswith('//'):
                        ram_output[f"M{ram_num}"] = assembler.signed_b_to_d(line)
                        ram_num += 1
            self.results[pc] = reg_output | ram_output
        self.grade()
        self.data['RUNTIME'] = f"{round(runtime * 1000, 2)}ms" if runtime < 1 else f"{round(runtime, 2)}s"
        if self.display:
            for line in results:
                print(line)  # prints verilog simulaiton output
            print(self.data["RUNTIME"])
        if self.info or self.display:
            print(f"{self.name} {'PASSED' if self.passed else 'FAILED'}")
            print("-" * 10)
        if top:
            print(f"Result: {'**PASS**' if self.passed else '**FAIL**'}")
            self.save()

    def save(self):
        t = time.localtime()
        date = f"{t.tm_mon}-{t.tm_mday}-{t.tm_year}"
        cur_time = f"{t.tm_hour}-{t.tm_min}-{t.tm_sec}"
        if os.getcwd().split('\\')[-1] != "cpuproject":
            os.chdir("..")
        path = pathlib.Path(f"TDR/{date}/{cur_time}-{self.name}_{'P' if self.passed else 'F'}.json")
        path.parent.mkdir(parents=True, exist_ok=True)
        with open(path, 'w', encoding='utf-8') as f:
            json.dump(self.data, f, ensure_ascii=False, indent=4)
