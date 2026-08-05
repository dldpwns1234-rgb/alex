extends Control

## 진입점.
##
## 화면 스택을 세우고 홈 화면을 올린다.
## 게임 시계와 시뮬레이션은 오토로드 `Game`이 소유한다 (game/game.gd).
##
## 승패 판정도 여기서 받는다. 홈 화면이 아니라 여기인 이유는,
## 결과 화면이 어느 화면 위에서든 떠야 하기 때문이다 — 건물 화면에 들어가 있는
## 동안에도 마지막 가구는 떠날 수 있다.

var _stack: ScreenStack


func _ready() -> void:
	_stack = ScreenStack.new()
	_stack.name = "ScreenStack"
	add_child(_stack)
	_stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	Game.world_restarted.connect(_start_new_game)
	_start_new_game()


func _start_new_game() -> void:
	# 월드가 갈아끼워졌을 수 있으므로 신호를 매번 다시 연결한다.
	Game.world.game_ended.connect(_on_game_ended)
	_stack.reset(HomeScreen.new())


func _on_game_ended(outcome: String) -> void:
	_stack.push_screen(GameOverScreen.new(outcome))
