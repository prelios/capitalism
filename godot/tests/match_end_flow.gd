extends SceneTree


var failures: Array[String] = []


func _init() -> void:
	var scene := load("res://game_controller.tscn") as PackedScene
	var controller := scene.instantiate() as GameController
	controller.auto_start = false
	root.add_child(controller)
	await process_frame
	controller.restart_game([1], 1)
	await process_frame
	var table := controller.get_node("GameTable") as GameTable
	var result := table.get_node("Result") as PanelContainer
	var title := result.get_node("Margin/Content/Title") as Label
	var detail := result.get_node("Margin/Content/Detail") as Label
	var fast_forward := result.get_node("Margin/Content/FastForward") as Button
	var old_generation := controller.match_generation
	var old_game := controller.game
	controller.game.players[0].die()
	controller.presentation_updated.emit(controller.game.player_view(1))
	_expect(result.visible and title.text == "Your company was acquired" and fast_forward.visible, "human elimination did not enter spectator mode")
	table._on_fast_forward()
	_expect(controller.fast_forward and fast_forward.disabled, "spectator fast-forward did not activate")
	table._on_rematch()
	await process_frame
	_expect(controller.match_generation == old_generation + 1 and controller.game != old_game and !result.visible, "rematch did not reset the spectator match")
	_expect(!controller.submit_offer(1, 2, "stale-card", old_generation), "stale command affected the rematch")
	controller.game.finish_game("Global Economic Meltdown", [])
	controller.presentation_updated.emit(controller.game.player_view(1))
	_expect(result.visible and title.text == "Global Economic Meltdown" and detail.text.contains("no winners"), "meltdown was not presented as a no-winner ending")
	table._on_rematch()
	await process_frame
	controller.game.finish_game("Monopoly", [controller.game.players[1]])
	controller.presentation_updated.emit(controller.game.player_view(1))
	_expect(result.visible and title.text == "Monopoly" and detail.text.contains("P2"), "monopoly winner was not presented")
	if failures.is_empty():
		print("Match end flow checks passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if !condition:
		failures.append(message)
