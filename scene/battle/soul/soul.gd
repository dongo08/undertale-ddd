extends CharacterBody2D
class_name Soul
enum Type{
	RED,
	BLUE,
	GREEN,
	YELLOW
}
enum GDir{
	DOWN,
	RIGHT,
	UP,
	LEFT,
}

const DIRECTION:Array[String]=["down","right","up","left"]

const NORMAL_SPEED:float=120
const SLOW_SPEED:float=60

@export var game:BattleManager
@export var battle_state:BattleManager.BattleState
@export var type:Type
@export var g_dir:GDir
@export var invincible_time:float=1
@export var player_status:PlayerStatus
@export var hitbox:HitBox
@onready var snd_hurt_1: AudioStreamPlayer = $SndHurt1
var invincible:bool=false
var g_velosity:float
var movement_locked:bool=false

func _ready() -> void:
	hitbox.apply_damage.connect(apply_damage)

func _physics_process(delta: float) -> void:
	if movement_locked:
		return
	velocity=Vector2.ZERO
	if !game or game.state==game.BattleState.ENEMY_TURN:
		if type==Type.BLUE:
			velocity=move_blue(delta)
		else:
			velocity=move_normal(delta)

	move_and_slide()
	#print(is_on_floor())

func move_blue(delta:float)->Vector2:
	motion_mode=CharacterBody2D.MOTION_MODE_GROUNDED
	var horizon_vel:float
	var g=get_gravity().y
	var soul_up:bool
	var soul_down:bool
	var soul_left:bool
	var soul_right:bool
	match g_dir:
		GDir.DOWN:
			up_direction=Vector2.UP
			soul_up=Input.is_action_pressed("up")
			soul_down=Input.is_action_pressed("down")
			soul_left=Input.is_action_pressed("left")
			soul_right=Input.is_action_pressed("right")
		GDir.UP:
			up_direction=Vector2.DOWN
			soul_up=Input.is_action_pressed("down")
			soul_down=Input.is_action_pressed("up")
			soul_left=Input.is_action_pressed("right")
			soul_right=Input.is_action_pressed("left")
		GDir.LEFT:
			up_direction=Vector2.RIGHT
			soul_up=Input.is_action_pressed("right")
			soul_down=Input.is_action_pressed("left")
			soul_left=Input.is_action_pressed("up")
			soul_right=Input.is_action_pressed("down")
		GDir.RIGHT:
			up_direction=Vector2.LEFT
			soul_up=Input.is_action_pressed("left")
			soul_down=Input.is_action_pressed("right")
			soul_left=Input.is_action_pressed("down")
			soul_right=Input.is_action_pressed("up")
	
	if soul_right:
		horizon_vel+=1
	if soul_left:
		horizon_vel+=-1
	if is_on_floor():
		if soul_up:
			g_velosity=-160
	else:
		if is_on_ceiling():
			g_velosity=0
		if  soul_up and g_velosity<0:
			g_velosity+=g*((g_velosity+165)/165)*delta
		else:
			if g_velosity<0:
				g_velosity+=g*delta*2
			else:
				g_velosity+=g*delta
	

	if Input.is_action_pressed("slow"):
		horizon_vel*=SLOW_SPEED
	else:
		horizon_vel*=NORMAL_SPEED
		
	#print(soul_up,is_on_floor(),is_on_ceiling(),g_velosity)
	match g_dir:
		GDir.DOWN:
			return Vector2(horizon_vel,g_velosity)
		GDir.UP:
			return Vector2(-horizon_vel,-g_velosity)
		GDir.LEFT:
			return Vector2(g_velosity,horizon_vel)
		GDir.RIGHT:
			return Vector2(g_velosity,horizon_vel)
		_:
			return Vector2.ZERO





func move_normal(_delta)->Vector2:
	motion_mode=CharacterBody2D.MOTION_MODE_FLOATING
	var vel:Vector2
	#if !Input.is_action_pressed("left") and !Input.is_action_pressed("right"):
		#vel.x=0
	vel=Input.get_vector("left","right","up","down")

	
	
	if Input.is_action_pressed("slow"):
		vel*=SLOW_SPEED
	else:
		vel*=NORMAL_SPEED
	return vel

func apply_damage(damage:float):
	if !invincible:
		_hurt(damage)


func _hurt(damage:float):
	if damage>=player_status.hp:
		if damage/2<player_status.hp:
			player_status.hp=1
		else:
			player_status.hp-=damage
	else:
		player_status.hp-=damage
	snd_hurt_1.play()
	modulate.v=0.5
	if player_status.hp<=0:

		get_tree().call_deferred("reload_current_scene")

	invincible=true
	await get_tree().create_timer(invincible_time).timeout
	modulate.v=1
	invincible=false
