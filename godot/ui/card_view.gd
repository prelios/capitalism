extends Button

class_name CardView


signal card_selection_changed(card_id: String, selected: bool)


var card_id := ""
var _is_endangered := false
var _is_selected := false
var _background := Color.TRANSPARENT


func _ready() -> void:
	toggled.connect(_on_toggled)


func set_card(card: Dictionary, endangered := false) -> void:
	card_id = card["id"]
	_is_endangered = endangered
	text = "%s%d\n%s" % ["⚠ " if _is_endangered else "", card["value"], card["suit"]]
	tooltip_text = "%s%s %d" % ["Market danger — this card will be removed in the pending crash: " if _is_endangered else "", card["suit"], card["value"]]
	_refresh_style()


func set_selected(selected: bool) -> void:
	button_pressed = selected
	_is_selected = selected
	_refresh_style()


func _on_toggled(selected: bool) -> void:
	_is_selected = selected
	_refresh_style()
	card_selection_changed.emit(card_id, selected)


func is_endangered() -> bool:
	return _is_endangered


func card_background() -> Color:
	return _background


func _refresh_style() -> void:
	self_modulate = Color.WHITE
	if !_is_endangered and !_is_selected:
		remove_theme_stylebox_override("normal")
		remove_theme_stylebox_override("hover")
		remove_theme_stylebox_override("pressed")
		_background = Color.TRANSPARENT
		return
	var background := Color("5c2609") if _is_endangered else Color("5a430d")
	var border := Color("f7d774") if _is_selected else Color("ff8a2a")
	if !_is_endangered:
		border = Color("f7d774")
	_background = background
	add_theme_stylebox_override("normal", _card_style(background, border))
	add_theme_stylebox_override("hover", _card_style(background.lightened(0.12), border.lightened(0.1)))
	add_theme_stylebox_override("pressed", _card_style(background.lightened(0.2), border.lightened(0.16)))


func _card_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style
