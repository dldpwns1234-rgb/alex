extends Node
## 환생 (GDD 7.7절). 역대 최고 스테이지 500에 닿으면 기억의 결정과 상점, 회귀 기록까지 내려놓고 새 삶을 시작한다.
## 운명의 실과 운명의 상점 레벨, 환생 횟수는 환생해도 남는다 (업적·장비도 남는다). 회귀 뒤 시작 스테이지도 여기서 정한다.
## 효과는 damage_multiplier()·crystal_multiplier()·start_stage()로 Party·Prestige·Game이 쓴다.
## 상태 변경은 이 오토로드의 함수로만 하고 UI는 표시만 한다.

signal threads_changed(threads: float)
signal fate_changed(index: int, level: int)
signal reborn(reward: float)

var threads: float = 0.0          # 운명의 실
var fate_levels: Array[int] = []  # 운명의 상점 레벨. Balance.Fate 순서
var rebirth_count: int = 0


func _ready() -> void:
	reset()


## 데이터 초기화에서만 부른다. 환생은 perform()이다
func reset() -> void:
	threads = 0.0
	fate_levels.clear()
	fate_levels.resize(Balance.FATES.size())
	fate_levels.fill(0)
	rebirth_count = 0
	threads_changed.emit(threads)
	for i in fate_levels.size():
		fate_changed.emit(i, 0)


func to_dict() -> Dictionary:
	return {"threads": threads, "fate_levels": fate_levels.duplicate(), "rebirth_count": rebirth_count}


## 없는 필드는 기본값으로, 상한을 넘는 값은 잘라낸다. 상점이 늘어나면 새 항목은 0레벨
func from_dict(data: Dictionary) -> void:
	reset()
	threads = maxf(float(data.get("threads", 0.0)), 0.0)
	var saved: Variant = data.get("fate_levels", [])
	if saved is Array:
		for i in mini(saved.size(), fate_levels.size()):
			fate_levels[i] = clampi(int(saved[i]), 0, _cap(i))
	rebirth_count = maxi(int(data.get("rebirth_count", 0)), 0)
	threads_changed.emit(threads)
	for i in fate_levels.size():
		fate_changed.emit(i, fate_levels[i])


## 역대 최고 스테이지 (이번 판 포함)
func best_stage() -> int:
	return maxi(Prestige.best_stage, Game.highest_stage)


func can_rebirth() -> bool:
	return Balance.can_rebirth(best_stage())


## 지금 환생하면 받을 운명의 실
func thread_reward() -> float:
	return Balance.thread_reward(best_stage())


## 환생: 실을 받고 기억까지 내려놓는다. 남는 것은 운명의 실과 상점, 환생 횟수, 업적, 장비, 설정
func perform() -> bool:
	if not can_rebirth():
		return false
	var reward := thread_reward()
	threads += reward
	rebirth_count += 1
	Prestige.reset()  # 결정, 상점 레벨, 역대 최고 스테이지, 회귀 횟수
	Party.reset()
	Skills.reset()
	Training.reset()
	Promotions.reset()
	Game.reset()
	threads_changed.emit(threads)
	reborn.emit(reward)
	Save.save_game()
	return true


## 시련의 탑 보상 등 환생 밖에서 주는 실
func add_threads(amount: float) -> void:
	if amount <= 0.0:
		return
	threads += amount
	threads_changed.emit(threads)


func level(index: int) -> int:
	return fate_levels[index]


func is_maxed(index: int) -> bool:
	var cap := Balance.fate_max_level(index)
	return cap > 0 and fate_levels[index] >= cap


func fate_cost(index: int) -> float:
	return Balance.fate_cost(fate_levels[index])


func can_buy(index: int) -> bool:
	return not is_maxed(index) and threads >= fate_cost(index)


func buy(index: int) -> bool:
	if not can_buy(index):
		return false
	threads -= fate_cost(index)
	fate_levels[index] += 1
	threads_changed.emit(threads)
	fate_changed.emit(index, fate_levels[index])
	return true


# 효과

func damage_multiplier() -> float:
	return Balance.destiny_multiplier(level(Balance.Fate.DESTINY))


func crystal_multiplier() -> float:
	return Balance.bond_multiplier(level(Balance.Fate.BOND))


## 회귀 뒤 (그리고 환생 뒤) 시작 스테이지
func start_stage() -> int:
	return Balance.start_stage(level(Balance.Fate.FORESIGHT))


## 유산: 예지가 건너뛴 스테이지의 골드. 시작이 1이면 0이라 배율을 묻지 않는다 (Game이 준비되기 전에도 불린다)
func inheritance() -> float:
	var start := start_stage()
	if start <= 1:
		return 0.0
	return Balance.inheritance_gold(start, Game.gold_multiplier())


func companion_memory_ratio() -> float:
	return Balance.companion_memory_ratio(level(Balance.Fate.COMPANION_MEMORY))


## 해금형 운명(자동 회귀, 자동 스킬)을 샀는지
func has_fate(index: int) -> bool:
	return fate_levels[index] > 0


## 저장 데이터의 레벨 상한. 0(무한)이면 그대로
func _cap(index: int) -> int:
	var cap := Balance.fate_max_level(index)
	return cap if cap > 0 else 1000000
