extends RefCounted

class_name GameModel


signal turn_started(turn: int, player: Player)
signal trade_proposed(from: Player, to: Player, card: Card)
signal trade_resolved(from: Player, to: Player, offered: Card, received: Array[Card])
signal player_eliminated(player: Player)
signal market_unstable(turns_remaining: int)
signal market_value_destruction(value: int)
signal game_over(ending: String, winners: Array[Player])


const CARDS_PER_PLAYER := 4
const BOREDOM_MULTIPLIER := 10
const PHASE_AWAITING_OFFER := "awaiting_offer"
const PHASE_AWAITING_REPAYMENT := "awaiting_repayment"
const PHASE_TURN_RESOLVED := "turn_resolved"
const PHASE_FINISHED := "finished"


var config: MatchConfig
var configuration_error := ""
var rng := RandomNumberGenerator.new()
var player_types: Array[String]
var players: Array[Player] = []
var max_value: int
var turn_counter := 1
var current_player: Player = null
var phase := PHASE_AWAITING_OFFER
var pending_trade: PendingTrade = null
var last_rejection := ""
var boredom_counter := 0
var countdown_to_destruction := -1
var warning_turns_per_survivor: int
var boredom_multiplier: int
var market_stable := true
var game_finished := false


func _init(configuration: MatchConfig) -> void:
	config = configuration.duplicate() as MatchConfig
	configuration_error = config.validation_error()
	if !configuration_error.is_empty():
		game_finished = true
		return
	rng.seed = config.rng_seed
	player_types = create_player_types()
	players = create_players(config.player_count)
	deal_cards(create_deck(), players)
	max_value = config.player_count
	warning_turns_per_survivor = config.warning_turns_per_survivor
	boredom_multiplier = config.boredom_multiplier


func create_player_types() -> Array[String]:
	return ["Random", "Aggro", "Scared", "OptiHigh", "OptiLow", "OptiRand"]


func create_deck() -> Array[Card]:
	var deck: Array[Card] = []
	for value in range(1, config.player_count + 1):
		for suit in Card.SUITS:
			deck.append(Card.new("%d-%s" % [value, suit.to_lower()], value, suit))
	return deck


func deal_cards(deck: Array[Card], recipients: Array[Player]) -> void:
	shuffle_cards(deck)
	for player in recipients:
		for _card in CARDS_PER_PLAYER:
			player.hand.append(deck.pop_front())


func shuffle_cards(cards: Array[Card]) -> void:
	for index in range(cards.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var swap_card := cards[index]
		cards[index] = cards[swap_index]
		cards[swap_index] = swap_card


func create_players(num_players: int) -> Array[Player]:
	var created_players: Array[Player] = []
	for player_id in range(1, num_players + 1):
		var player := create_player(player_id, player_types[rng.randi_range(0, player_types.size() - 1)])
		player.rng = rng
		created_players.append(player)
	return created_players


func create_player(id: int, player_type: String) -> Player:
	match player_type:
		"Aggro": return AggroPlayer.new(id)
		"Scared": return ScaredPlayer.new(id)
		"OptiHigh": return OptiHighPlayer.new(id)
		"OptiLow": return OptiLowPlayer.new(id)
		"OptiRand": return OptiRandPlayer.new(id)
		_: return RandomPlayer.new(id)


func pick_starting_player() -> void:
	current_player = players[rng.randi_range(0, players.size() - 1)]


func start_next_turn() -> void:
	if game_finished:
		return
	if current_player == null:
		pick_starting_player()
	elif turn_counter > 1:
		select_next_player()
	if current_player == null:
		finish_game("Global Economic Meltdown", [])
		return
	phase = PHASE_AWAITING_OFFER
	pending_trade = null
	last_rejection = ""
	turn_started.emit(turn_counter, current_player)


func select_next_player() -> void:
	if game_finished or players.is_empty():
		return
	var current_index := players.find(current_player)
	if current_index < 0:
		current_index = -1
	for offset in range(1, players.size() + 1):
		var candidate: Player = players[(current_index + offset) % players.size()]
		if candidate.alive:
			current_player = candidate
			return
	current_player = null


func submit_offer(actor_id: int, target_id: int, card_id: String) -> bool:
	if phase != PHASE_AWAITING_OFFER:
		return reject("An offer is not expected in the current phase.")
	var actor := player_by_id(actor_id)
	var target := player_by_id(target_id)
	if actor == null or target == null or actor != current_player or !actor.alive or !target.alive or actor == target:
		return reject("Offer actor or target is invalid.")
	var offered_card := card_owned_by(actor, card_id)
	if offered_card == null:
		return reject("Offered card is not owned by the actor.")
	pending_trade = PendingTrade.new(actor_id, target_id, offered_card)
	trade_proposed.emit(actor, target, offered_card)
	if target.can_return(offered_card.value):
		phase = PHASE_AWAITING_REPAYMENT
		return true
	resolve_acquisition(actor, target)
	return true


func submit_repayment(target_id: int, selected_card_ids: Array[String]) -> bool:
	if phase != PHASE_AWAITING_REPAYMENT or pending_trade == null:
		return reject("A repayment is not expected in the current phase.")
	if target_id != pending_trade.target_id:
		return reject("Repayment came from the wrong target.")
	if selected_card_ids.is_empty() or selected_card_ids.size() != ArrayUtils.distinct(selected_card_ids).size():
		return reject("Repayment must select one or more distinct cards.")
	var actor := player_by_id(pending_trade.actor_id)
	var target := player_by_id(target_id)
	if actor == null or target == null or !actor.alive or !target.alive:
		return reject("Repayment participants are no longer valid.")
	var returned_cards: Array[Card] = []
	for card_id in selected_card_ids:
		var card := card_owned_by(target, card_id)
		if card == null:
			return reject("Repayment contains a card not owned by the target.")
		returned_cards.append(card)
	if Player.cards_value(returned_cards) < pending_trade.offered_card.value:
		return reject("Repayment total is below the offered value.")
	resolve_successful_trade(actor, target, pending_trade.offered_card, returned_cards)
	return true


func resolve_successful_trade(actor: Player, target: Player, offered_card: Card, returned_cards: Array[Card]) -> void:
	phase = PHASE_TURN_RESOLVED
	for card in returned_cards:
		target.hand.erase(card)
	target.hand.append(offered_card)
	actor.hand.erase(offered_card)
	actor.hand.append_array(returned_cards)
	if market_stable:
		boredom_counter += 1
		if returned_cards.size() == 1 and returned_cards[0].value == offered_card.value:
			boredom_counter += 1
	trade_resolved.emit(actor, target, offered_card, returned_cards)
	pending_trade = null


func resolve_acquisition(actor: Player, target: Player) -> void:
	phase = PHASE_TURN_RESOLVED
	pending_trade = null
	actor.hand.append_array(target.hand)
	target.die()
	player_eliminated.emit(target)
	if check_game_end():
		return
	if market_stable:
		destabilize_market()
	else:
		destroy_value()


func reject(reason: String) -> bool:
	last_rejection = reason
	return false


func player_by_id(player_id: int) -> Player:
	for player in players:
		if player.id == player_id:
			return player
	return null


func card_owned_by(player: Player, card_id: String) -> Card:
	for card in player.hand:
		if card.id == card_id:
			return card
	return null


func finalize_turn() -> void:
	if game_finished:
		return
	if !market_stable:
		advance_warning()
		return
	if check_game_end():
		return
	if boredom_counter > boredom_multiplier * alive_players().size():
		destabilize_market()
		advance_warning()


func end_turn() -> void:
	if game_finished or phase != PHASE_TURN_RESOLVED:
		return
	turn_counter += 1


func destabilize_market() -> void:
	if game_finished or !market_stable:
		return
	boredom_counter = 0
	market_stable = false
	countdown_to_destruction = alive_players().size() * warning_turns_per_survivor


func advance_warning() -> void:
	boredom_counter = 0
	market_unstable.emit(countdown_to_destruction)
	countdown_to_destruction -= 1
	if countdown_to_destruction == 0:
		destroy_value()


func destroy_value() -> void:
	if game_finished or market_stable:
		return
	var destroyed_value := max_value
	market_value_destruction.emit(destroyed_value)
	for player in players:
		player.remove_cards_with_value(destroyed_value)
	max_value -= 1
	var bankrupt_players: Array[Player] = []
	for player in alive_players():
		if player.hand.is_empty():
			bankrupt_players.append(player)
	for player in bankrupt_players:
		player.die()
		player_eliminated.emit(player)
	stabilize_market()
	check_game_end()


func stabilize_market() -> void:
	market_stable = true
	boredom_counter = 0
	countdown_to_destruction = -1


func check_game_end() -> bool:
	if game_finished:
		return true
	var alive := alive_players()
	if alive.is_empty():
		finish_game("Global Economic Meltdown", [])
		return true
	if alive.size() == 1:
		finish_game("Monopoly", alive)
		return true
	if is_duopoly_equilibrium(alive):
		finish_game("Duopoly", alive)
		return true
	return false


func is_duopoly_equilibrium(alive: Array[Player]) -> bool:
	if !market_stable or alive.size() != 2 or max_value <= 0:
		return false
	for player in alive:
		for value in range(1, max_value + 1):
			if !player.has_card_value(value):
				return false
	return true


func finish_game(ending: String, winners: Array[Player]) -> void:
	if game_finished:
		return
	game_finished = true
	phase = PHASE_FINISHED
	pending_trade = null
	game_over.emit(ending, winners)


func alive_players() -> Array[Player]:
	return players.filter(func(player: Player): return player.alive)


func _to_string() -> String:
	var current_player_id := -1 if current_player == null else current_player.id
	return "Turn {turn} - {alive_count}/{player_count} alive - Current Player {current_player}\nPlayers: {players}".format({
		"turn": turn_counter,
		"alive_count": alive_players().size(),
		"player_count": players.size(),
		"current_player": current_player_id,
		"players": pretty_print_players(players)
	})


func pretty_print_players(player_list: Array[Player]) -> String:
	var output := "[\n"
	for player in player_list:
		output += "\t" + str(player) + ",\n"
	return output + "]"
