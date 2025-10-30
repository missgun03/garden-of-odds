extends Node
class_name SeasonManager

## SeasonManager: จัดการ season flow
## - 2 hands/season (มือที่ 1: 2-3 ต้น, มือที่ 2: 2-3 ต้น)
## - Mini-Bloom 0.8s หลังมือที่ 1
## - Bloom ใหญ่ 2-3s หลังมือที่ 2
## - Gate checking ตาม stages.json

# Season config
@export var season_id: int = 1
@export var target_score: int = 80
@export var plants_per_hand: int = 3  # จำนวนพืชที่วางได้ต่อมือ
@export var mini_bloom_duration: float = 0.8  # วินาที
@export var full_bloom_duration: float = 2.5  # วินาที

# State
enum SeasonState {
	DRAFT_STACK,      # เลือก draft stack
	HAND_1_DRAFTING,  # กำลังดราฟท์มือที่ 1
	HAND_1_PLACING,   # กำลังวางพืชมือที่ 1
	MINI_BLOOM,       # Mini-Bloom animation
	HAND_2_DRAFTING,  # กำลังดราฟท์มือที่ 2
	HAND_2_PLACING,   # กำลังวางพืชมือที่ 2
	FULL_BLOOM,       # Full Bloom animation
	GATE_CHECK,       # เช็คเป้าหมาย
	SEASON_END        # จบฤดู
}

var current_state: SeasonState = SeasonState.DRAFT_STACK
var current_hand: int = 0  # 1 or 2
var plants_placed_this_hand: int = 0

# Draft Stack
var available_stacks: Array = []  # Array of Arrays (3 stacks, each 3 plants)
var selected_stack: Array = []
var reroll_available: bool = true

# Season data
var season_score: int = 0
var current_entropy: float = 0.0

# References (set by Main)
var board: Board = null
var resolver: Resolver = null
var hud: Node = null

# Bloom timer
var bloom_timer: float = 0.0

signal state_changed(new_state: SeasonState)
signal season_completed(passed: bool, score: int)
signal bloom_started(is_mini: bool)
signal bloom_finished()
signal draft_stack_ready(stacks: Array)

func _ready() -> void:
	pass

## เริ่ม season
func start_season(season_config: Dictionary) -> void:
	season_id = season_config.get("id", 1)
	target_score = season_config.get("target", 80)

	current_state = SeasonState.DRAFT_STACK
	current_hand = 0
	plants_placed_this_hand = 0
	season_score = 0

	_generate_draft_stacks()
	_change_state(SeasonState.DRAFT_STACK)

## สุ่ม draft stacks (3 กอง, กองละ 3 ใบ)
func _generate_draft_stacks() -> void:
	available_stacks = []
	for i in range(3):
		var stack = []
		for j in range(3):
			# TODO: สุ่มพืชจาก plant pool (ตอนนี้ hardcode)
			stack.append({
				"plant_name": "Sunbud",
				"plant_id": i * 3 + j
			})
		available_stacks.append(stack)

	print("SeasonManager: Generated %d draft stacks" % available_stacks.size())
	emit_signal("draft_stack_ready", available_stacks)
	print("SeasonManager: Emitted draft_stack_ready signal")

## เลือก draft stack
func select_draft_stack(stack_index: int) -> void:
	if stack_index < 0 or stack_index >= available_stacks.size():
		push_error("Invalid stack index: %d" % stack_index)
		return

	selected_stack = available_stacks[stack_index]
	_change_state(SeasonState.HAND_1_DRAFTING)

## Reroll draft stacks (1 ครั้งต่อฤดู)
func reroll_draft_stacks() -> void:
	if not reroll_available:
		push_warning("Reroll not available")
		return

	reroll_available = false
	_generate_draft_stacks()

## เริ่ม hand
func start_hand(hand_number: int) -> void:
	current_hand = hand_number
	plants_placed_this_hand = 0

	if hand_number == 1:
		_change_state(SeasonState.HAND_1_PLACING)
	else:
		_change_state(SeasonState.HAND_2_PLACING)

## วางพืชในมือปัจจุบัน
func place_plant_in_hand() -> void:
	plants_placed_this_hand += 1

	# ถ้าวางครบแล้ว -> ไป bloom
	if plants_placed_this_hand >= plants_per_hand:
		if current_hand == 1:
			_start_mini_bloom()
		else:
			_start_full_bloom()

## เริ่ม Mini-Bloom
func _start_mini_bloom() -> void:
	_change_state(SeasonState.MINI_BLOOM)
	bloom_timer = mini_bloom_duration
	emit_signal("bloom_started", true)

	# Trigger bloom resolution
	_resolve_bloom(false)

## เริ่ม Full Bloom
func _start_full_bloom() -> void:
	_change_state(SeasonState.FULL_BLOOM)
	bloom_timer = full_bloom_duration
	emit_signal("bloom_started", false)

	# Trigger bloom resolution
	_resolve_bloom(true)

## Resolve bloom: trigger plants และคำนวณคะแนน
func _resolve_bloom(_is_full_bloom: bool) -> void:
	if not board or not resolver:
		push_error("Board or Resolver not set")
		return

	# Trigger all plants
	var events: Array = []
	for plant in board.get_all_plants():
		if plant is Plant:
			var ctx = board.create_trigger_context(plant.grid_pos)
			var event = plant.trigger(ctx)
			if not event.is_empty():
				events.append(event)

	# Resolve phase
	var modifiers = {
		"M_set": 1.0,
		"M_mut": 1.0,
		"M_biome": 1.0,
		"overgrow_active": false  # TODO: รับจาก HUD
	}

	var result = resolver.resolve_phase(events, current_entropy, modifiers)

	# อัพเดทคะแนนและ entropy
	season_score += result.score
	current_entropy = result.entropy

	print("Bloom resolved: +%d score, entropy: %.1f" % [result.score, current_entropy])

	# TODO: ส่ง result ไปยัง HUD เพื่อแสดงผล

func _process(delta: float) -> void:
	# Bloom timer
	if current_state == SeasonState.MINI_BLOOM or current_state == SeasonState.FULL_BLOOM:
		bloom_timer -= delta
		if bloom_timer <= 0:
			_on_bloom_finished()

## เมื่อ bloom จบ
func _on_bloom_finished() -> void:
	emit_signal("bloom_finished")

	if current_state == SeasonState.MINI_BLOOM:
		# ไปมือที่ 2
		_change_state(SeasonState.HAND_2_DRAFTING)
	elif current_state == SeasonState.FULL_BLOOM:
		# ไป gate check
		_change_state(SeasonState.GATE_CHECK)
		_check_gate()

## เช็คว่าผ่าน gate หรือไม่
func _check_gate() -> void:
	var passed = season_score >= target_score

	print("Gate check: %d / %d -> %s" % [season_score, target_score, "PASS" if passed else "FAIL"])

	# เช็ค collapse
	if resolver.check_collapse(current_entropy):
		print("COLLAPSE! Entropy: %.1f >= %.1f" % [current_entropy, resolver.E_CAP])
		passed = false

	_change_state(SeasonState.SEASON_END)
	emit_signal("season_completed", passed, season_score)

## เปลี่ยน state
func _change_state(new_state: SeasonState) -> void:
	current_state = new_state
	emit_signal("state_changed", new_state)
	print("SeasonManager: %s" % SeasonState.keys()[new_state])

## Get state name
func get_state_name() -> String:
	return SeasonState.keys()[current_state]
