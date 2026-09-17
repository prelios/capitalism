extends OptimalPlayer

## Extends OptimalPlayer, offering random card in our hand
class_name OptiRandPlayer


func _init(id):
	super(id)
	self.player_type = "OptiRand"


# Offer random card that's in our hand, but not in target's hand
func offer_card(target: Player) -> Card:
	var candidates: Array[Card] = []
	for card in hand:
		if !target.has_card_value(card.value):
			candidates.append(card)
	if candidates.is_empty():
		candidates = hand
	return candidates[rng.randi_range(0, candidates.size() - 1)]
