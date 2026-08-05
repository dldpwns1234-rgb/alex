class_name SimFamily
extends RefCounted

## 가구 하나 (GDD §4.1).
##
## **인구는 숫자가 아니라 가구다.** 가구 하나 = 오두막 하나 = 일자리 하나.
##
## 노동력 제로섬(GDD §4.4의 2번)이 여기서 구조적으로 보장된다:
## 가구는 `workplace_slot`을 하나만 갖는다. 방앗간에 넣으면 농장에서 빠진다.
## 합계를 따로 검사해서 막는 것이 아니라, 애초에 두 곳에 있을 수 없다.

## 일하는 건물의 슬롯 번호. -1이면 유휴.
var workplace_slot: int = -1


func is_idle() -> bool:
	return workplace_slot < 0
