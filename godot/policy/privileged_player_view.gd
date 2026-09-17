extends PlayerView

class_name PrivilegedPlayerView


var _hands_by_player: Dictionary


func _init(player_id: int, own_hand: Array[Dictionary], snapshot: Dictionary, history: Array[Dictionary], hands_by_player: Dictionary) -> void:
	super(player_id, own_hand, snapshot, history)
	_hands_by_player = hands_by_player.duplicate(true)


func all_hands() -> Dictionary:
	return _hands_by_player.duplicate(true)
