extends Node
## 스킬 상태와 효과 (GDD 5절). 지속 시간과 쿨타임은 실제 시간(유닉스 초) 기준이라 자리를 비워도 흐른다.
## Game·Party가 200줄을 넘지 않도록 나눴다. 상태 변경은 Game·Party·Skills의 함수로만 한다.

signal skill_activated(index: int)

var activated_at: Array[float] = []  # 스킬별 마지막 발동 시각 (유닉스 초). 0이면 아직 쓴 적 없음
var clock_override: float = -1.0     # 시뮬레이션이 켠다: 0 이상이면 유닉스 시각 대신 이 값을 지금 시각으로 쓴다
var _storm_clicks: float = 0.0       # 폭풍 베기 자동 클릭 누적


func _ready() -> void:
	reset()


## 폭풍 베기: 활성 동안 초당 10회 탭 공격
func _process(delta: float) -> void:
	if not is_active(Balance.Skill.STORM_SLASH):
		_storm_clicks = 0.0
		return
	var per_second := Balance.STORM_SLASH_CLICKS_PER_SECOND + Training.value(Balance.Effect.STORM_CLICKS)
	_storm_clicks += minf(delta, Balance.MAX_DELTA) * per_second
	while _storm_clicks >= 1.0:
		_storm_clicks -= 1.0
		Game.tap_attack(true)


## 새 판 시작 상태. 회귀(M5)와 데이터 초기화에서 쿨타임도 지운다
func reset() -> void:
	activated_at.clear()
	activated_at.resize(Balance.SKILLS.size())
	activated_at.fill(0.0)
	_storm_clicks = 0.0


func to_dict() -> Dictionary:
	return {"activated_at": activated_at.duplicate()}


## 없는 필드는 0(쓴 적 없음)으로. 발동 시각이 유닉스 초라서 불러온 뒤에도 쿨타임이 이어진다
func from_dict(data: Dictionary) -> void:
	reset()
	var saved: Variant = data.get("activated_at", [])
	if saved is Array:
		for i in mini(saved.size(), activated_at.size()):
			activated_at[i] = maxf(float(saved[i]), 0.0)


func is_unlocked(index: int) -> bool:
	return Party.hero_level >= Balance.skill_unlock_level(index)


func is_active(index: int) -> bool:
	return activated_at[index] > 0.0 and _now() < activated_at[index] + duration()


## 지속 시간: 30초 + 각성의 잔향 단련
func duration() -> float:
	return Balance.SKILL_DURATION + Training.value(Balance.Effect.SKILL_DURATION)


## 쿨타임: 5분 × 명상 × 마나 순환 단련 × 침묵의 검 보너스
func cooldown() -> float:
	var base := Balance.skill_cooldown(Prestige.effect_level(Balance.Memory.MEDITATION))
	return base * (1.0 - Training.value(Balance.Effect.SKILL_COOLDOWN)) * Challenges.cooldown_multiplier()


## 남은 지속 시간 (초)
func active_left(index: int) -> float:
	if not is_active(index):
		return 0.0
	return activated_at[index] + duration() - _now()


## 남은 쿨타임 (초)
func cooldown_left(index: int) -> float:
	if activated_at[index] <= 0.0:
		return 0.0
	return maxf(activated_at[index] + cooldown() - _now(), 0.0)


func is_ready(index: int) -> bool:
	return cooldown_left(index) <= 0.0


## 침묵의 검 도전 중에는 봉인된다
func is_sealed() -> bool:
	return Challenges.blocks_skills()


func can_activate(index: int) -> bool:
	return is_unlocked(index) and is_ready(index) and not is_sealed()


## 발동. 해금 전이거나 쿨타임 중이면 false
func activate(index: int) -> bool:
	if not can_activate(index):
		return false
	activated_at[index] = _now()
	skill_activated.emit(index)
	return true


## 전투의 함성: 활성 동안 동료 공격력 ×(2 + 함성 공명 단련)
func party_multiplier() -> float:
	if not is_active(Balance.Skill.BATTLE_CRY):
		return 1.0
	return Balance.BATTLE_CRY_MULTIPLIER + Training.value(Balance.Effect.BATTLE_CRY)


## 황금 손길: 활성 동안 처치 골드 ×(2 + 기적 단련)
func gold_multiplier() -> float:
	if not is_active(Balance.Skill.GOLDEN_TOUCH):
		return 1.0
	return Balance.GOLDEN_TOUCH_MULTIPLIER + Training.value(Balance.Effect.GOLDEN_TOUCH)


func _now() -> float:
	return clock_override if clock_override >= 0.0 else Time.get_unix_time_from_system()
