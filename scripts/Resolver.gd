extends Node
class_name Resolver

## Resolver: คำนวณคะแนนและ Entropy ตามสูตรใน 3-Scoring-Entropy-Spec.md
## สูตร:
##   EventScore = P × L × C
##   C = 1 + α·ln(1 + ChainLen)  where α = 0.8
##   PhaseTotal = Σ EventScore × (M_set × M_mut × M_biome × M_entropy)
##   M_entropy = 1 + β·Entropy^γ  where β = 0.02, γ = 0.8 (softcap ~7×)

# Constants from spec
const ALPHA: float = 0.8      # Chain multiplier coefficient
const BETA: float = 0.02      # Entropy multiplier coefficient
const GAMMA: float = 0.8      # Entropy exponent
const E_CAP: float = 100.0    # Entropy cap (Grove difficulty)
const M_ENTROPY_SOFTCAP: float = 7.0  # Entropy multiplier softcap

## คำนวณตัวคูณเชน: C = 1 + 0.8·ln(1 + ChainLen)
func calculate_chain_multiplier(chain_len: int) -> float:
	if chain_len < 0:
		chain_len = 0
	return 1.0 + ALPHA * log(1.0 + float(chain_len))

## คำนวณตัวคูณ Entropy: M_entropy = 1 + 0.02·Entropy^0.8 (softcap ~7×)
func calculate_entropy_multiplier(entropy: float) -> float:
	if entropy < 0:
		entropy = 0
	var raw_mult = 1.0 + BETA * pow(entropy, GAMMA)
	# Apply softcap
	return min(raw_mult, M_ENTROPY_SOFTCAP)

## คำนวณคะแนนต่อ event: EventScore = P × L × C
## event = {pid: int, P: float, L: float, type: String, chain_pos: int}
func calculate_event_score(event: Dictionary, chain_multiplier: float) -> float:
	var P: float = event.get("P", 0.0)
	var L: float = event.get("L", 1.0)
	return P * L * chain_multiplier

## Resolve ทั้ง phase: คำนวณคะแนนรวมและ entropy ที่เกิดขึ้น
## Input:
##   events: Array[Dictionary] - รายการ event ที่เกิดขึ้นในเฟส (เรียงตาม chain)
##   current_entropy: float - Entropy ปัจจุบันก่อน resolve
##   modifiers: Dictionary - {M_set, M_mut, M_biome, overgrow_active}
## Output:
##   {score: int, entropy: float, breakdown: Array}
func resolve_phase(events: Array, current_entropy: float, modifiers: Dictionary = {}) -> Dictionary:
	var M_set: float = modifiers.get("M_set", 1.0)
	var M_mut: float = modifiers.get("M_mut", 1.0)
	var M_biome: float = modifiers.get("M_biome", 1.0)
	var overgrow_active: bool = modifiers.get("overgrow_active", false)

	# คำนวณตัวคูณ entropy จาก entropy ปัจจุบัน
	var M_entropy: float = calculate_entropy_multiplier(current_entropy)

	var chain_len: int = events.size()

	# Overgrow: +1 ChainLen
	if overgrow_active and chain_len > 0:
		chain_len += 1

	# คำนวณตัวคูณเชน
	var C: float = calculate_chain_multiplier(chain_len)

	# คำนวณคะแนนแต่ละ event
	var phase_base: float = 0.0
	var entropy_gained: float = 0.0
	var breakdown: Array = []

	for i in range(events.size()):
		var event: Dictionary = events[i]

		# Overgrow: +0.3 L สำหรับทุก event
		var L: float = event.get("L", 1.0)
		if overgrow_active:
			L += 0.3

		var modified_event = event.duplicate()
		modified_event["L"] = L

		var event_score: float = calculate_event_score(modified_event, C)
		phase_base += event_score

		# รวม entropy ที่เกิดจาก event
		var event_entropy: float = event.get("entropy_delta", 0.0)
		entropy_gained += event_entropy

		breakdown.append({
			"event_index": i,
			"pid": event.get("pid", -1),
			"type": event.get("type", "unknown"),
			"P": event.get("P", 0.0),
			"L": L,
			"C": C,
			"event_score": event_score,
			"entropy_delta": event_entropy
		})

	# Overgrow: +3 Entropy
	if overgrow_active:
		entropy_gained += 3.0

	# คำนวณคะแนนรวม: PhaseTotal = PhaseBase × (M_set × M_mut × M_biome × M_entropy)
	var phase_total: float = phase_base * M_set * M_mut * M_biome * M_entropy

	# อัพเดท entropy (cap ที่ E_cap)
	var new_entropy: float = min(current_entropy + entropy_gained, E_CAP)

	return {
		"score": int(phase_total),
		"entropy": new_entropy,
		"entropy_gained": entropy_gained,
		"chain_len": chain_len,
		"C": C,
		"M_entropy": M_entropy,
		"phase_base": phase_base,
		"breakdown": breakdown,
		"multipliers": {
			"M_set": M_set,
			"M_mut": M_mut,
			"M_biome": M_biome,
			"M_entropy": M_entropy
		}
	}

## ใช้ Stabilize: ลด entropy -20%
func apply_stabilize(current_entropy: float, coins: int) -> Dictionary:
	const STABILIZE_COST: int = 10

	if coins < STABILIZE_COST:
		return {"success": false, "entropy": current_entropy, "coins": coins, "error": "Not enough coins"}

	var reduced_entropy: float = current_entropy * 0.8  # -20%

	return {
		"success": true,
		"entropy": reduced_entropy,
		"coins": coins - STABILIZE_COST,
		"reduction": current_entropy - reduced_entropy
	}

## เช็คว่า collapse หรือไม่ (entropy >= E_cap)
func check_collapse(entropy: float) -> bool:
	return entropy >= E_CAP
