extends OptimalPlayer

## Extends OptimalPlayer, offering lowest card in our hand
class_name OptiLowPlayer


func _init(random_source: RandomNumberGenerator = null) -> void:
	super("OptiLow", random_source)


func choose_offer_card_id(view: PlayerView, _target_id: int) -> String:
	var lowest: Dictionary = {}
	for card in view.own_hand():
		if lowest.is_empty() or card["value"] < lowest["value"]:
			lowest = card
	return "" if lowest.is_empty() else lowest["id"]
