extends RefCounted

class_name GameModel


signal turn_started(turn: int, player: Player)
signal trade_proposed(from: Player, to: Player, card: int)
signal trade_resolved(from: Player, to: Player, offered: int, received: Array[int])
signal player_eliminated(player: Player)
signal market_unstable(turns_remaining: int)
signal market_value_destruction(value: int)
signal game_over(ending: String, winners: Array[Player])


const CARDS_PER_PLAYER := 4
const BOREDOM_MULTIPLIER := 10


var player_types: Array[String]
var players: Array[Player]
var max_value: int
var turn_counter := 1
var current_player: Player = null
var boredom_counter := 0
var countdown_to_destruction := -1
var market_stable := true
var game_finished := false


func _init(num_players: int) -> void:
	player_types = create_player_types()
	players = create_players(num_players)
	deal_cards(create_deck(num_players), players)
	max_value = num_players


func create_player_types() -> Array[String]:
	return ["Random", "Aggro", "Scared", "OptiHigh", "OptiLow", "OptiRand"]


func create_deck(num_players: int) -> Array[int]:
	var deck: Array[int] = []
	for value in range(1, num_players + 1):
		for copy in range(CARDS_PER_PLAYER):
			deck.append(value)
	return deck


func deal_cards(deck: Array[int], recipients: Array[Player]) -> void:
	deck.shuffle()
	for player in recipients:
		for card in CARDS_PER_PLAYER:
			player.hand.append(deck.pop_front())


func create_players(num_players: int) -> Array[Player]:
	var created_players: Array[Player] = []
	for player_id in range(1, num_players + 1):
		created_players.append(create_player(player_id, player_types.pick_random()))
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
	current_player = players.pick_random()


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


func propose_trade(current: Player, target: Player) -> int:
	if game_finished or current != current_player or !current.alive or target == null or !target.alive or target == current:
		return -1
	var offered_card := current.offer_card(target)
	if !current.hand.has(offered_card):
		return -1
	trade_proposed.emit(current, target, offered_card)
	return offered_card


func resolve_trade(current: Player, target: Player, offered_card: int) -> void:
	if game_finished or current != current_player or !current.alive or target == null or !target.alive or target == current or !current.hand.has(offered_card):
		return
	if target.can_return(offered_card):
		var returned_cards := target.return_cards(offered_card, market_stable, max_value)
		if ArrayUtils.sum_array(returned_cards) < offered_card:
			return
		for card in returned_cards:
			target.hand.erase(card)
		target.hand.append(offered_card)
		current.hand.erase(offered_card)
		current.hand.append_array(returned_cards)
		boredom_counter += 1
		if offered_card == ArrayUtils.sum_array(returned_cards):
			boredom_counter += 1
		trade_resolved.emit(current, target, offered_card, returned_cards)
		return

	current.hand.append_array(target.hand)
	target.die()
	player_eliminated.emit(target)
	if check_game_end():
		return
	if market_stable:
		destabilize_market()
	else:
		destroy_value()


func finalize_turn() -> void:
	if game_finished:
		return
	if !market_stable:
		boredom_counter = 0
		market_unstable.emit(countdown_to_destruction)
		if countdown_to_destruction <= 0:
			destroy_value()
		else:
			countdown_to_destruction -= 1
		return
	if boredom_counter > BOREDOM_MULTIPLIER * alive_players().size():
		destabilize_market()


func end_turn() -> void:
	if game_finished:
		return
	turn_counter += 1


func destabilize_market() -> void:
	if game_finished or !market_stable:
		return
	boredom_counter = 0
	market_stable = false
	countdown_to_destruction = alive_players().size()


func destroy_value() -> void:
	if game_finished or market_stable:
		return
	var destroyed_value := max_value
	market_value_destruction.emit(destroyed_value)
	for player in players:
		ArrayUtils.erase_multiple(player.hand, destroyed_value)
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
	return false


func finish_game(ending: String, winners: Array[Player]) -> void:
	if game_finished:
		return
	game_finished = true
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
