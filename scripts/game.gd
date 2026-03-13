extends Node

signal ressources_changed()

var building_scene = preload("res://scenes/building.tscn")

var stock = {
	Constants.RESOURCE_FOOD: 0,
	Constants.RESOURCE_TOOLS: 0,
	Constants.RESOURCE_MONEY: 0
}

var buildings = {}
var next_building_id := 1
var first_card_popup_shown := false

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

	tick_count += 1
	process_production()

	if tick_count % Constants.CARD_POPUP_INTERVAL == 0:
		pause_game()
		$UI/CardPopup.show()
		return

	tick_started.emit(tick_count)
	process_transport()
	update_market_prices()
	check_collapse_state()
	tick_finished.emit(tick_count)

	if Constants.DEBUGFLAG:
		print("")
		print("Tick %d" % tick_count)
		print_stock()
#endregion

#region gameState
func start_game() -> void:
	tick_count = 0
	is_running = true
	is_paused = false
	tick_timer.start()
	
func setup_start_condition() -> void:
	create_building(Constants.BUILDING_BANK)
	create_building(Constants.BUILDING_CITY)
	create_building(Constants.BUILDING_FARM)
	create_building(Constants.BUILDING_FARM)
	create_building(Constants.BUILDING_FACTORY)
	create_building(Constants.BUILDING_FACTORY)
	stock[Constants.RESOURCE_FOOD] = 25
	stock[Constants.RESOURCE_TOOLS] = 25
	
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
#endregion

func _ready() -> void:
	$UI/CardPopup.hide()
	setup_tick_timer()
	setup_start_condition()
	start_game()
	$UI.building_chosen.connect(_on_building_chosen)
	ressources_changed.connect(_on_ressources_changed)
	_on_ressources_changed()

func _on_ressources_changed() -> void:
	$UI.update_resources(stock)
	
func _on_building_chosen(type: String) -> void:
	create_building(type)
	$UI/CardPopup.hide()
	resume_game()

func process_production() -> void:
	buildings = {
		Constants.BUILDING_FARM: $Buildings/Farms/Instanzen.get_children(),
		Constants.BUILDING_FACTORY: $Buildings/Factories/Instanzen.get_children(),
		Constants.BUILDING_CITY: $Buildings/Cities/Instanzen.get_children()
	}
	process_farms()
	process_factories()
	process_cities()

func normalize_efficiency_to_one(building) -> void:
	if building.efficiency < 1.0:
		building.efficiency += Constants.EFFICIENCY_RECOVERY_PER_TICK
		if building.efficiency > 1.0:
			building.efficiency = 1.0
	elif building.efficiency > 1.0:
		building.efficiency -= Constants.EFFICIENCY_LOSS_PER_TICK
		if building.efficiency < 1.0:
			building.efficiency = 1.0

func process_farms() -> void:
	var FOOD = Constants.RESOURCE_FOOD
	for building in buildings[Constants.BUILDING_FARM]:
		building.is_active = true
		normalize_efficiency_to_one(building)
		building.production_progress += building.outputs[FOOD] * building.efficiency
		while building.production_progress >= 1.0:
			add_resources(FOOD, 1)
			building.production_progress -= 1.0

func process_factories() -> void:
	var FOOD = Constants.RESOURCE_FOOD
	var TOOLS = Constants.RESOURCE_TOOLS
	for building in buildings[Constants.BUILDING_FACTORY]:
		if consume_resource(FOOD, building.inputs[FOOD]):
			building.is_active = true
			normalize_efficiency_to_one(building)
			building.production_progress += building.outputs[TOOLS] * building.efficiency
		else:
			building.is_active = false
			if building.efficiency > 0.0:
				building.efficiency -= Constants.EFFICIENCY_LOSS_PER_TICK
				if building.efficiency < 0.0:
					building.efficiency = 0.0
		while building.production_progress >= 1.0:
			add_resources(TOOLS, 1)
			building.production_progress -= 1.0

func process_cities() -> void:
	var FOOD = Constants.RESOURCE_FOOD
	var TOOLS = Constants.RESOURCE_TOOLS
	var MONEY = Constants.RESOURCE_MONEY
	for building in buildings[Constants.BUILDING_CITY]:
		if stock[FOOD] >= building.inputs[FOOD] and stock[TOOLS] >= building.inputs[TOOLS]:
			consume_resource(FOOD, building.inputs[FOOD])
			consume_resource(TOOLS, building.inputs[TOOLS])
			add_resources(MONEY, building.outputs[MONEY])
			building.is_active = true
		else:
			building.is_active = false

func process_transport() -> void:
	pass

func update_market_prices() -> void:
	pass

func check_collapse_state() -> void:
	pass

#region Building Factory
func create_building(type: String) -> void:
	match type:
		Constants.BUILDING_FARM:
			create_farm(next_building_id)
		Constants.BUILDING_FACTORY:
			create_factory(next_building_id)
		Constants.BUILDING_CITY:
			create_city(next_building_id)
		Constants.BUILDING_BANK:
			create_bank(next_building_id)
	next_building_id+=1

func create_farm(id: int) -> void:
	var parent_node = $Buildings/Farms/Instanzen
	var building = building_scene.instantiate()
	building.id = id
	building.building_type = Constants.BUILDING_FARM
	building.inputs = {
		Constants.RESOURCE_TOOLS: Constants.FARM_TOOLS_INPUT
	}
	building.outputs = {
		Constants.RESOURCE_FOOD: Constants.FARM_FOOD_OUTPUT
	}
	building.name = "Farm_%d" % parent_node.get_child_count()
	parent_node.add_child(building)

	if Constants.DEBUGFLAG:
		print("FARM added")

func create_factory(id: int) -> void:
	var parent_node = $Buildings/Factories/Instanzen
	var building = building_scene.instantiate()
	building.id = id
	building.building_type = Constants.BUILDING_FACTORY
	building.inputs = {
		Constants.RESOURCE_FOOD: Constants.FACTORY_FOOD_INPUT
	}
	building.outputs = {
		Constants.RESOURCE_TOOLS: Constants.FACTORY_TOOLS_OUTPUT
	}
	building.name = "Factory_%d" % parent_node.get_child_count()
	parent_node.add_child(building)

	if Constants.DEBUGFLAG:
		print("FACTORY added")

func create_city(id: int) -> void:
	var parent_node = $Buildings/Cities/Instanzen
	var building = building_scene.instantiate()
	building.id = id
	building.building_type = Constants.BUILDING_CITY
	building.inputs = {
		Constants.RESOURCE_FOOD: Constants.CITY_FOOD_INPUT,
		Constants.RESOURCE_TOOLS: Constants.CITY_TOOLS_INPUT
	}
	building.outputs = {
		Constants.RESOURCE_MONEY: Constants.CITY_MONEY_OUTPUT
	}
	building.name = "City_%d" % parent_node.get_child_count()
	parent_node.add_child(building)

	if Constants.DEBUGFLAG:
		print("CITY added")

func create_bank(id: int) -> void:
	var parent_node = $Buildings/Bank/Instanzen
	var building = building_scene.instantiate()
	building.id = id
	building.building_type = Constants.BUILDING_BANK
	building.inputs = {
		#ADD Inputs to Bank
	}
	building.outputs = {
		#ADD Output to Bank
	}
	building.name = "Bank_%d" % parent_node.get_child_count()
	parent_node.add_child(building)

	if Constants.DEBUGFLAG:
		print("BANK added")
#endregion

func add_resources(type: String, amount: float) -> void:
	stock[type] += amount
	ressources_changed.emit()

func consume_resource(type: String, amount: float) -> bool:
	if stock[type] >= amount:
		stock[type] -= amount
		ressources_changed.emit()
		return true
	return false
