extends Button

class_name PlayerSeatPanel


@onready var _identity: Label = $Margin/Content/Identity
@onready var _hand_count: Label = $Margin/Content/HandCount
@onready var _companies: Label = $Margin/Content/Companies
@onready var _state: Label = $Margin/Content/State


func set_public_player(player: Dictionary, is_local: bool, is_current: bool, is_target: bool) -> void:
	player_id = player["player_id"]
	_identity.text = "%s %s\nPlayer %d%s%s" % [player["company_emoji"], player["company_name"], player_id, " · You" if is_local else "", " · Current" if is_current else ""]
	_hand_count.text = "%d card%s" % [player["hand_size"], "" if player["hand_size"] == 1 else "s"]
	_companies.text = "%d compan%s" % [player["company_ids"].size(), "y" if player["company_ids"].size() == 1 else "ies"]
	if !player["alive"]:
		_state.text = "Acquired"
		_apply_seat_style(Color("30343b"), Color("adb2bd"), Color("454b54"))
	elif is_target:
		_state.text = "Trade target"
		_apply_seat_style(Color("6a1e28"), Color("ff6b78"), Color("8f2937"))
	elif is_current:
		_state.text = "Taking turn"
		_apply_seat_style(Color("2f86dc"), Color("a7d1ff"), Color("4a9ff2"))
	else:
		_state.text = "In market"
		_apply_seat_style(Color("212e47"), Color("617aad"), Color("2b3c5b"))


func _apply_seat_style(background: Color, border: Color, pressed_background: Color) -> void:
	self_modulate = Color.WHITE
	seat_background = background
	add_theme_stylebox_override("normal", _seat_style(background, border))
	add_theme_stylebox_override("hover", _seat_style(background.lightened(0.1), border.lightened(0.08)))
	add_theme_stylebox_override("pressed", _seat_style(pressed_background, border.lightened(0.12)))


func _seat_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	return style


func set_target_selectable(selectable: bool) -> void:
	target_selectable = selectable
	disabled = false
	focus_mode = Control.FOCUS_ALL if selectable else Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP if selectable else Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if selectable else Control.CURSOR_ARROW
	if selectable and _state.text != "Trade target":
		add_theme_stylebox_override("hover", _seat_style(Color("5a430d"), Color("f7d774")))
		add_theme_stylebox_override("pressed", _seat_style(Color("725712"), Color("f7d774")))


func is_target_selectable() -> bool:
	return target_selectable


func seat_visual_background() -> Color:
	return seat_background


func _pressed() -> void:
	if target_selectable:
		target_selected.emit(player_id)
signal target_selected(player_id: int)


var player_id := -1
var target_selectable := false
var seat_background := Color.TRANSPARENT
