extends SceneTree


var failures: Array[String] = []
var presentations: Array[Dictionary] = []


func _init() -> void:
	await _test_normal_trade_sequence()
	await _test_acquisition_and_crash_sequence()
	await _test_restart_cancels_presentation()
	if failures.is_empty():
		print("Trade presentation checks passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _new_controller() -> GameController:
	var scene := load("res://game_controller.tscn") as PackedScene
	var controller := scene.instantiate() as GameController
	controller.auto_start = false
	root.add_child(controller)
	controller.trade_presentation_updated.connect(_on_trade_presentation)
	await process_frame
	return controller


func _test_normal_trade_sequence() -> void:
	presentations.clear()
	var controller := await _new_controller()
	controller.restart_game([1], 1)
	await process_frame
	controller.game.players[0].hand = [Card.new("public-offer", 3, "Tech")]
	controller.game.players[1].hand = [Card.new("public-return-a", 1, "Money"), Card.new("public-return-b", 2, "Workers")]
	_expect(controller.submit_offer(1, 2, "public-offer"), "normal presentation scenario rejected its offer")
	await process_frame
	await process_frame
	var stages := _stages()
	_expect(_contains_ordered(stages, ["offer_moving", "offer_ready", "repayment_moving", "repayment_ready", "exchange", "arrival", "settled"]), "normal trade omitted or reordered a presentation stage: %s" % [stages])
	var repayment := _first_presentation("repayment_ready")
	_expect(repayment.get("returned_cards", []).size() == 2, "repayment presentation did not keep every returned card visible")
	_expect(controller.game.players[0].hand.any(func(card: Card): return card.id == "public-return-a") and controller.game.players[1].hand.any(func(card: Card): return card.id == "public-offer"), "presentation sequence changed the authoritative trade result")
	controller.return_to_main_menu()
	controller.queue_free()


func _test_acquisition_and_crash_sequence() -> void:
	presentations.clear()
	var controller := await _new_controller()
	controller.restart_game([1], 1)
	await process_frame
	controller.game.players[0].hand = [Card.new("acquisition-offer", 4, "Hype"), Card.new("actor-safe", 2, "Money")]
	controller.game.players[1].hand = [Card.new("victim-small", 1, "Workers")]
	for index in range(2, controller.game.players.size()):
		controller.game.players[index].hand = [Card.new("safe-%d" % index, 2, "Tech")]
	controller.game.market_stable = false
	controller.game.unstable_value = 4
	controller.game.countdown_to_destruction = 2
	_expect(controller.submit_offer(1, 2, "acquisition-offer"), "acquisition presentation scenario rejected its offer")
	await process_frame
	await process_frame
	var stages := _stages()
	_expect(_contains_ordered(stages, ["offer_moving", "offer_ready", "acquisition", "crash", "settled"]), "acquisition/crash feedback was not presented in order: %s" % [stages])
	var crash := _first_presentation("crash")
	_expect(crash.get("crash_value", -1) == 4, "crash interruption did not identify the destroyed value")
	_expect(!controller.game.players[1].alive and controller.game.market_stable, "presentation changed acquisition or crash authority")
	controller.return_to_main_menu()
	controller.queue_free()


func _test_restart_cancels_presentation() -> void:
	presentations.clear()
	var controller := await _new_controller()
	controller.fast_headless = false
	controller.presentation_speed_scale = 0.2
	controller.restart_game([1], 1)
	await process_frame
	controller.game.players[0].hand = [Card.new("restart-offer", 2, "Money")]
	controller.game.players[1].hand = [Card.new("restart-return", 2, "Tech")]
	var old_generation := controller.match_generation
	_expect(controller.submit_offer(1, 2, "restart-offer"), "restart scenario rejected its offer")
	await create_timer(0.03).timeout
	var arena := controller.get_node("GameTable/Margin/Layout/Main/Center/Arena") as TradeArena
	_expect(arena.stage() == "offer_moving", "slow proposal did not enter the in-flight presentation state")
	controller.start_rematch()
	await process_frame
	_expect(controller.match_generation == old_generation + 1 and arena.stage() == "idle", "restart did not clear the active presentation immediately")
	await create_timer(0.2).timeout
	_expect(arena.stage() == "idle" and controller.game.phase == GameModel.PHASE_AWAITING_OFFER, "cancelled presentation resumed against the rematch")
	controller.return_to_main_menu()
	controller.queue_free()


func _on_trade_presentation(presentation: Dictionary) -> void:
	presentations.append(presentation.duplicate(true))


func _stages() -> Array[String]:
	var result: Array[String] = []
	for presentation in presentations:
		result.append(presentation.get("stage", "idle"))
	return result


func _first_presentation(stage: String) -> Dictionary:
	for presentation in presentations:
		if presentation.get("stage", "idle") == stage:
			return presentation
	return {}


func _contains_ordered(values: Array[String], expected: Array[String]) -> bool:
	var expected_index := 0
	for value in values:
		if expected_index < expected.size() and value == expected[expected_index]:
			expected_index += 1
	return expected_index == expected.size()


func _expect(condition: bool, message: String) -> void:
	if !condition:
		failures.append(message)
