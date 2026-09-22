extends Node
## Balance 1부: 용사와 레벨업 공식 (GDD 4·5절). Balance는 200줄 규칙 때문에
## autoload/balance/ 아래 부분 스크립트를 상속으로 이어 붙인다. 바깥에서는 Balance.만 쓴다.
## L = 레벨. 골드·체력·피해·비용은 전부 float (CLAUDE.md 숫자 규칙)

# 용사
const HERO_START_LEVEL: int = 1
const HERO_BASE_COST: float = 5.0
const HERO_BASE_DAMAGE: float = 1.0

# 레벨업
const LEVEL_COST_GROWTH: float = 1.07
const BULK_COUNT: int = 10               # 구매 배수 ×10
const MILESTONE_FIRST_LEVEL: int = 10    # 이 레벨에서 첫 마일스톤
const MILESTONE_INTERVAL: int = 25       # 이후 이 간격마다 +1
const MILESTONE_MULTIPLIER: float = 2.0  # 마일스톤당 공격력 배율


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


## n레벨 한 번에 구매: 기본 비용 × 1.07^L × (1.07^n − 1) / 0.07
func bulk_cost(base_cost: float, level: int, count: int) -> float:
	var growth := LEVEL_COST_GROWTH - 1.0
	return level_cost(base_cost, level) * (pow(LEVEL_COST_GROWTH, count) - 1.0) / growth


## 골드로 살 수 있는 최대 n: floor(log(골드 × 0.07 / (기본 비용 × 1.07^L) + 1) / log(1.07)). 못 사면 0
func max_affordable(base_cost: float, level: int, gold: float) -> int:
	var growth := LEVEL_COST_GROWTH - 1.0
	var ratio := gold * growth / level_cost(base_cost, level) + 1.0
	return floori(log(ratio) / log(LEVEL_COST_GROWTH))


## 용사 클릭 피해. 검술의 기억과 용사의 각성은 M5에서 붙는다
func hero_click_damage(level: int) -> float:
	return attack(HERO_BASE_DAMAGE, level)


func hero_level_cost(level: int) -> float:
	return level_cost(HERO_BASE_COST, level)
