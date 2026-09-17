extends RefCounted

class_name PlayerPolicy


var display_name := "Random"
var rng: RandomNumberGenerator


func _init(policy_name := "Random", random_source: RandomNumberGenerator = null) -> void:
	display_name = policy_name
	rng = random_source if random_source != null else RandomNumberGenerator.new()


func choose_target(view: PlayerView) -> int:
	var candidates: Array[int] = []
	for player in view.players():
		if player["alive"] and player["player_id"] != view.requester_id:
			candidates.append(player["player_id"])
	return -1 if candidates.is_empty() else candidates[rng.randi_range(0, candidates.size() - 1)]


func choose_offer_card_id(view: PlayerView, _target_id: int) -> String:
	var hand := view.own_hand()
	return "" if hand.is_empty() else hand[rng.randi_range(0, hand.size() - 1)]["id"]


func choose_repayment_card_ids(view: PlayerView, offered_value: int) -> Array[String]:
	var cards: Array[Card] = []
	for card_data in view.own_hand():
		cards.append(Card.new(card_data["id"], card_data["value"], card_data["suit"]))
	var result: Array[String] = []
	for card in ClosestSubsetSum.closest_subset_cards(cards, offered_value):
		result.append(card.id)
	return result
