extends SceneTree


var failures: Array[String] = []


func _init() -> void:
	var scene := load("res://game_controller.tscn") as PackedScene
	var controller := scene.instantiate() as GameController
	controller.auto_start = false
	root.add_child(controller)
	await process_frame
	var table := controller.get_node("GameTable") as GameTable
	var result := table.get_node("Result") as PanelContainer
	var title := result.get_node("Margin/Content/Title") as Label
	var detail := result.get_node("Margin/Content/Detail") as Label
	var fast_forward := result.get_node("Margin/Content/FastForward") as Button
	var main_menu := table.get_node("MainMenu") as Control
	var start_match := table.get_node("MainMenu/Panel/Margin/Content/StartMatch") as Button
	var ai_pacing := table.get_node("MainMenu/Panel/Margin/Content/AIPacing") as CheckButton
	var conglomerate_name := table.get_node("MainMenu/Panel/Margin/Content/ConglomerateName") as OptionButton
	_expect(main_menu.visible, "game launch did not show the player-count menu")
	_expect(conglomerate_name.item_count == 20, "main menu did not offer the full conglomerate roster")
	conglomerate_name.select(3)
	start_match.emit_signal("pressed")
	await process_frame
	_expect(!main_menu.visible and controller.game.config.player_count == 4, "main menu did not start the selected player-count match")
	_expect(controller.game.players[0].company_name == controller.conglomerate_options()[3]["name"], "selected conglomerate was not assigned to Player 1")
	var company_names: Dictionary = {}
	for player: Player in controller.game.players:
		company_names[player.company_name] = true
	_expect(company_names.size() == controller.game.players.size(), "conglomerate names were not uniquely assigned")
	_expect(controller.game.current_player.id == 1, "Player 1 did not start the playtest match")
	_expect(ai_pacing.button_pressed and controller.ai_turn_pacing_enabled and is_equal_approx(controller.ai_delay_seconds, 2.0), "default AI pacing was not configured for the playtest delay")
	controller.game.players[0].die()
	controller.presentation_updated.emit(controller.game.player_view(1))
	_expect(result.visible and title.text == "Your company was acquired" and fast_forward.visible, "human elimination did not enter spectator mode")
	var result_menu := result.get_node("Margin/Content/MainMenu") as Button
	result_menu.emit_signal("pressed")
	_expect(main_menu.visible, "main menu was unavailable after human elimination")
	start_match.emit_signal("pressed")
	await process_frame
	controller.game.players[0].die()
	controller.presentation_updated.emit(controller.game.player_view(1))
	var old_generation := controller.match_generation
	var old_game := controller.game
	table._on_fast_forward()
	_expect(controller.fast_forward and fast_forward.disabled, "spectator fast-forward did not activate")
	table._on_rematch()
	await process_frame
	_expect(controller.match_generation == old_generation + 1 and controller.game != old_game and !result.visible, "rematch did not reset the spectator match")
	_expect(controller.game.config.player_count == 4, "rematch changed the selected player count")
	var header_menu := table.get_node("Margin/Layout/Header/Margin/Content/Controls/Menu") as Button
	header_menu.emit_signal("pressed")
	_expect(main_menu.visible, "main menu was unavailable during spectator mode")
	var count_picker := table.get_node("MainMenu/Panel/Margin/Content/PlayerCount") as SpinBox
	count_picker.value = 6
	ai_pacing.button_pressed = false
	start_match.emit_signal("pressed")
	await process_frame
	_expect(controller.game.config.player_count == 6 and !main_menu.visible and !controller.ai_turn_pacing_enabled, "main menu did not apply the player count and AI pacing settings")
	var header_restart := table.get_node("Margin/Layout/Header/Margin/Content/Controls/Restart") as Button
	header_restart.emit_signal("pressed")
	await process_frame
	_expect(controller.game.config.player_count == 6, "header restart changed the current player count")
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
