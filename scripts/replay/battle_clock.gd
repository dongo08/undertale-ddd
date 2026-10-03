extends Node

## 战斗时钟：逻辑“等一会儿”只按物理帧走，不按真实时间。
## 以后所有 await create_timer(...) 都换成 BattleClock.wait_ticks(...)，
## 回放才能逐帧重现（否则同样输入在不同帧率下会越跑越偏）。

## 物理 tick 频率（project.godot 用的是默认 60）
const TICKS_PER_SECOND := 60


## 等 N 个物理帧
func wait_ticks(ticks: int) -> void:
	for i in maxi(0, ticks):
		await get_tree().physics_frame


## 等 t 秒（换算成物理帧，至少 1 帧）
func wait_seconds(seconds: float) -> void:
	await wait_ticks(seconds_to_ticks(seconds))


## 秒 → tick
static func seconds_to_ticks(seconds: float) -> int:
	return maxi(1, roundi(seconds * TICKS_PER_SECOND))
