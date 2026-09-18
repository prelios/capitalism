extends Control

class_name GameTable


const CARD_VIEW_SCENE := preload("res://ui/card_view.tscn")
const PLAYER_SEAT_SCENE := preload("res://ui/player_seat_panel.tscn")


var _controller: GameController
var _selected_card_ids: Array[String] = []
var _last_view: PlayerView
var _decision_actor_id := -1
var _decision_phase := ""
var _selected_target_id := -1
var _feedback := ""

@onready var _turn_label: Label = $Margin/Layout/Header/Margin/Content/Turn
@onready var _market_label: Label = $Margin/Layout/Header/Margin/Content/Market
@onready var _seats: FlowContainer = $Margin/Layout/Main/Center/SeatScroll/Seats
@onready var _trade_label: Label = $Margin/Layout/Main/Center/Trade/Margin/Content/TradeStatus
@onready var _selection_label: Label = $Margin/Layout/Main/Center/Trade/Margin/Content/Selection
@onready var _confirm: Button = $Margin/Layout/Main/Center/Trade/Margin/Content/Confirm
@onready var _market_detail: Label = $Margin/Layout/Main/Sidebar/Market/Margin/Content
@onready var _history: RichTextLabel = $Margin/Layout/Main/Sidebar/History/Margin/Content
@onready var _hand_title: Label = $Margin/Layout/Hand/Margin/Content/Title
@onready var _hand: FlowContainer = $Margin/Layout/Hand/Margin/Content/HandScroll/Hand


func bind_controller(controller: GameController) -> void:
	_controller = controller
	if !_controller.presentation_updated.is_connected(_render):
		_controller.presentation_updated.connect(_render)
	_controller.decision_requested.connect(_on_decision_requested)
	_controller.action_rejected.connect(_on_action_rejected)
	_confirm.pressed.connect(_confirm_selection)


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
	_update_action_controls(state)


func _render_seats(players: Array[Dictionary], state: Dictionary, local_player_id: int) -> void:
	_clear_container(_seats)
	var trade: Dictionary = state["pending_trade"]
	var target_id: int = _selected_target_id if _is_offer_decision() else (-1 if trade.is_empty() else trade["target_id"])
	for player in players:
		var seat := PLAYER_SEAT_SCENE.instantiate() as PlayerSeatPanel
		_seats.add_child(seat)
		seat.set_public_player(player, player["player_id"] == local_player_id, player["player_id"] == state["current_player_id"], player["player_id"] == target_id)
		seat.set_target_selectable(_is_offer_decision() and player["alive"] and player["player_id"] != local_player_id)
		seat.target_selected.connect(_on_target_selected)


func _render_trade(state: Dictionary) -> void:
	var trade: Dictionary = state["pending_trade"]
	if trade.is_empty():
		_trade_label.text = _latest_public_update()
		return
	var offered: Dictionary = trade["offered_card"]
	_trade_label.text = "Player %d offers %s to Player %d\nAwaiting repayment." % [trade["actor_id"], _card_description(offered), trade["target_id"]]


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
	for event in events.slice(max(0, events.size() - 12)):
		lines.append(_event_summary(event))
	_history.text = "\n".join(lines)
	_history.scroll_to_line(max(0, _history.get_line_count() - 1))


func _latest_public_update() -> String:
	if _last_view == null:
		return "Trade floor ready"
	var events := _last_view.public_history()
	if events.is_empty():
		return "Trade floor ready\nChoose a company and a card when it is your turn."
	return _event_summary(events.back())


func _market_description(state: Dictionary) -> String:
	if state["market_stable"]:
		return "Stable market\nHighest active value: %d" % state["max_value"]
	return "Warning for value %d\n%d completed turns remaining" % [state["unstable_value"], state["turns_remaining"]]


func _event_summary(event: Dictionary) -> String:
	var data: Dictionary = event["data"]
	match event["type"]:
		"turn_started": return "Turn %d — Player %d acts" % [data["turn"], data["actor_id"]]
		"trade_proposed": return "P%d offered %s to P%d" % [data["actor_id"], _card_description(data["card"]), data["target_id"]]
		"trade_resolved": return "Trade: P%d gave %s; P%d returned %s" % [data["actor_id"], _card_description(data["offered"]), data["target_id"], _cards_description(data["returned"])]
		"player_acquired": return "Acquisition: P%d acquired P%d and %s" % [data["acquirer_id"], data["victim_id"], _cards_description(data["cards"])]
		"market_warning_started": return "Market warning: value %d, %d turns remaining" % [data["value"], data["turns_remaining"]]
		"market_warning_updated": return "Market warning: value %d, %d turns remaining after this turn" % [data["value"], max(0, data["turns_remaining"] - 1)]
		"market_crashed": return "Crash: removed all value %d%s" % [data["value"], _bankruptcy_description(data["bankrupt_player_ids"])]
		"game_finished": return "%s — winners: %s" % [data["ending"], _player_list(data["winner_ids"])]
		_: return event["type"]


func _card_description(card: Dictionary) -> String:
	return "%s %d" % [card["suit"], card["value"]]


func _cards_description(cards: Array) -> String:
	if cards.is_empty():
		return "no cards"
	var descriptions: PackedStringArray = []
	for card: Dictionary in cards:
		descriptions.append(_card_description(card))
	return ", ".join(descriptions)


func _bankruptcy_description(player_ids: Array) -> String:
	return "; bankrupt: %s" % _player_list(player_ids) if !player_ids.is_empty() else ""


func _player_list(player_ids: Array) -> String:
	if player_ids.is_empty():
		return "none"
	var names: PackedStringArray = []
	for player_id in player_ids:
		names.append("P%d" % player_id)
	return ", ".join(names)


func _on_card_selection_changed(card_id: String, selected: bool) -> void:
	if selected and _is_offer_decision():
		_selected_card_ids = [card_id]
		_render(_last_view)
	elif selected and !_selected_card_ids.has(card_id):
		_selected_card_ids.append(card_id)
	elif !selected:
		_selected_card_ids.erase(card_id)
	_update_action_controls(_last_view.public_state())


func _on_decision_requested(actor_id: int, phase: String, _view: PlayerView) -> void:
	_decision_actor_id = actor_id
	_decision_phase = phase
	_selected_card_ids.clear()
	_selected_target_id = -1
	_feedback = ""
	if _last_view != null:
		_render(_last_view)


func _on_target_selected(player_id: int) -> void:
	_selected_target_id = player_id
	_feedback = ""
	_render(_last_view)


func _update_action_controls(state: Dictionary) -> void:
	var enabled := false
	if _is_offer_decision():
		_trade_label.text = "Choose one card and a company to make your offer."
		enabled = _selected_card_ids.size() == 1 and _selected_target_id > 0
		_selection_label.text = "Card: %s · Target: %s%s" % [_selected_card_ids[0] if _selected_card_ids.size() == 1 else "none", "Player %d" % _selected_target_id if _selected_target_id > 0 else "none", _feedback]
	elif _is_repayment_decision() and !state["pending_trade"].is_empty():
		var offered: Dictionary = state["pending_trade"]["offered_card"]
		var total := _selected_value()
		_trade_label.text = "Repay the offered value %d with any legal subset." % offered["value"]
		enabled = !_selected_card_ids.is_empty() and total >= offered["value"]
		_selection_label.text = "Selected total: %d / %d%s" % [total, offered["value"], _feedback]
	else:
		_selection_label.text = _feedback
		_confirm.disabled = true
		return
	_confirm.disabled = !enabled


func _confirm_selection() -> void:
	if _controller == null or _confirm.disabled:
		return
	var submitted := false
	if _is_offer_decision():
		submitted = _controller.submit_offer(_local_actor_id(), _selected_target_id, _selected_card_ids[0])
	elif _is_repayment_decision():
		submitted = _controller.submit_repayment(_local_actor_id(), _selected_card_ids)
	if submitted:
		_decision_phase = ""
		_selected_card_ids.clear()
		_selected_target_id = -1
		_render(_last_view)


func _on_action_rejected(reason: String) -> void:
	_feedback = "\n%s" % reason
	if _last_view != null:
		_update_action_controls(_last_view.public_state())


func _is_offer_decision() -> bool:
	if _last_view == null:
		return _decision_phase == GameModel.PHASE_AWAITING_OFFER
	var state := _last_view.public_state()
	return state["phase"] == GameModel.PHASE_AWAITING_OFFER and state["current_player_id"] == _last_view.requester_id


func _is_repayment_decision() -> bool:
	if _last_view == null:
		return _decision_phase == GameModel.PHASE_AWAITING_REPAYMENT
	var state := _last_view.public_state()
	var trade: Dictionary = state["pending_trade"]
	return state["phase"] == GameModel.PHASE_AWAITING_REPAYMENT and !trade.is_empty() and trade["target_id"] == _last_view.requester_id


func _local_actor_id() -> int:
	return _last_view.requester_id if _last_view != null else _decision_actor_id


func _selected_value() -> int:
	var total := 0
	for card in _last_view.own_hand():
		if _selected_card_ids.has(card["id"]):
			total += card["value"]
	return total


func _clear_container(container: Container) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
