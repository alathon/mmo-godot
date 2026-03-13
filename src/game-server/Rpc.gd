extends Node

@rpc("authority", "reliable")
func server_tick(info):
	pass

@rpc("authority", "unreliable_ordered")
func player_update(id, position, velocity):
	pass
