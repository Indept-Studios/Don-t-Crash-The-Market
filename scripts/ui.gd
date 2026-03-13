extends CanvasLayer

@onready var food = $Panel/HBoxContainer/Food
@onready var tools = $Panel/HBoxContainer/Tools
@onready var money = $Panel/HBoxContainer/Money

signal building_chosen(building_type)

func _on_farm_pressed() -> void:
	building_chosen.emit(Constants.BUILDING_FARM)

func _on_city_pressed() -> void:
	building_chosen.emit(Constants.BUILDING_CITY)

func _on_factory_pressed() -> void:
	building_chosen.emit(Constants.BUILDING_FACTORY)

func update_resources(stock: Dictionary) -> void:
	food.text = "FOOD: %d" % stock[Constants.RESOURCE_FOOD]
	tools.text = "TOOLS: %d" % stock[Constants.RESOURCE_TOOLS]
	money.text = "MONEY: %d" % stock[Constants.RESOURCE_MONEY]
