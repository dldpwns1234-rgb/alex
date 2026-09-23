extends SceneTree
## 검격 자국 프레임 8장을 SVG로 만들어 assets/sprites/fx/slash_0.svg ~ slash_7.svg에 쓴다.
##
##   godot --headless --path . --script tools/make_slash_frames.gd
##
## docs/VFX_REFERENCES.md의 결론(Frostwindz 픽셀 슬래시의 수명)을 따른다: 얇은 조각 → 쉼표처럼 자람 →
## 꽉 찬 초승달(흰 심, 중간 톤, 어두운 외곽선, 앞머리는 살짝 말림) → 꼬리부터 침식 → 가닥 → 티끌.
## 6·7번은 난무(연타)용 가는 선이다: 두께 없이 긴 선 하나와 그 조각. 가는 선 여러 개가 연속 참격의 문법이다.
## 세로로 선 ")" 모양(오른쪽으로 불룩)으로 그리고 기울기·뒤집기는 SlashFx가 한다. 호의 중심은 (20, 128).
## 만든 뒤 --import 하고 .import의 svg/scale을 1.5, mipmaps/generate를 true로 맞춘다 (CLAUDE.md).

const OUT_DIR := "res://assets/sprites/fx/"
const CANVAS: float = 256.0
const CENTER := Vector2(20.0, 128.0)  # SlashFx.ARC_CENTER와 맞춘다
const RADIUS: float = 130.0
const ANGLE_FROM: float = -55.0  # 도. 꼬리(위)
const ANGLE_TO: float = 55.0     # 도. 앞머리(아래)
const WIDTH: float = 36.0        # 정점 프레임의 가장 두꺼운 곳
const OUTLINE: float = 3.0       # 한쪽 외곽선 두께
const HOOK: float = 16.0         # 앞머리가 안쪽으로 말리는 거리
const SAMPLES: int = 22
const COLOR_OUTLINE := "#2b2438"
const COLOR_FILL := "#cfe0f0"    # 옅은 강철빛
const COLOR_CORE := "#ffffff"


func _init() -> void:
	var frames: Array[String] = [_frame_start(), _frame_grow(), _frame_peak(), _frame_erode_1(), _frame_erode_2(),
		_frame_specks(), _frame_thin_line(), _frame_thin_fragments()]
	for i in frames.size():
		var path := OUT_DIR + "slash_%d.svg" % i
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(frames[i])
		file.close()
		print("wrote ", path)
	quit()


## 0: 칼이 막 나가는 조각. 꼬리 자리에 가는 평행선 셋
func _frame_start() -> String:
	var shapes := ""
	for k in 3:
		var a := 0.04 + 0.07 * k
		shapes += _band(a, a + 0.06, 5.0, 0.0, 1.0)
	return _svg(shapes)


## 1: 쉼표처럼 자람. 꼬리부터 절반을 조금 넘게, 앞머리는 말린다
func _frame_grow() -> String:
	return _svg(_crescent(0.0, 0.6, 0.8, true))


## 2: 정점. 꽉 찬 초승달 (이 프레임에서 닿는다)
func _frame_peak() -> String:
	return _svg(_crescent(0.0, 1.0, 1.0, true))


## 3: 침식 1. 몸통이 얇아지고 꼬리가 두 가닥으로 갈라진다
func _frame_erode_1() -> String:
	var shapes := _crescent(0.18, 1.0, 0.55, true)
	shapes += _band(0.0, 0.42, 6.0, 0.35 * WIDTH, 1.0)
	shapes += _band(0.06, 0.3, 4.0, -0.3 * WIDTH, 1.0)
	return _svg(shapes)


## 4: 침식 2. 가는 호와 조각들
func _frame_erode_2() -> String:
	var shapes := _crescent(0.5, 0.97, 0.28, false)
	shapes += _band(0.12, 0.24, 4.0, 0.3 * WIDTH, 1.0)
	shapes += _band(0.3, 0.4, 4.0, -0.25 * WIDTH, 1.0)
	shapes += _band(0.75, 0.85, 3.0, -0.4 * WIDTH, 1.0)
	return _svg(shapes)


## 5: 티끌
func _frame_specks() -> String:
	var shapes := _band(0.62, 0.68, 3.0, 0.1 * WIDTH, 0.0)
	shapes += _band(0.86, 0.9, 3.0, -0.2 * WIDTH, 0.0)
	shapes += _band(0.3, 0.34, 2.5, 0.25 * WIDTH, 0.0)
	return _svg(shapes)


## 6: 난무용 가는 선. 두께 없이 호 전체를 긋는 얇은 날 (흰 심에 외곽선)
func _frame_thin_line() -> String:
	return _svg(_band(0.02, 0.98, 8.0, 0.0, 1.0) + _band(0.1, 0.9, 3.0, 0.0, 0.0).replace(COLOR_FILL, COLOR_CORE))


## 7: 난무용 조각. 가는 선이 두 토막으로 끊어져 사라진다
func _frame_thin_fragments() -> String:
	return _svg(_band(0.14, 0.44, 5.0, 0.15 * WIDTH, 1.0) + _band(0.58, 0.9, 5.0, -0.1 * WIDTH, 1.0))


## 호 위 t(0 꼬리 ~ 1 앞머리)의 점과 바깥쪽 법선
func _point(t: float) -> Vector2:
	var angle := deg_to_rad(lerpf(ANGLE_FROM, ANGLE_TO, t))
	return CENTER + Vector2(cos(angle), sin(angle)) * RADIUS


func _normal(t: float) -> Vector2:
	var angle := deg_to_rad(lerpf(ANGLE_FROM, ANGLE_TO, t))
	return Vector2(cos(angle), sin(angle))


## 초승달: [a, b] 구간, 두께 배율 scale. 앞머리 쪽(u≈0.6)이 가장 두껍고 양 끝은 뾰족하다. hooked면 앞머리가 안으로 말린다
func _crescent(a: float, b: float, scale: float, hooked: bool) -> String:
	var widths := PackedFloat64Array()
	var offsets := PackedFloat64Array()
	for i in SAMPLES + 1:
		var u := float(i) / SAMPLES
		widths.append(WIDTH * scale * pow(sin(PI * pow(u, 1.4)), 0.9))
		var hook := HOOK * scale * pow(maxf(u - 0.82, 0.0) / 0.18, 2.0) if hooked else 0.0
		offsets.append(-hook)
	var shapes := _ribbon(a, b, widths, offsets, OUTLINE * 2.0, COLOR_OUTLINE)
	shapes += _ribbon(a, b, widths, offsets, 0.0, COLOR_FILL)
	var cores := PackedFloat64Array()
	for w: float in widths:
		cores.append(w * 0.5)
	shapes += _ribbon(a, b, cores, offsets, 0.0, COLOR_CORE)
	return shapes


## 고른 굵기의 가닥. offset은 호에서 바깥(+)·안쪽(−)으로 얼마나 비켜 놓을지. outline 배율만큼 외곽선을 두른다
func _band(a: float, b: float, width: float, offset: float, outline: float) -> String:
	var widths := PackedFloat64Array()
	var offsets := PackedFloat64Array()
	for i in SAMPLES + 1:
		var u := float(i) / SAMPLES
		widths.append(width * sin(PI * u) * 1.15)  # 양 끝이 뾰족한 잎 모양
		offsets.append(offset)
	var shapes := ""
	if outline > 0.0:
		shapes += _ribbon(a, b, widths, offsets, OUTLINE * 1.4 * outline, COLOR_OUTLINE)
	shapes += _ribbon(a, b, widths, offsets, 0.0, COLOR_FILL)
	return shapes


## 호를 따라 두께 widths[i]와 법선 방향 오프셋 offsets[i]를 가진 띠를 다각형으로 그린다
func _ribbon(a: float, b: float, widths: PackedFloat64Array, offsets: PackedFloat64Array, grow: float, color: String) -> String:
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in SAMPLES + 1:
		var t := lerpf(a, b, float(i) / SAMPLES)
		var center := _point(t) + _normal(t) * offsets[i]
		var half := widths[i] * 0.5 + grow
		outer.append(center + _normal(t) * half)
		inner.append(center - _normal(t) * half)
	var d := ""
	for i in outer.size():
		d += ("M" if i == 0 else " L") + _xy(outer[i])
	for i in range(inner.size() - 1, -1, -1):
		d += " L" + _xy(inner[i])
	return '  <path d="%s Z" fill="%s"/>\n' % [d, color]


func _xy(p: Vector2) -> String:
	return "%.1f %.1f" % [p.x, p.y]


func _svg(shapes: String) -> String:
	return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" width="%d" height="%d">\n'
		+ '  <!-- 검격 자국 프레임. tools/make_slash_frames.gd가 만든다. 손으로 고치지 말 것 -->\n%s</svg>\n') % [
		int(CANVAS), int(CANVAS), int(CANVAS), int(CANVAS), shapes]
