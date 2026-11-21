extends Node3D

var player: CharacterBody3D
var camera: Camera3D
var enemies: Array[CharacterBody3D] = []
var enemy_attack_cooldowns: Dictionary = {}
var material_cache: Dictionary = {}
var health := 100
var ammo := 30
var score := 0
var move_touch := -1
var look_touch := -1
var move_origin := Vector2.ZERO
var move_vector := Vector2.ZERO
var fire_button: Button
var hud_label: Label
var weapon_root: Node3D
var muzzle_flash: MeshInstance3D
var flash_light: OmniLight3D
var fire_audio: AudioStreamPlayer
var reload_audio: AudioStreamPlayer

const RIFLE_DARK := Color(0.075, 0.085, 0.075)
const RIFLE_METAL := Color(0.19, 0.21, 0.19)
const OLIVE := Color(0.22, 0.28, 0.17)
const OLIVE_LIGHT := Color(0.34, 0.39, 0.23)
const TAN := Color(0.42, 0.37, 0.25)

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	randomize()
	_build_world()
	_build_player()
	_build_hud()
	_build_audio()
	for i in range(6):
		_spawn_enemy()

func _material(color: Color, roughness := 0.88, metallic := 0.0) -> StandardMaterial3D:
	var key := "%s_%.2f_%.2f" % [color.to_html(), roughness, metallic]
	if material_cache.has(key):
		return material_cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	material_cache[key] = mat
	return mat

func _part(parent: Node3D, part_name: String, mesh_data: Mesh, pos: Vector3, color: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = part_name
	instance.mesh = mesh_data
	instance.position = pos
	instance.rotation_degrees = rot
	instance.material_override = _material(color)
	parent.add_child(instance)
	return instance

func _cube(parent: Node3D, part_name: String, pos: Vector3, size: Vector3, color: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return _part(parent, part_name, shape, pos, color, rot)

func _cylinder(parent: Node3D, part_name: String, pos: Vector3, radius: float, height: float, color: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 12
	return _part(parent, part_name, shape, pos, color, rot)

func _build_world() -> void:
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	environment.sky.sky_material = ProceduralSkyMaterial.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.48, 0.53, 0.48)
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = environment
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_energy = 1.45
	sun.shadow_enabled = true
	add_child(sun)

	_box("Dusty battlefield", Vector3(0, -0.5, 0), Vector3(48, 1, 48), Color(0.25, 0.25, 0.19), true)
	for x in [-23.0, 23.0]:
		_box("Perimeter wall", Vector3(x, 2.2, 0), Vector3(1.2, 4.4, 47), Color(0.28, 0.30, 0.26), true)
	for z in [-23.0, 23.0]:
		_box("Perimeter wall", Vector3(0, 2.2, z), Vector3(47, 4.4, 1.2), Color(0.28, 0.30, 0.26), true)

	# Large concrete barriers and sandbag positions
	for p in [Vector3(-8,1,-6), Vector3(7,1,-9), Vector3(3,1,5), Vector3(-10,1,9), Vector3(12,1,11)]:
		_box("Concrete barricade", p, Vector3(3.8,2,1.4), Color(0.38,0.39,0.34), true)
	for p in [Vector3(-3,0.55,-13), Vector3(13,0.55,-2), Vector3(-14,0.55,1), Vector3(5,0.55,15)]:
		_box("Sandbag stack", p, Vector3(3.2,1.1,1.0), Color(0.43,0.39,0.27), true)

	# Crates, drums, road markings and scattered debris
	for i in range(15):
		var x := randf_range(-19, 19)
		var z := randf_range(-19, 19)
		if Vector2(x, z).length() > 5.0:
			_box("Military supply crate", Vector3(x,0.65,z), Vector3(1.35,1.3,1.35), Color(0.25,0.29,0.18), true)
	for p in [Vector3(-17,0.8,-8), Vector3(17,0.8,4), Vector3(-5,0.8,18)]:
		_cylinder_world("Fuel drum", p, 0.48, 1.6, Color(0.25,0.29,0.27))
	for i in range(9):
		var mark := BoxMesh.new()
		mark.size = Vector3(0.12, 0.025, 1.4)
		var decal := MeshInstance3D.new()
		decal.mesh = mark
		decal.position = Vector3(-1.8 + i * 0.45, 0.015, -2.0)
		decal.material_override = _material(Color(0.52,0.48,0.34))
		add_child(decal)

func _box(n: String, pos: Vector3, size: Vector3, color: Color, solid: bool) -> void:
	var body: Node3D = StaticBody3D.new() if solid else Node3D.new()
	body.name = n
	body.position = pos
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material(color)
	body.add_child(instance)
	if solid:
		var collision := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		collision.shape = box
		body.add_child(collision)
	add_child(body)

func _cylinder_world(n: String, pos: Vector3, radius: float, height: float, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = n
	body.position = pos
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material(color)
	body.add_child(instance)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.position = Vector3(0, 1, 15)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.8
	collision.shape = capsule
	player.add_child(collision)

	camera = Camera3D.new()
	camera.position.y = 0.55
	camera.current = true
	camera.fov = 78.0
	player.add_child(camera)
	add_child(player)
	_build_rifle()

func _build_rifle() -> void:
	weapon_root = Node3D.new()
	weapon_root.name = "FIRST_PERSON_ASSAULT_RIFLE"
	weapon_root.position = Vector3(0.34, -0.31, -0.62)
	camera.add_child(weapon_root)

	# Receiver, stock, handguard, barrel, magazine and top rail
	_cube(weapon_root, "Rifle receiver", Vector3(0,0,0), Vector3(0.16,0.17,0.48), RIFLE_DARK)
	_cube(weapon_root, "Rifle handguard", Vector3(0,0.025,-0.34), Vector3(0.14,0.14,0.34), OLIVE)
	_cube(weapon_root, "Rifle stock", Vector3(0,-0.015,0.34), Vector3(0.13,0.14,0.32), RIFLE_DARK)
	_cylinder(weapon_root, "Long rifle barrel", Vector3(0,0.035,-0.62), 0.027, 0.48, RIFLE_METAL, Vector3(90,0,0))
	_cube(weapon_root, "Magazine", Vector3(0,-0.17,-0.02), Vector3(0.105,0.25,0.16), RIFLE_DARK, Vector3(-8,0,0))
	_cube(weapon_root, "Top rail", Vector3(0,0.105,-0.12), Vector3(0.08,0.035,0.44), RIFLE_METAL)
	_cube(weapon_root, "Optic sight", Vector3(0,0.17,-0.12), Vector3(0.13,0.10,0.16), RIFLE_DARK)
	_cube(weapon_root, "Front grip", Vector3(0,-0.12,-0.31), Vector3(0.075,0.20,0.09), RIFLE_DARK, Vector3(-10,0,0))
	_cube(weapon_root, "Trigger grip", Vector3(0,-0.15,0.13), Vector3(0.075,0.20,0.10), RIFLE_DARK, Vector3(-12,0,0))
	# First-person sleeve and glove suggest the soldier's support arm
	_cube(weapon_root, "Sleeve", Vector3(-0.19,-0.22,0.03), Vector3(0.17,0.19,0.32), OLIVE)
	_cube(weapon_root, "Glove", Vector3(-0.12,-0.13,-0.18), Vector3(0.14,0.10,0.16), Color(0.18,0.17,0.13))

	var flash_mesh := SphereMesh.new()
	flash_mesh.radius = 0.12
	flash_mesh.height = 0.24
	muzzle_flash = _part(weapon_root, "Muzzle flash", flash_mesh, Vector3(0,0.04,-0.88), Color(1.0,0.68,0.16))
	muzzle_flash.visible = false
	flash_light = OmniLight3D.new()
	flash_light.position = Vector3(0,0.04,-0.9)
	flash_light.light_color = Color(1.0,0.55,0.18)
	flash_light.omni_range = 4.0
	flash_light.light_energy = 2.5
	flash_light.visible = false
	weapon_root.add_child(flash_light)
	var flash_timer := Timer.new()
	flash_timer.one_shot = true
	flash_timer.wait_time = 0.075
	flash_timer.timeout.connect(func():
		if is_instance_valid(muzzle_flash):
			muzzle_flash.visible = false
			flash_light.visible = false
	)
	weapon_root.add_child(flash_timer)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	layer.add_child(panel)
	hud_label = Label.new()
	hud_label.add_theme_font_size_override("font_size", 22)
	hud_label.add_theme_color_override("font_color", Color(0.88,0.93,0.82))
	panel.add_child(hud_label)

	var hint := Label.new()
	hint.text = "LEFT: MOVE     RIGHT: AIM"
	hint.position = Vector2(16, 82)
	hint.add_theme_color_override("font_color", Color(0.88,0.9,0.8))
	layer.add_child(hint)

	var crosshair := Label.new()
	crosshair.text = "+"
	crosshair.add_theme_font_size_override("font_size", 34)
	crosshair.add_theme_color_override("font_color", Color(1,1,1,0.9))
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.position = Vector2(-10,-22)
	layer.add_child(crosshair)

	fire_button = Button.new()
	fire_button.text = "FIRE"
	fire_button.add_theme_font_size_override("font_size", 20)
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
	reload.pressed.connect(_reload)
	layer.add_child(reload)
	_update_hud()

func _build_audio() -> void:
	fire_audio = AudioStreamPlayer.new()
	fire_audio.stream = _make_sound(95.0, 0.16, true)
	fire_audio.volume_db = -4.0
	add_child(fire_audio)
	reload_audio = AudioStreamPlayer.new()
	reload_audio.stream = _make_sound(420.0, 0.22, false)
	reload_audio.volume_db = -9.0
	add_child(reload_audio)

func _make_sound(frequency: float, duration: float, noise: bool) -> AudioStreamWAV:
	var sample_rate := 22050
	var count := int(sample_rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i in range(count):
		var t := float(i) / float(sample_rate)
		var envelope := pow(1.0 - float(i) / float(count), 3.0)
		var sample := sin(TAU * frequency * t) * 0.45
		if noise:
			sample = (randf() * 2.0 - 1.0) * 0.85 + sample * 0.25
		bytes.encode_s16(i * 2, int(clamp(sample * envelope, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = bytes
	return stream

func _update_hud() -> void:
	if is_instance_valid(hud_label):
		hud_label.text = "RED ZONE 3D  |  HP: %d\nAMMO: %d / 30     ELIMINATIONS: %d" % [health, ammo, score]

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
	if not is_instance_valid(player):
		return
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
			if to_player.length() > 1.5:
				enemy.velocity = to_player.normalized() * 1.65
				enemy.look_at(Vector3(player.global_position.x, enemy.global_position.y, player.global_position.z))
			else:
				enemy.velocity = Vector3.ZERO
				var enemy_id := enemy.get_instance_id()
				var cooldown: float = maxf(0.0, float(enemy_attack_cooldowns.get(enemy_id, 0.0)) - delta)
				if cooldown <= 0.0 and health > 0:
					health = max(0, health - 5)
					cooldown = 1.5
					_update_hud()
				enemy_attack_cooldowns[enemy_id] = cooldown
			enemy.move_and_slide()

func _spawn_enemy() -> void:
	var enemy := CharacterBody3D.new()
	enemy.name = "Enemy_Soldier"
	enemy.add_to_group("enemies")
	enemy.position = Vector3(randf_range(-17,17), 1, randf_range(-17,5))
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.36
	capsule.height = 1.85
	collision.shape = capsule
	enemy.add_child(collision)

	var soldier := Node3D.new()
	soldier.name = "Soldier_Model"
	enemy.add_child(soldier)
	# Smooth capsule-based body parts replace the old block-shaped mannequin.
	var torso := CapsuleMesh.new()
	torso.radius = 0.31
	torso.height = 0.82
	_part(soldier, "Combat uniform", torso, Vector3(0,1.18,0), OLIVE)
	var vest := CapsuleMesh.new()
	vest.radius = 0.265
	vest.height = 0.62
	_part(soldier, "Armoured vest", vest, Vector3(0,1.2,-0.035), Color(0.30,0.32,0.24))
	for x in [-0.16, 0.0, 0.16]:
		_cube(soldier, "Vest pouch", Vector3(x,1.12,-0.27), Vector3(0.105,0.16,0.07), TAN)
	# Rounded upper and lower legs with knee pads and boots.
	for side in [-1.0, 1.0]:
		var leg := CapsuleMesh.new()
		leg.radius = 0.115
		leg.height = 0.66
		_part(soldier, "Combat trousers", leg, Vector3(side*0.17,0.48,0), OLIVE)
		var knee := SphereMesh.new()
		knee.radius = 0.13
		knee.height = 0.13
		_part(soldier, "Knee pad", knee, Vector3(side*0.17,0.43,-0.07), RIFLE_DARK)
		_cube(soldier, "Combat boot", Vector3(side*0.17,0.11,-0.045), Vector3(0.22,0.20,0.34), RIFLE_DARK)
	# Bent-looking arms, shoulder pads and gloves.
	for side in [-1.0, 1.0]:
		var upper_arm := CapsuleMesh.new()
		upper_arm.radius = 0.105
		upper_arm.height = 0.48
		_part(soldier, "Sleeved arm", upper_arm, Vector3(side*0.39,1.13,-0.015), OLIVE_LIGHT, Vector3(0,0,side*12))
		var glove := SphereMesh.new()
		glove.radius = 0.115
		glove.height = 0.16
		_part(soldier, "Glove", glove, Vector3(side*0.40,0.82,-0.04), RIFLE_DARK)
	# Head, neck and rounded combat helmet.
	var neck := CylinderMesh.new()
	neck.top_radius = 0.09
	neck.bottom_radius = 0.10
	neck.height = 0.16
	_part(soldier, "Neck", neck, Vector3(0,1.62,0), Color(0.34,0.27,0.20))
	var head := SphereMesh.new()
	head.radius = 0.17
	head.height = 0.34
	_part(soldier, "Head", head, Vector3(0,1.76,0), Color(0.43,0.33,0.25))
	var helmet := SphereMesh.new()
	helmet.radius = 0.205
	helmet.height = 0.22
	_part(soldier, "Combat helmet", helmet, Vector3(0,1.91,0.01), Color(0.16,0.21,0.14))
	var visor := SphereMesh.new()
	visor.radius = 0.11
	visor.height = 0.075
	_part(soldier, "Dark eye protection", visor, Vector3(0,1.78,-0.13), RIFLE_DARK)
	add_child(enemy)
	enemies.append(enemy)
	enemy_attack_cooldowns[enemy.get_instance_id()] = 0.0

func _shoot() -> void:
	if ammo <= 0:
		_update_hud()
		return
	ammo -= 1
	if is_instance_valid(fire_audio):
		fire_audio.play()
	if is_instance_valid(muzzle_flash):
		muzzle_flash.visible = true
		flash_light.visible = true
		var flash_timer: Timer = weapon_root.get_node("Timer")
		flash_timer.start()
	if is_instance_valid(weapon_root):
		var tween := create_tween()
		tween.tween_property(weapon_root, "position:z", -0.53, 0.045)
		tween.tween_property(weapon_root, "position:z", -0.62, 0.09)

	# Raycast from the exact centre of the camera; resolve enemy groups robustly.
	var origin := camera.global_position
	var direction := -camera.global_transform.basis.z
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 100.0)
	query.exclude = [player.get_rid()]
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var collider := hit.get("collider") as Node
		var target: CharacterBody3D = null
		if collider is CharacterBody3D and collider.is_in_group("enemies"):
			target = collider as CharacterBody3D
		elif collider != null:
			var ancestor := collider.get_parent()
			while ancestor != null and not ancestor is CharacterBody3D:
				ancestor = ancestor.get_parent()
			if ancestor is CharacterBody3D and ancestor.is_in_group("enemies"):
				target = ancestor as CharacterBody3D
		if is_instance_valid(target):
			enemies.erase(target)
			enemy_attack_cooldowns.erase(target.get_instance_id())
			target.queue_free()
			score += 1
			_spawn_enemy()
	_update_hud()

func _reload() -> void:
	ammo = 30
	if is_instance_valid(reload_audio):
		reload_audio.play()
	_update_hud()
