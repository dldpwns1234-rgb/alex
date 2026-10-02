extends "res://autoload/sfx/player.gd"
## 효과음과 배경음 (GDD 11절). 게임 오토로드의 시그널만 받아 소리를 낸다. 게임 상태는 바꾸지 않는다.
## 재생·버스·배경음·웹 잠금은 sfx/player.gd(1부)에 있다.
## 구매 소리(용사 레벨업, 동료·단련·상점·운명·장비 강화)는 버튼을 누른 그 프레임에 오른 레벨에만 낸다: 동료 자동 강화, 불러오기,
## 회귀 뒤 초기화가 레벨을 바꿀 때는 조용하다. 내려갈 때(새 판)는 기록만 고친다. 버튼은 트리에 들어올 때 pressed를 잇는다 (탭 파일을 고치지 않는다)

var _levels: Dictionary = {}     # "hero", "c0", "t3" … → 마지막으로 본 레벨
var _button_frame: int = -1      # 마지막으로 버튼이 눌린 프레임
var _pending: Dictionary = {}    # 버튼 시그널보다 먼저 오른 레벨의 소리 → 그 프레임


func _ready() -> void:
	super()
	Game.tap_hit.connect(_on_tap_hit)
	Game.monster_killed.connect(_on_monster_killed)
	Game.chain_killed.connect(func(_count: int, _reward: float) -> void: play("kill"))
	Game.monster_spawned.connect(_on_monster_spawned)
	Game.boss_failed.connect(play.bind("boss_fail"))
	Game.stage_changed.connect(func(_stage: int) -> void: _update_music())
	Party.hero_changed.connect(func(level: int) -> void: _on_level("hero", level, "level_up"))
	Party.companion_changed.connect(func(index: int, level: int) -> void: _on_level("c%d" % index, level, "buy"))
	Training.training_changed.connect(func(index: int, level: int) -> void: _on_level("t%d" % index, level, "buy"))
	Prestige.memory_changed.connect(func(index: int, level: int) -> void: _on_level("m%d" % index, level, "buy"))
	Rebirth.fate_changed.connect(func(index: int, level: int) -> void: _on_level("f%d" % index, level, "buy"))
	Equipment.equipment_changed.connect(func(slot: int) -> void: _on_level("e%d" % slot, Equipment.enhance_levels[slot], "buy"))
	Promotions.promoted.connect(func(_index: int, _rank: int) -> void: play("promote"))
	Skills.skill_activated.connect(func(_index: int) -> void: play("skill"))
	Achievements.unlocked.connect(func(_index: int) -> void: play("achievement"))
	Challenges.completed.connect(func(_index: int) -> void: play("achievement"))
	Equipment.item_dropped.connect(_on_item)
	Equipment.item_crafted.connect(_on_item)
	Prestige.prestiged.connect(func(_reward: float) -> void: play("prestige"))
	Rebirth.reborn.connect(func(_reward: float) -> void: play("rebirth"))
	Transcend.transcended.connect(func(_reward: float) -> void: play("rebirth"))
	Treasure.appeared.connect(func(_duration: float) -> void: play("fairy_appear"))
	Treasure.caught.connect(func(_reward: int, _amount: float) -> void: play("fairy_catch"))
	Tower.floor_cleared.connect(func(_floor: int, _stones: float, _threads: float) -> void: play("boss_kill"))
	Tower.failed.connect(func(_floor: int) -> void: play("boss_fail"))
	get_tree().node_added.connect(_on_node_added)
	set_process_input(not unlocked)
	_update_music()


## 웹이면 첫 누름이 소리를 연다 (브라우저의 자동 재생 막기). 열린 뒤에는 입력을 보지 않는다
func _input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventKey) and event.is_pressed():
		unlock()
		set_process_input(false)


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		(node as BaseButton).pressed.connect(note_button_press)


## 버튼이 눌렸다. 같은 프레임에 먼저 오른 레벨이 있으면 지금 소리를 낸다
func note_button_press() -> void:
	_button_frame = Engine.get_process_frames()
	for cue: String in _pending:
		if int(_pending[cue]) == _button_frame:
			play(cue)
	_pending.clear()


## 지금 스테이지에 맞는 곡: 마왕성(600부터)은 어두운 곡
func _update_music() -> void:
	set_music_track("castle" if Balance.is_castle_stage(Game.stage) else "field")


func _on_tap_hit(_amount: float, crit: bool) -> void:
	play("crit" if crit else "tap")


## 보스(마왕 포함)를 잡으면 팡파르. 시그널은 스테이지가 넘어가기 전에 온다
func _on_monster_killed(_reward: float) -> void:
	play("boss_kill" if Game.is_boss_stage() else "kill")


func _on_monster_spawned(_max_hp: float, boss: bool) -> void:
	if boss:
		play("boss_appear")


func _on_item(_slot: int, _grade: int, _stage: int, _equipped: bool) -> void:
	play("item")


## 레벨이 오르면 같은 프레임에 버튼이 눌렸을 때만 소리. 버튼 시그널이 아직이면 기다린다. 처음 보는 열쇠는 0에서 시작한 것으로 친다
func _on_level(key: String, level: int, cue: String) -> void:
	var before := int(_levels.get(key, 0))
	_levels[key] = level
	if level <= before:
		return
	var frame := Engine.get_process_frames()
	if frame == _button_frame:
		play(cue)
	else:
		_pending[cue] = frame
