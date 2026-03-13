extends Node

@rpc("authority", "reliable")
func server_tick(info):
	print("server_tick_info() called by authority with tick %s" % info.tick)

@rpc("authority", "unreliable_ordered")
func player_update(id, position, velocity):
	print("player_update() for id %s, position %s, velocity %s" % [id, position, velocity])
