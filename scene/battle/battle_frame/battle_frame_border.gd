@tool
extends AnimatableBody2D
class_name BattleFrameBorder
@export var collision: CollisionPolygon2D

func _draw() -> void:
	var polygon=collision.polygon
	polygon.append(collision.polygon[0])
	draw_colored_polygon(polygon,Color.BLACK)
	draw_polyline(polygon,Color.WHITE,4)
