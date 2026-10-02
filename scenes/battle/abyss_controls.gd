extends Control
## 전투 화면의 심연 (GDD 7.13절): 시련의 탑 입구 바로 위의 "심연 · 원정 N" 입구(첫 초월 전에는 숨김), 확인 창,
## 심연 안에서는 "N층 · 나가기"와 처치 수 아래의 저주 줄(이번 층의 저주와 고른 축복). 전투 화면을 덮는 투명한 판이라 탭은 그대로 지나간다.
## Abyss의 함수만 부르고 표시만 한다. 상수는 배치용이다.

const TowerControls := preload("res://scenes/battle/tower_controls.gd")

const BUTTON_SIZE := Vector2(170, 56)
const EDGE_MARGIN: float = 16.0
const BUTTON_GAP: float = 10.0
const CURSE_TOP: float = 58.0      # 처치 수 줄(높이 44) 아래
const CURSE_HEIGHT: float = 38.0
const CURSE_LEFT: float = 180.0    # 왼쪽 위는 전사 머리와 이름표 자리라 비운다
const CURSE_FONT_SIZE: int = 19
const CONFIRM_SIZE := Vector2i(600, 440)

var _button: Button
var _curse_label: Label
var _confirm: ConfirmationDialog


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_curse_label = Label.new()
	_curse_label.theme_type_variation = "DangerPill"
	_curse_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_curse_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_curse_label.clip_text = true
	_curse_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_curse_label.add_theme_font_size_override("font_size", CURSE_FONT_SIZE)
	_curse_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_curse_label)
	_button = Button.new()
	_button.custom_minimum_size = BUTTON_SIZE
	_button.size = BUTTON_SIZE
	_button.clip_text = true
	_button.pressed.connect(_on_pressed)
	add_child(_button)
	_confirm = ConfirmationDialog.new()
	_confirm.title = "심연"
	_confirm.ok_button_text = "내려간다"
	_confirm.cancel_button_text = "취소"
	_confirm.dialog_autowrap = true
	_confirm.confirmed.connect(Abyss.enter)
	add_child(_confirm)
	resized.connect(_layout)
	Abyss.abyss_changed.connect(_refresh)
	Abyss.floor_started.connect(_refresh.unbind(1))
	Game.tower_changed.connect(_refresh.unbind(1))
	Game.monster_spawned.connect(_refresh.unbind(2))
	Game.monster_killed.connect(_refresh.unbind(1))
	Game.boss_failed.connect(_refresh)
	Transcend.transcended.connect(_refresh.unbind(1))
	_layout()
	_refresh()


## 탑 입구(오른쪽 아래) 바로 위. 탑이 아직 안 열렸으면 그 자리에
func _layout() -> void:
	var corner := size - BUTTON_SIZE - Vector2.ONE * EDGE_MARGIN
	var above_tower := Tower.is_unlocked() and not Game.in_tower
	_button.position = corner - Vector2(0.0, TowerControls.BUTTON_SIZE.y + BUTTON_GAP) if above_tower else corner
	_curse_label.position = Vector2(CURSE_LEFT, CURSE_TOP)
	_curse_label.size = Vector2(maxf(size.x - CURSE_LEFT - EDGE_MARGIN, 0.0), CURSE_HEIGHT)


func _on_pressed() -> void:
	if Abyss.active:
		Abyss.leave()
		return
	if not Abyss.can_enter():
		return
	_confirm.dialog_text = _confirm_text()
	_confirm.popup_centered(CONFIRM_SIZE)


func _confirm_text() -> String:
	var seed := Time.get_date_string_from_system()
	var none: Array[int] = []
	var first: Array[String] = []
	for curse in Balance.abyss_floor_curses(seed, 1, none):
		first.append("%s: %s" % [Balance.abyss_curse_name(curse), Balance.abyss_curse_note(curse)])
	return "오늘의 심연 (%s). 1층부터 %d초 안에 몬스터 %d마리, %d층마다 두목과 축복 고르기.\n몬스터는 지금 내 피해량에 맞춰 층마다 ×%s 단단해집니다. 층마다 저주가 붙습니다. 1층은 %s.\n원정 1회를 씁니다 (남은 %d회, 하루 %d회). 실패하면 돌아옵니다.\n\n보상: 층마다 심연석, 처음 닿은 %d층마다 별의 파편 (100층마다 %s개)\n기록: 최고 %d층 · 오늘 %d층" % [
		seed, roundi(Balance.ABYSS_TIME_LIMIT), Balance.ABYSS_MONSTERS, Balance.ABYSS_BOSS_INTERVAL, Balance.ABYSS_HP_GROWTH,
		", ".join(first), Abyss.runs, Balance.ABYSS_RUNS_PER_DAY, Balance.ABYSS_BOSS_INTERVAL,
		Num.format(Balance.ABYSS_STARS_PER_HUNDRED), Abyss.best_floor, Abyss.today_best]


func _refresh() -> void:
	visible = Abyss.is_unlocked() and (Abyss.active or not Game.in_tower)  # 탑 안에서는 숨는다
	_layout()
	_curse_label.visible = Abyss.active
	if Abyss.active:
		_button.text = "%d층 · 나가기" % Abyss.floor
		_button.disabled = false
		_button.theme_type_variation = ""
		_curse_label.text = _curse_text()
		return
	_button.text = "심연 · 원정 %d" % Abyss.runs
	_button.disabled = not Abyss.can_enter()
	_button.theme_type_variation = "AccentButton" if not _button.disabled else ""


## "저주: 단단한 껍질 · 침묵  |  축복 2". 저주가 없으면(정화) "저주 없음"
func _curse_text() -> String:
	var names: Array[String] = []
	for curse in Abyss.curses:
		var name := Balance.abyss_curse_name(curse)
		if curse == Balance.Curse.SEAL and Abyss.seal_target >= 0:
			name += "(%s)" % Balance.companion_name(Abyss.seal_target)
		names.append(name)
	var text := "저주: " + " · ".join(names) if not names.is_empty() else "저주 없음"
	var blessings := Abyss.fury + Abyss.time_blessings + Abyss.removed.size()
	for count in Abyss.bond:
		blessings += count
	return text + ("  |  축복 %d" % blessings if blessings > 0 else "")
