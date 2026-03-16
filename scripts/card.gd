extends Panel

signal card_pressed(card)

var card_data:Dictionary

func set_card_data(data:Dictionary) -> void:
	card_data = data
	$VBoxContainer/TitleLabel.text = data["title"]
	$VBoxContainer/DescriptionLabel.text = data["description"]
	var effect_text = ""
	if data["effect"] == "buy_city":
		effect_text = "Cost: " + str(data["food_cost"]) + " Food / " + str(data["tools_cost"]) + " Tools"
	else:
		effect_text = str(data["value"])
		if data["duration"] > 0:
			effect_text += " for " + str(data["duration"]) + " ticks"
	$VBoxContainer/EffectLabel.text = effect_text

func _gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		card_pressed.emit(card_data)
