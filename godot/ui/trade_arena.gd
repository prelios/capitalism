extends Control

class_name TradeArena


const ARROW_HOVER := Color("f7d774")
const ARROW_SELECTED := Color("ff5f6d")
const ARROW_ACTIVE := Color("ff7a66")
const CARD_SIZE := Vector2(72.0, 92.0)


var _local_player_id := -1
var _actor_id := -1
var _target_id := -1
var _stage := "idle"
var _offered_card: Dictionary = {}
var _returned_cards: Array = []
var _acquired_cards: Array = []
var _stage_started_msec := 0
var _stage_duration := 0.0
var _arrow_color := ARROW_ACTIVE

@onready var seats: Control = $Seats


func _ready() -> void:
	resized.connect(_layout_seats)
	set_process(true)


func set_local_player(player_id: int) -> void:
	_local_player_id = player_id
	_layout_seats()


func refresh_seat_layout() -> void:
	_layout_seats()


func show_target_preview(actor_id: int, target_id: int, selected: bool) -> void:
	_actor_id = actor_id
	_target_id = target_id
	_stage = "selected" if selected else "hover"
	_arrow_color = ARROW_SELECTED if selected else ARROW_HOVER
	_offered_card = {}
	_returned_cards.clear()
	_acquired_cards.clear()
	_stage_duration = 0.0
	queue_redraw()


func clear_target_preview() -> void:
	if _stage == "hover" or _stage == "selected":
		clear_flow()


func show_presentation(presentation: Dictionary) -> void:
	_stage = presentation.get("stage", "idle")
	_actor_id = presentation.get("actor_id", -1)
	_target_id = presentation.get("target_id", -1)
	_offered_card = presentation.get("offered_card", {}).duplicate(true)
	_returned_cards = presentation.get("returned_cards", []).duplicate(true)
	_acquired_cards = presentation.get("acquired_cards", []).duplicate(true)
	_stage_duration = presentation.get("duration", 0.0)
	_stage_started_msec = Time.get_ticks_msec()
	_arrow_color = ARROW_SELECTED if _stage == "targeting" else ARROW_ACTIVE
	queue_redraw()


func clear_flow() -> void:
	_stage = "idle"
	_actor_id = -1
	_target_id = -1
	_offered_card = {}
	_returned_cards.clear()
	_acquired_cards.clear()
	_stage_duration = 0.0
	queue_redraw()


func stage() -> String:
	return _stage


func arrow_color() -> Color:
	return _arrow_color


func flow_participants() -> Vector2i:
	if _stage in ["acquisition", "acquisition_arrival"]:
		return Vector2i(_target_id, _actor_id)
	return Vector2i(_actor_id, _target_id)


func seat_center(player_id: int) -> Vector2:
	for child in seats.get_children():
		var seat := child as PlayerSeatPanel
		if seat != null and seat.player_id == player_id:
			return seat.position + seat.size * 0.5
	return size * 0.5


func _process(_delta: float) -> void:
	if _stage_duration > 0.0 and _stage in ["offer_moving", "repayment_moving", "arrival", "acquisition", "acquisition_arrival"]:
		queue_redraw()


func _draw() -> void:
	if _actor_id <= 0 or _target_id <= 0 or _actor_id == _target_id:
		return
	var points := _arrow_points()
	if points.size() < 2:
		return
	draw_polyline(points, _arrow_color, 7.0, true)
	_draw_arrow_head(points)
	_draw_trade_cards(points)


func _layout_seats() -> void:
	if !is_node_ready() or seats == null or seats.get_child_count() == 0 or size.x <= 0.0 or size.y <= 0.0:
		return
	var ordered: Array[PlayerSeatPanel] = []
	var local_index := 0
	for index in range(seats.get_child_count()):
		var seat := seats.get_child(index) as PlayerSeatPanel
		if seat == null:
			continue
		ordered.append(seat)
		if seat.player_id == _local_player_id:
			local_index = ordered.size() - 1
	if ordered.is_empty():
		return
	var rotated: Array[PlayerSeatPanel] = []
	for offset in range(ordered.size()):
		rotated.append(ordered[(local_index + offset) % ordered.size()])
	var center := size * 0.5
	var sample_size := rotated[0].size
	if sample_size.x <= 0.0 or sample_size.y <= 0.0:
		sample_size = rotated[0].custom_minimum_size
	var radius := Vector2(maxf(0.0, center.x - sample_size.x * 0.5 - 12.0), maxf(0.0, center.y - sample_size.y * 0.5 - 10.0))
	for index in range(rotated.size()):
		var angle := _seat_angle(index, rotated.size())
		var seat_center_position := center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y)
		rotated[index].position = seat_center_position - sample_size * 0.5


func _seat_angle(index: int, player_count: int) -> float:
	if index == 0:
		return PI * 0.5
	if player_count == 4:
		return PI * 0.5 + float(index) * PI * 0.5
	var opponent_count := player_count - 1
	var reserved_half_angle := PI / 3.0
	var start := PI * 0.5 + reserved_half_angle
	var end := PI * 2.5 - reserved_half_angle
	return lerpf(start, end, float(index - 1) / float(maxi(1, opponent_count - 1)))


func _arrow_points() -> PackedVector2Array:
	var flow := flow_participants()
	var start := seat_center(flow.x)
	var finish := seat_center(flow.y)
	var center := size * 0.5
	var direct := finish - start
	if direct.length() < 1.0:
		return PackedVector2Array()
	var direction := direct.normalized()
	start += direction * (_seat_edge_distance(flow.x, direction) + 8.0)
	finish -= direction * (_seat_edge_distance(flow.y, -direction) + 12.0)
	direct = finish - start
	var normal := Vector2(-direct.y, direct.x).normalized()
	var control := center + normal * minf(80.0, direct.length() * 0.12)
	var points := PackedVector2Array()
	for index in range(41):
		var t := float(index) / 40.0
		points.append(_quadratic(start, control, finish, t))
	return points


func _seat_edge_distance(player_id: int, direction: Vector2) -> float:
	for child in seats.get_children():
		var seat := child as PlayerSeatPanel
		if seat == null or seat.player_id != player_id:
			continue
		var half_size := seat.size * 0.5
		var horizontal := INF if is_zero_approx(direction.x) else half_size.x / absf(direction.x)
		var vertical := INF if is_zero_approx(direction.y) else half_size.y / absf(direction.y)
		return minf(horizontal, vertical)
	return 0.0


func _quadratic(start: Vector2, control: Vector2, finish: Vector2, t: float) -> Vector2:
	var inverse := 1.0 - t
	return inverse * inverse * start + 2.0 * inverse * t * control + t * t * finish


func _draw_arrow_head(points: PackedVector2Array) -> void:
	var tip := points[points.size() - 1]
	var direction := (tip - points[points.size() - 3]).normalized()
	var normal := Vector2(-direction.y, direction.x)
	var base := tip - direction * 24.0
	draw_colored_polygon(PackedVector2Array([tip, base + normal * 13.0, base - normal * 13.0]), _arrow_color)


func _draw_trade_cards(points: PackedVector2Array) -> void:
	if _offered_card.is_empty() or _stage in ["crash", "settled"]:
		return
	var progress := _stage_progress()
	var offer_t := 0.40
	var return_t := 0.60
	var acquired_t := 0.60
	var offer_side := 1.0
	var acquired_side := -1.0
	match _stage:
		"offer_moving":
			offer_t = lerpf(0.08, 0.40, progress)
		"repayment_moving":
			return_t = lerpf(0.92, 0.60, progress)
		"arrival":
			offer_t = lerpf(0.40, 0.92, progress)
			return_t = lerpf(0.60, 0.08, progress)
		"acquisition":
			offer_t = 0.60
			offer_side = -1.0
			acquired_t = lerpf(0.08, 0.40, progress)
			acquired_side = 1.0
		"acquisition_arrival":
			offer_t = lerpf(0.60, 0.92, progress)
			offer_side = -1.0
			acquired_t = lerpf(0.40, 0.92, progress)
			acquired_side = 1.0
	_draw_card_group(points, offer_t, [_offered_card], offer_side)
	if !_returned_cards.is_empty() and _stage in ["repayment_moving", "repayment_ready", "arrival"]:
		_draw_card_group(points, return_t, _returned_cards, -1.0)
	if !_acquired_cards.is_empty() and _stage in ["acquisition", "acquisition_arrival"]:
		_draw_card_group(points, acquired_t, _acquired_cards, acquired_side)


func _draw_card_group(points: PackedVector2Array, t: float, cards: Array, side: float) -> void:
	var point_index := clampi(int(round(t * float(points.size() - 1))), 1, points.size() - 2)
	var path_center := points[point_index]
	var tangent := (points[point_index + 1] - points[point_index - 1]).normalized()
	var normal := Vector2(-tangent.y, tangent.x)
	var column_count := mini(4, cards.size())
	var row_count := ceili(float(cards.size()) / float(column_count))
	var group_width := float(column_count - 1) * (CARD_SIZE.x + 8.0)
	var group_height := float(row_count - 1) * (CARD_SIZE.y + 8.0)
	var normal_extent := absf(normal.x) * group_width * 0.5 + absf(normal.y) * group_height * 0.5
	var center := path_center + normal * side * (58.0 + normal_extent)
	for index in range(cards.size()):
		var column := index % column_count
		var row := index / column_count
		var card_center := center + Vector2(float(column) * (CARD_SIZE.x + 8.0) - group_width * 0.5, float(row) * (CARD_SIZE.y + 8.0) - group_height * 0.5)
		_draw_public_card(card_center, cards[index])


func _draw_public_card(center: Vector2, card: Dictionary) -> void:
	var rect := Rect2(center - CARD_SIZE * 0.5, CARD_SIZE)
	draw_style_box(_card_style(), rect)
	var font := ThemeDB.fallback_font
	var value_text := str(card.get("value", "?"))
	var suit_text := str(card.get("suit", "Card"))
	draw_string(font, rect.position + Vector2(0.0, 36.0), value_text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 28, Color.WHITE)
	draw_string(font, rect.position + Vector2(4.0, 69.0), suit_text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 8.0, 14, Color("d8e8f7"))


func _card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("19243a")
	style.border_color = Color("f2d48a")
	style.set_border_width_all(3)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style


func _stage_progress() -> float:
	if _stage_duration <= 0.0:
		return 1.0
	return clampf(float(Time.get_ticks_msec() - _stage_started_msec) / (_stage_duration * 1000.0), 0.0, 1.0)
