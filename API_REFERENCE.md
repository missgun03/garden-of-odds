# Garden of Odds - API Reference

## Board API

### Core Methods

```gdscript
# วางพืชบนกระดาน
func place_plant(plant: Plant, pos: Vector2i) -> bool

# ลบพืชออกจากกระดาน
func remove_plant(pos: Vector2i) -> Plant

# ดึงพืชที่ตำแหน่ง
func get_plant_at(pos: Vector2i) -> Plant

# ดึง neighbors ทั้งหมด (8 ทิศ)
func get_neighbors(pos: Vector2i) -> Array

# ดึง orthogonal neighbors (4 ทิศ)
func get_orthogonal_neighbors(pos: Vector2i) -> Array

# แสดง placeholder highlight
func show_placeholder(pos: Vector2i, show: bool = true) -> void

# ตรวจสอบว่าตำแหน่งถูกต้อง
func is_position_valid(pos: Vector2i) -> bool

# ตรวจสอบว่าตำแหน่งว่าง
func is_position_empty(pos: Vector2i) -> bool

# สร้าง context สำหรับ trigger
func create_trigger_context(pos: Vector2i) -> Dictionary
```

### Signals

```gdscript
signal plant_placed(plant: Plant, pos: Vector2i)
signal plant_removed(plant: Plant, pos: Vector2i)
```

---

## Plant API

### Base Class

```gdscript
# Properties
@export var plant_id: int
@export var plant_name: String
@export var role: String
@export var p_base: int
@export var l_min: float
@export var l_max: float
@export var entropy_on_event: float
@export var tags: Array[String]

# Runtime state
var grid_pos: Vector2i
var buff_stacks: int
var is_alive: bool
var board: Node
```

### Methods to Override

```gdscript
# คำนวณ L จาก context (ใส่กติกาเฉพาะพืช)
func calculate_L(ctx: Dictionary) -> float

# Trigger event (ปกติไม่ต้อง override)
func trigger(ctx: Dictionary) -> Dictionary
```

### Utility Methods

```gdscript
func get_neighbors() -> Array
func get_orthogonal_neighbors() -> Array
func count_neighbors_with_tag(tag: String) -> int
func count_empty_orthogonal_cells() -> int
func die() -> void
```

### Event Dictionary Format

```gdscript
{
    "pid": int,              # Plant ID
    "P": float,              # Base power
    "L": float,              # Local multiplier
    "type": String,          # Role/type
    "entropy_delta": float,  # Entropy gained
    "plant_name": String,
    "grid_pos": Vector2i
}
```

### Signals

```gdscript
signal plant_triggered(event: Dictionary)
```

---

## Resolver API

### Constants

```gdscript
const ALPHA: float = 0.8      # Chain multiplier coefficient
const BETA: float = 0.02      # Entropy multiplier coefficient
const GAMMA: float = 0.8      # Entropy exponent
const E_CAP: float = 100.0    # Entropy cap (Grove)
const M_ENTROPY_SOFTCAP: float = 7.0
```

### Core Methods

```gdscript
# คำนวณตัวคูณเชน: C = 1 + 0.8·ln(1 + ChainLen)
func calculate_chain_multiplier(chain_len: int) -> float

# คำนวณตัวคูณ Entropy: M = 1 + 0.02·E^0.8
func calculate_entropy_multiplier(entropy: float) -> float

# คำนวณคะแนนต่อ event: EventScore = P × L × C
func calculate_event_score(event: Dictionary, chain_multiplier: float) -> float

# Resolve ทั้ง phase
func resolve_phase(events: Array, current_entropy: float, modifiers: Dictionary) -> Dictionary

# ใช้ Stabilize
func apply_stabilize(current_entropy: float, coins: int) -> Dictionary

# เช็ค collapse
func check_collapse(entropy: float) -> bool
```

### resolve_phase Input

```gdscript
events: Array[Dictionary]  # รายการ events จาก plant triggers
current_entropy: float     # Entropy ปัจจุบัน
modifiers: Dictionary = {
    "M_set": 1.0,
    "M_mut": 1.0,
    "M_biome": 1.0,
    "overgrow_active": false
}
```

### resolve_phase Output

```gdscript
{
    "score": int,           # คะแนนรวม
    "entropy": float,       # Entropy ใหม่
    "entropy_gained": float,
    "chain_len": int,
    "C": float,             # Chain multiplier ที่ใช้
    "M_entropy": float,     # Entropy multiplier ที่ใช้
    "phase_base": float,
    "breakdown": Array,     # รายละเอียดแต่ละ event
    "multipliers": {
        "M_set": float,
        "M_mut": float,
        "M_biome": float,
        "M_entropy": float
    }
}
```

---

## SeasonManager API

### States (Enum)

```gdscript
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
```

### Properties

```gdscript
@export var season_id: int
@export var target_score: int
@export var plants_per_hand: int
@export var mini_bloom_duration: float  # 0.8s
@export var full_bloom_duration: float  # 2.5s

var current_state: SeasonState
var season_score: int
var current_entropy: float
```

### Core Methods

```gdscript
# เริ่ม season
func start_season(season_config: Dictionary) -> void

# เลือก draft stack
func select_draft_stack(stack_index: int) -> void

# Reroll draft stacks (1 ครั้ง/ฤดู)
func reroll_draft_stacks() -> void

# เริ่ม hand
func start_hand(hand_number: int) -> void

# วางพืชในมือปัจจุบัน
func place_plant_in_hand() -> void

# Get state name
func get_state_name() -> String
```

### Signals

```gdscript
signal state_changed(new_state: SeasonState)
signal season_completed(passed: bool, score: int)
signal bloom_started(is_mini: bool)
signal bloom_finished()
signal draft_stack_ready(stacks: Array)
```

---

## HUD API

### Properties

```gdscript
var coins: int
var overgrow_active: bool
var stabilize_used_this_season: bool
```

### Core Methods

```gdscript
# อัพเดท UI
func update_display(score: int, target: int, entropy: float) -> void

# แสดง draft stacks
func show_draft_stacks(stacks: Array) -> void

# ซ่อน draft stacks
func hide_draft_stacks() -> void

# รีเซ็ตสำหรับฤดูใหม่
func reset_for_new_season() -> void

# รีเซ็ต Overgrow สำหรับมือใหม่
func reset_overgrow() -> void
```

### Signals

```gdscript
signal overgrow_pressed()
signal stabilize_pressed()
signal draft_stack_selected(stack_index: int)
```

---

## Main (Game Controller)

### Methods

```gdscript
# เริ่มเกม
func _start_game() -> void

# เริ่ม season
func _start_season(season_id: int) -> void

# ดึง season config จาก stages.json
func _get_season_config(season_id: int) -> Dictionary
```

### Signal Handlers

```gdscript
func _on_season_state_changed(new_state: SeasonState)
func _on_season_completed(passed: bool, score: int)
func _on_draft_stack_ready(stacks: Array)
func _on_draft_stack_selected(stack_index: int)
func _on_overgrow_pressed()
func _on_stabilize_pressed()
func _on_plant_placed(plant: Plant, pos: Vector2i)
```

---

## ตัวอย่างการใช้งาน

### 1. สร้างและวางพืช

```gdscript
# สร้างพืช
var plant = Sunbud.new()

# วางบนกระดาน
board.place_plant(plant, Vector2i(2, 3))
```

### 2. Trigger พืชและคำนวณคะแนน

```gdscript
# สร้าง context
var ctx = board.create_trigger_context(plant.grid_pos)

# Trigger พืช
var event = plant.trigger(ctx)

# รวม events จากพืชทั้งหมด
var events: Array = []
for p in board.get_all_plants():
    events.append(p.trigger(board.create_trigger_context(p.grid_pos)))

# Resolve phase
var result = resolver.resolve_phase(events, current_entropy, {
    "M_set": 1.0,
    "M_mut": 1.0,
    "M_biome": 1.0,
    "overgrow_active": false
})

print("Score: %d, Entropy: %.1f" % [result.score, result.entropy])
```

### 3. ใช้ Entropy Levers

```gdscript
# Overgrow: +3 entropy, +0.3 L, +1 chain
overgrow_active = true
var result = resolver.resolve_phase(events, entropy, {
    "overgrow_active": true
})

# Stabilize: -20% entropy, 10 coins
var stabilize_result = resolver.apply_stabilize(current_entropy, coins)
if stabilize_result.success:
    current_entropy = stabilize_result.entropy
    coins = stabilize_result.coins
```

### 4. เช็ค Gate

```gdscript
var passed = season_score >= target_score
var collapsed = resolver.check_collapse(current_entropy)

if collapsed:
    passed = false
    print("COLLAPSE!")
```

---

## สูตรสำคัญ (ห้ามเปลี่ยน)

### Event Score
```
EventScore = P × L × C
```

### Chain Multiplier
```
C = 1 + 0.8·ln(1 + ChainLen)
```

### Phase Total
```
PhaseTotal = Σ EventScore × (M_set × M_mut × M_biome × M_entropy)
```

### Entropy Multiplier
```
M_entropy = 1 + 0.02·Entropy^0.8  (softcap ~7×)
```

### Entropy Cap
```
E_cap = 100 (Grove difficulty)
Collapse if Entropy ≥ E_cap
```

### Overgrow
```
+3 Entropy
+0.3 L (for all events)
+1 ChainLen
```

### Stabilize
```
-20% Entropy
-10 Coins
1 time per season
```
