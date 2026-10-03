extends "res://autoload/dungeon.gd"
## Abyss 1부: 이번 원정의 상태(기준 피해량, 오늘의 시드, 이번 층의 저주, 고른 축복)와 효과 조회 (GDD 7.13절).
## Game·Party·Skills가 저주와 축복을 여기에 묻는다. 심연 안(Game이 이 모드로 싸우는 중)이 아니면 모두 효과가 없다.
## 입장·층·보상·각인·저장은 abyss.gd에 있다 (이 스크립트를 상속한다). 바깥에서는 Abyss.만 쓴다.

signal floor_started(floor: int)          # 새 층: 저주와 제한 시간이 바뀐다
signal blessing_offered(offers: Array)    # 10층마다 축복 셋. 원소는 {"type": Balance.Blessing, "target": 동료나 저주 번호}

var active: bool = false        # 원정 중. 저장하지 않는다 (불러오면 본편, 원정은 소모)
var base_damage: float = 0.0    # 기준 피해량. 들어갈 때 재고 층이 바뀔 때마다 다시 재서 큰 쪽 (원정 중에 사도 층을 건너뛰지 못하게)
var seed_date: String = ""      # 오늘의 심연: 들어간 날짜가 저주·축복 순서를 정한다
var curses: Array[int] = []     # 이번 층의 저주 (Balance.Curse)
var seal_target: int = -1       # 사슬이 묶은 동료
var removed: Array[int] = []    # 정화로 지운 저주 종류
var fury: int = 0               # 분노 축복 수 (클릭 ×1.5씩)
var bond: Array[int] = []       # 동료별 유대 축복 수 (×3씩)
var time_blessings: int = 0     # 유예 축복 수 (+15초씩)
var offers: Array[Dictionary] = []  # 축복 고르기 중이면 비어 있지 않다. 그동안 전투와 시간이 멈춘다
var _measuring: bool = false    # 기준 피해량을 재는 동안은 축복·저주를 빼고 본다


## 원정 상태를 비운다 (층·시간 포함)
func _clear_run() -> void:
	active = false
	floor = 0
	time_left = 0.0
	base_damage = 0.0
	seed_date = ""
	curses.clear()
	seal_target = -1
	removed.clear()
	fury = 0
	bond.clear()
	bond.resize(Balance.COMPANIONS.size())
	bond.fill(0)
	time_blessings = 0
	offers.clear()


## 기준 피해량: (동료 DPS + 클릭 피해 × 초당 5회) ÷ 전투의 함성. 스킬을 켜 두고 들어가도 벽이 높아지지 않게 함성은 뺀다
func measure_damage() -> float:
	_measuring = true
	var damage := Party.party_dps(false) + Party.click_damage() * Balance.ABYSS_TAPS_PER_SECOND
	_measuring = false
	return clampf(damage / Skills.party_multiplier(), Balance.ABYSS_MIN_BASE, Balance.MAX_NUMBER)


## 저주·축복을 끈 채로 잰다 (오프라인 보상은 본편 기준이다. 원정 중에 앱을 내려 두면 축복이 곱해졌다, 버그 점검 2026-10-03)
func outside(measure: Callable) -> Variant:
	var was := _measuring
	_measuring = true
	var result: Variant = measure.call()
	_measuring = was
	return result


## 저주·축복이 듣는 때: 원정 중이고 Game이 이 모드로 싸우는 중 (회귀·초월로 막 빠져나온 순간이나 재는 동안은 아니다)
func _live() -> bool:
	return active and not _measuring and Game.in_tower and Game.dungeon == self


func has_curse(curse: int) -> bool:
	return _live() and curses.has(curse)


# 효과 조회

## 분노: 클릭 피해 ×1.5씩 (Party)
func click_multiplier() -> float:
	return pow(Balance.ABYSS_FURY_MULTIPLIER, fury) if _live() else 1.0


## 고립: 동료가 싸우지 않는다. 클릭의 각성 몫은 동료 DPS에서 그대로 나온다 (Game)
func companion_scale() -> float:
	return 0.0 if has_curse(Balance.Curse.CLICK_ONLY) else 1.0


## 느린 숨: 재등장 대기 ×2 (Game)
func respawn_multiplier() -> float:
	return Balance.ABYSS_SLOW_RESPAWN if has_curse(Balance.Curse.SLOW) else 1.0


## 무딘 칼날: 클릭 치명타 없음 (Game). 궁수 치명타는 apply_mods가 끈다
func blocks_crit() -> bool:
	return has_curse(Balance.Curse.NO_CRIT)


## 침묵: 스킬 봉인 (Skills). 이미 켜진 스킬은 끝까지 간다
func blocks_skills() -> bool:
	return has_curse(Balance.Curse.SILENCE)


## 이 동료가 싸우지 않는지 (전투 화면의 공격 연출)
func silences(index: int) -> bool:
	return has_curse(Balance.Curse.CLICK_ONLY) or (has_curse(Balance.Curse.SEAL) and index == seal_target)


## 동료 공식에 넘길 보정값에 사슬(×0)·유대(×3씩)·무딘 칼날(궁수 치명타 0)을 얹는다 (Party._mods)
func apply_mods(mods: Dictionary) -> void:
	if not _live():
		return
	var damage: Array = mods.get("companion_damage", [])
	for i in mini(damage.size(), bond.size()):
		damage[i] = float(damage[i]) * pow(Balance.ABYSS_BOND_MULTIPLIER, bond[i])
		if has_curse(Balance.Curse.SEAL) and i == seal_target:
			damage[i] = 0.0
	if has_curse(Balance.Curse.NO_CRIT):
		mods["archer_crit_chance"] = 0.0


## 축복 셋을 고른다: 유대는 고용한 동료 하나, 정화는 아직 안 지운 저주 하나를 시드로 정한다
func _roll_offers() -> void:
	offers.clear()
	for type in Balance.abyss_blessing_offers(seed_date, floor):
		var target := -1
		if type == Balance.Blessing.BOND:
			target = _pick(_hired(), "bond")
		elif type == Balance.Blessing.CLEANSE:
			var left: Array[int] = []
			for curse in Balance.CURSES.size():
				if not removed.has(curse):
					left.append(curse)
			target = _pick(left, "cleanse")
		offers.append({"type": type, "target": target})
	blessing_offered.emit(offers.duplicate())


## 축복 하나를 받는다
func _apply_blessing(offer: Dictionary) -> void:
	var target: int = offer["target"]
	match int(offer["type"]):
		Balance.Blessing.FURY:
			fury += 1
		Balance.Blessing.BOND:
			if target >= 0:
				bond[target] += 1
		Balance.Blessing.CLEANSE:
			if target >= 0 and not removed.has(target):
				removed.append(target)
		Balance.Blessing.TIME:
			time_blessings += 1


func _hired() -> Array[int]:
	var hired: Array[int] = []
	for i in Balance.COMPANIONS.size():
		if Party.is_companion_hired(i):
			hired.append(i)
	return hired


func _pick(candidates: Array[int], salt: String) -> int:
	var k := Balance.abyss_pick(seed_date, floor, salt, candidates.size())
	return candidates[k] if k >= 0 else -1
