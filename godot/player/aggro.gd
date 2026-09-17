extends PlayerPolicy

class_name AggroPlayer


func _init(random_source: RandomNumberGenerator = null) -> void:
	super("Aggro", random_source)


func choose_target(view: PlayerView) -> int:
	var weakest: Dictionary = {}
	for player in view.players():
		if !player["alive"] or player["player_id"] == view.requester_id:
			continue
		if weakest.is_empty() or player["hand_size"] < weakest["hand_size"]:
			weakest = player
	return super.choose_target(view) if weakest.is_empty() else weakest["player_id"]


# Offer highest card that's in our hand, always
func choose_offer_card_id(view: PlayerView, _target_id: int) -> String:
	var highest: Dictionary = {}
	for card in view.own_hand():
		if highest.is_empty() or card["value"] > highest["value"]:
			highest = card
	return "" if highest.is_empty() else highest["id"]


func choose_repayment_card_ids(view: PlayerView, offered_value: int) -> Array[String]:
	if !view.market_is_stable():
		for card in view.own_hand():
			if card["value"] == view.max_value():
				return [card["id"]]
	return super.choose_repayment_card_ids(view, offered_value)
