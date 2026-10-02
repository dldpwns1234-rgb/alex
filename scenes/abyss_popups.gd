extends Node
## 심연의 창과 알림 (GDD 7.13절): 10층마다 축복 셋 중 하나를 고르는 창(고르기 전에는 닫히지 않고 전투가 멈춘다),
## 두목 층 돌파("심연 10층 돌파 · 이번 원정 심연석 +25 · 별의 파편 +1")와 원정 끝 알림 (층마다 띄우면 앞 층이 몇 초씩이라 알림이 밀린다). Abyss의 시그널을 받아 표시하고 고른 것만 Abyss.choose_blessing()으로 넘긴다.
## main.gd가 알림(toast.gd)을 넘겨 만든다. 상수는 배치용이다.

const Toast := preload("res://scenes/toast.gd")

const DIALOG_SIZE := Vector2i(620, 420)
const CHOICE_HEIGHT: float = 104.0
const CHOICE_GAP: int = 12
const ABYSS_TOAST_COLOR := Color("b9a2ff")  # 심연 배경의 보랏빛 달

var _toast: Toast
var _dialog: AcceptDialog
var _choices: Array[Button] = []
var _note: Label
var _run_stones: float = 0.0  # 이번 원정에서 받은 심연석


func _init(toast: Toast) -> void:
	_toast = toast


func _ready() -> void:
	_dialog = AcceptDialog.new()
	_dialog.dialog_close_on_escape = false
	_dialog.get_ok_button().visible = false  # 셋 중 하나를 눌러야 닫힌다
	_dialog.canceled.connect(_reopen)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", CHOICE_GAP)
	_note = Label.new()  # 대화 상자의 글(dialog_text)은 더한 자식과 겹쳐 그려져서 줄 하나로 따로 둔다
	_note.text = "이번 원정에서만 듣는다. 고르는 동안 시간이 멈춘다."
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER  # 줄바꿈을 켜면 폭 0에서 최소 높이가 창을 화면만큼 키운다
	column.add_child(_note)
	for i in Balance.ABYSS_BLESSING_CHOICES:
		var button := Button.new()
		button.custom_minimum_size = Vector2(0.0, CHOICE_HEIGHT)
		button.clip_text = true  # 줄바꿈(autowrap)을 켜면 폭 0에서 최소 높이가 화면만큼 커진다. 글은 두 줄로 직접 나눈다
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.pressed.connect(_on_choice.bind(i))
		column.add_child(button)
		_choices.append(button)
	_dialog.add_child(column)
	add_child(_dialog)
	Abyss.blessing_offered.connect(_on_offered)
	Abyss.floor_cleared.connect(_on_floor_cleared)
	Abyss.floor_started.connect(func(floor: int) -> void: _run_stones = 0.0 if floor == 1 else _run_stones)
	Abyss.failed.connect(_on_failed)
	Abyss.abyss_changed.connect(_on_abyss_changed)


func _on_offered(offers: Array) -> void:
	_dialog.title = "심연 %d층 돌파 · 축복을 하나 고른다" % (Abyss.floor - 1)
	for i in _choices.size():
		_choices[i].visible = i < offers.size()
		if i < offers.size():
			_choices[i].text = blessing_text(offers[i])
	_dialog.popup_centered(DIALOG_SIZE)


## 축복 하나의 글: "분노 · 클릭 피해 ×1.5"
static func blessing_text(offer: Dictionary) -> String:
	var target: int = offer["target"]
	var type := int(offer["type"])
	var name := Balance.abyss_blessing_name(type)
	match type:
		Balance.Blessing.FURY:
			return "%s\n클릭 피해 ×%s" % [name, Balance.ABYSS_FURY_MULTIPLIER]
		Balance.Blessing.BOND:
			if target < 0:
				return "%s\n함께할 동료가 없다" % name
			return "%s\n%s 피해 ×%d" % [name, Balance.companion_name(target), roundi(Balance.ABYSS_BOND_MULTIPLIER)]
		Balance.Blessing.CLEANSE:
			if target < 0:
				return "%s\n지울 저주가 없다" % name
			return "%s\n저주 '%s'(%s)가 더는 붙지 않는다" % [name, Balance.abyss_curse_name(target), Balance.abyss_curse_note(target)]
	return "%s\n층 제한 시간 +%d초" % [name, roundi(Balance.ABYSS_TIME_BLESSING)]


func _on_choice(index: int) -> void:
	if Abyss.choose_blessing(index):
		_dialog.hide()


## 닫기를 눌러도 고르기 전에는 다시 띄운다 (원정을 그만두면 Abyss가 고르기를 지운다)
func _reopen() -> void:
	if Abyss.paused():
		_dialog.call_deferred("popup_centered", DIALOG_SIZE)


## 원정이 끝나면(나가기·회귀) 창도 닫는다
func _on_abyss_changed() -> void:
	if not Abyss.paused() and _dialog.visible:
		_dialog.hide()


func _on_floor_cleared(floor: int, stones: float, stars: float) -> void:
	_run_stones += stones
	if not Balance.abyss_is_boss_floor(floor):
		return
	var reward := " · 이번 원정 심연석 +%s" % Num.format(_run_stones)
	if stars > 0.0:
		reward += " · 별의 파편 +%s" % Num.format(stars)
	_toast.show_message("심연 %d층 돌파%s" % [floor, reward], ABYSS_TOAST_COLOR)


func _on_failed(floor: int) -> void:
	_toast.show_message("심연 %d층에서 돌아왔다 · 심연석 +%s · 최고 %d층" % [floor, Num.format(_run_stones), Abyss.best_floor], ABYSS_TOAST_COLOR)
