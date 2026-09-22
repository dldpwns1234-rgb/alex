extends "res://autoload/balance/memory.gd"
## Balance 5부: 단련 (GDD 6.5절). 한 판 안에서 골드로 사는 반복 구매 패시브. 순서는 GDD 표와 같다

const OWNER_HERO: int = -1  # owner가 이 값이면 용사, 아니면 Companion 인덱스
enum Effect {
	CLICK_DAMAGE, CLICK_CRIT, KILL_GOLD, PARTY_DAMAGE, SKILL_DURATION,
	COMPANION_DAMAGE, RESPAWN_DELAY, BOSS_DAMAGE, BATTLE_CRY,
	ARCHER_CRIT_CHANCE, ARCHER_CRIT_MULT, BOSS_TIME, SKILL_COOLDOWN, MAGE_BOSS_MULT, STORM_CLICKS,
	CLERIC_BUFF, BOSS_GOLD, OFFLINE_RATE, GOLDEN_TOUCH,
}
const TRAINING_COST_FACTOR: float = 5.0    # 해금 레벨의 레벨업 비용 × 5
const TRAINING_COST_GROWTH: float = 1.3    # 단련 레벨마다 ×1.3
const CLICK_CRIT_MULTIPLIER: float = 3.0   # 클릭 치명타 피해 배율
const TRAININGS: Array[Dictionary] = [
	{"owner": -1, "unlock": 10, "name": "연격", "effect": Effect.CLICK_DAMAGE, "per_level": 0.1, "max_level": 10},
	{"owner": -1, "unlock": 25, "name": "급소 찌르기", "effect": Effect.CLICK_CRIT, "per_level": 0.02, "max_level": 10},
	{"owner": -1, "unlock": 50, "name": "전리품 감각", "effect": Effect.KILL_GOLD, "per_level": 0.05, "max_level": 10},
	{"owner": -1, "unlock": 75, "name": "지휘", "effect": Effect.PARTY_DAMAGE, "per_level": 0.05, "max_level": 10},
	{"owner": -1, "unlock": 100, "name": "각성의 잔향", "effect": Effect.SKILL_DURATION, "per_level": 2.0, "max_level": 5},
	{"owner": 0, "unlock": 10, "name": "굳건함", "effect": Effect.COMPANION_DAMAGE, "per_level": 0.2, "max_level": 10},
	{"owner": 0, "unlock": 25, "name": "도발", "effect": Effect.RESPAWN_DELAY, "per_level": -0.02, "max_level": 5},
	{"owner": 0, "unlock": 50, "name": "방패 강타", "effect": Effect.BOSS_DAMAGE, "per_level": 0.1, "max_level": 5},
	{"owner": 0, "unlock": 75, "name": "함성 공명", "effect": Effect.BATTLE_CRY, "per_level": 0.2, "max_level": 5},
	{"owner": 0, "unlock": 100, "name": "백전노장", "effect": Effect.PARTY_DAMAGE, "per_level": 0.05, "max_level": 10},
	{"owner": 1, "unlock": 10, "name": "정밀 사격", "effect": Effect.ARCHER_CRIT_CHANCE, "per_level": 0.02, "max_level": 5},
	{"owner": 1, "unlock": 25, "name": "황금 화살", "effect": Effect.KILL_GOLD, "per_level": 0.05, "max_level": 10},
	{"owner": 1, "unlock": 50, "name": "속사", "effect": Effect.COMPANION_DAMAGE, "per_level": 0.2, "max_level": 10},
	{"owner": 1, "unlock": 75, "name": "관통", "effect": Effect.ARCHER_CRIT_MULT, "per_level": 0.5, "max_level": 4},
	{"owner": 1, "unlock": 100, "name": "매의 눈", "effect": Effect.CLICK_CRIT, "per_level": 0.01, "max_level": 10},
	{"owner": 2, "unlock": 10, "name": "화염 폭발", "effect": Effect.BOSS_TIME, "per_level": 1.0, "max_level": 5},
	{"owner": 2, "unlock": 25, "name": "마나 순환", "effect": Effect.SKILL_COOLDOWN, "per_level": 0.04, "max_level": 5},
	{"owner": 2, "unlock": 50, "name": "대마법", "effect": Effect.MAGE_BOSS_MULT, "per_level": 0.4, "max_level": 5},
	{"owner": 2, "unlock": 75, "name": "원소 폭풍", "effect": Effect.COMPANION_DAMAGE, "per_level": 0.2, "max_level": 10},
	{"owner": 2, "unlock": 100, "name": "시간 왜곡", "effect": Effect.STORM_CLICKS, "per_level": 1.0, "max_level": 5},
	{"owner": 3, "unlock": 10, "name": "축복", "effect": Effect.CLERIC_BUFF, "per_level": 0.002, "max_level": 5},
	{"owner": 3, "unlock": 25, "name": "헌금", "effect": Effect.BOSS_GOLD, "per_level": 0.2, "max_level": 5},
	{"owner": 3, "unlock": 50, "name": "안식", "effect": Effect.OFFLINE_RATE, "per_level": 0.04, "max_level": 5},
	{"owner": 3, "unlock": 75, "name": "신성한 빛", "effect": Effect.COMPANION_DAMAGE, "per_level": 0.2, "max_level": 10},
	{"owner": 3, "unlock": 100, "name": "기적", "effect": Effect.GOLDEN_TOUCH, "per_level": 0.2, "max_level": 5},
]
## 효과 종류별 이름. 동료 DPS는 %s 자리에 동료 이름이 들어간다
const EFFECT_LABELS: Dictionary = {
	Effect.CLICK_DAMAGE: "클릭 피해", Effect.CLICK_CRIT: "클릭 치명타 확률",
	Effect.KILL_GOLD: "처치 골드", Effect.PARTY_DAMAGE: "동료 전체 DPS",
	Effect.SKILL_DURATION: "스킬 지속 시간", Effect.COMPANION_DAMAGE: "%s DPS",
	Effect.RESPAWN_DELAY: "재등장 대기", Effect.BOSS_DAMAGE: "보스에게 주는 피해",
	Effect.BATTLE_CRY: "전투의 함성 배율", Effect.ARCHER_CRIT_CHANCE: "궁수 치명타 확률",
	Effect.ARCHER_CRIT_MULT: "궁수 치명타 배율", Effect.BOSS_TIME: "보스 제한 시간",
	Effect.SKILL_COOLDOWN: "스킬 쿨타임", Effect.MAGE_BOSS_MULT: "마법사 보스 피해 배율",
	Effect.STORM_CLICKS: "폭풍 베기 초당 클릭", Effect.CLERIC_BUFF: "성직자 버프/레벨",
	Effect.BOSS_GOLD: "보스 처치 골드", Effect.OFFLINE_RATE: "오프라인 보상",
	Effect.GOLDEN_TOUCH: "황금 손길 배율",
}
## 효과 크기 뒤에 붙는 단위
const EFFECT_UNITS: Dictionary = {
	Effect.CLICK_DAMAGE: "%", Effect.CLICK_CRIT: "%p", Effect.KILL_GOLD: "%", Effect.PARTY_DAMAGE: "%",
	Effect.SKILL_DURATION: "초", Effect.COMPANION_DAMAGE: "%", Effect.RESPAWN_DELAY: "초",
	Effect.BOSS_DAMAGE: "%", Effect.BATTLE_CRY: "", Effect.ARCHER_CRIT_CHANCE: "%p",
	Effect.ARCHER_CRIT_MULT: "", Effect.BOSS_TIME: "초", Effect.SKILL_COOLDOWN: "%",
	Effect.MAGE_BOSS_MULT: "", Effect.STORM_CLICKS: "회", Effect.CLERIC_BUFF: "%p",
	Effect.BOSS_GOLD: "%", Effect.OFFLINE_RATE: "%p", Effect.GOLDEN_TOUCH: "",
}
## 백분율로 보여주는 효과
const PERCENT_EFFECTS: Array[Effect] = [
	Effect.CLICK_DAMAGE, Effect.CLICK_CRIT, Effect.KILL_GOLD, Effect.PARTY_DAMAGE, Effect.COMPANION_DAMAGE,
	Effect.BOSS_DAMAGE, Effect.ARCHER_CRIT_CHANCE, Effect.SKILL_COOLDOWN, Effect.CLERIC_BUFF, Effect.BOSS_GOLD,
	Effect.OFFLINE_RATE,
]


func training_owner(index: int) -> int:
	return TRAININGS[index]["owner"]


func training_unlock_level(index: int) -> int:
	return TRAININGS[index]["unlock"]


func training_name(index: int) -> String:
	return TRAININGS[index]["name"]


func training_effect(index: int) -> int:
	return TRAININGS[index]["effect"]


func training_per_level(index: int) -> float:
	return TRAININGS[index]["per_level"]


func training_max_level(index: int) -> int:
	return TRAININGS[index]["max_level"]


func owner_name(owner: int) -> String:
	return "용사" if owner == OWNER_HERO else companion_name(owner)


## 첫 레벨 비용: 주인의 해금 레벨 레벨업 비용 × 5
func training_base_cost(index: int) -> float:
	var owner := training_owner(index)
	var base := HERO_BASE_COST if owner == OWNER_HERO else companion_base_cost(owner)
	return level_cost(base, training_unlock_level(index)) * TRAINING_COST_FACTOR


## n → n+1 비용: 첫 레벨 비용 × 1.3^n
func training_cost(index: int, level: int) -> float:
	return training_base_cost(index) * pow(TRAINING_COST_GROWTH, level)


## 효과 이름. 예: "클릭 피해", "전사 DPS"
func training_label(index: int) -> String:
	var effect := training_effect(index)
	if effect == Effect.COMPANION_DAMAGE:
		return EFFECT_LABELS[effect] % owner_name(training_owner(index))
	return EFFECT_LABELS[effect]


## 효과 크기. level이 1이면 레벨당, 그 이상이면 그 레벨까지의 누적. 예: "+10%", "+70%", "-0.02초", "−4%"
func training_amount(index: int, level: int = 1) -> String:
	var effect := training_effect(index)
	var value := training_per_level(index) * level
	var shown := value * 100.0 if effect in PERCENT_EFFECTS else value
	var number := ("%.2f" % shown).rstrip("0").rstrip(".")  # 10 → "10", 0.2 → "0.2", −0.02 → "-0.02"
	var sign := "−" if effect == Effect.SKILL_COOLDOWN else ("+" if shown >= 0.0 else "")
	return sign + number + EFFECT_UNITS[effect]


## 이름과 크기를 붙인 설명. 예: "클릭 피해 +10%"
func training_note(index: int, level: int = 1) -> String:
	return "%s %s" % [training_label(index), training_amount(index, level)]
