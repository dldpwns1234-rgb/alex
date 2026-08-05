class_name SimBuildingType
extends RefCounted

## 건물 한 종류의 정의 — data/buildings.json 한 항목에 대응한다.
##
## 시뮬레이션이 알아야 하는 것만 담는다. 한글 이름과 설명은 여기 없다.
## 그것은 표현이고, game 계층의 BuildingDisplay가 같은 파일에서 읽는다
## (ARCHITECTURE §2 규칙 2).

var id: String = ""
## 자원 id → 필요 수량.
var cost: Dictionary = {}
var build_days: int = 0
## M2의 노동력 배분에서 쓴다. M1에서는 표시만 한다.
var workers: int = 0
## 이 건물들이 완공되어 있어야 메뉴에서 해금된다 (GDD §4.5).
var requires: Array[String] = []


static func from_dict(type_id: String, raw: Dictionary) -> SimBuildingType:
	var type := SimBuildingType.new()
	type.id = type_id
	type.build_days = int(raw.get("build_days", 0))
	type.workers = int(raw.get("workers", 0))

	for resource_id in raw.get("cost", {}):
		type.cost[String(resource_id)] = int(raw["cost"][resource_id])

	for required_id in raw.get("requires", []):
		type.requires.append(String(required_id))

	return type
