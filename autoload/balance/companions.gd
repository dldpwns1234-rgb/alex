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
## mods는 단련이 바꾼 값(Training.mods()). 비어 있으면 기본 상수를 쓴다
func companion_dps(index: int, level: int, boss: bool, mods: Dictionary = {}) -> float:
	var dps := attack(COMPANIONS[index]["base_damage"], level)
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
