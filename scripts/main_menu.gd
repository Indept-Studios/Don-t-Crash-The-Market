extends Control

var game_scene = preload("res://scenes/Game.tscn")
var highscroe_scene = preload("res://scenes/highscore.tscn")

func _on_new_game_pressed():
	get_tree().change_scene_to_packed(game_scene)

func _on_options_pressed():
	print("Options not implemented yet")

func _on_highscore_pressed():
	get_tree().change_scene_to_packed(highscroe_scene)
