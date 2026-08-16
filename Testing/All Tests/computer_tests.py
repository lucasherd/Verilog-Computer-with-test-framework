from test import Test
from testsuite import TestSuite
NONE = 0
SOME = 1
FAIL = 2
ALL = 3

add = Test('alu_add')
sub = Test('alu_sub')
bit = Test('alu_bitwise')
imm = Test('alu_imm')
mem = Test('mem_test')
cmp1 = Test('cmp_test1')
cmp2 = Test('cmp_test2')
cmp3 = Test('cmp_test3')
cmp_tests = TestSuite('cmp_tests',[cmp1, cmp2, cmp3])
br = Test('branch_test')
loopwhile = Test('loop_while')

alu_tests = TestSuite('alu_tests',[add, sub, bit, imm])
non_alu_tests = TestSuite('non-alu_tests', [cmp_tests,br])
integrated_tests = TestSuite('integrated_tests', [loopwhile])
TESTS = TestSuite('COMPUTER TESTS',
                  [alu_tests, non_alu_tests, integrated_tests],
                  update_programs=False,
                  display_output=FAIL)

TESTS.run(top=True)
