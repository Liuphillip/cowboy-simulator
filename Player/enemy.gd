extends CharacterBody3D  # or Node3D depending on your setup

var is_defeated := false

func on_defeated():
	if is_defeated:
		return
	is_defeated = true
	print("Enemy defeated!")

	# Optional: play death animation here

	# You can reset after a short delay:
	await get_tree().create_timer(2.0).timeout
	reset_enemy()

func reset_enemy():
	is_defeated = false
	print("Enemy ready again!")
	set_physics_process(true)
	if has_node("FightPrompt"):
		$FightPrompt.visible = false
	if has_node("CollisionShape3D"):
		$CollisionShape3D.disabled = false
	# Optionally reset animation here
