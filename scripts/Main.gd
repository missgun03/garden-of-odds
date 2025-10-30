extends Node
class_name Main

## Main: Game Controller
## เชื่อม Board, HUD, SeasonManager, Resolver เข้าด้วยกัน

# Node references (set in scene tree)
@onready var board: Board = $Board
@onready var hud: HUD = $HUD
@onready var season_manager: SeasonManager = $SeasonManager
@onready var resolver: Resolver = $Resolver

# Game state
var current_season: int = 1
var stages_data: Dictionary = {}
var selected_plant_to_place: Dictionary = {}

func _ready() -> void:
	# โหลด stages data
	_load_stages_data()

	# เชื่อม references
	_connect_references()

	# เชื่อม signals
	_connect_signals()

	# เริ่มเกม
	_start_game()

## โหลด stages data จาก JSON
func _load_stages_data() -> void:
	var file_path = "res://resources/stages.json"
	if not FileAccess.file_exists(file_path):
		push_error("stages.json not found at %s" % file_path)
		stages_data = {
			"difficulty": "Grove",
			"seasons": [
				{"id": 1, "target": 80, "trial": null, "contracts": 2}
			]
		}
		return

	var file = FileAccess.open(file_path, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)

	if parse_result != OK:
		push_error("Failed to parse stages.json: %s" % json.get_error_message())
		return

	stages_data = json.data
	print("Loaded stages data: %s" % stages_data.difficulty)

## เชื่อม references ระหว่าง nodes
func _connect_references() -> void:
	season_manager.board = board
	season_manager.resolver = resolver
	season_manager.hud = hud

	hud.season_manager = season_manager
	hud.resolver = resolver

## เชื่อม signals
func _connect_signals() -> void:
	# SeasonManager signals
	season_manager.state_changed.connect(_on_season_state_changed)
	season_manager.season_completed.connect(_on_season_completed)
	season_manager.draft_stack_ready.connect(_on_draft_stack_ready)

	# HUD signals
	hud.overgrow_pressed.connect(_on_overgrow_pressed)
	hud.stabilize_pressed.connect(_on_stabilize_pressed)
	hud.draft_stack_selected.connect(_on_draft_stack_selected)

	# Board signals
	board.plant_placed.connect(_on_plant_placed)

## เริ่มเกม
func _start_game() -> void:
	current_season = 1
	_start_season(current_season)

## เริ่ม season
func _start_season(season_id: int) -> void:
	print("\n=== Starting Season %d ===" % season_id)

	# ดึง season config จาก stages_data
	var season_config = _get_season_config(season_id)

	# รีเซ็ต HUD
	hud.reset_for_new_season()

	# เริ่ม season
	season_manager.start_season(season_config)

	# อัพเดท HUD
	hud.update_display(0, season_config.target, 0.0)

## ดึง season config จาก stages_data
func _get_season_config(season_id: int) -> Dictionary:
	var seasons = stages_data.get("seasons", [])
	for season in seasons:
		if season.get("id", -1) == season_id:
			return season

	# fallback
	return {"id": season_id, "target": 80, "trial": null, "contracts": 2}

## === Signal Handlers ===

func _on_season_state_changed(new_state: SeasonManager.SeasonState) -> void:
	print("Main: Season state -> %s" % SeasonManager.SeasonState.keys()[new_state])

	match new_state:
		SeasonManager.SeasonState.HAND_1_DRAFTING:
			_start_drafting(1)
		SeasonManager.SeasonState.HAND_2_DRAFTING:
			_start_drafting(2)

func _on_season_completed(passed: bool, score: int) -> void:
	print("\n=== Season %d Completed ===" % current_season)
	print("Score: %d / %d -> %s" % [score, season_manager.target_score, "PASS" if passed else "FAIL"])

	if passed:
		# ไปฤดูถัดไป
		current_season += 1
		if current_season <= 6:
			await get_tree().create_timer(2.0).timeout
			_start_season(current_season)
		else:
			print("=== GAME COMPLETED! ===")
	else:
		print("=== GAME OVER ===")

func _on_draft_stack_ready(stacks: Array) -> void:
	hud.show_draft_stacks(stacks)

func _on_draft_stack_selected(stack_index: int) -> void:
	season_manager.select_draft_stack(stack_index)

func _on_overgrow_pressed() -> void:
	print("Main: Overgrow activated")

func _on_stabilize_pressed() -> void:
	print("Main: Stabilize used")

func _on_plant_placed(_plant: Plant, pos: Vector2i) -> void:
	print("Main: Plant placed at %s" % pos)
	season_manager.place_plant_in_hand()

	# รีเซ็ต overgrow สำหรับการวางครั้งถัดไป
	hud.reset_overgrow()

	# อัพเดท HUD
	hud.update_display(season_manager.season_score, season_manager.target_score, season_manager.current_entropy)

## === Drafting ===

func _start_drafting(hand_number: int) -> void:
	print("Main: Drafting for hand %d" % hand_number)
	# TODO: แสดง UI สำหรับดราฟท์พืช (3->1)
	# ตอนนี้ให้เริ่ม placing ทันที
	season_manager.start_hand(hand_number)

## === Input Handling (สำหรับ testing) ===

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if season_manager.current_state == SeasonManager.SeasonState.HAND_1_PLACING or \
		   season_manager.current_state == SeasonManager.SeasonState.HAND_2_PLACING:
			_try_place_plant_at_mouse(event.position)

## วางพืชที่ตำแหน่ง mouse (สำหรับ testing)
func _try_place_plant_at_mouse(mouse_pos: Vector2) -> void:
	# แปลง mouse position -> board position
	var board_local_pos = board.to_local(mouse_pos)
	var grid_pos = board._world_to_grid(board_local_pos)

	if not board.is_position_valid(grid_pos):
		return

	if not board.is_position_empty(grid_pos):
		return

	# สร้างพืช (ตอนนี้ hardcode เป็น Sunbud)
	var plant = Plant.new()
	plant.plant_id = 0
	plant.plant_name = "Sunbud"
	plant.role = "Energy"
	plant.p_base = 5
	plant.l_min = 1.0
	plant.l_max = 2.2
	plant.entropy_on_event = 0.3
	# สร้าง typed array สำหรับ tags
	var plant_tags: Array[String] = ["light", "buff", "engine"]
	plant.tags = plant_tags

	# วางพืช
	board.place_plant(plant, grid_pos)
