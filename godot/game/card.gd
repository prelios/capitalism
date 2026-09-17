extends RefCounted

class_name Card


const SUITS: Array[String] = ["Money", "Workers", "Tech", "Hype"]


var id: String
var value: int
var suit: String


func _init(card_id: String, card_value: int, card_suit: String) -> void:
	id = card_id
	value = card_value
	suit = card_suit


func _to_string() -> String:
	return "%s %d (%s)" % [id, value, suit]
