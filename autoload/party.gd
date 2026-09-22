extends Node
## 용사와 동료의 레벨과 구매 (GDD 5·6절). 골드는 Game이 갖고 있어 Game.spend()로 치른다.
## Game이 200줄을 넘지 않도록 나눴다. 상태 변경은 Game과 Party의 함수로만 하고 UI는 표시만 한다.

signal hero_changed(level: int)
signal companion_changed(index: int, level: int)


## 한 번에 살 레벨 수와 비용. count는 최소 1이라 못 살 때도 비용을 보여줄 수 있다
class Purchase:
	var count: int = 1
	var cost: float = 0.0
	var affordable: bool = false


var hero_level: int = Balance.HERO_START_LEVEL
var companion_levels: Array[int] = []  # 0 = 미고용


func _ready() -> void:
	reset()


## 새 판 시작 상태로 되돌린다. 회귀(M5)에서도 쓴다
func reset() -> void:
	hero_level = Balance.HERO_START_LEVEL
	companion_levels.clear()
	companion_levels.resize(Balance.COMPANIONS.size())
	companion_levels.fill(0)
	hero_changed.emit(hero_level)
	for i in companion_levels.size():
		companion_changed.emit(i, 0)


func click_damage() -> float:
	return Balance.hero_click_damage(hero_level)


## 동료 DPS 합계. boss는 현재 적이 보스인지
func party_dps(boss: bool) -> float:
	return Balance.party_dps(companion_levels, boss)


## 동료 한 명이 실제로 내는 DPS (성직자 버프 포함). 공격 연출의 피해 숫자에 쓴다
func companion_dps(index: int, boss: bool) -> float:
	var cleric := Balance.cleric_multiplier(companion_levels[Balance.Companion.CLERIC])
	return Balance.companion_dps(index, companion_levels[index], boss) * cleric


func is_companion_hired(index: int) -> bool:
	return companion_levels[index] > 0


## 이번 판에서 합류 스테이지에 도달했으면 고용할 수 있다
func is_companion_unlocked(index: int) -> bool:
	return Game.highest_stage >= Balance.companion_unlock_stage(index)


func hero_purchase() -> Purchase:
	return _purchase(Balance.hero_level_cost(hero_level))


func companion_purchase(index: int) -> Purchase:
	return _purchase(Balance.companion_cost(index, companion_levels[index]))


func buy_hero() -> bool:
	var purchase := hero_purchase()
	if not Game.spend(purchase.cost):
		return false
	hero_level += purchase.count
	hero_changed.emit(hero_level)
	return true


## 레벨 0이면 고용, 아니면 레벨업. 합류 전이거나 골드가 모자라면 false
func buy_companion(index: int) -> bool:
	if not is_companion_unlocked(index):
		return false
	var purchase := companion_purchase(index)
	if not Game.spend(purchase.cost):
		return false
	companion_levels[index] += purchase.count
	companion_changed.emit(index, companion_levels[index])
	return true


func _purchase(cost: float) -> Purchase:
	var purchase := Purchase.new()
	purchase.count = 1
	purchase.cost = cost
	purchase.affordable = Game.gold >= cost
	return purchase
