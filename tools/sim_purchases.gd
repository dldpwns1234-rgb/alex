extends Node
## 밸런스 시뮬레이션 1부: 정책. balance_sim.gd가 상속한다. 정책 인자(--이름=값)를 읽고, 언제 회귀할지, 무엇을 살지 정한다.
## 골드 대비 진행 속도(DPS × 골드 배율) 상승이 가장 큰 것부터 산다 (용사·동료 레벨, 단련, 승급. 진행 속도에 안 잡히는
## 단련은 골드의 2% 이하일 때). 강화석은 생기는 대로 강화에, 결정은 계획(plan)대로, 운명의 실은 셋 중 싼 것에 쓴다.

var clicks_per_second: float = 4.0  # 정책 인자 taps (GDD 13절은 3~5)
var _goal: int = 0
var _ratio: float = 0.0
var _skills: bool = false
var _plan: String = "sword_gold"
var _stall: float = 180.0
var _extra: int = 0
var _hours: float = 10.0


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


## 회귀 보상이 결정 재산의 ratio배 이상이면 지금 회귀하는 게 낫다고 본다
func _worth_prestige() -> bool:
	return _ratio > 0.0 and Prestige.crystal_reward() >= _ratio * maxf(_crystal_wealth(), Balance.PRESTIGE_BASE_CRYSTALS)


## 진행 속도: (동료 DPS + 클릭 DPS) × 처치 골드 배율. 골드 대비 이 값의 상승이 큰 것부터 산다
func _progress_rate() -> float:
	var boss := Game.is_boss_stage()
	var dps := Party.party_dps(boss) + Party.click_damage() * clicks_per_second
	return dps * (1.0 + Training.value(Balance.Effect.KILL_GOLD))


func _buy_everything() -> void:
	for slot in Balance.SLOT_LABELS.size():
		while Equipment.enhance(slot):
			pass
	while true:
		var current := _progress_rate()
		var best_ratio := 0.0
		var best_kind := ""  # "hero", "companion", "training", "promotion"
		var best_index := -1
		var hero := Party.hero_purchase()
		if hero.affordable:
			Party.hero_level += 1
			best_ratio = (_progress_rate() - current) / hero.cost
			best_kind = "hero"
			Party.hero_level -= 1
		for i in Party.companion_levels.size():
			if not Party.is_companion_unlocked(i):
				continue
			var purchase := Party.companion_purchase(i)
			if not purchase.affordable:
				continue
			Party.companion_levels[i] += 1
			var ratio := (_progress_rate() - current) / purchase.cost
			Party.companion_levels[i] -= 1
			if ratio > best_ratio:
				best_ratio = ratio
				best_kind = "companion"
				best_index = i
		for i in Training.levels.size():
			if not Training.can_buy(i):
				continue
			var purchase := Training.purchase(i)
			Training.levels[i] += 1
			var gain := _progress_rate() - current
			Training.levels[i] -= 1
			# 진행 속도에 안 잡히는 효과(보스 시간, 스킬, 재등장 등)는 싸면 산다
			var ratio := gain / purchase.cost if gain > 0.0 else (1e9 if purchase.cost <= Game.gold * 0.02 else 0.0)
			if ratio > best_ratio:
				best_ratio = ratio
				best_kind = "training"
				best_index = i
		for i in Promotions.ranks.size():
			if not Promotions.can_promote(i):
				continue
			var cost := Promotions.cost(i)
			Promotions.ranks[i] += 1
			var ratio := (_progress_rate() - current) / cost
			Promotions.ranks[i] -= 1
			if ratio > best_ratio:
				best_ratio = ratio
				best_kind = "promotion"
				best_index = i
		match best_kind:
			"hero":
				Party.buy_hero()
			"companion":
				Party.buy_companion(best_index)
			"training":
				Training.buy(best_index)
			"promotion":
				Promotions.promote(best_index)
			_:
				return


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


## 결정 재산: 가진 것 + 상점에 쓴 것 (레벨 L까지 비용 합 = 2^L − 1). 회귀 시점 판단에 쓴다
func _crystal_wealth() -> float:
	var spent := 0.0
	for i in Balance.MEMORIES.size():
		spent += pow(Balance.MEMORY_COST_BASE, Prestige.level(i)) - 1.0
	return Prestige.crystals + spent
