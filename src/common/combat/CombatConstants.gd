class_name CombatConstants

const GCD_DURATION: float = 2.5
const ANIMATION_LOCK_DURATION: float = 0.7
const ABILITY_QUEUE_WINDOW: float = 0.5
const STATUS_EFFECT_DEFAULT_TICK: float = 3.0

# Cancel reason codes (used in AbilityUseRejected and CombatEvent_AbilityUseCanceled)
const CANCEL_MOVED: int = 0
const CANCEL_INTERRUPTED: int = 1
const CANCEL_STUNNED: int = 2
const CANCEL_TARGET_DIED: int = 3
const CANCEL_INVALID: int = 4

# Status effect remove reason codes (used in CombatEvent_StatusEffectRemoved)
const REMOVE_EXPIRED: int = 0
const REMOVE_DISPELLED: int = 1
const REMOVE_CONSUMED: int = 2
