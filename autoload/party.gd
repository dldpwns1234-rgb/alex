extends Node
## 용사와 동료의 레벨과 구매 (GDD 5·6절). 골드는 Game이 갖고 있어 Game.spend()로 치른다.
## Game이 200줄을 넘지 않도록 나눴다. 상태 변경은 Game과 Party의 함수로만 하고 UI는 표시만 한다.

signal hero_changed(level: int)
signal companion_changed(index: int, level: int)
signal buy_mode_changed(mode: BuyMode)

## 구매 배수 (GDD 9절): ×1, ×10, 최대. 용사 탭과 동료 탭이 같이 쓴다
enum BuyMode { ONE, TEN, MAX }


## 한 번에 살 레벨 수와 비용. count는 최소 1이라 못 살 때도 비용을 보여줄 수 있다
class Purchase:
	var count: int = 1
	var cost: float = 0.0
	var affordable: bool = false


var hero_level: int = Balance.HERO_START_LEVEL
var companion_levels: Array[int] = []  # 0 = 미고용
var buy_mode: BuyMode = BuyMode.ONE


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


## 저장할 상태 (Save가 부른다)
func to_dict() -> Dictionary:
	return {
		"hero_level": hero_level,
		"companion_levels": companion_levels.duplicate(),
		"buy_mode": buy_mode,
	}


## 저장 데이터를 적용한다. 없는 필드는 기본값으로, 동료가 늘어나면 새 동료는 미고용으로
func from_dict(data: Dictionary) -> void:
	hero_level = maxi(int(data.get("hero_level", Balance.HERO_START_LEVEL)), Balance.HERO_START_LEVEL)
	companion_levels.clear()
	companion_levels.resize(Balance.COMPANIONS.size())
	companion_levels.fill(0)
	var saved: Variant = data.get("companion_levels", [])
	if saved is Array:
		for i in mini(saved.size(), companion_levels.size()):
			companion_levels[i] = maxi(int(saved[i]), 0)
	buy_mode = clampi(int(data.get("buy_mode", BuyMode.ONE)), BuyMode.ONE, BuyMode.MAX) as BuyMode
	hero_changed.emit(hero_level)
	for i in companion_levels.size():
		companion_changed.emit(i, companion_levels[i])
	buy_mode_changed.emit(buy_mode)


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


func set_buy_mode(mode: BuyMode) -> void:
	if buy_mode == mode:
		return
	buy_mode = mode
	buy_mode_changed.emit(mode)


func hero_purchase() -> Purchase:
	return _purchase(Balance.HERO_BASE_COST, hero_level)


func companion_purchase(index: int) -> Purchase:
	return _purchase(Balance.companion_base_cost(index), companion_levels[index])


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


## 현재 구매 배수로 살 레벨 수와 비용. 최대 모드에서 하나도 못 사면 1레벨 비용을 보여준다
func _purchase(base_cost: float, level: int) -> Purchase:
	var count := 1
	match buy_mode:
		BuyMode.TEN:
			count = Balance.BULK_COUNT
		BuyMode.MAX:
			count = maxi(Balance.max_affordable(base_cost, level, Game.gold), 1)
			# 닫힌 공식의 부동소수 오차로 한 레벨 넘칠 수 있으니 실제 비용으로 확인한다
			while count > 1 and Balance.bulk_cost(base_cost, level, count) > Game.gold:
				count -= 1
	var purchase := Purchase.new()
	purchase.count = count
	purchase.cost = Balance.bulk_cost(base_cost, level, count)
	purchase.affordable = Game.gold >= purchase.cost
	return purchase
