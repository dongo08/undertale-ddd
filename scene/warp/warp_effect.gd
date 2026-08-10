extends Node3D

@export var speed: float = 50.0
@export var line_count: int = 60
@export var line_width: float = 60.0
@export var near_dist: float = 3.0
@export var far_dist: float = 300.0
@export var gap_power: float = 1.8

var _lines: Array[MeshInstance3D] = []
var _total_range: float


func _ready() -> void:
	_total_range = far_dist - near_dist

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.WHITE
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.disable_receive_shadows = true

	for i in range(line_count):
		var t := float(i) / (line_count - 1)
		var z := -(near_dist + _total_range * pow(t, gap_power))

		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(line_width * (1.0 - t * 0.6), 0.03, 0.15)
		mesh.mesh = box
		mesh.material_override = mat
		mesh.position = Vector3(0, 0, z)

		$Lines.add_child(mesh)
		_lines.append(mesh)


func _physics_process(delta: float) -> void:
	$Camera3D.position.z -= speed * delta

	for line in _lines:
		if line.position.z > $Camera3D.position.z + near_dist:
			line.position.z -= _total_range
