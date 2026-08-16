from test import Test
from testsuite import TestSuite
from pathlib import Path


NONE = 0
SOME = 1
FAIL = 2
ALL = 3

dir_path = Path('expected')
test_names = [f.stem for f in dir_path.rglob('*.json') if f.is_file()]

test_list = [Test(name) for name in test_names]
ALL_TESTS = TestSuite('ALL_TESTS', test_list,
                      display_output=SOME,update_programs=True)

ALL_TESTS.run(top=True)



