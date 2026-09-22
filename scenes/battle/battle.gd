extends Control
## 전투 화면 (GDD 3·9절). 왼쪽에 동료 4명, 오른쪽에 몬스터. 화면 어디를 탭해도 용사가 공격한다.
## 도형은 MonsterView와 PartyView가 그리고, 여기서는 배치, 탭 입력, 동료 공격 연출의 타이밍을 맡는다.

const MonsterView := preload("res://scenes/battle/monster_view.gd")
const PartyView := preload("res://scenes/battle/party_view.gd")

const BACKGROUND_COLOR := Color("2a2438")
const TAP_TEXT_COLOR := Color("ffe66d")
const PARTY_TEXT_COLOR := Color("dfe3ea")
const CRIT_TEXT_COLOR := Color("ff8c42")
const EDGE_MARGIN: float = 16.0
const LABEL_HEIGHT: float = 44.0
const PARTY_X: float = 0.06         # 동료 열의 왼쪽 여백 (화면 폭 비율)
const MONSTER_X: float = 0.68       # 몬스터 중심의 가로 위치 (화면 폭 비율)
const ATTACK_INTERVAL: float = 1.0  # 동료 공격 연출 주기 (GDD 3절: 약 1초)
const CHALLENGE_BUTTON_SIZE := Vector2(300, 80)

var _monster_view: MonsterView
var _party_view: PartyView
var _kill_label: Label
var _challenge_button: Button
var _attack_clocks: Array[float] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	resized.connect(_layout)
	Game.monster_spawned.connect(_on_monster_spawned)
	Game.monster_damaged.connect(_monster_view.set_hp)
	Game.tap_hit.connect(_on_tap_hit)
	Game.monster_killed.connect(_on_monster_killed)
	Game.boss_failed.connect(_monster_view.die)
	Game.kills_changed.connect(_refresh_progress.unbind(1))
	Game.stage_changed.connect(_refresh_progress.unbind(1))
	Game.farming_changed.connect(_on_farming_changed)
	Game.boss_queued_changed.connect(_refresh_challenge_button.unbind(1))
	Party.companion_changed.connect(_on_companion_changed)
	_layout()
	# 오토로드가 먼저 준비돼 있으므로 현재 상태를 직접 읽어 채운다
	_on_monster_spawned(Game.monster_max_hp, Game.is_boss_stage())
	_monster_view.set_hp(Game.monster_hp)
	_refresh_progress()
	_on_farming_changed(Game.farming)
	for i in Party.companion_levels.size():
		_on_companion_changed(i, Party.companion_levels[i])


## 동료 공격 연출: 고용한 동료마다 약 1초에 한 번 튀어나가며 그동안 준 피해를 숫자로 띄운다
func _process(delta: float) -> void:
	if not Game.is_monster_alive():
		return
	for i in _attack_clocks.size():
		if not Party.is_companion_hired(i):
			continue
		_attack_clocks[i] += delta
		if _attack_clocks[i] < ATTACK_INTERVAL:
			continue
		_attack_clocks[i] -= ATTACK_INTERVAL
		_party_view.play_attack(i)
		var amount := Party.companion_dps(i, Game.is_boss_stage()) * ATTACK_INTERVAL
		# 궁수의 치명타는 연출만 한다 (GDD 6절). 피해는 이미 기대값이다
		if i == Balance.Companion.ARCHER and randf() < Balance.ARCHER_CRIT_CHANCE:
			_monster_view.pop("치명타! " + Num.format(amount), CRIT_TEXT_COLOR)
		else:
			_monster_view.pop(Num.format(amount), PARTY_TEXT_COLOR)


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		Game.tap_attack()
		accept_event()


func _build() -> void:
	var background := ColorRect.new()
	background.color = BACKGROUND_COLOR
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	_party_view = PartyView.new()
	add_child(_party_view)
	_monster_view = MonsterView.new()
	add_child(_monster_view)

	_kill_label = Label.new()
	_kill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_kill_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_kill_label)

	# 파밍 중에만 보인다. 버튼이 탭을 삼키므로 누를 때 공격이 나가지 않는다
	_challenge_button = Button.new()
	_challenge_button.size = CHALLENGE_BUTTON_SIZE
	_challenge_button.pressed.connect(Game.challenge_boss)
	add_child(_challenge_button)

	_attack_clocks.resize(Balance.COMPANIONS.size())
	for i in _attack_clocks.size():
		_attack_clocks[i] = i * ATTACK_INTERVAL / _attack_clocks.size()  # 동료끼리 박자를 엇갈리게


## 전투 화면 크기가 정해지면 (그리고 바뀌면) 다시 배치한다
func _layout() -> void:
	var center_y := size.y * 0.5
	_party_view.position = Vector2(size.x * PARTY_X, center_y - _party_view.size.y * 0.5)
	_monster_view.position = Vector2(
		size.x * MONSTER_X - _monster_view.size.x * 0.5, center_y - _monster_view.size.y * 0.5)
	_kill_label.position = Vector2(EDGE_MARGIN, EDGE_MARGIN)
	_kill_label.size = Vector2(size.x - EDGE_MARGIN * 2.0, LABEL_HEIGHT)
	_challenge_button.position = Vector2(
		(size.x - CHALLENGE_BUTTON_SIZE.x) * 0.5, size.y - CHALLENGE_BUTTON_SIZE.y - EDGE_MARGIN)


func _on_monster_spawned(max_hp: float, boss: bool) -> void:
	_monster_view.spawn(max_hp, boss)


func _on_tap_hit(amount: float, crit: bool) -> void:
	if crit:
		_monster_view.pop("치명타! " + Num.format(amount), CRIT_TEXT_COLOR)
	else:
		_monster_view.pop(Num.format(amount), TAP_TEXT_COLOR)
	_monster_view.hit_flash()


func _on_monster_killed(_reward: float) -> void:
	_monster_view.die()


func _refresh_progress() -> void:
	if Game.is_boss_stage():
		_kill_label.text = "보스전"
	elif Game.farming:
		_kill_label.text = "파밍 중 · 처치 %d / %d" % [Game.kills, Balance.MONSTERS_PER_STAGE]
	else:
		_kill_label.text = "처치 %d / %d" % [Game.kills, Balance.MONSTERS_PER_STAGE]


func _on_farming_changed(farming: bool) -> void:
	_challenge_button.visible = farming
	_refresh_challenge_button()
	_refresh_progress()


func _refresh_challenge_button() -> void:
	_challenge_button.text = "보스 대기 중 (취소)" if Game.boss_queued else "보스 도전"


func _on_companion_changed(index: int, level: int) -> void:
	_party_view.set_hired(index, level > 0)
