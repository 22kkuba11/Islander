
extends Node2D

# ==========================================
# ISLANDER V0.5
# Godot 3.6
# ==========================================

const WORLD_WIDTH = 2400
const WORLD_HEIGHT = 1800

const PLAYER_SPEED = 240.0
const IRON_TO_WIN = 10
const PICKAXE_WOOD_COST = 5
const PICKAXE_STONE_COST = 5

const RESOLUTIONS = [
	"DEFAULT",
	"1280x720",
	"1600x900",
	"1920x1080"
]

var player_position = Vector2(1200, 900)

var wood = 0
var stone = 0
var iron = 0

var has_stone_pickaxe = false

var trees = []
var stones = []
var iron_ores = []

var game_state = "splash"
var splash_timer = 0.0
var victory_rotation = 0.0

var fps_enabled = false
var music_enabled = true

# MIDI is OPTIONAL.
# The base game does not require a MIDI plugin. (BROKEN)
var music_source = "music.mid"

var resolution_index = 0
var settings_return_state = "pause"

var ui_font
var music_player

var screen_size = Vector2(1280, 720)


func _ready():
	randomize()

	var font_holder = Label.new()
	add_child(font_holder)
	ui_font = font_holder.get_font("font")

	music_player = AudioStreamPlayer.new()
	add_child(music_player)

	_generate_world()
	_apply_resolution()
	_update_music()

	update()


# ==========================================
# WORLD GENERATION
# ==========================================

func _generate_world():
	trees.clear()
	stones.clear()
	iron_ores.clear()

	for i in range(35):
		trees.append(_random_position())

	for i in range(25):
		stones.append(_random_position())

	for i in range(18):
		iron_ores.append(_random_position())


func _random_position():
	return Vector2(
		rand_range(100, WORLD_WIDTH - 100),
		rand_range(100, WORLD_HEIGHT - 100)
	)


# ==========================================
# MAIN LOOP
# ==========================================

func _process(delta):
	screen_size = get_viewport_rect().size

	if game_state == "splash":
		splash_timer += delta

		if splash_timer >= 3.0:
			game_state = "game"
			update()

	elif game_state == "game":
		if _move_player(delta):
			update()

		if fps_enabled:
			update()

	elif game_state == "victory":
		victory_rotation += delta * 1.2
		update()


# ==========================================
# PLAYER
# ==========================================

func _move_player(delta):
	var direction = Vector2.ZERO

	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		direction.y -= 1

	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		direction.y += 1

	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction.x -= 1

	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction.x += 1

	if direction == Vector2.ZERO:
		return false

	direction = direction.normalized()

	var old_position = player_position

	player_position += direction * PLAYER_SPEED * delta

	player_position.x = clamp(player_position.x, 30, WORLD_WIDTH - 30)
	player_position.y = clamp(player_position.y, 30, WORLD_HEIGHT - 30)

	return old_position != player_position


# ==========================================
# RESOURCE COLLECTION
# ==========================================

func _collect_resource():
	var nearest_type = ""
	var nearest_index = -1
	var nearest_distance = 65.0

	for i in range(trees.size()):
		var distance = player_position.distance_to(trees[i])

		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = i
			nearest_type = "wood"

	for i in range(stones.size()):
		var distance = player_position.distance_to(stones[i])

		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = i
			nearest_type = "stone"

	for i in range(iron_ores.size()):
		var distance = player_position.distance_to(iron_ores[i])

		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = i
			nearest_type = "iron"

	if nearest_index == -1:
		return

	match nearest_type:
		"wood":
			wood += 1
			trees.remove(nearest_index)

		"stone":
			stone += 1
			stones.remove(nearest_index)

		"iron":
			if not has_stone_pickaxe:
				print("ISLANDER: You need a stone pickaxe to mine iron. Press C to craft one.")
				return

			iron += 1
			iron_ores.remove(nearest_index)

			if iron >= IRON_TO_WIN:
				game_state = "victory"

	update()


# ==========================================
# CRAFTING
# ==========================================

func _craft_stone_pickaxe():
	if has_stone_pickaxe:
		print("ISLANDER: You already have a stone pickaxe.")
		return

	if wood < PICKAXE_WOOD_COST or stone < PICKAXE_STONE_COST:
		print("ISLANDER: Stone pickaxe requires 5 wood and 5 stone.")
		return

	wood -= PICKAXE_WOOD_COST
	stone -= PICKAXE_STONE_COST

	has_stone_pickaxe = true

	print("ISLANDER: Stone pickaxe crafted!")
	update()


# ==========================================
# INPUT
# ==========================================

func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:

		if event.scancode == KEY_ESCAPE:
			if game_state == "game":
				game_state = "pause"

			elif game_state == "pause":
				game_state = "game"

			elif game_state == "settings":
				game_state = settings_return_state

			elif game_state == "splash":
				game_state = "game"

			update()
			get_tree().set_input_as_handled()
			return

		if event.scancode == KEY_E and game_state == "game":
			_collect_resource()
			get_tree().set_input_as_handled()

		if event.scancode == KEY_C and game_state == "game":
			_craft_stone_pickaxe()
			get_tree().set_input_as_handled()

	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT and event.pressed:
			_handle_click(event.position)


# ==========================================
# MENUS
# ==========================================

func _handle_click(pos):
	if game_state == "pause":

		if _button_hit(pos, 0):
			game_state = "game"

		elif _button_hit(pos, 1):
			settings_return_state = "pause"
			game_state = "settings"

		elif _button_hit(pos, 2):
			get_tree().quit()

	elif game_state == "settings":

		if _button_hit(pos, 0):
			music_enabled = not music_enabled
			_update_music()

		elif _button_hit(pos, 1):
			if music_source == "music.mid":
				music_source = "music.mp3"
			else:
				music_source = "music.mid"

			_update_music()

		elif _button_hit(pos, 2):
			resolution_index += 1

			if resolution_index >= RESOLUTIONS.size():
				resolution_index = 0

			_apply_resolution()

		elif _button_hit(pos, 3):
			fps_enabled = not fps_enabled

		elif _button_hit(pos, 4):
			game_state = settings_return_state

		update()


func _button_hit(pos, index):
	var button_width = 340.0
	var button_height = 48.0
	var y = 0.0

	if game_state == "pause":
		y = screen_size.y * 0.5 - 35 + index * 65

	elif game_state == "settings":
		y = screen_size.y * 0.5 - 115 + index * 65

	var rect = Rect2(
		screen_size.x * 0.5 - button_width * 0.5,
		y,
		button_width,
		button_height
	)

	return rect.has_point(pos)


# ==========================================
# SETTINGS
# ==========================================

func _apply_resolution():
	var resolution = RESOLUTIONS[resolution_index]

	if resolution == "DEFAULT":
		OS.set_window_fullscreen(true)
		return

	OS.set_window_fullscreen(false)

	var parts = resolution.split("x")

	var width = int(parts[0])
	var height = int(parts[1])

	OS.set_window_size(Vector2(width, height))
	OS.center_window()


func _update_music():
	if music_player.playing:
		music_player.stop()

	if not music_enabled:
		return

	var path = "res://" + music_source

	if not ResourceLoader.exists(path):
		print("ISLANDER: Music file not found: " + music_source)
		return

	var stream = load(path)

	if stream == null:
		print("ISLANDER: Cannot load music: " + music_source)
		return

	music_player.stream = stream
	music_player.play()


# ==========================================
# DRAWING
# ==========================================

func _draw():
	screen_size = get_viewport_rect().size

	if game_state == "splash":
		_draw_splash()
		return

	if game_state == "victory":
		_draw_victory()
		return

	_draw_world()

	if game_state == "game":
		_draw_hud()

	elif game_state == "pause":
		_draw_pause()

	elif game_state == "settings":
		_draw_settings()


# ==========================================
# CAMERA AND WORLD
# ==========================================

func _get_camera_position():
	var half_screen = screen_size * 0.5

	var camera = player_position

	if half_screen.x * 2 >= WORLD_WIDTH:
		camera.x = WORLD_WIDTH * 0.5
	else:
		camera.x = clamp(
			camera.x,
			half_screen.x,
			WORLD_WIDTH - half_screen.x
		)

	if half_screen.y * 2 >= WORLD_HEIGHT:
		camera.y = WORLD_HEIGHT * 0.5
	else:
		camera.y = clamp(
			camera.y,
			half_screen.y,
			WORLD_HEIGHT - half_screen.y
		)

	return camera


func _draw_world():
	var camera = _get_camera_position()
	var half_screen = screen_size * 0.5
	var offset = half_screen - camera

	var visible_rect = Rect2(
		camera - half_screen - Vector2(50, 50),
		screen_size + Vector2(100, 100)
	)

	draw_set_transform(offset, 0, Vector2.ONE)

	# Ocean
	draw_rect(
		Rect2(-100, -100, WORLD_WIDTH + 200, WORLD_HEIGHT + 200),
		Color(0.10, 0.35, 0.58)
	)

	# Island
	draw_rect(
		Rect2(0, 0, WORLD_WIDTH, WORLD_HEIGHT),
		Color(0.20, 0.48, 0.27)
	)

	# Visible resources only
	for tree in trees:
		if visible_rect.has_point(tree):
			_draw_tree(tree)

	for rock in stones:
		if visible_rect.has_point(rock):
			_draw_stone(rock)

	for ore in iron_ores:
		if visible_rect.has_point(ore):
			_draw_iron(ore)

	_draw_player_world()

	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


func _draw_tree(pos):
	draw_rect(
		Rect2(pos.x - 5, pos.y, 10, 25),
		Color(0.38, 0.20, 0.09)
	)

	draw_circle(
		pos + Vector2(0, -8),
		19,
		Color(0.08, 0.35, 0.13)
	)

	draw_circle(
		pos + Vector2(-9, -15),
		11,
		Color(0.12, 0.43, 0.17)
	)


func _draw_stone(pos):
	draw_colored_polygon(
		PoolVector2Array([
			pos + Vector2(-14, 8),
			pos + Vector2(-10, -9),
			pos + Vector2(5, -15),
			pos + Vector2(15, -3),
			pos + Vector2(11, 10)
		]),
		Color(0.48, 0.49, 0.49)
	)


func _draw_iron(pos):
	draw_colored_polygon(
		PoolVector2Array([
			pos + Vector2(-15, 9),
			pos + Vector2(-11, -9),
			pos + Vector2(3, -15),
			pos + Vector2(15, -4),
			pos + Vector2(12, 9)
		]),
		Color(0.38, 0.40, 0.43)
	)

	draw_circle(
		pos + Vector2(-3, -3),
		4,
		Color(0.83, 0.52, 0.37)
	)

	draw_circle(
		pos + Vector2(6, 4),
		3,
		Color(0.83, 0.52, 0.37)
	)


func _draw_player_world():
	draw_circle(
		player_position + Vector2(0, 7),
		15,
		Color(0.08, 0.12, 0.10)
	)

	draw_circle(
		player_position,
		15,
		Color(0.88, 0.76, 0.56)
	)

	draw_circle(
		player_position + Vector2(0, -4),
		7,
		Color(0.25, 0.38, 0.65)
	)


# ==========================================
# HUD
# ==========================================

func _draw_hud():
	_draw_text("Wood: " + str(wood), Vector2(20, 35))
	_draw_text("Stone: " + str(stone), Vector2(20, 65))
	_draw_text("Iron: " + str(iron) + " / 10", Vector2(20, 95))

	_draw_text(
		"Stone pickaxe: " + ("YES" if has_stone_pickaxe else "NO"),
		Vector2(20, 125)
	)

	if not has_stone_pickaxe:
		_draw_text(
			"C - CRAFT PICKAXE (5 WOOD + 5 STONE)",
			Vector2(20, 155)
		)
	else:
		_draw_text(
			"Pickaxe ready - you can mine iron",
			Vector2(20, 155)
		)

	_draw_text(
		"WASD / ARROWS - MOVE     E - COLLECT     C - CRAFT     ESC - MENU",
		Vector2(20, screen_size.y - 25)
	)

	if fps_enabled:
		_draw_text(
			"FPS: " + str(Engine.get_frames_per_second()),
			Vector2(screen_size.x - 125, 30)
		)


# ==========================================
# SPLASH SCREEN AND LOGO
# ==========================================

func _draw_splash():
	draw_rect(
		Rect2(Vector2.ZERO, screen_size),
		Color(0.025, 0.04, 0.05)
	)

	_draw_logo(
		Vector2(screen_size.x * 0.5, screen_size.y * 0.43),
		1.0
	)

	_draw_text(
		"LOADING...",
		Vector2(screen_size.x * 0.5 - 45, screen_size.y * 0.65)
	)


func _draw_logo(center, scale):
	var letters = [
		[[0,0,30,0],[15,0,15,50],[0,50,30,50]],
		[[0,0,30,0],[0,0,0,25],[0,25,30,25],[30,25,30,50],[0,50,30,50]],
		[[0,0,0,50],[0,50,30,50]],
		[[0,50,0,10],[0,10,15,0],[15,0,30,10],[30,10,30,50],[0,25,30,25]],
		[[0,50,0,0],[0,0,30,50],[30,50,30,0]],
		[[0,0,0,50],[0,0,20,0],[20,0,30,12],[30,12,30,38],[30,38,20,50],[20,50,0,50]],
		[[30,0,0,0],[0,0,0,50],[0,25,25,25],[0,50,30,50]],
		[[0,50,0,0],[0,0,22,0],[22,0,30,10],[30,10,22,25],[22,25,0,25],[15,25,30,50]]
	]

	var total_width = 8 * 42.0 * scale
	var start_x = center.x - total_width * 0.5

	for i in range(letters.size()):
		var x_offset = start_x + i * 42.0 * scale

		for segment in letters[i]:
			var a = Vector2(
				x_offset + segment[0] * scale,
				center.y - 25 * scale + segment[1] * scale
			)

			var b = Vector2(
				x_offset + segment[2] * scale,
				center.y - 25 * scale + segment[3] * scale
			)

			draw_line(
				a,
				b,
				Color(0.91, 0.95, 0.91),
				4.0 * scale,
				true
			)


# ==========================================
# PAUSE MENU
# ==========================================

func _draw_pause():
	_draw_overlay()

	_draw_text(
		"PAUSED",
		Vector2(screen_size.x * 0.5 - 45, screen_size.y * 0.5 - 90)
	)

	_draw_button("RESUME", 0)
	_draw_button("SETTINGS", 1)
	_draw_button("QUIT", 2)


# ==========================================
# SETTINGS MENU
# ==========================================

func _draw_settings():
	_draw_overlay()

	_draw_text(
		"SETTINGS",
		Vector2(screen_size.x * 0.5 - 45, screen_size.y * 0.5 - 175)
	)

	_draw_button(
		"Music: " + ("ON" if music_enabled else "OFF"),
		0
	)

	_draw_button(
		"Music file: " + music_source,
		1
	)

	_draw_button(
		"Resolution: " + RESOLUTIONS[resolution_index],
		2
	)

	_draw_button(
		"FPS counter: " + ("ON" if fps_enabled else "OFF"),
		3
	)

	_draw_button("BACK", 4)


func _draw_overlay():
	draw_rect(
		Rect2(Vector2.ZERO, screen_size),
		Color(0, 0, 0, 0.78)
	)


func _draw_button(label, index):
	var y

	if game_state == "pause":
		y = screen_size.y * 0.5 - 35 + index * 65
	else:
		y = screen_size.y * 0.5 - 115 + index * 65

	var rect = Rect2(
		screen_size.x * 0.5 - 170,
		y,
		340,
		48
	)

	draw_rect(rect, Color(0.13, 0.18, 0.16))
	draw_rect(rect, Color(0.55, 0.68, 0.58), false, 2)

	_draw_text(
		label,
		Vector2(rect.position.x + 20, rect.position.y + 31)
	)


# ==========================================
# TEXT
# ==========================================

func _draw_text(value, position):
	if ui_font == null:
		return

	draw_string(
		ui_font,
		position,
		value,
		Color(0.94, 0.96, 0.94)
	)


# ==========================================
# VICTORY
# ==========================================

func _draw_victory():
	draw_rect(
		Rect2(Vector2.ZERO, screen_size),
		Color(0.015, 0.015, 0.02)
	)

	_draw_text(
		"ISLANDER",
		Vector2(screen_size.x * 0.5 - 45, 100)
	)

	_draw_text(
		"GAME COMPLETED!",
		Vector2(screen_size.x * 0.5 - 75, screen_size.y - 90)
	)

	_draw_cube_2d(
		Vector2(screen_size.x * 0.5, screen_size.y * 0.5),
		120,
		victory_rotation
	)


func _draw_cube_2d(center, size, angle):
	var vertices = []

	var points = [
		Vector3(-1,-1,-1),
		Vector3(1,-1,-1),
		Vector3(1,1,-1),
		Vector3(-1,1,-1),
		Vector3(-1,-1,1),
		Vector3(1,-1,1),
		Vector3(1,1,1),
		Vector3(-1,1,1)
	]

	var ca = cos(angle)
	var sa = sin(angle)

	for point in points:
		var x = point.x * ca - point.z * sa
		var z = point.x * sa + point.z * ca

		var y = point.y * cos(angle * 0.7) - z * sin(angle * 0.7)
		z = point.y * sin(angle * 0.7) + z * cos(angle * 0.7)

		var perspective = 3.5 / (3.5 + z * 0.35)

		vertices.append(
			center + Vector2(x, y) * size * 0.5 * perspective
		)

	var faces = [
		[0,1,2,3],
		[4,5,6,7],
		[0,1,5,4],
		[2,3,7,6],
		[1,2,6,5],
		[0,3,7,4]
	]

	var colors = [
		Color(0.75,0.77,0.80),
		Color(0.95,0.95,0.95),
		Color(0.55,0.57,0.60),
		Color(0.68,0.70,0.73),
		Color(0.85,0.87,0.90),
		Color(0.43,0.45,0.48)
	]

	for i in range(faces.size()):
		var face = faces[i]

		var polygon = PoolVector2Array([
			vertices[face[0]],
			vertices[face[1]],
			vertices[face[2]],
			vertices[face[3]]
		])

		draw_colored_polygon(polygon, colors[i])

		for j in range(4):
			draw_line(
				vertices[face[j]],
				vertices[face[(j + 1) % 4]],
				Color(0.08,0.08,0.09),
				3.0,
				true
			)
