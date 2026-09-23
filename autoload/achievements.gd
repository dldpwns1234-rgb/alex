extends Node
## 업적 (GDD 7.5절). 누적 통계(역대 최고 스테이지, 처치, 보스 처치, 획득 골드, 탭, 회귀, 스킬 사용, 용사 레벨, 동료 수, 환생)는
## 회귀와 환생을 해도 남고 데이터 초기화에서만 지운다. 통계가 목표에 닿으면 업적이 열리고 영구 보너스가 붙는다.
## 통계는 Game·Party·Prestige·Skills의 시그널로 모은다 (오토로드 순서상 그 뒤에 있어 _ready에서 연결한다).
## 탭 수(Game)와 오프라인 골드(Save)만 직접 add()로 더한다. 효과는 damage_multiplier()·gold_multiplier()로
## Party·Game·Save가 자기 공식에 곱한다. 상태 변경은 이 오토로드의 함수로만 하고 UI는 표시만 한다.

signal stat_changed(stat: int, value: float)
signal unlocked(index: int)   # 새로 달성한 업적. 알림과 탭 점에 쓴다
signal seen_changed()

var stats: Array[float] = []  # Balance.Stat 순서. 골드처럼 큰 수가 있어 전부 float
var seen_count: int = 0       # 업적 탭에서 본 달성 수. 그보다 많이 달성했으면 탭에 점을 찍는다
var _unlocked: Array[bool] = []
var _multipliers: Array[float] = []  # Balance.Reward 순서. 달성이 바뀔 때만 다시 계산한다


func _ready() -> void:
	reset()
	Game.stage_changed.connect(_on_stage_changed)
	Game.monster_killed.connect(_on_monster_killed)
	Party.hero_changed.connect(_on_hero_changed)
	Party.companion_changed.connect(_on_companion_changed)
	Prestige.prestiged.connect(_on_prestiged)
	Rebirth.reborn.connect(_on_reborn)
	Skills.skill_activated.connect(_on_skill_activated)


## 데이터 초기화에서만 부른다. 회귀는 아무것도 지우지 않는다
func reset() -> void:
	stats.clear()
	stats.resize(Balance.STAT_LABELS.size())
	stats.fill(0.0)
	seen_count = 0
	_recount()
	for i in stats.size():
		stat_changed.emit(i, 0.0)
	seen_changed.emit()


func to_dict() -> Dictionary:
	return {"stats": stats.duplicate(), "seen_count": seen_count}


## 없는 필드는 0으로. 업적이 없던 옛 저장도 회귀 기록에서 시작하도록 Prestige 다음에 불러야 한다 (Save.from_dict).
## 통계가 늘어나면 새 항목은 0
func from_dict(data: Dictionary) -> void:
	reset()
	var saved: Variant = data.get("stats", [])
	if saved is Array:
		for i in mini(saved.size(), stats.size()):
			stats[i] = maxf(float(saved[i]), 0.0)
	stats[Balance.Stat.STAGE] = maxf(stats[Balance.Stat.STAGE], float(Prestige.best_stage))
	stats[Balance.Stat.PRESTIGES] = maxf(stats[Balance.Stat.PRESTIGES], float(Prestige.prestige_count))
	_recount()
	seen_count = clampi(int(data.get("seen_count", 0)), 0, unlocked_count())
	for i in stats.size():
		stat_changed.emit(i, stats[i])
	seen_changed.emit()


## 누적 통계에 더한다 (처치, 골드, 탭, 스킬)
func add(stat: int, amount: float) -> void:
	if amount > 0.0:
		_set_stat(stat, stats[stat] + amount)


## 최고 기록 통계를 올린다 (스테이지, 회귀, 용사 레벨, 동료 수). 낮은 값은 무시한다
func raise(stat: int, value: float) -> void:
	if value > stats[stat]:
		_set_stat(stat, value)


func value(stat: int) -> float:
	return stats[stat]


func is_unlocked(index: int) -> bool:
	return _unlocked[index]


## 목표 대비 진행 (0~1)
func progress(index: int) -> float:
	return clampf(stats[Balance.achievement_stat(index)] / Balance.achievement_goal(index), 0.0, 1.0)


func unlocked_count() -> int:
	return _unlocked.count(true)


## 업적 탭을 열지 않은 새 달성이 있는지 (탭 점)
func has_unseen() -> bool:
	return unlocked_count() > seen_count


## 업적 탭을 열면 부른다
func mark_seen() -> void:
	seen_count = unlocked_count()
	seen_changed.emit()


## 모든 피해 배율: 1 + 달성한 피해 보너스의 합
func damage_multiplier() -> float:
	return _multipliers[Balance.Reward.DAMAGE]


## 처치 골드 배율 (오프라인 보상 포함): 1 + 달성한 골드 보너스의 합
func gold_multiplier() -> float:
	return _multipliers[Balance.Reward.GOLD]


## 통계를 바꾸고, 새로 목표에 닿은 업적을 연다. 배율을 먼저 갱신한 뒤 알리므로 받는 쪽은 새 배율을 본다
func _set_stat(stat: int, value: float) -> void:
	var before := stats[stat]
	stats[stat] = value
	var fresh: Array[int] = []
	for i in Balance.ACHIEVEMENTS.size():
		var goal := Balance.achievement_goal(i)
		if Balance.achievement_stat(i) == stat and before < goal and value >= goal:
			fresh.append(i)
	if not fresh.is_empty():
		_recount()
	stat_changed.emit(stat, value)
	for i in fresh:
		unlocked.emit(i)


func _recount() -> void:
	_unlocked.clear()
	_unlocked.resize(Balance.ACHIEVEMENTS.size())
	for i in _unlocked.size():
		_unlocked[i] = stats[Balance.achievement_stat(i)] >= Balance.achievement_goal(i)
	_multipliers.clear()
	for reward in Balance.REWARD_LABELS.size():
		_multipliers.append(Balance.achievement_multiplier(reward, _unlocked))


## 스테이지가 바뀔 때마다 이번 판 최고 스테이지를 본다 (불러온 저장의 최고 스테이지도 여기서 잡힌다)
func _on_stage_changed(_stage: int) -> void:
	raise(Balance.Stat.STAGE, float(Game.highest_stage))


## 처치 직후라 아직 그 스테이지다: 보스 스테이지면 보스를 잡은 것
func _on_monster_killed(reward: float) -> void:
	add(Balance.Stat.KILLS, 1.0)
	if Game.is_boss_stage():
		add(Balance.Stat.BOSS_KILLS, 1.0)
	add(Balance.Stat.GOLD, reward)


func _on_hero_changed(level: int) -> void:
	raise(Balance.Stat.HERO_LEVEL, float(level))


## 동시에 고용한 동료 수
func _on_companion_changed(_index: int, _level: int) -> void:
	var hired := 0
	for level in Party.companion_levels:
		if level > 0:
			hired += 1
	raise(Balance.Stat.PARTY, float(hired))


## 회귀 횟수는 환생을 넘어 누적한다. 역대 최고 스테이지도 회귀 기록에 맞춘다
func _on_prestiged(_reward: float) -> void:
	add(Balance.Stat.PRESTIGES, 1.0)
	raise(Balance.Stat.STAGE, float(Prestige.best_stage))


func _on_reborn(_reward: float) -> void:
	add(Balance.Stat.REBIRTHS, 1.0)


func _on_skill_activated(_index: int) -> void:
	add(Balance.Stat.SKILLS, 1.0)
