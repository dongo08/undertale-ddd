extends Node

## 战斗随机数：gameplay 的随机全部从这里出。
## 种子一固定，同样的输入就会长出同样的弹幕 / 同样的伤害 —— 回放能成立的前提。
##
## 注意：视觉特效、粒子之类**不要**用它（那些用 Godot 全局的 randf 就行），
## 否则会扰动 gameplay 的随机序列。

var rng := RandomNumberGenerator.new()
## 本局用的种子（录制时要写进回放文件）
var used_seed: int = 0


func _ready() -> void:
	begin_random()


## 开一局：随机种子（和以前“每局都不一样”一致）
func begin_random() -> void:
	begin(randi())


## 开一局：指定种子（回放用）
func begin(seed_value: int) -> void:
	used_seed = seed_value
	rng.seed = seed_value


func randf() -> float:
	return rng.randf()


func randf_range(from: float, to: float) -> float:
	return rng.randf_range(from, to)


func randi() -> int:
	return rng.randi()


func randi_range(from: int, to: int) -> int:
	return rng.randi_range(from, to)
