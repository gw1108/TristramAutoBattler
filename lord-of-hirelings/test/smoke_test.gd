# Smoke test verifying the gdUnit4 framework itself runs.
# Delete or replace this suite once real game functionality has tests.
extends GdUnitTestSuite


func test_framework_runs() -> void:
	assert_bool(true).is_true()


func test_basic_assertions() -> void:
	assert_int(1 + 1).is_equal(2)
	assert_str("gdUnit4").contains("Unit")
