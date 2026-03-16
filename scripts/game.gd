extends Node

signal resources_changed()

@export var card_manager = Node

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

var buildings = {}
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
	process_banks()
	if has_won:
		return
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
	update_temporary_effects()
	tick_finished.emit(tick_count)

	if tick_count % Constants.CARD_POPUP_INTERVAL == 0:
		pause_game()
		var cards = card_manager.draw_cards()
		$UI.show_cards(cards)
		$UI/CardPopup.show()
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
	if file == null:
		return []
	var content = file.get_as_text()
	file.close()

	var data = JSON.parse_string(content)
	if data == null or typeof(data) != TYPE_DICTIONARY:
		return []
	if not data.has("best_times") or typeof(data["best_times"]) != TYPE_ARRAY:
		return []
	var result: Array = []
	for entry in data["best_times"]:
		if typeof(entry) == TYPE_DICTIONARY and entry.has("ticks") and entry.has("date"):
			result.append(entry)
	return result
	
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
	highscores.sort_custom(func(a, b): return a["ticks"] < b["ticks"])
	if highscores.size() > Constants.MAX_HIGHSCORES:
		highscores.resize(Constants.MAX_HIGHSCORES)
	save_highscores(highscores)
	
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
	buildings = {}
	for child in $Buildings/Farms/Instanzen.get_children():
		child.queue_free()
	for child in $Buildings/Factories/Instanzen.get_children():
		child.queue_free()
	for child in $Buildings/Cities/Instanzen.get_children():
		child.queue_free()
	for child in $Buildings/Bank/Instanzen.get_children():
		child.queue_free()

	resources_changed.emit()
#endregion

func _ready() -> void:
	card_manager.game = self
	$UI/CardPopup.hide()
	setup_tick_timer()
	setup_start_condition()
	start_game()
	$UI.card_selected.connect(card_selected)
	resources_changed.connect(_on_resources_changed)
	_on_resources_changed()

func _on_resources_changed() -> void:
	$UI.update_resources(stock)
	

func card_selected(card:Dictionary) -> void:
	var success = card_manager.apply_card(card,self)
	if not success:
		return
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

func process_farms() -> void:
	var FOOD = Constants.RESOURCE_FOOD
	for building in buildings[Constants.BUILDING_FARM]:
		building.is_active = true
		normalize_efficiency_to_one(building)
		var modifier = get_modifier("farm_output")
		var effective_output = get_modified_value(Constants.FARM_FOOD_OUTPUT,modifier,0)
		building.production_progress += effective_output*building.efficiency
		if Constants.DEBUGFLAG:
			print(building.production_progress)
		while building.production_progress >= 1.0:
			add_resources(FOOD,1)
			building.production_progress -= 1.0

func process_factories() -> void:
	var FOOD = Constants.RESOURCE_FOOD
	var TOOLS = Constants.RESOURCE_TOOLS
	for building in buildings[Constants.BUILDING_FACTORY]:
		var base_input = building.inputs[FOOD]
		var modifier = get_modifier("factory_food_input")
		var food_input = max(1,base_input+modifier)
		var tools_output = get_modified_value(building.outputs[TOOLS],get_modifier("factory_output"),0)
		if consume_resource(FOOD,food_input):
			building.is_active = true
			normalize_efficiency_to_one(building)
			building.production_progress += tools_output*building.efficiency
		else:
			building.is_active = false
			if building.efficiency > 0.0:
				building.efficiency -= Constants.EFFICIENCY_LOSS_PER_TICK
				if building.efficiency < 0.0:
					building.efficiency = 0.0
		if Constants.DEBUGFLAG:
			print(building.production_progress)
		while building.production_progress >= 1.0:
			add_resources(TOOLS,1)
			building.production_progress -= 1.0

func process_cities() -> void:
	var FOOD = Constants.RESOURCE_FOOD
	var TOOLS = Constants.RESOURCE_TOOLS
	var MONEY = Constants.RESOURCE_MONEY
	for building in buildings[Constants.BUILDING_CITY]:
		var base_food = building.inputs[FOOD]
		var base_tools = building.inputs[TOOLS]
		
		var food_modifier = get_modifier("city_food_input")
		var tools_modifier = get_modifier("city_tools_input")
		
		var food_input = max(1,base_food+food_modifier)
		var tools_input = max(1,base_tools+tools_modifier)
		
		var money_output = get_modified_value(building.outputs[MONEY],get_modifier("city_money_output"),0)
		var has_food = stock[FOOD] >= food_input
		var has_tools = stock[TOOLS] >= tools_input
		var supplied_resources = 0
		if has_food:
			consume_resource(FOOD,food_input)
			supplied_resources += 1
		if has_tools:
			consume_resource(TOOLS,tools_input)
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
		move_efficiency_toward(building,target_efficiency)
		building.production_progress += building.efficiency
		while building.production_progress >= 1.0:
			add_resources(MONEY,money_output)
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
	add_highscore(run_time)
	print("Victory in ", format_time(run_time))

func format_time(seconds: float) -> String:
	var total_seconds = int(seconds)
	var minutes = total_seconds / 60
	var secs = total_seconds % 60
	return "%02d:%02d" % [minutes, secs]

func get_run_time_seconds() -> float:
	return tick_count * Constants.TICK_INTERVAL

func process_transport() -> void:
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
	parent_node.add_child(building)
	building.name = "Farm_" + str(id)

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
	parent_node.add_child(building)
	building.name = "Factory_" + str(id)

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
	parent_node.add_child(building)
	building.name = "City_" + str(id)

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
	resources_changed.emit()

func consume_resource(type: String, amount: float) -> bool:
	if stock[type] >= amount:
		stock[type] -= amount
		resources_changed.emit()
		return true
	return false
