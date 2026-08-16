from test import Test
from testsuite import TestSuite
from boardtest import BoardTest
from pathlib import Path


NONE = 0
SOME = 1
FAIL = 2
ALL = 3

dir_path = Path('expected')
test_names = [f.stem for f in dir_path.rglob('*.json') if f.is_file()]


board_test_list = [BoardTest(name) for name in test_names]

ALL_BOARD_TESTS = TestSuite('ALL_TESTS', board_test_list,
                      display_output=FAIL,update_programs=True)

ALL_BOARD_TESTS.run(top=True)

#baordtest1 = BoardTest('alu_add', displayall=FAIL, update_program=True)
#boardtestsuite = TestSuite('board_tests',[baordtest1],display_output=SOME,update_programs=True)
#boardtestsuite.run(top=True)
