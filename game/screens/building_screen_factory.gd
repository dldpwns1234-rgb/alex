class_name BuildingScreenFactory
extends RefCounted

## 건물 종류에 맞는 화면을 만든다.
##
## 베이스 클래스(BuildingScreen)가 직접 서브클래스를 참조하면 순환 의존이 된다
## — 서브클래스는 베이스를 상속하고, 베이스는 서브클래스를 생성하게 되므로.
## 그래서 이 매핑만 따로 떼어 둔다.
##
## 여기 없는 건물은 공통 골격만으로 충분하다는 뜻이다.
## 나무꾼 오두막과 방앗간·화덕이 그렇다 — 레시피 선택과 인력 배정이
## 베이스에 있으므로 고유 화면을 만들 이유가 없다 (ARCHITECTURE §6.2).

static func create(slot_index: int, type_id: String) -> BuildingScreen:
	match type_id:
		"farm":
			return FarmScreen.new(slot_index, type_id)
		"storehouse":
			return StorehouseScreen.new(slot_index, type_id)
		"hut":
			return HutScreen.new(slot_index, type_id)
		_:
			return BuildingScreen.new(slot_index, type_id)
