extends Node

class_name GameController

# Constants
const NUM_PLAYERS := 4

@export var auto_start := true

# Vars
var game: GameModel
var policies: Dictionary[int, PlayerPolicy] = {}
var policy_rng := RandomNumberGenerator.new()
var match_generation := 0
var ai_delay_seconds := 0.25
var fast_headless := true

signal decision_requested(actor_id: int, phase: String, view: PlayerView)
signal action_resolved
signal presentation_updated(view: PlayerView)
signal action_rejected(reason: String)


var local_player_id := 1


func play_game(generation: int) -> void:
	while generation == match_generation and !game.game_finished:
		game.start_next_turn()
		_publish_presentation()
		if !await _resolve_offer(generation):
			return
		if game.phase == GameModel.PHASE_AWAITING_REPAYMENT and !await _resolve_repayment(generation):
			return
		if generation != match_generation or game.game_finished:
			_publish_presentation()
			return
		game.complete_turn()
		_publish_presentation()


func _resolve_offer(generation: int) -> bool:
	var actor := game.current_player
	if policies.has(actor.id):
		if !await _wait_for_ai(generation):
			return false
		var policy: PlayerPolicy = policies[actor.id]
		var view := game.player_view(actor.id)
		var target_id := policy.choose_target(view)
		var target := game.player_by_id(target_id)
		if target == null:
			return false
		var target_name := "Human" if !policies.has(target.id) else policies[target.id].display_name
		$DebugLogPanel._on_turn_matchup(actor, target, policy.display_name, target_name)
		return submit_offer(actor.id, target_id, policy.choose_offer_card_id(view, target_id))
	decision_requested.emit(actor.id, GameModel.PHASE_AWAITING_OFFER, game.player_view(actor.id))
	return await _wait_for_action(generation, GameModel.PHASE_AWAITING_OFFER)


func _resolve_repayment(generation: int) -> bool:
	var target := game.player_by_id(game.pending_trade.target_id)
	if policies.has(target.id):
		if !await _wait_for_ai(generation):
			return false
		var offered := game.pending_trade.offered_card
		var policy: PlayerPolicy = policies[target.id]
		return submit_repayment(target.id, policy.choose_repayment_card_ids(game.player_view(target.id), offered.value))
	decision_requested.emit(target.id, GameModel.PHASE_AWAITING_REPAYMENT, game.player_view(target.id))
	return await _wait_for_action(generation, GameModel.PHASE_AWAITING_REPAYMENT)


func _wait_for_ai(generation: int) -> bool:
	if !fast_headless or !OS.has_feature("headless"):
		await get_tree().create_timer(ai_delay_seconds).timeout
	return generation == match_generation and !game.game_finished


func _wait_for_action(generation: int, expected_phase: String) -> bool:
	while generation == match_generation and !game.game_finished and game.phase == expected_phase:
		await action_resolved
	return generation == match_generation and !game.game_finished


func submit_offer(actor_id: int, target_id: int, card_id: String, generation := match_generation) -> bool:
	if generation != match_generation or game == null:
		return false
	if !game.submit_offer(actor_id, target_id, card_id):
		action_rejected.emit(game.last_rejection)
		return false
	_publish_presentation()
	action_resolved.emit()
	return true


func submit_repayment(actor_id: int, card_ids: Array[String], generation := match_generation) -> bool:
	if generation != match_generation or game == null:
		return false
	if !game.submit_repayment(actor_id, card_ids):
		action_rejected.emit(game.last_rejection)
		return false
	_publish_presentation()
	action_resolved.emit()
	return true


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$GameTable.bind_controller(self)
	if auto_start:
		start_game()


func start_game() -> void:
	restart_game([local_player_id])


func restart_game(human_player_ids: Array[int] = [], starting_player_id := -1) -> void:
	match_generation += 1
	_disconnect_game()
	setup_game()
	local_player_id = human_player_ids[0] if !human_player_ids.is_empty() else 1
	for player_id in human_player_ids:
		assign_human(player_id)
	connect_game()
	game.current_player = game.player_by_id(starting_player_id) if starting_player_id > 0 else null
	if game.current_player == null:
		game.pick_starting_player()
	$DebugLogPanel._on_game_started(game.players, policies)
	_publish_presentation()
	play_game(match_generation)


func _publish_presentation() -> void:
	if game == null:
		return
	var view := game.player_view(local_player_id)
	if view != null:
		presentation_updated.emit(view)


func connect_game() -> void:
	var debug_log_panel = $DebugLogPanel
	
	game.turn_started.connect(debug_log_panel._on_turn_started)
	game.trade_proposed.connect(debug_log_panel._on_trade_proposed)
	game.trade_resolved.connect(debug_log_panel._on_trade_resolved)
	game.player_eliminated.connect(debug_log_panel._on_player_eliminated)
	game.market_unstable.connect(debug_log_panel._on_market_unstable)
	game.market_value_destruction.connect(debug_log_panel._on_market_value_destruction)
	game.game_over.connect(debug_log_panel._on_game_over)


func _disconnect_game() -> void:
	if game == null:
		return
	var debug_log_panel = $DebugLogPanel
	if game.turn_started.is_connected(debug_log_panel._on_turn_started):
		game.turn_started.disconnect(debug_log_panel._on_turn_started)
	if game.trade_proposed.is_connected(debug_log_panel._on_trade_proposed):
		game.trade_proposed.disconnect(debug_log_panel._on_trade_proposed)
	if game.trade_resolved.is_connected(debug_log_panel._on_trade_resolved):
		game.trade_resolved.disconnect(debug_log_panel._on_trade_resolved)
	if game.player_eliminated.is_connected(debug_log_panel._on_player_eliminated):
		game.player_eliminated.disconnect(debug_log_panel._on_player_eliminated)
	if game.market_unstable.is_connected(debug_log_panel._on_market_unstable):
		game.market_unstable.disconnect(debug_log_panel._on_market_unstable)
	if game.market_value_destruction.is_connected(debug_log_panel._on_market_value_destruction):
		game.market_value_destruction.disconnect(debug_log_panel._on_market_value_destruction)
	if game.game_over.is_connected(debug_log_panel._on_game_over):
		game.game_over.disconnect(debug_log_panel._on_game_over)


func setup_game() -> void:
	self.game = GameModel.new(MatchConfig.for_player_count(NUM_PLAYERS, 1))
	policy_rng.seed = game.config.rng_seed + 1
	policies.clear()
	for player in game.players:
		var policy: PlayerPolicy
		match (player.id - 1) % 3:
			0: policy = RandomPlayer.new(policy_rng)
			1: policy = AggroPlayer.new(policy_rng)
			_: policy = ScaredPlayer.new(policy_rng)
		assign_policy(player.id, policy)


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
	
