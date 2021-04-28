extends Node2D

const VERTICAL_LABEL_INPUT: Resource = preload("res://screens/ui-elements/VerticalLabelInput.tscn")

const INPUT_TYPE_RAW: String = "Raw"
const INPUT_TYPE_STRUCTURED: String = "Structured"

const INPUT_HISTORY_MAX: int = 100

# Sqlite options
const SQLITE = preload("res://addons/godot-sqlite/bin/gdsqlite.gdns")
const DB_NAME: String = "potato"
const CMS_TABLE_NAME: String = "cms"
const CREATE_CMS_TABLE: String = """
CREATE TABLE cms (
	key TEXT NOT NULL,
	lang TEXT NOT NULL,
	value TEXT NOT NULL,
	PRIMARY KEY (key, lang)
)
"""
const GET_CMS_COLUMNS: String = "PRAGMA table_info(cms)"
var db
var db_path: String

var _last_query_result: Array = []

# Control nodes
onready var query_results: ItemList = find_node("QueryResults")

onready var input_type_button: OptionButton = find_node("InputTypeButton")
onready var raw_input_text_edit: TextEdit = find_node("RawInputTextEdit")
onready var structured_container: HBoxContainer = find_node("StructuredContainer")
onready var input_button: Button = find_node("InputButton")

# Input
var _is_super_pressed: bool = false

var _raw_input_history_pointer: int = 0
var _raw_input_history: Array = Array()

var _structured_input_history_pointer: int = 0
var _structured_input_history: Array = Array()

###############################################################################
# Builtin functions                                                           #
###############################################################################

func _ready() -> void:
	input_type_button.connect("item_selected", self, "_on_item_selected")
	input_button.connect("pressed", self, "_on_input_button_pressed")
	
	if not OS.is_debug_build():
		db_path = OS.get_executable_path().get_base_dir()
	else:
		db_path = "res://export/"
	
	db = SQLITE.new()
	db.path = "%s%s" % [db_path, DB_NAME]
	
	db.open_db()
	
	db.query("SELECT name FROM sqlite_master WHERE type='table' AND name='cms'")
	
	if db.query_result.empty():
		db.query(CREATE_CMS_TABLE)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("super"):
		_is_super_pressed = true
	elif event.is_action_released("super"):
		_is_super_pressed = false
	
	elif _is_super_pressed:
		if event.is_action_pressed("ui_accept"):
			_on_input_button_pressed()
			get_tree().set_input_as_handled()
		elif event.is_action_pressed("ui_up"):
			_get_previous_input_history()
		elif event.is_action_pressed("ui_down"):
			_get_next_input_history()

###############################################################################
# Connections                                                                 #
###############################################################################

func _on_item_selected(index: int) -> void:
	match input_type_button.get_item_text(index):
		INPUT_TYPE_RAW:
			raw_input_text_edit.visible = true
			structured_container.visible = false
		INPUT_TYPE_STRUCTURED:
			raw_input_text_edit.visible = false
			_build_structured_container()
			structured_container.visible = true

func _on_input_button_pressed() -> void:
	var query_text: String = ""
	
	if raw_input_text_edit.visible:
		query_text = raw_input_text_edit.text
		_add_to_raw_input_history(query_text)
		raw_input_text_edit.text = ""
	else:
		# TODO fill out structured input logic
		pass
	
	db.query(query_text)
	
	_last_query_result = db.query_result
	
	_display_query_results()

###############################################################################
# Private functions                                                           #
###############################################################################

func _get_previous_input_history() -> void:
	if raw_input_text_edit.visible:
		# Return early if there is no history
		if _raw_input_history_pointer < 0:
			return
		
		if _raw_input_history_pointer > 0:
			_raw_input_history_pointer -= 1
		
		raw_input_text_edit.text = _raw_input_history[_raw_input_history_pointer]
	else:
		# TODO fill out structured input logic
		pass

func _get_next_input_history() -> void:
	var result: String = ""
	
	if raw_input_text_edit.visible:
		# Return early if we have reached come back to the most recent result
		if _raw_input_history_pointer == _raw_input_history.size() - 1:
			return
		
		_raw_input_history_pointer += 1
		raw_input_text_edit.text = _raw_input_history[_raw_input_history_pointer]
	else:
		# TODO fill out structured input logic
		pass

func _add_to_raw_input_history(text: String) -> void:
	_raw_input_history.push_back(text)
	
	while _raw_input_history.size() > INPUT_HISTORY_MAX:
		_raw_input_history.remove(0)
	
	_raw_input_history_pointer = _raw_input_history.size() - 1

func _get_column_names() -> Array:
	var result: Array = []
	db.query(GET_CMS_COLUMNS)
	
	for r in db.query_result:
		result.append(r["name"])
	
	return result

func _build_structured_container() -> void:
	for c in structured_container.get_children():
		c.queue_free()
	
	yield(get_tree(), "idle_frame")
	
	var column_names: Array = _get_column_names()
	for r in column_names:
		var vli: VerticalLabelInput = VERTICAL_LABEL_INPUT.instance()
		vli.title = r
		structured_container.call_deferred("add_child", vli)

func _display_query_results() -> void:
	query_results.clear()
	
	if _last_query_result.size() < 1:
		return
	
	# Dictionary
	var results: Array = _last_query_result.duplicate()
	
	query_results.max_columns = results[0].size()
	
	# Create column names
	var column_names: PoolStringArray = PoolStringArray()
	for r in results[0].keys():
		query_results.add_item(r)
		column_names.push_back(r)
	
	# Populate column value
	for r in results:
		for n in column_names:
			var value = ""
			if r[n] != null:
				value = str(r[n])
			query_results.add_item(value)

###############################################################################
# Public functions                                                            #
###############################################################################


