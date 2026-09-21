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
	var poker_table := table.get_node("PokerTable") as ColorRect
	_expect(poker_table.color.is_equal_approx(Color("062b1a")), "game table did not use the deep-green poker surface")
	var arena := table.get_node("Margin/Layout/Main/Center/Arena") as TradeArena
	var seats := table.get_node("Margin/Layout/Main/Center/Arena/Seats") as Control
	var hand := table.get_node("Margin/Layout/Hand/Margin/Content/HandScroll/Hand") as FlowContainer
	_expect(seats.get_child_count() == 4, "four-seat match did not render four public seat panels")
	var local_center := arena.seat_center(1)
	var left_center := arena.seat_center(2)
	var top_center := arena.seat_center(3)
	var right_center := arena.seat_center(4)
	_expect(local_center.y > left_center.y and local_center.y > right_center.y and top_center.y < left_center.y, "four players were not placed at 6-9-12-3 o'clock")
	_expect(left_center.x < local_center.x and right_center.x > local_center.x, "four-player clock ordering was incorrect")
	_expect(hand.get_child_count() == 4, "local hand did not render the four private cards")
	_expect(table.market_status_background().is_equal_approx(Color("173d2b")), "stable market status did not use the green style")
	var market_detail := table.get_node("Margin/Layout/Main/Sidebar/Market/Margin/Content") as Label
	_expect(market_detail.text.contains("stable and calm"), "stable market did not identify calm pressure")
	controller.return_to_main_menu()
	await process_frame
	var market_policy := table.get_node("MainMenu/Panel/Margin/Content/MarketPolicy") as OptionButton
	market_policy.select(1)
	table._on_start_match()
	await process_frame
	_expect(controller.game.market_policy == MatchConfig.MARKET_POLICY_TIME_BASED and market_detail.text.contains("Time-based market") and market_detail.text.contains("Round 1 of 2"), "time-based market menu option did not start an explicit round countdown")
	controller.set_market_policy(MatchConfig.MARKET_POLICY_PLAY_BASED)
	controller.restart_game([1], 1)
	await process_frame
	_expect(table.trade_window_background().is_equal_approx(Color.WHITE), "trade window did not turn white while awaiting local input")
	var banner := table.get_node("Margin/Layout/Header/Margin/Content/TurnStatus/Turn") as Label
	_expect(banner.text.contains(controller.game.players[0].company_name) and banner.text.contains(controller.game.players[0].company_emoji), "turn banner did not identify the active conglomerate")
	var active_seat := seats.get_child(0) as PlayerSeatPanel
	_expect(active_seat.seat_visual_background().is_equal_approx(Color("2f86dc")), "active player did not use the explicit blue resting style")
	_expect(active_seat.get_node("Margin/Content/Identity").text.contains("Current"), "active player identity did not include the Current label")
	_expect(active_seat.get_global_rect().encloses((active_seat.get_node("Margin/Content") as VBoxContainer).get_global_rect()), "player seat content exceeded its visual panel")
	_expect(!active_seat.disabled, "inactive seat controls should not use desaturating disabled rendering")
	table._on_target_hovered(2, true)
	_expect(arena.stage() == "hover" and arena.arrow_color().is_equal_approx(TradeArena.ARROW_HOVER), "target hover did not show the yellow direction arrow")
	table._on_target_selected(2)
	_expect(arena.stage() == "selected" and arena.arrow_color().is_equal_approx(TradeArena.ARROW_SELECTED), "selected target did not show the red direction arrow")
	var arrow_points := arena._arrow_points()
	var arrow_tangent := (arrow_points[arrow_points.size() - 1] - arrow_points[arrow_points.size() - 2]).normalized()
	var target_direction := (arena.seat_center(2) - arrow_points[arrow_points.size() - 1]).normalized()
	_expect(arrow_tangent.dot(target_direction) > 0.9, "curved arrow endpoint did not continue toward the target seat center")
	arena.show_presentation({"stage": "acquisition", "actor_id": 1, "target_id": 2, "offered_card": {"id": "offer", "value": 4, "suit": "Tech"}, "acquired_cards": [{"id": "asset", "value": 1, "suit": "Money"}], "duration": 0.0})
	_expect(arena.flow_participants() == Vector2i(2, 1), "acquisition flow arrow did not reverse from the victim toward the acquirer")
	controller.game.players[1].die()
	controller.presentation_updated.emit(controller.game.player_view(1))
	await process_frame
	var acquired_seat := seats.get_child(1) as PlayerSeatPanel
	_expect(acquired_seat.seat_visual_background().is_equal_approx(Color("30343b")), "acquired player did not use the neutral grey resting style")
	_expect(!acquired_seat.is_target_selectable() and acquired_seat.mouse_filter == Control.MOUSE_FILTER_IGNORE, "acquired player seat remained interactive")
	controller.restart_game([1], 1)
	await process_frame
	controller.game.players[0].hand = [Card.new("safe-value", 3, "Money"), Card.new("endangered-value", 4, "Tech")]
	controller.game.boredom_counter = 16
	controller.presentation_updated.emit(controller.game.player_view(1))
	await process_frame
	_expect(!(hand.get_child(1) as CardView).is_endangered(), "stable market marked a card as endangered")
	_expect(market_detail.text.contains("stable but restless") and !market_detail.text.contains("16"), "stable market did not present qualitative pressure without an exact counter")
	controller.game.market_stable = false
	controller.game.unstable_value = 4
	controller.presentation_updated.emit(controller.game.player_view(1))
	await process_frame
	_expect(table.market_status_background().is_equal_approx(Color("532207")), "unstable market status did not use the dark-orange style")
	var endangered_card := hand.get_child(1) as CardView
	_expect(endangered_card.is_endangered() and endangered_card.text.begins_with("⚠"), "pending crash value was not visibly marked in the local hand")
	endangered_card.button_pressed = true
	var selected_id := endangered_card.card_id
	controller.presentation_updated.emit(controller.game.player_view(1))
	await process_frame
	_expect(table.selected_card_ids() == [selected_id], "local card selection was lost during redraw")
	endangered_card = hand.get_child(1) as CardView
	_expect(endangered_card.is_endangered() and endangered_card.card_background().is_equal_approx(Color("5c2609")), "selected endangered card did not preserve both danger and selection treatments")
	controller.game.stabilize_market()
	controller.presentation_updated.emit(controller.game.player_view(1))
	await process_frame
	_expect(!(hand.get_child(1) as CardView).is_endangered(), "post-crash stable market left a card marked as endangered")
	_expect(market_detail.text.contains("stable and calm"), "stable market did not reset pressure presentation")
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
	_expect(warning_summary.contains("Market crash in 4 turns"), "warning history did not describe the pending crash")
	var complete_history: Array[Dictionary] = []
	for turn in range(1, 61):
		complete_history.append({"type": "turn_started", "data": {"turn": turn, "actor_id": 1}})
	table._render_history(complete_history, controller.game.public_snapshot()["players"])
	await process_frame
	await process_frame
	var history := table.get_node("Margin/Layout/Main/Sidebar/History/Margin/Content") as RichTextLabel
	_expect(history.text.contains("Turn 1") and history.text.contains("Turn 60"), "event log discarded early match events")
	_expect(history.text.contains("────────"), "event log did not delimit turns")
	var history_scrollbar := history.get_v_scroll_bar()
	_expect(history_scrollbar.value >= maxf(0.0, history_scrollbar.max_value - history_scrollbar.page), "event log did not scroll to the latest event")
	controller.selected_player_count = 10
	controller.restart_game([1], 1)
	await process_frame
	_expect(seats.get_child_count() == 10, "ten-seat match did not render every player seat")
	local_center = arena.seat_center(1)
	var first_opponent_center := arena.seat_center(2)
	var last_opponent_center := arena.seat_center(10)
	_expect(first_opponent_center.y < local_center.y - 40.0 and last_opponent_center.y < local_center.y - 40.0, "ten-player layout did not reserve extra room around the human seat")
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
