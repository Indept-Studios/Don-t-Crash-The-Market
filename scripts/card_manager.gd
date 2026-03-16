extends Node
class_name CardManager

var card_pool:Array=[
{"id":"farm_output_up","title":"Better Seeds","description":"Farms produce +1 Food","effect":"farm_output","value":1,"duration":0},
{"id":"farm_output_temp","title":"Fertile Season","description":"Farms produce +2 Food for 5 ticks","effect":"farm_output","value":2,"duration":7},
{"id":"factory_output_up","title":"Improved Machinery","description":"Factories produce +1 Tool","effect":"factory_output","value":1,"duration":0},
{"id":"factory_output_temp","title":"Overdrive","description":"Factories produce +2 Tools for 4 ticks","effect":"factory_output","value":2,"duration":4},
{"id":"city_food_down","title":"Efficient Kitchens","description":"Cities need -1 Food","effect":"city_food_input","value":-1,"duration":0},
{"id":"city_food_temp","title":"Food Rationing","description":"Cities need -2 Food for 5 ticks","effect":"city_food_input","value":-2,"duration":5},
{"id":"city_tools_down","title":"Tool Recycling","description":"Cities need -1 Tool","effect":"city_tools_input","value":-1,"duration":0},
{"id":"city_tools_temp","title":"Emergency Repairs","description":"Cities need +2 Tools for 4 ticks","effect":"city_tools_input","value":2,"duration":4},
{"id":"food_bonus","title":"Food Delivery","description":"+20 Food immediately","effect":"add_food","value":20,"duration":0},
{"id":"tools_bonus","title":"Tool Shipment","description":"+10 Tools immediately","effect":"add_tools","value":10,"duration":0},
{"id":"farm_output_down","title":"Bad Weather","description":"Farms produce -1 Food","effect":"farm_output","value":-1,"duration":0},
{"id":"factory_output_down","title":"Machine Wear","description":"Factories produce -1 Tool","effect":"factory_output","value":-1,"duration":0},
{"id":"city_food_up","title":"Food Festival","description":"Cities need +1 Food","effect":"city_food_input","value":1,"duration":0},
{"id":"city_tools_up","title":"Industrial Demand","description":"Cities need +1 Tool","effect":"city_tools_input","value":1,"duration":0},
{"id":"farm_output_big_temp","title":"Golden Harvest","description":"Farms produce +3 Food for 3 ticks","effect":"farm_output","value":3,"duration":3},
{"id":"factory_output_big_temp","title":"Full Production","description":"Factories produce +3 Tools for 3 ticks","effect":"factory_output","value":3,"duration":3},
{"id":"food_crisis","title":"Food Crisis","description":"Cities need +2 Food for 5 ticks","effect":"city_food_input","value":2,"duration":6},
{"id":"tool_shortage","title":"Tool Shortage","description":"Cities need +2 Tools for 5 ticks","effect":"city_tools_input","value":2,"duration":5},
{"id":"food_relief","title":"Relief Supplies","description":"+40 Food immediately","effect":"add_food","value":40,"duration":0},
{"id":"tool_relief","title":"Industrial Aid","description":"+25 Tools immediately","effect":"add_tools","value":25,"duration":0},
{"id":"farm_building","title":"New Farmland","description":"Gain 1 additional Farm","effect":"add_building","value":Constants.BUILDING_FARM,"duration":0},
{"id":"factory_building","title":"New Workshop","description":"Gain 1 additional Factory","effect":"add_building","value":Constants.BUILDING_FACTORY,"duration":0},
{"id":"city_building","title":"New Settlement","description":"Gain 1 additional City","effect":"add_building","value":Constants.BUILDING_CITY,"duration":0},
]

var game
var current_cards: Array = []

func draw_cards(count:int=3) -> Array:
	var shuffled = card_pool.duplicate()
	shuffled.shuffle()
	current_cards = shuffled.slice(0,count)

	var city_count = game.buildings[Constants.BUILDING_CITY].size()
	var cost = 150 * city_count

	if game.stock[Constants.RESOURCE_FOOD] >= cost and game.stock[Constants.RESOURCE_TOOLS] >= cost:
		var buy_city_card = {
			"id":"buy_city",
			"title":"Buy City",
			"description":"Expand your settlement",
			"effect":"buy_city",
			"food_cost":cost,
			"tools_cost":cost,
			"duration":0
		}
		current_cards.append(buy_city_card)

	return current_cards

func apply_card(card:Dictionary,game) -> bool:
	var effect = card["effect"]
	match effect:
		"add_food":
			var value = card["value"]
			game.stock[Constants.RESOURCE_FOOD] += value
			game.resources_changed.emit()
			return true
		"add_tools":
			var value = card["value"]
			game.stock[Constants.RESOURCE_TOOLS] += value
			game.resources_changed.emit()
			return true
		"add_building":
			var value = card["value"]
			game.create_building(value)
			return true
		"buy_city":
			var food_cost = card["food_cost"]
			var tools_cost = card["tools_cost"]
			if game.stock[Constants.RESOURCE_FOOD] >= food_cost and game.stock[Constants.RESOURCE_TOOLS] >= tools_cost:
				game.stock[Constants.RESOURCE_FOOD] -= food_cost
				game.stock[Constants.RESOURCE_TOOLS] -= tools_cost
				game.create_building(Constants.BUILDING_CITY)
				game.resources_changed.emit()
				return true
			return false
		_:
			var value = card["value"]
			var duration = card["duration"]
			if duration > 0:
				game.temporary_effects.append({"effect":effect,"value":value,"remaining_ticks":duration})
			else:
				game.modifiers[effect] += value
			return true
