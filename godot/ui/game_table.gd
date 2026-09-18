extends Control

class_name GameTable


const CARD_VIEW_SCENE := preload("res://ui/card_view.tscn")
const PLAYER_SEAT_SCENE := preload("res://ui/player_seat_panel.tscn")


var _controller: GameController
var _selected_card_ids: Array[String] = []
var _last_view: PlayerView

@onready var _turn_label: Label = $Margin/Layout/Header/Margin/Content/Turn
@onready var _market_label: Label = $Margin/Layout/Header/Margin/Content/Market
@onready var _seats: FlowContainer = $Margin/Layout/Main/Center/SeatScroll/Seats
@onready var _trade_label: Label = $Margin/Layout/Main/Center/Trade/Margin/TradeStatus
@onready var _market_detail: Label = $Margin/Layout/Main/Sidebar/Market/Margin/Content
@onready var _history: RichTextLabel = $Margin/Layout/Main/Sidebar/History/Margin/Content
@onready var _hand_title: Label = $Margin/Layout/Hand/Margin/Content/Title
@onready var _hand: FlowContainer = $Margin/Layout/Hand/Margin/Content/HandScroll/Hand


func bind_controller(controller: GameController) -> void:
	_controller = controller
	if !_controller.presentation_updated.is_connected(_render):
		_controller.presentation_updated.connect(_render)


func selected_card_ids() -> Array[String]:
	return _selected_card_ids.duplicate()


func _render(view: PlayerView) -> void:
	_last_view = view
	var state := view.public_state()
	_turn_label.text = "Turn %d · Player %d" % [state["turn"], state["current_player_id"]]
	_market_label.text = "Market stable" if state["market_stable"] else "Instability: value %d" % state["unstable_value"]
	_market_detail.text = _market_description(state)
	_render_seats(view.players(), state, view.requester_id)
	_render_trade(state)
	_render_history(view.public_history())
	_render_hand(view.own_hand())


func _render_seats(players: Array[Dictionary], state: Dictionary, local_player_id: int) -> void:
	_clear_container(_seats)
	var trade: Dictionary = state["pending_trade"]
	var target_id: int = -1 if trade.is_empty() else trade["target_id"]
	for player in players:
		var seat := PLAYER_SEAT_SCENE.instantiate() as PlayerSeatPanel
		_seats.add_child(seat)
		seat.set_public_player(player, player["player_id"] == local_player_id, player["player_id"] == state["current_player_id"], player["player_id"] == target_id)


func _render_trade(state: Dictionary) -> void:
	var trade: Dictionary = state["pending_trade"]
	if trade.is_empty():
		_trade_label.text = "Trade floor ready\nChoose a company and a card when it is your turn."
		return
	var offered: Dictionary = trade["offered_card"]
	_trade_label.text = "Player %d offers %s %d to Player %d" % [trade["actor_id"], offered["suit"], offered["value"], trade["target_id"]]


func _render_hand(cards: Array[Dictionary]) -> void:
	var present_ids: Array[String] = []
	for card in cards:
		present_ids.append(card["id"])
	_selected_card_ids = _selected_card_ids.filter(func(card_id: String): return present_ids.has(card_id))
	_clear_container(_hand)
	_hand_title.text = "Your private hand · %d cards" % cards.size()
	for card in cards:
		var card_view := CARD_VIEW_SCENE.instantiate() as CardView
		card_view.set_card(card)
		card_view.set_selected(_selected_card_ids.has(card["id"]))
		card_view.card_selection_changed.connect(_on_card_selection_changed)
		_hand.add_child(card_view)


func _render_history(events: Array[Dictionary]) -> void:
	var lines: PackedStringArray = []
	for event in events.slice(max(0, events.size() - 6)):
		lines.append(_event_summary(event))
	_history.text = "\n".join(lines)


func _market_description(state: Dictionary) -> String:
	if state["market_stable"]:
		return "Stable market\nHighest active value: %d" % state["max_value"]
	return "Warning for value %d\n%d completed turns remaining" % [state["unstable_value"], state["turns_remaining"]]


func _event_summary(event: Dictionary) -> String:
	var data: Dictionary = event["data"]
	match event["type"]:
		"turn_started": return "Turn %d: Player %d" % [data["turn"], data["actor_id"]]
		"trade_proposed": return "P%d offered %s %d to P%d" % [data["actor_id"], data["card"]["suit"], data["card"]["value"], data["target_id"]]
		"trade_resolved": return "P%d and P%d traded" % [data["actor_id"], data["target_id"]]
		"player_acquired": return "P%d acquired P%d" % [data["acquirer_id"], data["victim_id"]]
		"market_warning_started": return "Warning: value %d" % data["value"]
		"market_crashed": return "Market removed value %d" % data["value"]
		"game_finished": return data["ending"]
		_: return event["type"]


func _on_card_selection_changed(card_id: String, selected: bool) -> void:
	if selected and !_selected_card_ids.has(card_id):
		_selected_card_ids.append(card_id)
	elif !selected:
		_selected_card_ids.erase(card_id)


func _clear_container(container: Container) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
