extends TextureButton

@onready var cooldown = $Cooldown
@onready var key: Label = $Key
@onready var time: Label = $Time
@onready var timer: Timer = $Timer

var change_key = "":
	set(v):
		change_key = v
		key.text = v
		
		shortcut = Shortcut.new()
		var input_key = InputEventKey.new()
		input_key.keycode = v.unicode_at(0)
		
		shortcut.events = [input_key]

func _ready():
	change_key = "1"
	cooldown.max_value = timer.wait_time
	set_process(false)

	self.pressed.connect(_on_pressed)
	timer.timeout.connect(_on_timeout)

func _process(_delta):
	time.text = "%3.1f" % timer.time_left
	cooldown.value = timer.time_left

func _on_pressed():
	timer.start()
	disabled = true
	set_process(true)

func _on_timeout():
	disabled = false
	time.text = ""
	cooldown.value = 0
	set_process(false)
