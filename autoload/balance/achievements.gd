extends "res://autoload/balance/training.gd"
## Balance 6부: 업적 (GDD 7.5절). 누적 통계가 목표에 닿으면 열리고 영구 보너스(모든 피해 또는 처치 골드)를 준다.
## 통계는 Stat 열거형 순서, 업적은 통계별로 목표가 오르는 순서다 (같은 통계끼리 모여 있어 탭이 묶어 보인다)

enum Stat { STAGE, KILLS, BOSS_KILLS, GOLD, TAPS, PRESTIGES, SKILLS, HERO_LEVEL, PARTY, REBIRTHS }
enum Reward { DAMAGE, GOLD }
const ACHIEVEMENTS: Array[Dictionary] = [
	{"stat": Stat.STAGE, "goal": 10.0, "name": "첫 발걸음", "reward": Reward.DAMAGE, "amount": 0.01},
	{"stat": Stat.STAGE, "goal": 25.0, "name": "마을 밖으로", "reward": Reward.DAMAGE, "amount": 0.01},
	{"stat": Stat.STAGE, "goal": 50.0, "name": "국경 너머", "reward": Reward.DAMAGE, "amount": 0.02},
	{"stat": Stat.STAGE, "goal": 100.0, "name": "백 개의 관문", "reward": Reward.DAMAGE, "amount": 0.02},
	{"stat": Stat.STAGE, "goal": 200.0, "name": "마왕성의 그림자", "reward": Reward.DAMAGE, "amount": 0.03},
	{"stat": Stat.STAGE, "goal": 300.0, "name": "심연의 문턱", "reward": Reward.DAMAGE, "amount": 0.03},
	{"stat": Stat.STAGE, "goal": 500.0, "name": "전설의 여정", "reward": Reward.DAMAGE, "amount": 0.03},
	{"stat": Stat.KILLS, "goal": 100.0, "name": "신참 사냥꾼", "reward": Reward.DAMAGE, "amount": 0.01},
	{"stat": Stat.KILLS, "goal": 1000.0, "name": "숙련된 사냥꾼", "reward": Reward.DAMAGE, "amount": 0.02},
	{"stat": Stat.KILLS, "goal": 10000.0, "name": "마왕군의 악몽", "reward": Reward.DAMAGE, "amount": 0.03},
	{"stat": Stat.KILLS, "goal": 100000.0, "name": "전장의 학살자", "reward": Reward.DAMAGE, "amount": 0.03},
	{"stat": Stat.BOSS_KILLS, "goal": 10.0, "name": "두목 사냥", "reward": Reward.DAMAGE, "amount": 0.01},
	{"stat": Stat.BOSS_KILLS, "goal": 50.0, "name": "두목 전문가", "reward": Reward.DAMAGE, "amount": 0.02},
	{"stat": Stat.BOSS_KILLS, "goal": 200.0, "name": "두목의 천적", "reward": Reward.DAMAGE, "amount": 0.03},
	{"stat": Stat.BOSS_KILLS, "goal": 1000.0, "name": "왕관 수집가", "reward": Reward.DAMAGE, "amount": 0.03},
	{"stat": Stat.GOLD, "goal": 1e4, "name": "첫 금화 주머니", "reward": Reward.GOLD, "amount": 0.01},
	{"stat": Stat.GOLD, "goal": 1e6, "name": "금고 개장", "reward": Reward.GOLD, "amount": 0.02},
	{"stat": Stat.GOLD, "goal": 1e8, "name": "상단의 주인", "reward": Reward.GOLD, "amount": 0.02},
	{"stat": Stat.GOLD, "goal": 1e12, "name": "황금 왕국", "reward": Reward.GOLD, "amount": 0.03},
	{"stat": Stat.GOLD, "goal": 1e16, "name": "부의 신화", "reward": Reward.GOLD, "amount": 0.03},
	{"stat": Stat.TAPS, "goal": 1000.0, "name": "휘두르고 또 휘두르고", "reward": Reward.DAMAGE, "amount": 0.01},
	{"stat": Stat.TAPS, "goal": 10000.0, "name": "검의 달인", "reward": Reward.DAMAGE, "amount": 0.02},
	{"stat": Stat.TAPS, "goal": 100000.0, "name": "검성", "reward": Reward.DAMAGE, "amount": 0.03},
	{"stat": Stat.PRESTIGES, "goal": 1.0, "name": "첫 회귀", "reward": Reward.GOLD, "amount": 0.02},
	{"stat": Stat.PRESTIGES, "goal": 3.0, "name": "반복되는 시간", "reward": Reward.GOLD, "amount": 0.02},
	{"stat": Stat.PRESTIGES, "goal": 10.0, "name": "운명의 개척자", "reward": Reward.GOLD, "amount": 0.03},
	{"stat": Stat.PRESTIGES, "goal": 25.0, "name": "시간의 지배자", "reward": Reward.GOLD, "amount": 0.03},
	{"stat": Stat.SKILLS, "goal": 10.0, "name": "각성", "reward": Reward.GOLD, "amount": 0.01},
	{"stat": Stat.SKILLS, "goal": 100.0, "name": "필살기의 달인", "reward": Reward.GOLD, "amount": 0.02},
	{"stat": Stat.HERO_LEVEL, "goal": 50.0, "name": "용사의 자격", "reward": Reward.DAMAGE, "amount": 0.02},
	{"stat": Stat.HERO_LEVEL, "goal": 150.0, "name": "전설의 용사", "reward": Reward.DAMAGE, "amount": 0.03},
	{"stat": Stat.PARTY, "goal": 4.0, "name": "파티 완성", "reward": Reward.GOLD, "amount": 0.02},
	{"stat": Stat.REBIRTHS, "goal": 1.0, "name": "새로운 삶", "reward": Reward.DAMAGE, "amount": 0.03},
	{"stat": Stat.REBIRTHS, "goal": 5.0, "name": "윤회를 넘어", "reward": Reward.GOLD, "amount": 0.03},
]
## 통계별 이름 (업적 탭의 묶음 제목)
const STAT_LABELS: Dictionary = {
	Stat.STAGE: "스테이지", Stat.KILLS: "처치", Stat.BOSS_KILLS: "보스", Stat.GOLD: "골드", Stat.TAPS: "탭",
	Stat.PRESTIGES: "회귀", Stat.SKILLS: "스킬", Stat.HERO_LEVEL: "용사", Stat.PARTY: "동료", Stat.REBIRTHS: "환생",
}
## 목표 설명. %s 자리에 목표 수치(Num.format)가 들어간다
const STAT_GOAL_FORMATS: Dictionary = {
	Stat.STAGE: "스테이지 %s 도달", Stat.KILLS: "몬스터 %s마리 처치", Stat.BOSS_KILLS: "보스 %s마리 처치",
	Stat.GOLD: "골드 %s 획득", Stat.TAPS: "%s번 탭", Stat.PRESTIGES: "회귀 %s회", Stat.SKILLS: "스킬 %s회 사용",
	Stat.HERO_LEVEL: "용사 Lv %s 도달", Stat.PARTY: "동료 %s명 고용", Stat.REBIRTHS: "환생 %s회",
}
const REWARD_LABELS: Dictionary = {Reward.DAMAGE: "모든 피해", Reward.GOLD: "처치 골드"}


func achievement_name(index: int) -> String:
	return ACHIEVEMENTS[index]["name"]


func achievement_stat(index: int) -> int:
	return ACHIEVEMENTS[index]["stat"]


func achievement_goal(index: int) -> float:
	return ACHIEVEMENTS[index]["goal"]


func achievement_reward(index: int) -> int:
	return ACHIEVEMENTS[index]["reward"]


func achievement_amount(index: int) -> float:
	return ACHIEVEMENTS[index]["amount"]


func stat_label(stat: int) -> String:
	return STAT_LABELS[stat]


## 목표 설명. goal_text는 Num.format으로 만든 목표 수치. 예: "스테이지 10 도달", "골드 1만 획득"
func achievement_goal_text(index: int, goal_text: String) -> String:
	return STAT_GOAL_FORMATS[achievement_stat(index)] % goal_text


## 보너스 설명. 예: "모든 피해 +1%"
func achievement_reward_note(index: int) -> String:
	return "%s +%d%%" % [REWARD_LABELS[achievement_reward(index)], roundi(achievement_amount(index) * 100.0)]


## 달성한 업적의 보너스를 종류별로 더한 배율: 1 + (달성한 같은 종류 보너스의 합). 종류가 다르면 각자 곱한다
func achievement_multiplier(reward: int, unlocked: Array[bool]) -> float:
	var total := 0.0
	for i in mini(unlocked.size(), ACHIEVEMENTS.size()):
		if unlocked[i] and achievement_reward(i) == reward:
			total += achievement_amount(i)
	return 1.0 + total
