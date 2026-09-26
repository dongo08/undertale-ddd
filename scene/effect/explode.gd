extends Node2D
class_name ExplodeEffect
#@onready var color_rect: ColorRect = $ColorRect

var radius1:float
var radius2:float
var radius3:float
var radius4:float

func _draw() -> void:
	draw_circle(Vector2.ZERO,radius1,Color.WHITE)
	draw_circle(Vector2.ZERO,radius2,Color.WHITE,false)
	draw_circle(Vector2.ZERO,radius3,Color.WHITE,false)
	draw_circle(Vector2.ZERO,radius4,Color.WHITE,false)
	
func _ready() -> void:
	$GPUParticles2D.emitting=true	
	var tween=create_tween()
	tween.tween_property(self,"radius1",100,0.3).from(0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self,"radius2",200,0.3).from(50)
	#tween.parallel().tween_property(color_rect,"scale",Vector2.ONE,0.3).from(Vector2.ZERO).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self,"radius3",250,0.3).from(100)
	tween.parallel().tween_property(self,"radius4",300,0.3).from(100)
	tween.tween_property(self,"radius1",50,0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self,"radius2",100,0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	#tween.parallel().tween_property(color_rect,"scale",Vector2.ZERO,0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self,"radius3",200,0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self,"radius4",200,0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self,"modulate:a",0,0.2)
	await get_tree().create_timer(0.5).timeout
	queue_free()
	
func _process(delta: float) -> void:
	queue_redraw()
