extends Node
## Party 1부: 구매 배수(×1, ×10, 최대)와 한 번에 살 레벨 수·비용 계산. party.gd가 상속한다. 골드는 Game이 갖고 있다.

signal buy_mode_changed(mode: BuyMode)

## 구매 배수 (GDD 9절): ×1, ×10, 최대. 용사 탭과 동료 탭이 같이 쓴다
enum BuyMode { ONE, TEN, MAX }


## 한 번에 살 레벨 수와 비용. count는 최소 1이라 못 살 때도 비용을 보여줄 수 있다
class Purchase:
	var count: int = 1
	var cost: float = 0.0
	var affordable: bool = false


var buy_mode: BuyMode = BuyMode.ONE


func set_buy_mode(mode: BuyMode) -> void:
	if buy_mode == mode:
		return
	buy_mode = mode
	buy_mode_changed.emit(mode)


## 현재 구매 배수로 살 레벨 수와 비용. 최대 모드에서 하나도 못 사면 1레벨 비용을 보여준다
func _purchase(base_cost: float, level: int) -> Purchase:
	var count := 1
	match buy_mode:
		BuyMode.TEN:
			count = Balance.BULK_COUNT
		BuyMode.MAX:
			count = maxi(Balance.max_affordable(base_cost, level, Game.gold), 1)
			# 닫힌 공식의 부동소수 오차로 한 레벨 넘칠 수 있으니 실제 비용으로 확인한다
			while count > 1 and Balance.bulk_cost(base_cost, level, count) > Game.gold:
				count -= 1
	var purchase := Purchase.new()
	purchase.count = count
	purchase.cost = Balance.bulk_cost(base_cost, level, count)
	purchase.affordable = Game.gold >= purchase.cost
	return purchase
