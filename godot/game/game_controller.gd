extends Node

class_name GameController

# Constants
const NUM_PLAYERS := 10

# Vars
var game: GameModel


func play_game():
	while !game.game_finished:
		# Start next turn
		game.start_next_turn()
		var current = game.current_player
		
		# Current player chooses target
		var target = current.choose_target(game.alive_players())
		$DebugLogPanel._on_turn_matchup(current, target)
		
		# Propose trade
		var offered_card := current.offer_card(target)
		game.submit_offer(current.id, target.id, offered_card.id)
		if game.phase == GameModel.PHASE_AWAITING_REPAYMENT:
			var returned_cards := target.return_cards(offered_card.value, game.market_stable, game.max_value)
			var returned_ids: Array[String] = []
			for returned_card in returned_cards:
				returned_ids.append(returned_card.id)
			game.submit_repayment(target.id, returned_ids)
		
		game.complete_turn()


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	self.start_game()


func start_game() -> void:
	setup_game()
	connect_game()
	
	# Choose random player to start
	game.pick_starting_player()
	
	$DebugLogPanel._on_game_started(game.players)
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
	
