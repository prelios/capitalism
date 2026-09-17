extends Node

class_name GameController

# Constants
const NUM_PLAYERS := 10

# Vars
var game: GameModel
var policies: Dictionary[int, PlayerPolicy] = {}
var policy_rng := RandomNumberGenerator.new()


func play_game() -> void:
	while !game.game_finished:
		# Start next turn
		game.start_next_turn()
		var current := game.current_player
		var current_policy: PlayerPolicy = policies[current.id]
		var current_view := game.player_view(current.id)
		
		var target_id := current_policy.choose_target(current_view)
		var target := game.player_by_id(target_id)
		if target == null:
			game.finish_game("Global Economic Meltdown", [])
			return
		$DebugLogPanel._on_turn_matchup(current, target, current_policy.display_name, policies[target.id].display_name)
		
		var offered_id := current_policy.choose_offer_card_id(current_view, target.id)
		var offered_card: Card = null
		for card in current.hand:
			if card.id == offered_id:
				offered_card = card
				break
		if offered_card == null or !game.submit_offer(current.id, target.id, offered_id):
			game.finish_game("Global Economic Meltdown", [])
			return
		if game.phase == GameModel.PHASE_AWAITING_REPAYMENT:
			var target_policy: PlayerPolicy = policies[target.id]
			game.submit_repayment(target.id, target_policy.choose_repayment_card_ids(game.player_view(target.id), offered_card.value))
		
		game.complete_turn()


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	self.start_game()


func start_game() -> void:
	setup_game()
	connect_game()
	
	# Choose random player to start
	game.pick_starting_player()
	
	$DebugLogPanel._on_game_started(game.players, policies)
	play_game()


func connect_game() -> void:
	var debug_log_panel = $DebugLogPanel
	
	game.turn_started.connect(debug_log_panel._on_turn_started)
	game.trade_proposed.connect(debug_log_panel._on_trade_proposed)
	game.trade_resolved.connect(debug_log_panel._on_trade_resolved)
	game.player_eliminated.connect(debug_log_panel._on_player_eliminated)
	game.market_unstable.connect(debug_log_panel._on_market_unstable)
	game.market_value_destruction.connect(debug_log_panel._on_market_value_destruction)
	game.game_over.connect(debug_log_panel._on_game_over)


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
	
