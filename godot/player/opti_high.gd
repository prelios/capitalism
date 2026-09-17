extends OptimalPlayer

## Extends OptimalPlayer, offering highest card in our hand
class_name OptiHighPlayer


func _init(id):
	super(id)
	self.player_type = "OptiHigh"


# Offer highest card that's in our hand, but not in target's hand
func offer_card(target: Player) -> Card:
	var candidates := cards_missing_from(target)
	if candidates.is_empty():
		candidates = hand
	return highest_card(candidates)


func highest_card(cards: Array[Card]) -> Card:
	var highest := cards[0]
	for card in cards:
		if card.value > highest.value:
			highest = card
	return highest


func cards_missing_from(target: Player) -> Array[Card]:
	var candidates: Array[Card] = []
	for card in hand:
		if !target.has_card_value(card.value):
			candidates.append(card)
	return candidates
