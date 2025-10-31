extends Node
class_name LRuleEvaluator

## LRuleEvaluator: ประมวลผล L rules จากข้อมูลพืช
## รองรับ patterns พื้นฐาน:
## - "+X per adjacent plant" / "+X per neighbor"
## - "+X if neighbor is PlantName"
## - "×X if unblocked" / "×X if not blocked"
## - "+X per empty orthogonal cell"

## ประมวลผล rule และคืนค่า L
## ctx: Dictionary from board.create_trigger_context()
##      {neighbors, orthogonal_neighbors, board_state, grid_size, plant_count}
## plant: Plant instance ที่กำลังคำนวณ L
## l_rule: String rule จาก CSV
## l_min: ค่าต่ำสุดของ L
func evaluate(ctx: Dictionary, plant: Plant, l_rule: String, l_min: float) -> float:
	if l_rule.is_empty():
		return l_min

	var L = l_min
	var multiplier = 1.0

	# แยก rule ด้วย semicolon (;)
	var sub_rules = l_rule.split(";")

	for sub_rule in sub_rules:
		var rule = sub_rule.strip_edges().to_lower()

		if rule.is_empty():
			continue

		# Pattern: "+X per adjacent plant" / "+X per neighbor"
		if "per adjacent plant" in rule or "per neighbor" in rule:
			var value = _extract_numeric_value(rule)
			var neighbors = ctx.get("neighbors", [])
			var count = 0
			for neighbor in neighbors:
				if neighbor is Plant and neighbor.is_alive:
					count += 1
			L += value * count

		# Pattern: "+X per affected orthogonal neighbor"
		elif "per affected orthogonal neighbor" in rule or "per orthogonal neighbor" in rule:
			var value = _extract_numeric_value(rule)
			var ortho_neighbors = ctx.get("orthogonal_neighbors", [])
			var count = 0
			for neighbor in ortho_neighbors:
				if neighbor is Plant and neighbor.is_alive:
					count += 1
			L += value * count

		# Pattern: "+X if neighbor is PlantName"
		elif "if neighbor is" in rule:
			var value = _extract_numeric_value(rule)
			var plant_names = _extract_plant_names(rule)
			var neighbors = ctx.get("neighbors", [])

			for neighbor in neighbors:
				if neighbor is Plant and neighbor.is_alive:
					if neighbor.plant_name in plant_names:
						L += value

		# Pattern: "+X per empty orthogonal cell"
		elif "per empty orthogonal cell" in rule:
			var value = _extract_numeric_value(rule)
			var empty_count = _count_empty_orthogonal_cells(ctx, plant)
			L += value * empty_count

		# Pattern: "×X if unblocked" / "×X if not blocked" / "×X if tile is unblocked"
		elif ("if unblocked" in rule or "if not blocked" in rule or "if tile is unblocked" in rule):
			var value = _extract_multiplier_value(rule)
			if _is_unblocked(ctx, plant):
				multiplier *= value

		# Pattern: "×X if ..." (other multiplier conditions)
		elif rule.begins_with("×") or rule.begins_with("x"):
			var _value = _extract_multiplier_value(rule)
			# For now, just apply the multiplier (full condition checking requires more context)
			# TODO: Implement specific condition checking
			# multiplier *= _value

		# Pattern: "+X per ..." (generic additive)
		elif "+0." in rule or "+1." in rule or "+2." in rule:
			# Already handled by specific patterns above
			pass

	# Apply multiplier
	L *= multiplier

	return L

## แยกค่าตัวเลขจาก rule (เช่น "+0.2 per..." -> 0.2)
func _extract_numeric_value(rule: String) -> float:
	var regex = RegEx.new()
	regex.compile(r"[+\-]?\d+\.?\d*")
	var result = regex.search(rule)
	if result:
		return result.get_string().to_float()
	return 0.0

## แยกค่า multiplier จาก rule (เช่น "×1.5 if..." -> 1.5)
func _extract_multiplier_value(rule: String) -> float:
	var regex = RegEx.new()
	regex.compile(r"[×x]\s*(\d+\.?\d*)")
	var result = regex.search(rule)
	if result:
		return result.get_string(1).to_float()
	return 1.0

## แยกชื่อพืชจาก rule (เช่น "if neighbor is Seedbomb or Honeyroot" -> ["Seedbomb", "Honeyroot"])
func _extract_plant_names(rule: String) -> Array[String]:
	var names: Array[String] = []

	# Find "is PlantName" pattern
	var regex = RegEx.new()
	regex.compile(r"is\s+([A-Z][a-z]+)")
	var results = regex.search_all(rule)

	for result in results:
		var plant_name = result.get_string(1)
		names.append(plant_name)

	# Also check for "or PlantName" pattern
	var or_regex = RegEx.new()
	or_regex.compile(r"or\s+([A-Z][a-z]+)")
	var or_results = or_regex.search_all(rule)

	for result in or_results:
		var plant_name = result.get_string(1)
		if not names.has(plant_name):
			names.append(plant_name)

	return names

## นับจำนวน empty orthogonal cells รอบพืช
func _count_empty_orthogonal_cells(_ctx: Dictionary, plant: Plant) -> int:
	if not plant.board:
		return 0

	var board = plant.board
	var pos = plant.grid_pos
	var offsets = [
		Vector2i(0, -1),  # บน
		Vector2i(0, 1),   # ล่าง
		Vector2i(-1, 0),  # ซ้าย
		Vector2i(1, 0)    # ขวา
	]

	var empty_count = 0
	for offset in offsets:
		var check_pos = pos + offset
		if board.is_position_valid(check_pos) and board.is_position_empty(check_pos):
			empty_count += 1

	return empty_count

## ตรวจสอบว่าพืชอยู่ในตำแหน่งที่ "unblocked" (ไม่มีพืชด้านบน)
func _is_unblocked(_ctx: Dictionary, plant: Plant) -> bool:
	if not plant.board:
		return false

	var board = plant.board
	var pos = plant.grid_pos

	# Check if there's a plant directly above (y-1)
	var above_pos = Vector2i(pos.x, pos.y - 1)

	# If position above is outside grid, consider it unblocked (edge case)
	if not board.is_position_valid(above_pos):
		# If we're at the top edge, we're unblocked
		return pos.y == 0

	# If position above is empty, we're unblocked
	return board.is_position_empty(above_pos)
