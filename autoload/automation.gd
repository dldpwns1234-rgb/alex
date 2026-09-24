extends Node
## 자동화 (GDD 7.7절 운명의 상점): 자동 회귀, 결정 자동 구매, 스킬 자동 사용. 운명의 상점에서 해금했을 때만 동작한다.
## 켜고 끄는 설정은 저장되고 회귀·환생해도 남는다 (데이터 초기화에서만 기본값으로). 상태 변경은 Prestige·Skills의 함수로만 한다.

signal settings_changed()

var enabled: Array[bool] = []   # Balance.Auto 순서. 기본은 켬이라 운명을 사는 순간부터 동작한다
var _stall: float = 0.0         # 최고 스테이지가 오르지 않은 시간 (게임 시간, 초)
var _best_seen: int = 0


func _ready() -> void:
	reset()
	Game.stage_changed.connect(_on_stage_changed)
	Prestige.prestiged.connect(_on_new_run)
	Rebirth.reborn.connect(_on_new_run)


## 정체 시계를 재고, 자동 회귀와 자동 스킬을 돌린다. 보스와 싸우는 중이거나 도전 판이면 회귀하지 않는다 (판이 끊기는 느낌을 막는다)
func _process(delta: float) -> void:
	_stall += minf(delta, Balance.MAX_DELTA)
	if is_active(Balance.Auto.PRESTIGE) and Prestige.can_prestige() and _stall >= Balance.AUTO_PRESTIGE_STALL \
			and not _boss_alive() and Challenges.active < 0:
		Prestige.perform()
	if is_active(Balance.Auto.SKILLS):
		use_skills()


## 데이터 초기화에서만 부른다 (회귀·환생은 설정을 남긴다)
func reset() -> void:
	enabled.clear()
	enabled.resize(Balance.AUTO_NAMES.size())
	enabled.fill(true)
	_restart_clock()
	settings_changed.emit()


func to_dict() -> Dictionary:
	return {"enabled": enabled.duplicate()}


## 없는 필드는 켬으로 (옛 저장 호환). Game을 불러온 뒤에 불러 정체 시계가 이번 판 최고에서 시작한다
func from_dict(data: Dictionary) -> void:
	reset()
	var saved: Variant = data.get("enabled", [])
	if saved is Array:
		for i in mini(saved.size(), enabled.size()):
			enabled[i] = bool(saved[i])
	settings_changed.emit()


func is_enabled(kind: int) -> bool:
	return enabled[kind]


func is_unlocked(kind: int) -> bool:
	return Rebirth.has_fate(Balance.auto_fate(kind))


## 켜져 있고 운명의 상점에서 해금했으면 동작한다
func is_active(kind: int) -> bool:
	return enabled[kind] and is_unlocked(kind)


func set_enabled(kind: int, on: bool) -> void:
	if enabled[kind] == on:
		return
	enabled[kind] = on
	settings_changed.emit()


## 최고 스테이지가 오르지 않은 시간 (표시용)
func stall_seconds() -> float:
	return _stall


## 결정을 싼 것부터 산다 (같으면 앞의 것). 루트 탐색에서 가장 빠른 결정 사용 계획이다 (docs/BALANCE_SIM.md)
func buy_memories() -> void:
	while true:
		var pick := -1
		for i in Balance.MEMORIES.size():
			if Prestige.can_buy(i) and (pick < 0 or Prestige.memory_cost(i) < Prestige.memory_cost(pick)):
				pick = i
		if pick < 0 or not Prestige.buy(pick):
			return


## 쿨타임이 끝난 스킬을 바로 쓴다
func use_skills() -> void:
	for i in Balance.SKILLS.size():
		if Skills.can_activate(i):
			Skills.activate(i)


## 새 스테이지에 닿으면 정체 시계를 되돌린다. 보스 실패로 돌아갔다 다시 오른 것은 진행이 아니다
func _on_stage_changed(stage: int) -> void:
	if stage > _best_seen:
		_best_seen = stage
		_stall = 0.0


## 회귀·환생 직후: 시작 스테이지가 기준이 되고, 결정 자동 구매가 켜져 있으면 바로 산다
func _on_new_run(_reward: float) -> void:
	_restart_clock()
	if is_active(Balance.Auto.MEMORIES):
		buy_memories()


func _restart_clock() -> void:
	_best_seen = Game.highest_stage
	_stall = 0.0


func _boss_alive() -> bool:
	return Game.is_boss_stage() and Game.is_monster_alive()
