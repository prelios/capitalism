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
