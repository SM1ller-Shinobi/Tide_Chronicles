extends SceneTree

# Запуск: godot --headless --path <папка проекта> --script res://tests/smoke.gd

func _initialize() -> void:
	call_deferred("run_checks")


func run_checks() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	if not check(game.state == "title", "начальный экран"):
		return
	game.start_game()
	game.advance_dialogue()
	game.advance_dialogue()
	if not check(game.state == "playing", "начало игры"):
		return
	if not check(game.is_walkable(Vector2(558, 220)) and game.is_walkable(Vector2(820, 220)), "переходы через мосты"):
		return
	game.player_pos = game.GUARD_POS
	game.interact()
	for i in range(3):
		game.advance_dialogue()
	if not check(game.quest_stage == 1, "получение задания"):
		return
	game.player_pos = Vector2(245, 220)
	for step in range(663):
		game.move_player(Vector2(2, 0))
	if not check(game.player_pos.x > 1568, "проход от города до маяка"):
		return
	game.player_pos = Vector2(880, 220)
	game.facing = Vector2.RIGHT
	var enemy: Dictionary = game.enemies[0]
	enemy["pos"] = game.player_pos + Vector2(20, 0)
	var previous_hp: int = enemy["hp"]
	game.try_attack()
	if not check(enemy["hp"] == previous_hp - 1, "удар парным мечом"):
		return
	if not check(game.attack_flash > 0.0 and game.attack_duration > 0.0, "запуск анимации удара Кэриана"):
		return
	game.player_run_blend = 0.0
	var phase_before_run: float = game.walk_phase
	game.advance_player_run_animation(0.05, true, false)
	if not check(game.player_run_blend > 0.0 and game.walk_phase > phase_before_run, "запуск анимации бега Кэриана"):
		return
	var blend_before_stop: float = game.player_run_blend
	game.advance_player_run_animation(0.05, false, false)
	if not check(game.player_run_blend < blend_before_stop, "плавная остановка бега Кэриана"):
		return
	var running_enemy: Dictionary = game.make_enemy(game.player_pos + Vector2(48, 0), "налётчик", 3, 55.0)
	running_enemy["cooldown"] = 1.0
	game.update_enemy(running_enemy, 0.05)
	if not check(running_enemy["run_phase"] > 0.0 and running_enemy["run_blend"] > 0.0, "запуск анимации бега врага"):
		return
	running_enemy["pos"] = game.player_pos + Vector2(20, 0)
	running_enemy["windup"] = 0.01
	game.invulnerability = 1.0
	game.update_enemy(running_enemy, 0.02)
	if not check(running_enemy["attack_time"] > 0.0, "запуск анимации удара врага"):
		return
	game.invulnerability = 0.0
	game.resonance = 80.0
	game.try_dash()
	if not check(game.dash_time > 0.0 and game.resonance == 60.0, "рывок расходует Резонанс"):
		return
	game.dash_time = 0.0
	game.resonance = 100.0
	game.try_special()
	if not check(not enemy["alive"] and game.resonance >= 60.0, "приливный удар"):
		return
	var parry_target: Dictionary = game.enemies[1]
	parry_target["pos"] = game.player_pos + Vector2(20, 0)
	game.parry_window = 0.3
	game.invulnerability = 0.0
	var hp_before_parry: int = game.hp
	game.resolve_enemy_hit(parry_target)
	if not check(game.hp == hp_before_parry and parry_target["hp"] == 1, "парирование вражеского удара"):
		return
	for target in game.enemies:
		target["alive"] = false
	game.player_pos = game.EVIDENCE_POS
	game.interact()
	game.advance_dialogue()
	game.advance_dialogue()
	if not check(game.quest_stage == 2, "находка приказа"):
		return
	game.player_pos = game.GUARD_POS
	game.interact()
	for i in range(3):
		game.advance_dialogue()
	if not check(game.state == "victory", "завершение эпизода"):
		return
	print("SMOKE TEST PASSED")
	await create_timer(1.5).timeout
	game.queue_free()
	await process_frame
	quit(0)


func check(condition: bool, label: String) -> bool:
	if condition:
		print("OK: ", label)
		return true
	push_error("FAILED: " + label)
	quit(1)
	return false
