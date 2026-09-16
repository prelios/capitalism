extends Node

class_name Player


var id: int
var player_type: String
var alive := true
var hand: Array[int] = []


func _init(id):
	self.id = id
	self.player_type = "DefaultPlayer SHOULD NOT EXIST"

func hand_value() -> int:
	return ArrayUtils.sum_array(hand)

func choose_target(players: Array[Player]) -> Player:
	# Default functionality picks random player from list
	return ArrayUtils.pick_random_excluding_value(players, self)
	#return ArrayUtils.pick_random_excluding_filter(players, func(p): return p != self && p.alive)


func offer_card(target: Player) -> int:
	# Default functionality picks random card and ignores target
	return hand.pick_random()

func can_return(value: int) -> bool:
	return ArrayUtils.sum_array(hand) >= value
	
func return_cards(offered: int, market_stable: bool, max_value: int) -> Array[int]:
	return ClosestSubsetSum.closest_subset_sum(self.hand, offered)

func die() -> void:
	self.hand.clear()
	self.alive = false


func _to_string() -> String:
	return "{id} - {player_type} ({alive}): {hand}".format({
		"id": id,
		"player_type": player_type,
		"alive": alive,
		"hand": hand_to_string(hand)
	})

func hand_to_string(hand: Array[int]) -> String:
	var dup = hand.duplicate()
	dup.sort()
	return str(dup)
