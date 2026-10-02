extends "res://autoload/balance/rebirth.gd"
## Balance 9부: 도전 판 (GDD 7.9절). 제한을 걸고 목표 스테이지에 닿으면 고유 영구 보너스를 받는 한 번뿐인 판.
## 순서는 CHALLENGES 배열이 곧 목록 순서다. 제한과 보너스 종류는 열거형으로 두고 Challenges가 묻는다

enum Restriction { NO_COMPANIONS, NO_SKILLS, HALF_BOSS_TIME, NO_EQUIPMENT, NO_MEMORIES }
enum Perk { CLICK, COOLDOWN, BOSS_TIME, STONES, CRYSTALS }
const CHALLENGES: Array[Dictionary] = [
	{"name": "홀로 서기", "restriction": Restriction.NO_COMPANIONS, "goal": 200, "perk": Perk.CLICK},
	{"name": "침묵의 검", "restriction": Restriction.NO_SKILLS, "goal": 400, "perk": Perk.COOLDOWN},
	{"name": "시간의 채찍", "restriction": Restriction.HALF_BOSS_TIME, "goal": 450, "perk": Perk.BOSS_TIME},
	{"name": "빈손", "restriction": Restriction.NO_EQUIPMENT, "goal": 450, "perk": Perk.STONES},
	{"name": "맨몸의 회귀", "restriction": Restriction.NO_MEMORIES, "goal": 200, "perk": Perk.CRYSTALS},
]
const CHALLENGE_UNLOCK_REBIRTHS: int = 1        # 환생 1회부터 연다
const CHALLENGE_BOSS_TIME_SCALE: float = 0.5    # 시간의 채찍: 보스 제한 시간 × 0.5
const PERK_CLICK_BONUS: float = 0.25            # 홀로 서기: 클릭 피해 +25%
const PERK_COOLDOWN_CUT: float = 0.1            # 침묵의 검: 스킬 쿨타임 −10%
const PERK_BOSS_TIME_SECONDS: float = 5.0       # 시간의 채찍: 보스 제한 시간 +5초
const PERK_STONE_MULTIPLIER: float = 2.0        # 빈손: 분해 강화석 ×2
const PERK_CRYSTAL_BONUS: float = 0.1           # 맨몸의 회귀: 기억의 결정 +10%


func challenge_name(index: int) -> String:
	return CHALLENGES[index]["name"]


func challenge_goal(index: int) -> int:
	return CHALLENGES[index]["goal"]


func challenge_restriction(index: int) -> int:
	return CHALLENGES[index]["restriction"]


func challenge_perk(index: int) -> int:
	return CHALLENGES[index]["perk"]


func restriction_note(restriction: int) -> String:
	match restriction:
		Restriction.NO_COMPANIONS:
			return "동료가 싸우지 않는다"
		Restriction.NO_SKILLS:
			return "스킬을 쓸 수 없다"
		Restriction.HALF_BOSS_TIME:
			return "보스 제한 시간이 절반"
		Restriction.NO_EQUIPMENT:
			return "장비 효과가 없다"
	return "기억의 상점 효과가 없다"


func perk_note(perk: int) -> String:
	match perk:
		Perk.CLICK:
			return "클릭 피해 +%d%%" % roundi(PERK_CLICK_BONUS * 100.0)
		Perk.COOLDOWN:
			return "스킬 쿨타임 −%d%%" % roundi(PERK_COOLDOWN_CUT * 100.0)
		Perk.BOSS_TIME:
			return "보스 제한 시간 +%d초" % roundi(PERK_BOSS_TIME_SECONDS)
		Perk.STONES:
			return "분해 강화석 ×%d" % roundi(PERK_STONE_MULTIPLIER)
	return "기억의 결정 +%d%%" % roundi(PERK_CRYSTAL_BONUS * 100.0)


# 별자리 시련 (GDD 7.12절): 도전 판의 제한을 둘씩 묶은 판 5개 × 단계 5개. 초월 1회부터 연다

enum TrialReward { BOSS_TIME, CLICK, CRYSTALS, STONES, STARS }
const TRIALS: Array[Dictionary] = [
	{"name": "침묵의 시간", "restrictions": [Restriction.NO_SKILLS, Restriction.HALF_BOSS_TIME], "goal": 300, "reward": TrialReward.BOSS_TIME},
	{"name": "고독한 맨손", "restrictions": [Restriction.NO_COMPANIONS, Restriction.NO_EQUIPMENT], "goal": 150, "reward": TrialReward.CLICK},
	{"name": "망각의 침묵", "restrictions": [Restriction.NO_MEMORIES, Restriction.NO_SKILLS], "goal": 250, "reward": TrialReward.CRYSTALS},
	{"name": "맨손의 질주", "restrictions": [Restriction.NO_EQUIPMENT, Restriction.HALF_BOSS_TIME], "goal": 300, "reward": TrialReward.STONES},
	{"name": "홀로 잊힌 자", "restrictions": [Restriction.NO_COMPANIONS, Restriction.NO_MEMORIES], "goal": 120, "reward": TrialReward.STARS},
]
const TRIAL_TIER_SCALES: Array[float] = [1.0, 1.6, 2.5, 4.0, 6.0]  # 단계마다 목표 배율 (단계 수 = 이 배열의 길이)
const TRIAL_BOSS_SECONDS: float = 3.0     # 단계마다 보스 제한 시간 +3초
const TRIAL_CLICK_MULTIPLIER: float = 2.0  # 단계마다 클릭 피해 ×2 (복리)
const TRIAL_CRYSTAL_MULTIPLIER: float = 2.0
const TRIAL_STONE_BONUS: float = 0.5       # 단계마다 분해 강화석 +50%
const TRIAL_STAR_BONUS: float = 1.0        # 단계마다 초월할 때 별의 파편 +1


func trial_name(index: int) -> String:
	return TRIALS[index]["name"]


func trial_restrictions(index: int) -> Array:
	return TRIALS[index]["restrictions"]


func trial_reward(index: int) -> int:
	return TRIALS[index]["reward"]


## tier(0부터) 단계의 목표 스테이지: 기준 × 배율
func trial_goal(index: int, tier: int) -> int:
	return roundi(TRIALS[index]["goal"] * TRIAL_TIER_SCALES[mini(tier, TRIAL_TIER_SCALES.size() - 1)])


func trial_reward_note(index: int) -> String:
	match trial_reward(index):
		TrialReward.BOSS_TIME:
			return "단계마다 보스 제한 시간 +%d초" % roundi(TRIAL_BOSS_SECONDS)
		TrialReward.CLICK:
			return "단계마다 클릭 피해 ×%d" % roundi(TRIAL_CLICK_MULTIPLIER)
		TrialReward.CRYSTALS:
			return "단계마다 기억의 결정 ×%d" % roundi(TRIAL_CRYSTAL_MULTIPLIER)
		TrialReward.STONES:
			return "단계마다 분해 강화석 +%d%%" % roundi(TRIAL_STONE_BONUS * 100.0)
	return "단계마다 초월할 때 별의 파편 +%d" % roundi(TRIAL_STAR_BONUS)


## 시련 줄처럼 제한 둘을 한 줄에 적을 때 쓰는 짧은 이름
func restriction_short(restriction: int) -> String:
	match restriction:
		Restriction.NO_COMPANIONS:
			return "동료 없음"
		Restriction.NO_SKILLS:
			return "스킬 봉인"
		Restriction.HALF_BOSS_TIME:
			return "보스 시간 절반"
		Restriction.NO_EQUIPMENT:
			return "장비 없음"
	return "기억 없음"
