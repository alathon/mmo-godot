# References to other components

- If a script needs to reference another node that it knows will be part of the same scene,
use an `@onready var` pointing to a `%`-unique name. For example: `@onready var body: CharacterBody3D = %Body`
- If a script needs to reference a node that is part of the global services, use an
`@onready var` pointing to a `$`-path. For example: `@onready var _game_manager: GameManager = $/root/Root/Services/GameManager`
- If a script needs to reference a unique-named child of another scene/node it is referring to,
paths can be constructed using what that node has declared as unique names. For example: `var anim_tree: AnimationTree = new_model.get_node("%AnimationTree") as AnimationTree`
works because the model scene has `%AnimationTree` as a unique name.
- Don't use `init()` or `setup()` methods to accomplish the above, if it is possible to avoid it. Where `setup()` is
valid is if an existing node needs to change its values to reflect something new entering the scene, e.g., `animation_controller.bind_model(_animationTree, _animationPlayer, self)`
happens so that `animation_controller` can bind to the new animation tree and animation player part of the loaded model.

# Preloads

- Do not preload(), except to reference the `Proto` messages, e.g., `const Proto = preload("res://src/common/proto/packets.gd")`.
- You can use references to any class_name in the whole project, without preload()'ing it.

# Separation of concerns
Keep logic in .gd files, data in .tres files:

```
src/
  spells/
    spell_resource.gd      # Class definition + logic
    spell_effect.gd        # Effect logic
resources/
  spells/
    fireball.tres          # Data only, references scripts
    ice_spike.tres         # Data only
```

# Signal-driven communication
## Use signals for loose coupling:

```
signal health_changed(current, max)
signal death()

# Parent connects to signals
func _ready():
    $HealthAttribute.health_changed.connect(_on_health_changed)
    $HealthAttribute.death.connect(_on_death)
```

Benefits:

- No tight coupling between systems
- Easy to add new listeners
- Self-documenting (signals show available events)
- UI can connect without modifying game logic
