extends Node

func load_highscores() -> Array:
	if not FileAccess.file_exists(Constants.HIGHSCORE_PATH):
		return []
	var file = FileAccess.open(Constants.HIGHSCORE_PATH, FileAccess.READ)
	if file == null:
		return []
	var content = file.get_as_text()
	file.close()
	var data = JSON.parse_string(content)
	if data == null or typeof(data) != TYPE_DICTIONARY:
		return []
	if not data.has("best_times") or typeof(data["best_times"]) != TYPE_ARRAY:
		return []
	var result: Array = []
	for entry in data["best_times"]:
		if typeof(entry) == TYPE_DICTIONARY and entry.has("ticks") and entry.has("date"):
			result.append(entry)
	return result
	
func save_highscores(highscores: Array) -> void:
	var data = {
		"best_times": highscores
	}
	var file = FileAccess.open(Constants.HIGHSCORE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	
func add_highscore(tick_count: float) -> void:
	var highscores = load_highscores()
	var entry = {
		"ticks": tick_count,
		"date": Time.get_datetime_string_from_system()
	}
	highscores.append(entry)
	highscores.sort_custom(func(a, b): return a["ticks"] < b["ticks"])
	if highscores.size() > Constants.MAX_HIGHSCORES:
		highscores.resize(Constants.MAX_HIGHSCORES)
	save_highscores(highscores)
