extends Node

signal message_logged(message)

onready var sdu: SaveDataUtil = SaveDataUtil.new()

###############################################################################
# Builtin functions                                                           #
###############################################################################

func _ready() -> void:
	var default_theme: Theme = load("res://assets/DefaultTheme.tres")
	var font = DynamicFont.new()
	font.font_data = load("c://Windows/Fonts/arial.ttf")
#	font.font_data = load("res://assets/arial-unicode-ms.ttf")
	default_theme.default_font = font

###############################################################################
# Connections                                                                 #
###############################################################################

###############################################################################
# Private functions                                                           #
###############################################################################

###############################################################################
# Public functions                                                            #
###############################################################################

func log_message(message: String, is_error: bool = false) -> void:
	if is_error:
		message = "%s: %s" % ["[ERROR]", message]
		assert(false, message)
	print(message)
	emit_signal("message_logged", message)
