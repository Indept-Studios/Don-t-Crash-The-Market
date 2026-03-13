extends Node

var stock = {
	Constants.RESOURCE_FOOD: 0,
	Constants.RESOURCE_TOOLS: 0,
	Constants.RESOURCE_MONEY: 0
}
var buildings = {
	Constants.BUILDING_FARM: 2,
	Constants.BUILDING_FACTORY: 2,
	Constants.BUILDING_CITY: 1,
	Constants.BUILDING_BANK: 1
}

#region tick
signal tick_started(tick_number: int)
signal tick_finished(tick_number: int)
var tick_count: int = 0
var is_running: bool = false
var is_paused: bool = false
var tick_timer: Timer
#endregion

func _ready() -> void:
	setup_tick_timer()
	if Constants.DEBUGFLAG:
		stock[Constants.RESOURCE_FOOD] = 5
		stock[Constants.RESOURCE_TOOLS] = 5
		
	start_game()

func setup_tick_timer() -> void:
	tick_timer = Timer.new()
	tick_timer.wait_time = Constants.TICK_INTERVAL
	tick_timer.one_shot = false
	tick_timer.autostart = false
	add_child(tick_timer)
	tick_timer.timeout.connect(_on_tick_timer_timeout)

func start_game() -> void:
	tick_count = 0
	is_running = true
	is_paused = false
	tick_timer.start()
	

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
		print(stock)

func process_production() -> void:
	produce_from_farms()
	produce_from_factories()
	produce_from_cities()

func produce_from_farms() -> void:
	if stock[Constants.RESOURCE_TOOLS] >= buildings[Constants.BUILDING_FARM] * Constants.FARM_TOOLS_INPUT :
		for i in range(buildings[Constants.BUILDING_FARM]):
			consume_resource(Constants.RESOURCE_TOOLS,Constants.FARM_TOOLS_INPUT)
			add_resources(Constants.RESOURCE_FOOD,Constants.FARM_FOOD_OUTPUT)

func produce_from_factories() -> void:
	if stock[Constants.RESOURCE_FOOD] >= buildings[Constants.BUILDING_FACTORY] * Constants.FACTORY_FOOD_INPUT :
		for i in range(buildings[Constants.BUILDING_FACTORY]):
			consume_resource(Constants.RESOURCE_FOOD, Constants.FACTORY_FOOD_INPUT)
			add_resources(Constants.RESOURCE_TOOLS,Constants.FACTORY_TOOLS_OUTPUT)
	
func produce_from_cities() -> void:
	var enough_food = stock[Constants.RESOURCE_FOOD] >= buildings[Constants.BUILDING_CITY] * Constants.CITY_FOOD_INPUT
	var enough_tools = stock[Constants.RESOURCE_TOOLS] >= buildings[Constants.BUILDING_CITY] * Constants.CITY_TOOLS_INPUT
	if enough_food and enough_tools:
		for i in range(buildings[Constants.BUILDING_CITY]):
			consume_resource(Constants.RESOURCE_FOOD, Constants.CITY_FOOD_INPUT)
			consume_resource(Constants.RESOURCE_TOOLS, Constants.CITY_TOOLS_INPUT)
			add_resources(Constants.RESOURCE_MONEY,Constants.CITY_MONEY_OUTPUT)

func process_transport() -> void:
	pass

func update_market_prices() -> void:
	pass

func check_collapse_state() -> void:
	pass

func add_resources(type: String, amount: float) -> void:
	if stock.has(type):
		var a = stock[type]
		stock[type] = a + amount
	else:
		print(type + " not found")

func consume_resource(type: String, amount: float) -> void:
	if stock.has(type):
		var a = stock[type]
		if a >= amount:
			stock[type] = a - amount
		else:
			print("not enough ressources " + type) # Change to effizience for each building
	else:
		print(type +" not found")
