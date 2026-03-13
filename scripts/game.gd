extends Node

signal tick_started(tick_number: int)
signal tick_finished(tick_number: int)

var tick_count: int = 0
var is_running: bool = false
var is_paused: bool = false

var tick_timer: Timer

func _ready() -> void:
	setup_tick_timer()
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
	process_consumption()
	update_market_prices()
	check_collapse_state()
	tick_finished.emit(tick_count)
	if Constants.DEBUGFLAG:
		print("")
		print("Tick %d" % tick_count)

func process_production() -> void:
	produce_from_farms()
	produce_from_factories()
	produce_from_cities()

func produce_from_farms() -> void:
	pass

func produce_from_factories() -> void:
	pass
	
func produce_from_cities() -> void:
	pass

func process_transport() -> void:
	pass

func process_consumption() -> void:
	pass

func update_market_prices() -> void:
	pass

func check_collapse_state() -> void:
	pass
