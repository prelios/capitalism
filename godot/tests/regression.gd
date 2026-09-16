extends SceneTree


var failures: Array[String] = []


func _init() -> void:
	test_non_mutating_helpers_and_instability_repayment()
	test_monopoly_precedes_pending_crash()
	test_unstable_acquisition_resolves_one_crash()
	test_simultaneous_bankruptcy_ends_in_meltdown()
	test_stable_two_player_duopoly()
	test_fixed_seat_turn_traversal()
	for player_count in [4, 6, 10]:
		run_seeded_smoke(player_count, 1000 + player_count)
	if failures.is_empty():
		print("Regression checks passed: 6 deterministic scenarios; smoke seeds 1004, 1006, 1010.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func expect(condition: bool, message: String) -> void:
	if !condition:
		failures.append(message)


func test_non_mutating_helpers_and_instability_repayment() -> void:
	var hand: Array[int] = [4, 1, 4]
	var original_hand := hand.duplicate()
	var unique := ArrayUtils.distinct(hand)
	expect(hand == original_hand, "distinct() changed its input hand")
	expect(unique == [4, 1], "distinct() did not preserve first-seen order")
	var bots: Array[Player] = [AggroPlayer.new(1), ScaredPlayer.new(1), OptimalPlayer.new(1)]
	for bot in bots:
		bot.hand = [1, 4]
		expect(bot.return_cards(1, true, 4) == [1], "%s discarded during a stable market" % bot.player_type)
		expect(bot.return_cards(1, false, 4) == [4], "%s did not discard during an unstable market" % bot.player_type)
		expect(bot.hand == [1, 4], "%s repayment selection mutated its hand" % bot.player_type)


func test_monopoly_precedes_pending_crash() -> void:
	var game := GameModel.new(2)
	var acquirer := game.players[0]
	var target := game.players[1]
	acquirer.hand = [4]
	target.hand = [1]
	game.max_value = 4
	game.current_player = acquirer
	game.market_stable = false
	game.resolve_trade(acquirer, target, 4)
	expect(game.game_finished, "last-opponent acquisition did not finish the game")
	expect(game.market_stable == false and game.max_value == 4, "pending crash ran before monopoly")
	expect(acquirer.hand.has(4), "monopoly acquirer lost cards to a pending crash")


func test_unstable_acquisition_resolves_one_crash() -> void:
	var game := GameModel.new(3)
	var acquirer := game.players[0]
	var target := game.players[1]
	var survivor := game.players[2]
	acquirer.hand = [3]
	target.hand = [1]
	survivor.hand = [2]
	game.max_value = 3
	game.current_player = acquirer
	game.market_stable = false
	game.resolve_trade(acquirer, target, 3)
	expect(!target.alive, "failed target was not acquired")
	expect(game.market_stable and game.max_value == 2, "unstable acquisition did not resolve exactly one crash")
	expect(!acquirer.hand.has(3), "crash did not remove the pending value from the acquirer")
	expect(!game.game_finished, "non-final unstable acquisition ended the game")


func test_simultaneous_bankruptcy_ends_in_meltdown() -> void:
	var game := GameModel.new(3)
	var endings: Array[String] = []
	game.game_over.connect(func(ending: String, _winners: Array[Player]) -> void: endings.append(ending))
	for player in game.players:
		player.hand = [3]
	game.max_value = 3
	game.market_stable = false
	game.destroy_value()
	expect(game.game_finished, "all-player crash did not finish the game")
	expect(game.alive_players().is_empty(), "all-player crash left a survivor")
	expect(endings == ["Global Economic Meltdown"], "meltdown ending was missing or duplicated")
	var turns_before := game.turn_counter
	game.start_next_turn()
	game.finalize_turn()
	game.end_turn()
	expect(game.turn_counter == turns_before, "terminal match advanced after meltdown")


func test_stable_two_player_duopoly() -> void:
	var game := GameModel.new(2)
	var winners: Array[int] = []
	game.game_over.connect(func(_ending: String, result: Array[Player]) -> void:
		for player in result:
			winners.append(player.id)
	)
	game.players[0].hand = [1, 2]
	game.players[1].hand = [1, 2]
	game.max_value = 2
	expect(game.check_game_end(), "stable two-player equilibrium did not end the game")
	expect(game.game_finished and winners == [1, 2], "duopoly did not declare both survivors as winners")

	var unstable_game := GameModel.new(2)
	unstable_game.players[0].hand = [1, 2]
	unstable_game.players[1].hand = [1, 2]
	unstable_game.max_value = 2
	unstable_game.market_stable = false
	expect(!unstable_game.check_game_end(), "unstable two-player market ended as a duopoly")

	var incomplete_game := GameModel.new(2)
	incomplete_game.players[0].hand = [1, 3]
	incomplete_game.players[1].hand = [1, 2]
	incomplete_game.max_value = 2
	expect(!incomplete_game.check_game_end(), "missing active value ended as a duopoly")


func test_fixed_seat_turn_traversal() -> void:
	var game := GameModel.new(4)
	var started: Array[int] = []
	game.turn_started.connect(func(_turn: int, player: Player) -> void: started.append(player.id))
	game.current_player = game.players[2]
	game.start_next_turn()
	game.end_turn()
	game.players[2].die()
	game.start_next_turn()
	expect(started == [3, 4], "turn traversal was not anchored to the original seat order")


func run_seeded_smoke(player_count: int, run_seed: int) -> void:
	seed(run_seed)
	var game := GameModel.new(player_count)
	game.pick_starting_player()
	var cap := 5000
	while !game.game_finished and game.turn_counter <= cap:
		game.start_next_turn()
		var current := game.current_player
		var target := current.choose_target(game.alive_players())
		var offered := game.propose_trade(current, target)
		game.resolve_trade(current, target, offered)
		game.finalize_turn()
		game.check_game_end()
		game.end_turn()
	expect(game.game_finished, "%d-player smoke seed %d hit diagnostic cap %d" % [player_count, run_seed, cap])
	if game.game_finished:
		expect(game.game_finished and (game.alive_players().size() <= 2), "%d-player smoke ended with an invalid survivor count" % player_count)
		for player in game.alive_players():
			for card in player.hand:
				expect(card > 0, "%d-player smoke retained a non-positive active card" % player_count)
