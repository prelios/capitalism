extends Button

class_name PlayerSeatPanel


@onready var _identity: Label = $Margin/Content/Identity
@onready var _hand_count: Label = $Margin/Content/HandCount
@onready var _companies: Label = $Margin/Content/Companies
@onready var _state: Label = $Margin/Content/State


func set_public_player(player: Dictionary, is_local: bool, is_current: bool, is_target: bool) -> void:
	player_id = player["player_id"]
	_identity.text = "Player %d%s" % [player_id, " · You" if is_local else ""]
	_hand_count.text = "%d card%s" % [player["hand_size"], "" if player["hand_size"] == 1 else "s"]
	_companies.text = "%d compan%s" % [player["company_ids"].size(), "y" if player["company_ids"].size() == 1 else "ies"]
	if !player["alive"]:
		_state.text = "Acquired"
		self_modulate = Color("8b93a4")
	elif is_target:
		_state.text = "Trade target"
		self_modulate = Color("f7d774")
	elif is_current:
		_state.text = "Taking turn"
		self_modulate = Color("78b7ff")
	else:
		_state.text = "In market"
		self_modulate = Color.WHITE


func set_target_selectable(selectable: bool) -> void:
	target_selectable = selectable
	disabled = false
	focus_mode = Control.FOCUS_ALL if selectable else Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP if selectable else Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if selectable else Control.CURSOR_ARROW


func is_target_selectable() -> bool:
	return target_selectable


func _pressed() -> void:
	if target_selectable:
		target_selected.emit(player_id)
signal target_selected(player_id: int)


var player_id := -1
var target_selectable := false
