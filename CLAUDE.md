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
    balance/     leveling(용사·레벨업) → companions(동료) → skills(스킬) → memory(회귀·상점) → training(단련) → balance.gd(몬스터·보스·오프라인). 바깥에서는 Balance.만 쓴다
    game.gd      (Game) 전투 흐름: 피해, 처치, 보스 타이머, 파밍과 도전. 상태 변경은 오토로드에서만
    game/state.gd  Game 1부: 시그널, 상태, 저장, 골드, 진행과 등장. game.gd가 상속한다
    party.gd     (Party) 용사와 동료의 레벨, 구매 배수, 구매. Game이 200줄을 넘지 않도록 나눔
    skills.gd    (Skills) 스킬 발동·지속·쿨타임(유닉스 초 기준)과 효과 배율
    prestige.gd  (Prestige) 기억의 결정, 상점 레벨, 역대 기록, 회귀 실행. 회귀해도 남는 것들
    training.gd  (Training) 단련 레벨, 구매, 효과 합산(value·mods). 한 판 안의 패시브
    save.gd      (Save) 저장, 불러오기, 오프라인 보상
    num.gd       (Num) 한국식 숫자 표기
  scenes/
    main.tscn    세로 화면 전체 (상단 바, 전투, 스킬 바, 구매 배수, 탭 패널)
    top_bar.gd, skill_bar.gd, tabs/buy_bar.gd
    battle/      battle(배치, 탭 공격, 연출 타이밍), monster_view(몬스터, 체력바, 피해 숫자), party_view(동료 4명)
    tabs/        hero, party, training, prestige, settings
  assets/fonts/  한글 폰트만 둔다 (고도 기본 폰트에 한글이 없어서 웹에서 네모로 나온다). 이미지, 사운드는 M6부터
  tests/
    run_tests.tscn 헤드리스 테스트 러너. test_case.gd(도우미)를 상속한 스위트를 돌린다
docs/GDD.md      기획서
```

## 아키텍처 원칙

1. 모든 수치와 공식은 Balance에만 둔다. 다른 파일에 숫자를 하드코딩하지 않는다.
2. UI는 Game의 시그널을 받아 표시만 한다. UI에서 상태를 직접 바꾸지 말고 Game의 함수를 호출한다.
3. 스크립트 하나는 200줄 이하로 유지한다. 넘으면 나눈다.
4. 반복되는 UI(동료 줄, 상점 항목)는 코드로 생성한다. .tscn은 최소 구조로만 작성한다.

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
- M6 전까지 그래픽은 ColorRect, 도형, Label로 대신한다
- 기획과 다르게 구현해야 할 이유가 생기면 먼저 물어본다
