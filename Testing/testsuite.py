from test import Test
from time import time

class TestSuite(Test):
    def __init__(self, name: str, tests: list[Test], display_output=0, update_programs=False):
        self.tests = tests
        super().__init__(name, suite=True,displayall=display_output, update_program=update_programs)

    def run(self, top=False, depth=0):
        if top:
            print(f"-----BEGINNING {self.name}-----")
            start_time = time()
        elif self.info:
            print(f"{self.name}:")
            print("-" * (30-5*depth if depth < 4 else 15))
        passing = True
        for t in self.tests:
            if self.update_program:
                t.update_program = True
            if self.display:
                t.display = self.display
            elif self.display is None and not t.display:
                t.display = self.display
            if self.info:
                t.info = self.info
            t.run(depth=depth+1)
            self.data[t.name] = t.data
            if not t.passed:
                passing = False
        self.passed = passing

        self.data['RESULT'] = 'PASS' if self.passed else 'FAIL'
        if top:
            print(f"-----{self.name} COMPLETED-----")
            runtime = time()-start_time
            self.data['TOTAL TIME'] = f"{round(runtime * 1000, 2)}ms" if runtime < 1 else f"{round(runtime, 2)}s"
            print(f"Result: **{self.data['RESULT']}**")
            self.save()
        elif self.info:
            print(f"{self.name} {'PASSED' if self.passed else 'FAILED'}")
            print("-" * (30-5*depth if depth < 4 else 15))


