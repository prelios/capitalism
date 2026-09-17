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
	if failures.is_empty():
		print("Controller integration checks passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _on_decision_requested(actor_id: int, phase: String, view: PlayerView) -> void:
	decisions.append({"actor_id": actor_id, "phase": phase, "view": view})


func _expect(condition: bool, message: String) -> void:
	if !condition:
		failures.append(message)
