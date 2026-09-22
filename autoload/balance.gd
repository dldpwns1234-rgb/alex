extends Node
## 모든 수치와 공식 (GDD 4·5절). 다른 파일에 게임 수치를 하드코딩하지 않는다.
## L = 레벨, s = 스테이지. 골드·체력·피해·비용은 전부 float (CLAUDE.md 숫자 규칙)

# 용사
const HERO_START_LEVEL: int = 1
const HERO_BASE_COST: float = 5.0
const HERO_BASE_DAMAGE: float = 1.0

# 레벨업
const LEVEL_COST_GROWTH: float = 1.07
const MILESTONE_FIRST_LEVEL: int = 10    # 이 레벨에서 첫 마일스톤
const MILESTONE_INTERVAL: int = 25       # 이후 이 간격마다 +1
const MILESTONE_MULTIPLIER: float = 2.0  # 마일스톤당 공격력 배율

# 몬스터
const MONSTER_BASE_HP: float = 10.0
const MONSTER_HP_GROWTH: float = 1.15
const MONSTERS_PER_STAGE: int = 10
const GOLD_PER_HP: float = 1.0 / 15.0
const RESPAWN_DELAY: float = 0.3         # 처치 후 다음 몬스터가 나오기까지 (초)

# 시간
const MAX_DELTA: float = 0.25            # _process delta 상한 (초)


## 마일스톤 수 m(L): 10레벨에 1, 이후 25레벨마다 +1
func milestones(level: int) -> int:
	var first := 1 if level >= MILESTONE_FIRST_LEVEL else 0
	return first + floori(float(level) / MILESTONE_INTERVAL)


## 공격력: 기본 공격력 × L × 2^m(L). 레벨 0(미고용)은 0
func attack(base_damage: float, level: int) -> float:
	if level <= 0:
		return 0.0
	return base_damage * level * pow(MILESTONE_MULTIPLIER, milestones(level))


## 레벨업 비용 (L → L+1): 기본 비용 × 1.07^L
func level_cost(base_cost: float, level: int) -> float:
	return base_cost * pow(LEVEL_COST_GROWTH, level)


## 용사 클릭 피해. 검술의 기억과 용사의 각성은 M5에서 붙는다
func hero_click_damage(level: int) -> float:
	return attack(HERO_BASE_DAMAGE, level)


func hero_level_cost(level: int) -> float:
	return level_cost(HERO_BASE_COST, level)


## 일반 몬스터 체력: 10 × 1.15^(s − 1)
func monster_hp(stage: int) -> float:
	return MONSTER_BASE_HP * pow(MONSTER_HP_GROWTH, stage - 1)


## 처치 골드: 체력 ÷ 15. 황금의 기억과 황금 손길은 M4·M5에서 붙는다
func kill_gold(max_hp: float) -> float:
	return max_hp * GOLD_PER_HP


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


func companion_cost(index: int, level: int) -> float:
	return level_cost(COMPANIONS[index]["base_cost"], level)


## 궁수 치명타 기대값: 1 + 확률 × (배율 − 1) = 1.4. 실제 피해는 이 기대값으로 계산하고 치명타는 연출만 한다
func archer_expected_multiplier() -> float:
	return 1.0 + ARCHER_CRIT_CHANCE * (ARCHER_CRIT_MULTIPLIER - 1.0)


## 성직자 버프: 동료 전체 공격력 × (1 + 0.02 × 성직자 레벨). 성직자 자신도 포함한다
func cleric_multiplier(cleric_level: int) -> float:
	return 1.0 + CLERIC_BUFF_PER_LEVEL * cleric_level


## 동료 한 명의 DPS (성직자 버프 제외). 마법사의 ×3은 현재 적이 보스일 때만
func companion_dps(index: int, level: int, boss: bool) -> float:
	var dps := attack(COMPANIONS[index]["base_damage"], level)
	match index:
		Companion.ARCHER:
			dps *= archer_expected_multiplier()
		Companion.MAGE:
			if boss:
				dps *= MAGE_BOSS_MULTIPLIER
	return dps


## 동료 DPS 합계: (각 동료 DPS의 합) × 성직자 버프. 전투의 함성(M4)과 검술의 기억(M5)은 뒤에 곱한다
func party_dps(levels: Array[int], boss: bool) -> float:
	var total := 0.0
	for i in levels.size():
		total += companion_dps(i, levels[i], boss)
	return total * cleric_multiplier(levels[Companion.CLERIC])


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
