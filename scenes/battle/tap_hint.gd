extends Label
## 첫 판 안내 (GDD 9절): 처음 시작한 사람에게 "화면을 탭해 공격"을 띄운다. 몇 번 탭하면 사라지고 다시 나오지 않는다.
## 탭 수는 업적 통계(회귀·환생해도 남는다)로 센다. 입력은 막지 않는다 (아래 전투 화면이 탭을 받는다).

const HIDE_AFTER_TAPS: float = 5.0  # 이만큼 탭하면 안내를 거둔다
const PULSE_SCALE: float = 1.08      # 숨 쉬듯 커졌다 작아진다. 자리를 옮기면 앵커 배치와 다퉈 위치를 Tween하지 않는다
const PULSE_SECONDS: float = 0.6
const FADE_SECONDS: float = 0.3
const VERTICAL_ANCHOR: float = 0.24  # 전투 화면 높이에서의 자리. 하늘(용사 머리 위). 아래쪽은 알림 자리라 겹친다

var _pulse: Tween


func _ready() -> void:
	text = "화면을 탭해 공격!"
	theme_type_variation = "Pill"
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 10  # 전투 화면이 나중에 만드는 인물·연출보다 위에
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE)
	anchor_top = VERTICAL_ANCHOR
	anchor_bottom = VERTICAL_ANCHOR
	Achievements.stat_changed.connect(_on_stat_changed)
	visible = _needed()
	resized.connect(func() -> void: pivot_offset = size / 2.0)
	if visible:
		_start_pulse()


## 회귀·환생을 한 적이 없고 탭이 아직 적을 때만
func _needed() -> bool:
	return Prestige.prestige_count == 0 and Rebirth.rebirth_count == 0 \
		and Achievements.value(Balance.Stat.TAPS) < HIDE_AFTER_TAPS


func _start_pulse() -> void:
	_pulse = create_tween().set_loops()
	_pulse.tween_property(self, "scale", Vector2.ONE * PULSE_SCALE, PULSE_SECONDS).set_trans(Tween.TRANS_SINE)
	_pulse.tween_property(self, "scale", Vector2.ONE, PULSE_SECONDS).set_trans(Tween.TRANS_SINE)


func _on_stat_changed(stat: int, _value: float) -> void:
	if stat != Balance.Stat.TAPS or not visible or _needed():
		return
	if _pulse:
		_pulse.kill()
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, FADE_SECONDS)
	fade.tween_callback(hide)
