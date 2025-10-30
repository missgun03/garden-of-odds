extends Plant
class_name Sunbud

## Sunbud: Energy plant
## Rule: +0.2 per adjacent plant; +0.4 if neighbor is Seedbomb or Honeyroot
## From garden_plants_12.csv

func _init() -> void:
	plant_name = "Sunbud"
	role = "Energy"
	p_base = 5
	l_min = 1.0
	l_max = 2.2
	entropy_on_event = 0.3
	tags = ["light", "buff", "engine"]

## Override calculate_L to implement Sunbud's specific rule
func calculate_L(ctx: Dictionary) -> float:
	var L: float = l_min

	# +0.2 per adjacent plant
	var neighbors = ctx.get("neighbors", [])
	for neighbor in neighbors:
		if neighbor is Plant and neighbor.is_alive:
			L += 0.2

			# +0.4 if neighbor is Seedbomb or Honeyroot (instead of +0.2)
			if neighbor.plant_name in ["Seedbomb", "Honeyroot"]:
				L += 0.2  # รวมเป็น +0.4

	return clamp(L, l_min, l_max)
