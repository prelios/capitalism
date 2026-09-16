extends RefCounted

class_name ClosestSubsetSum

const max_int := 2147483647

# Returns an array of indices into `values`
# whose sum is >= target and minimal
# Returns [] if no subset is possible
static func closest_subset_sum(values, target):
	return closest_subset_sum_acc(values, target, 0, [], [])

# Closest subset sum function with accumulator
# Does all the work, but is complex to use (which is why we use the higher defined one)
static func closest_subset_sum_acc(values: Array[int], target: int, 
								   acc_sum: int, acc_return: Array[int], 
								   best_return: Array[int]) -> Array[int]:
	# Calculate sum of best_return, or use max int value as starter
	var best_sum := max_int if best_return.is_empty() else ArrayUtils.sum_array(best_return)
	
	# Short circuit: empty values array means we don't have enough to return
	# In this case, return empty array
	if values.is_empty():
		return []
	
	# Make internal copy to avoid altering input, and sort it for ease of use
	var _values = values.duplicate()
	_values.sort()
	
	# Loop over possible values to remove, and recurse as needed
	for val in _values:
		var new_sum = acc_sum + val
		var new_return = ArrayUtils.copy_append(acc_return, val)
		
		# If we've reached the target, we can return whatever best result we have so far
		if new_sum >= target:
			if new_sum < best_sum:
				best_sum = new_sum
				best_return = new_return
			return best_return
		# Otherwise, we have to go deeper
		else:
			var new_values = ArrayUtils.copy_erase(_values, val)
			var best_sub = closest_subset_sum_acc(new_values, target, new_sum, new_return, best_return)
			# Check if sub-result might improve our best
			var best_sub_sum = ArrayUtils.sum_array(best_sub)
			if best_sub_sum < best_sum:
				best_sum = best_sub_sum
				best_return = best_sub
	
	return best_return
