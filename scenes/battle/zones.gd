extends RefCounted
## 스테이지에 따른 몬스터 종류, 바퀴마다 바뀌는 색조, 배경 팔레트 (GDD 11절: 몬스터는 색만 바꿔서 재활용).
## 10 스테이지마다 몬스터가 바뀌고, 6종을 다 돌면 같은 몬스터가 다른 색으로 다시 나온다.
## 연출 규칙이며 게임 수치가 아니다. MonsterView·Backdrop·Battle이 정적 함수로 읽는다.

const STAGES_PER_ZONE: int = 10

const MONSTER_TEXTURES: Array[Texture2D] = [
	preload("res://assets/sprites/monsters/slime.svg"),
	preload("res://assets/sprites/monsters/bat.svg"),
	preload("res://assets/sprites/monsters/goblin.svg"),
	preload("res://assets/sprites/monsters/skeleton.svg"),
	preload("res://assets/sprites/monsters/ghost.svg"),
	preload("res://assets/sprites/monsters/golem.svg"),
]
const MONSTER_NAMES: Array[String] = ["슬라임", "박쥐", "고블린", "해골", "유령", "골렘"]
## 그림 안에서 머리 꼭대기의 높이 (0 = 위, 1 = 아래). 보스 왕관을 얹는 자리
const HEAD_TOPS: Array[float] = [0.33, 0.23, 0.2, 0.16, 0.22, 0.18]
const BOSS_SUFFIX: String = " 두목"

## 바퀴(6종을 한 번 돈 횟수)마다 몬스터 그림에 곱하는 색. 첫 바퀴는 원래 색
const LAP_TINTS: Array[Color] = [
	Color.WHITE,
	Color(1.0, 0.8, 0.7),
	Color(0.75, 0.85, 1.0),
	Color(1.0, 0.95, 0.55),
	Color(0.85, 0.72, 1.0),
	Color(0.7, 1.0, 0.8),
]

## 지역별 배경 색: [하늘 위, 하늘 아래, 먼 언덕, 땅]
const PALETTES: Array[Array] = [
	[Color("7ec8ff"), Color("d9f1ff"), Color("6fb26a"), Color("79c46e")],  # 초원
	[Color("2f2b4a"), Color("4a4470"), Color("3a3560"), Color("4b4670")],  # 동굴
	[Color("6fb8e8"), Color("cfe9f7"), Color("3f8a4f"), Color("5aa85f")],  # 숲
	[Color("5a5f7a"), Color("a3a8c0"), Color("5c6280"), Color("6b7290")],  # 묘지
	[Color("1f2a4a"), Color("3d4f7a"), Color("2f4a5c"), Color("3b5a6a")],  # 늪
	[Color("f0b27a"), Color("ffe0b3"), Color("8a6b5a"), Color("a07a5a")],  # 산
]


static func zone(stage: int) -> int:
	@warning_ignore("integer_division")
	return ((stage - 1) / STAGES_PER_ZONE) % MONSTER_NAMES.size()


static func lap(stage: int) -> int:
	@warning_ignore("integer_division")
	return (stage - 1) / (STAGES_PER_ZONE * MONSTER_NAMES.size())


static func monster_texture(stage: int) -> Texture2D:
	return MONSTER_TEXTURES[zone(stage)]


static func monster_name(stage: int, boss: bool) -> String:
	return MONSTER_NAMES[zone(stage)] + (BOSS_SUFFIX if boss else "")


static func head_top(stage: int) -> float:
	return HEAD_TOPS[zone(stage)]


static func monster_tint(stage: int) -> Color:
	return LAP_TINTS[lap(stage) % LAP_TINTS.size()]


static func palette(stage: int) -> Array:
	return PALETTES[zone(stage)]
