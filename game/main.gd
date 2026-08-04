extends Control

## 진입점.
##
## 화면 스택을 세우고 홈 화면을 올린다.
## 게임 시계와 시뮬레이션은 오토로드 `Game`이 소유한다 (game/game.gd).

func _ready() -> void:
	var stack := ScreenStack.new()
	stack.name = "ScreenStack"
	add_child(stack)
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	stack.push_screen(HomeScreen.new())
