extends "res://autoload/party/purchases.gd"
## 용사와 동료의 레벨과 구매 (GDD 5·6절). 골드는 Game이 갖고 있어 Game.spend()로 치른다. 구매 배수와 구매 계산은 party/purchases.gd에.
## Game이 200줄을 넘지 않도록 나눴다. 상태 변경은 Game과 Party의 함수로만 하고 UI는 표시만 한다.

signal hero_changed(level: int)
signal companion_changed(index: int, level: int)

var hero_level: int = Balance.HERO_START_LEVEL
var companion_levels: Array[int] = []  # 산 레벨. 0 = 미고용 (기억 레벨이 있으면 고용 상태)
var companion_memory: Array[int] = []  # 동료 기억(운명의 상점)이 얹는 기억 레벨. DPS·승급·단련에는 들고 레벨업 비용에는 안 든다


func _ready() -> void:
	reset()


## 새 판 시작 상태로 되돌린다. 회귀와 환생에서도 쓴다.
## 동료 기억(운명의 상점)이 있으면 지난 판 레벨(산 레벨 + 기억 레벨)의 일부를 기억 레벨로 얹고 시작한다.
## 산 레벨로 남기면 다음 레벨 비용이 감당 못 할 만큼 뛰어 동료가 굳는다 (docs/BALANCE_SIM.md). 데이터 초기화는 Rebirth를 먼저 지워 0이 된다
func reset() -> void:
	hero_level = Balance.HERO_START_LEVEL
	var ratio := Rebirth.companion_memory_ratio()
	var remembered: Array[int] = []
	for i in Balance.COMPANIONS.size():
		remembered.append(Balance.remembered_level(companion_level(i), ratio) if i < companion_levels.size() else 0)
	companion_levels.clear()
	companion_levels.resize(Balance.COMPANIONS.size())
	companion_levels.fill(0)
	companion_memory = remembered
	hero_changed.emit(hero_level)
	for i in companion_levels.size():
		companion_changed.emit(i, companion_level(i))


## 저장할 상태 (Save가 부른다)
func to_dict() -> Dictionary:
	return {
		"hero_level": hero_level,
		"companion_levels": companion_levels.duplicate(),
		"companion_memory": companion_memory.duplicate(),
		"buy_mode": buy_mode,
	}


## 저장 데이터를 적용한다. 없는 필드는 기본값으로, 동료가 늘어나면 새 동료는 미고용으로
func from_dict(data: Dictionary) -> void:
	hero_level = _read_level(data.get("hero_level", Balance.HERO_START_LEVEL), Balance.HERO_START_LEVEL)
	companion_levels.clear()
	companion_levels.resize(Balance.COMPANIONS.size())
	companion_levels.fill(0)
	companion_memory.clear()
	companion_memory.resize(Balance.COMPANIONS.size())
	companion_memory.fill(0)
	_read_levels(data.get("companion_levels", []), companion_levels)
	_read_levels(data.get("companion_memory", []), companion_memory)
	buy_mode = clampi(int(data.get("buy_mode", BuyMode.ONE)), BuyMode.ONE, BuyMode.MAX) as BuyMode
	hero_changed.emit(hero_level)
	for i in companion_levels.size():
		companion_changed.emit(i, companion_level(i))
	buy_mode_changed.emit(buy_mode)


func _read_levels(saved: Variant, into: Array[int]) -> void:
	if saved is Array:
		for i in mini(saved.size(), into.size()):
			into[i] = _read_level(saved[i], 0)


## 저장된 레벨을 상한 안으로. 무한대나 int 범위 밖의 값(망가진 저장)도 float으로 받아 자른다
func _read_level(saved: Variant, minimum: int) -> int:
	return int(clampf(float(saved), float(minimum), float(Balance.MAX_LEVEL)))


## 동료의 실제 레벨 = 산 레벨 + 기억 레벨. DPS, 승급, 단련 해금, 표시에 쓴다
func companion_level(index: int) -> int:
	return companion_levels[index] + companion_memory[index]


func companion_level_list() -> Array[int]:
	var levels: Array[int] = []
	for i in companion_levels.size():
		levels.append(companion_level(i))
	return levels


## 클릭 피해: 기본 × 검술의 기억 × 업적 × 무기 × 숙명 × 도전 보너스 × 연격 (보스면 × 방패 강타) + 동료 DPS 합계 × 용사의 각성 × 용사 마일스톤 보정 (GDD 5절)
func click_damage() -> float:
	var boss := Game.is_boss_stage()
	var base := Balance.hero_click_damage(hero_level) * Prestige.sword_multiplier() * Achievements.damage_multiplier()
	base *= Equipment.click_multiplier() * Rebirth.damage_multiplier() * Challenges.click_multiplier()
	base *= (1.0 + Training.value(Balance.Effect.CLICK_DAMAGE)) * _boss_bonus(boss)
	return minf(base + party_dps(boss) * Prestige.awakening_share() * Balance.awakening_factor(hero_level), Balance.MAX_NUMBER)


## 동료 DPS 합계 × 검술의 기억 × 단련 × 전투의 함성 (GDD 6절). boss는 현재 적이 보스인지.
## 오프라인 보상처럼 스킬을 빼고 볼 때는 with_skills를 끈다. 홀로 서기 도전 중에는 0
func party_dps(boss: bool, with_skills: bool = true) -> float:
	if Challenges.blocks_companions():
		return 0.0
	var dps := Balance.party_dps(companion_level_list(), boss, _mods()) * _party_bonus(boss)
	return minf(dps * Skills.party_multiplier() if with_skills else dps, Balance.MAX_NUMBER)


## 동료 한 명이 실제로 내는 DPS (성직자 버프, 승급, 검술의 기억, 단련, 전투의 함성 포함). 공격 연출의 피해 숫자에 쓴다
func companion_dps(index: int, boss: bool) -> float:
	if Challenges.blocks_companions():
		return 0.0
	var mods := _mods()
	var cleric := Balance.cleric_multiplier(companion_level(Balance.Companion.CLERIC), mods["cleric_buff"])
	var dps := Balance.companion_dps(index, companion_level(index), boss, mods) * cleric
	return minf(dps * _party_bonus(boss) * Skills.party_multiplier(), Balance.MAX_NUMBER)


## 동료 공식에 넘길 보정값: 단련 값에 승급 단계를 얹는다
func _mods() -> Dictionary:
	var mods := Training.mods()
	mods["promotion_ranks"] = Promotions.ranks
	mods["demon_king"] = not Game.in_tower and Balance.is_demon_king_stage(Game.stage)
	return mods


## 검술의 기억 × 업적 × 깃발 × 숙명 × 지휘·백전노장 (보스면 × 방패 강타)
func _party_bonus(boss: bool) -> float:
	var bonus := Prestige.sword_multiplier() * Achievements.damage_multiplier() * Equipment.party_multiplier()
	bonus *= Rebirth.damage_multiplier()
	return bonus * (1.0 + Training.value(Balance.Effect.PARTY_DAMAGE)) * _boss_bonus(boss)


func _boss_bonus(boss: bool) -> float:
	return 1.0 + Training.value(Balance.Effect.BOSS_DAMAGE) if boss else 1.0


func is_companion_hired(index: int) -> bool:
	return companion_level(index) > 0


## 이번 판에서 합류 스테이지에 도달했으면 고용할 수 있다. 동료 기억으로 이미 레벨이 있으면 합류 제한이 없다
func is_companion_unlocked(index: int) -> bool:
	return is_companion_hired(index) or Game.highest_stage >= Balance.companion_unlock_stage(index)


func hero_purchase() -> Purchase:
	return _purchase(Balance.HERO_BASE_COST, hero_level)


## mode를 주면 그 배수로 (고용은 늘 최대로 산다: 늦게 합류한 동료의 1레벨은 다른 동료에 비해 0에 가깝다)
func companion_purchase(index: int, mode: BuyMode = buy_mode) -> Purchase:
	return _purchase(Balance.companion_base_cost(index), companion_levels[index], mode)


## 레벨 상한이면(살 레벨 0) 사지 않는다
func buy_hero() -> bool:
	var purchase := hero_purchase()
	if purchase.count <= 0 or not Game.spend(purchase.cost):
		return false
	hero_level += purchase.count
	hero_changed.emit(hero_level)
	return true


## 산 레벨 0이면 고용, 아니면 레벨업 (비용은 산 레벨 기준). 합류 전이거나 골드가 모자라면 false
func buy_companion(index: int, mode: BuyMode = buy_mode) -> bool:
	if not is_companion_unlocked(index) or Challenges.blocks_companions():
		return false
	var purchase := companion_purchase(index, mode)
	if purchase.count <= 0 or not Game.spend(purchase.cost):
		return false
	companion_levels[index] += purchase.count
	companion_changed.emit(index, companion_level(index))
	return true


## 지금 구매 배수로 이 동료를 사면 파티 DPS(일반 몬스터 기준)가 골드당 얼마나 느는지. 동료 탭의 골드 효율 비교에 쓴다.
## 합류 전이거나 홀로 서기 도전 중이면 0. 레벨을 잠깐 올렸다 되돌려 재므로 시그널은 내지 않는다
func companion_gain_per_gold(index: int) -> float:
	if not is_companion_unlocked(index) or Challenges.blocks_companions():
		return 0.0
	var purchase := companion_purchase(index)
	var before := party_dps(false)
	companion_levels[index] += purchase.count
	var gain := party_dps(false) - before
	companion_levels[index] -= purchase.count
	return gain / purchase.cost if purchase.cost > 0.0 else 0.0


## 지금 승급하면 파티 DPS(일반 몬스터 기준)가 골드당 얼마나 느는지. 승급할 수 없으면(레벨 부족, 최고 단계, 홀로 서기) 0.
## 동료 자동 강화가 레벨업과 견준다. 단계를 잠깐 올렸다 되돌려 재므로 시그널은 내지 않는다
func promotion_gain_per_gold(index: int) -> float:
	if not Promotions.is_unlocked(index) or Challenges.blocks_companions():
		return 0.0
	var cost := Promotions.cost(index)
	var before := party_dps(false)
	Promotions.ranks[index] += 1
	var gain := party_dps(false) - before
	Promotions.ranks[index] -= 1
	return gain / cost if cost > 0.0 else 0.0
