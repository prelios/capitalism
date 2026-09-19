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
	var seats := table.get_node("Margin/Layout/Main/Center/SeatScroll/Seats") as FlowContainer
	var hand := table.get_node("Margin/Layout/Hand/Margin/Content/HandScroll/Hand") as FlowContainer
	_expect(seats.get_child_count() == 4, "four-seat match did not render four public seat panels")
	_expect(hand.get_child_count() == 4, "local hand did not render the four private cards")
	_expect(table.market_status_background().is_equal_approx(Color("173d2b")), "stable market status did not use the green style")
	_expect(table.trade_window_background().is_equal_approx(Color.WHITE), "trade window did not turn white while awaiting local input")
	var banner := table.get_node("Margin/Layout/Header/Margin/Content/TurnStatus/Turn") as Label
	_expect(banner.text.contains(controller.game.players[0].company_name) and banner.text.contains(controller.game.players[0].company_emoji), "turn banner did not identify the active conglomerate")
	var active_seat := seats.get_child(0) as PlayerSeatPanel
	_expect(active_seat.seat_visual_background().is_equal_approx(Color("2f86dc")), "active player did not use the explicit blue resting style")
	_expect(active_seat.get_node("Margin/Content/Identity").text.contains("Current"), "active player identity did not include the Current label")
	_expect(active_seat.get_global_rect().encloses((active_seat.get_node("Margin/Content") as VBoxContainer).get_global_rect()), "player seat content exceeded its visual panel")
	_expect(!active_seat.disabled, "inactive seat controls should not use desaturating disabled rendering")
	controller.game.players[1].die()
	controller.presentation_updated.emit(controller.game.player_view(1))
	await process_frame
	var acquired_seat := seats.get_child(1) as PlayerSeatPanel
	_expect(acquired_seat.seat_visual_background().is_equal_approx(Color("30343b")), "acquired player did not use the neutral grey resting style")
	_expect(!acquired_seat.is_target_selectable() and acquired_seat.mouse_filter == Control.MOUSE_FILTER_IGNORE, "acquired player seat remained interactive")
	controller.restart_game([1], 1)
	await process_frame
	controller.game.market_stable = false
	controller.game.unstable_value = 4
	controller.presentation_updated.emit(controller.game.player_view(1))
	await process_frame
	_expect(table.market_status_background().is_equal_approx(Color("4d3d0c")), "unstable market status did not use the yellow style")
	var first_card := hand.get_child(0) as CardView
	first_card.button_pressed = true
	var selected_id := first_card.card_id
	controller.presentation_updated.emit(controller.game.player_view(1))
	await process_frame
	_expect(table.selected_card_ids() == [selected_id], "local card selection was lost during redraw")
	var expanded_hand: Array[Card] = []
	for value in range(1, 25):
		expanded_hand.append(Card.new("large-hand-%d" % value, value, "Money"))
	controller.game.players[0].hand = expanded_hand
	controller.presentation_updated.emit(controller.game.player_view(1))
	await process_frame
	_expect(hand.get_child_count() == 24, "large local hand was not rendered in the scrollable hand area")
	_expect(table.selected_card_ids().is_empty(), "selection retained an absent card ID after hand changed")
	var identities := {1: {"company_emoji": "🦅", "company_name": "Apex Morrow"}, 2: {"company_emoji": "⚡", "company_name": "Bramble & Bolt"}}
	var trade_summary := table._event_summary({"type": "trade_resolved", "data": {"actor_id": 1, "target_id": 2, "offered": {"id": "private-offer-id", "suit": "Tech", "value": 3}, "returned": [{"id": "private-return-id", "suit": "Money", "value": 1}, {"id": "private-return-id-2", "suit": "Workers", "value": 2}]}}, identities)
	_expect(trade_summary.contains("Bramble & Bolt") and trade_summary.contains("Money 1") and !trade_summary.contains("private-"), "public trade history omitted facts or exposed private card IDs")
	var crash_summary := table._event_summary({"type": "market_crashed", "data": {"value": 4, "bankrupt_player_ids": [2, 3]}})
	_expect(crash_summary.contains("value 4") and crash_summary.contains("Player 2, Player 3"), "crash history omitted value or bankrupt players")
	var warning_summary := table._event_summary({"type": "market_warning_updated", "data": {"value": 4, "turns_remaining": 3}})
	_expect(warning_summary.contains("2 turns remaining after this turn"), "warning history did not describe the post-turn countdown")
	controller.selected_player_count = 10
	controller.restart_game([1], 1)
	await process_frame
	_expect(seats.get_child_count() == 10, "ten-seat match did not render every player seat")
	var conglomerate := controller.game.players[0]
	conglomerate.owned_company_ids.clear()
	for player in controller.game.players:
		conglomerate.owned_company_ids.append(player.company_id)
		if player != conglomerate:
			player.owned_company_ids.clear()
	controller.presentation_updated.emit(controller.game.player_view(1))
	await process_frame
	var token_container := (seats.get_child(0) as PlayerSeatPanel).get_node("Margin/Content/CompanyTokenScroll/CompanyTokens") as HFlowContainer
	_expect(token_container.get_child_count() == 10, "large company collection did not render every company token")
	_expect((token_container.get_child(1) as CompanyToken).tooltip_text.contains(controller.game.players[1].company_name), "company token did not identify its conglomerate")
	for seat_node in seats.get_children():
		var seat := seat_node as PlayerSeatPanel
		_expect(seat.get_global_rect().encloses((seat.get_node("Margin/Content") as VBoxContainer).get_global_rect()), "ten-seat player content exceeded its visual panel")
	if failures.is_empty():
		print("Table layout checks passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if !condition:
		failures.append(message)
