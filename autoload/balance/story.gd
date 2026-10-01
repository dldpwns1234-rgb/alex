extends "res://autoload/balance/challenges.gd"
## Balance 10부: 기억 조각 (GDD 7.11절, 문안은 docs/STORY.md). 회귀·환생·마왕에 붙는 독백 12개. 게임 수치에는 영향이 없다.
## 업적 통계(Stat)가 목표에 닿고 앞 조각이 열려 있으면 열린다. 순서가 곧 이야기 순서라 앞 조각을 건너뛰지 않는다

const FRAGMENTS: Array[Dictionary] = [
	{"stat": Stat.PRESTIGES, "goal": 1.0, "title": "다시, 처음",
		"text": "분명히 쓰러졌다. 그런데 눈을 뜨니 마을 어귀다. 손에는 녹슨 검이 들려 있고, 하늘은 그날 아침처럼 맑다. 꿈이었다고 하기에는 상처가 아직 욱신거린다."},
	# 첫 판 최고가 150 안팎이라 200이어야 두 번째 판에서 열린다 (첫 회귀와 한꺼번에 뜨지 않게)
	{"stat": Stat.STAGE, "goal": 200.0, "title": "익숙한 관문",
		"text": "이 관문을 넘는 것은 처음이 아니다. 몬스터가 어디서 튀어나올지, 바람이 언제 바뀔지 몸이 먼저 안다. 기억은 검보다 날카롭다."},
	{"stat": Stat.PRESTIGES, "goal": 3.0, "title": "낯선 인사",
		"text": "전사가 나를 보고 \"처음 뵙겠습니다\" 하고 웃었다. 지난번에 내 등을 지켜 주다 쓰러진 사람이다. 나는 대답 대신 고개만 숙였다."},
	{"stat": Stat.STAGE, "goal": 300.0, "title": "심연의 문턱",
		"text": "여기서부터는 공기가 무겁다. 몇 번을 돌아와도 이 문턱에서 발이 굳는다. 두려움도 함께 회귀하는 모양이다."},
	{"stat": Stat.PRESTIGES, "goal": 10.0, "title": "결정의 무게",
		"text": "손바닥 위의 결정이 따뜻하다. 돌아올 때마다 하나씩 늘어나는 이것은, 아마 내가 잃어버린 시간이 굳은 것이리라."},
	{"stat": Stat.STAGE, "goal": 500.0, "title": "전설의 끝자락",
		"text": "노래로만 듣던 자리에 섰다. 그런데 이상하다. 돌기둥에 새겨진 검 자국이, 내 검과 똑같은 각도로 기울어 있다."},
	{"stat": Stat.REBIRTHS, "goal": 1.0, "title": "실을 쥔 손",
		"text": "꿈속에서 여신이 실 한 가닥을 건넸다. \"기억을 내려놓으면, 더 멀리 갈 수 있습니다.\" 결정이 흩어지는 소리가 유리처럼 맑았다."},
	{"stat": Stat.PRESTIGES, "goal": 25.0, "title": "닳아 가는 것",
		"text": "동료들의 얼굴은 선명한데 이름이 자꾸 늦게 떠오른다. 회귀는 몸이 아니라 마음을 깎는다. 오늘은 마법사의 이름을 세 번 되뇌었다."},
	{"stat": Stat.STAGE, "goal": 600.0, "title": "마왕성",
		"text": "검붉은 하늘 아래 성벽이 서 있다. 성문 앞의 발자국은 오래되었는데, 크기가 내 신발과 꼭 같다. 누군가 나보다 먼저 이 길을 수없이 걸었다."},
	{"stat": Stat.DEMON_KING, "goal": 1.0, "title": "왕좌의 얼굴",
		"text": "투구가 벗겨지자 늙고 지친 얼굴이 드러났다. 그가 웃었다. \"또 왔구나, 나야.\" 그는 회귀를 너무 많이 한 나였다. 무너진 뒤에도 끝내 멈추지 못한."},
	{"stat": Stat.REBIRTHS, "goal": 5.0, "title": "여신의 계약",
		"text": "실의 끝을 따라가니 여신이 울고 있었다. 마왕을 만든 것도, 나를 돌려보낸 것도 같은 계약이었다. 고리를 끊으려면 기억을 지닌 채 끝까지 가야 한다."},
	{"stat": Stat.FINAL, "goal": 1.0, "title": "고리의 끝",
		"text": "마지막 마왕은 아무 말 없이 검을 내려놓았다. 나도 검을 내려놓았다. 아침 햇살이 왕좌의 먼지를 비췄다. 이번에는, 내일이 온다."},
]


func fragment_stat(index: int) -> int:
	return FRAGMENTS[index]["stat"]


func fragment_goal(index: int) -> float:
	return FRAGMENTS[index]["goal"]


func fragment_title(index: int) -> String:
	return FRAGMENTS[index]["title"]


func fragment_text(index: int) -> String:
	return FRAGMENTS[index]["text"]


## 잠긴 조각에 보이는 힌트: "스테이지 300 도달" (업적 목표 글과 같은 꼴)
func fragment_hint(index: int) -> String:
	return STAT_GOAL_FORMATS[fragment_stat(index)] % Num.format(fragment_goal(index))
