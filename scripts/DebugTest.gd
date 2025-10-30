extends Node

## DebugTest: ทดสอบว่า Console messages ทำงานหรือไม่

func _ready() -> void:
	print("=".repeat(60))
	print("DEBUG TEST STARTED - If you see this, console works!")
	print("=".repeat(60))

	# Print ทุก 0.5 วินาที
	for i in range(5):
		print("Test message %d - Time: %.2f" % [i + 1, Time.get_ticks_msec() / 1000.0])
		await get_tree().create_timer(0.5).timeout

	print("=".repeat(60))
	print("DEBUG TEST COMPLETED")
	print("=".repeat(60))
