class_name ResourceDisplay
extends RefCounted

## 자원의 표시 정보 (GDD §4.3).
##
## sim의 SimResourceCatalog와 **같은 파일**(data/resources.json)을 읽되,
## sim은 food/capacity를, 여기는 name만 가져간다 (ARCHITECTURE §5).
##
## 파일에 적힌 순서가 곧 화면 표시 순서다. sim의 tracked_ids()는
## 영문 id 알파벳순이라 "석재 · 목재"처럼 뜬금없는 순서가 되므로,
## 표시 순서는 여기서 다시 잡는다.

const COMMENT_PREFIX := "_"

static var _names: Dictionary = {}
static var _order: Array[String] = []
static var _loaded := false


static func name_of(resource_id: String) -> String:
	_ensure_loaded()
	return _names.get(resource_id, resource_id)


static func has(resource_id: String) -> bool:
	_ensure_loaded()
	return _names.has(resource_id)


## 데이터 파일 순서로 정렬한다. 표에 없는 자원은 뒤로 밀되 버리지 않는다
## — 화면에서 사라지면 빠진 것을 눈치채지 못한다.
static func ordered(resource_ids: Array) -> Array[String]:
	_ensure_loaded()

	var known: Array[String] = []
	var unknown: Array[String] = []

	for id in _order:
		if resource_ids.has(id):
			known.append(id)
	for id in resource_ids:
		if not _names.has(id):
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


## "밀 3 → 밀가루 3" 형태로 레시피의 투입·산출을 적는다.
static func format_flow(amounts: Dictionary, separator: String = " · ") -> String:
	var parts: Array[String] = []
	for id in ordered(amounts.keys()):
		parts.append("%s %d" % [name_of(id), int(amounts[id])])
	return separator.join(parts)


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true

	var raw := SimJson.read_dict(SimResourceCatalog.DATA_PATH)
	for key in raw:
		var id := String(key)
		if id.begins_with(COMMENT_PREFIX):
			continue
		_names[id] = String(raw[key].get("name", id))
		_order.append(id)
