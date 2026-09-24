extends RefCounted
## 스테이지에 따른 몬스터 종류, 바퀴마다 바뀌는 색조, 배경 팔레트 (GDD 11절: 몬스터는 색만 바꿔서 재활용).
## 10 스테이지마다 몬스터가 바뀌고, 6종을 다 돌면 같은 몬스터가 다른 색으로 다시 나온다.
## 마왕성(Balance.CASTLE_STAGE부터)은 몬스터 3종과 어두운 팔레트를 따로 쓰고, 마왕 스테이지에는 마왕이 나온다 (GDD 7.8절).
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

## 지역별 배경 색: [하늘 위, 하늘 아래, 먼 언덕, 땅, 해]
const SUN := Color(1.0, 0.96, 0.8, 0.9)
const PALETTES: Array[Array] = [
	[Color("7ec8ff"), Color("d9f1ff"), Color("6fb26a"), Color("79c46e"), SUN],  # 초원
	[Color("2f2b4a"), Color("4a4470"), Color("3a3560"), Color("4b4670"), SUN],  # 동굴
	[Color("6fb8e8"), Color("cfe9f7"), Color("3f8a4f"), Color("5aa85f"), SUN],  # 숲
	[Color("5a5f7a"), Color("a3a8c0"), Color("5c6280"), Color("6b7290"), SUN],  # 묘지
	[Color("1f2a4a"), Color("3d4f7a"), Color("2f4a5c"), Color("3b5a6a"), SUN],  # 늪
	[Color("f0b27a"), Color("ffe0b3"), Color("8a6b5a"), Color("a07a5a"), SUN],  # 산
]

# 마왕성: 검붉은 하늘, 붉은 달, 검은 성벽(Backdrop이 그린다), 검은 땅. 몬스터 3종이 10 스테이지마다 바뀌고 셋을 돌면 색조로 재활용
const CASTLE_TEXTURES: Array[Texture2D] = [
	preload("res://assets/sprites/monsters/imp.svg"),
	preload("res://assets/sprites/monsters/gargoyle.svg"),
	preload("res://assets/sprites/monsters/dark_knight.svg"),
]
const CASTLE_NAMES: Array[String] = ["임프", "가고일", "흑기사"]
const CASTLE_HEAD_TOPS: Array[float] = [0.2, 0.16, 0.1]
const CASTLE_PALETTE: Array = [Color("1a0b1e"), Color("5a1030"), Color("120810"), Color("261426"), Color("e0403a")]
const DEMON_KING_TEXTURE: Texture2D = preload("res://assets/sprites/monsters/demon_king.svg")
# 시련의 탑: 잿빛 돌탑. 몬스터는 층에 해당하는 스테이지의 것이 나온다
const TOWER_PALETTE: Array = [Color("2a2a3a"), Color("55566a"), Color("1e1e2a"), Color("3a3a4a"), Color("d0d4e0")]
const DEMON_KING_NAME: String = "마왕"


static func zone(stage: int) -> int:
	@warning_ignore("integer_division")
	return ((stage - 1) / STAGES_PER_ZONE) % MONSTER_NAMES.size()


static func lap(stage: int) -> int:
	@warning_ignore("integer_division")
	return (stage - 1) / (STAGES_PER_ZONE * MONSTER_NAMES.size())


static func is_castle(stage: int) -> bool:
	return Balance.is_castle_stage(stage)


static func is_demon_king(stage: int) -> bool:
	return Balance.is_demon_king_stage(stage)


static func castle_zone(stage: int) -> int:
	@warning_ignore("integer_division")
	return ((stage - Balance.CASTLE_STAGE) / STAGES_PER_ZONE) % CASTLE_NAMES.size()


static func castle_lap(stage: int) -> int:
	@warning_ignore("integer_division")
	return (stage - Balance.CASTLE_STAGE) / (STAGES_PER_ZONE * CASTLE_NAMES.size())


static func monster_texture(stage: int) -> Texture2D:
	if is_demon_king(stage):
		return DEMON_KING_TEXTURE
	return CASTLE_TEXTURES[castle_zone(stage)] if is_castle(stage) else MONSTER_TEXTURES[zone(stage)]


## 마왕은 "두목"을 붙이지 않는다
static func monster_name(stage: int, boss: bool) -> String:
	if is_demon_king(stage):
		return DEMON_KING_NAME
	var base: String = CASTLE_NAMES[castle_zone(stage)] if is_castle(stage) else MONSTER_NAMES[zone(stage)]
	return base + (BOSS_SUFFIX if boss else "")


static func head_top(stage: int) -> float:
	return CASTLE_HEAD_TOPS[castle_zone(stage)] if is_castle(stage) else HEAD_TOPS[zone(stage)]


## 마왕은 원래 색 그대로
static func monster_tint(stage: int) -> Color:
	if is_demon_king(stage):
		return Color.WHITE
	var laps := castle_lap(stage) if is_castle(stage) else lap(stage)
	return LAP_TINTS[laps % LAP_TINTS.size()]


static func palette(stage: int) -> Array:
	return CASTLE_PALETTE if is_castle(stage) else PALETTES[zone(stage)]
