extends Node

var building_scene = preload("res://scenes/building.tscn")

var stock = {}
var buildings = {}
var next_building_id := 1


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
	tick_started.emit(tick_count)
	process_production()
	process_transport()
	update_market_prices()
	check_collapse_state()
	tick_finished.emit(tick_count)
	if Constants.DEBUGFLAG:
		print("")
		print("Tick %d" % tick_count)
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
#endregion

func _ready() -> void:
	setup_tick_timer()
	setup_start_condition()
	start_game()

func process_production() -> void:
	pass

func process_transport() -> void:
	pass

func update_market_prices() -> void:
	pass

func check_collapse_state() -> void:
	pass

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
	var parent_node = $Buildings/Farms
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
	var parent_node = $Buildings/Factories
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
	var parent_node = $Buildings/Cities
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
	var parent_node = $Buildings/Bank
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


func add_resources() -> void:
	pass

func consume_resource() -> void:
	pass
