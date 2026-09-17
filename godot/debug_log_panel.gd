extends Panel


func _on_game_started(players: Array[Player]) -> void:
	print("Starting game with %d players:" % players.size())
	for player in players:
		print("  Player %d: %s" % [player.id, player.player_type])


func _on_turn_started(turn: int, current_player: Player) -> void:
	print("---------\nTurn %d started with Player %d (%s)" % [turn, current_player.id, current_player.player_type])


func _on_turn_matchup(current_player: Player, target: Player) -> void:
	if !OS.is_debug_build():
		return
	print("Current Player %d (%s) hand: %s" % [current_player.id, current_player.player_type, current_player.hand_to_string(current_player.hand)])
	print("Target Player %d (%s) hand: %s" % [target.id, target.player_type, target.hand_to_string(target.hand)])


func _on_trade_proposed(from: Player, to: Player, card: int) -> void:
	return
#	print("Trade proposed from {from} to {to}: {card}".format({
#		"from": from.id,
#		"to": to.id,
#		"card": card
#	}))


func _on_trade_resolved(from: Player, to: Player, offered: int, received: Array[int]) -> void:
	print("Trade resolved between {from} <-> {to}: {offered} <-> {returned}".format({
		"from": from.id,
		"to": to.id,
		"offered": offered,
		"returned": received
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
