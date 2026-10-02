extends Node
## 밸런스 시뮬레이션 0부 앞: 강화석 쓰기. sim_buy.gd가 상속한다. 강화석은 생기는 대로 강화에, 강화가 다 차면 가장 약한 칸의 제작에 쓴다.


func _spend_stones() -> void:
	for slot in Balance.SLOT_LABELS.size():
		while Equipment.enhance(slot):
			pass
	while _all_enhanced() and Equipment.craft(_weakest_slot()):
		pass


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
