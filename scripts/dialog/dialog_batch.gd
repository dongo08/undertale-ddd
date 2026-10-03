extends BaseDialog
class_name DialogBatch

## 一批“同时说”的对话：里面每一句各自指定 enemy_index，
## 播放时会同时显示在它那个敌人的对话框上，等这一批全部说完才轮到下一批。
##
## 放在 EnemyRoundSet.dialog_list 里当一条用。想“分开说”就直接放单句，
## 或者一层里只放一句；连续的单句会被自动合并成同一批。
##
## 继承 BaseDialog 是为了让 dialog_list 保持 Array[BaseDialog]，
## 这个类自己的 content 字段不使用，内容写在 dialogs 里的每一句上。
@export var dialogs: Array[ExpressionDialog] = []
