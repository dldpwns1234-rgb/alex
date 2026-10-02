extends Node
## 밸런스 시뮬레이션 0부: 무엇을 살지. sim_purchases.gd가 상속한다.
## 골드 대비 진행 속도(DPS × 골드 배율) 상승이 가장 큰 것부터 산다 (용사·동료 레벨, 단련, 승급). 강화석은 강화에, 강화가 다 차면 제작에 쓴다.

var clicks_per_second: float = 4.0  # 정책 인자 taps (GDD 13절은 3~5)
var _exact: bool = true  # 정책 인자 exact=0이면 동료를 몰아 산다 (어림). 1000 도달이 1.7% 빨라지고 실행은 1.5배 빨라 기본은 하나씩 (2026-10-02)


## 진행 속도: (동료 DPS + 클릭 DPS) × 처치 골드 배율. 골드 대비 이 값의 상승이 큰 것부터 산다
func _progress_rate() -> float:
	var boss := Game.is_boss_stage()
	var dps := Party.party_dps(boss) + Party.click_damage() * clicks_per_second
	return dps * (1.0 + Training.value(Balance.Effect.KILL_GOLD))


func _buy_everything() -> void:
	_hire_late_companions()
	for slot in Balance.SLOT_LABELS.size():
		while Equipment.enhance(slot):
			pass
	while _all_enhanced() and Equipment.craft(_weakest_slot()):
		pass
	# 골드당 진행 속도 상승을 후보마다 기억해 두고 산 것만 다시 잰다: 동료 i(c)와 그 승급(p)의 상승은 다른 동료를 사도 그대로다 (성직자 레벨은 빼고).
	# 모두에게 곱해지는 것(단련, 용사 마일스톤의 각성 배율)을 사면 전부 다시 잰다. 레벨마다 41개를 다시 재던 것이 실행 시간의 90%였다
	var cache := {}
	while true:
		var current := _progress_rate()
		var best_ratio := 0.0
		var best := ""
		var runner_up := 0.0  # 두 번째로 좋은 비율. 몰아 살 때 이보다 나빠지기 전까지 산다
		for key in _buy_keys():
			if not _can_buy_key(key):
				continue
			if not cache.has(key) or key[0] == "h" or key[0] == "t" or key == "c%d" % Balance.Companion.CLERIC:  # 성직자 레벨은 버프로 모두의 DPS에 곱해져 늘 다시 잰다
				cache[key] = _key_ratio(key, current)
			if cache[key] > best_ratio or key == "h":  # 용사는 살 수 있으면 기본으로 고른다 (예전 그대로)
				runner_up = maxf(runner_up, best_ratio)
				best_ratio = cache[key]
				best = key
			else:
				runner_up = maxf(runner_up, cache[key])
		if best.is_empty():
			return
		var milestones := Balance.milestones(Party.hero_level)
		var index := int(best.substr(1))
		var cleric_before := _cleric_multiplier()
		match best[0]:
			"h": Party.buy_hero()
			"c":
				for _k in (1 if _exact else _run_length(index, best_ratio, runner_up)):
					Party.buy_companion(index)
			"t": Training.buy(index)
			"p": Promotions.promote(index)
		cache.erase("c%d" % index)
		cache.erase("p%d" % index)
		if best[0] == "t" or Balance.milestones(Party.hero_level) != milestones:
			cache.clear()
		elif best == "c%d" % Balance.Companion.CLERIC:
			# 성직자 버프는 다른 동료·승급의 상승에 똑같이 곱해진다: 지우지 않고 배율만큼 곱한다 (후반 구매의 절반이 성직자라 지우면 느렸다)
			var factor := _cleric_multiplier() / cleric_before
			for key: String in cache:
				cache[key] *= factor


## 몰아 사기: 이 동료를 연달아 몇 레벨 살지. 다음 레벨의 상승은 공식(Balance.companion_dps의 차)에 지금 잰 공통 배율을 곱해 어림하고,
## 두 번째 후보의 비율 아래로 떨어지거나 골드가 모자라면 멈춘다. 다른 후보의 값은 그동안 그대로라고 본다 (그래서 어림이다).
## 성직자는 버프가 모두에게 곱해져 공통 배율이 바뀌므로 하나씩 산다. 사람이 '최대'로 몰아 사는 것에 가깝다
func _run_length(index: int, ratio: float, runner_up: float) -> int:
	if index == Balance.Companion.CLERIC:
		return 1
	var mods := Party._mods()
	var boss := Game.is_boss_stage()
	var level := Party.companion_level(index)
	var bought := Party.companion_levels[index]
	var first := Party.companion_purchase(index).cost
	var gain := Balance.companion_dps(index, level + 1, boss, mods) - Balance.companion_dps(index, level, boss, mods)
	if gain <= 0.0:
		return 1
	var scale := ratio * first / gain  # 공식 상승 → 진행 속도 상승
	var gold := Game.gold - first
	var count := 1
	while count < Balance.MAX_LEVEL - level:
		var cost := Balance.companion_cost(index, bought + count)
		var next := Balance.companion_dps(index, level + count + 1, boss, mods) - Balance.companion_dps(index, level + count, boss, mods)
		if cost > gold or next * scale / cost < runner_up:
			break
		gold -= cost
		count += 1
	return count


func _cleric_multiplier() -> float:
	return Balance.cleric_multiplier(Party.companion_level(Balance.Companion.CLERIC), Training.mods()["cleric_buff"])


func _buy_keys() -> PackedStringArray:
	var keys := PackedStringArray(["h"])  # 견주는 순서는 예전과 같다 (같으면 앞의 것): 용사, 동료, 단련, 승급
	for i in Party.companion_levels.size():
		keys.append("c%d" % i)
	for i in Training.levels.size():
		keys.append("t%d" % i)
	for i in Promotions.ranks.size():
		keys.append("p%d" % i)
	return keys


func _can_buy_key(key: String) -> bool:
	var i := int(key.substr(1))
	match key[0]:
		"h": return Party.hero_purchase().affordable
		"c": return Party.is_companion_unlocked(i) and Party.companion_purchase(i).affordable
		"t": return Training.can_buy(i)
	return Promotions.can_promote(i)


## 한 단계 사면 진행 속도가 골드당 얼마나 오르는지. 진행 속도에 안 잡히는 단련(보스 시간, 스킬, 재등장 등)은 싸면 산다
func _key_ratio(key: String, current: float) -> float:
	var i := int(key.substr(1))
	var cost := 0.0
	match key[0]:
		"h":
			cost = Party.hero_purchase().cost
			Party.hero_level += 1
		"c":
			cost = Party.companion_purchase(i).cost
			Party.companion_levels[i] += 1
		"t":
			cost = Training.purchase(i).cost
			Training.levels[i] += 1
		"p":
			cost = Promotions.cost(i)
			Promotions.ranks[i] += 1
	var gain := _progress_rate() - current
	match key[0]:
		"h": Party.hero_level -= 1
		"c": Party.companion_levels[i] -= 1
		"t": Training.levels[i] -= 1
		"p": Promotions.ranks[i] -= 1
	if key[0] == "t" and gain <= 0.0:
		return 1e9 if cost <= Game.gold * 0.02 else 0.0
	return gain / cost


## 장비가 든 칸이 모두 +10인지. 그때부터 남는 강화석을 제작에 쓴다 (강화가 남았으면 모은다)
func _all_enhanced() -> bool:
	for slot in Balance.SLOT_LABELS.size():
		if Equipment.has_item(slot) and not Equipment.is_enhance_maxed(slot):
			return false
	return true


## 효과가 가장 작은 칸 (빈 칸이 먼저). 제작으로 채울 자리
func _weakest_slot() -> int:
	var weakest := 0
	for slot in Balance.SLOT_LABELS.size():
		if Equipment.effect(slot) < Equipment.effect(weakest):
			weakest = slot
	return weakest


## 늦게 합류한 동료(용기사, 600)는 다른 동료가 수천 레벨이라 1레벨의 DPS가 부동소수에 묻혀 증가분이 0으로 나온다.
## 한 레벨씩 견주는 탐욕 구매로는 영영 안 사므로, 사람처럼 구매 배수 최대로 한 번에 고용한다
func _hire_late_companions() -> void:
	for i in Party.companion_levels.size():
		if Party.is_companion_hired(i) or not Party.is_companion_unlocked(i) or not Party.companion_purchase(i).affordable:
			continue
		var before := _progress_rate()
		Party.companion_levels[i] += 1
		var gain := _progress_rate() - before
		Party.companion_levels[i] -= 1
		if gain > 0.0:
			continue
		Party.set_buy_mode(Party.BuyMode.MAX)
		Party.buy_companion(i)
		Party.set_buy_mode(Party.BuyMode.ONE)
