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
const MARKET_PRESSURE_CALM := "Calm"
const MARKET_PRESSURE_MOVING := "Moving"
const MARKET_PRESSURE_RESTLESS := "Restless"
const MARKET_PRESSURE_DANGEROUS := "Dangerous"
const TIME_BASED_ROUNDS_TO_WARNING := 2


var config: MatchConfig
var configuration_error := ""
var rng := RandomNumberGenerator.new()
var players: Array[Player] = []
var max_value: int
var turn_counter := 1
var current_player: Player = null
var phase := PHASE_AWAITING_OFFER
var pending_trade: PendingTrade = null
var last_rejection := ""
var boredom_counter := 0
var countdown_to_destruction := -1
var unstable_value := -1
var warning_waits_for_next_turn := false
var warning_turns_per_survivor: int
var boredom_multiplier: int
var market_policy := MatchConfig.MARKET_POLICY_PLAY_BASED
var market_stable := true
var game_finished := false
var ending := ""
var winner_ids: Array[int] = []
var time_based_rounds_without_elimination := 0
var time_based_round_player_ids: Array[int] = []
var time_based_completed_player_ids: Array[int] = []
var _public_history: Array[Dictionary] = []


func _init(configuration: MatchConfig) -> void:
	config = configuration.duplicate() as MatchConfig
	configuration_error = config.validation_error()
	if !configuration_error.is_empty():
		game_finished = true
		return
	rng.seed = config.rng_seed
	players = create_players(config.player_count)
	deal_cards(create_deck(), players)
	max_value = config.player_count
	warning_turns_per_survivor = config.warning_turns_per_survivor
	boredom_multiplier = config.boredom_multiplier
	market_policy = config.market_policy


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
		created_players.append(Player.new(player_id))
	return created_players


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
	_start_time_based_round_if_needed()
	phase = PHASE_AWAITING_OFFER
	pending_trade = null
	last_rejection = ""
	record_public_event("turn_started", {"turn": turn_counter, "actor_id": current_player.id})
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
	record_public_event("trade_proposed", {"actor_id": actor_id, "target_id": target_id, "card": public_card(offered_card)})
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
	if market_stable and market_policy == MatchConfig.MARKET_POLICY_PLAY_BASED:
		boredom_counter += 1
		if returned_cards.size() == 1 and returned_cards[0].value == offered_card.value:
			boredom_counter += 1
	trade_resolved.emit(actor, target, offered_card, returned_cards)
	record_public_event("trade_resolved", {"actor_id": actor.id, "target_id": target.id, "offered": public_card(offered_card), "returned": public_cards(returned_cards)})
	pending_trade = null


func resolve_acquisition(actor: Player, target: Player) -> void:
	phase = PHASE_TURN_RESOLVED
	pending_trade = null
	var acquired_cards := target.hand.duplicate()
	var acquired_companies := target.owned_company_ids.duplicate()
	actor.hand.append_array(acquired_cards)
	actor.acquire_companies_from(target)
	target.die()
	record_public_event("player_acquired", {"acquirer_id": actor.id, "victim_id": target.id, "cards": public_cards(acquired_cards), "company_ids": acquired_companies})
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
		if warning_waits_for_next_turn:
			warning_waits_for_next_turn = false
			return
		advance_warning()
		return
	if check_game_end():
		return
	if market_policy == MatchConfig.MARKET_POLICY_PLAY_BASED and boredom_counter > boredom_multiplier * alive_players().size():
		destabilize_market()
	elif market_policy == MatchConfig.MARKET_POLICY_TIME_BASED:
		advance_time_based_market()


func complete_turn() -> bool:
	if game_finished or phase != PHASE_TURN_RESOLVED:
		return false
	finalize_turn()
	if game_finished:
		return true
	end_turn()
	return true


func end_turn() -> void:
	if game_finished or phase != PHASE_TURN_RESOLVED:
		return
	turn_counter += 1


func destabilize_market() -> void:
	if game_finished or !market_stable:
		return
	reset_market_pacing()
	market_stable = false
	warning_waits_for_next_turn = true
	unstable_value = highest_active_value()
	if unstable_value <= 0:
		check_game_end()
		return
	countdown_to_destruction = alive_players().size() * warning_turns_per_survivor
	record_public_event("market_warning_started", {"value": unstable_value, "turns_remaining": countdown_to_destruction})


func advance_warning() -> void:
	boredom_counter = 0
	record_public_event("market_warning_updated", {"value": unstable_value, "turns_remaining": countdown_to_destruction})
	market_unstable.emit(countdown_to_destruction)
	countdown_to_destruction -= 1
	if countdown_to_destruction == 0:
		destroy_value()


func destroy_value() -> void:
	if game_finished or market_stable:
		return
	var destroyed_value := unstable_value
	if destroyed_value <= 0:
		return
	var bankrupt_ids: Array[int] = []
	for player in players:
		player.remove_cards_with_value(destroyed_value)
	max_value = highest_active_value()
	var bankrupt_players: Array[Player] = []
	for player in alive_players():
		if player.hand.is_empty():
			bankrupt_players.append(player)
	for player in bankrupt_players:
		bankrupt_ids.append(player.id)
		player.die()
		player.remove_companies()
		player_eliminated.emit(player)
	stabilize_market()
	record_public_event("market_crashed", {"value": destroyed_value, "bankrupt_player_ids": bankrupt_ids})
	market_value_destruction.emit(destroyed_value)
	check_game_end()


func stabilize_market() -> void:
	market_stable = true
	reset_market_pacing()
	countdown_to_destruction = -1
	unstable_value = -1
	warning_waits_for_next_turn = false


func reset_market_pacing() -> void:
	boredom_counter = 0
	time_based_rounds_without_elimination = 0
	time_based_round_player_ids.clear()
	time_based_completed_player_ids.clear()


func _start_time_based_round_if_needed() -> void:
	if market_policy != MatchConfig.MARKET_POLICY_TIME_BASED or !market_stable or !time_based_round_player_ids.is_empty():
		return
	for player in alive_players():
		time_based_round_player_ids.append(player.id)


func advance_time_based_market() -> void:
	_start_time_based_round_if_needed()
	if current_player == null or !time_based_round_player_ids.has(current_player.id):
		return
	if !time_based_completed_player_ids.has(current_player.id):
		time_based_completed_player_ids.append(current_player.id)
	for player_id in time_based_round_player_ids:
		var player := player_by_id(player_id)
		if !time_based_completed_player_ids.has(player_id) and player != null and player.alive:
			return
	time_based_rounds_without_elimination += 1
	time_based_round_player_ids.clear()
	time_based_completed_player_ids.clear()
	if time_based_rounds_without_elimination >= TIME_BASED_ROUNDS_TO_WARNING:
		destabilize_market()


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
	self.ending = ending
	winner_ids.clear()
	for winner in winners:
		winner_ids.append(winner.id)
	phase = PHASE_FINISHED
	pending_trade = null
	record_public_event("game_finished", {"ending": ending, "winner_ids": winner_ids.duplicate()})
	game_over.emit(ending, winners)


func record_public_event(event_type: String, data: Dictionary) -> void:
	_public_history.append({"sequence": _public_history.size() + 1, "type": event_type, "data": data.duplicate(true)})


func public_history() -> Array[Dictionary]:
	var history: Array[Dictionary] = []
	for event in _public_history:
		history.append(event.duplicate(true))
	return history


func public_snapshot() -> Dictionary:
	var seats: Array[Dictionary] = []
	for player in players:
		seats.append({"player_id": player.id, "seat": player.seat, "company_name": player.company_name, "company_emoji": player.company_emoji, "alive": player.alive, "hand_size": player.hand.size(), "company_ids": player.owned_company_ids.duplicate(), "company_tokens": public_company_tokens(player.owned_company_ids)})
	var trade: Dictionary = {}
	if pending_trade != null:
		trade = {
			"actor_id": pending_trade.actor_id,
			"target_id": pending_trade.target_id,
			"offered_card": public_card(pending_trade.offered_card)
		}
	return {"turn": turn_counter, "phase": phase, "current_player_id": -1 if current_player == null else current_player.id, "market_stable": market_stable, "market_policy": market_policy, "market_pressure": market_pressure(), "inactivity_rounds_completed": time_based_rounds_without_elimination, "inactivity_round_turns_completed": time_based_completed_player_ids.size(), "inactivity_round_player_count": time_based_round_player_ids.size(), "inactivity_rounds_until_warning": max(0, TIME_BASED_ROUNDS_TO_WARNING - time_based_rounds_without_elimination), "unstable_value": unstable_value, "max_value": max_value, "turns_remaining": countdown_to_destruction, "pending_trade": trade, "game_finished": game_finished, "ending": ending, "winner_ids": winner_ids.duplicate(), "players": seats}


func player_view(requester_id: int) -> PlayerView:
	var requester := player_by_id(requester_id)
	if requester == null:
		return null
	return PlayerView.new(requester_id, public_cards(requester.hand), public_snapshot(), public_history())


func privileged_player_view(requester_id: int) -> PrivilegedPlayerView:
	var requester := player_by_id(requester_id)
	if requester == null:
		return null
	var hands_by_player: Dictionary = {}
	for player in players:
		hands_by_player[player.id] = public_cards(player.hand)
	return PrivilegedPlayerView.new(requester_id, public_cards(requester.hand), public_snapshot(), public_history(), hands_by_player)


func public_card(card: Card) -> Dictionary:
	return {"id": card.id, "value": card.value, "suit": card.suit}


func public_cards(cards: Array[Card]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for card in cards:
		result.append(public_card(card))
	return result


func market_pressure() -> String:
	if !market_stable or market_policy != MatchConfig.MARKET_POLICY_PLAY_BASED:
		return ""
	var threshold: int = max(1, boredom_multiplier * alive_players().size())
	var progress: float = float(boredom_counter) / float(threshold)
	if progress >= 0.6:
		return MARKET_PRESSURE_DANGEROUS
	if progress >= 0.4:
		return MARKET_PRESSURE_RESTLESS
	if progress >= 0.1:
		return MARKET_PRESSURE_MOVING
	return MARKET_PRESSURE_CALM


func public_company_tokens(company_ids: Array[String]) -> Array[Dictionary]:
	var tokens: Array[Dictionary] = []
	for company_id in company_ids:
		var company := company_by_id(company_id)
		if company != null:
			tokens.append({"company_id": company.company_id, "company_name": company.company_name, "company_emoji": company.company_emoji})
	return tokens


func company_by_id(company_id: String) -> Player:
	for player in players:
		if player.company_id == company_id:
			return player
	return null


func alive_players() -> Array[Player]:
	return players.filter(func(player: Player): return player.alive)


func highest_active_value() -> int:
	var highest := 0
	for player in alive_players():
		for card in player.hand:
			highest = max(highest, card.value)
	return highest


func invariant_violations() -> Array[String]:
	var violations: Array[String] = []
	var owned_card_ids: Dictionary = {}
	var owned_company_ids: Dictionary = {}
	for player in players:
		if !player.alive and !player.hand.is_empty():
			violations.append("Eliminated player %d still owns cards." % player.id)
		for card in player.hand:
			if card.value <= 0:
				violations.append("Player %d owns non-positive card %s." % [player.id, card.id])
			if owned_card_ids.has(card.id):
				violations.append("Card %s has multiple owners." % card.id)
			owned_card_ids[card.id] = player.id
		for company_id in player.owned_company_ids:
			if owned_company_ids.has(company_id):
				violations.append("Company %s has multiple owners." % company_id)
			owned_company_ids[company_id] = player.id
	if !game_finished and phase == PHASE_AWAITING_OFFER and current_player != null and !current_player.alive:
		violations.append("Current player %d is not alive." % current_player.id)
	if game_finished and phase != PHASE_FINISHED:
		violations.append("Finished match is not in the finished phase.")
	if !market_stable and unstable_value <= 0:
		violations.append("Unstable market has no pending value.")
	return violations


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
