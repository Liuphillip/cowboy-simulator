extends CharacterBody3D


const SPEED = 5.0
const JUMP_VELOCITY = 4.5
# Stores x/y direction the player is trying to look in
var _look:= Vector2.ZERO
var last_target: Node = null
var raycast_enabled := true
var in_fight := false
var movement_cooldown_timer := 0.0


@export var min_camera_angle: float = -40
@export var max_camera_angle: float = 40
@export var mouse_sensitivity: float = 0.001
@export var RAY_LENGTH: float = 10

@onready var horizontal_pivot: Node3D = $HorizontalPivot
@onready var vertical_pivot: Node3D = $HorizontalPivot/VerticalPivot
@onready var player = self
@onready var ray_debug: MeshInstance3D = $RayDebug
@onready var camera: Camera3D = $HorizontalPivot/VerticalPivot/CameraShakePivot/SmoothCameraArm/Camera
@onready var camera_shake_pivot: Node3D = $HorizontalPivot/VerticalPivot/CameraShakePivot
@onready var combo_ui: Control = get_tree().root.get_node("World/CanvasLayer/ComboUI")





func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	combo_ui.connect("combo_completed", Callable(self, "_on_combo_completed"))
	combo_ui.connect("combo_failed", Callable(self, "_on_combo_failed"))
	randomize()

func _physics_process(delta: float) -> void:
	# Cooldown logic
	if movement_cooldown_timer > 0:
		movement_cooldown_timer -= delta
		if movement_cooldown_timer < 0:
			movement_cooldown_timer = 0
			
	ray_cast_func()
	camera_rotation()

	# Always apply gravity
	if not is_on_floor():
		velocity.y += get_gravity().y * delta
	else:
		velocity.y = 0

	# Movement logic
	if not in_fight and movement_cooldown_timer <= 0:
		var direction := get_movement_direction()

		if direction:
			velocity.x = direction.x * SPEED
			velocity.z = direction.z * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
			velocity.z = move_toward(velocity.z, 0, SPEED)
	else:
		# This lets movement restart after cooldown instead of freezing
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("Esc"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not in_fight:
		if event is InputEventMouseMotion:
			_look = -event.relative * mouse_sensitivity

	if event.is_action_pressed("fight") and last_target:
		print("Fight initiated with ", last_target.name)
		# Do your fight setup here
	if event.is_action_pressed("fight") and last_target and not combo_ui.visible:
		start_fight_with_combo()

	if event is InputEventKey and combo_ui.visible:
			if event.pressed and not event.echo:
				var key_name = OS.get_keycode_string(event.keycode).to_lower()

				# Only accept WASD
				if key_name in ["w", "a", "s", "d"]:
					combo_ui.register_input(key_name)



# Limits the up and down look angle of the camera
func camera_rotation() -> void:
	horizontal_pivot.rotate_y(_look.x)
	vertical_pivot.rotate_x(_look.y)
	
	vertical_pivot.rotation.x = clampf(
		vertical_pivot.rotation.x, 
		deg_to_rad(min_camera_angle), 
		deg_to_rad(max_camera_angle)
		)
	_look = Vector2.ZERO
	
# It returns a 3D direction vector based on the player's input (WASD) and rotates it 
# to match the direction the player or camera is facing, so movement always feels correct 
# relative to where you're looking.
func get_movement_direction() -> Vector3:
	var input_dir := Input.get_vector("Left", "Right", "Forward", "Backward")
	var input_vector := Vector3(input_dir.x, 0, input_dir.y).normalized()
	return horizontal_pivot.global_transform.basis * input_vector
	
	
func ray_cast_func() -> void:

	# Get ray origin and direction
	var origin = camera.global_transform.origin
	var direction = -vertical_pivot.global_transform.basis.z.normalized()
	var to = origin + direction * RAY_LENGTH

	# Draw the ray line in 3D view
	var local_origin = ray_debug.to_local(origin)
	var local_to = ray_debug.to_local(to)

	var mesh = ImmediateMesh.new()
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_add_vertex(local_origin)
	mesh.surface_add_vertex(local_to)
	mesh.surface_end()
	ray_debug.mesh = mesh

	# Set up raycast parameters
	var ray_params = PhysicsRayQueryParameters3D.create(origin, to)
	ray_params.exclude = [self]

	# Perform raycast
	var result = get_world_3d().direct_space_state.intersect_ray(ray_params)

	# Hide last target’s prompt (if any)
	if last_target and last_target.has_node("FightPrompt"):
		last_target.get_node("FightPrompt").visible = false
		last_target = null

	if result:
		var hit = result.collider
		if hit.name == "Enemy" or hit.is_in_group("enemies"):
			if hit.has_method("is_defeated") and hit.is_defeated:
				return

			if hit.has_node("FightPrompt") and not in_fight:  # ✅ only show prompt if not in fight
				hit.get_node("FightPrompt").visible = true
				last_target = hit


func start_fight_with_combo():
	if in_fight:
		return  # Prevent multiple fights

	in_fight = true  # Lock fight state
	raycast_enabled = false

	print("Fight initiated with", last_target.name)

	var keys = ['w', 'a', 's', 'd']
	var random_combo: Array = []

	var length := randi_range(4, 6)
	for i in range(length):
		random_combo.append(keys.pick_random())

	combo_ui.show_combo(random_combo)
	
	
func _on_combo_completed():
	print("Fight success!")
	combo_ui.hide()

	screen_shake(0.2, 1)  # Shake happens here

	if last_target and last_target.has_method("on_defeated"):
		last_target.on_defeated()

	last_target = null
	in_fight = false
	raycast_enabled = true
	velocity = Vector3.ZERO
	movement_cooldown_timer = 0.2
	
func screen_shake(intensity := 0.1, duration := 0.1):
	var tween := get_tree().create_tween()
	var original_position = camera_shake_pivot.position
	var shake_offset = Vector3(
		randf_range(-intensity, intensity),
		randf_range(-intensity, intensity),
		randf_range(-intensity, intensity)
	)

	camera_shake_pivot.position += shake_offset

	tween.tween_property(
		camera_shake_pivot, "position", original_position, duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
func _on_combo_failed():
	print("Combo failed!")
	combo_ui.hide()
	in_fight = false
	raycast_enabled = true
	velocity = Vector3.ZERO
	movement_cooldown_timer = 0.2
