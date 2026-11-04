extends SceneTree

# Необязательные снимки для художественной проверки.
# Запуск без --headless: godot --path <папка проекта> --script res://tests/capture.gd

func _initialize() -> void:
	call_deferred("capture_screens")


func capture_screens() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	var game = scene.instantiate()
	root.add_child(game)
	await capture_frame(game, "title")
	game.start_game()
	game.advance_dialogue()
	game.advance_dialogue()
	await capture_frame(game, "start")
	game.player_pos = game.GUARD_POS + Vector2(-25, 0)
	game.interact()
	await capture_frame(game, "dialogue")
	for i in range(3):
		game.advance_dialogue()
	game.notice_time = 0.0
	game.player_pos = Vector2(886, 220)
	game.camera_pos = Vector2(566, 40)
	game.facing = Vector2.RIGHT
	game.enemies[0]["pos"] = Vector2(925, 220)
	game.enemies[0]["attack_time"] = 0.14
	game.try_attack()
	game.attack_flash = game.attack_duration * 0.55
	game.player_run_blend = 0.75
	game.walk_phase = 1.1
	await capture_frame(game, "combat", true)
	game.player_pos = Vector2(1480, 215)
	game.camera_pos = Vector2(1100, 45)
	await capture_frame(game, "beacon")
	game.state = "victory"
	await capture_frame(game, "victory")
	game.queue_free()
	await process_frame
	quit(0)


func capture_frame(game: Node2D, label: String, freeze_game: bool = false) -> void:
	if freeze_game:
		game.set_process(false)
	game.queue_redraw()
	for i in range(4):
		await process_frame
	var picture: Image = root.get_texture().get_image()
	if picture == null:
		push_error("Для снимков нужен графический режим Godot")
		quit(2)
		return
	var destination := "user://preview_" + label + ".png"
	picture.save_png(destination)
	print(ProjectSettings.globalize_path(destination))
	if freeze_game:
		game.set_process(true)
