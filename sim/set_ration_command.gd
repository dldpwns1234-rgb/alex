class_name SimSetRationCommand
extends SimCommand

## 배급 정책을 바꾼다 — 창고 화면의 결정 (GDD §4.6).
##
## 저장 한도가 유한하기 때문에 공짜 선택이 아니다.
## 빵은 한 칸에 다섯 끼니가 들어가므로 비축 효율이 가장 좋고,
## 순무부터 먹으면 그 빵이 쌓이지만 순무가 창고를 차지한다.

const ERR_UNKNOWN_POLICY := "unknown_policy"

const VALID_POLICIES := [
	SimVillage.RATION_RICH_FIRST,
	SimVillage.RATION_CHEAP_FIRST,
]

var policy: String


func _init(new_policy: String) -> void:
	policy = new_policy


func execute(world: SimWorld) -> String:
	if not VALID_POLICIES.has(policy):
		return ERR_UNKNOWN_POLICY

	world.village.ration_policy = policy
	return OK
