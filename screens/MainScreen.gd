extends Node2D

signal toggle_selected(toggle_name)

const VERTICAL_LABEL_INPUT: Resource = preload("res://screens/ui-elements/VerticalLabelInput.tscn")

const RAW_TOGGLE: String = "RawToggle"
const SELECT_TOGGLE: String = "SelectToggle"
const INSERT_TOGGLE: String = "InsertToggle"
const UPDATE_TOGGLE: String = "UpdateToggle"
const DELETE_TOGGLE: String = "DeleteToggle"

const WHERE_COLUMN: String = "where"
const ERROR_MESSAGE_EMPTY: String = "not an error"

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
	notes TEXT,
	PRIMARY KEY (key, lang),
	CHECK (key <> '' and lang <> '' and value <> '')
)
"""
const GET_CMS_COLUMNS: String = "PRAGMA table_info(cms)"
var db
var db_path: String

var _last_query_result: Array = []

# Control nodes
onready var query_results: ItemList = find_node("QueryResults")
onready var error_display: Label = find_node("ErrorDisplay")

onready var toggle_container: VBoxContainer = find_node("ToggleContainer")
onready var raw_toggle: Toggle = find_node(RAW_TOGGLE)
onready var select_toggle: Toggle = find_node(SELECT_TOGGLE)
onready var insert_toggle: Toggle = find_node(INSERT_TOGGLE)
onready var update_toggle: Toggle = find_node(UPDATE_TOGGLE)
onready var delete_toggle: Toggle = find_node(DELETE_TOGGLE)

onready var raw_input_text_edit: TextEdit = find_node("RawInputTextEdit")
onready var structured_container: HBoxContainer = find_node("StructuredContainer")
onready var input_button: Button = find_node("InputButton")

# Input
var _is_super_pressed: bool = false

var _raw_input_history_pointer: int = 0
var _raw_input_history: Array = Array()

###############################################################################
# Builtin functions                                                           #
###############################################################################

func _ready() -> void:
	self.connect("toggle_selected", raw_toggle, "_on_toggle_selected")
	self.connect("toggle_selected", select_toggle, "_on_toggle_selected")
	self.connect("toggle_selected", insert_toggle, "_on_toggle_selected")
	self.connect("toggle_selected", update_toggle, "_on_toggle_selected")
	self.connect("toggle_selected", delete_toggle, "_on_toggle_selected")
	
	raw_toggle.connect("self_pressed", self, "_on_toggle_pressed")
	select_toggle.connect("self_pressed", self, "_on_toggle_pressed")
	insert_toggle.connect("self_pressed", self, "_on_toggle_pressed")
	update_toggle.connect("self_pressed", self, "_on_toggle_pressed")
	delete_toggle.connect("self_pressed", self, "_on_toggle_pressed")
	
	input_button.connect("pressed", self, "_on_input_button_pressed")
	
	find_node("ExportAllButton").connect("pressed", self, "_on_export_all")
	find_node("ExportQueryButton").connect("pressed", self, "_on_export_query")
	
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

func _on_toggle_pressed(toggle_name: String) -> void:
	# Unselect other toggles
	emit_signal("toggle_selected", toggle_name)
	
	raw_input_text_edit.visible = false
	structured_container.visible = false
	
	if toggle_name == RAW_TOGGLE:
		raw_input_text_edit.visible = true
	else:
		_build_structured_container(toggle_name)
		structured_container.visible = true

func _on_input_button_pressed() -> void:
	var query_text: String = ""
	
	if raw_input_text_edit.visible:
		query_text = raw_input_text_edit.text
		raw_input_text_edit.text = ""
	else:
		var toggle_name: String = ""
		for c in toggle_container.get_children():
			if c.pressed:
				toggle_name = c.name
				break
		
		var where_text: String = " WHERE "
		# String
		var column_names: Array = []
		# String
		var column_values: Array = []
		
		for c in structured_container.get_children():
			if c.title == WHERE_COLUMN:
				if c.get_value().empty():
					where_text = ""
				else:
					where_text += c.get_value()
			else:
				column_names.append(c.title)
				column_values.append(c.get_value())
		
		match toggle_name:
			SELECT_TOGGLE:
				query_text = "SELECT * FROM cms%s;" % where_text
			INSERT_TOGGLE:
				var column_text: String
				var value_text: String
				
				for i in column_names.size():
					column_text += "%s" % column_names[i]
					value_text += '"%s"' % column_values[i]
					if i < column_names.size() - 1:
						column_text += ", "
						value_text += ", "
				
				query_text = "INSERT INTO cms (%s) values (%s);" % [column_text, value_text]
			UPDATE_TOGGLE:
				var set_text: String
				
				for i in column_names.size():
					if column_values[i].empty():
						continue
					set_text += '%s = "%s"' % [column_names[i], column_values[i]]
					if i < column_values.size() - 1:
						set_text += ", "
				
				query_text = "UPDATE cms SET %s%s;" % [set_text, where_text]
			DELETE_TOGGLE:
				query_text = "DELETE FROM cms%s;" % where_text
	
	db.query(query_text)
	_add_to_raw_input_history(query_text)
	
	_last_query_result = db.query_result
	if db.error_message == ERROR_MESSAGE_EMPTY:
		error_display.text = "Success"
	else:
		error_display.text = db.error_message
	
	_display_query_results()

func _on_export_all() -> void:
	"""
	output
	{
		"lang": {
			"key": "value"
		}
	}
	"""
	db.query("SELECT * FROM cms;")
	
	if db.query_result.size() < 1:
		error_display.text = "No data to export in 'cms' table"
		return
	
	var result: Dictionary = _generate_lean_json(db.query_result)
	
	var save_file: File = File.new()
	save_file.open("%s%s.json" % [db_path, "export_all"], File.WRITE)
	
	save_file.store_string(to_json(result))
	
	save_file.close()
	
	error_display.text = "DB exported as lean json"

func _on_export_query() -> void:
	"""
	output
	{
		"lang": {
			"key": "value"
		}
	}
	"""
	if _last_query_result.size() < 1:
		error_display.text = "No data to export from current query"
		return
	
	var result: Dictionary = _generate_lean_json(db.query_result)
	
	var save_file: File = File.new()
	var cdt: Dictionary = OS.get_datetime()
	save_file.open('%s%s-%s-%s-%s-%s-%s.json' % [db_path, cdt.year, cdt.month, cdt.day, cdt.hour, cdt.minute, cdt.second], File.WRITE)
	
	save_file.store_string(to_json(result))
	
	save_file.close()
	
	error_display.text = "Current query exported as lean json"

###############################################################################
# Private functions                                                           #
###############################################################################

func _get_previous_input_history() -> void:
	"""
	Input history is only supported for raw queries
	"""
	if raw_input_text_edit.visible:
		# Return early if there is no history
		if _raw_input_history_pointer < 0:
			return
		
		if _raw_input_history_pointer > 0:
			_raw_input_history_pointer -= 1
		
		raw_input_text_edit.text = _raw_input_history[_raw_input_history_pointer]

func _get_next_input_history() -> void:
	"""
	Input history is only supported for raw queries
	"""
	var result: String = ""
	
	if raw_input_text_edit.visible:
		# Return early if we have reached come back to the most recent result
		if _raw_input_history_pointer == _raw_input_history.size() - 1:
			return
		
		_raw_input_history_pointer += 1
		raw_input_text_edit.text = _raw_input_history[_raw_input_history_pointer]

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

func _build_structured_container(toggle_name: String) -> void:
	for c in structured_container.get_children():
		c.queue_free()
	
	yield(get_tree(), "idle_frame")
	
	match toggle_name:
		SELECT_TOGGLE:
			_generate_where_column_node()
		INSERT_TOGGLE:
			_generate_column_nodes()
		UPDATE_TOGGLE:
			_generate_where_column_node()
			_generate_column_nodes()
		DELETE_TOGGLE:
			_generate_where_column_node()
	
	yield(get_tree(), "idle_frame")
	
	for i in structured_container.get_child_count():
		var next_node = i + 1
		if next_node > structured_container.get_child_count() - 1:
			next_node = 0
		(structured_container.get_child(i) as VerticalLabelInput).focus_next = (structured_container.get_child(next_node) as VerticalLabelInput).text_edit.get_path()

func _generate_where_column_node() -> void:
	var vli: VerticalLabelInput = VERTICAL_LABEL_INPUT.instance()
	vli.title = WHERE_COLUMN
	vli.name = WHERE_COLUMN
	structured_container.call_deferred("add_child", vli)

func _generate_column_nodes() -> void:
	for r in _get_column_names():
		var vli: VerticalLabelInput = VERTICAL_LABEL_INPUT.instance()
		vli.title = r
		vli.name = r
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
			
			value.replace("\n", "\\n")
			
			query_results.add_item(value)

func _generate_lean_json(db_query_result: Array) -> Dictionary:
	var result: Dictionary = {}
	
	for r in db_query_result:
		var lang: String = r["lang"]
		if not result.has(lang):
			result[lang] = {}
		
		result[lang][r["key"]] = r["value"]
	
	return result

###############################################################################
# Public functions                                                            #
###############################################################################


