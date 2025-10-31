extends Node
class_name DataLoader

## DataLoader: โหลดข้อมูลจาก CSV/JSON ใน res://Document/data/
## ส่งออกเป็น dictionaries: plants[], mutations[], trials[], contracts[]

# Cache loaded data
var plants_data: Array = []
var mutations_data: Array = []
var trials_data: Array = []
var contracts_data: Array = []

var is_loaded: bool = false

## โหลดข้อมูลทั้งหมด
func load_all_data() -> void:
	if is_loaded:
		return

	print("DataLoader: Loading game data...")

	plants_data = load_plants()
	mutations_data = load_mutations()
	trials_data = load_trials()
	contracts_data = load_contracts()

	is_loaded = true
	print("DataLoader: All data loaded successfully")
	print("  - Plants: %d" % plants_data.size())
	print("  - Mutations: %d" % mutations_data.size())
	print("  - Trials: %d" % trials_data.size())
	print("  - Contracts: %d" % contracts_data.size())

## โหลดข้อมูลพืชจาก CSV
## Returns: Array of Dictionary {name, role, p_base, l_rule, l_min, l_max, entropy_on_event, tags, notes}
func load_plants() -> Array:
	var file_path = "res://Document/data/garden_plants_12.csv"

	if not FileAccess.file_exists(file_path):
		push_error("DataLoader: Plants file not found: %s" % file_path)
		return []

	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("DataLoader: Failed to open plants file")
		return []

	var plants: Array = []
	var line_num = 0

	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		line_num += 1

		# Skip header and empty lines
		if line_num == 1 or line.is_empty():
			continue

		# Parse CSV line
		var plant_dict = _parse_plant_csv_line(line)
		if not plant_dict.is_empty():
			plants.append(plant_dict)

	file.close()
	print("DataLoader: Loaded %d plants from CSV" % plants.size())
	return plants

## แปลง CSV line เป็น plant dictionary
func _parse_plant_csv_line(line: String) -> Dictionary:
	# Split by comma (simple CSV parser - doesn't handle quoted commas)
	var parts = line.split(",")

	if parts.size() < 9:
		push_warning("DataLoader: Invalid plant CSV line (too few columns)")
		return {}

	# Parse fields
	var name = parts[0].strip_edges()
	var role = parts[1].strip_edges()
	var p_base = parts[2].strip_edges().to_int()
	var l_rule = parts[3].strip_edges()
	var l_min = parts[4].strip_edges().to_float()
	var l_max = parts[5].strip_edges().to_float()
	var entropy_on_event = parts[6].strip_edges().to_float()
	var tags_str = parts[7].strip_edges()
	var notes = parts[8].strip_edges()

	# Parse tags (comma-separated within quotes or raw)
	var tags: Array[String] = []
	if not tags_str.is_empty():
		# Remove quotes if present
		tags_str = tags_str.trim_prefix("\"").trim_suffix("\"")
		var tag_parts = tags_str.split(",")
		for tag in tag_parts:
			var cleaned_tag = tag.strip_edges()
			if not cleaned_tag.is_empty():
				tags.append(cleaned_tag)

	return {
		"name": name,
		"role": role,
		"p_base": p_base,
		"l_rule": l_rule,
		"l_min": l_min,
		"l_max": l_max,
		"entropy_on_event": entropy_on_event,
		"tags": tags,
		"notes": notes
	}

## โหลดข้อมูล mutations จาก JSON
func load_mutations() -> Array:
	return _load_json_file("res://Document/data/garden_mutations_8.json", "mutations")

## โหลดข้อมูล trials จาก JSON
func load_trials() -> Array:
	return _load_json_file("res://Document/data/garden_trials_8.json", "trials")

## โหลดข้อมูล contracts จาก JSON
func load_contracts() -> Array:
	return _load_json_file("res://Document/data/garden_contracts_8.json", "contracts")

## โหลดไฟล์ JSON ทั่วไป
func _load_json_file(file_path: String, data_type: String) -> Array:
	if not FileAccess.file_exists(file_path):
		push_error("DataLoader: %s file not found: %s" % [data_type, file_path])
		return []

	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("DataLoader: Failed to open %s file" % data_type)
		return []

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)

	if parse_result != OK:
		push_error("DataLoader: Failed to parse %s JSON: %s" % [data_type, json.get_error_message()])
		return []

	var data = json.data
	if data is Array:
		print("DataLoader: Loaded %d %s from JSON" % [data.size(), data_type])
		return data
	else:
		push_error("DataLoader: %s JSON root is not an array" % data_type)
		return []

## ค้นหาพืชจากชื่อ
func get_plant_by_name(plant_name: String) -> Dictionary:
	for plant in plants_data:
		if plant.get("name", "") == plant_name:
			return plant

	push_warning("DataLoader: Plant not found: %s" % plant_name)
	return {}

## ค้นหา mutation จาก id
func get_mutation_by_id(mutation_id: String) -> Dictionary:
	for mutation in mutations_data:
		if mutation.get("id", "") == mutation_id:
			return mutation

	push_warning("DataLoader: Mutation not found: %s" % mutation_id)
	return {}

## ค้นหา trial จาก id
func get_trial_by_id(trial_id: String) -> Dictionary:
	for trial in trials_data:
		if trial.get("id", "") == trial_id:
			return trial

	push_warning("DataLoader: Trial not found: %s" % trial_id)
	return {}

## ค้นหา contract จาก id
func get_contract_by_id(contract_id: String) -> Dictionary:
	for contract in contracts_data:
		if contract.get("id", "") == contract_id:
			return contract

	push_warning("DataLoader: Contract not found: %s" % contract_id)
	return {}

## ดึงรายชื่อพืชทั้งหมด
func get_all_plant_names() -> Array[String]:
	var names: Array[String] = []
	for plant in plants_data:
		names.append(plant.get("name", ""))
	return names
