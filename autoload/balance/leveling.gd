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

# 수치 상한. float은 1.8e308에서 무한대가 되고(스테이지 4507의 체력) 그 뒤로는 비용·구매 수·DPS가 차례로 망가진다 (플레이테스트 2026-10-01).
# 골드·결정·피해·통계는 MAX_NUMBER로 자르고, 레벨은 MAX_LEVEL까지만 산다 (레벨 비용 1.07^L은 10190에서 1e300을 넘어 어차피 못 산다). 스테이지는 FINAL_STAGE(balance.gd)까지
const MAX_NUMBER: float = 1e300
const MAX_LEVEL: int = 10000


## 큰 수 상한: MAX_NUMBER에서 자르고, 0 × ∞ 같은 계산이 낸 NaN은 0으로 (minf(NaN, 상한)은 상한을 돌려준다).
## 가진 양만 자르면 화면의 수입·보상 글에 ∞가 남는다 (방장 2026-10-03: 금화 수입이 ∞)
func cap(value: float) -> float:
	return 0.0 if is_nan(value) else minf(value, MAX_NUMBER)


## 마일스톤 수 m(L): 10레벨에 1, 이후 25레벨마다 +1
func milestones(level: int) -> int:
	var first := 1 if level >= MILESTONE_FIRST_LEVEL else 0
	return first + floori(float(level) / MILESTONE_INTERVAL)


## 다음 마일스톤이 생기는 레벨: 10, 이후 25의 배수 (용사 탭의 "다음 마일스톤까지")
func next_milestone_level(level: int) -> int:
	if level < MILESTONE_FIRST_LEVEL:
		return MILESTONE_FIRST_LEVEL
	return (floori(float(level) / MILESTONE_INTERVAL) + 1) * MILESTONE_INTERVAL


## 공격력: 기본 공격력 × L × 2^m(L). 레벨 0(미고용)은 0
func attack(base_damage: float, level: int) -> float:
	if level <= 0:
		return 0.0
	return base_damage * level * pow(MILESTONE_MULTIPLIER, milestones(level))


## 레벨업 비용 (L → L+1): 기본 비용 × 1.07^L
func level_cost(base_cost: float, level: int) -> float:
	return base_cost * pow(LEVEL_COST_GROWTH, level)


## n레벨 한 번에 구매: 기본 비용 × g^L × (g^n − 1) / (g − 1). g는 레벨업 1.07, 단련 1.3
func bulk_cost(base_cost: float, level: int, count: int, growth: float = LEVEL_COST_GROWTH) -> float:
	return base_cost * pow(growth, level) * (pow(growth, count) - 1.0) / (growth - 1.0)


## 골드로 살 수 있는 최대 n: floor(log(골드 × (g − 1) / (기본 비용 × g^L) + 1) / log(g)). 못 사면 0
func max_affordable(base_cost: float, level: int, gold: float, growth: float = LEVEL_COST_GROWTH) -> int:
	var ratio := gold * (growth - 1.0) / (base_cost * pow(growth, level)) + 1.0
	return floori(log(ratio) / log(growth))


## 용사 클릭 피해. 검술의 기억과 용사의 각성은 M5에서 붙는다
func hero_click_damage(level: int) -> float:
	return attack(HERO_BASE_DAMAGE, level)


func hero_level_cost(level: int) -> float:
	return level_cost(HERO_BASE_COST, level)
