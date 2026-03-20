extends CanvasLayer

@onready var game = get_parent()

@onready var food = $Panel/HBoxContainer/Food
@onready var tools = $Panel/HBoxContainer/Tools
@onready var money = $Panel/HBoxContainer/Money

@onready var farms_count = $"../Buildings/Farms/Name"
@onready var factories_count = $"../Buildings/Factories/Name"
@onready var cities_count = $"../Buildings/Cities/Name"
@onready var year_label = $YearLabel
#FARMS
@onready var output_label_Farm = $"../Buildings/Farms/In_Outputs/OutputLabel"
#FACTORIES
@onready var input_label_Factory = $"../Buildings/Factories/In_Outputs/InputLabel"
@onready var output_label_Factory = $"../Buildings/Factories/In_Outputs/OutputLabel"
#CITIES
@onready var input_label_1_City = $"../Buildings/Cities/In_Outputs/InputLabel1"
@onready var input_label_2_City = $"../Buildings/Cities/In_Outputs/InputLabel2"
@onready var output_label_City = $"../Buildings/Cities/In_Outputs/OutputLabel"


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
		update_building_io(buildings)

func pluralize(count: int, singular: String, plural: String) -> String:
	return singular if count == 1 else plural

func update_year(tick: int) -> void:
	year_label.text = "Year: %d" % tick

func _ready():
	year_label.text = "Year: 1"
	get_parent().tick_started.connect(update_year)

func update_building_io(buildings: Dictionary) -> void:
	update_farm_io(buildings)
	update_factory_io(buildings)
	update_city_io(buildings)
	
func update_farm_io(buildings: Dictionary) -> void:
	var farms = buildings.get(Constants.BUILDING_FARM, [])
	if farms.is_empty():
		output_label_Farm.text = "0"
		return

	var farm = farms[0]
	var base_food = farm.outputs.get(Constants.RESOURCE_FOOD, 0)
	var modifier = game.get_modifier("farm_output")
	var effective_food = game.get_modified_value(base_food, modifier, 0)

	output_label_Farm.text = str(effective_food)
	
func update_factory_io(buildings: Dictionary) -> void:
	var factories = buildings.get(Constants.BUILDING_FACTORY, [])
	if factories.is_empty():
		input_label_Factory.text = "0"
		output_label_Factory.text = "0"
		return

	var factory = factories[0]

	var base_food = factory.inputs.get(Constants.RESOURCE_FOOD, 0)
	var food_modifier = game.get_modifier("factory_food_input")
	var effective_food = game.get_modified_value(base_food, food_modifier, 1)

	var base_tools = factory.outputs.get(Constants.RESOURCE_TOOLS, 0)
	var tools_modifier = game.get_modifier("factory_output")
	var effective_tools = game.get_modified_value(base_tools, tools_modifier, 0)

	input_label_Factory.text = str(effective_food)
	output_label_Factory.text = str(effective_tools)
	
func update_city_io(buildings: Dictionary) -> void:
	var cities = buildings.get(Constants.BUILDING_CITY, [])
	if cities.is_empty():
		input_label_1_City.text = "0"
		input_label_2_City.text = "0"
		output_label_City.text = "0"
		return

	var city = cities[0]

	var base_food = city.inputs.get(Constants.RESOURCE_FOOD, 0)
	var food_modifier = game.get_modifier("city_food_input")
	var effective_food = game.get_modified_value(base_food, food_modifier, 1)

	var base_tools = city.inputs.get(Constants.RESOURCE_TOOLS, 0)
	var tools_modifier = game.get_modifier("city_tools_input")
	var effective_tools = game.get_modified_value(base_tools, tools_modifier, 1)

	var base_money = city.outputs.get(Constants.RESOURCE_MONEY, 0)
	var money_modifier = game.get_modifier("city_money_output")
	var effective_money = game.get_modified_value(base_money, money_modifier, 0)

	input_label_1_City.text = str(effective_food)
	input_label_2_City.text = str(effective_tools)
	output_label_City.text = str(effective_money)
