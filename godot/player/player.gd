extends RefCounted

class_name Player


var id: int
var seat: int
var company_id: String
var player_type: String
var alive := true
var hand: Array[Card] = []
var rng: RandomNumberGenerator


func _init(id: int) -> void:
	self.id = id
	self.seat = id
	self.company_id = "company-%d" % id
	self.player_type = "DefaultPlayer SHOULD NOT EXIST"

func hand_value() -> int:
	return cards_value(hand)


static func cards_value(cards: Array[Card]) -> int:
	var total := 0
	for card in cards:
		total += card.value
	return total

func choose_target(players: Array[Player]) -> Player:
	var candidates: Array[Player] = players.filter(func(player: Player): return player != self)
	return null if candidates.is_empty() else candidates[rng.randi_range(0, candidates.size() - 1)]


func offer_card(_target: Player) -> Card:
	return hand[rng.randi_range(0, hand.size() - 1)]

func can_return(value: int) -> bool:
	return hand_value() >= value
	
func return_cards(offered: int, _market_stable: bool, _max_value: int) -> Array[Card]:
	return ClosestSubsetSum.closest_subset_cards(hand, offered)


func has_card_value(value: int) -> bool:
	return hand.any(func(card: Card): return card.value == value)


func first_card_with_value(value: int) -> Card:
	for card in hand:
		if card.value == value:
			return card
	return null


func remove_cards_with_value(value: int) -> void:
	for index in range(hand.size() - 1, -1, -1):
		if hand[index].value == value:
			hand.remove_at(index)

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

static func hand_to_string(cards: Array[Card]) -> String:
	var values: Array[int] = []
	for card in cards:
		values.append(card.value)
	values.sort()
	return str(values)
