extends Node

class_name GameController

# Constants
const NUM_PLAYERS := 4
const PLAYTEST_AI_DELAY_SECONDS := 2.0
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

# Vars
var game: GameModel
var policies: Dictionary[int, PlayerPolicy] = {}
var policy_rng := RandomNumberGenerator.new()
var match_generation := 0
var ai_delay_seconds := PLAYTEST_AI_DELAY_SECONDS
var fast_headless := true
var fast_forward := false
var ai_turn_pacing_enabled := true
var selected_player_count := NUM_PLAYERS
var selected_conglomerate_index := 0
var _main_menu_open := true

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
	if ai_turn_pacing_enabled and !fast_forward and (!fast_headless or !OS.has_feature("headless")):
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
	
