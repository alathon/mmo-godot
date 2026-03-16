extends VestTest

func get_suite_name() -> String:
	return "HistoryBuffer"

# --- Initialization ---

func test_starts_empty():
	var buf := _HistoryBuffer.new()
	expect_true(buf.is_empty())
	expect_equal(buf.size(), 0)

func test_default_capacity():
	var buf := _HistoryBuffer.new()
	expect_equal(buf.capacity(), 64)

func test_custom_capacity():
	var buf := _HistoryBuffer.new(16)
	expect_equal(buf.capacity(), 16)

# --- push / pop ---

func test_push_increases_size():
	var buf := _HistoryBuffer.new()
	buf.push("a")
	expect_equal(buf.size(), 1)
	buf.push("b")
	expect_equal(buf.size(), 2)

func test_pop_returns_oldest():
	var buf := _HistoryBuffer.new()
	buf.push("first")
	buf.push("second")
	expect_equal(buf.pop(), "first")

func test_pop_decreases_size():
	var buf := _HistoryBuffer.new()
	buf.push(1)
	buf.push(2)
	buf.pop()
	expect_equal(buf.size(), 1)

func test_push_beyond_capacity_evicts_oldest():
	var buf := _HistoryBuffer.new(4)
	for i in range(5):
		buf.push(i)
	expect_equal(buf.size(), 4)
	expect_equal(buf.pop(), 1)  # 0 was evicted

# --- set_at / has_at / get_at ---

func test_set_at_on_empty_buffer():
	var buf := _HistoryBuffer.new()
	buf.set_at(10, "hello")
	expect_true(buf.has_at(10))
	expect_equal(buf.get_at(10), "hello")

func test_set_at_sequential():
	var buf := _HistoryBuffer.new()
	buf.set_at(0, "zero")
	buf.set_at(1, "one")
	buf.set_at(2, "two")
	expect_equal(buf.get_at(0), "zero")
	expect_equal(buf.get_at(1), "one")
	expect_equal(buf.get_at(2), "two")

func test_set_at_overwrites_existing():
	var buf := _HistoryBuffer.new()
	buf.set_at(5, "original")
	buf.set_at(5, "overwritten")
	expect_equal(buf.get_at(5), "overwritten")

func test_has_at_returns_false_for_missing():
	var buf := _HistoryBuffer.new()
	buf.set_at(0, "zero")
	expect_false(buf.has_at(1))

func test_get_at_returns_default_when_missing():
	var buf := _HistoryBuffer.new()
	buf.set_at(0, "zero")
	expect_null(buf.get_at(99))

func test_get_at_returns_custom_default():
	var buf := _HistoryBuffer.new()
	buf.set_at(0, "zero")
	expect_equal(buf.get_at(99, "fallback"), "fallback")

func test_set_at_gap_skips_forward():
	var buf := _HistoryBuffer.new()
	buf.set_at(0, "zero")
	buf.set_at(5, "five")
	expect_true(buf.has_at(5))
	expect_false(buf.has_at(1))
	expect_false(buf.has_at(3))

func test_set_at_too_old_ignored():
	# Writing something so old it would wrap around and overwrite live data
	var buf := _HistoryBuffer.new(4)
	for i in range(4):
		buf.set_at(i, i)
	# Tick 0 is now outside the window (capacity is 4, head is at 4)
	buf.set_at(0, "stale")
	# Should not change anything for the ticks still in range
	expect_equal(buf.get_at(1), 1)

func test_set_at_far_future_clears_buffer():
	var buf := _HistoryBuffer.new(4)
	buf.set_at(0, "zero")
	buf.set_at(1, "one")
	# Jump way beyond capacity
	buf.set_at(100, "future")
	expect_true(buf.has_at(100))
	expect_false(buf.has_at(0))
	expect_false(buf.has_at(1))

# --- get_latest_index / get_earliest_index ---

func test_get_latest_index():
	var buf := _HistoryBuffer.new()
	buf.set_at(3, "three")
	buf.set_at(4, "four")
	expect_equal(buf.get_latest_index(), 4)

func test_get_earliest_index():
	var buf := _HistoryBuffer.new()
	buf.set_at(3, "three")
	buf.set_at(4, "four")
	expect_equal(buf.get_earliest_index(), 3)

# --- has_latest_at / get_latest_index_at / get_latest_at ---

func test_has_latest_at_true_for_exact_tick():
	var buf := _HistoryBuffer.new()
	buf.set_at(5, "five")
	expect_true(buf.has_latest_at(5))

func test_has_latest_at_true_for_future_tick():
	var buf := _HistoryBuffer.new()
	buf.set_at(5, "five")
	expect_true(buf.has_latest_at(10))

func test_has_latest_at_false_before_earliest():
	var buf := _HistoryBuffer.new()
	buf.set_at(5, "five")
	expect_false(buf.has_latest_at(4))

func test_get_latest_at_returns_value_at_tick():
	var buf := _HistoryBuffer.new()
	buf.set_at(5, "five")
	expect_equal(buf.get_latest_at(5), "five")

func test_get_latest_at_returns_previous_when_gap():
	var buf := _HistoryBuffer.new()
	buf.set_at(5, "five")
	buf.set_at(8, "eight")
	# Tick 6 has no direct entry; latest should be 5
	expect_equal(buf.get_latest_index_at(6), 5)
	expect_equal(buf.get_latest_at(6), "five")

func test_get_latest_index_at_returns_minus_one_before_tail():
	var buf := _HistoryBuffer.new()
	buf.set_at(5, "five")
	expect_equal(buf.get_latest_index_at(4), -1)

# --- clear ---

func test_clear_makes_empty():
	var buf := _HistoryBuffer.new()
	buf.push("a")
	buf.push("b")
	buf.clear()
	expect_true(buf.is_empty())
	expect_equal(buf.size(), 0)

# --- duplicate ---

func test_duplicate_is_independent():
	var buf := _HistoryBuffer.new()
	buf.set_at(0, "original")
	var copy := buf.duplicate()
	copy.set_at(0, "mutated")
	expect_equal(buf.get_at(0), "original")
	expect_equal(copy.get_at(0), "mutated")

func test_duplicate_preserves_data():
	var buf := _HistoryBuffer.new()
	buf.set_at(2, "two")
	buf.set_at(3, "three")
	var copy := buf.duplicate()
	expect_equal(copy.get_at(2), "two")
	expect_equal(copy.get_at(3), "three")

func test_duplicate_preserves_capacity():
	var buf := _HistoryBuffer.new(8)
	var copy := buf.duplicate()
	expect_equal(copy.capacity(), 8)

# --- of() static constructor ---

func test_of_creates_buffer_from_dict():
	var buf := _HistoryBuffer.of(64, { 0: "a", 1: "b", 2: "c" })
	expect_equal(buf.get_at(0), "a")
	expect_equal(buf.get_at(1), "b")
	expect_equal(buf.get_at(2), "c")

# --- Ring buffer wrap-around ---

func test_ring_buffer_wrap_around():
	var buf := _HistoryBuffer.new(4)
	for i in range(8):
		buf.set_at(i, i * 10)
	# Only last 4 ticks should be accessible
	expect_false(buf.has_at(3))
	expect_true(buf.has_at(4))
	expect_equal(buf.get_at(7), 70)
