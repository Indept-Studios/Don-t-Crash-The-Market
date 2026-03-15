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
var has_won: bool = false
var highscores: Array = []

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
	if Constants.DEBUGFLAG:
		print("")
		print("Tick %d" % tick_count)
		print_stock()
	if tick_count % Constants.CARD_POPUP_INTERVAL == 0:
		pause_game()
		$UI/CardPopup.show()
		return

	tick_started.emit(tick_count)
	process_transport()
	update_market_prices()
	check_collapse_state()
	check_win_condition()
	tick_finished.emit(tick_count)

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
	
func load_highscores() -> Array:
	if not FileAccess.file_exists(Constants.HIGHSCORE_PATH):
		return []
	var file = FileAccess.open(Constants.HIGHSCORE_PATH, FileAccess.READ)
	var content = file.get_as_text()
	file.close()
	var data = JSON.parse_string(content)
	if data == null:
		return []
	if not data.has("best_times"):
		return []
	return data["best_times"]
	
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
	highscores.sort_custom(func(a, b): return a["tick_count"] < b["tick_count"])
	if highscores.size() > 10:
		highscores.resize(10)
	save_highscores(highscores)
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

func process_farms() -> void:
	var FOOD = Constants.RESOURCE_FOOD
	for building in buildings[Constants.BUILDING_FARM]:
		building.is_active = true
		normalize_efficiency_to_one(building)
		building.production_progress += building.outputs[FOOD] * building.efficiency
		if Constants.DEBUGFLAG:
			print(building.production_progress)
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
		if Constants.DEBUGFLAG:
			print(building.production_progress)
		while building.production_progress >= 1.0:
			add_resources(TOOLS, 1)
			building.production_progress -= 1.0

func process_cities() -> void:
	var FOOD = Constants.RESOURCE_FOOD
	var TOOLS = Constants.RESOURCE_TOOLS
	var MONEY = Constants.RESOURCE_MONEY
	for building in buildings[Constants.BUILDING_CITY]:
		var has_food = stock[FOOD] >= building.inputs[FOOD]
		var has_tools = stock[TOOLS] >= building.inputs[TOOLS]
		var supplied_resources = 0
		if has_food:
			consume_resource(FOOD, building.inputs[FOOD])
			supplied_resources += 1
		if has_tools:
			consume_resource(TOOLS, building.inputs[TOOLS])
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
		while building.production_progress >= 1.0:
			add_resources(MONEY, building.outputs[MONEY])
			building.production_progress -= 1.0

func process_banks() -> void:
	if stock[Constants.RESOURCE_MONEY] == 0:
		return
	check_victory_state()

func check_victory_state() -> void:
	if has_won:
		return
	if stock[Constants.RESOURCE_MONEY] >= Constants.BANK_GOAL:
		handle_victory()

func handle_victory() -> void:
	has_won = true
	stop_game()
	var run_time = get_run_time_seconds()
	add_highscore(run_time)
	print("Victory in ", format_time(run_time))
	print_highscores()

func format_time(seconds: float) -> String:
	var total_seconds = int(seconds)
	var minutes = total_seconds / 60
	var secs = total_seconds % 60
	return "%02d:%02d" % [minutes, secs]

func print_highscores() -> void:
	print("=== HIGHSCORES ===")
	for i in range(highscores.size()):
		var entry = highscores[i]
		print(str(i + 1), ". ", format_time(entry["time_seconds"]), " | ", entry["date"])

func get_run_time_seconds() -> float:
	return tick_count * Constants.TICK_INTERVAL

func process_transport() -> void:
	pass

func update_market_prices() -> void:
	pass

func check_collapse_state() -> void:
	pass

func check_win_condition() -> void:
	if stock[Constants.RESOURCE_MONEY] >= 2000:
		add_highscore(tick_count)
	
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
