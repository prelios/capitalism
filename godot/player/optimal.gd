extends PlayerPolicy

## Development-only policy. It requires privileged state and is never assigned by GameController.
class_name OptimalPlayer


func _init(policy_name := "Optimal", random_source: RandomNumberGenerator = null) -> void:
	super(policy_name, random_source)


func choose_target(view: PlayerView) -> int:
	if !(view is PrivilegedPlayerView):
		return -1
	var hands := (view as PrivilegedPlayerView).all_hands()
	var weakest_id := -1
	var weakest_value := 0
	for player in view.players():
		var player_id: int = player["player_id"]
		if !player["alive"] or player_id == view.requester_id:
			continue
		var total := 0
		for card in hands[player_id]:
			total += card["value"]
		if weakest_id == -1 or total < weakest_value:
			weakest_id = player_id
			weakest_value = total
	return weakest_id


func choose_repayment_card_ids(view: PlayerView, offered_value: int) -> Array[String]:
	if !view.market_is_stable():
		for card in view.own_hand():
			if card["value"] == view.max_value():
				return [card["id"]]
	return super.choose_repayment_card_ids(view, offered_value)
