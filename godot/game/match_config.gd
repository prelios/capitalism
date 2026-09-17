extends Resource

class_name MatchConfig


@export_range(4, 10) var player_count := 4
@export_range(1, 10) var warning_turns_per_survivor := 1
@export_range(1, 100) var boredom_multiplier := 10
@export var rng_seed := 1


func validation_error() -> String:
	if player_count < 4 or player_count > 10:
		return "Player count must be between 4 and 10."
	if warning_turns_per_survivor < 1:
		return "Warning turns per survivor must be at least 1."
	if boredom_multiplier < 1:
		return "Boredom multiplier must be at least 1."
	return ""


func is_valid() -> bool:
	return validation_error().is_empty()


static func for_player_count(player_count_value: int, seed_value := 1) -> MatchConfig:
	var config := MatchConfig.new()
	config.player_count = player_count_value
	config.rng_seed = seed_value
	return config
