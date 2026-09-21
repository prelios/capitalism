extends Resource

class_name MatchConfig

const MIN_PLAYERS := 4
const MAX_PLAYERS := 10
const MARKET_POLICY_PLAY_BASED := "play_based"
const MARKET_POLICY_TIME_BASED := "time_based"

@export_range(MIN_PLAYERS, MAX_PLAYERS) var player_count := MIN_PLAYERS
@export_range(1, 10) var warning_turns_per_survivor := 1
@export_range(1, 100) var boredom_multiplier := 10
@export var market_policy := MARKET_POLICY_PLAY_BASED
@export var rng_seed := 1


func validation_error() -> String:
	if player_count < MIN_PLAYERS or player_count > MAX_PLAYERS:
		return "Player count must be between 4 and 10."
	if warning_turns_per_survivor < 1:
		return "Warning turns per survivor must be at least 1."
	if boredom_multiplier < 1:
		return "Boredom multiplier must be at least 1."
	if market_policy != MARKET_POLICY_PLAY_BASED and market_policy != MARKET_POLICY_TIME_BASED:
		return "Market policy must be play-based or time-based."
	return ""


func is_valid() -> bool:
	return validation_error().is_empty()


static func for_player_count(player_count_value: int, seed_value := 1, market_policy_value := MARKET_POLICY_PLAY_BASED) -> MatchConfig:
	var config := MatchConfig.new()
	config.player_count = player_count_value
	config.rng_seed = seed_value
	config.market_policy = market_policy_value
	return config
