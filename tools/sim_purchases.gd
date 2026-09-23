extends Node
## 밸런스 시뮬레이션 1부: 구매 정책. balance_sim.gd가 상속한다.
## 골드 대비 진행 속도(DPS × 골드 배율) 상승이 가장 큰 것부터 산다 (용사·동료 레벨, 단련, 승급. 진행 속도에 안 잡히는
## 단련은 골드의 2% 이하일 때). 강화석은 생기는 대로 강화에, 결정은 검술·황금 중 싼 것에, 운명의 실은 셋 중 싼 것에 쓴다.

const CLICKS_PER_SECOND: float = 4.0


## 진행 속도: (동료 DPS + 클릭 DPS) × 처치 골드 배율. 골드 대비 이 값의 상승이 큰 것부터 산다
func _progress_rate() -> float:
	var boss := Game.is_boss_stage()
	var dps := Party.party_dps(boss) + Party.click_damage() * CLICKS_PER_SECOND
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


## 결정은 검술의 기억과 황금의 기억 중 싼 것부터
func _buy_memories() -> void:
	while true:
		var sword: int = Balance.Memory.SWORD
		var gold: int = Balance.Memory.GOLD
		var pick := sword if Prestige.memory_cost(sword) <= Prestige.memory_cost(gold) else gold
		if not Prestige.buy(pick):
			return


## 운명의 실은 숙명·인연·예지 중 싼 것부터 (같으면 앞의 것)
func _buy_fates() -> void:
	while true:
		var best := -1
		for i in Balance.FATES.size():
			if Rebirth.can_buy(i) and (best < 0 or Rebirth.fate_cost(i) < Rebirth.fate_cost(best)):
				best = i
		if best < 0 or not Rebirth.buy(best):
			return
