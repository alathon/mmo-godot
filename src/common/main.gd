extends Node
## This is the application entrypoint.
## The only purpose is to boot up the application and route to e.g., client or game_server or other.

@export var CLIENT_MAIN = "res://src/client/Game.tscn"
@export var GAME_SERVER_MAIN = "res://src/game-server/zones/ServerForest.tscn"
@export var BOT_MAIN = "res://src/client/Bot/BotGame.tscn"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var features: Dictionary[String, Callable] = {
		"client": start_client,
		"game-server": start_game_server,
		"bot": start_bot_client
	}
	
	for feature in features:
		if OS.has_feature(feature):
			features[feature].call()
			return

	printerr("No valid feature tag was found.")

func start_client() -> void:
	get_tree().change_scene_to_file.call_deferred(CLIENT_MAIN)

func start_game_server() -> void:
	get_tree().change_scene_to_file.call_deferred(GAME_SERVER_MAIN)

func start_bot_client() -> void:
	get_tree().change_scene_to_file.call_deferred(BOT_MAIN)
