extends "res://autoload/balance/companions.gd"
## Balance 3부: 스킬 (GDD 5절). 순서는 Skill 열거형과 같다

enum Skill { STORM_SLASH, BATTLE_CRY, GOLDEN_TOUCH }
const SKILLS: Array[Dictionary] = [
	{"name": "폭풍 베기", "unlock_level": 10},
	{"name": "전투의 함성", "unlock_level": 25},
	{"name": "황금 손길", "unlock_level": 50},
]
const SKILL_DURATION: float = 30.0                 # 초
const SKILL_COOLDOWN: float = 5.0 * 60.0           # 초
const MEDITATION_COOLDOWN_CUT: float = 0.1         # 명상(M5) 레벨당 −10%
const STORM_SLASH_CLICKS_PER_SECOND: float = 10.0  # 폭풍 베기: 초당 자동 클릭
const BATTLE_CRY_MULTIPLIER: float = 2.0           # 전투의 함성: 동료 공격력
const GOLDEN_TOUCH_MULTIPLIER: float = 2.0         # 황금 손길: 처치 골드


func skill_name(index: int) -> String:
	return SKILLS[index]["name"]


func skill_unlock_level(index: int) -> int:
	return SKILLS[index]["unlock_level"]


## 쿨타임: 5분 × (1 − 0.1 × 명상 레벨)
func skill_cooldown(meditation_level: int) -> float:
	return SKILL_COOLDOWN * (1.0 - MEDITATION_COOLDOWN_CUT * meditation_level)


## 스킬 바에 보여줄 효과 설명. 숫자는 위 상수에서 가져온다
func skill_note(index: int) -> String:
	match index:
		Skill.STORM_SLASH:
			return "초당 %d회 자동 클릭" % roundi(STORM_SLASH_CLICKS_PER_SECOND)
		Skill.BATTLE_CRY:
			return "동료 공격력 ×%d" % roundi(BATTLE_CRY_MULTIPLIER)
	return "처치 골드 ×%d" % roundi(GOLDEN_TOUCH_MULTIPLIER)
