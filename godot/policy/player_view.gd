extends RefCounted

class_name PlayerView


var requester_id: int
var _own_hand: Array[Dictionary]
var _snapshot: Dictionary
var _history: Array[Dictionary]


func _init(player_id: int, own_hand: Array[Dictionary], snapshot: Dictionary, history: Array[Dictionary]) -> void:
	requester_id = player_id
	_own_hand = own_hand.duplicate(true)
	_snapshot = snapshot.duplicate(true)
	_history = history.duplicate(true)


func own_hand() -> Array[Dictionary]:
	return _own_hand.duplicate(true)


func public_state() -> Dictionary:
	return _snapshot.duplicate(true)


func public_history() -> Array[Dictionary]:
	return _history.duplicate(true)


func players() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for player: Dictionary in _snapshot["players"]:
		result.append(player.duplicate(true))
	return result


func market_is_stable() -> bool:
	return _snapshot["market_stable"]


func max_value() -> int:
	return _snapshot["max_value"]
