extends Node

class_name GameModel


# Signals
signal turn_started(player: Player)
signal trade_proposed(from: Player, to: Player, card: int)
signal trade_resolved(from: Player, to: Player, offered: int, received: Array[int])
signal player_eliminated(p: Player)
signal market_unstable(turns_remaining: int)
signal market_value_destruction(value: int)
signal game_over(ending: String, winners: Array[Player])

# Constants
const CARDS_PER_PLAYER := 4
const BOREDOM_MULTIPLIER := 10

# Vars
var player_types: Array[String]
var players: Array[Player]
var max_value: int
var turn_counter := 1
var current_player: Player
var boredom_counter := 0
var countdown_to_destruction = 0
var market_stable := true
var game_finished := false

# Constructor
func _init(num_players: int):
	# Create deck, players, and deal cards
	var deck = create_deck(num_players)
	player_types = create_player_types()
	players = create_players(num_players)
	deal_cards(deck, players)
	# Set max_value
	max_value = num_players
	# Init player types
	player_types = create_player_types()


func create_player_types() -> Array[String]:
	return ["Random", "Aggro", "Scared", "OptiHigh", "OptiLow", "OptiRand"]

func create_deck(num_players: int) -> Array[int]:
	var deck: Array[int] = []
	for i in range(num_players):
		for j in range(CARDS_PER_PLAYER):
			deck.append(i + 1)
	return deck

func deal_cards(deck, players) -> void:
	deck.shuffle()
	for player in players:
		for i in range(CARDS_PER_PLAYER):
			player.hand.append(deck.pop_front())


func create_players(num_players: int) -> Array[Player]:
	var players: Array[Player] = []
	for i in range(num_players):
		players.append(create_player(i + 1, self.player_types.pick_random()))
		#players.append(RandomPlayer.new(i + 1))
		#players.append(AggroPlayer.new(i + 1))
	return players

func create_player(id: int, player_type: String) -> Player:
	match player_type:
		"Aggro": return AggroPlayer.new(id)
		"Scared": return ScaredPlayer.new(id)
		"OptiHigh": return OptiHighPlayer.new(id)
		"OptiLow": return OptiLowPlayer.new(id)
		"OptiRand": return OptiRandPlayer.new(id)
		_: return RandomPlayer.new(id)


func start_next_turn() -> void:
	select_next_player()
	turn_started.emit(turn_counter, current_player)


func finalize_turn() -> void:
	# Check if market is unstable, destroy value if countdown is done
	if !market_stable:
		boredom_counter = 0
		market_unstable.emit(countdown_to_destruction)
		if countdown_to_destruction == 0:
			destroy_value()
		countdown_to_destruction -= 1

	# If boredom counter gets too high, trigger market instability
	print("Boredom counter: ", boredom_counter)
	if boredom_counter > (BOREDOM_MULTIPLIER * alive_players().size()):
		print("Game getting stale, triggering market crash!")
		destabilize_market()


func check_game_end() -> void:
	# Single player alive: Monopoly victory
	if alive_players().size() == 1:
		game_finished = true
		game_over.emit("Monopoly", alive_players())
	
	# Check for Market Equilibrium in case of 2 players
	if alive_players().size() == 2 && is_market_equilibrium():
		game_finished = true
		# Even though the market is in equilibrium, 
		# some players might have more total value than others
		# Reflect this in the list of winners
		var alive = alive_players()
		#var hand_values = alive.map(func(p: Player): p.hand_value())
		var hand_values = alive.map(func(p: Player): return p.hand_value())
		var highest_value = hand_values.max()
		var winners = alive.filter(func(p): return p.hand_value() == highest_value)
		game_over.emit("Equilibrium", winners)
	
	# Check if game is infinite (> 1000 turns)
	if turn_counter > 1000:
		game_finished = true
		game_over.emit("Infinity", alive_players())


# An equilibrium exists when all (living) players have a straight 1-N
# (e.g. 1-2-3-4 with 4 players)
func is_market_equilibrium() -> bool:
	# Unstable markets are not in equilibrium
	if !market_stable:
		return false

	for p in alive_players():
		# Count number of unique cards in hand (e.g. 1-1-2-3 has 3 unique cards)
		var unique_card_count = ArrayUtils.distinct(p.hand).size()
		# If our unique card count is less than the max value, we don't have a straight
		if unique_card_count < max_value:
			return false
	
	# If we get here, all players had a straight
	return true


func end_turn() -> void:
	print("Turn ended. Current state:\n", str(self))
	turn_counter += 1


func pick_starting_player() -> void:
	current_player = players.pick_random()

func select_next_player() -> void:
	var alive = alive_players()
	var current_index = alive.find(current_player)
	current_player = alive[(current_index + 1) % alive.size()]


func propose_trade(current: Player, target: Player) -> int:
	var offered_card = current.offer_card(target)
	trade_proposed.emit(current, target, offered_card)
	return offered_card


func resolve_trade(current: Player, target: Player, offered_card: int):
	# If target can return, exchange cards
	if target.can_return(offered_card):
		# Select cards to return
		var returned_cards = target.return_cards(offered_card, market_stable, max_value)

		# Exchange cards
		for c in returned_cards:
			target.hand.erase(c)
		target.hand.append(offered_card)
		current.hand.erase(offered_card)
		current.hand.append_array(returned_cards)
		
		# Increase boredom for trade without elimination
		boredom_counter += 1
		# Check for mirror trade, these increase boredom
		if offered_card == ArrayUtils.sum_array(returned_cards):
			boredom_counter += 1
		
		# Emit signal
		trade_resolved.emit(current, target, offered_card, returned_cards)
	# Otherwise, eliminate target
	else:
		# Handle elimination
		current.hand.append_array(target.hand)
		target.die()
		player_eliminated.emit(target)
		destabilize_market()

func destabilize_market() -> void:
	market_stable = false
	boredom_counter = 0
	countdown_to_destruction = alive_players().size()

func destroy_value() -> void:
	# Emit signal for destruction
	market_value_destruction.emit(max_value)
	# Remove highest card from players' hands
	for p in players:
		ArrayUtils.erase_multiple(p.hand, max_value)
	# Lower max value
	max_value -= 1
	
	# Value destruction may trigger another player death!
	# Players can die if they only have the highest card and it goes away.
	# Loop over all remaining players, if someone has 0 cards then they also die.
	for p in alive_players():
		if p.hand.is_empty():
			p.die()
	
	# Reset stability or trigger new instability if maxValue does not match alivePlayers
	if max_value > alive_players().size():
		destabilize_market()
	else:
		stabilize_market()


func stabilize_market() -> void:
	market_stable = true
	boredom_counter = 0
	countdown_to_destruction = -1


func alive_players() -> Array[Player]:
	return players.filter(func(p: Player): return p.alive)


func _to_string() -> String:
	return "Turn {turn} - {alive_count}/{player_count} alive - Current Player {current_player}
Players: {players}".format({
		"turn": turn_counter,
		"alive_count": alive_players().size(),
		"player_count": players.size(),
		"current_player": current_player.id,
		"players": pretty_print_players(players)
	})

func pretty_print_players(players: Array[Player]) -> String:
	var sb = "[\n"
	for player in players:
		sb += "\t" + str(player) + ",\n"
	sb += "]"
	return sb
