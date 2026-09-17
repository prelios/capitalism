extends Player

## An OptimalPlayer has full knowledge of other players' hands.
## It will attempt to play optimally (and avoid wasteful moves if possible).
class_name OptimalPlayer


func _init(id):
	super(id)
	self.player_type = "Optimal"


# Choose weakest player based on total card value, excluding exact-match mirrors
func choose_target(players: Array[Player]):
	var weakest: Player = null
	
	for p in players:
		# Don't attack ourselves
		if p == self:
			continue
		
		# If our entire hand is contained in the target hand, they should be skipped (can always match-return)
		if has_all_card_values(p):
			continue
		
		# Weakest player is chosen based on total card value
		if weakest == null || p.hand_value() < weakest.hand_value():
			weakest = p
	
	
	if weakest != null:
		return weakest
	else:
		# It's possible that weakest player is null if there was no weakest player that would be a "good" target.
		# We still need a target, so defer to super.
		return super.choose_target(players)


func return_cards(offered: int, market_stable: bool, max_value: int) -> Array[Card]:
	# If market is unstable and we have a max_value card (which will disappear),
	# always return that card regardless of target value (we'll lose it anyway).
	if !market_stable && has_card_value(max_value):
		return [first_card_with_value(max_value)]
	
	# In other cases, defer to super
	return super.return_cards(offered, market_stable, max_value)


func has_all_card_values(target: Player) -> bool:
	for card in hand:
		if !target.has_card_value(card.value):
			return false
	return true
