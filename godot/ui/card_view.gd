extends Button

class_name CardView


signal card_selection_changed(card_id: String, selected: bool)


var card_id := ""


func _ready() -> void:
	toggled.connect(_on_toggled)


func set_card(card: Dictionary) -> void:
	card_id = card["id"]
	text = "%d\n%s" % [card["value"], card["suit"]]
	tooltip_text = "%s %d" % [card["suit"], card["value"]]


func set_selected(selected: bool) -> void:
	button_pressed = selected
	_apply_selection_style(selected)


func _on_toggled(selected: bool) -> void:
	_apply_selection_style(selected)
	card_selection_changed.emit(card_id, selected)


func _apply_selection_style(selected: bool) -> void:
	self_modulate = Color.WHITE
	if !selected:
		remove_theme_stylebox_override("normal")
		remove_theme_stylebox_override("hover")
		remove_theme_stylebox_override("pressed")
		return
	add_theme_stylebox_override("normal", _selection_style(Color("5a430d"), Color("f7d774")))
	add_theme_stylebox_override("hover", _selection_style(Color("725712"), Color("ffe39a")))
	add_theme_stylebox_override("pressed", _selection_style(Color("8a6816"), Color("ffe39a")))


func _selection_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style
