extends Node
class_name PlantFactory

## PlantFactory: สร้าง Plant instances จากข้อมูลที่โหลดโดย DataLoader
## ใช้ LRuleEvaluator เพื่อคำนวณ L

# References (set by Main)
var data_loader: DataLoader = null
var l_rule_evaluator: LRuleEvaluator = null

# Plant ID counter (for unique plant instances)
var next_plant_id: int = 0

## สร้างพืชจากชื่อ
## plant_name: ชื่อพืช (เช่น "Sunbud", "Seedbomb")
## Returns: Plant instance หรือ null ถ้าไม่พบข้อมูล
func create_plant_by_name(plant_name: String) -> Plant:
	if not data_loader:
		push_error("PlantFactory: DataLoader not set")
		return null

	if not data_loader.is_loaded:
		push_error("PlantFactory: Data not loaded yet")
		return null

	var plant_data = data_loader.get_plant_by_name(plant_name)
	if plant_data.is_empty():
		push_error("PlantFactory: Plant data not found for: %s" % plant_name)
		return null

	return _create_plant_from_data(plant_data)

## สร้างพืชจากข้อมูล dictionary
func _create_plant_from_data(plant_data: Dictionary) -> Plant:
	# สร้าง Plant instance ใหม่
	var plant = Plant.new()

	# Set plant ID
	plant.plant_id = next_plant_id
	next_plant_id += 1

	# Set basic properties จากข้อมูล
	plant.plant_name = plant_data.get("name", "Unknown")
	plant.role = plant_data.get("role", "Energy")
	plant.p_base = plant_data.get("p_base", 5)
	plant.l_min = plant_data.get("l_min", 1.0)
	plant.l_max = plant_data.get("l_max", 2.0)
	plant.entropy_on_event = plant_data.get("entropy_on_event", 0.3)

	# Set tags (convert Array to Array[String])
	var tags_data = plant_data.get("tags", [])
	var plant_tags: Array[String] = []
	for tag in tags_data:
		if tag is String:
			plant_tags.append(tag)
	plant.tags = plant_tags

	# Store l_rule for later evaluation
	var l_rule = plant_data.get("l_rule", "")
	plant.set_meta("l_rule", l_rule)

	# Override calculate_L method with custom logic
	# Note: In Godot, we can't easily override methods at runtime,
	# so we'll call the evaluator from the base Plant class
	if l_rule_evaluator:
		plant.set_meta("l_rule_evaluator", l_rule_evaluator)

	# Create visual representation (simple colored square for now)
	_create_plant_visual(plant)

	return plant

## สร้าง visual สำหรับพืช (placeholder - แทนที่ด้วย sprite ภายหลัง)
func _create_plant_visual(plant: Plant) -> void:
	var sprite = ColorRect.new()
	sprite.size = Vector2(48, 48)
	sprite.position = Vector2(-24, -24)  # Center the sprite

	# Set color based on role
	var color = _get_role_color(plant.role)
	sprite.color = color

	plant.add_child(sprite)

	# Add label with plant name
	var label = Label.new()
	label.text = plant.plant_name.substr(0, 3)  # First 3 letters
	label.position = Vector2(-16, -8)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color.WHITE)
	plant.add_child(label)

## กำหนดสีตาม role
func _get_role_color(role: String) -> Color:
	match role:
		"Energy":
			return Color(1.0, 0.9, 0.2)  # Yellow
		"Sap":
			return Color(0.2, 0.8, 0.4)  # Green
		"Support":
			return Color(0.4, 0.7, 1.0)  # Blue
		"Control":
			return Color(0.6, 0.4, 1.0)  # Purple
		"Spore":
			return Color(0.8, 0.3, 0.8)  # Magenta
		"Meta":
			return Color(0.9, 0.5, 0.2)  # Orange
		"Burst":
			return Color(1.0, 0.3, 0.2)  # Red
		_:
			return Color(0.7, 0.7, 0.7)  # Gray

## สร้างพืชแบบสุ่มจาก pool
## count: จำนวนพืชที่ต้องการ
## Returns: Array of Plant instances
func create_random_plants(count: int) -> Array[Plant]:
	if not data_loader or not data_loader.is_loaded:
		push_error("PlantFactory: DataLoader not ready")
		return []

	var plants: Array[Plant] = []
	var plant_names = data_loader.get_all_plant_names()

	if plant_names.is_empty():
		push_error("PlantFactory: No plant data available")
		return []

	for i in range(count):
		var random_name = plant_names[randi() % plant_names.size()]
		var plant = create_plant_by_name(random_name)
		if plant:
			plants.append(plant)

	return plants

## สร้างพืชจากรายชื่อ
## plant_names: Array of String
## Returns: Array of Plant instances
func create_plants_from_names(plant_names: Array[String]) -> Array[Plant]:
	var plants: Array[Plant] = []

	for name in plant_names:
		var plant = create_plant_by_name(name)
		if plant:
			plants.append(plant)

	return plants

## รีเซ็ต plant ID counter
func reset_plant_id_counter() -> void:
	next_plant_id = 0
