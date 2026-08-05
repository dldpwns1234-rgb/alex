class_name ResourceDisplay
extends RefCounted

## 자원의 한글 이름 (GDD §4.3).
##
## sim은 자원을 "wood" 같은 id로만 안다 (SimResourcePool).
## 여기 없는 id는 id 그대로 보여준다 — 데이터 파일에 새 자원을 넣었는데
## 이 표가 비어 있으면 화면에 영어가 뜨므로 바로 눈에 띈다.
##
## TODO(M2): 자원이 늘어나면 data/resources.json으로 옮긴다.
##           아이콘도 그때 함께 붙인다.

const NAMES := {
	# 1차 (채취)
	"wood": "목재",
	"stone": "석재",
	"iron_ore": "철광",
	"grain": "곡물",
	"game_meat": "수렵육",
	# 2차 (가공)
	"firewood": "장작",
	"flour": "밀가루",
	"bread": "빵",
	"iron": "철괴",
	# 화폐
	"silver": "은화",
}


static func name_of(resource_id: String) -> String:
	return NAMES.get(resource_id, resource_id)


## 화면에 늘어놓을 순서로 정렬한다.
##
## sim의 tracked_ids()는 영문 id 알파벳순이라 화면에서는 "석재 · 목재"처럼
## 뜬금없는 순서가 된다. 여기 NAMES에 적힌 순서(1차 → 2차 → 화폐)가
## GDD §4.3의 분류 순서이고, 그것이 플레이어가 기대하는 순서다.
##
## 표에 없는 자원은 뒤로 밀되 버리지 않는다 — 화면에서 사라지면 눈치채지 못한다.
static func ordered(resource_ids: Array) -> Array[String]:
	var known: Array[String] = []
	var unknown: Array[String] = []

	for id in NAMES:
		if resource_ids.has(id):
			known.append(String(id))
	for id in resource_ids:
		if not NAMES.has(id):
			unknown.append(String(id))

	unknown.sort()
	known.append_array(unknown)
	return known


## "목재 140  ·  석재 60"
static func format_stock(pool: SimResourcePool, separator: String = "  ·  ") -> String:
	var parts: Array[String] = []
	for id in ordered(pool.tracked_ids()):
		parts.append("%s %d" % [name_of(id), pool.amount_of(id)])
	return separator.join(parts)
