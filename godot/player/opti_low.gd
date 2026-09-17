extends OptimalPlayer

## Extends OptimalPlayer, offering lowest card in our hand
class_name OptiLowPlayer


func _init(id):
	super(id)
	self.player_type = "OptiLow"


# Offer lowest card that's in our hand, but not in target's hand
func offer_card(target: Player) -> Card:
	var candidates: Array[Card] = []
	for card in hand:
		if !target.has_card_value(card.value):
			candidates.append(card)
	if candidates.is_empty():
		candidates = hand
	var lowest := candidates[0]
	for card in candidates:
		if card.value < lowest.value:
			lowest = card
	return lowest
