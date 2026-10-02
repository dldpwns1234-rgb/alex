extends Node
## 회귀와 기억의 상점 (GDD 7절). 기억의 결정, 상점 레벨, 역대 기록은 회귀해도 남는다 (환생에서 내려놓는다).
## 판 기록(이번 판 시간, 지난 판 최고)도 여기서 센다. 새 판은 Game.run_started로 안다.
## 상태 변경은 Game·Party·Skills·Prestige의 함수로만 한다.

signal crystals_changed(crystals: float)
signal memory_changed(index: int, level: int)
signal prestiged(reward: float)

var crystals: float = 0.0
var memory_levels: Array[int] = []
var best_stage: int = 1          # 역대 최고 스테이지 (통계)
var prestige_count: int = 0
var run_seconds: float = 0.0     # 이번 판이 흐른 게임 시간 (초). 오프라인 시간은 넣지 않는다
var last_run_best: int = 0       # 지난 판의 최고 스테이지. 0이면 지난 판이 없다


func _ready() -> void:
	reset()
	Game.run_started.connect(_on_run_started)


func _process(delta: float) -> void:
	tick(minf(delta, Balance.MAX_DELTA))


func tick(dt: float) -> void:
	run_seconds += dt


## 새 판: 시간을 0으로, 지난 판의 최고를 남긴다. 처음 시작(데이터 초기화 포함)이면 지난 판이 없다
func _on_run_started(previous_highest: int) -> void:
	run_seconds = 0.0
	var first_run := prestige_count == 0 and Rebirth.rebirth_count == 0
	last_run_best = 0 if first_run else previous_highest


## 이번 판 최고가 지난 판 최고보다 얼마나 높은지 (낮으면 음수)
func run_gain() -> int:
	return Game.highest_stage - last_run_best


## 데이터 초기화에서만 부른다. 회귀는 perform()이다
func reset() -> void:
	crystals = 0.0
	memory_levels.clear()
	memory_levels.resize(Balance.MEMORIES.size())
	memory_levels.fill(0)
	best_stage = 1
	prestige_count = 0
	run_seconds = 0.0
	last_run_best = 0
	crystals_changed.emit(crystals)
	for i in memory_levels.size():
		memory_changed.emit(i, 0)


func to_dict() -> Dictionary:
	return {
		"crystals": crystals,
		"memory_levels": memory_levels.duplicate(),
		"best_stage": best_stage,
		"prestige_count": prestige_count,
		"run_seconds": run_seconds,
		"last_run_best": last_run_best,
	}


## 없는 필드는 기본값으로. 상점이 늘어나면 새 항목은 0레벨
func from_dict(data: Dictionary) -> void:
	reset()
	crystals = clampf(float(data.get("crystals", 0.0)), 0.0, Balance.MAX_NUMBER)
	var saved: Variant = data.get("memory_levels", [])
	if saved is Array:
		for i in mini(saved.size(), memory_levels.size()):
			memory_levels[i] = clampi(int(saved[i]), 0, _cap(i))
	best_stage = maxi(int(data.get("best_stage", 1)), 1)
	prestige_count = maxi(int(data.get("prestige_count", 0)), 0)
	run_seconds = maxf(float(data.get("run_seconds", 0.0)), 0.0)  # 옛 저장은 불러온 때부터 센다
	last_run_best = maxi(int(data.get("last_run_best", 0)), 0)
	crystals_changed.emit(crystals)
	for i in memory_levels.size():
		memory_changed.emit(i, memory_levels[i])


func can_prestige() -> bool:
	return Balance.can_prestige(Game.highest_stage)


## 지금 회귀하면 받을 결정 (인연과 맨몸의 회귀 보너스가 곱해진다)
func crystal_reward() -> float:
	return Balance.crystal_reward(Game.highest_stage) * Rebirth.crystal_multiplier() * Challenges.crystal_multiplier()


## 회귀: 결정을 받고 새 판을 시작한다. 결정, 상점 레벨, 통계, 업적, 장비는 남는다
func perform() -> bool:
	if not can_prestige():
		return false
	var reward := crystal_reward()
	crystals = minf(crystals + reward, Balance.MAX_NUMBER)
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


## 별의 상점 '기억의 잔향': 결정을 쓰지 않고 레벨을 얹는다 (초월·환생 직후)
func grant_levels(index: int, amount: int) -> void:
	if amount <= 0:
		return
	memory_levels[index] = mini(memory_levels[index] + amount, _cap(index))
	memory_changed.emit(index, memory_levels[index])


## 기억의 상점에서 지금 살 수 있는 것이 있는지 (회귀 탭 점)
func any_affordable() -> bool:
	for i in memory_levels.size():
		if can_buy(i):
			return true
	return false


func buy(index: int) -> bool:
	if not can_buy(index):
		return false
	crystals -= memory_cost(index)
	memory_levels[index] += 1
	crystals_changed.emit(crystals)
	memory_changed.emit(index, memory_levels[index])
	return true


# 효과. 각 오토로드가 공식에 곱하거나 더한다. 맨몸의 회귀 도전 중에는 효과 레벨이 0이다 (상점 표시는 level()로 그대로)

func effect_level(index: int) -> int:
	return 0 if Challenges.blocks_memories() else memory_levels[index]


func sword_multiplier() -> float:
	return Balance.sword_multiplier(effect_level(Balance.Memory.SWORD))


func gold_multiplier() -> float:
	return Balance.gold_memory_multiplier(effect_level(Balance.Memory.GOLD))


func awakening_share() -> float:
	return Balance.awakening_share(effect_level(Balance.Memory.AWAKENING))


## 바람의 걸음: 재등장 대기에서 빼는 초
func wind_respawn_cut() -> float:
	return Balance.wind_respawn_cut(effect_level(Balance.Memory.WIND))


## 저장 데이터의 레벨 상한. 0(무한)이면 그대로
func _cap(index: int) -> int:
	var cap := Balance.memory_max_level(index)
	return cap if cap > 0 else 1000000
