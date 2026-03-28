extends Control

@onready var entries_container = %EntriesVBox

func _ready():
	fill_highscores()
	
func fill_highscores() -> void:
	var highscores = HighscoreManager.load_highscores()
	for i in range(10):
		var label = entries_container.get_child(i)
		if i < highscores.size():
			var entry = highscores[i]
			var ticks = str(int(entry["ticks"])) + " Ticks"
			var datetime = entry["date"]
			var date = datetime.substr(0,10)
			var time = datetime.substr(11,5)
			label.text = ticks + " | " + date + " | " + time
		else:
			label.text = "- - -"


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
