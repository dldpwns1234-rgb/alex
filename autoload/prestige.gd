extends Node
## 회귀와 기억의 상점 (GDD 7절). 기억의 결정, 상점 레벨, 역대 기록은 회귀해도 남는다.
## 상태 변경은 Game·Party·Skills·Prestige의 함수로만 한다.

signal crystals_changed(crystals: float)
signal memory_changed(index: int, level: int)
signal prestiged(reward: float)

var crystals: float = 0.0
var memory_levels: Array[int] = []
var best_stage: int = 1          # 역대 최고 스테이지 (통계)
var prestige_count: int = 0


func _ready() -> void:
	reset()


## 데이터 초기화에서만 부른다. 회귀는 perform()이다
func reset() -> void:
	crystals = 0.0
	memory_levels.clear()
	memory_levels.resize(Balance.MEMORIES.size())
	memory_levels.fill(0)
	best_stage = 1
	prestige_count = 0
	crystals_changed.emit(crystals)
	for i in memory_levels.size():
		memory_changed.emit(i, 0)


func to_dict() -> Dictionary:
	return {
		"crystals": crystals,
		"memory_levels": memory_levels.duplicate(),
		"best_stage": best_stage,
		"prestige_count": prestige_count,
	}


## 없는 필드는 기본값으로. 상점이 늘어나면 새 항목은 0레벨
func from_dict(data: Dictionary) -> void:
	reset()
	crystals = maxf(float(data.get("crystals", 0.0)), 0.0)
	var saved: Variant = data.get("memory_levels", [])
	if saved is Array:
		for i in mini(saved.size(), memory_levels.size()):
			memory_levels[i] = clampi(int(saved[i]), 0, _cap(i))
	best_stage = maxi(int(data.get("best_stage", 1)), 1)
	prestige_count = maxi(int(data.get("prestige_count", 0)), 0)
	crystals_changed.emit(crystals)
	for i in memory_levels.size():
		memory_changed.emit(i, memory_levels[i])


func can_prestige() -> bool:
	return Balance.can_prestige(Game.highest_stage)


## 지금 회귀하면 받을 결정
func crystal_reward() -> float:
	return Balance.crystal_reward(Game.highest_stage)


## 회귀: 결정을 받고 새 판을 시작한다. 결정, 상점 레벨, 통계, 업적, 장비는 남는다
func perform() -> bool:
	if not can_prestige():
		return false
	var reward := crystal_reward()
	crystals += reward
	best_stage = maxi(best_stage, Game.highest_stage)
	prestige_count += 1
	Party.reset()
	Skills.reset()
	Training.reset()
	Promotions.reset()
	Game.reset()
	crystals_changed.emit(crystals)
	prestiged.emit(reward)
	Save.save_game()
	return true


func level(index: int) -> int:
	return memory_levels[index]


func is_maxed(index: int) -> bool:
	var cap := Balance.memory_max_level(index)
	return cap > 0 and memory_levels[index] >= cap


func memory_cost(index: int) -> float:
	return Balance.memory_cost(memory_levels[index])


func can_buy(index: int) -> bool:
	return not is_maxed(index) and crystals >= memory_cost(index)


func buy(index: int) -> bool:
	if not can_buy(index):
		return false
	crystals -= memory_cost(index)
	memory_levels[index] += 1
	crystals_changed.emit(crystals)
	memory_changed.emit(index, memory_levels[index])
	return true


# 효과. 각 오토로드가 공식에 곱하거나 더한다

func sword_multiplier() -> float:
	return Balance.sword_multiplier(level(Balance.Memory.SWORD))


func gold_multiplier() -> float:
	return Balance.gold_memory_multiplier(level(Balance.Memory.GOLD))


func awakening_share() -> float:
	return Balance.awakening_share(level(Balance.Memory.AWAKENING))


## 저장 데이터의 레벨 상한. 0(무한)이면 그대로
func _cap(index: int) -> int:
	var cap := Balance.memory_max_level(index)
	return cap if cap > 0 else 1000000
