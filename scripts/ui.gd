extends CanvasLayer

@onready var food = $Panel/HBoxContainer/Food
@onready var tools = $Panel/HBoxContainer/Tools
@onready var money = $Panel/HBoxContainer/Money

@onready var farms_count = $"../Buildings/Farms/Name"
@onready var factories_count = $"../Buildings/Factories/Name"
@onready var cities_count = $"../Buildings/Cities/Name"


var card_scene = preload("res://scenes/card.tscn")

signal card_selected(card)

var current_cards: Array

func show_cards(cards:Array) -> void:
	current_cards = cards
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
	
func update_buildings(buildings: Dictionary) -> void:
	if buildings != null:
		var farm_count = buildings.get(Constants.BUILDING_FARM, []).size()
		var factory_count = buildings.get(Constants.BUILDING_FACTORY, []).size()
		var city_count = buildings.get(Constants.BUILDING_CITY, []).size()

		farms_count.text = "%d %s" % [farm_count, pluralize(farm_count, "FARM", "FARMS")]
		factories_count.text = "%d %s" % [factory_count, pluralize(factory_count, "FACTORY", "FACTORIES")]
		cities_count.text = "%d %s" % [city_count, pluralize(city_count, "CITY", "CITIES")]

func pluralize(count: int, singular: String, plural: String) -> String:
	return singular if count == 1 else plural
