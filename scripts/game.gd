extends Node

signal resources_changed()
signal buildings_changed()

@onready var card_manager = $Card_Manager
@export var highscore_manager: Node

var building_scene = preload("res://scenes/building.tscn")

var stock = {
	Constants.RESOURCE_FOOD: 0,
	Constants.RESOURCE_TOOLS: 0,
	Constants.RESOURCE_MONEY: 0
}

var modifiers = {
	"farm_output": 0,
	"factory_output": 0,
	"city_food_input": 0,
	"city_tools_input": 0,
	"city_money_output": 0
}
var temporary_effects:Array=[]

var buildings := {
	Constants.BUILDING_FARM: [],
	Constants.BUILDING_FACTORY: [],
	Constants.BUILDING_CITY: [],
	Constants.BUILDING_BANK: []
}
var next_building_id := 1
var has_won: bool = false

#region tick
signal tick_started(tick_number: int)
signal tick_finished(tick_number: int)
var tick_count: int = 0
var is_running: bool = false
var is_paused: bool = false
var tick_timer: Timer

func setup_tick_timer() -> void:
	tick_timer = Timer.new()
	tick_timer.wait_time = Constants.TICK_INTERVAL
	tick_timer.one_shot = false
	tick_timer.autostart = false
	add_child(tick_timer)
	tick_timer.timeout.connect(_on_tick_timer_timeout)
	
func _on_tick_timer_timeout() -> void:
	run_tick()

func run_tick() -> void:
	if not is_running:
		return
	if is_paused:
		return
	if has_won:
		return
	tick_count += 1
	process_production()
	if has_won:
		return
	if Constants.DEBUGFLAG:
		print("")
		print("Tick %d" % tick_count)
		print_stock()
	if tick_count % Constants.CARD_POPUP_INTERVAL == 0:
		pause_game()
		var cards = card_manager.draw_cards()
		$UI.show_cards(cards)
		$UI/CardPopup.show()
		return
	tick_started.emit(tick_count)
	process_transport()
	update_temporary_effects()
	tick_finished.emit(tick_count)
#endregion

#region gameState
func start_game() -> void:
	reset_game_state()
	setup_start_condition()
	is_running = true
	is_paused = false
	tick_timer.start()
	
func setup_start_condition() -> void:
	create_building(Constants.BUILDING_BANK)
	create_building(Constants.BUILDING_CITY)
	create_building(Constants.BUILDING_FARM)
	create_building(Constants.BUILDING_FARM)
	create_building(Constants.BUILDING_FACTORY)
	
	stock[Constants.RESOURCE_FOOD] = 25
	stock[Constants.RESOURCE_TOOLS] = 25
	stock[Constants.RESOURCE_MONEY] = 0
	
	refresh_buildings()
	resources_changed.emit()
	
func stop_game() -> void:
	is_running = false
	tick_timer.stop()

func pause_game() -> void:
	if not is_running:
		return
	if is_paused:
		return
	is_paused = true
	tick_timer.stop()

func resume_game() -> void:
	if not is_running:
		return
	if not is_paused:
		return
	is_paused = false
	tick_timer.start()
	
func print_stock() -> void:
	print("Stock | Food: ", stock[Constants.RESOURCE_FOOD], " | Tools: ", stock[Constants.RESOURCE_TOOLS], " | Money: ", stock[Constants.RESOURCE_MONEY])
	
func reset_game_state() -> void:
	stop_game()

	has_won = false
	tick_count = 0
	is_paused = false
	is_running = false
	next_building_id = 1

	stock = {
		Constants.RESOURCE_FOOD: 0,
		Constants.RESOURCE_TOOLS: 0,
		Constants.RESOURCE_MONEY: 0
	}
	
	for child in $Buildings/Farms/Instanzen.get_children():
		child.queue_free()
	for child in $Buildings/Factories/Instanzen.get_children():
		child.queue_free()
	for child in $Buildings/Cities/Instanzen.get_children():
		child.queue_free()
	for child in $Buildings/Bank/Instanzen.get_children():
		child.queue_free()

	buildings = {
		Constants.BUILDING_FARM: [],
		Constants.BUILDING_FACTORY: [],
		Constants.BUILDING_CITY: [],
		Constants.BUILDING_BANK: []
	}
	
	resources_changed.emit()
	buildings_changed.emit()
#endregion

func _ready() -> void:
	card_manager.game = self
	$UI/CardPopup.hide()
	setup_tick_timer()
	$UI.card_selected.connect(card_selected)
	resources_changed.connect(_on_resources_changed)
	buildings_changed.connect(_on_buildings_changed)
	start_game()
	_on_resources_changed()
	_on_buildings_changed()

func _on_resources_changed() -> void:
	$UI.update_resources(stock)
	
func _on_buildings_changed() -> void:
	$UI.update_buildings(buildings)

func refresh_buildings() -> void:
	buildings = {
		Constants.BUILDING_FARM: $Buildings/Farms/Instanzen.get_children(),
		Constants.BUILDING_FACTORY: $Buildings/Factories/Instanzen.get_children(),
		Constants.BUILDING_CITY: $Buildings/Cities/Instanzen.get_children(),
		Constants.BUILDING_BANK: $Buildings/Bank/Instanzen.get_children()
	}
	buildings_changed.emit()
	
func card_selected(card:Dictionary) -> void:
	var success = card_manager.apply_card(card,self)
	if not success:
		return
	$UI/CardPopup.hide()
	resume_game()

func process_production() -> void:
	refresh_buildings()
	process_farms()
	process_factories()
	process_cities()
	process_banks()

func normalize_efficiency_to_one(building) -> void:
	if building.efficiency < 1.0:
		building.efficiency += Constants.EFFICIENCY_RECOVERY_PER_TICK
		if building.efficiency > 1.0:
			building.efficiency = 1.0
	elif building.efficiency > 1.0:
		building.efficiency -= Constants.EFFICIENCY_LOSS_PER_TICK
		if building.efficiency < 1.0:
			building.efficiency = 1.0

func move_efficiency_toward(building, target: float) -> void:
	if building.efficiency < target:
		building.efficiency += Constants.EFFICIENCY_RECOVERY_PER_TICK
		if building.efficiency > target:
			building.efficiency = target
	elif building.efficiency > target:
		building.efficiency -= Constants.EFFICIENCY_LOSS_PER_TICK
		if building.efficiency < target:
			building.efficiency = target
	if building.efficiency < 0.0:
		building.efficiency = 0.0

func get_modified_value(base_value:int, modifier_value:int, min_value:int=0) -> int:
	return max(min_value, base_value + modifier_value)

func update_temporary_effects() -> void:
	for i in range(temporary_effects.size()-1,-1,-1):
		temporary_effects[i]["remaining_ticks"] -= 1
		if temporary_effects[i]["remaining_ticks"] <= 0:
			temporary_effects.remove_at(i)

func get_temporary_modifier(effect_name:String) -> int:
	var total = 0
	for effect in temporary_effects:
		if effect["effect"] == effect_name:
			total += effect["value"]
	return total

func get_modifier(effect_name:String) -> int:
	return modifiers.get(effect_name,0)+get_temporary_modifier(effect_name)

func debug_production(building, base_value, modifier, effective_value) -> void:
	if not Constants.DEBUGFLAG:
		return
	print(
		building.name,
		" | base:", base_value,
		" mod:", modifier,
		" eff:", effective_value,
		" effc:", building.efficiency,
		" prog:", building.production_progress
	)

func process_farms() -> void:
	var FOOD = Constants.RESOURCE_FOOD
	for building in buildings.get(Constants.BUILDING_FARM,[]):
		building.is_active = true
		normalize_efficiency_to_one(building)
		var modifier = get_modifier("farm_output")
		var effective_output = get_modified_value(Constants.FARM_FOOD_OUTPUT,modifier,0)
		building.production_progress += effective_output*building.efficiency
		debug_production(building,Constants.FARM_FOOD_OUTPUT,modifier,effective_output)
		while building.production_progress >= 1.0:
			add_resources(FOOD,1)
			building.production_progress -= 1.0

func process_factories() -> void:
	var FOOD = Constants.RESOURCE_FOOD
	var TOOLS = Constants.RESOURCE_TOOLS

	for building in buildings.get(Constants.BUILDING_FACTORY, []):
		var base_input = building.inputs.get(FOOD, Constants.FACTORY_FOOD_INPUT)
		var modifier = get_modifier("factory_food_input")
		var food_input = max(1, base_input + modifier)

		var output_modifier = get_modifier("factory_output")
		var base_output = building.outputs.get(TOOLS, Constants.FACTORY_TOOLS_OUTPUT)
		var tools_output = get_modified_value(base_output, output_modifier, 0)

		if consume_resource(FOOD, food_input):
			building.is_active = true
			normalize_efficiency_to_one(building)
			building.production_progress += tools_output * building.efficiency
		else:
			building.is_active = false
			if building.efficiency > 0.0:
				building.efficiency -= Constants.EFFICIENCY_LOSS_PER_TICK
				if building.efficiency < 0.0:
					building.efficiency = 0.0

		debug_production(building, base_output, output_modifier, tools_output)

		while building.production_progress >= 1.0:
			add_resources(TOOLS, 1)
			building.production_progress -= 1.0

func process_cities() -> void:
	var FOOD = Constants.RESOURCE_FOOD
	var TOOLS = Constants.RESOURCE_TOOLS
	var MONEY = Constants.RESOURCE_MONEY

	for building in buildings.get(Constants.BUILDING_CITY, []):
		var base_food = building.inputs.get(FOOD, Constants.CITY_FOOD_INPUT)
		var base_tools = building.inputs.get(TOOLS, Constants.CITY_TOOLS_INPUT)

		var food_modifier = get_modifier("city_food_input")
		var tools_modifier = get_modifier("city_tools_input")
		var money_modifier = get_modifier("city_money_output")

		var food_input = max(1, base_food + food_modifier)
		var tools_input = max(1, base_tools + tools_modifier)

		var base_money = building.outputs.get(MONEY, Constants.CITY_MONEY_OUTPUT)
		var money_output = get_modified_value(base_money, money_modifier, 0)

		var has_food = stock[FOOD] >= food_input
		var has_tools = stock[TOOLS] >= tools_input

		var supplied_resources = 0
		if has_food:
			consume_resource(FOOD, food_input)
			supplied_resources += 1
		if has_tools:
			consume_resource(TOOLS, tools_input)
			supplied_resources += 1

		var target_efficiency = 0.0
		if supplied_resources == 2:
			target_efficiency = 1.0
			building.is_active = true
		elif supplied_resources == 1:
			target_efficiency = 0.5
			building.is_active = true
		else:
			target_efficiency = 0.0
			building.is_active = false

		move_efficiency_toward(building, target_efficiency)
		building.production_progress += building.efficiency

		debug_production(building, base_money, money_modifier, money_output)

		while building.production_progress >= 1.0:
			add_resources(MONEY, money_output)
			building.production_progress -= 1.0

func process_banks() -> void:
	if has_won:
		return
	if stock[Constants.RESOURCE_MONEY] >= Constants.BANK_GOAL:
		handle_victory()

func handle_victory() -> void:
	has_won = true
	stop_game()
	var run_time = get_run_time_seconds()
	HighscoreManager.add_highscore(run_time)
	if Constants.DEBUGFLAG:
		print("Victory in ",format_time(run_time))
	get_tree().change_scene_to_file("res://scenes/highscore.tscn")

func format_time(seconds: float) -> String:
	var total_seconds = int(seconds)
	var minutes = total_seconds / 60
	var secs = total_seconds % 60
	return "%02d:%02d" % [minutes, secs]

func get_run_time_seconds() -> float:
	return tick_count * Constants.TICK_INTERVAL

func process_transport() -> void:
	pass

func remove_building_by_type(building_type) -> bool:
	if not buildings.has(building_type):
		return false

	var list = buildings[building_type]
	if list.is_empty():
		return false

	var building = list.pop_back()
	if is_instance_valid(building):
		building.queue_free()

	refresh_buildings()
	return true
	
#region Building Factory
func create_building(building_type) -> Node:
	var building = building_scene.instantiate()

	building.building_id = next_building_id
	building.building_type = building_type
	building.inputs = {}
	building.outputs = {}
	building.efficiency = 1.0
	building.production_progress = 0.0
	building.is_active = true
	building.modifiers = {}
	building.temporary_effects = []
	building.name = "%s_%d" % [str(building_type).capitalize(), next_building_id]

	next_building_id += 1

	match building_type:
		Constants.BUILDING_FARM:
			building.inputs = {
				Constants.RESOURCE_TOOLS: Constants.FARM_TOOLS_INPUT
			}
			building.outputs = {
				Constants.RESOURCE_FOOD: Constants.FARM_FOOD_OUTPUT
			}
			$Buildings/Farms/Instanzen.add_child(building)

		Constants.BUILDING_FACTORY:
			building.inputs = {
				Constants.RESOURCE_FOOD: Constants.FACTORY_FOOD_INPUT
			}
			building.outputs = {
				Constants.RESOURCE_TOOLS: Constants.FACTORY_TOOLS_OUTPUT
			}
			$Buildings/Factories/Instanzen.add_child(building)

		Constants.BUILDING_CITY:
			building.inputs = {
				Constants.RESOURCE_FOOD: Constants.CITY_FOOD_INPUT,
				Constants.RESOURCE_TOOLS: Constants.CITY_TOOLS_INPUT
			}
			building.outputs = {
				Constants.RESOURCE_MONEY: Constants.CITY_MONEY_OUTPUT
			}
			$Buildings/Cities/Instanzen.add_child(building)

		Constants.BUILDING_BANK:
			building.inputs = {}
			building.outputs = {}
			$Buildings/Bank/Instanzen.add_child(building)

		_:
			building.queue_free()
			return null

	if Constants.DEBUGFLAG:
		print("%s added" % str(building_type).to_upper())

	refresh_buildings()
	return building
#endregion

func add_resources(type: String, amount: float) -> void:
	stock[type] += amount
	resources_changed.emit()

func consume_resource(type: String, amount: float) -> bool:
	if stock[type] >= amount:
		stock[type] -= amount
		resources_changed.emit()
		return true
	return false
