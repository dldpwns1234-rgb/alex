# 서리 변경 (Frostmarch) — 가칭

> 북부 최전선의 장원에서 몬스터의 습격을 막아내고, 그 사체를 팔아 겨울을 나는 2D 도트 전략 경영 게임

**장르:** 중세 판타지 마을 경영 + 실시간 자동 전투
**플랫폼:** **안드로이드 폰** (세로 고정, 모바일 전용)
**그래픽:** 2D 픽셀아트 — 마을 파노라마 + 건물별 화면
**엔진:** Godot 4.7.1 / GDScript
**현재 상태:** **M3 완료** — 계절 압박 · 겨울 · 승패 판정. 이제 지고 이길 수 있다
(M0: 뼈대 · 배포 / M1: 슬롯과 해금 / M2: 생산과 노동력)

## 구조

```
sim/    순수 로직. Node를 상속하지 않고 실시간을 모른다. 엔진 없이 테스트된다
game/   Godot 노드. sim을 읽어서 그린다. 상태 변경은 커맨드 객체로만
data/   건물·자원·슬롯·밸런싱 상수. 코드에 숫자를 박지 않는다
tests/  헤드리스 테스트 러너 + 밸런스 탐침
tools/  밸런싱 스윕 (ARCHITECTURE §8)
```

자세한 이유는 `docs/ARCHITECTURE.md` §2에 있다.

## 개발

```bash
# 임포트 (최초 1회, 그리고 새 에셋 추가 시)
godot --headless --import

# 테스트 (sim 계층은 엔진 없이 헤드리스로 돈다)
godot --headless --script res://tests/run_tests.gd

# 밸런스 탐침 — 전략 하나를 하루씩 추적한다. "무슨 일이 일어났나"
godot --headless --script res://tests/balance_probe.gd

# 밸런싱 스윕 — 전략 32개를 쓸어보고 생존율을 낸다. "몇 %가 살아남나"
godot --headless --script res://tools/headless_balance.gd

# 웹 익스포트 — build/ 를 Godot이 스캔하지 않도록 .gdignore를 먼저 만든다
mkdir -p build/web && touch build/.gdignore
godot --headless --export-release "Web" build/web/index.html

# 로컬 확인
cd build/web && python3 -m http.server 8000
```

**Android APK**는 SDK와 디버그 키스토어가 필요하다.
`.github/workflows/android.yml`이 전 과정을 담고 있으니 그대로 따라하면 된다.

푸시하면 웹 빌드가 GitHub Pages에 자동 배포된다 (`.github/workflows/web.yml`).
**최초 1회만** 저장소 Settings → Pages → Source를 **GitHub Actions**로 설정해야 한다.

## 화면 구조

```
     홈 화면 (마을 전경)  ──탭──▶  건물 화면 (세부 컨트롤)
     자원 · 날짜 · 경고            인력 배정 · 생산 큐 · 정책
            │
            ▼ 습격 / 원정
     전투 화면 (3열 자동 전투)
```

타일 배치가 아니라 **건물 슬롯 + 메뉴 해금** 방식이다. 폰 화면에서 타일 조작이 불가능하기 때문.

---

## 한 줄 요약

몬스터 부산물은 북부에서만 얻을 수 있고 남부에서 비싸게 팔린다. 그래서 사람들이 이 혹독한 땅에 산다.
플레이어는 그 장원의 영주로서 마을을 키우고, 병력을 육성하고, 겨울마다 찾아오는 대습격을 막아낸다.

## 핵심 순환

```
     몬스터 토벌 ──→ 부산물 ──→ 남부 무역 ──→ 은화
          ↑                                    │
          │                                    ↓
   더 깊은 곳까지 ←── 장비 업그레이드 · 마을 발전 · 병사 임금
```

안전하게 웅크리면 돈이 안 벌리고, 돈이 없으면 병사 임금을 못 주고, 병사가 없으면 겨울에 죽는다.
**소극적 플레이가 자동으로 처벌되는 구조.**

## 문서

| 문서 | 내용 |
|---|---|
| [docs/GDD.md](docs/GDD.md) | 게임 디자인 문서 — 세계관, 시스템, 밸런스 방향 |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | 기술 설계 — 엔진 구조, 시뮬레이션 분리, 데이터 주도 설계 |
| [docs/ROADMAP.md](docs/ROADMAP.md) | 개발 마일스톤 — 무엇을 어떤 순서로 만들 것인가 |

## 레퍼런스

| 게임 | 배울 점 |
|---|---|
| **Manor Lords** | 방향성 레퍼런스. 가구 단위 인구, 계절, 물류 병목 |
| **Rise to Ruins** | 구조 레퍼런스. 2D 픽셀 마을 경영 + 몬스터 웨이브 방어. 거의 같은 장르 |
| **They Are Billions** | 방어 압박과 경제의 결합, 웨이브 리듬 |
| **Against the Storm** | 생산 체인 설계의 교과서 |
| **Banished** | 겨울 압박의 원형 |
