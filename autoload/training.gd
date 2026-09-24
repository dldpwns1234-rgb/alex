extends Node
## 단련 상태 (GDD 6.5절). 한 판 안에서 골드로 사는 반복 구매 패시브. 회귀하면 초기화된다.
## 효과는 value()와 mods()로 합산해서 Party·Game·Skills·Save가 자기 공식에 곱하거나 더한다.

signal training_changed(index: int, level: int)

var levels: Array[int] = []


func _ready() -> void:
	reset()


func reset() -> void:
	levels.clear()
	levels.resize(Balance.TRAININGS.size())
	levels.fill(0)
	for i in levels.size():
		training_changed.emit(i, 0)


func to_dict() -> Dictionary:
	return {"levels": levels.duplicate()}


## 없는 필드는 0으로, 상한을 넘는 값은 잘라낸다. 단련이 늘어나면 새 항목은 0
func from_dict(data: Dictionary) -> void:
	reset()
	var saved: Variant = data.get("levels", [])
	if saved is Array:
		for i in mini(saved.size(), levels.size()):
			levels[i] = clampi(int(saved[i]), 0, Balance.training_max_level(i))
	for i in levels.size():
		training_changed.emit(i, levels[i])


## 주인(용사 또는 동료)의 현재 레벨
func owner_level(index: int) -> int:
	var owner := Balance.training_owner(index)
	return Party.hero_level if owner == Balance.OWNER_HERO else Party.companion_level(owner)


func is_unlocked(index: int) -> bool:
	return owner_level(index) >= Balance.training_unlock_level(index)


func is_maxed(index: int) -> bool:
	return levels[index] >= Balance.training_max_level(index)


## 현재 구매 배수로 살 레벨 수와 비용. 남은 레벨을 넘지 않는다. 못 사면 1레벨 비용을 보여준다
func purchase(index: int) -> Party.Purchase:
	var remaining := maxi(Balance.training_max_level(index) - levels[index], 1)
	var base := Balance.training_base_cost(index)
	var growth := Balance.TRAINING_COST_GROWTH
	var count := 1
	match Party.buy_mode:
		Party.BuyMode.TEN:
			count = mini(Balance.BULK_COUNT, remaining)
		Party.BuyMode.MAX:
			count = clampi(Balance.max_affordable(base, levels[index], Game.gold, growth), 1, remaining)
			while count > 1 and Balance.bulk_cost(base, levels[index], count, growth) > Game.gold:
				count -= 1
	var result := Party.Purchase.new()
	result.count = count
	result.cost = Balance.bulk_cost(base, levels[index], count, growth)
	result.affordable = Game.gold >= result.cost
	return result


func can_buy(index: int) -> bool:
	return is_unlocked(index) and not is_maxed(index) and purchase(index).affordable


func buy(index: int) -> bool:
	if not is_unlocked(index) or is_maxed(index):
		return false
	var result := purchase(index)
	if not Game.spend(result.cost):
		return false
	levels[index] += result.count
	training_changed.emit(index, levels[index])
	return true


## 살 수 있는 단련이 하나라도 있는지 (탭 표시용)
func any_affordable() -> bool:
	for i in levels.size():
		if can_buy(i):
			return true
	return false


## 같은 효과의 단련을 모두 더한 값 (레벨당 효과 × 레벨). 동료별 DPS는 companion_damage_multiplier()
func value(effect: int) -> float:
	var total := 0.0
	for i in levels.size():
		if Balance.training_effect(i) == effect:
			total += Balance.training_per_level(i) * levels[i]
	return total


func companion_damage_multiplier(companion: int) -> float:
	var total := 0.0
	for i in levels.size():
		if Balance.training_effect(i) == Balance.Effect.COMPANION_DAMAGE and Balance.training_owner(i) == companion:
			total += Balance.training_per_level(i) * levels[i]
	return 1.0 + total


## Balance의 동료 공식에 넘길 보정값. 기본값에 단련을 더한 것
func mods() -> Dictionary:
	var damage: Array[float] = []
	for i in Balance.COMPANIONS.size():
		damage.append(companion_damage_multiplier(i))
	return {
		"archer_crit_chance": Balance.ARCHER_CRIT_CHANCE + value(Balance.Effect.ARCHER_CRIT_CHANCE),
		"archer_crit_mult": Balance.ARCHER_CRIT_MULTIPLIER + value(Balance.Effect.ARCHER_CRIT_MULT),
		"mage_boss_mult": Balance.MAGE_BOSS_MULTIPLIER + value(Balance.Effect.MAGE_BOSS_MULT),
		"cleric_buff": Balance.CLERIC_BUFF_PER_LEVEL + value(Balance.Effect.CLERIC_BUFF),
		"companion_damage": damage,
	}
