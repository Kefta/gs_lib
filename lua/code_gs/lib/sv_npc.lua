TASK_INVALID = 0
// Forces the activity to reset.
TASK_RESET_ACTIVITY = 1
// Waits for the specified number of seconds.
TASK_WAIT = 2
// Make announce attack sound
TASK_ANNOUNCE_ATTACK = 3
// Waits for the specified number of seconds. Will constantly turn to 
// face the enemy while waiting. 
TASK_WAIT_FACE_ENEMY = 4
// Waits up to the specified number of seconds. Will constantly turn to 
// face the enemy while waiting. 
TASK_WAIT_FACE_ENEMY_RANDOM = 5
// Wait until the player enters the same PVS as this character.
TASK_WAIT_PVS = 6
// DON'T use this, it needs to go away. 
TASK_SUGGEST_STATE = 7
// Set m_hTargetEnt to nearest player
TASK_TARGET_PLAYER = 8
// Walk to m_hTargetEnt's location
TASK_SCRIPT_WALK_TO_TARGET = 9
// Run to m_hTargetEnt's location
TASK_SCRIPT_RUN_TO_TARGET = 10
// Move to m_hTargetEnt's location using the activity specified by m_hCine->m_iszCustomMove.
TASK_SCRIPT_CUSTOM_MOVE_TO_TARGET =11 
// Move to within specified range of m_hTargetEnt
TASK_MOVE_TO_TARGET_RANGE = 12
// Move to within specified range of our nav goal
TASK_MOVE_TO_GOAL_RANGE = 13
// Path that moves the character a few steps forward of where it is.
TASK_MOVE_AWAY_PATH = 14
TASK_GET_PATH_AWAY_FROM_BEST_SOUND = 15
// Set the implied goal for TASK_GET_PATH_TO_GOAL
TASK_SET_GOAL = 16
// Get the path to the goal specified by TASK_SET_GOAL
TASK_GET_PATH_TO_GOAL = 17
// Path to the enemy's location. Even if the enemy is unseen!
TASK_GET_PATH_TO_ENEMY = 18
// Path to the last place this character saw the enemy
TASK_GET_PATH_TO_ENEMY_LKP = 19
// Path to the enemy's location or path to a LOS with the enemy's last known position, depending on range
TASK_GET_CHASE_PATH_TO_ENEMY = 20
// Path to a LOS with the enemy's last known position
TASK_GET_PATH_TO_ENEMY_LKP_LOS = 21
// Path to the dead enemy's carcass.
TASK_GET_PATH_TO_ENEMY_CORPSE = 22
// Path to the player's origin
TASK_GET_PATH_TO_PLAYER = 23
// Path to node with line of sight to enemy
TASK_GET_PATH_TO_ENEMY_LOS = 24
// Path to node with line of sight to enemy, at least flTaskData units away from m_vSavePosition
TASK_GET_FLANK_RADIUS_PATH_TO_ENEMY_LOS = 25
// Path to node with line of sight to enemy, at least flTaskData degrees away from m_vSavePosition from the enemy's POV
TASK_GET_FLANK_ARC_PATH_TO_ENEMY_LOS = 26
// Path to the within shot range of last place this character saw the enemy
TASK_GET_PATH_TO_RANGE_ENEMY_LKP_LOS = 27
// Build a path to m_hTargetEnt
TASK_GET_PATH_TO_TARGET = 28
// Allow a little slop, and allow for some Z offset (like the target is a gun on a table).
TASK_GET_PATH_TO_TARGET_WEAPON = 29
TASK_CREATE_PENDING_WEAPON = 30
// Path to nodes[ m_pHintNode ]
TASK_GET_PATH_TO_HINTNODE = 31
// Store current position for later reference
TASK_STORE_LASTPOSITION = 32
// Clear stored position
TASK_CLEAR_LASTPOSITION = 33
// Store current position for later reference
TASK_STORE_POSITION_IN_SAVEPOSITION = 34
// Store best sound position for later reference
TASK_STORE_BESTSOUND_IN_SAVEPOSITION = 35
TASK_STORE_BESTSOUND_REACTORIGIN_IN_SAVEPOSITION = 36
TASK_REACT_TO_COMBAT_SOUND = 37
// Store current enemy position in saveposition
TASK_STORE_ENEMY_POSITION_IN_SAVEPOSITION = 38
// Move to the goal specified by the player in command mode.
TASK_GET_PATH_TO_COMMAND_GOAL = 39
TASK_MARK_COMMAND_GOAL_POS = 40
TASK_CLEAR_COMMAND_GOAL = 41
// Path to last position (Last position must be stored with TASK_STORE_LAST_POSITION)
TASK_GET_PATH_TO_LASTPOSITION = 42
// Path to saved position (Save position must by set in code or by a task)
TASK_GET_PATH_TO_SAVEPOSITION = 43
// Path to location that has line of sight to saved position (Save position must by set in code or by a task)
TASK_GET_PATH_TO_SAVEPOSITION_LOS = 44
// Path to random node
TASK_GET_PATH_TO_RANDOM_NODE = 45
// Path to source of loudest heard sound that I care about
TASK_GET_PATH_TO_BESTSOUND = 46
// Path to source of the strongest scend that I care about
TASK_GET_PATH_TO_BESTSCENT = 47
// Run the current path
TASK_RUN_PATH = 48
// Walk the current path
TASK_WALK_PATH = 49
// Walk the current path for a specified number of seconds
TASK_WALK_PATH_TIMED = 50
// Walk the current path until you are x units from the goal.
TASK_WALK_PATH_WITHIN_DIST = 51
// Walk the current path until for x units
TASK_WALK_PATH_FOR_UNITS = 52
// Rung the current path until you are x units from the goal.
TASK_RUN_PATH_FLEE = 53
// Run the current path for a specified number of seconds
TASK_RUN_PATH_TIMED = 54
// Run the current path until for x units
TASK_RUN_PATH_FOR_UNITS = 55
// Run the current path until you are x units from the goal.
TASK_RUN_PATH_WITHIN_DIST = 56
// Walk the current path sideways (must be supported by animation)
TASK_STRAFE_PATH = 57
// Clear m_flMoveWaitFinished (timer that inhibits movement)
TASK_CLEAR_MOVE_WAIT = 58
// Decide on the appropriate small flinch animation, and play it. 
TASK_SMALL_FLINCH = 59
// Decide on the appropriate big flinch animation, and play it. 
TASK_BIG_FLINCH = 60
// Prevent dodging for a certain amount of time.
TASK_DEFER_DODGE = 61
// Turn to face ideal yaw
TASK_FACE_IDEAL = 62
// Find an interesting direction to face. Don't face into walls, corners if you can help it.
TASK_FACE_REASONABLE = 63
// Turn to face the way I should walk or run
TASK_FACE_PATH = 64
// Turn to face a player
TASK_FACE_PLAYER = 65
// Turn to face the enemy
TASK_FACE_ENEMY = 66
// Turn to face nodes[ m_pHintNode ]
TASK_FACE_HINTNODE = 67
// Play activity associate with the current hint
TASK_PLAY_HINT_ACTIVITY = 68
// Turn to face m_hTargetEnt
TASK_FACE_TARGET = 69
// Turn to face stored last position (last position must be stored first!)
TASK_FACE_LASTPOSITION = 70
// Turn to face stored save position (save position must be stored first!)
TASK_FACE_SAVEPOSITION = 71
// Turn to face directly away from stored save position (save position must be stored first!)
TASK_FACE_AWAY_FROM_SAVEPOSITION = 72
// Set the current facing to be the ideal
TASK_SET_IDEAL_YAW_TO_CURRENT = 73
// Attack the enemy (should be facing the enemy)
TASK_RANGE_ATTACK1 = 74
TASK_RANGE_ATTACK2 = 75
TASK_MELEE_ATTACK1 = 76
TASK_MELEE_ATTACK2 = 77
// Reload weapon
TASK_RELOAD = 78
// Execute special attack (user-defined)
TASK_SPECIAL_ATTACK1 = 79
TASK_SPECIAL_ATTACK2 = 79
TASK_FIND_HINTNODE = 80
TASK_FIND_LOCK_HINTNODE = 80
TASK_CLEAR_HINTNODE = 81
// Claim m_pHintNode exclusively for this NPC.
TASK_LOCK_HINTNODE = 82
// Emit an angry sound
TASK_SOUND_ANGRY = 83
// Emit a dying sound
TASK_SOUND_DEATH = 84
// Emit an idle sound
TASK_SOUND_IDLE = 85
// Emit a sound because you are pissed off because you just saw someone you don't like
TASK_SOUND_WAKE = 86
// Emit a pain sound
TASK_SOUND_PAIN = 87
// Emit a death sound
TASK_SOUND_DIE = 88
// Speak a sentence
TASK_SPEAK_SENTENCE = 89
// Wait for the current sentence I'm speaking to finish
TASK_WAIT_FOR_SPEAK_FINISH = 90
// Set current animation activity to the specified activity
TASK_SET_ACTIVITY = 91
// Adjust the framerate to plus/minus N%
TASK_RANDOMIZE_FRAMERATE = 92
// Immediately change to a schedule of the specified type
TASK_SET_SCHEDULE = 93
// Set the specified schedule to execute if the current schedule fails.
TASK_SET_FAIL_SCHEDULE = 94
// How close to route goal do I need to get
TASK_SET_TOLERANCE_DISTANCE = 95
// How many seconds should I spend search for a route
TASK_SET_ROUTE_SEARCH_TIME = 96
// Return to use of default fail schedule
TASK_CLEAR_FAIL_SCHEDULE = 97
// Play the specified animation sequence before continuing
TASK_PLAY_SEQUENCE = 98
// Play the specified private animation sequence before continuing
TASK_PLAY_PRIVATE_SEQUENCE = 99
// Turn to face the enemy while playing specified animation sequence
TASK_PLAY_PRIVATE_SEQUENCE_FACE_ENEMY = 100
TASK_PLAY_SEQUENCE_FACE_ENEMY = 101
TASK_PLAY_SEQUENCE_FACE_TARGET = 102
// tries lateral cover first, then node cover
TASK_FIND_COVER_FROM_BEST_SOUND = 103
// tries lateral cover first, then node cover
TASK_FIND_COVER_FROM_ENEMY = 104
// Find a place to hide from the enemy, somewhere on either side of me
TASK_FIND_LATERAL_COVER_FROM_ENEMY = 105
// Find a place further from the saved position
TASK_FIND_BACKAWAY_FROM_SAVEPOSITION = 106
// Fine a place to hide from the enemy, anywhere. Use the node system.
TASK_FIND_NODE_COVER_FROM_ENEMY = 107
// Find a place to hide from the enemy that's within the specified distance
TASK_FIND_NEAR_NODE_COVER_FROM_ENEMY = 108
// data for this one is there MINIMUM aceptable distance to the cover.
TASK_FIND_FAR_NODE_COVER_FROM_ENEMY = 109
// Find a place to go that can't see to where I am now.
TASK_FIND_COVER_FROM_ORIGIN = 110
// Unhook from the AI system.
TASK_DIE = 111
// Wait until scripted sequence plays
TASK_WAIT_FOR_SCRIPT = 112
// Play scripted sequence animation
TASK_PUSH_SCRIPT_ARRIVAL_ACTIVITY = 113
TASK_PLAY_SCRIPT = 114
TASK_PLAY_SCRIPT_POST_IDLE = 115
TASK_ENABLE_SCRIPT = 116
TASK_PLANT_ON_SCRIPT = 117
TASK_FACE_SCRIPT = 118
// Wait for scene to complete
TASK_PLAY_SCENE = 119
// Wait for 0 to specified number of seconds
TASK_WAIT_RANDOM = 120
// Wait forever (until this schedule is interrupted)
TASK_WAIT_INDEFINITE = 121
TASK_STOP_MOVING = 122
// Turn left the specified number of degrees
TASK_TURN_LEFT = 123
// Turn right the specified number of degrees
TASK_TURN_RIGHT = 124
// Remember the specified piece of data
TASK_REMEMBER = 125
// Forget the specified piece of data
TASK_FORGET = 126
// Wait until current movement is complete. 
TASK_WAIT_FOR_MOVEMENT = 127
// Wait until a single-step movement is complete.
TASK_WAIT_FOR_MOVEMENT_STEP = 128
// Wait until I can't hear any danger sound.
TASK_WAIT_UNTIL_NO_DANGER_SOUND = 129
// Pick up new weapons:
TASK_WEAPON_FIND = 130
TASK_WEAPON_PICKUP = 131
// run to weapon but break if someone else picks it up
TASK_WEAPON_RUN_PATH = 132
TASK_WEAPON_CREATE = 133
TASK_ITEM_PICKUP = 134
TASK_ITEM_RUN_PATH = 135
// Use small hull for tight navigation
TASK_USE_SMALL_HULL = 136
// wait until you are on ground
TASK_FALL_TO_GROUND = 137
// Wander for a specfied amound of time
TASK_WANDER = 138
TASK_FREEZE = 139
// regather conditions at the start of a schedule (all conditions are cleared between schedules)
TASK_GATHER_CONDITIONS = 140
// Require an enemy be seen after the task is run to be considered a candidate enemy
TASK_IGNORE_OLD_ENEMIES = 141
TASK_DEBUG_BREAK = 142
// Add a specified amount of health to this NPC
TASK_ADD_HEALTH = 143
// Add a gesture layer and wait until it's finished
TASK_ADD_GESTURE_WAIT = 144
// Add a gesture layer
TASK_ADD_GESTURE = 145
// Get a path to my forced interaction partner
TASK_GET_PATH_TO_INTERACTION_PARTNER = 146
// First task of all schedules for playing back scripted sequences
TASK_PRE_SCRIPT = 147
// ======================================
// IMPORTANT: This must be the last enum
// ======================================
LAST_SHARED_TASK = 148
