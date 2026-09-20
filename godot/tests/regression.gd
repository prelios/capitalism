extends SceneTree


var failures: Array[String] = []
var fixture_card_counter := 0


func _init() -> void:
	test_seeded_card_setup_and_configuration()
	test_offer_and_repayment_commands_are_atomic()
	test_company_lineage_and_public_history()
	test_player_views_and_policies()
	test_domain_invariants()
	test_non_mutating_helpers_and_instability_repayment()
	test_monopoly_precedes_pending_crash()
	test_unstable_acquisition_resolves_one_crash()
	test_simultaneous_bankruptcy_ends_in_meltdown()
	test_stable_two_player_duopoly()
	test_warning_timing_uses_completed_turns()
	test_boredom_trade_policy()
	test_market_pressure_feedback()
	test_fixed_seat_turn_traversal()
	for player_count in [4, 6, 10]:
		run_seeded_smoke(player_count, 1000 + player_count)
	if failures.is_empty():
		print("Regression checks passed: 14 deterministic scenarios; smoke seeds 1004, 1006, 1010.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func expect(condition: bool, message: String) -> void:
	if !condition:
		failures.append(message)


func game_for(player_count: int, seed_value := 1) -> GameModel:
	return GameModel.new(MatchConfig.for_player_count(player_count, seed_value))


func two_player_game() -> GameModel:
	var game := game_for(4)
	game.players[2].die()
	game.players[3].die()
	return game


func cards(values: Array[int]) -> Array[Card]:
	var result: Array[Card] = []
	for value in values:
		fixture_card_counter += 1
		result.append(Card.new("fixture-%d" % fixture_card_counter, value, Card.SUITS[fixture_card_counter % Card.SUITS.size()]))
	return result


func card_values(cards_to_read: Array[Card]) -> Array[int]:
	var values: Array[int] = []
	for card in cards_to_read:
		values.append(card.value)
	return values


func card_ids(cards_to_read: Array[Card]) -> Array[String]:
	var ids: Array[String] = []
	for card in cards_to_read:
		ids.append(card.id)
	return ids


func resolve_bot_trade(game: GameModel, actor: Player, target: Player, offered: Card) -> bool:
	if !game.submit_offer(actor.id, target.id, offered.id):
		return false
	if game.phase != GameModel.PHASE_AWAITING_REPAYMENT:
		return true
	return game.submit_repayment(target.id, PlayerPolicy.new().choose_repayment_card_ids(game.player_view(target.id), offered.value))


func test_seeded_card_setup_and_configuration() -> void:
	var first := game_for(4, 42)
	var second := game_for(4, 42)
	var first_order: Array[String] = []
	var second_order: Array[String] = []
	var ids: Array[String] = []
	for player_index in range(4):
		expect(first.players[player_index].hand.size() == 4, "setup did not deal four cards to player %d" % (player_index + 1))
		expect(first.players[player_index].seat == player_index + 1, "setup did not preserve fixed seat identity")
		expect(first.players[player_index].company_id == "company-%d" % (player_index + 1), "setup did not preserve company identity")
		for card in first.players[player_index].hand:
			first_order.append(card.id)
			ids.append(card.id)
			expect(card.value >= 1 and card.value <= 4, "setup created an invalid card value")
			expect(Card.SUITS.has(card.suit), "setup did not preserve a valid suit")
		for card in second.players[player_index].hand:
			second_order.append(card.id)
	expect(first_order == second_order, "same configuration and seed produced different deals")
	expect(ArrayUtils.distinct(ids).size() == 16, "setup did not create unique card IDs")
	for value in range(1, 5):
		var suits: Array[String] = []
		for player in first.players:
			for card in player.hand:
				if card.value == value:
					suits.append(card.suit)
		expect(ArrayUtils.distinct(suits).size() == Card.SUITS.size(), "value %d did not have one card of each suit" % value)

	var source_config := MatchConfig.for_player_count(4, 7)
	var copied_config_game := GameModel.new(source_config)
	source_config.player_count = 10
	expect(copied_config_game.config.player_count == 4, "match retained mutable shared configuration")
	var invalid_config := MatchConfig.for_player_count(3, 1)
	var rejected_game := GameModel.new(invalid_config)
	expect(!invalid_config.is_valid() and !rejected_game.configuration_error.is_empty(), "invalid player count was not rejected explicitly")

	var suit_game := game_for(4)
	var offered := Card.new("money-3", 3, "Money")
	var returned := Card.new("hype-3", 3, "Hype")
	suit_game.players[0].hand = [offered]
	suit_game.players[1].hand = [returned]
	suit_game.current_player = suit_game.players[0]
	resolve_bot_trade(suit_game, suit_game.players[0], suit_game.players[1], offered)
	expect(suit_game.players[1].hand.has(offered) and suit_game.players[0].hand.has(returned), "suits changed base-game trade legality")


func test_offer_and_repayment_commands_are_atomic() -> void:
	var game := game_for(4)
	var actor := game.players[0]
	var target := game.players[1]
	var offered := Card.new("offer-3", 3, "Money")
	var low_return := Card.new("return-1", 1, "Workers")
	var high_return := Card.new("return-2", 2, "Hype")
	actor.hand = [offered]
	target.hand = [low_return, high_return]
	game.current_player = actor
	var actor_before := card_ids(actor.hand)
	var target_before := card_ids(target.hand)
	expect(!game.submit_offer(999, target.id, offered.id), "invented actor offer was accepted")
	expect(!game.submit_offer(actor.id, actor.id, offered.id), "self-targeted offer was accepted")
	expect(!game.submit_offer(actor.id, target.id, "invented-card"), "invented card offer was accepted")
	expect(card_ids(actor.hand) == actor_before and card_ids(target.hand) == target_before, "invalid offer changed hands")

	expect(game.submit_offer(actor.id, target.id, offered.id), "valid offer was rejected")
	expect(game.phase == GameModel.PHASE_AWAITING_REPAYMENT and card_ids(actor.hand) == actor_before, "offer mutated state before repayment")
	expect(!game.submit_offer(actor.id, target.id, offered.id), "repeated offer was accepted")
	expect(!game.submit_repayment(actor.id, [low_return.id, high_return.id]), "wrong-actor repayment was accepted")
	expect(!game.submit_repayment(target.id, []), "empty repayment was accepted")
	expect(!game.submit_repayment(target.id, [low_return.id, low_return.id]), "duplicate repayment IDs were accepted")
	expect(!game.submit_repayment(target.id, [low_return.id]), "insufficient repayment was accepted")
	expect(card_ids(actor.hand) == actor_before and card_ids(target.hand) == target_before, "invalid repayment changed hands")
	expect(game.submit_repayment(target.id, [low_return.id, high_return.id]), "legal overpayment was rejected")
	expect(game.phase == GameModel.PHASE_TURN_RESOLVED, "accepted repayment did not resolve the turn")
	expect(actor.hand.has(low_return) and actor.hand.has(high_return) and target.hand.has(offered), "accepted repayment did not transfer exact card identities")
	expect(!game.submit_repayment(target.id, [low_return.id]), "repeated repayment was accepted")
	game.finish_game("Test", [])
	expect(!game.submit_offer(actor.id, target.id, offered.id), "post-finish offer was accepted")


func test_company_lineage_and_public_history() -> void:
	var game := game_for(4)
	var acquirer := game.players[0]
	var middle := game.players[1]
	var victim := game.players[2]
	middle.hand = cards([4])
	victim.hand = cards([1])
	game.current_player = middle
	resolve_bot_trade(game, middle, victim, middle.hand[0])
	expect(middle.owned_company_ids == ["company-2", "company-3"], "first acquisition did not transfer company lineage")

	acquirer.hand = cards([6])
	game.current_player = acquirer
	game.phase = GameModel.PHASE_AWAITING_OFFER
	resolve_bot_trade(game, acquirer, middle, acquirer.hand[0])
	expect(acquirer.owned_company_ids == ["company-1", "company-2", "company-3"], "second acquisition did not inherit all company tokens")
	expect(middle.acquired_by_id == acquirer.id, "direct acquirer identity was not retained")

	var history_before := game.public_history()
	expect(history_before.filter(func(event: Dictionary): return event["type"] == "player_acquired").size() == 2, "public history did not record both acquisitions")
	var acquisition_event: Dictionary = history_before.filter(func(event: Dictionary): return event["type"] == "player_acquired")[0]
	var recorded_cards: Array = acquisition_event["data"]["cards"]
	var recorded_id: String = recorded_cards[0]["id"]
	acquirer.hand.clear()
	expect(game.public_history().filter(func(event: Dictionary): return event["type"] == "player_acquired")[0]["data"]["cards"][0]["id"] == recorded_id, "history changed after later hand mutation")
	var snapshot := game.public_snapshot()
	expect(snapshot["players"][0].has("hand_size") and !snapshot["players"][0].has("hand"), "public snapshot exposed a private hand")
	var inherited_tokens: Array = snapshot["players"][0]["company_tokens"]
	expect(inherited_tokens.map(func(token: Dictionary): return token["company_id"]) == ["company-1", "company-2", "company-3"], "public snapshot did not expose inherited company tokens")
	expect(inherited_tokens[1]["company_name"] == "Company 2" and inherited_tokens[1]["company_emoji"] == "🏢", "company token identity was incomplete")

	acquirer.hand = cards([3])
	game.market_stable = false
	game.unstable_value = 3
	game.destroy_value()
	expect(acquirer.owned_company_ids.is_empty(), "bankruptcy did not remove inherited company tokens")
	expect((game.public_snapshot()["players"][0]["company_tokens"] as Array).is_empty(), "bankruptcy left company tokens visible in the public snapshot")


func test_domain_invariants() -> void:
	var game := game_for(4, 77)
	expect(game.invariant_violations().is_empty(), "fresh seeded match violated domain invariants")
	game.pick_starting_player()
	game.start_next_turn()
	var actor := game.current_player
	var policy := PlayerPolicy.new("Test")
	var target := game.player_by_id(policy.choose_target(game.player_view(actor.id)))
	var offered_id := policy.choose_offer_card_id(game.player_view(actor.id), target.id)
	var offered: Card = actor.hand.filter(func(card: Card): return card.id == offered_id)[0]
	resolve_bot_trade(game, actor, target, offered)
	game.complete_turn()
	expect(game.invariant_violations().is_empty(), "accepted transition violated domain invariants")


func test_player_views_and_policies() -> void:
	var game := game_for(4)
	var view := game.player_view(1)
	var opponent := game.players[1]
	var public_players := view.players()
	expect(view.own_hand().size() == game.players[0].hand.size(), "player view omitted the requester's hand")
	expect(!public_players[1].has("hand") and !public_players[1].has("hand_value"), "normal player view exposed an opponent hand or total")
	public_players[1]["hand_size"] = 999
	view.own_hand().clear()
	expect(opponent.hand.size() != 999 and game.players[0].hand.size() == 4, "mutating a player view changed model state")
	var fair_policy := AggroPlayer.new()
	var target_id := fair_policy.choose_target(view)
	expect(target_id != 1 and target_id > 0, "fair policy could not choose a public target")
	var tie_rng := RandomNumberGenerator.new()
	tie_rng.seed = 99
	var tied_policy := AggroPlayer.new(tie_rng)
	var tied_targets: Dictionary = {}
	for _attempt in 8:
		tied_targets[tied_policy.choose_target(view)] = true
	expect(tied_targets.size() > 1, "fair target tie-breaking always chose one seat")
	var optimal := OptimalPlayer.new()
	expect(optimal.choose_target(view) == -1, "optimal policy accepted a normal player view")
	var privileged_target := optimal.choose_target(game.privileged_player_view(1))
	expect(privileged_target != 1 and privileged_target > 0, "optimal policy did not accept its explicit privileged view")


func test_non_mutating_helpers_and_instability_repayment() -> void:
	var hand: Array[int] = [4, 1, 4]
	var original_hand := hand.duplicate()
	var unique := ArrayUtils.distinct(hand)
	expect(hand == original_hand, "distinct() changed its input hand")
	expect(unique == [4, 1], "distinct() did not preserve first-seen order")
	var repayment_game := game_for(4)
	repayment_game.players[0].hand = cards([1, 4])
	var policies: Array[PlayerPolicy] = [AggroPlayer.new(), ScaredPlayer.new(), OptimalPlayer.new(), OptiHighPlayer.new(), OptiLowPlayer.new(), OptiRandPlayer.new()]
	for policy in policies:
		expect(policy.choose_repayment_card_ids(repayment_game.player_view(1), 1).size() == 1, "%s did not select a stable repayment" % policy.display_name)
		repayment_game.market_stable = false
		expect(policy.choose_repayment_card_ids(repayment_game.player_view(1), 1) == [repayment_game.players[0].hand[1].id], "%s did not discard the unstable value" % policy.display_name)
		repayment_game.market_stable = true
		expect(card_values(repayment_game.players[0].hand) == [1, 4], "%s repayment selection mutated its hand" % policy.display_name)
	var exact_game := game_for(4)
	exact_game.players[0].hand = cards([1, 2, 4])
	var exact_ids := PlayerPolicy.new().choose_repayment_card_ids(exact_game.player_view(1), 3)
	expect(exact_ids.size() == ArrayUtils.distinct(exact_ids).size(), "repayment policy returned duplicate card IDs")
	expect(exact_ids == [exact_game.players[0].hand[0].id, exact_game.players[0].hand[1].id], "repayment policy did not choose the exact minimum-total repayment")


func test_monopoly_precedes_pending_crash() -> void:
	var game := two_player_game()
	var acquirer := game.players[0]
	var target := game.players[1]
	acquirer.hand = cards([4])
	target.hand = cards([1])
	game.max_value = 4
	game.current_player = acquirer
	game.market_stable = false
	game.unstable_value = 4
	resolve_bot_trade(game, acquirer, target, acquirer.hand[0])
	expect(game.game_finished, "last-opponent acquisition did not finish the game")
	expect(game.market_stable == false and game.max_value == 4, "pending crash ran before monopoly")
	expect(acquirer.has_card_value(4), "monopoly acquirer lost cards to a pending crash")


func test_unstable_acquisition_resolves_one_crash() -> void:
	var game := game_for(4)
	var acquirer := game.players[0]
	var target := game.players[1]
	var survivor := game.players[2]
	acquirer.hand = cards([3])
	target.hand = cards([1])
	survivor.hand = cards([2])
	game.players[3].die()
	game.max_value = 3
	game.current_player = acquirer
	game.market_stable = false
	game.unstable_value = 3
	resolve_bot_trade(game, acquirer, target, acquirer.hand[0])
	expect(!target.alive, "failed target was not acquired")
	expect(game.market_stable and game.max_value == 2, "unstable acquisition did not resolve exactly one crash")
	expect(!acquirer.has_card_value(3), "crash did not remove the pending value from the acquirer")
	expect(!game.game_finished, "non-final unstable acquisition ended the game")


func test_simultaneous_bankruptcy_ends_in_meltdown() -> void:
	var game := game_for(4)
	var endings: Array[String] = []
	game.game_over.connect(func(ending: String, _winners: Array[Player]) -> void: endings.append(ending))
	for player in game.players:
		player.hand = cards([3])
	game.players[3].die()
	game.max_value = 3
	game.market_stable = false
	game.unstable_value = 3
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
	var game := two_player_game()
	var winners: Array[int] = []
	game.game_over.connect(func(_ending: String, result: Array[Player]) -> void:
		for player in result:
			winners.append(player.id)
	)
	game.players[0].hand = cards([1, 2])
	game.players[1].hand = cards([1, 2])
	game.max_value = 2
	expect(game.check_game_end(), "stable two-player equilibrium did not end the game")
	expect(game.game_finished and winners == [1, 2], "duopoly did not declare both survivors as winners")

	var unstable_game := two_player_game()
	unstable_game.players[0].hand = cards([1, 2])
	unstable_game.players[1].hand = cards([1, 2])
	unstable_game.max_value = 2
	unstable_game.market_stable = false
	expect(!unstable_game.check_game_end(), "unstable two-player market ended as a duopoly")

	var incomplete_game := two_player_game()
	incomplete_game.players[0].hand = cards([1, 3])
	incomplete_game.players[1].hand = cards([1, 2])
	incomplete_game.max_value = 2
	expect(!incomplete_game.check_game_end(), "missing active value ended as a duopoly")


func test_warning_timing_uses_completed_turns() -> void:
	var game := game_for(4)
	var announced_counts: Array[int] = []
	game.market_unstable.connect(func(count: int) -> void: announced_counts.append(count))
	for player in game.players:
		player.hand = cards([1, 2, 3, 4])
	game.destabilize_market()
	for _turn in range(4):
		game.finalize_turn()
	expect(announced_counts == [4, 3, 2, 1], "warning did not count each completed turn from the trigger")
	expect(game.market_stable and game.max_value == 3, "warning did not resolve the crash when its count reached zero")

	var boredom_game := game_for(4)
	boredom_game.boredom_counter = boredom_game.BOREDOM_MULTIPLIER * boredom_game.alive_players().size() + 1
	boredom_game.finalize_turn()
	expect(!boredom_game.market_stable and boredom_game.countdown_to_destruction == 3, "boredom warning did not count its triggering turn")


func test_boredom_trade_policy() -> void:
	var split_game := game_for(4)
	var split_current := split_game.players[0]
	var split_target := split_game.players[1]
	split_current.hand = cards([3])
	split_target.hand = cards([1, 2])
	split_game.current_player = split_current
	resolve_bot_trade(split_game, split_current, split_target, split_current.hand[0])
	expect(split_game.boredom_counter == 1, "exact split repayment counted as a mirror trade")

	var mirror_game := game_for(4)
	var mirror_current := mirror_game.players[0]
	var mirror_target := mirror_game.players[1]
	mirror_current.hand = cards([3])
	mirror_target.hand = cards([3])
	mirror_game.current_player = mirror_current
	resolve_bot_trade(mirror_game, mirror_current, mirror_target, mirror_current.hand[0])
	expect(mirror_game.boredom_counter == 2, "same-value single-card swap did not add mirror boredom")

	var warning_game := game_for(4)
	var warning_current := warning_game.players[0]
	var warning_target := warning_game.players[1]
	warning_current.hand = cards([2])
	warning_target.hand = cards([2])
	warning_game.current_player = warning_current
	warning_game.market_stable = false
	resolve_bot_trade(warning_game, warning_current, warning_target, warning_current.hand[0])
	expect(warning_game.boredom_counter == 0, "warning-phase trade accumulated boredom")


func test_market_pressure_feedback() -> void:
	var game := game_for(4)
	game.boredom_counter = 3
	expect(game.market_pressure() == GameModel.MARKET_PRESSURE_CALM, "pressure reached Moving before ten percent of the active threshold")
	game.boredom_counter = 4
	expect(game.market_pressure() == GameModel.MARKET_PRESSURE_MOVING, "pressure did not enter Moving at ten percent")
	game.boredom_counter = 16
	expect(game.market_pressure() == GameModel.MARKET_PRESSURE_RESTLESS, "pressure did not enter Restless at forty percent")
	game.boredom_counter = 24
	expect(game.market_pressure() == GameModel.MARKET_PRESSURE_DANGEROUS, "pressure did not enter Dangerous at sixty percent")
	game.players[3].die()
	game.boredom_counter = 3
	expect(game.market_pressure() == GameModel.MARKET_PRESSURE_MOVING, "pressure did not use the current survivor threshold")
	game.destabilize_market()
	expect(game.market_pressure().is_empty(), "warning market exposed a stable-market pressure state")
	game.stabilize_market()
	expect(game.market_pressure() == GameModel.MARKET_PRESSURE_CALM, "pressure did not reset after stabilization")
	expect(!game.public_snapshot().has("boredom_counter"), "public snapshot exposed the exact boredom counter")


func test_fixed_seat_turn_traversal() -> void:
	var game := game_for(4)
	var started: Array[int] = []
	game.turn_started.connect(func(_turn: int, player: Player) -> void: started.append(player.id))
	game.current_player = game.players[2]
	game.start_next_turn()
	game.phase = GameModel.PHASE_TURN_RESOLVED
	game.end_turn()
	game.players[2].die()
	game.start_next_turn()
	expect(started == [3, 4], "turn traversal was not anchored to the original seat order")


func run_seeded_smoke(player_count: int, run_seed: int) -> void:
	var game := game_for(player_count, run_seed)
	game.pick_starting_player()
	var cap := 5000
	while !game.game_finished and game.turn_counter <= cap:
		game.start_next_turn()
		var current := game.current_player
		var policy := PlayerPolicy.new("Smoke")
		var target := game.player_by_id(policy.choose_target(game.player_view(current.id)))
		var offered_id := policy.choose_offer_card_id(game.player_view(current.id), target.id)
		var offered: Card = current.hand.filter(func(card: Card): return card.id == offered_id)[0]
		resolve_bot_trade(game, current, target, offered)
		game.complete_turn()
		for violation in game.invariant_violations():
			expect(false, "%d-player smoke seed %d: %s" % [player_count, run_seed, violation])
	expect(game.game_finished, "%d-player smoke seed %d hit diagnostic cap %d" % [player_count, run_seed, cap])
	if game.game_finished:
		expect(game.game_finished and (game.alive_players().size() <= 2), "%d-player smoke ended with an invalid survivor count" % player_count)
		for player in game.alive_players():
			for card in player.hand:
				expect(card.value > 0, "%d-player smoke retained a non-positive active card" % player_count)
