# 회귀 용사 키우기 (가제)

> 용사가 동료 파티와 함께 마왕군을 뚫고 나아간다. 벽에 막히면 과거로 회귀해서 기억을 가져와 더 강해진다

**장르:** 클리커 + 자동 전투 인크리멘탈 (Clicker Heroes식 동시 전투)
**플랫폼:** 웹 브라우저, 세로 화면 (PC와 모바일)
**엔진:** Godot 4.7.1 / GDScript (typed)
**현재 상태:** **M6 그래픽** — 벡터 SD 캐릭터와 몬스터 6종, Tween 연출, 지역별 배경, 전체 UI 테마. 효과음은 아직

기획서는 [docs/GDD.md](docs/GDD.md), 개발 규칙은 [CLAUDE.md](CLAUDE.md)에 있다.

## 구조

```
autoload/   Balance(수치·공식, balance/ 부분 스크립트를 상속으로 연결) · Num(한국식 숫자 표기) · Game(골드·스테이지·몬스터·보스) · Party(용사·동료 레벨과 구매) · Skills(스킬) · Training(단련) · Prestige(회귀·기억의 상점) · Save(저장·불러오기·오프라인 보상)
scenes/     main.tscn 세로 화면 전체 · top_bar · battle/ 전투 화면 · skill_bar · nav_bar 탭 버튼 · tabs/ 탭 패널과 구매 배수
tests/      헤드리스 테스트 러너와 스위트 (공식, 진행, 보스, 저장, 오프라인, 스킬, 회귀, 단련)
tools/      밸런스 시뮬레이션, 테마 생성기 (익스포트에서 제외)
assets/     한글 폰트 · sprites/ 손으로 짠 SVG 캐릭터·몬스터·효과·아이콘 · shaders/ 피격 번쩍임 · ui/ 테마
docs/       기획서
```

## 개발

```bash
# 임포트 (최초 1회, 그리고 새 에셋 추가 시)
godot --headless --import

# 스크립트 오류 검사 (메인 씬을 한 프레임 돌린다)
godot --headless --path . --quit

# 테스트 (공식, 숫자 표기, 전투 진행)
godot --headless --path . res://tests/run_tests.tscn

# 밸런스 시뮬레이션 — 실제 게임 코드로 회귀 12번까지 돌려 GDD 13절 목표와 비교한다 (결과: docs/BALANCE_SIM.md)
godot --headless --path . res://tools/balance_sim.tscn

# 웹 익스포트 — build/ 를 Godot이 스캔하지 않도록 .gdignore를 먼저 만든다
mkdir -p build/web && touch build/.gdignore
godot --headless --export-release "Web" build/web/index.html

# 로컬 확인
cd build/web && python3 -m http.server 8000
```

푸시하면 웹 빌드가 GitHub Pages에 자동 배포된다 (`.github/workflows/web.yml`).
**최초 1회만** 저장소 Settings → Pages → Source를 **GitHub Actions**로 설정해야 한다.

## 마일스톤

| 단계 | 내용 | 상태 |
|---|---|---|
| M1 | 전투 기본: 탭 공격, 체력바, 골드, 스테이지, 용사 레벨업 | 완료 |
| M2 | 동료와 보스: 동료 4명, 구매 배수 ×1/×10/최대, 보스 타이머와 파밍 모드 | 완료 |
| M3 | 저장과 오프라인: 자동 저장(30초, 탭 숨김), 내보내기·가져오기·초기화, 오프라인 보상 팝업 | 완료 |
| M4 | 스킬 3종: 해금, 30초 지속, 5분 쿨타임(유닉스 시간 기준), 저장 | 완료 |
| M5 | 회귀: 스테이지 100부터, 결정 획득과 확인 창, 초기화·유지. 기억의 상점 6종 | 완료 |
| M5.5 | 단련: 용사·동료별 5종씩 25종, 레벨 10/25/50/75/100 해금, 5~10레벨 반복 강화, 단련 탭 | 완료 |
| M6 | 그래픽: SVG SD 캐릭터 10종과 보스 왕관, 대기·공격·피격·처치 연출, 지역별 배경과 색조, UI 테마와 탭 내비게이션 | 완료 (효과음 제외) |
