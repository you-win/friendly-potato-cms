class_name VerticalLabelInput
extends VBoxContainer

onready var label: Label = $Label
onready var text_edit: TextEdit = $TextEdit

var title: String = ""

###############################################################################
# Builtin functions                                                           #
###############################################################################

func _ready() -> void:
	label.text = title

func _input(event: InputEvent) -> void:
	if not text_edit.has_focus():
		return
	if event is InputEventKey:
		if event.is_action_pressed("ui_focus_next"):
			get_node(self.focus_next).grab_focus()
			get_tree().set_input_as_handled()
		elif event.is_action("ui_focus_next"):
			get_tree().set_input_as_handled()

###############################################################################
# Connections                                                                 #
###############################################################################

###############################################################################
# Private functions                                                           #
###############################################################################

###############################################################################
# Public functions                                                            #
###############################################################################

func get_value() -> String:
	return text_edit.text
