extends Node
## 화면 설정 (GDD 9절): 하단 메뉴 시트의 높이. 게임 수치가 아니라 보는 방식이라 회귀·환생해도 남고 데이터 초기화에서만 기본값으로 돌아간다.
## 저장은 Save가 "prefs" 절로 한다. UI는 set_sheet_height()로 바꾸고 sheet_height_changed를 받아 움직인다 (scenes/sheet.gd).

signal sheet_height_changed(height: float)

var sheet_height: float = 0.0  # 하단 메뉴 시트 높이(px). 0이면 접힌 기본 높이 (화면이 정한다)


## 바꾸면 알린다. 같은 값이면 조용하다
func set_sheet_height(height: float) -> void:
	var clamped := maxf(height, 0.0)
	if is_equal_approx(clamped, sheet_height):
		return
	sheet_height = clamped
	sheet_height_changed.emit(sheet_height)


func reset() -> void:
	set_sheet_height(0.0)


func to_dict() -> Dictionary:
	return {"sheet_height": sheet_height}


## 없는 필드는 기본값(접힘)으로
func from_dict(data: Dictionary) -> void:
	set_sheet_height(float(data.get("sheet_height", 0.0)))
