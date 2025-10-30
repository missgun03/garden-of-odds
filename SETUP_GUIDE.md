# Garden of Odds - Setup Guide

## โครงสร้างโปรเจกต์

```
garden-of-odds/
├── scripts/
│   ├── Main.gd              # Game controller
│   ├── Board.gd             # กระดาน 5×5 พร้อม API
│   ├── Plant.gd             # Base class สำหรับพืช
│   ├── Resolver.gd          # คำนวณคะแนนและ Entropy
│   ├── SeasonManager.gd     # จัดการ Season flow
│   ├── HUD.gd               # User Interface
│   └── plants/
│       └── Sunbud.gd        # ตัวอย่างพืช (extend Plant)
├── scenes/
│   └── Main.tscn            # Scene หลัก
├── resources/
│   └── stages.json          # ข้อมูล stages/gates
└── Document/                # เอกสารสเปก
```

## การเชื่อมโยงซีน (Main.tscn)

### Scene Tree Structure:
```
Main (Node) [Main.gd]
├── Board (Node2D) [Board.gd]
│   └── (พืชจะถูกเพิ่มเข้ามาที่นี่แบบ dynamic)
├── HUD (Control) [HUD.gd]
│   └── (UI elements สร้างใน _ready())
├── SeasonManager (Node) [SeasonManager.gd]
└── Resolver (Node) [Resolver.gd]
```

### การเชื่อม References (ใน Main.gd):

```gdscript
# Main.gd ทำหน้าที่เชื่อม references ระหว่าง nodes
func _connect_references() -> void:
    season_manager.board = board
    season_manager.resolver = resolver
    season_manager.hud = hud

    hud.season_manager = season_manager
    hud.resolver = resolver
```

### Signal Flow:

```
SeasonManager → Main → HUD/Board
    ↓
  Signals:
  - state_changed (เปลี่ยนสถานะฤดู)
  - season_completed (จบฤดู)
  - draft_stack_ready (พร้อมดราฟท์)

Board → Main → SeasonManager
    ↓
  Signals:
  - plant_placed (วางพืชแล้ว)
  - plant_removed (ลบพืช)

HUD → Main → SeasonManager
    ↓
  Signals:
  - overgrow_pressed
  - stabilize_pressed
  - draft_stack_selected
```

## วิธี Run โปรเจกต์

### 1. เปิดใน Godot Editor
```bash
# เปิด Godot 4.x และ import โปรเจกต์
# หรือใช้ command line:
godot --editor --path /home/user/garden-of-odds
```

### 2. ตรวจสอบ Scene
- เปิด `scenes/Main.tscn`
- ตรวจสอบว่า scripts ทั้งหมดโหลดได้ถูกต้อง (ไม่มีไอคอน warning)

### 3. Run (F5)
```
กด F5 หรือ Run > Run Project
```

### 4. การเล่น (Testing)
- **วางพืช**: คลิกบนกระดาน (Board) เพื่อวางพืชทดสอบ
- **Overgrow**: กดปุ่ม "Overgrow" เพื่อเพิ่ม entropy และ boost
- **Stabilize**: กดปุ่ม "Stabilize" เพื่อลด entropy (ใช้ 10 coins)
- **Draft**: เลือก stack จากปุ่มด้านบน (แสดงเมื่อเริ่มฤดู)

## Game Flow (ตาม Core-Loop-Spec)

### Season Structure:
1. **DRAFT_STACK** - เลือก 1 จาก 3 กอง (9 ใบ)
2. **HAND_1** - วาง 2-3 ต้น → **Mini-Bloom (0.8s)**
3. **HAND_2** - วาง 2-3 ต้น → **Full Bloom (2-3s)**
4. **GATE_CHECK** - เช็คว่าผ่านเป้าหมายหรือไม่
5. → ฤดูถัดไป (ถ้าผ่าน) หรือ Game Over

### Scoring Formula (ตาม 3-Scoring-Entropy-Spec):
```
EventScore = P × L × C
C = 1 + 0.8·ln(1 + ChainLen)
PhaseTotal = Σ EventScore × (M_set × M_mut × M_biome × M_entropy)
M_entropy = 1 + 0.02·Entropy^0.8 (softcap ~7×)
E_cap = 100 (Grove difficulty)
```

## การสร้างพืชใหม่

### ตัวอย่าง: สร้างพืชชนิดใหม่

```gdscript
# scripts/plants/MyPlant.gd
extends Plant
class_name MyPlant

func _init() -> void:
    plant_name = "MyPlant"
    role = "Energy"
    p_base = 6
    l_min = 1.0
    l_max = 2.5
    entropy_on_event = 0.4
    tags = ["custom", "test"]

# Override calculate_L เพื่อใส่กติกาเฉพาะ
func calculate_L(ctx: Dictionary) -> float:
    var L: float = l_min

    # ตัวอย่าง: +0.3 per orthogonal neighbor
    var ortho_neighbors = ctx.get("orthogonal_neighbors", [])
    L += ortho_neighbors.size() * 0.3

    return clamp(L, l_min, l_max)
```

### การใช้งานพืชใหม่ใน Main.gd:

```gdscript
# ใน _try_place_plant_at_mouse():
var plant = MyPlant.new()  # เปลี่ยนจาก Plant.new()
board.place_plant(plant, grid_pos)
```

## Data-Driven: โหลดพืชจาก CSV

### TODO: Plant Loader
สร้าง `PlantDatabase.gd` เพื่ออ่าน `Document/data/garden_plants_12.csv`:

```gdscript
class_name PlantDatabase

static func load_plant(plant_name: String) -> Plant:
    # อ่าน CSV และสร้าง Plant instance
    # ใช้ Dictionary mapping plant_name -> Plant class
    pass
```

## การ Debug

### 1. ดู Console Output
```
SeasonManager: DRAFT_STACK
Main: Season state -> DRAFT_STACK
SeasonManager: HAND_1_PLACING
Main: Plant placed at (2, 3)
Bloom resolved: +15 score, entropy: 3.0
```

### 2. ตรวจสอบ Entropy Bar
- **Green (Low)**: 0-40
- **Yellow (Medium)**: 40-70
- **Red (High)**: 70-100
- **Collapse**: ≥100

### 3. Remote Debug (F7)
- ดู Scene Tree แบบ live
- ตรวจสอบ properties ของ nodes

## Troubleshooting

### ❌ "stages.json not found"
→ ตรวจสอบว่ามีไฟล์ `resources/stages.json`

### ❌ Scripts ไม่โหลด
→ ตรวจสอบ path ใน Main.tscn:
```
res://scripts/Main.gd
res://scripts/Board.gd
res://scripts/HUD.gd
...
```

### ❌ UI ไม่แสดง
→ ตรวจสอบว่า HUD เป็น child ของ Main และมี anchors_preset = FULL_RECT

## Next Steps

### Sprint 1 Checklist:
- [x] Grid/Resolve system
- [x] Draft Stack basic
- [x] Entropy Levers (Overgrow/Stabilize)
- [x] Mini-Bloom & Full Bloom timing
- [x] Gate checking
- [ ] Plant Database (load from CSV)
- [ ] Draft UI (3->1 selection)
- [ ] Visual effects (bloom animation)
- [ ] Mutation system
- [ ] Trial/Contract integration

### ข้อมูลเพิ่มเติม:
- ดูสเปกใน `Document/2-Core-Loop-Spec.md`
- สูตรคะแนนใน `Document/3-Scoring-Entropy-Spec.md`
- ข้อมูลพืชใน `Document/data/garden_plants_12.csv`
- Stages ใน `Document/stages/stages_all_difficulties.json`
