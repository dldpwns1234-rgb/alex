class_name SimBuilding
extends RefCounted

## 슬롯에 실제로 놓인 건물 한 채.
##
## SimBuildingType이 "화덕이란 무엇인가"라면, 이쪽은 "3번 슬롯의 저 화덕"이다.

enum State {
	## 건설 중. 자원은 이미 지불되었고 날짜만 남았다.
	UNDER_CONSTRUCTION,
	## 완공. 인력이 붙어 있으면 생산한다.
	ACTIVE,
}

## 생산이 멈춘 이유. 홈 화면 경고 배지와 건물 화면이 같은 값을 읽는다.
## 한글 문구가 아니라 코드다 — 문구는 game 계층의 몫이다 (ARCHITECTURE §2 규칙 2).
const HALT_NONE := ""
const HALT_NO_WORKERS := "no_workers"
const HALT_NO_INPUT := "no_input"
const HALT_STORAGE_FULL := "storage_full"
## 겨울이라 밭이 얼었다. 인력을 더 넣어도 소용없다.
const HALT_WINTER := "winter"

var type_id: String = ""
var slot_index: int = -1
var state: State = State.UNDER_CONSTRUCTION
## 완공까지 남은 일수. 0이면 다음 틱에 완공된다.
var days_remaining: int = 0
## 진행률 표시에 쓴다.
var total_build_days: int = 0

## 지금 만들고 있는 것. 여러 레시피를 가진 건물에서 플레이어가 고른다.
var recipe_id: String = ""
## 쌓인 '가구 × 일'. worker_days를 채우면 한 번 산출한다.
## 계절 배율이 곱해지므로 정수가 아니다 (겨울에는 하루에 0.2씩 쌓인다).
var production_progress: float = 0.0
var halt_reason: String = HALT_NONE


static func start_construction(type: SimBuildingType, slot: int) -> SimBuilding:
	var building := SimBuilding.new()
	building.type_id = type.id
	building.slot_index = slot
	building.total_build_days = type.build_days
	building.days_remaining = type.build_days
	building.state = State.ACTIVE if type.build_days <= 0 else State.UNDER_CONSTRUCTION
	building.recipe_id = type.default_recipe_id()
	return building


func is_complete() -> bool:
	return state == State.ACTIVE


func is_halted() -> bool:
	return halt_reason != HALT_NONE


## 하루 진행. 완공된 순간에만 true를 반환한다.
func advance_construction() -> bool:
	if is_complete():
		return false

	days_remaining -= 1
	if days_remaining > 0:
		return false

	days_remaining = 0
	state = State.ACTIVE
	return true


## 0.0 ~ 1.0. 건설 진행률.
func construction_progress() -> float:
	if total_build_days <= 0:
		return 1.0
	return float(total_build_days - days_remaining) / float(total_build_days)


## 레시피를 바꾸면 진행 중이던 작업은 버린다.
## 밀을 4일 갈다가 순무로 바꾸면서 그 4일이 순무로 넘어가면 이상하다.
func set_recipe(new_recipe_id: String) -> void:
	if new_recipe_id == recipe_id:
		return
	recipe_id = new_recipe_id
	production_progress = 0.0
	halt_reason = HALT_NONE


## 0.0 ~ 1.0. 다음 산출까지의 진행률.
func production_ratio(recipe: SimRecipe) -> float:
	if recipe == null or recipe.worker_days <= 0:
		return 0.0
	return clampf(production_progress / float(recipe.worker_days), 0.0, 1.0)
