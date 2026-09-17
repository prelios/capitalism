extends OptimalPlayer

## Extends OptimalPlayer, offering highest card in our hand
class_name OptiHighPlayer


func _init(random_source: RandomNumberGenerator = null) -> void:
	super("OptiHigh", random_source)


func choose_offer_card_id(view: PlayerView, _target_id: int) -> String:
	var highest: Dictionary = {}
	for card in view.own_hand():
		if highest.is_empty() or card["value"] > highest["value"]:
			highest = card
	return "" if highest.is_empty() else highest["id"]
