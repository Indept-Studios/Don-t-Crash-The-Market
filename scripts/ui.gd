extends CanvasLayer

@onready var food = $Panel/HBoxContainer/Food
@onready var tools = $Panel/HBoxContainer/Tools
@onready var money = $Panel/HBoxContainer/Money

var card_scene = preload("res://scenes/card.tscn")

signal card_selected(card)

var current_cards: Array

func show_cards(cards:Array) -> void:
	current_cards=cards
	var container=$CardPopup/Panel/VBoxContainer/Middle/HBoxContainer
	for child in container.get_children():
		child.queue_free()
	for card in cards:
		var card_instance=card_scene.instantiate()
		container.add_child(card_instance)
		card_instance.set_card_data(card)
		card_instance.card_pressed.connect(_on_card_pressed)

func _on_card_pressed(card):
	card_selected.emit(card)

func update_resources(stock: Dictionary) -> void:
	food.text = "FOOD: %d" % stock[Constants.RESOURCE_FOOD]
	tools.text = "TOOLS: %d" % stock[Constants.RESOURCE_TOOLS]
	money.text = "MONEY: %d" % stock[Constants.RESOURCE_MONEY]
