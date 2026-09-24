extends Node
## 도전 판 (GDD 7.9절). 환생 1회부터 연다. 도전을 시작하면 지금 판을 회귀(스테이지 120 이상이면 결정을 받는다)로 끝내고 제한이 걸린
## 새 판이 시작된다. 이번 판 최고가 목표에 닿으면 달성: 고유 보너스가 영구히 붙고 제한이 풀린다. 회귀·환생하면 도전이 풀린다 (다시 할 수 있다).
## 제한은 Party·Skills·Game·Equipment·Prestige가 여기 묻고, 보너스도 여기서 준다. 상태 변경은 이 오토로드의 함수로만 하고 UI는 표시만 한다.

signal challenge_changed()
signal completed(index: int)

var active: int = -1          # 진행 중인 도전 (Balance.CHALLENGES 색인). 없으면 -1. 저장된다
var done: Array[bool] = []    # 달성 여부. 회귀·환생해도 남고 데이터 초기화에서만 지운다


func _ready() -> void:
	reset()
	Game.stage_changed.connect(_on_stage_changed)
	Prestige.prestiged.connect(_on_run_reset)
	Rebirth.reborn.connect(_on_run_reset)


## 데이터 초기화에서만 부른다
func reset() -> void:
	active = -1
	done.clear()
	done.resize(Balance.CHALLENGES.size())
	done.fill(false)
	challenge_changed.emit()


func to_dict() -> Dictionary:
	return {"active": active, "done": done.duplicate()}


## 없는 필드는 기본값으로. 도전이 늘어나면 새 것은 미달성
func from_dict(data: Dictionary) -> void:
	reset()
	active = clampi(int(data.get("active", -1)), -1, done.size() - 1)
	var saved: Variant = data.get("done", [])
	if saved is Array:
		for i in mini(saved.size(), done.size()):
			done[i] = bool(saved[i])
	challenge_changed.emit()


func is_unlocked() -> bool:
	return Rebirth.rebirth_count >= Balance.CHALLENGE_UNLOCK_REBIRTHS


func is_done(index: int) -> bool:
	return done[index]


func is_active(index: int) -> bool:
	return active == index


## 한 번에 하나만, 달성한 것은 다시 못 한다
func can_start(index: int) -> bool:
	return is_unlocked() and not done[index] and active < 0


## 지금 판을 끝내고(회귀할 수 있으면 결정을 받는다) 제한이 걸린 새 판을 시작한다
func start(index: int) -> bool:
	if not can_start(index):
		return false
	if Prestige.can_prestige():
		Prestige.perform()  # prestiged 시그널이 active를 지우므로 그 뒤에 켠다
	else:
		_reset_run()
	active = index
	challenge_changed.emit()
	Save.save_game()
	return true


## 제한을 풀고 판은 그대로 이어 간다. 달성하지 않았으니 다시 할 수 있다
func give_up() -> void:
	if active < 0:
		return
	active = -1
	challenge_changed.emit()
	Save.save_game()


func _reset_run() -> void:
	Party.reset()
	Skills.reset()
	Training.reset()
	Promotions.reset()
	Game.reset()


func _on_run_reset(_reward: float) -> void:
	if active >= 0:
		active = -1
		challenge_changed.emit()


func _on_stage_changed(_stage: int) -> void:
	if active < 0 or Game.highest_stage < Balance.challenge_goal(active):
		return
	var index := active
	done[index] = true
	active = -1
	completed.emit(index)
	challenge_changed.emit()
	Save.save_game()


# 제한. 진행 중인 도전의 제한만 건다

func _restriction() -> int:
	return Balance.challenge_restriction(active) if active >= 0 else -1


func blocks_companions() -> bool:
	return _restriction() == Balance.Restriction.NO_COMPANIONS


func blocks_skills() -> bool:
	return _restriction() == Balance.Restriction.NO_SKILLS


func blocks_equipment() -> bool:
	return _restriction() == Balance.Restriction.NO_EQUIPMENT


func blocks_memories() -> bool:
	return _restriction() == Balance.Restriction.NO_MEMORIES


func boss_time_scale() -> float:
	return Balance.CHALLENGE_BOSS_TIME_SCALE if _restriction() == Balance.Restriction.HALF_BOSS_TIME else 1.0


# 보너스. 달성한 도전의 보너스는 영구히 붙는다

func has_perk(perk: int) -> bool:
	for i in done.size():
		if done[i] and Balance.challenge_perk(i) == perk:
			return true
	return false


func click_multiplier() -> float:
	return 1.0 + Balance.PERK_CLICK_BONUS if has_perk(Balance.Perk.CLICK) else 1.0


func cooldown_multiplier() -> float:
	return 1.0 - Balance.PERK_COOLDOWN_CUT if has_perk(Balance.Perk.COOLDOWN) else 1.0


func boss_time_bonus() -> float:
	return Balance.PERK_BOSS_TIME_SECONDS if has_perk(Balance.Perk.BOSS_TIME) else 0.0


func stone_multiplier() -> float:
	return Balance.PERK_STONE_MULTIPLIER if has_perk(Balance.Perk.STONES) else 1.0


func crystal_multiplier() -> float:
	return 1.0 + Balance.PERK_CRYSTAL_BONUS if has_perk(Balance.Perk.CRYSTALS) else 1.0
