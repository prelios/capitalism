extends Player

class_name AggroPlayer


func _init(id):
	super(id)
	self.player_type = "Aggro"


func choose_target(players: Array[Player]) -> Player:
	# Choose weakest player based on number of cards (least cards is weakest)
	var weakest: Player = null
	for p in players:
		# Don't attack ourselves
		if p == self:
			continue
		
		# Weakest player is chosen based on total card count
		if weakest == null || p.hand.size() < weakest.hand.size():
			weakest = p
	
	
	if weakest != null:
		return weakest
	else:
		# It's possible that weakest player is null if there was no weakest player that would be a "good" target.
		# We still need a target, so defer to super.
		return super.choose_target(players)


# Offer highest card that's in our hand, always
func offer_card(_target: Player) -> int:
	var sorted_hand = ArrayUtils.distinct(self.hand)
	sorted_hand.sort()
	return sorted_hand.pop_back()


func return_cards(offered: int, market_stable: bool, max_value: int) -> Array[int]:
	# If market is unstable and we have a max_value card (which will disappear),
	# always return that card regardless of target value (we'll lose it anyway).
	if !market_stable && self.hand.has(max_value):
		return [max_value]
	
	# In other cases, defer to super
	return super.return_cards(offered, market_stable, max_value)
