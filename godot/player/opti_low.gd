extends OptimalPlayer

## Extends OptimalPlayer, offering lowest card in our hand
class_name OptiLowPlayer


func _init(id):
	super(id)
	self.player_type = "OptiLow"


# Offer lowest card that's in our hand, but not in target's hand
func offer_card(target: Player) -> int:
	var sorted_hand = ArrayUtils.distinct(self.hand)
	sorted_hand.sort()
	var different_cards = sorted_hand.duplicate()
	
	for c in target.hand:
		different_cards = ArrayUtils.copy_erase(different_cards, c)
	
	# If there are no different cards, just offer lowest in our hand
	if different_cards.is_empty():
		return sorted_hand.pop_front()
	# Otherwise, return lowest card among the different ones
	else:
		return different_cards.pop_front()
