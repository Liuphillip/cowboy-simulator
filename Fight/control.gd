extends Control

signal combo_completed

var combo_sequence := []
var current_index := 0
var can_accept_input := true
signal combo_failed

@onready var panel: Panel = $Panel
@onready var key_container: HBoxContainer = $Panel/HBoxContainer


func _ready():
	print("ComboUI Position:", position)
	print("Anchors:", anchor_left, anchor_top, anchor_right, anchor_bottom)
	hide()

func show_combo(sequence: Array):
	can_accept_input = true
	combo_sequence = sequence
	current_index = 0
	show()

	for child in key_container.get_children():
		key_container.remove_child(child)
		child.queue_free()

	for key in combo_sequence:
		var tex_rect = TextureRect.new()
		tex_rect.texture = get_arrow_texture(key)
		tex_rect.modulate = Color.GRAY
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.custom_minimum_size = Vector2(64, 64)  # Or however big you want
		key_container.add_child(tex_rect)

func get_arrow_texture(key: String) -> Texture:
	match key:
		"w":
			return preload("res://Fight/uparrow.png")
		"a":
			return preload("res://Fight/leftarrow.png")
		"s":
			return preload("res://Fight/downarrow.png")
		"d":
			return preload("res://Fight/rightarrow.png")
		_:
			return null  # fallback

func register_input(key: String):
	if not can_accept_input:
		return

	if current_index >= combo_sequence.size():
		return

	if key == combo_sequence[current_index]:
		var tex_rect = key_container.get_child(current_index)
		tex_rect.modulate = Color.GREEN
		current_index += 1

		if current_index == combo_sequence.size():
			emit_signal("combo_completed")
	else:
		can_accept_input = false  # ⛔ Block input while resetting
		await flash_panel_red_then_reset()
		await get_tree().create_timer(0.2).timeout
		show_combo(combo_sequence)  # Optional: retry same combo
		can_accept_input = true  # Re-enable input

		
func reset_combo():
	current_index = 0

	for i in range(key_container.get_child_count()):
		var key = combo_sequence[i]
		match key:
			"w":
				key_container.get_child(i).texture = preload("res://Fight/uparrow.png")
			"a":
				key_container.get_child(i).texture = preload("res://Fight/leftarrow.png")
			"s":
				key_container.get_child(i).texture = preload("res://Fight/downarrow.png")
			"d":
				key_container.get_child(i).texture = preload("res://Fight/rightarrow.png")
		
		key_container.get_child(i).modulate = Color.GRAY
	
func flash_panel_red_then_reset() -> void:
	# Step 1: Reset all blocks to gray and original arrows
	for i in range(key_container.get_child_count()):
		var key = combo_sequence[i]
		match key:
			"w":
				key_container.get_child(i).texture = preload("res://Fight/uparrow.png")
			"a":
				key_container.get_child(i).texture = preload("res://Fight/leftarrow.png")
			"s":
				key_container.get_child(i).texture = preload("res://Fight/downarrow.png")
			"d":
				key_container.get_child(i).texture = preload("res://Fight/rightarrow.png")

		key_container.get_child(i).modulate = Color.GRAY

	# Step 2: Flash the whole panel red
	panel.modulate = Color.RED
	await get_tree().create_timer(0.2).timeout

	# Step 3: Reset the panel color
	panel.modulate = Color.WHITE

	# Step 4: Restart the combo logic
	reset_combo()
