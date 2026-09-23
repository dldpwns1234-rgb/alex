extends TextureRect
## 검격 자국 한 번 (GDD 11절, docs/VFX_REFERENCES.md). 픽셀 슬래시 에셋들이 공유하는 수명을 SVG 프레임 6장의 플립북으로 그린다:
## 얇은 조각 → 쉼표처럼 자람 → 꽉 찬 초승달(접촉) → 꼬리부터 침식 → 가닥 → 티끌. 프레임은 tools/make_slash_frames.gd가 만든다.
## 호의 중심이 용사의 손에 오도록 놓고, 내려베기(＼)는 그대로, 올려베기(／)는 위아래로 뒤집는다 (활은 그대로 몬스터 쪽).
## 연타(난무)는 두께가 없는 가는 선 프레임 두 장만 쓰고, 각도를 ＼／ 두 자리에 고정해 흔들리지 않는 X자 잔상이 된다
## (가는 선 여러 개 = 연속 참격). 치명타는 주황색이고 단발이면 두껍게, 연타 중이면 가는 선 그대로 색과 크기로만 구분한다
## (연타 중 두꺼운 자국은 초당 몇 번씩 덩어리로 보인다).
## 만들어서 add_child()하면 알아서 재생하고 사라진다. 상수는 연출용이다.

const FRAMES: Array[Texture2D] = [
	preload("res://assets/sprites/fx/slash_0.svg"),
	preload("res://assets/sprites/fx/slash_1.svg"),
	preload("res://assets/sprites/fx/slash_2.svg"),
	preload("res://assets/sprites/fx/slash_3.svg"),
	preload("res://assets/sprites/fx/slash_4.svg"),
	preload("res://assets/sprites/fx/slash_5.svg"),
	preload("res://assets/sprites/fx/slash_6.svg"),
	preload("res://assets/sprites/fx/slash_7.svg"),
]
const ARC_CENTER := Vector2(20.0, 128.0) / 256.0  # 프레임 안에서 호의 중심 (크기 비율). 생성기의 CENTER와 맞춘다
const SIZE: float = 250.0
const TILT: float = 15.0          # 도. 세로 호를 기울여 ＼(내려베기)와 ／(올려베기)를 만든다
const TILT_JITTER: float = 5.0
const OFFSET_JITTER: float = 8.0  # px. 같은 자리에 도장 찍히지 않게
## 단발: 프레임 번호와 지속 시간(초). 정점 프레임(2)이 가장 길고 그때 닿는다
const STRIKE_FRAMES: Array[int] = [0, 1, 2, 3, 4, 5]
const STRIKE_TIMES: Array[float] = [0.025, 0.03, 0.06, 0.04, 0.035, 0.02]
## 난무: 가는 선과 그 조각만. 각도는 고정(흔들림 없음), 자리도 고정이라 연타가 같은 X자 위에 겹친다
const FLURRY_FRAMES: Array[int] = [6, 7]
const FLURRY_TIMES: Array[float] = [0.08, 0.06]  # 초당 10회 탭이면 ＼와 ／가 잠깐 겹쳐 X자가 이어진다
const FLURRY_TILT: float = 22.0
const CRIT_SCALE: float = 1.25
const FLURRY_CRIT_SCALE: float = 1.12
const CRIT_COLOR := Color("ffb060")

var _frames: Array[int] = []
var _times: Array[float] = []
var _index: int = 0
var _clock: float = 0.0


func _init(hand: Vector2, downward: bool, crit: bool, flurry: bool) -> void:
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var thin := flurry
	var side := SIZE * ((FLURRY_CRIT_SCALE if thin else CRIT_SCALE) if crit else 1.0)
	size = Vector2(side, side)
	var center := ARC_CENTER * side
	pivot_offset = center  # 손을 축으로 기울인다
	var jitter := Vector2.ZERO if thin else Vector2(randf_range(-OFFSET_JITTER, OFFSET_JITTER), randf_range(-OFFSET_JITTER, OFFSET_JITTER))
	position = hand - center + jitter
	flip_v = not downward  # 호 중심이 세로 가운데라 뒤집어도 손 자리는 그대로
	var tilt := (FLURRY_TILT if thin else TILT) * (-1.0 if downward else 1.0)  # ＼ 는 반시계, ／ 는 시계 방향
	rotation = deg_to_rad(tilt + (0.0 if thin else randf_range(-TILT_JITTER, TILT_JITTER)))
	modulate = CRIT_COLOR if crit else Color.WHITE
	_frames = FLURRY_FRAMES if thin else STRIKE_FRAMES
	_times = FLURRY_TIMES if thin else STRIKE_TIMES
	texture = FRAMES[_frames[0]]


func _process(delta: float) -> void:
	_clock += delta
	while _clock >= _times[_index]:
		_clock -= _times[_index]
		_index += 1
		if _index >= _frames.size():
			queue_free()
			return
		texture = FRAMES[_frames[_index]]
