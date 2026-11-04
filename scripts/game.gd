extends Node2D

# Хроники Прилива — первый играбельный срез. Все координаты в логических пикселях.
# Окружение сочетает подготовленные иллюстрации и динамические эффекты Godot.

const VIEW := Vector2(640, 360)
const WORLD := Vector2(1740, 450)
const PLAYER_SPEED := 88.0
const DASH_SPEED := 270.0
const STONE_TEX: Texture2D = preload("res://assets/art/stone_v3.png")
const WATER_TEX: Texture2D = preload("res://assets/art/water_v2.png")
const KARIAN_TEX: Texture2D = preload("res://assets/art/karian_lowdetail.png")
const MARA_TEX: Texture2D = preload("res://assets/art/mara_lowdetail.png")
const KARIAN_PORTRAIT: Texture2D = preload("res://assets/art/karian_portrait.png")
const MARA_PORTRAIT: Texture2D = preload("res://assets/art/mara_portrait.png")
const MERCENARY_TEX: Texture2D = preload("res://assets/art/mercenary_lowdetail.png")
const LIGHTHOUSE_TEX: Texture2D = preload("res://assets/art/lighthouse_lowdetail.png")
const WAREHOUSE_TEX: Texture2D = preload("res://assets/art/warehouse_lowdetail.png")
const TITLE_TEX: Texture2D = preload("res://assets/art/title_harbor_lowdetail.png")
const SLASH_A: AudioStream = preload("res://assets/audio/knifeSlice.ogg")
const SLASH_B: AudioStream = preload("res://assets/audio/knifeSlice2.ogg")
const HIT_SOUND: AudioStream = preload("res://assets/audio/chop.ogg")
const DASH_SOUND: AudioStream = preload("res://assets/audio/cloth1.ogg")
const READY_SOUND: AudioStream = preload("res://assets/audio/drawKnife3.ogg")
const PARRY_SOUND: AudioStream = preload("res://assets/audio/metalClick.ogg")
const PAGE_SOUND: AudioStream = preload("res://assets/audio/bookOpen.ogg")
const GUARD_POS := Vector2(452, 180)
const EVIDENCE_POS := Vector2(1570, 238)
const WALK_AREAS := [
	Rect2(38, 94, 522, 262),
	Rect2(558, 200, 264, 56),
	Rect2(820, 91, 352, 278),
	Rect2(1170, 190, 172, 60),
	Rect2(1340, 94, 365, 274),
]
const SOLID_AREAS := [
	Rect2(100, 100, 120, 104),
	Rect2(910, 100, 120, 104),
	Rect2(1576, 110, 64, 71),
]

const INK := Color("#091622")
const NIGHT := Color("#102b3b")
const WATER := Color("#17465b")
const FOAM := Color("#3d8292")
const STONE := Color("#52606c")
const STONE_LIGHT := Color("#89949a")
const CORAL := Color("#8e4e58")
const CORAL_LIGHT := Color("#c97870")
const GOLD := Color("#e5bc74")
const PAPER := Color("#e6e2cf")
const RED := Color("#e4706b")
const BLUE := Color("#78cad4")
const WOOD_DARK := Color("#261d23")
const WOOD_MID := Color("#463039")
const WOOD_LIGHT := Color("#63474a")

var font: Font
var state := "title" # title, playing, dialogue, paused, dead, victory
var quest_stage := 0 # 0: страж, 1: маяк, 2: возвращение, 3: завершено
var player_pos := Vector2(245, 230)
var camera_pos := Vector2.ZERO
var facing := Vector2.RIGHT
var hp := 5
var resonance := 35.0
var invulnerability := 0.0
var attack_cooldown := 0.0
var attack_flash := 0.0
var attack_duration := 0.2
var combo_window := 0.0
var combo_step := 0
var parry_window := 0.0
var parry_cooldown := 0.0
var dash_time := 0.0
var dash_direction := Vector2.RIGHT
var special_flash := 0.0
var walk_phase := 0.0
var player_run_blend := 0.0
var player_moving := false
var time_passed := 0.0
var enemies: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var dialogue: Array[Dictionary] = []
var dialogue_index := 0
var dialogue_result := ""
var notice := ""
var notice_time := 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	font = ThemeDB.fallback_font
	reset_game()


func reset_game() -> void:
	state = "title"
	quest_stage = 0
	player_pos = Vector2(245, 230)
	camera_pos = Vector2.ZERO
	facing = Vector2.RIGHT
	hp = 5
	resonance = 35.0
	invulnerability = 0.0
	attack_cooldown = 0.0
	attack_flash = 0.0
	attack_duration = 0.2
	combo_window = 0.0
	combo_step = 0
	parry_window = 0.0
	parry_cooldown = 0.0
	dash_time = 0.0
	special_flash = 0.0
	walk_phase = 0.0
	player_run_blend = 0.0
	player_moving = false
	notice = ""
	notice_time = 0.0
	effects.clear()
	enemies = [
		make_enemy(Vector2(895, 222), "налётчик", 3, 48.0),
		make_enemy(Vector2(1080, 252), "налётчик", 3, 51.0),
		make_enemy(Vector2(1445, 224), "ветеран", 4, 43.0),
		make_enemy(Vector2(1530, 304), "налётчик", 3, 55.0),
	]
	queue_redraw()


func make_enemy(where: Vector2, kind: String, health: int, speed: float) -> Dictionary:
	return {
		"pos": where, "kind": kind, "hp": health, "max_hp": health,
		"speed": speed, "cooldown": 0.0, "windup": 0.0,
		"stun": 0.0, "flash": 0.0, "alive": true,
		"facing": Vector2.LEFT, "run_phase": 0.0,
		"run_blend": 0.0, "attack_time": 0.0,
	}


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if state == "title" and event.keycode == KEY_ENTER:
			start_game()
			return
		if state == "dialogue" and event.keycode in [KEY_E, KEY_ENTER, KEY_SPACE]:
			advance_dialogue()
			return
		if state == "paused" and event.keycode in [KEY_ESCAPE, KEY_ENTER]:
			state = "playing"
			return
		if state == "dead" and event.keycode in [KEY_R, KEY_ENTER]:
			reset_game()
			start_game()
			return
		if state == "victory" and event.keycode == KEY_ENTER:
			reset_game()
			return
		if state == "playing":
			match event.keycode:
				KEY_ESCAPE:
					state = "paused"
				KEY_E:
					interact()
				KEY_SHIFT:
					try_dash()
				KEY_Q:
					try_special()
	if event is InputEventMouseButton and event.pressed:
		if state == "title":
			start_game()
		elif state == "dialogue":
			advance_dialogue()
		elif state == "playing":
			if event.button_index == MOUSE_BUTTON_LEFT:
				try_attack()
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				try_parry()


func start_game() -> void:
	show_dialogue([
		{"who": "Тидхавен · 16 лет спустя", "text": "У старого маяка снова видели людей\nв багровых плащах. Отец велел не вмешиваться."},
		{"who": "Кэриан", "text": "Разумеется. Я лишь прогуляюсь к причалу\nс двумя мечами. Совпадение, не более."},
	])


func _process(delta: float) -> void:
	time_passed += delta
	if notice_time > 0.0:
		notice_time -= delta
	if state == "playing":
		update_game(delta)
	for index in range(effects.size() - 1, -1, -1):
		effects[index]["ttl"] -= delta
		if effects[index]["ttl"] <= 0.0:
			effects.remove_at(index)
	var desired_camera = player_pos - VIEW * 0.5
	desired_camera.x = clampf(desired_camera.x, 0.0, WORLD.x - VIEW.x)
	desired_camera.y = clampf(desired_camera.y, 0.0, WORLD.y - VIEW.y)
	camera_pos = camera_pos.lerp(desired_camera, minf(1.0, delta * 8.0))
	queue_redraw()


func update_game(delta: float) -> void:
	invulnerability = maxf(0.0, invulnerability - delta)
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	attack_flash = maxf(0.0, attack_flash - delta)
	combo_window = maxf(0.0, combo_window - delta)
	parry_window = maxf(0.0, parry_window - delta)
	parry_cooldown = maxf(0.0, parry_cooldown - delta)
	special_flash = maxf(0.0, special_flash - delta)
	resonance = minf(100.0, resonance + delta * 2.0)

	var mouse_world = get_viewport().get_mouse_position() + camera_pos
	var mouse_delta = mouse_world - player_pos
	if mouse_delta.length_squared() > 16.0:
		facing = mouse_delta.normalized()

	var movement := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		movement.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		movement.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		movement.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		movement.y += 1.0

	if dash_time > 0.0:
		dash_time -= delta
		player_moving = true
		move_player(dash_direction * DASH_SPEED * delta)
	elif movement != Vector2.ZERO:
		player_moving = true
		move_player(movement.normalized() * PLAYER_SPEED * delta)
	else:
		player_moving = false
	advance_player_run_animation(delta, player_moving, dash_time > 0.0)

	for enemy in enemies:
		update_enemy(enemy, delta)


func advance_player_run_animation(delta: float, moving: bool, dashing: bool) -> void:
	if moving:
		walk_phase += delta * (22.0 if dashing else 16.0)
	player_run_blend = move_toward(player_run_blend, 1.0 if moving else 0.0, delta * 12.0)


func move_player(offset: Vector2) -> void:
	var next_x := player_pos + Vector2(offset.x, 0.0)
	if is_walkable(next_x):
		player_pos.x = next_x.x
	var next_y := player_pos + Vector2(0.0, offset.y)
	if is_walkable(next_y):
		player_pos.y = next_y.y


func is_walkable(where: Vector2) -> bool:
	if where.distance_to(GUARD_POS) < 19.0:
		return false
	for obstacle in SOLID_AREAS:
		if obstacle.has_point(where):
			return false
	for area in WALK_AREAS:
		if area.grow(2.0).has_point(where):
			return true
	return false


func update_enemy(enemy: Dictionary, delta: float) -> void:
	if not enemy["alive"]:
		return
	enemy["cooldown"] = maxf(0.0, enemy["cooldown"] - delta)
	enemy["stun"] = maxf(0.0, enemy["stun"] - delta)
	enemy["flash"] = maxf(0.0, enemy["flash"] - delta)
	enemy["attack_time"] = maxf(0.0, enemy["attack_time"] - delta)
	enemy["run_blend"] = move_toward(float(enemy["run_blend"]), 0.0, delta * 10.0)
	var to_player = player_pos - enemy["pos"]
	var distance: float = to_player.length()
	if distance > 0.1:
		enemy["facing"] = to_player / distance
	if enemy["stun"] > 0.0:
		enemy["windup"] = 0.0
		return
	if enemy["attack_time"] > 0.0:
		return
	if enemy["windup"] > 0.0:
		enemy["windup"] -= delta
		if enemy["windup"] <= 0.0:
			enemy["windup"] = 0.0
			enemy["attack_time"] = 0.23
			enemy["cooldown"] = 1.15 if enemy["kind"] == "налётчик" else 1.4
			if distance < 29.0:
				resolve_enemy_hit(enemy)
		return
	if distance < 23.0 and enemy["cooldown"] <= 0.0:
		enemy["windup"] = 0.48 if enemy["kind"] == "налётчик" else 0.65
		return
	if distance < 175.0 and distance > 20.0:
		var step: Vector2 = to_player.normalized() * enemy["speed"] * delta
		var candidate: Vector2 = enemy["pos"] + step
		if is_walkable(candidate):
			enemy["pos"] = candidate
			enemy["run_blend"] = move_toward(float(enemy["run_blend"]), 1.0, delta * 20.0)
			enemy["run_phase"] += delta * 15.0


func resolve_enemy_hit(enemy: Dictionary) -> void:
	if invulnerability > 0.0:
		return
	var to_enemy = enemy["pos"] - player_pos
	if parry_window > 0.0 and facing.dot(to_enemy.normalized()) > -0.15:
		play_sound(PARRY_SOUND, -8.0)
		parry_window = 0.0
		gain_resonance(24.0)
		damage_enemy(enemy, 2, 0.6)
		add_effect(player_pos, BLUE, 29.0, 0.3)
		show_notice("ПАРИРОВАНИЕ  +24 РЕЗОНАНСА")
		return
	hp -= 1
	play_sound(HIT_SOUND, -12.0, 0.75)
	invulnerability = 0.75
	add_effect(player_pos, RED, 26.0, 0.3)
	show_notice("Кэриан ранен")
	if hp <= 0:
		state = "dead"


func try_attack() -> void:
	if attack_cooldown > 0.0 or dash_time > 0.0:
		return
	combo_step = combo_step + 1 if combo_window > 0.0 else 1
	if combo_step > 3:
		combo_step = 1
	play_sound(SLASH_A if combo_step == 1 else SLASH_B, -11.0, 1.08 if combo_step == 3 else 1.0)
	combo_window = 0.72
	attack_cooldown = 0.22 if combo_step < 3 else 0.4
	attack_duration = 0.21 if combo_step < 3 else 0.27
	attack_flash = attack_duration
	var reach := 30.0 if combo_step < 3 else 38.0
	var damage := 1 if combo_step < 3 else 2
	var hits := 0
	for enemy in enemies:
		if not enemy["alive"]:
			continue
		var offset = enemy["pos"] - player_pos
		if offset.length() <= reach and facing.dot(offset.normalized()) > 0.05:
			damage_enemy(enemy, damage, 0.2)
			hits += 1
	if hits > 0:
		gain_resonance(8.0 + 3.0 * float(hits - 1))
	add_effect(player_pos + facing * 20.0, BLUE, reach * 0.5, 0.18)


func try_parry() -> void:
	if parry_cooldown > 0.0 or dash_time > 0.0:
		return
	parry_window = 0.3
	play_sound(READY_SOUND, -17.0, 1.2)
	parry_cooldown = 0.65
	add_effect(player_pos + facing * 11.0, GOLD, 17.0, 0.3)


func try_dash() -> void:
	if dash_time > 0.0 or resonance < 20.0:
		if resonance < 20.0:
			show_notice("Нужно 20 Резонанса")
		return
	resonance -= 20.0
	play_sound(DASH_SOUND, -14.0, 1.15)
	dash_direction = facing
	var move_input := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): move_input.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): move_input.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): move_input.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): move_input.y += 1.0
	if move_input != Vector2.ZERO:
		dash_direction = move_input.normalized()
	dash_time = 0.16
	invulnerability = maxf(invulnerability, 0.22)
	add_effect(player_pos, BLUE, 22.0, 0.2)


func try_special() -> void:
	if resonance < 40.0:
		show_notice("Нужно 40 Резонанса")
		return
	resonance -= 40.0
	play_sound(PARRY_SOUND, -6.0, 0.65)
	special_flash = 0.3
	for enemy in enemies:
		if enemy["alive"] and enemy["pos"].distance_to(player_pos) < 57.0:
			damage_enemy(enemy, 2, 0.5)
	add_effect(player_pos, BLUE, 57.0, 0.45)
	show_notice("ПРИЛИВНЫЙ УДАР")


func damage_enemy(enemy: Dictionary, damage: int, stun: float) -> void:
	enemy["hp"] -= damage
	play_sound(HIT_SOUND, -11.0, 0.9)
	enemy["stun"] = stun
	enemy["flash"] = 0.22
	add_effect(enemy["pos"], CORAL_LIGHT, 16.0, 0.22)
	if enemy["hp"] <= 0:
		enemy["alive"] = false
		gain_resonance(10.0)
		add_effect(enemy["pos"], GOLD, 32.0, 0.45)


func gain_resonance(value: float) -> void:
	resonance = minf(100.0, resonance + value)


func add_effect(where: Vector2, color: Color, radius: float, lifetime: float) -> void:
	effects.append({"pos": where, "color": color, "radius": radius, "ttl": lifetime, "max_ttl": lifetime})


func show_notice(message: String) -> void:
	notice = message
	notice_time = 2.1


func interact() -> void:
	if player_pos.distance_to(GUARD_POS) < 31.0:
		if quest_stage == 0:
			show_dialogue([
				{"who": "Страж Мара", "text": "Принц, у старого маяка замечены чужаки.\nОни пришли по восточному мосту."},
				{"who": "Кэриан", "text": "На их плащах был багровый знак?"},
				{"who": "Страж Мара", "text": "Да. Осмотрите маяк и принесите улику.\nНа мостах тесно — следите за их клинками."},
			], "accept")
		elif quest_stage == 1:
			show_dialogue([{"who": "Страж Мара", "text": "Маяк к востоку. Если враг замахнулся,\nпоймайте удар парированием."}])
		elif quest_stage == 2:
			show_dialogue([
				{"who": "Кэриан", "text": "У маяка нашёлся приказ с кровавой печатью.\nТе же слова, что были в старом донесении."},
				{"who": "Страж Мара", "text": "Это уже не слухи. Я передам письмо королю.\nА вам лучше сохранить его копию."},
				{"who": "Кэриан", "text": "Отец опять скажет, что я ищу беды.\nНа этот раз беда сама приплыла в порт."},
			], "complete")
		else:
			show_dialogue([{"who": "Страж Мара", "text": "Приказ в надёжных руках. Спасибо, принц."}])
		return
	if player_pos.distance_to(EVIDENCE_POS) < 30.0:
		if quest_stage == 0:
			show_notice("Сначала поговорите со стражем")
			return
		if quest_stage == 1:
			for enemy in enemies:
				if enemy["alive"] and enemy["pos"].distance_to(EVIDENCE_POS) < 85.0:
					show_notice("Сначала обезвредьте стражу маяка")
					return
			show_dialogue([
				{"who": "Промокший приказ", "text": "«Маяки погасить до прихода прилива.\nТорговые суда послужат прикрытием»."},
				{"who": "Кэриан", "text": "Печать Валиса... Это было не нападение\nс моря. Их впустили через сам порт."},
			], "evidence")
		else:
			show_notice("Копия приказа уже у вас")
		return
	show_notice("Здесь не с чем взаимодействовать")


func show_dialogue(lines: Array[Dictionary], result: String = "") -> void:
	play_sound(PAGE_SOUND, -18.0)
	dialogue = lines
	dialogue_index = 0
	dialogue_result = result
	state = "dialogue"


func advance_dialogue() -> void:
	play_sound(PAGE_SOUND, -22.0, 1.16)
	dialogue_index += 1
	if dialogue_index < dialogue.size():
		return
	state = "playing"
	match dialogue_result:
		"accept":
			quest_stage = 1
			show_notice("ЗАДАНИЕ: ОСМОТРЕТЬ СТАРЫЙ МАЯК")
		"evidence":
			quest_stage = 2
			show_notice("УЛИКА НАЙДЕНА: ВЕРНИТЕСЬ К МАРЕ")
		"complete":
			quest_stage = 3
			state = "victory"
	dialogue_result = ""


func play_sound(sample: AudioStream, volume: float, pitch: float = 1.0) -> void:
	var voice := AudioStreamPlayer.new()
	voice.stream = sample
	voice.volume_db = volume
	voice.pitch_scale = pitch
	add_child(voice)
	voice.finished.connect(voice.queue_free)
	voice.play()


func _draw() -> void:
	draw_set_transform(-camera_pos)
	draw_world()
	draw_props()
	draw_guard()
	draw_evidence()
	for enemy in enemies:
		draw_enemy(enemy)
	draw_player()
	draw_effects()
	draw_set_transform(Vector2.ZERO)
	if state not in ["title", "victory"]:
		draw_weather()
	draw_hud()
	match state:
		"title": draw_title()
		"dialogue": draw_dialogue()
		"paused": draw_overlay("ПАУЗА", "Esc или Enter — продолжить")
		"dead": draw_overlay("КЭРИАН ПАЛ", "R или Enter — начать заново")
		"victory": draw_victory()


# Мир: холодная вода, коралловая кладка Тидхавена и узкие причалы.
func draw_world() -> void:
	draw_rect(Rect2(Vector2.ZERO, WORLD), NIGHT)
	var water_shift := sin(time_passed * 0.58) * 22.0
	for tile in range(4):
		draw_texture_rect_region(WATER_TEX, Rect2(tile * 500, 0, 500, 450), Rect2(24.0 + water_shift, 0, 1205, 940))
	draw_rect(Rect2(Vector2.ZERO, WORLD), Color(0.01, 0.08, 0.13, 0.16))
	for i in range(54):
		var ripple_x := fposmod(float(i * 139) + time_passed * (9.0 + float(i % 4) * 2.0), WORLD.x)
		var ripple_y := float(32 + (i * 89) % 382) + sin(time_passed * 1.2 + float(i)) * 2.0
		var wave_color := Color(0.44, 0.76, 0.81, 0.22) if i % 5 == 0 else Color(0.25, 0.55, 0.62, 0.19)
		draw_line(Vector2(ripple_x, ripple_y), Vector2(ripple_x + 10.0 + float(i % 3) * 3.0, ripple_y), wave_color, 1.0)

	for i in range(WALK_AREAS.size()):
		draw_platform(WALK_AREAS[i], i == 1 or i == 3)

	# Силуэты лодок остаются за пределами игрового маршрута.
	for i in range(3):
		var boat_x := 610.0 + float(i) * 283.0
		var boat_y := 335.0 if i % 2 == 0 else 105.0
		draw_line(Vector2(boat_x, boat_y), Vector2(boat_x + 44, boat_y), INK, 6.0)
		draw_line(Vector2(boat_x + 17, boat_y - 5), Vector2(boat_x + 17, boat_y - 31), STONE_LIGHT, 1.0)
		draw_line(Vector2(boat_x + 18, boat_y - 30), Vector2(boat_x + 35, boat_y - 8), PAPER.darkened(0.28), 2.0)

	# Фасады старого причала и маяка.
	draw_rect(Rect2(850, 49, 67, 42), INK)
	draw_rect(Rect2(855, 54, 57, 37), CORAL.darkened(0.25))
	draw_rect(Rect2(875, 71, 11, 20), INK)
	draw_line(Vector2(846, 50), Vector2(884, 35), CORAL_LIGHT, 4.0)
	draw_line(Vector2(884, 35), Vector2(921, 50), CORAL_LIGHT, 4.0)
	draw_texture_rect(WAREHOUSE_TEX, Rect2(95, 90, 130, 114), false)
	draw_texture_rect(WAREHOUSE_TEX, Rect2(905, 90, 130, 114), false)
	draw_lighthouse()


func draw_platform(area: Rect2, bridge: bool) -> void:
	draw_rect(Rect2(area.position + Vector2(-5, 0), area.size + Vector2(10, 10)), INK)
	if bridge:
		draw_wood_bridge(area)
	else:
		draw_texture_rect_region(STONE_TEX, area, Rect2(0, 0, area.size.x * 2.4, area.size.y * 2.4), Color(0.85, 0.88, 0.93))
		draw_rect(Rect2(area.position.x, area.position.y, area.size.x, 4), STONE_LIGHT.darkened(0.38))
		draw_rect(Rect2(area.position.x + 5, area.end.y - 5, area.size.x - 10, 3), CORAL)
		for x in range(int(area.position.x + 26), int(area.end.x), 90):
			draw_rect(Rect2(x, area.end.y - 5, 24, 3), GOLD.darkened(0.25))


func draw_wood_bridge(area: Rect2) -> void:
	draw_rect(area, WOOD_DARK)
	for x in range(int(area.position.x + 3), int(area.end.x - 3), 12):
		var plank_color := WOOD_MID if int(x / 12) % 3 == 0 else WOOD_LIGHT.darkened(0.12)
		draw_rect(Rect2(x, area.position.y + 5, 10, area.size.y - 10), plank_color)
		draw_rect(Rect2(x + 2, area.position.y + 8, 2, area.size.y - 16), Color(0.13, 0.10, 0.12, 0.2))
		draw_rect(Rect2(x + 3, area.position.y + 9, 2, 2), WOOD_DARK)
		draw_rect(Rect2(x + 3, area.end.y - 11, 2, 2), WOOD_DARK)
	for side_y in [area.position.y + 1, area.end.y - 4]:
		draw_rect(Rect2(area.position.x, side_y, area.size.x, 3), WOOD_DARK)
		draw_rect(Rect2(area.position.x, side_y + 1, area.size.x, 1), WOOD_LIGHT)
	for x in range(int(area.position.x + 13), int(area.end.x), 36):
		for side_y in [area.position.y - 5, area.end.y - 5]:
			draw_rect(Rect2(x, side_y, 5, 10), WOOD_DARK)
			draw_rect(Rect2(x + 1, side_y + 1, 3, 7), WOOD_LIGHT)


func draw_lighthouse() -> void:
	var base := Vector2(1608, 177)
	draw_circle(base + Vector2(0, -93), 47.0, Color(1.0, 0.70, 0.32, 0.10))
	draw_texture_rect(LIGHTHOUSE_TEX, Rect2(base.x - 47, base.y - 112, 94, 112), false)
	draw_arc(base + Vector2(0, -91), 24.0 + sin(time_passed * 2.0) * 3.0, 0.0, TAU, 36, Color(1.0, 0.81, 0.46, 0.22), 2.0)


func draw_props() -> void:
	for lamp in [Vector2(82, 119), Vector2(515, 121), Vector2(842, 116), Vector2(1136, 115), Vector2(1370, 114), Vector2(1682, 117)]:
		draw_lamp(lamp)
	for crate in [Vector2(113, 300), Vector2(130, 300), Vector2(500, 303), Vector2(1020, 321), Vector2(1038, 321), Vector2(1392, 322)]:
		draw_rect(Rect2(crate.x - 6, crate.y - 5, 13, 12), INK)
		draw_rect(Rect2(crate.x - 4, crate.y - 4, 10, 9), CORAL.darkened(0.2))
		draw_line(crate + Vector2(-4, -4), crate + Vector2(6, 5), GOLD.darkened(0.3), 1.0)
	for flag_x in [330.0, 1015.0, 1488.0]:
		draw_line(Vector2(flag_x, 121), Vector2(flag_x, 76), INK, 2.0)
		draw_rect(Rect2(flag_x + 2, 78, 18, 12), CORAL)
		draw_rect(Rect2(flag_x + 5, 81, 11, 2), GOLD)


func draw_lamp(where: Vector2) -> void:
	draw_circle(where + Vector2(0, -13), 11.0, Color(1.0, 0.77, 0.42, 0.09))
	draw_line(where, where + Vector2(0, -19), INK, 3.0)
	draw_rect(Rect2(where.x - 4, where.y - 23, 8, 8), INK)
	draw_rect(Rect2(where.x - 2, where.y - 21, 4, 4), GOLD)


func draw_guard() -> void:
	draw_ellipse_shadow(GUARD_POS + Vector2(0, 8))
	var idle_sway := sin(time_passed * 1.5) * 0.5
	var idle_bob := sin(time_passed * 2.4) * 0.5
	draw_texture_rect(MARA_TEX, Rect2(GUARD_POS.x - 15 + idle_sway, GUARD_POS.y - 35 + idle_bob, 30, 43), false)
	draw_text_world(GUARD_POS + Vector2(-12, 24), "Мара", 10, PAPER)
	if quest_stage == 0 or quest_stage == 2:
		draw_marker(GUARD_POS + Vector2(0, -26), GOLD, "!")


func draw_evidence() -> void:
	draw_rect(Rect2(EVIDENCE_POS.x - 8, EVIDENCE_POS.y - 6, 18, 14), INK)
	draw_rect(Rect2(EVIDENCE_POS.x - 6, EVIDENCE_POS.y - 5, 14, 11), PAPER)
	draw_line(EVIDENCE_POS + Vector2(-3, -1), EVIDENCE_POS + Vector2(5, -1), CORAL, 1.0)
	draw_circle(EVIDENCE_POS + Vector2(3, 3), 2.0, CORAL)
	if quest_stage == 1:
		draw_marker(EVIDENCE_POS + Vector2(0, -23), BLUE, "?")


func draw_marker(where: Vector2, color: Color, symbol: String) -> void:
	var float_y := sin(time_passed * 4.0) * 2.0
	draw_circle(where + Vector2(0, float_y), 9.0, INK)
	draw_circle(where + Vector2(0, float_y), 7.0, color)
	draw_text_world(where + Vector2(-3, 4 + float_y), symbol, 12, INK)


func draw_character(where: Vector2, cloak: Color, trim: Color, direction: Vector2) -> void:
	var x := roundf(where.x)
	var y := roundf(where.y)
	draw_ellipse_shadow(Vector2(x, y + 7))
	draw_rect(Rect2(x - 5, y + 1, 4, 7), INK)
	draw_rect(Rect2(x + 2, y + 1, 4, 7), INK)
	draw_rect(Rect2(x - 8, y - 12, 16, 15), cloak.darkened(0.32))
	draw_rect(Rect2(x - 6, y - 10, 12, 12), cloak)
	draw_rect(Rect2(x - 3, y - 9, 6, 9), trim.darkened(0.36))
	draw_rect(Rect2(x - 5, y - 20, 10, 10), INK)
	draw_rect(Rect2(x - 4, y - 18, 8, 7), Color("#d7a284"))
	draw_rect(Rect2(x - 5, y - 21, 10, 4), trim)
	if direction.x < -0.1:
		draw_rect(Rect2(x - 5, y - 16, 2, 2), INK)
	else:
		draw_rect(Rect2(x + 3, y - 16, 2, 2), INK)


func draw_ellipse_shadow(where: Vector2) -> void:
	draw_rect(Rect2(where.x - 9, where.y, 18, 3), Color(0.04, 0.09, 0.12, 0.45))


func draw_enemy(enemy: Dictionary) -> void:
	if not enemy["alive"]:
		draw_rect(Rect2(enemy["pos"].x - 7, enemy["pos"].y + 3, 14, 3), CORAL.darkened(0.55))
		return
	draw_ellipse_shadow(enemy["pos"] + Vector2(0, 8))
	var tint := Color(1.0, 0.96, 0.86) if enemy["kind"] == "ветеран" else Color.WHITE
	if enemy["flash"] > 0.0:
		tint = Color(1.0, 0.74, 0.74)
	var run_blend: float = enemy["run_blend"]
	var stride: float = sin(float(enemy["run_phase"])) * run_blend
	var idle_bob := sin(time_passed * 2.3 + enemy["pos"].x * 0.02) * 0.55 * (1.0 - run_blend)
	var bob := idle_bob - absf(stride) * 1.8
	var attack_strength := 0.0
	if enemy["attack_time"] > 0.0:
		attack_strength = sin(PI * (1.0 - float(enemy["attack_time"]) / 0.23))
	var flip := -1.0 if enemy["facing"].x < 0.0 else 1.0
	var lean := stride * 0.075 + attack_strength * flip * 0.14
	var lunge: Vector2 = enemy["facing"] * attack_strength * 4.0
	draw_set_transform(enemy["pos"] - camera_pos + lunge + Vector2(0.0, bob), lean, Vector2(flip, 1.0))
	draw_texture_rect(MERCENARY_TEX, Rect2(-15, -33, 30, 41), false, tint)
	draw_set_transform(-camera_pos)
	if run_blend > 0.05:
		var step_color := Color(0.33, 0.61, 0.68, 0.22 * run_blend)
		draw_line(enemy["pos"] + Vector2(-7, 5), enemy["pos"] + Vector2(-7 - stride * 3.0, 5), step_color, 1.0)
		draw_line(enemy["pos"] + Vector2(7, 5), enemy["pos"] + Vector2(7 + stride * 3.0, 5), step_color, 1.0)
	if enemy["windup"] > 0.0:
		var pulse := 0.55 + 0.45 * sin(time_passed * 16.0)
		draw_arc(enemy["pos"], 21.0, -PI * 0.2, PI * 1.2, 20, Color(RED, pulse), 2.0)
		draw_text_world(enemy["pos"] + Vector2(-3, -29), "!", 13, RED)
	if enemy["attack_time"] > 0.0:
		var progress := 1.0 - float(enemy["attack_time"]) / 0.23
		var blade_angle: float = enemy["facing"].angle() - 1.05 + progress * 1.55
		var slash_color := Color(RED, 0.4 + 0.5 * sin(PI * progress))
		draw_arc(enemy["pos"] + enemy["facing"] * 8.0, 22.0, blade_angle, blade_angle + 0.78, 14, slash_color, 3.0)
	if enemy["hp"] < enemy["max_hp"]:
		draw_rect(Rect2(enemy["pos"].x - 10, enemy["pos"].y - 27, 20, 3), INK)
		draw_rect(Rect2(enemy["pos"].x - 9, enemy["pos"].y - 26, 18.0 * float(enemy["hp"]) / float(enemy["max_hp"]), 1), RED)


func draw_player() -> void:
	if invulnerability > 0.0 and int(time_passed * 14.0) % 2 == 0:
		return
	if dash_time > 0.0:
		for i in range(1, 4):
			draw_rect(Rect2(player_pos.x - dash_direction.x * i * 7.0 - 7, player_pos.y - dash_direction.y * i * 7.0 - 16, 14, 19), Color(0.39, 0.81, 0.84, 0.2))
	draw_ellipse_shadow(player_pos + Vector2(0, 8))
	var stride := sin(walk_phase) * player_run_blend
	var idle_weight := 1.0 - player_run_blend
	var bob := -absf(stride) * 2.1 + sin(time_passed * 2.6) * 0.7 * idle_weight
	var sway := sin(time_passed * 1.3) * 0.8 * idle_weight
	var breath := sin(time_passed * 2.6 + 0.7) * 0.6 * idle_weight
	var attack_strength := 0.0
	if attack_flash > 0.0:
		attack_strength = sin(PI * (1.0 - attack_flash / attack_duration))
	var flip := -1.0 if facing.x < 0.0 else 1.0
	var combo_side := -1.0 if combo_step == 2 else 1.0
	var lean := stride * 0.07 + attack_strength * combo_side * flip * 0.16
	var lunge := facing * attack_strength * 5.0
	draw_set_transform(player_pos - camera_pos + lunge + Vector2(sway, bob), lean, Vector2(flip, 1.0))
	draw_texture_rect(KARIAN_TEX, Rect2(-19, -42 - breath, 38, 50 + breath), false)
	draw_set_transform(-camera_pos)
	if player_run_blend > 0.05:
		var wake_color := Color(BLUE, 0.23 * player_run_blend)
		draw_line(player_pos + Vector2(-9, 5), player_pos + Vector2(-9 - stride * 4.0, 5), wake_color, 1.0)
		draw_line(player_pos + Vector2(9, 5), player_pos + Vector2(9 + stride * 4.0, 5), wake_color, 1.0)
	if attack_flash > 0.0:
		var progress := 1.0 - attack_flash / attack_duration
		var arc_radius := 25.0 + float(combo_step) * 3.0
		var slash_angle := facing.angle() + combo_side * (-1.1 + progress * 1.8)
		var slash_alpha := 0.4 + 0.55 * sin(PI * progress)
		draw_arc(player_pos + facing * 9.0, arc_radius, minf(slash_angle, slash_angle + combo_side * 0.85), maxf(slash_angle, slash_angle + combo_side * 0.85), 16, Color(BLUE, slash_alpha), 4.0)
		draw_arc(player_pos + facing * 7.0, arc_radius - 7.0, minf(slash_angle - combo_side * 0.22, slash_angle + combo_side * 0.5), maxf(slash_angle - combo_side * 0.22, slash_angle + combo_side * 0.5), 14, Color(PAPER, slash_alpha * 0.8), 2.0)
	if parry_window > 0.0:
		draw_arc(player_pos + facing * 5.0, 16.0, facing.angle() - 1.1, facing.angle() + 1.1, 16, GOLD, 2.0)
	if special_flash > 0.0:
		draw_arc(player_pos, 57.0 * (1.0 - special_flash), 0.0, TAU, 32, BLUE, 3.0)


func draw_effects() -> void:
	for effect in effects:
		var progress: float = 1.0 - float(effect["ttl"]) / float(effect["max_ttl"])
		var effect_color: Color = effect["color"]
		effect_color.a = 0.7 * (1.0 - progress)
		draw_arc(effect["pos"], float(effect["radius"]) * (0.65 + progress * 0.5), 0.0, TAU, 24, effect_color, 2.0)


func draw_weather() -> void:
	for i in range(96):
		var rain_x := fposmod(float(i * 139) - time_passed * 32.0, VIEW.x)
		var rain_y := fposmod(float(i * 83) + time_passed * 145.0, VIEW.y)
		draw_line(Vector2(rain_x, rain_y), Vector2(rain_x - 2.0, rain_y + 7.0), Color(0.65, 0.85, 0.93, 0.24), 1.0)


# Экранный интерфейс использует тот же шрифт Godot, что и обычные Control.
func draw_hud() -> void:
	if state == "title":
		return
	draw_rect(Rect2(0, 0, 640, 38), Color(0.03, 0.08, 0.12, 0.92))
	draw_rect(Rect2(0, 37, 640, 1), CORAL)
	draw_text_ui(Vector2(13, 14), "КЭРИАН", 12, PAPER)
	for i in range(5):
		var heart_color := RED if i < hp else STONE.darkened(0.25)
		draw_rect(Rect2(88 + i * 13, 5, 9, 8), heart_color)
		draw_rect(Rect2(90 + i * 13, 13, 5, 3), heart_color)
	draw_text_ui(Vector2(13, 30), "РЕЗОНАНС", 10, BLUE)
	draw_rect(Rect2(87, 23, 108, 7), INK)
	draw_rect(Rect2(89, 25, 104.0 * resonance / 100.0, 3), BLUE)
	draw_text_ui(Vector2(209, 28), "%d / 100" % int(resonance), 10, PAPER)
	var objective := "Поговорить с Марой"
	match quest_stage:
		1: objective = "Осмотреть старый маяк"
		2: objective = "Вернуться к Маре с уликой"
		3: objective = "Приказ передан"
	draw_text_ui(Vector2(390, 14), "НОЧЬ РАЗБИТЫХ МАЯКОВ", 10, GOLD)
	draw_text_ui(Vector2(390, 29), objective, 10, PAPER)
	if state == "playing":
		draw_rect(Rect2(0, 342, 640, 18), Color(0.03, 0.08, 0.12, 0.85))
		draw_text_ui(Vector2(8, 355), "WASD ходьба   ЛКМ комбо   ПКМ парирование   Shift рывок   Q прилив   E действие", 10, PAPER)
		var prompt := ""
		if player_pos.distance_to(GUARD_POS) < 31.0:
			prompt = "E — поговорить с Марой"
		elif player_pos.distance_to(EVIDENCE_POS) < 30.0:
			prompt = "E — изучить приказ"
		if prompt != "":
			draw_rect(Rect2(202, 292, 235, 24), INK)
			draw_rect(Rect2(204, 294, 231, 20), CORAL.darkened(0.5))
			draw_text_ui(Vector2(217, 308), prompt, 12, PAPER)
	if notice_time > 0.0 and state in ["playing", "dialogue"]:
		draw_rect(Rect2(163, 46, 314, 24), INK)
		draw_text_ui(Vector2(176, 62), notice, 12, GOLD)


func draw_title() -> void:
	draw_texture_rect_region(TITLE_TEX, Rect2(0, 0, 640, 360), Rect2(Vector2.ZERO, TITLE_TEX.get_size()))
	draw_rect(Rect2(0, 0, 355, 360), Color(0.02, 0.05, 0.09, 0.78))
	draw_rect(Rect2(355, 0, 72, 360), Color(0.02, 0.05, 0.09, 0.36))
	draw_rect(Rect2(0, 0, 640, 4), CORAL)
	draw_text_ui(Vector2(35, 88), "ХРОНИКИ", 31, PAPER)
	draw_text_ui(Vector2(35, 124), "ПРИЛИВА", 31, PAPER)
	draw_line(Vector2(36, 140), Vector2(305, 140), GOLD, 2.0)
	draw_text_ui(Vector2(36, 170), "ОСКОЛОК МАЯКА", 17, GOLD)
	draw_text_ui(Vector2(36, 200), "Тидхавен. 16 лет после Ночи Маяков.", 11, PAPER)
	draw_text_ui(Vector2(36, 219), "Первый след вновь ведёт к причалу.", 11, PAPER)
	draw_text_ui(Vector2(36, 247), "КОРОТКИЙ ЭПИЗОД ПЕРВОЙ ГЛАВЫ", 10, BLUE)
	draw_rect(Rect2(35, 268, 279, 38), CORAL.darkened(0.12))
	draw_rect(Rect2(35, 268, 279, 2), GOLD)
	draw_text_ui(Vector2(58, 293), "ENTER / ЩЕЛЧОК — НАЧАТЬ", 13, PAPER)


func draw_dialogue() -> void:
	if dialogue_index >= dialogue.size():
		return
	var line := dialogue[dialogue_index]
	draw_rect(Rect2(13, 237, 614, 119), INK)
	draw_rect(Rect2(16, 240, 608, 113), Color("#203b4a"))
	draw_rect(Rect2(16, 240, 608, 2), GOLD)
	draw_rect(Rect2(17, 351, 606, 2), CORAL.darkened(0.35))
	var has_mara := false
	var has_document := false
	for dialogue_line in dialogue:
		if dialogue_line["who"] == "Страж Мара":
			has_mara = true
		if dialogue_line["who"] == "Промокший приказ":
			has_document = true
	var karian_active: bool = line["who"] == "Кэриан"
	var mara_active: bool = line["who"] == "Страж Мара"
	var left_border := GOLD if karian_active else CORAL.darkened(0.35)
	draw_rect(Rect2(21, 244, 89, 102), left_border)
	draw_rect(Rect2(23, 246, 85, 98), Color("#112432"))
	draw_texture_rect(KARIAN_PORTRAIT, Rect2(34, 246 - (2 if karian_active else 0), 64, 96), false, Color.WHITE if karian_active else Color(0.58, 0.65, 0.7, 0.75))
	draw_rect(Rect2(23, 328, 85, 16), Color(0.04, 0.09, 0.14, 0.9))
	draw_text_ui(Vector2(44, 340), "КЭРИАН", 10, GOLD if karian_active else PAPER.darkened(0.28))
	if has_mara or has_document:
		var right_border := GOLD if mara_active or line["who"] == "Промокший приказ" else CORAL.darkened(0.35)
		draw_rect(Rect2(530, 244, 89, 102), right_border)
		draw_rect(Rect2(532, 246, 85, 98), Color("#112432"))
		if has_mara:
			draw_texture_rect(MARA_PORTRAIT, Rect2(544, 246 - (2 if mara_active else 0), 64, 96), false, Color.WHITE if mara_active else Color(0.58, 0.65, 0.7, 0.75))
			draw_rect(Rect2(532, 328, 85, 16), Color(0.04, 0.09, 0.14, 0.9))
			draw_text_ui(Vector2(558, 340), "МАРА", 10, GOLD if mara_active else PAPER.darkened(0.28))
		else:
			draw_rect(Rect2(558, 266, 31, 48), PAPER)
			draw_rect(Rect2(563, 278, 21, 2), CORAL)
			draw_rect(Rect2(563, 286, 21, 2), STONE)
			draw_rect(Rect2(563, 294, 16, 2), STONE)
			draw_circle(Vector2(580, 306), 4.0, CORAL)
			draw_rect(Rect2(532, 328, 85, 16), Color(0.04, 0.09, 0.14, 0.9))
			draw_text_ui(Vector2(554, 340), "ПРИКАЗ", 10, PAPER.darkened(0.1))
	draw_text_ui(Vector2(119, 260), line["who"], 13, GOLD)
	draw_line(Vector2(119, 268), Vector2(518, 268), CORAL.darkened(0.25), 1.0)
	var text_lines: PackedStringArray = line["text"].split("\n")
	for i in range(text_lines.size()):
		draw_text_ui(Vector2(119, 289 + i * 18), text_lines[i], 12, PAPER)
	draw_text_ui(Vector2(445, 341), "E / Enter  ›", 10, BLUE)


func draw_overlay(heading: String, hint: String) -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color(0.02, 0.05, 0.08, 0.69))
	draw_rect(Rect2(130, 123, 380, 114), INK)
	draw_rect(Rect2(134, 127, 372, 106), CORAL.darkened(0.45))
	draw_text_center(166, heading, 24, PAPER)
	draw_text_center(203, hint, 13, GOLD)


func draw_victory() -> void:
	draw_texture_rect_region(TITLE_TEX, Rect2(0, 0, 640, 360), Rect2(Vector2.ZERO, TITLE_TEX.get_size()))
	draw_rect(Rect2(0, 0, 640, 360), Color(0.02, 0.05, 0.08, 0.68))
	draw_rect(Rect2(29, 30, 582, 300), INK)
	draw_rect(Rect2(33, 34, 574, 292), Color("#1b3948"))
	draw_rect(Rect2(33, 34, 574, 3), GOLD)
	draw_texture_rect(KARIAN_TEX, Rect2(420, 57, 155, 248), false)
	draw_text_ui(Vector2(59, 85), "ЭПИЗОД ЗАВЕРШЁН", 21, PAPER)
	draw_text_ui(Vector2(60, 117), "Осколок маяка", 16, GOLD)
	draw_line(Vector2(60, 133), Vector2(374, 133), CORAL, 2.0)
	draw_text_ui(Vector2(60, 172), "У Кэриана есть первый след", 12, PAPER)
	draw_text_ui(Vector2(60, 190), "Ночи Маяков.", 12, PAPER)
	draw_text_ui(Vector2(60, 224), "Кто открыл порт налётчикам?", 12, PAPER)
	draw_text_ui(Vector2(60, 275), "ENTER — К ТИТУЛЬНОМУ ЭКРАНУ", 11, BLUE)


func draw_text_world(where: Vector2, value: String, size: int, color: Color) -> void:
	draw_string(font, where, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func draw_text_ui(where: Vector2, value: String, size: int, color: Color) -> void:
	draw_string(font, where, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func draw_text_center(y: float, value: String, size: int, color: Color) -> void:
	draw_string(font, Vector2(0, y), value, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, size, color)
