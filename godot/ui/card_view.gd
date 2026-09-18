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
	self_modulate = Color("f9d976") if selected else Color.WHITE
