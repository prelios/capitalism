extends OptimalPlayer

## Extends OptimalPlayer, offering random card in our hand
class_name OptiRandPlayer


func _init(random_source: RandomNumberGenerator = null) -> void:
	super("OptiRand", random_source)


func choose_offer_card_id(view: PlayerView, target_id: int) -> String:
	return super.choose_offer_card_id(view, target_id)
