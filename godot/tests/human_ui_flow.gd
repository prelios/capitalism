extends SceneTree


var failures: Array[String] = []


func _init() -> void:
	await _test_human_offer()
	await _test_human_overpayment()
	await _test_insufficient_repayment_selection()
	await _test_duplicate_values_repayment()
	if failures.is_empty():
		print("Human UI flow checks passed.")
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
	await process_frame
	return controller


func _test_human_offer() -> void:
	var controller := await _new_controller()
	controller.restart_game([1], 1)
	await process_frame
	var table := controller.get_node("GameTable") as GameTable
	var hand := table.get_node("Margin/Layout/Hand/Margin/Content/HandScroll/Hand") as FlowContainer
	var seats := table.get_node("Margin/Layout/Main/Center/Arena/Seats") as Control
	var confirm := table.get_node("Margin/Layout/Main/Center/Trade/Margin/Content/Confirm") as Button
	_expect(confirm.disabled, "offer confirmation began enabled")
	_expect((seats.get_child(1) as PlayerSeatPanel).is_target_selectable(), "living opponent target was not selectable on the human turn")
	(hand.get_child(0) as CardView).button_pressed = true
	(seats.get_child(1) as PlayerSeatPanel)._pressed()
	_expect((seats.get_child(1) as PlayerSeatPanel).seat_visual_background().is_equal_approx(Color("6a1e28")), "selected trade target did not use the dedicated red style")
	_expect(!confirm.disabled, "complete offer selection did not enable confirmation")
	confirm.emit_signal("pressed")
	await process_frame
	_expect(controller.game.public_history().any(func(event: Dictionary): return event["type"] == "trade_proposed"), "human offer was not submitted")
	var events_after_offer := controller.game.public_history().size()
	table._confirm_selection()
	_expect(controller.game.public_history().size() == events_after_offer, "stale offer confirmation mutated the match")
	controller.queue_free()


func _test_human_overpayment() -> void:
	var controller := await _new_controller()
	controller.ai_turn_pacing_enabled = false
	_start_configured_ai_turn(controller, [Card.new("human-overpay", 3, "Money")], [Card.new("ai-offer", 2, "Workers"), Card.new("ai-extra", 1, "Tech")])
	await process_frame
	var table := controller.get_node("GameTable") as GameTable
	var hand := table.get_node("Margin/Layout/Hand/Margin/Content/HandScroll/Hand") as FlowContainer
	var confirm := table.get_node("Margin/Layout/Main/Center/Trade/Margin/Content/Confirm") as Button
	_expect(confirm.disabled, "repayment confirmation began enabled")
	(hand.get_child(0) as CardView).button_pressed = true
	_expect(!confirm.disabled, "legal overpayment did not enable confirmation")
	confirm.emit_signal("pressed")
	await process_frame
	_expect(controller.game.players[0].hand.any(func(card: Card): return card.id == "ai-offer"), "human overpayment did not resolve through the model")
	controller.queue_free()


func _test_insufficient_repayment_selection() -> void:
	var controller := await _new_controller()
	controller.ai_turn_pacing_enabled = false
	_start_configured_ai_turn(controller, [Card.new("human-small", 1, "Money"), Card.new("human-large", 3, "Workers")], [Card.new("ai-offer", 3, "Tech"), Card.new("ai-extra", 1, "Hype")])
	await process_frame
	var table := controller.get_node("GameTable") as GameTable
	var hand := table.get_node("Margin/Layout/Hand/Margin/Content/HandScroll/Hand") as FlowContainer
	var confirm := table.get_node("Margin/Layout/Main/Center/Trade/Margin/Content/Confirm") as Button
	(hand.get_child(0) as CardView).button_pressed = true
	_expect(confirm.disabled, "insufficient repayment selection enabled confirmation")
	(hand.get_child(1) as CardView).button_pressed = true
	_expect(!confirm.disabled, "legal multi-card repayment remained disabled")
	controller.queue_free()


func _test_duplicate_values_repayment() -> void:
	var controller := await _new_controller()
	controller.ai_turn_pacing_enabled = false
	_start_configured_ai_turn(controller, [Card.new("duplicate-a", 2, "Money"), Card.new("duplicate-b", 2, "Workers")], [Card.new("ai-offer", 4, "Tech")])
	await process_frame
	var table := controller.get_node("GameTable") as GameTable
	var hand := table.get_node("Margin/Layout/Hand/Margin/Content/HandScroll/Hand") as FlowContainer
	var confirm := table.get_node("Margin/Layout/Main/Center/Trade/Margin/Content/Confirm") as Button
	(hand.get_child(0) as CardView).button_pressed = true
	(hand.get_child(1) as CardView).button_pressed = true
	_expect(!confirm.disabled and table.selected_card_ids().size() == 2, "duplicate-valued cards were not independently selectable")
	controller.queue_free()


func _start_configured_ai_turn(controller: GameController, human_hand: Array[Card], ai_hand: Array[Card]) -> void:
	controller.match_generation += 1
	controller.setup_game()
	controller.local_player_id = 1
	controller.assign_human(1)
	controller.game.current_player = controller.game.players[1]
	controller.game.players[0].hand = human_hand
	controller.game.players[1].hand = ai_hand
	controller.play_game(controller.match_generation)


func _expect(condition: bool, message: String) -> void:
	if !condition:
		failures.append(message)
