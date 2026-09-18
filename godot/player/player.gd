extends RefCounted

class_name Player


var id: int
var seat: int
var company_id: String
var company_name: String
var company_emoji: String
var owned_company_ids: Array[String] = []
var acquired_by_id := -1
var alive := true
var hand: Array[Card] = []


func _init(id: int) -> void:
	self.id = id
	self.seat = id
	self.company_id = "company-%d" % id
	self.company_name = "Company %d" % id
	self.company_emoji = "🏢"
	self.owned_company_ids = [self.company_id]

func hand_value() -> int:
	return cards_value(hand)


static func cards_value(cards: Array[Card]) -> int:
	var total := 0
	for card in cards:
		total += card.value
	return total

func can_return(value: int) -> bool:
	return hand_value() >= value
	

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


func acquire_companies_from(victim: Player) -> void:
	owned_company_ids.append_array(victim.owned_company_ids)
	victim.owned_company_ids.clear()
	victim.acquired_by_id = id


func remove_companies() -> void:
	owned_company_ids.clear()


func _to_string() -> String:
	return "{id} ({alive}): {hand}".format({
		"id": id,
		"alive": alive,
		"hand": hand_to_string(hand)
	})

static func hand_to_string(cards: Array[Card]) -> String:
	var values: Array[int] = []
	for card in cards:
		values.append(card.value)
	values.sort()
	return str(values)
