extends Node
class_name Main

## Main: Game Controller
## เชื่อม Board, HUD, SeasonManager, Resolver เข้าด้วยกัน

# Node references (set in scene tree)
@onready var board: Board = $Board
@onready var hud: HUD = $HUD
@onready var season_manager: SeasonManager = $SeasonManager
@onready var resolver: Resolver = $Resolver

# Data loading system (created in _ready)
var data_loader: DataLoader = null
var l_rule_evaluator: LRuleEvaluator = null
var plant_factory: PlantFactory = null

# Game state
var current_season: int = 1
var stages_data: Dictionary = {}
var selected_plant_to_place: Dictionary = {}
var is_placing_plant: bool = false  # ป้องกัน double-click

func _ready() -> void:
	print("Main: _ready() started")

	# สร้าง data loading system
	_setup_data_loading_system()

	# โหลด stages data
	_load_stages_data()

	# เชื่อม references
	_connect_references()

	# เชื่อม signals
	_connect_signals()

	print("Main: All setup complete, starting game...")

	# เริ่มเกม
	_start_game()

## สร้างและตั้งค่า data loading system
func _setup_data_loading_system() -> void:
	print("Main: Setting up data loading system...")

	# สร้าง DataLoader
	data_loader = DataLoader.new()
	add_child(data_loader)
	data_loader.load_all_data()

	# สร้าง LRuleEvaluator
	l_rule_evaluator = LRuleEvaluator.new()
	add_child(l_rule_evaluator)

	# สร้าง PlantFactory
	plant_factory = PlantFactory.new()
	plant_factory.data_loader = data_loader
	plant_factory.l_rule_evaluator = l_rule_evaluator
	add_child(plant_factory)

	print("Main: Data loading system ready")

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
	season_manager.plant_factory = plant_factory

	hud.season_manager = season_manager
	hud.resolver = resolver

## เชื่อม signals
func _connect_signals() -> void:
	print("Main: Connecting signals...")

	# SeasonManager signals
	season_manager.state_changed.connect(_on_season_state_changed)
	season_manager.season_completed.connect(_on_season_completed)
	season_manager.draft_stack_ready.connect(_on_draft_stack_ready)
	print("Main: SeasonManager signals connected")

	# HUD signals
	hud.overgrow_pressed.connect(_on_overgrow_pressed)
	hud.stabilize_pressed.connect(_on_stabilize_pressed)
	hud.draft_stack_selected.connect(_on_draft_stack_selected)
	print("Main: HUD signals connected")

	# Board signals
	board.plant_placed.connect(_on_plant_placed)
	print("Main: Board signals connected")

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
	var state_name = SeasonManager.SeasonState.keys()[new_state]
	print("Main: Season state -> %s" % state_name)

	match new_state:
		SeasonManager.SeasonState.DRAFT_STACK:
			hud.update_status("SELECT A DRAFT STACK (3 plants)", Color.YELLOW)
		SeasonManager.SeasonState.HAND_1_DRAFTING, SeasonManager.SeasonState.HAND_2_DRAFTING:
			_start_drafting(new_state)
		SeasonManager.SeasonState.HAND_1_PLACING:
			hud.update_status("HAND 1: Click to place plants", Color.GREEN)
			hud.update_hand_info()
		SeasonManager.SeasonState.HAND_2_PLACING:
			hud.update_status("HAND 2: Click to place plants", Color.GREEN)
			hud.update_hand_info()
		SeasonManager.SeasonState.MINI_BLOOM:
			hud.update_status("MINI BLOOM...", Color.CYAN)
		SeasonManager.SeasonState.FULL_BLOOM:
			hud.update_status("FULL BLOOM...", Color.ORANGE)
		SeasonManager.SeasonState.GATE_CHECK:
			hud.update_status("GATE CHECK...", Color.MAGENTA)
		SeasonManager.SeasonState.SEASON_END:
			hud.update_status("SEASON END", Color.RED)

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
	print("Main: Received draft_stack_ready with %d stacks" % stacks.size())
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

	# อัพเดทจำนวนพืชที่เหลือ
	var remaining = season_manager.plants_per_hand - season_manager.plants_placed_this_hand
	if remaining > 0:
		var hand_text = "HAND %d" % season_manager.current_hand
		hud.update_status("%s: Click to place plants (%d remaining)" % [hand_text, remaining], Color.GREEN)

	# รีเซ็ต overgrow สำหรับการวางครั้งถัดไป
	hud.reset_overgrow()

	# อัพเดท HUD
	hud.update_display(season_manager.season_score, season_manager.target_score, season_manager.current_entropy)

## === Drafting ===

func _start_drafting(state: SeasonManager.SeasonState) -> void:
	var hand_number = 1 if state == SeasonManager.SeasonState.HAND_1_DRAFTING else 2
	print("Main: Drafting for hand %d" % hand_number)
	hud.update_status("DRAFTING: Select plants (TODO)", Color.CYAN)
	# TODO: แสดง UI สำหรับดราฟท์พืช (3->1)
	# ตอนนี้ให้เริ่ม placing ทันที
	season_manager.start_hand(hand_number)

## === Input Handling (สำหรับ testing) ===

func _input(event: InputEvent) -> void:
	# แสดง placeholder เมื่อ mouse เคลื่อนไหว
	if event is InputEventMouseMotion:
		if season_manager.current_state == SeasonManager.SeasonState.HAND_1_PLACING or \
		   season_manager.current_state == SeasonManager.SeasonState.HAND_2_PLACING:
			_show_placement_preview(event.position)

	# วางพืชเมื่อคลิก
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if season_manager.current_state == SeasonManager.SeasonState.HAND_1_PLACING or \
		   season_manager.current_state == SeasonManager.SeasonState.HAND_2_PLACING:
			_try_place_plant_at_mouse(event.position)

## แสดง preview ก่อนวาง
func _show_placement_preview(mouse_pos: Vector2) -> void:
	var global_mouse = mouse_pos
	var board_local_pos = board.to_local(global_mouse)
	var grid_pos = board._world_to_grid(board_local_pos)

	# ซ่อน placeholder เก่า (TODO: optimize นี้)
	for x in range(board.grid_size):
		for y in range(board.grid_size):
			board.show_placeholder(Vector2i(x, y), false)

	# แสดง placeholder ใหม่ **เฉพาะ** ถ้า valid และว่าง
	if board.is_position_valid(grid_pos):
		if board.is_position_empty(grid_pos):
			board.show_placeholder(grid_pos, true)

## วางพืชที่ตำแหน่ง mouse
func _try_place_plant_at_mouse(mouse_pos: Vector2) -> void:
	# ป้องกัน double-click
	if is_placing_plant:
		return

	is_placing_plant = true

	# แปลง screen mouse position -> board local position
	# mouse_pos จาก event.position เป็น viewport position
	# ต้องแปลงเป็น global position ก่อน แล้วค่อยแปลงเป็น local ของ board
	var global_mouse = mouse_pos  # ใน 2D game viewport = global
	var board_local_pos = board.to_local(global_mouse)
	var grid_pos = board._world_to_grid(board_local_pos)

	print("Mouse: %s -> Board local: %s -> Grid: %s" % [mouse_pos, board_local_pos, grid_pos])

	if not board.is_position_valid(grid_pos):
		is_placing_plant = false
		return

	if not board.is_position_empty(grid_pos):
		is_placing_plant = false
		return

	# ดึงพืชจาก hand
	var plant = season_manager.get_next_plant_to_place()
	if not plant:
		push_warning("No plant available in hand to place")
		is_placing_plant = false
		return

	print("Placing plant: %s" % plant.plant_name)

	# วางพืช
	var success = board.place_plant(plant, grid_pos)

	if success:
		# อัพเดท hand state
		season_manager.advance_plant_index()
		season_manager.place_plant_in_hand()

		# อัพเดท HUD
		hud.update_hand_info()
	else:
		push_warning("Failed to place plant: %s" % plant.plant_name)

	is_placing_plant = false
