extends Node

class_name ArrayUtils

static func pick_random_excluding_value(array: Array, excluded) -> Variant:
	var filtered = array.filter(func(v): return v != excluded)
	return null if filtered.is_empty() else filtered.pick_random()

static func pick_random_excluding_filter(array: Array, excl_func) -> Variant:
	var filtered = array.filter(excl_func)
	return null if filtered.is_empty() else filtered.pick_random()

static func sum_array(array: Array[int]) -> int:
	return array.reduce(func(accum, number): return accum + number, 0)

static func erase_multiple(array: Array, val) -> void:
	var i = array.size() - 1
	while i >= 0:
		if array[i] == val:
			array.remove_at(i)
		i -= 1

static func copy_erase(arr: Array, val) -> Array:
	var new_arr = arr.duplicate()
	new_arr.erase(val)
	return new_arr

static func copy_append(arr: Array, val) -> Array:
	var new_arr = arr.duplicate()
	new_arr.append(val)
	return new_arr

static func distinct(array: Array) -> Array:
	var unique: Array = []
	array.sort()
	for item in array:
		if not unique.has(item):
			unique.append(item)
	return unique

static func contains_all(array: Array, values: Array) -> bool:
	for val in values:
		if !array.has(val):
			return false
	
	return true
