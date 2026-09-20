extends Node

class_name GameController

# Constants
const NUM_PLAYERS := 4
const CONGLOMERATES: Array[Dictionary] = [
	{"name": "Apex Morrow", "emoji": "🦅"},
	{"name": "Bramble & Bolt", "emoji": "⚡"},
	{"name": "Cinderloop", "emoji": "🔥"},
	{"name": "Dunewell Group", "emoji": "🏜️"},
	{"name": "Evercoil Systems", "emoji": "🌀"},
	{"name": "Fableworks", "emoji": "📚"},
	{"name": "Glimmer Axis", "emoji": "✨"},
	{"name": "Hearthstone Union", "emoji": "🏠"},
	{"name": "Iron Orchard", "emoji": "🍎"},
	{"name": "Juniper & Sons", "emoji": "🌲"},
	{"name": "Kestrel Dynamics", "emoji": "🦜"},
	{"name": "Lunar Vale", "emoji": "🌙"},
	{"name": "Mosaic Foundry", "emoji": "🎨"},
	{"name": "Northstar Mercantile", "emoji": "⭐"},
	{"name": "Opaline Ventures", "emoji": "💎"},
	{"name": "Peregrine Labs", "emoji": "🧪"},
	{"name": "Quarrylight", "emoji": "💡"},
	{"name": "Rook & River", "emoji": "♜"},
	{"name": "Solstice Works", "emoji": "☀️"},
	{"name": "Tanglewood Collective", "emoji": "🌿"},
]

@export var auto_start := false
@export_group("Trade presentation timing")
@export var target_selection_seconds := 0.65
@export var offer_travel_seconds := 0.85
@export var offer_read_seconds := 0.45
@export var repayment_decision_seconds := 0.65
@export var repayment_travel_seconds := 0.85
@export var repayment_read_seconds := 0.7
@export var exchange_seconds := 0.9
@export var arrival_seconds := 0.8
@export var acquisition_seconds := 1.0
@export var crash_interrupt_seconds := 1.0
@export var hand_update_beat_seconds := 0.5

# Vars
var game: GameModel
var policies: Dictionary[int, PlayerPolicy] = {}
var policy_rng := RandomNumberGenerator.new()
var match_generation := 0
var presentation_speed_scale := 1.0
var fast_headless := true
var fast_forward := false
var ai_turn_pacing_enabled := true
var selected_player_count := NUM_PLAYERS
var selected_conglomerate_index := 0
var _main_menu_open := true
var _trade_context: Dictionary = {}

signal decision_requested(actor_id: int, phase: String, view: PlayerView)
signal action_resolved
signal presentation_updated(view: PlayerView)
signal action_rejected(reason: String)
signal trade_presentation_updated(presentation: Dictionary)


var local_player_id := 1


func play_game(generation: int) -> void:
	while generation == match_generation and !game.game_finished:
		_clear_trade_presentation()
		game.start_next_turn()
		_publish_presentation()
		if !await _resolve_offer(generation):
			return
		if !await _present_offer(generation):
			return
		if game.phase == GameModel.PHASE_AWAITING_REPAYMENT and !await _resolve_repayment(generation):
			return
		if _trade_context.get("acquisition", false):
			if !await _present_acquisition(generation):
				return
		elif game.phase == GameModel.PHASE_TURN_RESOLVED and !_trade_context.get("returned_cards", []).is_empty():
			if !await _present_successful_trade(generation):
				return
		if generation != match_generation or game.game_finished:
			_publish_presentation()
			return
		if !await _complete_turn_with_feedback(generation):
			return


func _resolve_offer(generation: int) -> bool:
	var actor := game.current_player
	if policies.has(actor.id):
		var policy: PlayerPolicy = policies[actor.id]
		var view := game.player_view(actor.id)
		var target_id := policy.choose_target(view)
		var target := game.player_by_id(target_id)
		if target == null:
			return false
		var offered_id := policy.choose_offer_card_id(view, target_id)
		var offered := game.card_owned_by(actor, offered_id)
		if offered == null:
			return false
		_trade_context = _new_trade_context(actor.id, target_id, game.public_card(offered))
		if !await _present_stage("targeting", target_selection_seconds, generation):
			return false
		return submit_offer(actor.id, target_id, offered_id, generation)
	decision_requested.emit(actor.id, GameModel.PHASE_AWAITING_OFFER, game.player_view(actor.id))
	return await _wait_for_action(generation, GameModel.PHASE_AWAITING_OFFER)


func _resolve_repayment(generation: int) -> bool:
	var target := game.player_by_id(game.pending_trade.target_id)
	if policies.has(target.id):
		if !await _wait_for_presentation(repayment_decision_seconds, generation):
			return false
		var offered := game.pending_trade.offered_card
		var policy: PlayerPolicy = policies[target.id]
		return submit_repayment(target.id, policy.choose_repayment_card_ids(game.player_view(target.id), offered.value))
	decision_requested.emit(target.id, GameModel.PHASE_AWAITING_REPAYMENT, game.player_view(target.id))
	return await _wait_for_action(generation, GameModel.PHASE_AWAITING_REPAYMENT)


func _wait_for_presentation(duration: float, generation: int) -> bool:
	var running_headless := DisplayServer.get_name() == "headless"
	if ai_turn_pacing_enabled and !fast_forward and (!fast_headless or !running_headless) and duration > 0.0:
		await get_tree().create_timer(duration * presentation_speed_scale).timeout
	return generation == match_generation


func _wait_for_action(generation: int, expected_phase: String) -> bool:
	while generation == match_generation and !game.game_finished and game.phase == expected_phase:
		await action_resolved
	return generation == match_generation and game.phase != expected_phase


func submit_offer(actor_id: int, target_id: int, card_id: String, generation := match_generation) -> bool:
	if generation != match_generation or game == null:
		return false
	var actor := game.player_by_id(actor_id)
	var offered := game.card_owned_by(actor, card_id) if actor != null else null
	if offered == null:
		if !game.submit_offer(actor_id, target_id, card_id):
			action_rejected.emit(game.last_rejection)
		return false
	_trade_context = _new_trade_context(actor_id, target_id, game.public_card(offered))
	if !game.submit_offer(actor_id, target_id, card_id):
		action_rejected.emit(game.last_rejection)
		return false
	_capture_offer_outcome()
	action_resolved.emit()
	return true


func submit_repayment(actor_id: int, card_ids: Array[String], generation := match_generation) -> bool:
	if generation != match_generation or game == null:
		return false
	var target := game.player_by_id(actor_id)
	var returned_cards: Array = []
	if target != null:
		for card_id in card_ids:
			var card := game.card_owned_by(target, card_id)
			if card != null:
				returned_cards.append(game.public_card(card))
	if !game.submit_repayment(actor_id, card_ids):
		action_rejected.emit(game.last_rejection)
		return false
	_trade_context["returned_cards"] = returned_cards
	action_resolved.emit()
	return true


func _new_trade_context(actor_id: int, target_id: int, offered_card: Dictionary) -> Dictionary:
	return {"actor_id": actor_id, "target_id": target_id, "offered_card": offered_card.duplicate(true), "returned_cards": [], "acquisition": false, "crash_value": -1}


func _capture_offer_outcome() -> void:
	if game.phase == GameModel.PHASE_AWAITING_REPAYMENT:
		return
	_trade_context["acquisition"] = true
	var history := game.public_history()
	for index in range(history.size() - 1, -1, -1):
		var event: Dictionary = history[index]
		if event["type"] == "trade_proposed":
			break
		if event["type"] == "market_crashed":
			_trade_context["crash_value"] = event["data"]["value"]


func _present_offer(generation: int) -> bool:
	if !await _present_stage("offer_moving", offer_travel_seconds, generation):
		return false
	if !await _present_stage("offer_ready", offer_read_seconds, generation):
		return false
	if game.phase == GameModel.PHASE_AWAITING_REPAYMENT:
		_publish_presentation()
	return generation == match_generation


func _present_successful_trade(generation: int) -> bool:
	if !await _present_stage("repayment_moving", repayment_travel_seconds, generation):
		return false
	if !await _present_stage("repayment_ready", repayment_read_seconds, generation):
		return false
	if !await _present_stage("exchange", exchange_seconds, generation):
		return false
	if !await _present_stage("arrival", arrival_seconds, generation):
		return false
	_publish_presentation()
	return await _present_stage("settled", hand_update_beat_seconds, generation)


func _present_acquisition(generation: int) -> bool:
	if !await _present_stage("acquisition", acquisition_seconds, generation):
		return false
	if _trade_context.get("crash_value", -1) > 0:
		if !await _present_stage("crash", crash_interrupt_seconds, generation):
			return false
	_publish_presentation()
	return await _present_stage("settled", hand_update_beat_seconds, generation)


func _complete_turn_with_feedback(generation: int) -> bool:
	var history_size := game.public_history().size()
	game.complete_turn()
	var history := game.public_history()
	for index in range(history_size, history.size()):
		var event: Dictionary = history[index]
		if event["type"] == "market_crashed":
			_trade_context["crash_value"] = event["data"]["value"]
			if !await _present_stage("crash", crash_interrupt_seconds, generation):
				return false
			break
	_publish_presentation()
	return generation == match_generation


func _present_stage(stage: String, duration: float, generation: int) -> bool:
	var presentation := _trade_context.duplicate(true)
	presentation["stage"] = stage
	presentation["duration"] = duration * presentation_speed_scale
	trade_presentation_updated.emit(presentation)
	return await _wait_for_presentation(duration, generation)


func _clear_trade_presentation() -> void:
	_trade_context.clear()
	trade_presentation_updated.emit({"stage": "idle", "duration": 0.0})


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$GameTable.bind_controller(self)
	if auto_start and _main_menu_open:
		start_game()
	elif _main_menu_open:
		$GameTable.show_main_menu()


func start_game() -> void:
	start_match(selected_player_count)


func start_match(player_count: int) -> void:
	if player_count < MatchConfig.MIN_PLAYERS or player_count > MatchConfig.MAX_PLAYERS:
		return
	selected_player_count = player_count
	fast_forward = false
	_main_menu_open = false
	restart_game([local_player_id])


func start_rematch() -> void:
	fast_forward = false
	_main_menu_open = false
	restart_game([local_player_id])


func return_to_main_menu() -> void:
	match_generation += 1
	fast_forward = false
	_main_menu_open = true
	action_resolved.emit()
	_clear_trade_presentation()
	if $GameTable.is_node_ready():
		$GameTable.show_main_menu(selected_player_count)


func set_fast_forward(enabled: bool) -> void:
	fast_forward = enabled


func set_ai_turn_pacing(enabled: bool) -> void:
	ai_turn_pacing_enabled = enabled


func conglomerate_options() -> Array[Dictionary]:
	return CONGLOMERATES.duplicate(true)


func set_player_one_conglomerate(index: int) -> void:
	selected_conglomerate_index = clampi(index, 0, CONGLOMERATES.size() - 1)


func restart_game(human_player_ids: Array[int] = [], starting_player_id := -1) -> void:
	match_generation += 1
	action_resolved.emit()
	_clear_trade_presentation()
	setup_game()
	_main_menu_open = false
	if $GameTable.is_node_ready():
		$GameTable.show_match()
	local_player_id = human_player_ids[0] if !human_player_ids.is_empty() else 1
	for player_id in human_player_ids:
		assign_human(player_id)
	game.current_player = game.player_by_id(starting_player_id) if starting_player_id > 0 else game.player_by_id(1)
	if game.current_player == null:
		game.pick_starting_player()
	_publish_presentation()
	play_game(match_generation)


func _publish_presentation() -> void:
	if game == null:
		return
	var view := game.player_view(local_player_id)
	if view != null:
		presentation_updated.emit(view)


func setup_game() -> void:
	self.game = GameModel.new(MatchConfig.for_player_count(selected_player_count, 1))
	_assign_conglomerates()
	policy_rng.seed = game.config.rng_seed + 1
	policies.clear()
	for player in game.players:
		var policy: PlayerPolicy
		match (player.id - 1) % 3:
			0: policy = RandomPlayer.new(policy_rng)
			1: policy = AggroPlayer.new(policy_rng)
			_: policy = ScaredPlayer.new(policy_rng)
		assign_policy(player.id, policy)


func _assign_conglomerates() -> void:
	var available := conglomerate_options()
	var player_one_identity: Dictionary = available.pop_at(selected_conglomerate_index)
	_apply_conglomerate_identity(game.player_by_id(1), player_one_identity)
	_shuffle_conglomerates(available)
	for player in game.players:
		if player.id != 1:
			_apply_conglomerate_identity(player, available.pop_front())


func _shuffle_conglomerates(identities: Array[Dictionary]) -> void:
	for index in range(identities.size() - 1, 0, -1):
		var swap_index := game.rng.randi_range(0, index)
		var identity := identities[index]
		identities[index] = identities[swap_index]
		identities[swap_index] = identity


func _apply_conglomerate_identity(player: Player, identity: Dictionary) -> void:
	player.company_name = identity["name"]
	player.company_emoji = identity["emoji"]


func assign_policy(player_id: int, policy: PlayerPolicy) -> bool:
	if game == null or game.player_by_id(player_id) == null or policy == null:
		return false
	policies[player_id] = policy
	return true


func assign_human(player_id: int) -> bool:
	if game == null or game.player_by_id(player_id) == null:
		return false
	policies.erase(player_id)
	return true
	
