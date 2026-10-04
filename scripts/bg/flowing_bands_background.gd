extends ColorRect

## 流动斜向条纹背景 —— 可直接挂在铺满屏幕的 ColorRect 上。
##
## 用法 A（最省事）：把本脚本挂在 ColorRect 上，什么都不用连，
##   它会自己生成两张噪声贴图喂给 shader，并把 ColorRect 设成全屏铺满。
## 用法 B（用自己的噪声图）：在检查器里把两张噪点图分别拖到 noise_tex_a /
##   noise_tex_b（可以是 ImageTexture，也可以是 NoiseTexture2D）。
## 用法 C（只想要 shader）：不要这个脚本，手动创建 ShaderMaterial 也行。
##
## 想调画面参数（颜色、条数、波浪、透明度……）用 set_param()，
## 例如 set_param("opacity", 0.5)；完整参数表见 shader 文件里的注释。

@export_group("噪声贴图")
## 留空则自动生成（FastNoiseLite，无缝）。
@export var noise_tex_a: Texture2D
@export var noise_tex_b: Texture2D
@export_group("自动生成的噪声参数")
@export var noise_seed_a := 1337
@export var noise_seed_b := 90210
@export var noise_freq_a := 0.0032
@export var noise_freq_b := 0.0091
@export var noise_octaves_a := 3
@export var noise_octaves_b := 4
@export_group("行为")
## 自动铺满父节点（锚点全开）。
@export var fill_parent := true
## 自动把 t 写进 shader 的 time_offset，不需要的话可以在 _process 里拆掉。
@export var animate := true

const SHADER_PATH := "res://shader/flowing_diagonal_bands.gdshader"

var _mat: ShaderMaterial
var _time := 0.0
var _gen_a: NoiseTexture2D
var _gen_b: NoiseTexture2D


func _ready() -> void:
	if fill_parent:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color(1, 1, 1, 1)   # 颜色交给 shader，这里保持白色
	_apply_noise_textures()


func _process(delta: float) -> void:
	if not animate:
		set_process(false)
		return
	_time += delta
	if _mat != null:
		_mat.set_shader_parameter("time_offset", _time)


func _apply_noise_textures() -> void:
	if material is ShaderMaterial:
		_mat = material
	else:
		_mat = ShaderMaterial.new()
		_mat.shader = load(SHADER_PATH)
		material = _mat

	if noise_tex_a == null:
		_gen_a = _resolve(noise_seed_a, noise_freq_a, noise_octaves_a)
	if noise_tex_b == null:
		_gen_b = _resolve(noise_seed_b, noise_freq_b, noise_octaves_b)
	if _gen_a != null:
		_mat.set_shader_parameter("noise_tex_a", _gen_a)
	if _gen_b != null:
		_mat.set_shader_parameter("noise_tex_b", _gen_b)


func _resolve(seed_value: int, freq: float, octaves: int) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.seed = seed_value
	n.frequency = freq
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = octaves
	n.fractal_lacunarity = 2.0
	n.fractal_gain = 0.5
	var t := NoiseTexture2D.new()
	t.width = 512
	t.height = 512
	t.seamless = true
	t.seamless_blend_skirt = 0.15
	t.generate_mipmaps = false
	t.noise = n
	return t


## 运行时要换贴图 / 换参数时调这个。
func set_noise(tex_a: Texture2D, tex_b: Texture2D) -> void:
	if _mat == null:
		_apply_noise_textures()
	_mat.set_shader_parameter("noise_tex_a", tex_a)
	_mat.set_shader_parameter("noise_tex_b", tex_b)


## 便捷入口：随手改某个参数。
func set_param(name: StringName, value: Variant) -> void:
	if _mat == null:
		_apply_noise_textures()
	_mat.set_shader_parameter(name, value)
