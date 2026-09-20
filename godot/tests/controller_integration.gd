extends SceneTree


var failures: Array[String] = []
var controller: GameController
var decisions: Array[Dictionary] = []


func _init() -> void:
	var scene := load("res://game_controller.tscn") as PackedScene
	controller = scene.instantiate() as GameController
	controller.auto_start = false
	root.add_child(controller)
	controller.decision_requested.connect(_on_decision_requested)
	controller.restart_game([1], 1)
	await process_frame
	await process_frame
	_expect(decisions.size() == 1 and decisions[0]["phase"] == GameModel.PHASE_AWAITING_OFFER, "human offer did not pause the match")
	var view: PlayerView = decisions[0]["view"]
	var old_generation := controller.match_generation
	var target_id := 2
	var offered_id: String = view.own_hand()[0]["id"]
	_expect(!controller.submit_offer(1, 1, offered_id), "invalid human offer was accepted")
	_expect(controller.game.phase == GameModel.PHASE_AWAITING_OFFER, "invalid offer cleared the pending human choice")
	_expect(controller.submit_offer(1, target_id, offered_id), "valid human offer was rejected")
	await process_frame
	if controller.game.phase == GameModel.PHASE_AWAITING_REPAYMENT:
		var repayment_target_id := controller.game.pending_trade.target_id
		var repayment_view := controller.game.player_view(repayment_target_id)
		var repayment_ids := PlayerPolicy.new().choose_repayment_card_ids(repayment_view, controller.game.pending_trade.offered_card.value)
		_expect(controller.submit_repayment(repayment_target_id, repayment_ids), "AI repayment command was rejected")
	await process_frame
	controller.restart_game([1], 1)
	_expect(!controller.submit_offer(1, 2, offered_id, old_generation), "stale offer affected a restarted match")
	_expect(controller.game.phase == GameModel.PHASE_AWAITING_OFFER, "stale offer changed restarted match phase")
	await _test_human_repayment_against_model(scene)
	if failures.is_empty():
		print("Controller integration checks passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _on_decision_requested(actor_id: int, phase: String, view: PlayerView) -> void:
	decisions.append({"actor_id": actor_id, "phase": phase, "view": view})


func _test_human_repayment_against_model(scene: PackedScene) -> void:
	decisions.clear()
	var delayed_controller := scene.instantiate() as GameController
	delayed_controller.auto_start = false
	delayed_controller.ai_turn_pacing_enabled = false
	root.add_child(delayed_controller)
	delayed_controller.decision_requested.connect(_on_decision_requested)
	delayed_controller.match_generation += 1
	delayed_controller.setup_game()
	delayed_controller.local_player_id = 1
	delayed_controller.assign_human(1)
	delayed_controller.game.current_player = delayed_controller.game.players[1]
	delayed_controller.game.players[0].hand = [Card.new("human-overpay", 3, "Money")]
	delayed_controller.game.players[1].hand = [Card.new("ai-offer", 2, "Workers"), Card.new("ai-extra", 1, "Tech")]
	delayed_controller.play_game(delayed_controller.match_generation)
	await process_frame
	_expect(decisions.size() == 1 and decisions[0]["actor_id"] == 1 and decisions[0]["phase"] == GameModel.PHASE_AWAITING_REPAYMENT, "human repayment did not pause an AI turn")
	_expect(!delayed_controller.submit_repayment(1, ["human-overpay", "human-overpay"]), "duplicate human repayment was accepted")
	_expect(delayed_controller.game.phase == GameModel.PHASE_AWAITING_REPAYMENT, "invalid repayment cleared the pending human choice")
	_expect(delayed_controller.submit_repayment(1, ["human-overpay"]), "legal human overpayment was rejected")

	var mirror := GameModel.new(MatchConfig.for_player_count(10, 1))
	mirror.players[0].hand = [Card.new("human-overpay", 3, "Money")]
	mirror.players[1].hand = [Card.new("ai-offer", 2, "Workers"), Card.new("ai-extra", 1, "Tech")]
	mirror.current_player = mirror.players[1]
	_expect(mirror.submit_offer(2, 1, "ai-offer"), "mirror AI offer was rejected")
	_expect(mirror.submit_repayment(1, ["human-overpay"]), "mirror human overpayment was rejected")
	_expect(delayed_controller.game.players[0].hand[0].id == mirror.players[0].hand[0].id, "paced controller and direct model produced different trade ownership")


func _expect(condition: bool, message: String) -> void:
	if !condition:
		failures.append(message)
