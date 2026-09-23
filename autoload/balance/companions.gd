extends "res://autoload/balance/leveling.gd"
## Balance 2부: 동료 (GDD 6절)

# 동료 (GDD 6절). 레벨 0은 미고용. 순서는 Companion 열거형과 같다
enum Companion { WARRIOR, ARCHER, MAGE, CLERIC }
const COMPANIONS: Array[Dictionary] = [
	{"name": "전사", "unlock_stage": 1, "base_cost": 10.0, "base_damage": 3.0},
	{"name": "궁수", "unlock_stage": 10, "base_cost": 100.0, "base_damage": 16.0},
	{"name": "마법사", "unlock_stage": 25, "base_cost": 1000.0, "base_damage": 110.0},
	{"name": "성직자", "unlock_stage": 50, "base_cost": 10000.0, "base_damage": 200.0},
]
const ARCHER_CRIT_CHANCE: float = 0.1
const ARCHER_CRIT_MULTIPLIER: float = 5.0
const MAGE_BOSS_MULTIPLIER: float = 3.0
const CLERIC_BUFF_PER_LEVEL: float = 0.02

# 승급 (GDD 6.6절): 동료 레벨 50마다 골드를 내고 한 단계씩 승급한다. 단계마다 그 동료의 DPS ×1.5, 최대 5단계 (×7.6).
# ×2(5단계 ×32)는 첫 회귀가 155에서 200으로, 판당 상승이 +40에서 +85로 뛰어 GDD 13절 목표를 벗어났다. docs/BALANCE_SIM.md
const PROMOTION_LEVEL_STEP: int = 50
const PROMOTION_MAX_RANK: int = 5
const PROMOTION_COST_FACTOR: float = 50.0  # 승급 비용 = 필요 레벨의 레벨업 비용 × 50 (레벨업 25개 값과 비슷하다)
const PROMOTION_MULTIPLIER: float = 1.5


func companion_name(index: int) -> String:
	return COMPANIONS[index]["name"]


func companion_unlock_stage(index: int) -> int:
	return COMPANIONS[index]["unlock_stage"]


func companion_base_cost(index: int) -> float:
	return COMPANIONS[index]["base_cost"]


func companion_cost(index: int, level: int) -> float:
	return level_cost(companion_base_cost(index), level)


## 궁수 치명타 기대값: 1 + 확률 × (배율 − 1) = 1.4. 실제 피해는 이 기대값으로 계산하고 치명타는 연출만 한다
func archer_expected_multiplier(chance: float = ARCHER_CRIT_CHANCE, multiplier: float = ARCHER_CRIT_MULTIPLIER) -> float:
	return 1.0 + chance * (multiplier - 1.0)


## 성직자 버프: 동료 전체 공격력 × (1 + 0.02 × 성직자 레벨). 성직자 자신도 포함한다
func cleric_multiplier(cleric_level: int, buff_per_level: float = CLERIC_BUFF_PER_LEVEL) -> float:
	return 1.0 + buff_per_level * cleric_level


## 동료 한 명의 DPS (성직자 버프 제외). 마법사의 ×3은 현재 적이 보스일 때만.
## mods는 단련이 바꾼 값(Training.mods())에 승급 단계(promotion_ranks)를 얹은 것. 비어 있으면 기본 상수를 쓴다
func companion_dps(index: int, level: int, boss: bool, mods: Dictionary = {}) -> float:
	var dps := attack(COMPANIONS[index]["base_damage"], level)
	var ranks: Array = mods.get("promotion_ranks", [])
	if index < ranks.size():
		dps *= promotion_multiplier(int(ranks[index]))
	match index:
		Companion.ARCHER:
			var chance: float = mods.get("archer_crit_chance", ARCHER_CRIT_CHANCE)
			var multiplier: float = mods.get("archer_crit_mult", ARCHER_CRIT_MULTIPLIER)
			dps *= archer_expected_multiplier(chance, multiplier)
		Companion.MAGE:
			if boss:
				var boss_multiplier: float = mods.get("mage_boss_mult", MAGE_BOSS_MULTIPLIER)
				dps *= boss_multiplier
	var damage: Array = mods.get("companion_damage", [])
	if index < damage.size():
		dps *= float(damage[index])
	return dps


## 동료 DPS 합계: (각 동료 DPS의 합) × 성직자 버프. 전투의 함성, 검술의 기억, 단련 배율은 Party가 곱한다
func party_dps(levels: Array[int], boss: bool, mods: Dictionary = {}) -> float:
	var total := 0.0
	for i in levels.size():
		total += companion_dps(i, levels[i], boss, mods)
	var buff: float = mods.get("cleric_buff", CLERIC_BUFF_PER_LEVEL)
	return total * cleric_multiplier(levels[Companion.CLERIC], buff)


## 동료 탭에 보여줄 특수 효과 설명. 숫자는 위 상수에서 가져온다
func companion_note(index: int) -> String:
	match index:
		Companion.ARCHER:
			return "치명타 %d%% 확률 ×%d" % [roundi(ARCHER_CRIT_CHANCE * 100.0), roundi(ARCHER_CRIT_MULTIPLIER)]
		Companion.MAGE:
			return "보스에게 피해 ×%d" % roundi(MAGE_BOSS_MULTIPLIER)
		Companion.CLERIC:
			return "동료 전체 공격력 +%d%%/레벨" % roundi(CLERIC_BUFF_PER_LEVEL * 100.0)
	return "꾸준한 기본 피해"


## rank단계(1~5) 승급에 필요한 동료 레벨: 50 × rank
func promotion_level(rank: int) -> int:
	return PROMOTION_LEVEL_STEP * rank


## rank단계 승급 비용: 필요 레벨의 레벨업 비용 × 50
func promotion_cost(index: int, rank: int) -> float:
	return companion_cost(index, promotion_level(rank)) * PROMOTION_COST_FACTOR


## 승급 단계에 따른 그 동료의 DPS 배율: 1.5^rank
func promotion_multiplier(rank: int) -> float:
	return pow(PROMOTION_MULTIPLIER, rank)


## 이름 옆에 붙이는 별. 0단계면 빈 문자열
func promotion_stars(rank: int) -> String:
	return "★".repeat(rank)
