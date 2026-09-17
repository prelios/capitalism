extends RefCounted

class_name PendingTrade


var actor_id: int
var target_id: int
var offered_card: Card


func _init(actor_id_value: int, target_id_value: int, card: Card) -> void:
	actor_id = actor_id_value
	target_id = target_id_value
	offered_card = card
