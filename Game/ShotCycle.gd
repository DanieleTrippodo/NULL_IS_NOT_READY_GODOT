# res://Game/ShotCycle.gd
extends Node

const SINGLE_SHOT: int = 0
const EXPAND_SHOT: int = 1
const LASER_SHOT: int = 2
const BOMB_SHOT: int = 3
const EMPTY_SLOT: int = -1

const SLOT_SEQUENCE: Array[int] = [
	SINGLE_SHOT,
	EMPTY_SLOT,
	EXPAND_SHOT,
	EMPTY_SLOT,
	LASER_SHOT,
	EMPTY_SLOT,
	BOMB_SHOT,
	EMPTY_SLOT,
]

@export_range(0.1, 10.0, 0.05) var slot_duration: float = 1.5

var _elapsed_slots: float = 0.0
var _active_shot_type: int = SINGLE_SHOT
var _last_crossed_slot: int = 0
var _last_ticks_msec: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_active_shot_type = SINGLE_SHOT
	_last_ticks_msec = Time.get_ticks_msec()
	Run.current_shot_type = _active_shot_type
	call_deferred("_emit_current_type")

func _process(_delta: float) -> void:
	if slot_duration <= 0.0:
		return

	var now_msec: int = Time.get_ticks_msec()
	if _last_ticks_msec <= 0:
		_last_ticks_msec = now_msec
		return

	var real_delta: float = float(now_msec - _last_ticks_msec) / 1000.0
	_last_ticks_msec = now_msec
	_elapsed_slots += maxf(real_delta, 0.0) / slot_duration
	var crossed_slot: int = int(floor(_elapsed_slots + 0.00001))

	if crossed_slot - _last_crossed_slot > SLOT_SEQUENCE.size() * 2:
		_last_crossed_slot = crossed_slot
		_activate_latest_type(crossed_slot)
		return

	while _last_crossed_slot < crossed_slot:
		_last_crossed_slot += 1
		_activate_slot(_last_crossed_slot)

func _activate_latest_type(absolute_slot: int) -> void:
	for offset in range(SLOT_SEQUENCE.size()):
		var slot_index: int = posmod(absolute_slot - offset, SLOT_SEQUENCE.size())
		var shot_type: int = SLOT_SEQUENCE[slot_index]
		if shot_type != EMPTY_SLOT:
			if shot_type != _active_shot_type:
				_active_shot_type = shot_type
				Run.current_shot_type = shot_type
				Signals.shot_type_changed.emit(shot_type)
			return

func _activate_slot(absolute_slot: int) -> void:
	var slot_index: int = posmod(absolute_slot, SLOT_SEQUENCE.size())
	var shot_type: int = SLOT_SEQUENCE[slot_index]
	if shot_type == EMPTY_SLOT:
		return
	if shot_type == _active_shot_type:
		return

	_active_shot_type = shot_type
	Run.current_shot_type = shot_type
	Signals.shot_type_changed.emit(shot_type)

func _emit_current_type() -> void:
	Run.current_shot_type = _active_shot_type
	Signals.shot_type_changed.emit(_active_shot_type)

func get_cycle_position() -> float:
	return fposmod(_elapsed_slots, float(SLOT_SEQUENCE.size()))

func get_active_shot_type() -> int:
	return _active_shot_type

func get_slot_duration() -> float:
	return slot_duration

func get_shot_name(shot_type: int) -> String:
	match shot_type:
		SINGLE_SHOT:
			return "SINGLESHOT"
		EXPAND_SHOT:
			return "EXPANDSHOT"
		LASER_SHOT:
			return "LASERSHOT"
		BOMB_SHOT:
			return "BOMBSHOT"
		_:
			return "UNKNOWN"
