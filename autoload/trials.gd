extends Node
## 별자리 시련 (GDD 7.12절): 도전 판의 제한을 둘씩 묶은 판 5개를 단계 5개까지 다시 깬다. 초월 1회부터.
## 제한은 Challenges가 도전 판의 제한과 합쳐서 묻고(blocks_*), 보상은 Challenges·Transcend가 자기 공식에 곱한다.
## 단계 기록은 초월해도 남고 데이터 초기화에서만 지운다. 상태 변경은 이 오토로드의 함수로만 한다.

signal trial_changed()          # 시작·포기·달성으로 진행 중인 시련이나 단계가 바뀌었다
signal completed(index: int, tier: int)  # tier: 방금 깬 단계 (1부터)

var tiers: Array[int] = []  # 시련마다 깬 단계 수 (0~5)
var active: int = -1         # 진행 중인 시련. 없으면 -1
var _starting: bool = false  # 새 판을 시작하는 중 (도약이 목표를 건너뛰지 않게)


func _ready() -> void:
	reset()
	Game.stage_changed.connect(_on_stage_changed)
	Prestige.prestiged.connect(_on_run_reset)
	Rebirth.reborn.connect(_on_run_reset)
	Transcend.transcended.connect(_on_run_reset)


func reset() -> void:
	tiers.clear()
	tiers.resize(Balance.TRIALS.size())
	tiers.fill(0)
	active = -1
	trial_changed.emit()


func to_dict() -> Dictionary:
	return {"tiers": tiers.duplicate(), "active": active}


func from_dict(data: Dictionary) -> void:
	reset()
	var saved: Variant = data.get("tiers", [])
	if saved is Array:
		for i in mini(saved.size(), tiers.size()):
			tiers[i] = clampi(int(saved[i]), 0, Balance.TRIAL_TIER_SCALES.size())
	active = clampi(int(data.get("active", -1)), -1, tiers.size() - 1)
	trial_changed.emit()


func is_unlocked() -> bool:
	return Transcend.count > 0


func is_maxed(index: int) -> bool:
	return tiers[index] >= Balance.TRIAL_TIER_SCALES.size()


## 이번에 도전할 단계의 목표
func goal(index: int) -> int:
	return Balance.trial_goal(index, tiers[index])


## 한 번에 하나만 (도전 판과도 겹치지 않는다)
func can_start(index: int) -> bool:
	return is_unlocked() and not is_maxed(index) and active < 0 and Challenges.active < 0


## 지금 판을 끝내고(회귀할 수 있으면 결정을 받는다) 제한이 걸린 새 판을 시작한다
func start(index: int) -> bool:
	if not can_start(index):
		return false
	_starting = true
	if Prestige.can_prestige():
		Prestige.perform()  # prestiged 시그널이 active를 지우므로 그 뒤에 켠다
	else:
		Tower.leave()
		Party.reset()
		Skills.reset()
		Training.reset()
		Promotions.reset()
		Game.reset()
	_starting = false
	active = index
	trial_changed.emit()
	Save.save_game()
	return true


func give_up() -> void:
	if active < 0:
		return
	active = -1
	trial_changed.emit()
	Save.save_game()


func is_starting() -> bool:
	return _starting


## 진행 중인 시련이 이 제한을 거는지 (Challenges가 묻는다)
func restricts(restriction: int) -> bool:
	return active >= 0 and Balance.trial_restrictions(active).has(restriction)


# 보상: 깬 단계만큼 쌓인다

func _tiers_of(reward: int) -> int:
	var total := 0
	for i in tiers.size():
		if Balance.trial_reward(i) == reward:
			total += tiers[i]
	return total


func boss_time_bonus() -> float:
	return Balance.TRIAL_BOSS_SECONDS * _tiers_of(Balance.TrialReward.BOSS_TIME)


func click_multiplier() -> float:
	return pow(Balance.TRIAL_CLICK_MULTIPLIER, _tiers_of(Balance.TrialReward.CLICK))


func crystal_multiplier() -> float:
	return pow(Balance.TRIAL_CRYSTAL_MULTIPLIER, _tiers_of(Balance.TrialReward.CRYSTALS))


func stone_multiplier() -> float:
	return 1.0 + Balance.TRIAL_STONE_BONUS * _tiers_of(Balance.TrialReward.STONES)


func star_bonus() -> float:
	return Balance.TRIAL_STAR_BONUS * _tiers_of(Balance.TrialReward.STARS)


func _on_run_reset(_reward: float) -> void:
	if active >= 0:
		active = -1
		trial_changed.emit()


func _on_stage_changed(_stage: int) -> void:
	if active < 0 or Game.highest_stage < goal(active):
		return
	var index := active
	tiers[index] += 1
	active = -1
	completed.emit(index, tiers[index])
	trial_changed.emit()
	Save.save_game()
