extends Node3D

var player: CharacterBody3D
var camera: Camera3D
var enemies: Array[CharacterBody3D] = []
var health := 100
var ammo := 30
var score := 0
var move_touch := -1
var look_touch := -1
var move_origin := Vector2.ZERO
var move_vector := Vector2.ZERO
var fire_button: Button
var hud_label: Label
var joystick: ColorRect

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_build_world()
	_build_player()
	_build_hud()
	for i in range(5):
		_spawn_enemy()

func _build_world() -> void:
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	environment.sky.sky_material = ProceduralSkyMaterial.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.60, 0.68)
	environment.ambient_light_energy = 0.7
	env.environment = environment
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	sun.light_energy = 1.4
	add_child(sun)
	_box("Ground", Vector3(0, -0.5, 0), Vector3(45, 1, 45), Color(0.19, 0.22, 0.20), true)
	for x in [-21.0, 21.0]:
		_box("Boundary", Vector3(x, 2, 0), Vector3(1, 4, 43), Color(0.25, 0.29, 0.28), true)
	for z in [-21.0, 21.0]:
		_box("Boundary", Vector3(0, 2, z), Vector3(43, 4, 1), Color(0.25, 0.29, 0.28), true)
	for p in [Vector3(-7,1,-5), Vector3(6,1,-8), Vector3(2,1,5), Vector3(-9,1,8), Vector3(10,1,10)]:
		_box("Concrete cover", p, Vector3(3,2,2), Color(0.32,0.34,0.33), true)
	for i in range(12):
		var x := randf_range(-17,17)
		var z := randf_range(-17,17)
		_box("Crate", Vector3(x,0.65,z), Vector3(1.3,1.3,1.3), Color(0.30,0.25,0.16), true)

func _box(n: String, pos: Vector3, size: Vector3, color: Color, solid: bool) -> void:
	var body := StaticBody3D.new() if solid else Node3D.new()
	body.name = n
	body.position = pos
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mesh.material_override = mat
	body.add_child(mesh)
	if solid:
		var collision := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		collision.shape = box
		body.add_child(collision)
	add_child(body)

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.position = Vector3(0, 1, 12)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.8
	collision.shape = capsule
	player.add_child(collision)
	camera = Camera3D.new()
	camera.position.y = 0.55
	camera.current = true
	player.add_child(camera)
	add_child(player)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	layer.add_child(panel)
	hud_label = Label.new()
	hud_label.add_theme_font_size_override("font_size", 22)
	panel.add_child(hud_label)
	var hint := Label.new()
	hint.text = "LEFT: MOVE     RIGHT: LOOK"
	hint.position = Vector2(16, 62)
	layer.add_child(hint)
	fire_button = Button.new()
	fire_button.text = "FIRE"
	fire_button.custom_minimum_size = Vector2(112, 76)
	fire_button.position = Vector2(0, 0)
	fire_button.anchor_left = 1
	fire_button.anchor_top = 1
	fire_button.anchor_right = 1
	fire_button.anchor_bottom = 1
	fire_button.offset_left = -142
	fire_button.offset_top = -112
	fire_button.offset_right = -24
	fire_button.offset_bottom = -28
	fire_button.pressed.connect(_shoot)
	layer.add_child(fire_button)
	var reload := Button.new()
	reload.text = "RELOAD"
	reload.position = Vector2(0,0)
	reload.anchor_left = 1
	reload.anchor_top = 1
	reload.anchor_right = 1
	reload.anchor_bottom = 1
	reload.offset_left = -142
	reload.offset_top = -172
	reload.offset_right = -24
	reload.offset_bottom = -122
	reload.pressed.connect(func(): ammo = 30; _update_hud())
	layer.add_child(reload)
	_update_hud()

func _update_hud() -> void:
	if is_instance_valid(hud_label):
		hud_label.text = "RED ZONE 3D\nHP: %d   AMMO: %d\nELIMINATIONS: %d" % [health, ammo, score]

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look(event.relative)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventScreenTouch:
		if event.pressed:
			if event.position.x < get_viewport().get_visible_rect().size.x * 0.45 and move_touch == -1:
				move_touch = event.index
				move_origin = event.position
			elif look_touch == -1:
				look_touch = event.index
		else:
			if event.index == move_touch:
				move_touch = -1
				move_vector = Vector2.ZERO
			if event.index == look_touch:
				look_touch = -1
	elif event is InputEventScreenDrag:
		if event.index == move_touch:
			move_vector = (event.position - move_origin).limit_length(85) / 85.0
		elif event.index == look_touch:
			_look(event.relative)

func _look(delta: Vector2) -> void:
	player.rotate_y(-delta.x * 0.003)
	camera.rotate_x(-delta.y * 0.003)
	camera.rotation.x = clamp(camera.rotation.x, -1.35, 1.35)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	var input_vec := move_vector
	if Input.is_key_pressed(KEY_W): input_vec.y -= 1
	if Input.is_key_pressed(KEY_S): input_vec.y += 1
	if Input.is_key_pressed(KEY_A): input_vec.x -= 1
	if Input.is_key_pressed(KEY_D): input_vec.x += 1
	var direction := (player.transform.basis * Vector3(input_vec.x, 0, input_vec.y)).normalized()
	player.velocity.x = direction.x * 6.0
	player.velocity.z = direction.z * 6.0
	if not player.is_on_floor():
		player.velocity.y -= 20.0 * delta
	else:
		player.velocity.y = 0
	player.move_and_slide()
	for enemy in enemies:
		if is_instance_valid(enemy):
			var to_player := player.global_position - enemy.global_position
			to_player.y = 0
			if to_player.length() > 1.3:
				enemy.velocity = to_player.normalized() * 1.8
				enemy.look_at(Vector3(player.global_position.x, enemy.global_position.y, player.global_position.z))
			else:
				enemy.velocity = Vector3.ZERO
				if randf() < delta * 0.25:
					health = max(0, health - 5)
					_update_hud()
			enemy.move_and_slide()

func _spawn_enemy() -> void:
	var enemy := CharacterBody3D.new()
	enemy.position = Vector3(randf_range(-15,15), 1, randf_range(-15,5))
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.8
	collision.shape = capsule
	enemy.add_child(collision)
	var mesh := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.42
	body_mesh.height = 1.8
	mesh.mesh = body_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.38,0.12,0.10)
	mesh.material_override = mat
	enemy.add_child(mesh)
	add_child(enemy)
	enemies.append(enemy)

func _shoot() -> void:
	if ammo <= 0:
		_update_hud()
		return
	ammo -= 1
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position - camera.global_transform.basis.z * 80)
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit and hit.collider in enemies:
		var target: CharacterBody3D = hit.collider
		enemies.erase(target)
		target.queue_free()
		score += 1
		_spawn_enemy()
	_update_hud()
