class_name SimRecipe
extends RefCounted

## 건물이 만드는 것 하나.
##
## `worker_days`는 "가구 × 일"이다. 4라면 1가구로 4일, 2가구로 2일이 걸린다.
## 인력을 옮기는 것이 곧 속도를 옮기는 것이므로, 이 단위가 M2의 제로섬을
## 플레이어에게 체감시키는 지점이다 (GDD §4.4의 2번).

var id: String = ""
## 비어 있으면 채취다 — 재료 없이 만들어낸다.
var inputs: Dictionary = {}
var outputs: Dictionary = {}
var worker_days: int = 1


static func from_dict(raw: Dictionary) -> SimRecipe:
	var recipe := SimRecipe.new()
	recipe.id = String(raw.get("id", ""))
	recipe.worker_days = maxi(1, int(raw.get("worker_days", 1)))

	for resource_id in raw.get("in", {}):
		recipe.inputs[String(resource_id)] = int(raw["in"][resource_id])
	for resource_id in raw.get("out", {}):
		recipe.outputs[String(resource_id)] = int(raw["out"][resource_id])

	return recipe


func is_gathering() -> bool:
	return inputs.is_empty()
