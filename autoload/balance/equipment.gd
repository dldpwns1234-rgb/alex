extends "res://autoload/balance/achievements.gd"
## Balance 7부: 장비 (GDD 7.6절). 보스가 떨어뜨리고 회귀해도 남는다. 칸(무기·깃발·장신구)마다 효과 종류가 정해져 있고,
## 효과 크기는 등급과 떨어진 스테이지, 칸의 강화 레벨로 정해진다

enum Slot { WEAPON, BANNER, CHARM }
enum Grade { COMMON, FINE, RARE, EPIC, LEGENDARY }
const SLOT_LABELS: PackedStringArray = ["무기", "깃발", "장신구"]
const SLOT_EFFECT_LABELS: PackedStringArray = ["클릭 피해", "동료 전체 DPS", "처치 골드"]
const GRADE_LABELS: PackedStringArray = ["일반", "고급", "희귀", "영웅", "전설"]
const GRADE_WEIGHTS: Array[float] = [50.0, 30.0, 13.0, 6.0, 1.0]    # 뽑힐 비율 (합 100)
const GRADE_MULTIPLIERS: Array[float] = [1.0, 1.5, 2.0, 3.0, 5.0]  # 효과 배율
const GRADE_STONES: Array[float] = [1.0, 2.0, 5.0, 12.0, 30.0]     # 분해하면 나오는 강화석
## 등급 색 (연출용). 이름과 알림에 쓴다
const GRADE_COLORS: Array[Color] = [Color("d8d4e6"), Color("7ddc7a"), Color("6fb4ff"), Color("c98cff"), Color("ffb060")]
const ITEM_NAMES: Array[Array] = [  # Slot 순서, 안은 Grade 순서
	["녹슨 검", "강철 검", "기사의 검", "용살자의 검", "성검"],
	["낡은 깃발", "부대 깃발", "기사단 깃발", "왕국 깃발", "용사의 군기"],
	["구리 반지", "은 반지", "금 반지", "마력의 반지", "왕의 인장"],
]
const BOSS_DROP_CHANCE: float = 0.35     # 보스 처치마다 떨어질 확률
# 효과 = 등급 배율 × (5% + 스테이지 × 0.05%) × (1 + 강화 × 10%). 100스테이지 전설 +50%, 500스테이지 전설 +150%(강화 +10이면 +300%).
# 10% + 0.2%/스테이지는 시뮬레이션에서 판당 +95로 검술의 기억을 압도했다. docs/BALANCE_SIM.md
const EQUIP_BASE_BONUS: float = 0.05
const EQUIP_STAGE_BONUS: float = 0.0005
const ENHANCE_STEP: float = 0.1
const ENHANCE_MAX: int = 10
const ENHANCE_BASE_COST: float = 3.0     # 강화 비용 (n → n+1): 올림(3 × 1.5^n) 강화석 → 3, 5, 7, 11, 16 …
const ENHANCE_COST_GROWTH: float = 1.5


func slot_label(slot: int) -> String:
	return SLOT_LABELS[slot]


func slot_effect_label(slot: int) -> String:
	return SLOT_EFFECT_LABELS[slot]


func grade_label(grade: int) -> String:
	return GRADE_LABELS[grade]


func grade_color(grade: int) -> Color:
	return GRADE_COLORS[grade]


func item_name(slot: int, grade: int) -> String:
	return ITEM_NAMES[slot][grade]


## 0~1 사이 값을 등급으로. 가중치를 앞에서부터 누적한다 (0.5 미만 일반, 0.8 미만 고급, 0.93 미만 희귀, 0.99 미만 영웅)
func roll_grade(value: float) -> int:
	var total := 0.0
	for weight in GRADE_WEIGHTS:
		total += weight
	var acc := 0.0
	for grade in GRADE_WEIGHTS.size():
		acc += GRADE_WEIGHTS[grade] / total
		if value < acc:
			return grade
	return GRADE_WEIGHTS.size() - 1


## 0~1 사이 값을 칸으로 (균등)
func roll_slot(value: float) -> int:
	return clampi(floori(value * SLOT_LABELS.size()), 0, SLOT_LABELS.size() - 1)


## 강화 전 효과: 등급 배율 × (5% + 스테이지 × 0.05%). 어느 장비가 더 좋은지 비교하는 기준
func item_power(grade: int, stage: int) -> float:
	return GRADE_MULTIPLIERS[grade] * (EQUIP_BASE_BONUS + EQUIP_STAGE_BONUS * stage)


## 실제 효과 (더해지는 비율): 강화 전 효과 × (1 + 강화 레벨 × 10%)
func item_effect(grade: int, stage: int, enhance: int) -> float:
	return item_power(grade, stage) * (1.0 + ENHANCE_STEP * enhance)


## 강화석은 정수로만 다루므로 올림한다
func enhance_cost(level: int) -> float:
	return ceil(ENHANCE_BASE_COST * pow(ENHANCE_COST_GROWTH, level))


func dismantle_stones(grade: int) -> float:
	return GRADE_STONES[grade]


## 효과 설명. 예: "클릭 피해 +64%"
func equipment_note(slot: int, effect: float) -> String:
	return "%s +%d%%" % [SLOT_EFFECT_LABELS[slot], roundi(effect * 100.0)]
