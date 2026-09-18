extends SceneTree


const SEEDS_PER_CONFIGURATION := 30
const TURN_CAP := 5000


func _init() -> void:
	for roster_name in ["fair", "privileged"]:
		for player_count in [4, 6, 10]:
			print(_run_batch(player_count, roster_name == "privileged"))
	quit(0)


func _run_batch(player_count: int, privileged: bool) -> String:
	var metrics := {"completed": 0, "diagnostics": 0, "turns": 0, "monopoly": 0, "duopoly": 0, "meltdown": 0, "acquisitions": 0, "crashes": 0, "warnings": 0, "mirror_payments": 0, "exact_payments": 0, "decision_microseconds": 0, "decisions": 0}
	for offset in range(SEEDS_PER_CONFIGURATION):
		var seed_value := 31000 + player_count * 100 + offset
		_run_match(player_count, seed_value, privileged, metrics)
	var label := "privileged" if privileged else "fair"
	var average_turns: float = float(metrics["turns"]) / max(1, metrics["completed"])
	var average_decision_us: float = float(metrics["decision_microseconds"]) / max(1, metrics["decisions"])
	return "%s %d-player seeds %d-%d: completed=%d diagnostics=%d avg_turns=%.2f monopoly=%d duopoly=%d meltdown=%d acquisitions=%d warnings=%d crashes=%d mirrors=%d exact=%d avg_decision_us=%.2f" % [label, player_count, 31000 + player_count * 100, 31000 + player_count * 100 + SEEDS_PER_CONFIGURATION - 1, metrics["completed"], metrics["diagnostics"], average_turns, metrics["monopoly"], metrics["duopoly"], metrics["meltdown"], metrics["acquisitions"], metrics["warnings"], metrics["crashes"], metrics["mirror_payments"], metrics["exact_payments"], average_decision_us]


func _run_match(player_count: int, seed_value: int, privileged: bool, metrics: Dictionary) -> void:
	var game := GameModel.new(MatchConfig.for_player_count(player_count, seed_value))
	var policy_rng := RandomNumberGenerator.new()
	policy_rng.seed = seed_value + 1
	var policies: Dictionary[int, PlayerPolicy] = {}
	for player in game.players:
		policies[player.id] = _policy_for(player.id, privileged, policy_rng)
	game.pick_starting_player()
	while !game.game_finished and game.turn_counter <= TURN_CAP:
		game.start_next_turn()
		var actor := game.current_player
		var policy: PlayerPolicy = policies[actor.id]
		var view: PlayerView = game.privileged_player_view(actor.id) if policy is OptimalPlayer else game.player_view(actor.id)
		var started_at := Time.get_ticks_usec()
		var target_id := policy.choose_target(view)
		var offered_id := policy.choose_offer_card_id(view, target_id)
		metrics["decision_microseconds"] += Time.get_ticks_usec() - started_at
		metrics["decisions"] += 1
		var target := game.player_by_id(target_id)
		if target == null or !game.submit_offer(actor.id, target_id, offered_id):
			metrics["diagnostics"] += 1
			return
		if game.phase == GameModel.PHASE_AWAITING_REPAYMENT:
			var repayment_policy: PlayerPolicy = policies[target.id]
			var repayment_view: PlayerView = game.privileged_player_view(target.id) if repayment_policy is OptimalPlayer else game.player_view(target.id)
			started_at = Time.get_ticks_usec()
			var repayment_ids := repayment_policy.choose_repayment_card_ids(repayment_view, game.pending_trade.offered_card.value)
			metrics["decision_microseconds"] += Time.get_ticks_usec() - started_at
			metrics["decisions"] += 1
			if !game.submit_repayment(target.id, repayment_ids):
				metrics["diagnostics"] += 1
				return
		game.complete_turn()
	if !game.game_finished:
		metrics["diagnostics"] += 1
		return
	metrics["completed"] += 1
	metrics["turns"] += game.turn_counter
	match game.ending:
		"Monopoly": metrics["monopoly"] += 1
		"Duopoly": metrics["duopoly"] += 1
		"Global Economic Meltdown": metrics["meltdown"] += 1
		_: metrics["diagnostics"] += 1
	for event in game.public_history():
		match event["type"]:
			"player_acquired": metrics["acquisitions"] += 1
			"market_warning_started": metrics["warnings"] += 1
			"market_crashed": metrics["crashes"] += 1
			"trade_resolved":
				var data: Dictionary = event["data"]
				var returned: Array = data["returned"]
				var total := 0
				for card: Dictionary in returned:
					total += card["value"]
				if total == data["offered"]["value"]:
					metrics["exact_payments"] += 1
				if returned.size() == 1 and returned[0]["value"] == data["offered"]["value"]:
					metrics["mirror_payments"] += 1


func _policy_for(player_id: int, privileged: bool, rng: RandomNumberGenerator) -> PlayerPolicy:
	if privileged:
		match (player_id - 1) % 3:
			0: return OptiHighPlayer.new(rng)
			1: return OptiLowPlayer.new(rng)
			_: return OptiRandPlayer.new(rng)
	match (player_id - 1) % 3:
		0: return RandomPlayer.new(rng)
		1: return AggroPlayer.new(rng)
		_: return ScaredPlayer.new(rng)
