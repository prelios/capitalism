extends Panel


func _on_game_started(players: Array[Player], policies: Dictionary[int, PlayerPolicy]) -> void:
	print("Starting game with %d players:" % players.size())
	for player in players:
		var personality := "Human" if !policies.has(player.id) else policies[player.id].display_name
		print("  Player %d: %s" % [player.id, personality])


func _on_turn_started(turn: int, current_player: Player) -> void:
	print("---------\nTurn %d started with Player %d" % [turn, current_player.id])


func _on_turn_matchup(current_player: Player, target: Player, current_policy: String, target_policy: String) -> void:
	if !OS.is_debug_build():
		return
	print("Current Player %d (%s) hand: %s" % [current_player.id, current_policy, current_player.hand_to_string(current_player.hand)])
	print("Target Player %d (%s) hand: %s" % [target.id, target_policy, target.hand_to_string(target.hand)])


func _on_trade_proposed(_from: Player, _to: Player, _card: Card) -> void:
	return
#	print("Trade proposed from {from} to {to}: {card}".format({
#		"from": from.id,
#		"to": to.id,
#		"card": card
#	}))


func _on_trade_resolved(from: Player, to: Player, offered: Card, received: Array[Card]) -> void:
	print("Trade resolved between {from} <-> {to}: {offered} <-> {returned}".format({
		"from": from.id,
		"to": to.id,
		"offered": offered.value,
		"returned": Player.hand_to_string(received)
	}))


func _on_player_eliminated(p: Player) -> void:
	print("Player %d has been eliminated!" % p.id)


func _on_market_unstable(turns_remaining: int) -> void:
	print("Market unstable - %d turns remaining" % turns_remaining)

func _on_market_value_destruction(val: int) -> void:
	print("Value %d is being destroyed!" % val)

func _on_possible_equilibrium_detected() -> void:
	print("Possible equilibrium detected")

func _on_possible_equilibrium_broken() -> void:
	print("Possible equilibrium broken")


func _on_game_over(ending: String, winners: Array[Player]) -> void:
	print("Game has ended in: ", ending)
	print("Winner(s): ", str(winners))
