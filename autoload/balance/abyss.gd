extends "res://autoload/balance/transcend.gd"
## Balance 12부: 심연 (GDD 7.13절). 첫 초월 뒤에 여는 끝없는 층. 몬스터 체력은 스테이지 공식이 아니라 들어갈 때 잰 플레이어 피해량에 비례하고
## 층마다 ×1.1씩 는다. 그래서 숫자 한계(1.8e308) 안에서 끝이 없다. 층마다 '오늘 날짜'를 시드로 저주가 붙고, 10층마다 축복을 고른다.
## 순서는 Curse·Blessing·Mark 열거형과 같다

const ABYSS_RUNS_PER_DAY: int = 2           # 하루 원정 (방장 결정 2026-10-02)
const ABYSS_TIME_LIMIT: float = 60.0         # 초. 한 층
const ABYSS_MONSTERS: int = 10               # 한 층의 몬스터. 두목 층은 1마리
const ABYSS_BOSS_INTERVAL: int = 10          # 10층마다 두목과 축복 고르기
const ABYSS_TAPS_PER_SECOND: float = 5.0     # 기준 피해량 = 동료 DPS + 클릭 피해 × 5 (GDD 13절의 초당 3~5회 중 위쪽: 손으로 하는 모드다)
const ABYSS_HP_SECONDS: float = 0.5          # 0층 몬스터 = 기준 피해량 0.5초 몫
const ABYSS_HP_GROWTH: float = 1.1           # 층마다 ×1.1. 10층(×2.59)이 축복 하나(×1.5 안팎)보다 커서 축복만으로 끝없이 내려가지 못한다
const ABYSS_BOSS_HP: float = 12.0            # 두목 = 그 층 몬스터 12마리 몫 (재등장 대기가 없어 10마리보다 조금 단단하게)
const ABYSS_HP_CAP: float = 1e306            # 체력 상한. 피해 상한(1e300)보다 높아 상한에 닿은 피해로도 벽이 남는다
const ABYSS_MIN_BASE: float = 1.0
const ABYSS_CURSE_TIERS: Array[int] = [1, 20, 50]  # 이 층부터 저주 1개, 2개, 3개
const ABYSS_TOUGH_HP: float = 1.5
const ABYSS_SHORT_TIME: float = 2.0 / 3.0
const ABYSS_SLOW_RESPAWN: float = 2.0
const ABYSS_BLESSING_CHOICES: int = 3
const ABYSS_FURY_MULTIPLIER: float = 1.5     # 축복: 클릭 피해. ×2는 10층 성장(×2.59)에 가까워 축복만으로 70층 넘게 내려갔다
const ABYSS_BOND_MULTIPLIER: float = 3.0     # 축복: 동료 하나
const ABYSS_TIME_BLESSING: float = 15.0      # 축복: 제한 시간 +15초
const ABYSS_STONE_BASE: float = 1.0          # 층마다 심연석 = (1 + 층 × 0.1) × (1 + 0.25 × 저주 무게) × 수확
const ABYSS_STONE_PER_FLOOR: float = 0.1
const ABYSS_CURSE_REWARD: float = 0.25
const ABYSS_STARS_PER_TEN: float = 1.0       # 처음 닿은 10층마다 별의 파편
const ABYSS_STARS_PER_HUNDRED: float = 10.0  # 100층마다는 10개 (10층 몫 대신)
const ABYSS_VISUAL_BASE: int = 601           # 그림: 마왕성 몬스터를 10스테이지씩 돌린다 (끝자리 1이라 마왕 스테이지에 걸리지 않는다)
const ABYSS_VISUAL_SPAN: int = 3390

enum Curse { SEAL, CLICK_ONLY, SLOW, NO_CRIT, SHORT, TOUGH, SILENCE }
const CURSES: Array[Dictionary] = [
	{"name": "사슬", "note": "동료 하나가 싸우지 않는다", "weight": 0.5},
	{"name": "고립", "note": "동료가 싸우지 않는다 (용사만)", "weight": 1.0},
	{"name": "느린 숨", "note": "재등장 대기 ×2", "weight": 0.5},
	{"name": "무딘 칼날", "note": "치명타 없음", "weight": 0.5},
	{"name": "조여드는 시간", "note": "제한 시간 ×2/3", "weight": 1.5},
	{"name": "단단한 껍질", "note": "몬스터 체력 ×1.5", "weight": 1.5},
	{"name": "침묵", "note": "스킬 봉인", "weight": 1.0},
]
enum Blessing { FURY, BOND, CLEANSE, TIME }
const BLESSINGS: Array[String] = ["분노", "유대", "정화", "유예"]
enum Mark { POWER, TIME, HARVEST, STORM_COOLDOWN, STORM_DURATION }
const MARKS: Array[Dictionary] = [
	{"name": "심연의 힘", "max_level": 0, "base_cost": 20.0, "cost_growth": 1.12},
	{"name": "심연의 시간", "max_level": 10, "base_cost": 40.0, "cost_growth": 1.5},
	{"name": "심연의 수확", "max_level": 10, "base_cost": 50.0, "cost_growth": 1.5},
	# 폭풍 베기 각인 둘은 본편에도 듣는다 (방장 제안 2026-10-02: 심연의 성장 동기). 다 올리면 쿨타임 2분에 80초
	{"name": "폭풍의 날", "max_level": 10, "base_cost": 60.0, "cost_growth": 1.6},
	{"name": "폭풍의 숨", "max_level": 10, "base_cost": 60.0, "cost_growth": 1.6},
]
const MARK_POWER_MULTIPLIER: float = 1.1     # = 층 성장. 1레벨이 1층이다
const MARK_TIME_PER_LEVEL: float = 3.0
const MARK_HARVEST_PER_LEVEL: float = 0.2
const MARK_STORM_COOLDOWN_CUT: float = 0.05     # 폭풍 베기 쿨타임 −5%/레벨
const MARK_STORM_SECONDS: float = 5.0           # 폭풍 베기 지속 +5초/레벨


func abyss_is_boss_floor(floor: int) -> bool:
	return floor > 0 and floor % ABYSS_BOSS_INTERVAL == 0


## 몬스터 체력: 기준 피해량 × 0.5초 × 1.1^(층 − 심연의 힘) (단단한 껍질 ×1.5, 두목 ×12). 힘을 피해 대신 체력에서 빼서 숫자가 커지지 않는다
func abyss_monster_hp(base_damage: float, floor: int, power_level: int, tough: bool, boss: bool) -> float:
	var hp := maxf(base_damage, ABYSS_MIN_BASE) * ABYSS_HP_SECONDS * pow(ABYSS_HP_GROWTH, floor - power_level)
	if tough:
		hp *= ABYSS_TOUGH_HP
	if boss:
		hp *= ABYSS_BOSS_HP
	return clampf(hp, 1e-6, ABYSS_HP_CAP)


## 한 층의 제한 시간: (60 + 심연의 시간 + 유예 축복) × (조여드는 시간이면 2/3)
func abyss_time_limit(time_level: int, time_blessings: int, short: bool) -> float:
	var limit := ABYSS_TIME_LIMIT + MARK_TIME_PER_LEVEL * time_level + ABYSS_TIME_BLESSING * time_blessings
	return limit * ABYSS_SHORT_TIME if short else limit


func abyss_curse_count(floor: int) -> int:
	var count := 0
	for start in ABYSS_CURSE_TIERS:
		if floor >= start:
			count += 1
	return maxi(count, 1)


## 이 층의 저주: 날짜와 층을 시드로 섞어 앞에서 개수만큼 (하루 동안 같다). 정화로 지운 저주는 뽑힌 뒤에 뺀다 (순서가 바뀌지 않게)
func abyss_floor_curses(seed: String, floor: int, removed: Array[int]) -> Array[int]:
	var order := _abyss_shuffle(seed, floor, "curse", CURSES.size())
	var curses: Array[int] = []
	for i in abyss_curse_count(floor):
		if not removed.has(order[i]):
			curses.append(order[i])
	return curses


## 축복 셋: 날짜와 층을 시드로 넷 중 셋
func abyss_blessing_offers(seed: String, floor: int) -> Array[int]:
	var order := _abyss_shuffle(seed, floor, "blessing", BLESSINGS.size())
	return order.slice(0, ABYSS_BLESSING_CHOICES)


## 시드로 0 ~ n−1 중 하나 (사슬이 묶는 동료, 유대·정화의 대상)
func abyss_pick(seed: String, floor: int, salt: String, n: int) -> int:
	if n <= 0:
		return -1
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s/%d/%s" % [seed, floor, salt])
	return rng.randi_range(0, n - 1)


func _abyss_shuffle(seed: String, floor: int, salt: String, n: int) -> Array[int]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s/%d/%s" % [seed, floor, salt])
	var order: Array[int] = []
	for i in n:
		order.append(i)
	for i in range(n - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := order[i]
		order[i] = order[j]
		order[j] = swap
	return order


func abyss_curse_weight(curses: Array[int]) -> float:
	var total := 0.0
	for curse in curses:
		total += float(CURSES[curse]["weight"])
	return total


## 층 돌파 심연석: 내림((1 + 층 × 0.1) × (1 + 0.25 × 저주 무게) × (1 + 0.2 × 수확)), 최소 1. 다시 오르는 층도 받는다 (파밍)
func abyss_floor_stones(depth: int, curse_weight: float, harvest_level: int) -> float:
	var stones := (ABYSS_STONE_BASE + ABYSS_STONE_PER_FLOOR * depth) * (1.0 + ABYSS_CURSE_REWARD * curse_weight)
	return maxf(1.0, floor(stones * (1.0 + MARK_HARVEST_PER_LEVEL * harvest_level)))


## 처음 닿은 층의 별의 파편: 100층마다 10, 10층마다 1
func abyss_floor_stars(floor: int) -> float:
	if floor > 0 and floor % (ABYSS_BOSS_INTERVAL * 10) == 0:
		return ABYSS_STARS_PER_HUNDRED
	return ABYSS_STARS_PER_TEN if abyss_is_boss_floor(floor) else 0.0


func abyss_visual_stage(floor: int) -> int:
	return ABYSS_VISUAL_BASE + (maxi(floor - 1, 0) * ABYSS_BOSS_INTERVAL) % ABYSS_VISUAL_SPAN


func abyss_curse_name(index: int) -> String:
	return CURSES[index]["name"]


func abyss_curse_note(index: int) -> String:
	return CURSES[index]["note"]


func abyss_blessing_name(index: int) -> String:
	return BLESSINGS[index]


func mark_name(index: int) -> String:
	return MARKS[index]["name"]


func mark_max_level(index: int) -> int:
	return MARKS[index]["max_level"]


## 각인 다음 레벨 비용: 내림(기본 × 성장^레벨)
func mark_cost(index: int, level: int) -> float:
	var cost := float(MARKS[index]["base_cost"]) * pow(float(MARKS[index]["cost_growth"]), level)
	return minf(floor(cost), MAX_NUMBER)


func mark_power_multiplier(level: int) -> float:
	return minf(pow(MARK_POWER_MULTIPLIER, level), MAX_NUMBER)  # 레벨이 아주 높으면 무한대가 되어 0과 곱할 때 NaN이 난다


func mark_note(index: int) -> String:
	match index:
		Mark.POWER:
			return "심연 안 모든 피해 ×%s (복리, 1레벨 = 1층)" % MARK_POWER_MULTIPLIER
		Mark.TIME:
			return "심연 층 제한 시간 +%d초" % roundi(MARK_TIME_PER_LEVEL)
		Mark.STORM_COOLDOWN:
			return "폭풍 베기 쿨타임 −%d%% (본편에도)" % roundi(MARK_STORM_COOLDOWN_CUT * 100.0)
		Mark.STORM_DURATION:
			return "폭풍 베기 지속 +%d초 (본편에도)" % roundi(MARK_STORM_SECONDS)
	return "심연석 +%d%%" % roundi(MARK_HARVEST_PER_LEVEL * 100.0)
