extends Control
class_name HUD

## HUD: User Interface
## - Draft Stack (แสดง 3 กอง, เลือก 1)
## - Overgrow (+3 entropy, +0.3 L, +1 chain)
## - Stabilize (-20% entropy, 10 coins)
## - Entropy bar 3 ระดับ (Low/Medium/High)

# References (set by Main)
var season_manager: SeasonManager = null
var resolver: Resolver = null

# State
var coins: int = 50
var overgrow_active: bool = false
var stabilize_used_this_season: bool = false

# UI Elements (created in _ready)
var score_label: Label
var target_label: Label
var coins_label: Label
var entropy_bar: ProgressBar
var entropy_label: Label

var overgrow_button: Button
var stabilize_button: Button

var draft_container: HBoxContainer
var draft_buttons: Array = []

signal overgrow_pressed()
signal stabilize_pressed()
signal draft_stack_selected(stack_index: int)

func _ready() -> void:
	_setup_ui()

## สร้าง UI
func _setup_ui() -> void:
	# Main layout
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	# === Top Panel: Score, Target, Coins ===
	var top_panel = HBoxContainer.new()
	top_panel.add_theme_constant_override("separation", 20)
	vbox.add_child(top_panel)

	score_label = Label.new()
	score_label.text = "Score: 0"
	score_label.add_theme_font_size_override("font_size", 20)
	top_panel.add_child(score_label)

	target_label = Label.new()
	target_label.text = "Target: 80"
	target_label.add_theme_font_size_override("font_size", 20)
	top_panel.add_child(target_label)

	coins_label = Label.new()
	coins_label.text = "Coins: 50"
	coins_label.add_theme_font_size_override("font_size", 20)
	top_panel.add_child(coins_label)

	# === Entropy Bar ===
	var entropy_panel = VBoxContainer.new()
	entropy_panel.add_theme_constant_override("separation", 5)
	vbox.add_child(entropy_panel)

	entropy_label = Label.new()
	entropy_label.text = "Entropy: 0.0 / 100.0 (Low)"
	entropy_label.add_theme_font_size_override("font_size", 16)
	entropy_panel.add_child(entropy_label)

	entropy_bar = ProgressBar.new()
	entropy_bar.min_value = 0
	entropy_bar.max_value = 100
	entropy_bar.value = 0
	entropy_bar.show_percentage = false
	entropy_bar.custom_minimum_size = Vector2(400, 30)
	entropy_panel.add_child(entropy_bar)

	# === Entropy Levers ===
	var levers_panel = HBoxContainer.new()
	levers_panel.add_theme_constant_override("separation", 10)
	vbox.add_child(levers_panel)

	overgrow_button = Button.new()
	overgrow_button.text = "Overgrow (+3 Entropy, +0.3 L, +1 Chain)"
	overgrow_button.custom_minimum_size = Vector2(250, 40)
	overgrow_button.pressed.connect(_on_overgrow_pressed)
	levers_panel.add_child(overgrow_button)

	stabilize_button = Button.new()
	stabilize_button.text = "Stabilize (-20% Entropy, 10 Coins)"
	stabilize_button.custom_minimum_size = Vector2(250, 40)
	stabilize_button.pressed.connect(_on_stabilize_pressed)
	levers_panel.add_child(stabilize_button)

	# === Draft Stack Container ===
	draft_container = HBoxContainer.new()
	draft_container.add_theme_constant_override("separation", 10)
	draft_container.visible = false
	vbox.add_child(draft_container)

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

## อัพเดท UI
func update_display(score: int, target: int, entropy: float) -> void:
	score_label.text = "Score: %d" % score
	target_label.text = "Target: %d" % target
	coins_label.text = "Coins: %d" % coins

	# อัพเดท entropy bar
	entropy_bar.value = entropy
	var level = _get_entropy_level(entropy)
	entropy_label.text = "Entropy: %.1f / 100.0 (%s)" % [entropy, level]

	# สีของ entropy bar
	match level:
		"Low":
			entropy_bar.modulate = Color.GREEN
		"Medium":
			entropy_bar.modulate = Color.YELLOW
		"High":
			entropy_bar.modulate = Color.RED

## คำนวณระดับ entropy
func _get_entropy_level(entropy: float) -> String:
	if entropy < 40:
		return "Low"
	elif entropy < 70:
		return "Medium"
	else:
		return "High"

## แสดง draft stacks
func show_draft_stacks(stacks: Array) -> void:
	# ล้าง draft buttons เก่า
	for btn in draft_buttons:
		btn.queue_free()
	draft_buttons.clear()

	# สร้าง button สำหรับแต่ละ stack
	for i in range(stacks.size()):
		var stack = stacks[i]
		var btn = Button.new()
		btn.text = "Stack %d\n%s" % [i + 1, _format_stack(stack)]
		btn.custom_minimum_size = Vector2(150, 100)
		btn.pressed.connect(_on_draft_stack_selected.bind(i))
		draft_container.add_child(btn)
		draft_buttons.append(btn)

	draft_container.visible = true

func _format_stack(stack: Array) -> String:
	var names = []
	for plant_data in stack:
		names.append(plant_data.get("plant_name", "???"))
	return "\n".join(names)

## ซ่อน draft stacks
func hide_draft_stacks() -> void:
	draft_container.visible = false

## Overgrow pressed
func _on_overgrow_pressed() -> void:
	if overgrow_active:
		push_warning("Overgrow already active this turn")
		return

	overgrow_active = true
	overgrow_button.disabled = true
	emit_signal("overgrow_pressed")
	print("HUD: Overgrow activated!")

## Stabilize pressed
func _on_stabilize_pressed() -> void:
	if stabilize_used_this_season:
		push_warning("Stabilize already used this season")
		return

	if coins < 10:
		push_warning("Not enough coins for Stabilize")
		return

	# ตรวจสอบว่า references พร้อมหรือไม่
	if not resolver:
		push_warning("Resolver not ready yet")
		return

	if not season_manager:
		push_warning("SeasonManager not ready yet")
		return

	# ใช้ Stabilize
	var result = resolver.apply_stabilize(season_manager.current_entropy, coins)
	if result.success:
		coins = result.coins
		season_manager.current_entropy = result.entropy
		stabilize_used_this_season = true
		stabilize_button.disabled = true
		print("HUD: Stabilize used! Entropy reduced by %.1f" % result.reduction)

		# Emit signal เพื่อแจ้ง Main
		emit_signal("stabilize_pressed")

		# อัพเดท UI
		update_display(season_manager.season_score, season_manager.target_score, season_manager.current_entropy)

## Draft stack selected
func _on_draft_stack_selected(stack_index: int) -> void:
	emit_signal("draft_stack_selected", stack_index)
	hide_draft_stacks()
	print("HUD: Draft stack %d selected" % stack_index)

## รีเซ็ตสำหรับฤดูใหม่
func reset_for_new_season() -> void:
	overgrow_active = false
	stabilize_used_this_season = false
	overgrow_button.disabled = false
	stabilize_button.disabled = false

## รีเซ็ต Overgrow สำหรับมือใหม่
func reset_overgrow() -> void:
	overgrow_active = false
	overgrow_button.disabled = false
