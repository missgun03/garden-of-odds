extends Node2D
class_name Plant

## Plant: ต้นไม้แต่ละต้นที่มี trigger(ctx) คืน event Dictionary
## Event format: {pid: int, P: float, L: float, type: String, entropy_delta: float}

# Plant data (from garden_plants_12.csv schema)
@export var plant_id: int = -1
@export var plant_name: String = ""
@export var role: String = "Energy"  # Energy, Sap, Support, Control, Spore, Meta, Burst
@export var p_base: int = 5
@export var l_min: float = 1.0
@export var l_max: float = 2.0
@export var entropy_on_event: float = 0.3
@export var tags: Array[String] = []  # ["light", "buff", "engine"]

# Runtime state
var grid_pos: Vector2i = Vector2i(-1, -1)  # ตำแหน่งบนกระดาน
var buff_stacks: int = 0
var is_alive: bool = true

# Reference to Board (set by Board when placing)
var board: Node = null

signal plant_triggered(event: Dictionary)

func _ready() -> void:
	# เพิ่ม visual placeholder
	_setup_visual()

## Setup visual (สามารถ override ได้)
func _setup_visual() -> void:
	# สร้าง sprite/shape placeholder
	var shape = ColorRect.new()
	shape.size = Vector2(32, 32)
	shape.position = Vector2(-16, -16)
	shape.color = _get_role_color()
	add_child(shape)

	# เพิ่ม label
	var label = Label.new()
	label.text = plant_name if plant_name else "Plant"
	label.position = Vector2(-15, -20)
	label.add_theme_font_size_override("font_size", 10)
	add_child(label)

func _get_role_color() -> Color:
	match role:
		"Energy": return Color.YELLOW
		"Sap": return Color.GREEN
		"Support": return Color.CYAN
		"Control": return Color.BLUE
		"Spore": return Color.PURPLE
		"Meta": return Color.MAGENTA
		"Burst": return Color.ORANGE_RED
		_: return Color.WHITE

## คำนวณ L จาก context (override ในแต่ละพืชเพื่อใส่ logic เฉพาะ)
## ctx = {neighbors: Array[Plant], board_state: Dictionary, ...}
func calculate_L(ctx: Dictionary) -> float:
	# Base implementation: คืน l_min (override ในแต่ละพืชเพื่อใส่ logic)
	return l_min

## Trigger event: คำนวณและคืน event Dictionary
## ctx = {neighbors: Array[Plant], board_state: Dictionary, phase: String, ...}
func trigger(ctx: Dictionary) -> Dictionary:
	if not is_alive:
		return {}

	# คำนวณ L จาก context
	var L: float = calculate_L(ctx)
	L = clamp(L, l_min, l_max)

	# สร้าง event
	var event = {
		"pid": plant_id,
		"P": float(p_base),
		"L": L,
		"type": role,
		"entropy_delta": entropy_on_event,
		"plant_name": plant_name,
		"grid_pos": grid_pos
	}

	emit_signal("plant_triggered", event)
	return event

## ตัวอย่าง utility functions สำหรับ subclass
func get_neighbors() -> Array:
	if board:
		return board.get_neighbors(grid_pos)
	return []

func get_orthogonal_neighbors() -> Array:
	if board:
		return board.get_orthogonal_neighbors(grid_pos)
	return []

func count_neighbors_with_tag(tag: String) -> int:
	var count = 0
	for neighbor in get_neighbors():
		if neighbor is Plant and tag in neighbor.tags:
			count += 1
	return count

func count_empty_orthogonal_cells() -> int:
	if not board:
		return 0
	var empty = 0
	var orthogonal_offsets = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
	for offset in orthogonal_offsets:
		var neighbor_pos = grid_pos + offset
		if board.is_position_valid(neighbor_pos) and not board.get_plant_at(neighbor_pos):
			empty += 1
	return empty

func die() -> void:
	is_alive = false
	modulate = Color(0.5, 0.5, 0.5, 0.7)  # Visual feedback
