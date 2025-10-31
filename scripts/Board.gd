extends Node2D
class_name Board

## Board: กระดานวางพืช พร้อม API place/remove และ neighbor lookup
## Grid: 5×5 หรือ 7×7 (configurable)

@export var grid_size: int = 5  # ขนาดกระดาน (5×5 or 7×7)
@export var cell_size: int = 64  # ขนาดแต่ละช่อง (pixels)

# Grid data: Dictionary[Vector2i, Plant]
var grid: Dictionary = {}

# Placeholder nodes for visual feedback
var placeholders: Dictionary = {}  # Vector2i -> ColorRect

signal plant_placed(plant: Plant, pos: Vector2i)
signal plant_removed(plant: Plant, pos: Vector2i)

func _ready() -> void:
	_setup_grid_visuals()

## สร้าง visual grid
func _setup_grid_visuals() -> void:
	# สร้าง border รอบกระดาน
	var border = ColorRect.new()
	border.size = Vector2(grid_size * cell_size + 4, grid_size * cell_size + 4)
	border.position = Vector2(-2, -2)
	border.color = Color(0.8, 0.8, 0.8, 0.5)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(border)

	# สร้าง grid cells
	for x in range(grid_size):
		for y in range(grid_size):
			var pos = Vector2i(x, y)
			var rect = ColorRect.new()
			rect.size = Vector2(cell_size - 2, cell_size - 2)
			rect.position = _grid_to_world(pos)
			rect.color = Color(0.2, 0.2, 0.2, 0.3)
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(rect)
			placeholders[pos] = rect

## แปลง grid position -> world position
func _grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(
		grid_pos.x * cell_size + cell_size / 2.0,
		grid_pos.y * cell_size + cell_size / 2.0
	)

## แปลง world position -> grid position
func _world_to_grid(world_pos: Vector2) -> Vector2i:
	# world position เป็น local position ของ board (relative to board origin)
	# แปลงเป็น grid index โดยหารด้วย cell_size
	# ใช้ floor() เพื่อให้ค่าติดลบยังคงเป็นลบ (ไม่ปัดเป็น 0)
	var grid_x = int(floor(world_pos.x / cell_size))
	var grid_y = int(floor(world_pos.y / cell_size))
	return Vector2i(grid_x, grid_y)

## ตรวจสอบว่าตำแหน่งถูกต้องหรือไม่
func is_position_valid(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < grid_size and pos.y >= 0 and pos.y < grid_size

## ตรวจสอบว่าตำแหน่งว่างหรือไม่
func is_position_empty(pos: Vector2i) -> bool:
	return is_position_valid(pos) and not grid.has(pos)

## วางพืชบนกระดาน
## Returns: true ถ้าวางสำเร็จ, false ถ้าตำแหน่งไม่ถูกต้องหรือมีพืชอยู่แล้ว
func place_plant(plant: Plant, pos: Vector2i) -> bool:
	if not is_position_valid(pos):
		push_error("Board.place_plant: Invalid position %s" % pos)
		return false

	if grid.has(pos):
		push_error("Board.place_plant: Position %s already occupied" % pos)
		return false

	# วางพืช
	grid[pos] = plant
	plant.grid_pos = pos
	plant.board = self
	plant.position = _grid_to_world(pos)

	# เพิ่มเป็น child
	add_child(plant)

	# อัพเดท placeholder
	if placeholders.has(pos):
		placeholders[pos].color = Color(0.3, 0.5, 0.3, 0.5)  # เปลี่ยนสีแสดงว่ามีพืช

	emit_signal("plant_placed", plant, pos)
	return true

## ลบพืชออกจากกระดาน
## Returns: Plant ที่ถูกลบ หรือ null ถ้าไม่มีพืช
func remove_plant(pos: Vector2i) -> Plant:
	if not grid.has(pos):
		return null

	var plant: Plant = grid[pos]
	grid.erase(pos)

	# ลบจาก scene tree
	if plant.get_parent() == self:
		remove_child(plant)

	# รีเซ็ต placeholder
	if placeholders.has(pos):
		placeholders[pos].color = Color(0.2, 0.2, 0.2, 0.3)

	emit_signal("plant_removed", plant, pos)
	return plant

## ดึงพืชที่ตำแหน่ง
func get_plant_at(pos: Vector2i) -> Plant:
	return grid.get(pos, null)

## ดึง neighbors ทั้งหมด (8 ทิศ)
func get_neighbors(pos: Vector2i) -> Array:
	var neighbors: Array = []
	var offsets = [
		Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
		Vector2i(-1, 0),                   Vector2i(1, 0),
		Vector2i(-1, 1),  Vector2i(0, 1),  Vector2i(1, 1)
	]

	for offset in offsets:
		var neighbor_pos = pos + offset
		if grid.has(neighbor_pos):
			neighbors.append(grid[neighbor_pos])

	return neighbors

## ดึง orthogonal neighbors (4 ทิศ: บน ล่าง ซ้าย ขวา)
func get_orthogonal_neighbors(pos: Vector2i) -> Array:
	var neighbors: Array = []
	var offsets = [
		Vector2i(0, -1),  # บน
		Vector2i(0, 1),   # ล่าง
		Vector2i(-1, 0),  # ซ้าย
		Vector2i(1, 0)    # ขวา
	]

	for offset in offsets:
		var neighbor_pos = pos + offset
		if grid.has(neighbor_pos):
			neighbors.append(grid[neighbor_pos])

	return neighbors

## แสดง placeholder (highlight ตำแหน่งที่จะวาง)
func show_placeholder(pos: Vector2i, should_show: bool = true) -> void:
	if not placeholders.has(pos):
		return

	if should_show and is_position_empty(pos):
		placeholders[pos].color = Color(0.5, 0.8, 0.5, 0.6)  # เขียวสว่าง
	else:
		# รีเซ็ตกลับเป็นสีปกติ
		if is_position_empty(pos):
			placeholders[pos].color = Color(0.2, 0.2, 0.2, 0.3)
		else:
			placeholders[pos].color = Color(0.3, 0.5, 0.3, 0.5)

## ดึงพืชทั้งหมดบนกระดาน
func get_all_plants() -> Array:
	return grid.values()

## นับจำนวนพืชบนกระดาน
func get_plant_count() -> int:
	return grid.size()

## ล้างกระดาน
func clear_board() -> void:
	for plant in grid.values():
		if plant.get_parent() == self:
			remove_child(plant)
		plant.queue_free()

	grid.clear()

	# รีเซ็ต placeholders
	for pos in placeholders.keys():
		placeholders[pos].color = Color(0.2, 0.2, 0.2, 0.3)

## สร้าง context สำหรับ trigger
func create_trigger_context(pos: Vector2i) -> Dictionary:
	return {
		"neighbors": get_neighbors(pos),
		"orthogonal_neighbors": get_orthogonal_neighbors(pos),
		"board_state": grid.duplicate(),
		"grid_size": grid_size,
		"plant_count": get_plant_count()
	}
