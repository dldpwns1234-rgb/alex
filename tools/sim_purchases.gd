extends "res://tools/sim_buy.gd"
## 밸런스 시뮬레이션 1부: 정책. balance_sim.gd가 상속한다. 정책 인자(--이름=값)를 읽고, 언제 회귀할지 정하며, 결정은 계획(plan)대로,
## 운명의 실과 별의 파편은 싼 것에 쓴다. 골드로 무엇을 살지는 sim_buy.gd(0부)에 있다.

var _goal: int = 0
var _ratio: float = 0.0
var _skills: bool = false
var _plan: String = "sword_gold"
var _stall: float = 180.0
var _extra: int = 0
var _hours: float = 10.0
var _transcends: int = 0  # 0보다 크면 초월을 이만큼 하면 끝낸다 (목표 스테이지 대신)


## "--이름=값" 꼴의 사용자 인자 (godot ... -- --goal=500)
func _parse_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=")
		if parts.size() != 2:
			continue
		match parts[0]:
			"goal": _goal = int(parts[1])
			"ratio": _ratio = float(parts[1])
			"skills": _skills = int(parts[1]) != 0
			"plan": _plan = parts[1]
			"stall": _stall = float(parts[1])
			"extra": _extra = int(parts[1])
			"taps": clicks_per_second = float(parts[1])
			"hours": _hours = float(parts[1])
			"transcends": _transcends = int(parts[1])
			"exact": _exact = int(parts[1]) != 0


## 회귀 보상이 결정 재산의 ratio배 이상이면 지금 회귀하는 게 낫다고 본다
func _worth_prestige() -> bool:
	return _ratio > 0.0 and Prestige.crystal_reward() >= _ratio * maxf(_crystal_wealth(), Balance.PRESTIGE_BASE_CRYSTALS)


## 결정 사용 계획: sword(검술만), sword_gold(검술·황금 중 싼 것), all(일곱 개 중 싼 것. 같으면 앞의 것)
func _buy_memories(plan: String) -> void:
	while true:
		var pick := -1
		for i in Balance.MEMORIES.size():
			if plan == "sword" and i != Balance.Memory.SWORD:
				continue
			if plan == "sword_gold" and i != Balance.Memory.SWORD and i != Balance.Memory.GOLD:
				continue
			if Prestige.can_buy(i) and (pick < 0 or Prestige.memory_cost(i) < Prestige.memory_cost(pick)):
				pick = i
		if pick < 0 or not Prestige.buy(pick):
			return


## 스킬은 쿨타임이 끝나는 대로 쓴다 (사람처럼)
func _use_skills() -> void:
	for i in Balance.SKILLS.size():
		if Skills.can_activate(i):
			Skills.activate(i)


## 운명의 실은 숙명·인연·예지 중 싼 것부터 (같으면 앞의 것)
func _buy_fates() -> void:
	while true:
		var best := -1
		for i in Balance.FATES.size():
			if Rebirth.can_buy(i) and (best < 0 or Rebirth.fate_cost(i) < Rebirth.fate_cost(best)):
				best = i
		if best < 0 or not Rebirth.buy(best):
			return


## 별의 파편은 별의 상점 중 싼 것부터 (같으면 앞의 것). 그 뒤 별빛 날개로 받은 실로 운명을 산다
func _buy_stars() -> void:
	while true:
		var best := -1
		for i in Balance.STARS.size():
			if Transcend.can_buy(i) and (best < 0 or Transcend.star_cost(i) < Transcend.star_cost(best)):
				best = i
		if best < 0 or not Transcend.buy(best):
			break
	_buy_fates()


## 결정 재산: 가진 것 + 상점에 쓴 것 (레벨 L까지 비용 합 = 2^L − 1). 회귀 시점 판단에 쓴다
func _crystal_wealth() -> float:
	var spent := 0.0
	for i in Balance.MEMORIES.size():
		spent += pow(Balance.MEMORY_COST_BASE, Prestige.level(i)) - 1.0
	return Prestige.crystals + spent


