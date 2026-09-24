# 회귀 용사 키우기 (가제)

고도 엔진으로 만드는 웹용 판타지 인크리멘탈 게임. 클릭 공격과 동료 파티의 자동 전투가 동시에 진행된다.
전체 기획서: @docs/GDD.md

## 기술 스택

- Godot 4.7 일반(표준) 빌드. .NET 빌드 사용 금지 (고도 4의 C#은 웹 내보내기 불가)
- 언어: GDScript만 사용. 변수, 인자, 반환값에 타입을 지정한다 (typed GDScript)
- 렌더러: Compatibility (웹 전용)
- 웹 내보내기: 단일 스레드 (Thread Support 끔)
- 기준 해상도: 720×1280 세로. stretch mode = canvas_items, aspect = keep_width

## 고도 3 문법 금지

AI가 가장 자주 하는 실수다. 왼쪽 문법은 절대 쓰지 않는다.

| 고도 3 (금지) | 고도 4 (사용) |
|---|---|
| `yield(...)` | `await ...` |
| `onready var`, `export var`, `tool` | `@onready var`, `@export var`, `@tool` |
| `connect("sig", self, "fn")` | `sig.connect(fn)` |
| `emit_signal("sig", a)` | `sig.emit(a)` |
| `instance()` | `instantiate()` |
| `$Tween.interpolate_property()` | `create_tween().tween_property()` |
| `File`, `JSON.print()`, `parse_json()` | `FileAccess`, `JSON.stringify()`, `JSON.parse_string()` |
| `OS.get_unix_time()` | `Time.get_unix_time_from_system()` |
| `rand_range()`, `stepify()`, `deg2rad()` | `randf_range()`, `snapped()`, `deg_to_rad()` |
| `.empty()` | `.is_empty()` |
| `setget` | 프로퍼티 `set`/`get` 문법 |
| `PoolStringArray` 등 | `PackedStringArray` 등 |

## 폴더 구조

```
res://
  autoload/
    balance.gd   (Balance) 모든 수치와 공식. 200줄 규칙 때문에 balance/ 아래 부분 스크립트를 상속으로 이어 붙인다
    balance/     leveling(용사·레벨업) → companions(동료) → skills(스킬) → memory(회귀·상점) → training(단련) → achievements(업적) → equipment(장비) → rebirth(환생·운명의 상점·자동화) → balance.gd(몬스터·보스·오프라인·유산). 바깥에서는 Balance.만 쓴다. 앞 스크립트는 뒤 스크립트의 것을 못 본다
    game.gd      (Game) 전투 흐름: 피해, 처치, 보스 타이머, 파밍과 도전. 상태 변경은 오토로드에서만
    game/state.gd  Game 1부: 시그널, 상태, 저장, 골드, 진행과 등장. game.gd가 상속한다
    party.gd     (Party) 용사와 동료의 레벨, 구매 배수, 구매. Game이 200줄을 넘지 않도록 나눔
    skills.gd    (Skills) 스킬 발동·지속·쿨타임(유닉스 초 기준)과 효과 배율
    prestige.gd  (Prestige) 기억의 결정, 상점 레벨, 역대 기록, 회귀 실행. 회귀해도 남는 것들
    rebirth.gd   (Rebirth) 환생: 운명의 실, 운명의 상점(숙명·인연·예지), 환생 실행. 회귀 뒤 시작 스테이지도 여기서 정한다
    training.gd  (Training) 단련 레벨, 구매, 효과 합산(value·mods). 한 판 안의 패시브
    promotions.gd (Promotions) 동료 승급 단계, 구매, DPS 배율. 한 판 안의 강화. Party가 동료 공식에 배율을 넘긴다
    achievements.gd (Achievements) 누적 통계와 업적 달성, 영구 보너스 배율. 회귀해도 남는다. 통계는 Game·Party·Prestige·Skills의 시그널로 모은다
    equipment.gd (Equipment) 장비 3칸, 보스 드롭(Game 시그널), 자동 장착·분해, 강화석과 강화, 효과 배율. 회귀해도 남는다
    automation.gd (Automation) 자동 회귀(정체 시계), 결정 자동 구매, 스킬 자동 사용. 운명의 상점에서 해금하면 동작하고 토글은 저장된다
    save.gd      (Save) 저장, 불러오기, 오프라인 보상
    num.gd       (Num) 한국식 숫자 표기
  scenes/
    main.tscn    세로 화면 전체 (상단 바, 전투, 스킬 바, 구매 배수, 탭 내비게이션, 패널)
    main.gd      내비게이션이 고른 패널만 보이고 용사(강화)·동료(승급)·단련·업적 탭 점을 갱신하며, 업적·승급·장비 알림(toast.gd)을 띄운다
    top_bar.gd, skill_bar.gd(쿨타임·지속 시간 막), nav_bar.gd(탭 버튼 6개와 점), toast.gd(잠깐 뜨는 알림), tabs/buy_bar.gd
    battle/      battle(배치, 탭 공격, 연출 타이밍), monster_view(몬스터, 체력바, 피해 숫자), party_view(용사와 동료 4명), boss_controls(보스 도전·자동 재도전)
                 actor(인물 하나의 그림과 Tween 연출), backdrop(지역별 배경), zones(스테이지→몬스터 종류·색조·팔레트)
                 stage(흔들리는 무대, 자국·불꽃을 띄우고 개수 상한), slash_fx(검격 자국 플립북, 프레임 6장), impact_fx(접촉 불꽃과 처치 고리)
    tabs/        hero(레벨업과 장비 3칸), party, training, prestige(+automation_panel 자동화, +rebirth_panel 환생), achievements, settings. 스크롤 목록은 tap_scroll(버튼 위에서도 끌어 스크롤, 탭 판정)을 쓴다
  assets/fonts/  한글 폰트만 둔다 (고도 기본 폰트에 한글이 없어서 웹에서 네모로 나온다)
  assets/sprites/ 손으로 짠 SVG 캐릭터(용사, 동료 4), monsters/(6종), fx/(왕관, 파편, 검격 프레임 slash_0~5), ui/(아이콘). .import 파일도 커밋한다 (svg/scale 1.5, 밉맵)
  tools/make_slash_frames.gd  검격 프레임 생성기. slash_N.svg는 손으로 고치지 않는다: 상수를 고치고 다시 만든다 (`--script tools/make_slash_frames.gd`)
  assets/shaders/ flash.gdshader (피격 번쩍임)
  assets/ui/theme.tres 전체 테마. 손으로 고치지 않는다: tools/make_theme.gd의 상수를 고치고 다시 만든다
  tools/make_theme.gd  테마 생성기. `<GODOT 경로> --headless --path . --script tools/make_theme.gd`
  tools/balance_sim.gd 밸런스 시뮬레이션 (구매 정책은 sim_purchases.gd, 상속). `-- --goal=500 --ratio=2 --skills=1 …` 정책 인자로 목표 도달 시간을 잰다. 결과는 docs/BALANCE_SIM.md
  tools/route_search.py 정책 조합을 바꿔 가며 시뮬레이션을 나란히 돌려 가장 빠른 루트를 찾는다 (개발 도구라 파이썬)
  tests/
    run_tests.tscn 헤드리스 테스트 러너. test_case.gd(도우미)를 상속한 스위트를 돌린다
docs/GDD.md      기획서
docs/VFX_REFERENCES.md  검격 연출 레퍼런스와 그로부터 뽑은 형태·타격 원칙. 연출을 고치기 전에 읽는다
docs/LATEGAME_REFERENCES.md  다른 게임의 후반 구조(층·자동화·별도 모드·도전)와 UI 패턴, 우리 게임에 적용할 순서. 환생 뒤 콘텐츠를 짓기 전에 읽는다
```

## 아키텍처 원칙

1. 모든 수치와 공식은 Balance에만 둔다. 다른 파일에 숫자를 하드코딩하지 않는다.
2. UI는 Game의 시그널을 받아 표시만 한다. UI에서 상태를 직접 바꾸지 말고 Game의 함수를 호출한다.
3. 스크립트 하나는 200줄 이하로 유지한다. 넘으면 나눈다.
4. 반복되는 UI(동료 줄, 상점 항목)는 코드로 생성한다. .tscn은 최소 구조로만 작성한다.
5. 색과 모양은 테마(tools/make_theme.gd)에 둔다. 컨트롤마다 스타일을 덮어쓰지 말고 타입 변형(`theme_type_variation`: AccentButton, NavButton, SkillReady, SkillActive, TopBar, Pill, DangerPill)을 쓴다. 연출용 색(피해 숫자, 체력바)은 예외다.
6. 글 길이가 바뀌어도 배치가 움직이지 않게 한다. 목록의 줄 높이는 고정하고, 숫자가 든 라벨은 한 줄에 말줄임하거나 폭을 정하고, 요약 글은 접힐 줄 수만큼 자리를 미리 잡는다. 탭 하나의 내용은 패널 최소 높이(440px)를 넘지 않는다 (넘으면 전투 화면이 줄어 화면 전체가 흔들린다).

## 숫자 규칙

- 골드, 체력, 피해, 비용, 기억의 결정은 전부 float. int 금지 (64비트 int는 약 9.2e18에서 넘친다)
- 큰 수에 `int()`, `floori()` 변환 금지. `floor()`는 float을 반환하므로 그대로 쓴다
- 화면에 숫자를 표시할 때는 항상 `Num.format()`을 쓴다. `str()`로 직접 표시하지 않는다

## 시간 규칙

- `_process`의 delta는 `minf(delta, 0.25)`로 상한을 둔다
- 매 프레임 `Time.get_unix_time_from_system()`을 기록한다. 직전 프레임과 10초 이상 차이 나면 그 시간은 게임 진행 대신 오프라인 보상으로 처리한다 (웹은 탭이 숨겨지면 게임 루프가 멈춘다)
- 스킬의 지속 시간과 쿨타임은 실제 시간(유닉스 시간) 기준으로 계산한다

## 저장 규칙

- `user://save.json`에 JSON으로 저장한다. `save_version` 필드 필수 (현재 1)
- 30초마다, 그리고 창이나 탭의 포커스를 잃을 때 저장한다
  - 웹에서는 창 blur가 `NOTIFICATION_APPLICATION_FOCUS_OUT`으로 오지 않는다 (M3 브라우저 검사). 그래서 Save가 `JavaScriptBridge`로 `visibilitychange`와 `pagehide`를 직접 받아 저장한다. 데스크톱은 포커스 아웃 알림을 그대로 쓴다
- 내보내기 문자열은 저장 JSON을 `Marshalls.utf8_to_base64()`로 인코딩한 것이다
- 새 필드를 추가하면 불러오기에서 기본값을 채워서 옛 저장 데이터가 깨지지 않게 한다

## 작업 방식

- GDD의 마일스톤 하나씩, 그 안에서도 기능 하나씩 구현한다
- 기능 하나를 끝내면 바뀐 파일 요약과 에디터에서 확인하는 방법을 알려주고 git 커밋한다
- 코드를 고친 뒤에는 `<GODOT 경로> --headless --path . --quit`을 실행해 SCRIPT ERROR가 없는지 확인한다
  - GODOT 경로: `godot` (PATH에 없으면 `.github/workflows/web.yml`의 설치 단계대로 4.7.1을 받는다)
  - 처음 한 번, 그리고 에셋을 추가했을 때는 먼저 `<GODOT 경로> --headless --import`를 실행한다
- 공식이나 숫자 표기를 고쳤으면 `<GODOT 경로> --headless --path . res://tests/run_tests.tscn`로 테스트도 돌린다
- 그래픽은 SVG를 직접 그린다 (GDD 11절). 새 SVG를 넣으면 `--import` 뒤 생긴 .import의 `svg/scale`을 1.5, `mipmaps/generate`를 true로 맞춘다
  - 미리 보려면 `Image.load_svg_from_string()`으로 PNG를 뽑는다. 브라우저 대신 고도(ThorVG)가 그리는 결과가 기준이다
- 기획과 다르게 구현해야 할 이유가 생기면 먼저 물어본다
