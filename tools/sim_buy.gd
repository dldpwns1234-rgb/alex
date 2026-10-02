extends Node
## 밸런스 시뮬레이션 0부: 무엇을 살지. sim_purchases.gd가 상속한다.
## 골드 대비 진행 속도(DPS × 골드 배율) 상승이 가장 큰 것부터 산다 (용사·동료 레벨, 단련, 승급). 강화석은 강화에, 강화가 다 차면 제작에 쓴다.

var clicks_per_second: float = 4.0  # 정책 인자 taps (GDD 13절은 3~5)


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
	# 모두에게 곱해지는 것(성직자, 단련, 용사 마일스톤의 각성 배율)을 사면 전부 다시 잰다. 레벨마다 41개를 다시 재던 것이 실행 시간의 90%였다
	var cache := {}
	while true:
		var current := _progress_rate()
		var best_ratio := 0.0
		var best := ""
		for key in _buy_keys():
			if not _can_buy_key(key):
				continue
			if not cache.has(key) or key[0] == "h" or key[0] == "t" or key == "c%d" % Balance.Companion.CLERIC:  # 성직자 레벨은 버프로 모두의 DPS에 곱해져 늘 다시 잰다
				cache[key] = _key_ratio(key, current)
			if cache[key] > best_ratio or key == "h":  # 용사는 살 수 있으면 기본으로 고른다 (예전 그대로)
				best_ratio = cache[key]
				best = key
		if best.is_empty():
			return
		var milestones := Balance.milestones(Party.hero_level)
		var index := int(best.substr(1))
		match best[0]:
			"h": Party.buy_hero()
			"c": Party.buy_companion(index)
			"t": Training.buy(index)
			"p": Promotions.promote(index)
		cache.erase("c%d" % index)
		cache.erase("p%d" % index)
		if best[0] == "t" or index == Balance.Companion.CLERIC and best[0] != "h" or Balance.milestones(Party.hero_level) != milestones:
			cache.clear()


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
