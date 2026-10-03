extends Resource
class_name EnemyRoundSet

## 一轮敌人的数据：四个难度各一份弹幕脚本 + 四个难度共用的对话。
## 放在 BattleData.rounds 里当一条用（下标还是回合下标）。

## 四个难度
enum Difficulty {
	EASY,
	NORMAL,
	HARD,
	EXTREME,
}

## 这一轮敌人的对话（四个难度共用）
## 元素可以是单句，也可以是 DialogBatch（一批同时说的对话）
@export var dialog_list:Array[BaseDialog]
## 这一轮显示在战斗框里的文本（四个难度共用）
@export var battleframe_text:BaseDialog

## 四个难度的弹幕脚本，留空表示这个难度还没做
@export var easy:GDScript
@export var normal:GDScript
@export var hard:GDScript
@export var extreme:GDScript


## 取某个难度填的脚本，没填返回 null（不回退）
func script_for(difficulty:Difficulty)->GDScript:
	match difficulty:
		Difficulty.EASY:
			return easy
		Difficulty.HARD:
			return hard
		Difficulty.EXTREME:
			return extreme
		_:
			return normal


## 这个难度有没有单独做脚本
func has_manager(difficulty:Difficulty)->bool:
	return script_for(difficulty)!=null


## 这一轮在某个难度下该用哪个脚本：
## 想要的难度没填就用 normal，normal 也没填就用第一个填了的（easy→hard→extreme）；
## 都没填返回 null，表示这一轮没有弹幕
func manager_for(difficulty:Difficulty)->GDScript:
	var wanted:=script_for(difficulty)
	if wanted:
		return wanted
	if difficulty!=Difficulty.NORMAL and normal:
		return normal
	for script in [easy,hard,extreme]:
		if script:
			return script
	return null
