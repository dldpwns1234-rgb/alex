extends Control
## 전투 화면 (GDD 3·9절). 왼쪽에 동료 4명과 용사, 오른쪽에 몬스터. 화면 어디를 탭해도 용사가 공격한다.
## 그림은 Backdrop, MonsterView, PartyView, Stage(궤적·섬광·흔들림)가 그리고, 여기서는 배치, 탭 입력, 연출 타이밍을 맡는다.

const Stage := preload("res://scenes/battle/stage.gd")
const Backdrop := preload("res://scenes/battle/backdrop.gd")
const MonsterView := preload("res://scenes/battle/monster_view.gd")
const PartyView := preload("res://scenes/battle/party_view.gd")
const BossControls := preload("res://scenes/battle/boss_controls.gd")
const Zones := preload("res://scenes/battle/zones.gd")

const TAP_TEXT_COLOR := Color("ffe66d")
const PARTY_TEXT_COLOR := Color("dfe3ea")
const CRIT_TEXT_COLOR := Color("ff8c42")
const EDGE_MARGIN: float = 16.0
const LABEL_HEIGHT: float = 44.0
const MONSTER_X: float = 0.68       # 몬스터 중심의 가로 위치 (화면 폭 비율)
const ATTACK_INTERVAL: float = 1.0  # 동료 공격 연출 주기 (GDD 3절: 약 1초)
const BOSS_ESCAPE_DURATION: float = 0.5
# 탭 한 번의 박자: 용사가 달려든 뒤 칼이 몬스터를 지나는 순간 자국과 타격이 함께 나온다
const TAP_LAND_DELAY: float = 0.08
const FLURRY_GAP: float = 0.18  # 초. 이보다 빨리 이어지는 탭은 난무: 자국은 작고 짧게, 몬스터는 굳지 않는다
const TAP_SHAKE: float = 3.0
const FLURRY_SHAKE: float = 2.0
const CRIT_SHAKE: float = 8.0
const KILL_SHAKE: float = 5.0
const OUTLINE_SIZE: int = 6
const OUTLINE_COLOR := Color("2b2438")

var _stage: Stage
var _backdrop: Backdrop
var _monster_view: MonsterView
var _downward: bool = true  # 다음 검격이 내려베기인지
var _last_tap_msec: int = 0
var _party_view: PartyView
var _kill_label: Label
var _boss_controls: BossControls
var _attack_clocks: Array[float] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true  # 배경 언덕과 튀어나가는 인물이 전투 화면 밖으로 그려지지 않게
	_build()
	resized.connect(_layout)
	Game.monster_spawned.connect(_on_monster_spawned)
	Game.monster_damaged.connect(_monster_view.set_hp)
	Game.tap_hit.connect(_on_tap_hit)
	Game.monster_killed.connect(_on_monster_killed)
	Game.boss_failed.connect(_monster_view.vanish.bind(BOSS_ESCAPE_DURATION))
	Game.kills_changed.connect(_refresh_progress.unbind(1))
	Game.stage_changed.connect(_refresh_progress.unbind(1))
	Game.farming_changed.connect(_on_farming_changed)
	Party.companion_changed.connect(_on_companion_changed)
	Promotions.promoted.connect(_on_promoted)
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
		_monster_view.hit(false)
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
	_stage = Stage.new()
	add_child(_stage)
	_backdrop = Backdrop.new()
	_stage.add_child(_backdrop)
	_party_view = PartyView.new()
	_stage.add_child(_party_view)
	_monster_view = MonsterView.new()
	_stage.add_child(_monster_view)

	_kill_label = Label.new()
	_kill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_kill_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kill_label.add_theme_constant_override("outline_size", OUTLINE_SIZE)
	_kill_label.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	add_child(_kill_label)

	# 파밍 중에만 보인다. 버튼이 탭을 삼키므로 누를 때 공격이 나가지 않는다
	_boss_controls = BossControls.new()
	add_child(_boss_controls)

	_attack_clocks.resize(Balance.COMPANIONS.size())
	for i in _attack_clocks.size():
		_attack_clocks[i] = i * ATTACK_INTERVAL / _attack_clocks.size()  # 동료끼리 박자를 엇갈리게


## 전투 화면 크기가 정해지면 (그리고 바뀌면) 다시 배치한다. 용사는 몬스터와 같은 땅 선에 선다
func _layout() -> void:
	var center_y := size.y * 0.5
	_monster_view.position = Vector2(
		size.x * MONSTER_X - _monster_view.size.x * 0.5, center_y - _monster_view.size.y * 0.5)
	_party_view.layout(size, _monster_view.position.y + MonsterView.FIGURE_SIZE.y)
	_kill_label.position = Vector2(EDGE_MARGIN, EDGE_MARGIN)
	_kill_label.size = Vector2(size.x - EDGE_MARGIN * 2.0, LABEL_HEIGHT)
	_boss_controls.position = Vector2((size.x - BossControls.CHALLENGE_SIZE.x) * 0.5, EDGE_MARGIN)


func _on_monster_spawned(max_hp: float, boss: bool) -> void:
	_monster_view.spawn(max_hp, boss, Game.stage)
	_backdrop.set_palette(Zones.palette(Game.stage))
	_backdrop.set_castle(Zones.is_castle(Game.stage))


func _on_tap_hit(amount: float, crit: bool) -> void:
	var now := Time.get_ticks_msec()
	var flurry := now - _last_tap_msec < FLURRY_GAP * 1000.0
	_last_tap_msec = now
	_party_view.play_hero_attack(_downward)
	get_tree().create_timer(TAP_LAND_DELAY, false).timeout.connect(_land_tap.bind(amount, crit, flurry, _downward))
	_downward = not _downward


## 칼이 몬스터에 닿는 순간: 검격 자국(치명타는 X자), 숫자, 굳었다 밀리는 몬스터, 접촉 불꽃, 화면 흔들림
func _land_tap(amount: float, crit: bool, flurry: bool, downward: bool) -> void:
	var hand := _party_view.hero_hand()
	var light := flurry and not crit  # 연타 중 보통 타는 부수 연출을 줄인다. 치명타는 그대로 악센트
	_stage.slash(hand, downward, crit, flurry)
	if crit:
		_stage.slash(hand, not downward, crit, flurry)
		_monster_view.pop("치명타! " + Num.format(amount), CRIT_TEXT_COLOR, true)
	else:
		_monster_view.pop(Num.format(amount), TAP_TEXT_COLOR, false, not light)
	_monster_view.hit(true, crit, flurry)
	_stage.impact(_monster_view.position + MonsterView.IMPACT_POINT, crit, false, light)
	_stage.shake(CRIT_SHAKE if crit else (FLURRY_SHAKE if light else TAP_SHAKE))


func _on_monster_killed(_reward: float) -> void:
	_monster_view.die(Game.respawn_delay())
	_stage.impact(_monster_view.position + MonsterView.FIGURE_SIZE * 0.5, false, true)
	_stage.shake(KILL_SHAKE)


func _refresh_progress() -> void:
	if Game.is_boss_stage():
		_kill_label.text = "보스전"
	elif Game.farming:
		_kill_label.text = "파밍 중 · 처치 %d / %d" % [Game.kills, Balance.MONSTERS_PER_STAGE]
	else:
		_kill_label.text = "처치 %d / %d" % [Game.kills, Balance.MONSTERS_PER_STAGE]


func _on_farming_changed(farming: bool) -> void:
	_refresh_progress()


func _on_companion_changed(index: int, level: int) -> void:
	_party_view.set_hired(index, level > 0)


## 승급: 동료가 튀어오르고 흰 고리가 퍼진다
func _on_promoted(index: int, _rank: int) -> void:
	_party_view.celebrate(index)
	_stage.impact(_party_view.companion_center(index), false, true)
