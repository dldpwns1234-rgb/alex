extends Node

## 게임 전역 상태 — 오토로드 싱글턴 `Game`.
##
## 시뮬레이션(SimWorld)을 소유하고, 실시간을 게임 시간으로 변환한다.
## sim은 실시간을 모르므로(ARCHITECTURE §3.1) 그 변환이 여기서 일어난다.
##
## 세션 기반 진행 (GDD D16):
##   게임을 켜고 일시정지하지 않았을 때만 시간이 흐른다.
##   앱이 백그라운드로 가면 자동으로 멈춘다. 오프라인 진행은 없다.

signal speed_changed(index: int)

## 0번은 일시정지. 나머지는 실시간 배속.
const SPEEDS: Array[float] = [0.0, 1.0, 2.0, 4.0]
const SPEED_LABELS: Array[String] = ["II", "1x", "2x", "4x"]

## 1배속에서 게임 내 하루에 해당하는 실제 시간(초).
## 1년 = 120일 = 4분. 밸런싱 과정에서 조정된다.
const REAL_SECONDS_PER_DAY := 2.0

var world := SimWorld.create_default()
var speed_index: int = 1

var _day_accumulator := 0.0
## 백그라운드 전환 직전의 속도. -1이면 복원할 것이 없다.
var _speed_before_suspend: int = -1


func _ready() -> void:
	# 화면 스택이 어떻게 바뀌든 시계는 계속 돈다 (ARCHITECTURE §6.1 규칙 3).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_install_theme()


func _process(delta: float) -> void:
	var multiplier := SPEEDS[speed_index]
	if multiplier <= 0.0:
		return

	_day_accumulator += delta * multiplier

	# while 루프인 이유: 4배속이나 프레임 드랍 시 한 프레임에 여러 날이
	# 지날 수 있다. 이산 틱이므로 건너뛰지 않고 하루씩 전부 처리한다.
	while _day_accumulator >= REAL_SECONDS_PER_DAY:
		_day_accumulator -= REAL_SECONDS_PER_DAY
		world.tick()


func set_speed(index: int) -> void:
	var clamped := clampi(index, 0, SPEEDS.size() - 1)
	if clamped == speed_index:
		return
	speed_index = clamped
	speed_changed.emit(speed_index)


func is_paused() -> bool:
	return SPEEDS[speed_index] <= 0.0


# --- 세션 기반 진행 (GDD D16) -------------------------------------------------

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			_suspend()
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_WM_WINDOW_FOCUS_IN:
			_resume()


## 앱이 백그라운드로 갔다. 시간을 멈춘다.
func _suspend() -> void:
	if is_paused():
		return
	_speed_before_suspend = speed_index
	set_speed(0)


## 돌아왔다. 자리를 비운 동안 시간은 흐르지 않았다.
func _resume() -> void:
	if _speed_before_suspend < 0:
		return
	set_speed(_speed_before_suspend)
	_speed_before_suspend = -1


# --- 테마 --------------------------------------------------------------------

## Godot 기본 폰트에는 한글 글리프가 없다. 넣지 않으면 UI가 전부 빈 네모가 된다.
##
## TODO(M5): 도트 그래픽에 맞는 한글 픽셀 폰트로 교체한다.
##           Noto Sans KR은 5.9MB로 무겁고 게임 톤과도 맞지 않는다.
func _install_theme() -> void:
	var font := load("res://assets/fonts/NotoSansKR-Regular.ttf")
	if font == null:
		push_warning("한글 폰트를 불러오지 못했습니다. UI가 깨져 보입니다.")
		return

	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 26
	get_tree().root.theme = theme
