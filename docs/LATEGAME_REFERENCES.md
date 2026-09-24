# 후반 콘텐츠 레퍼런스

환생(7.7절) 뒤의 게임을 감으로 짓지 않기 위해 모은 자료. 2026-09-24 기준.
우리 상황: 실제 플레이는 1시간 40분에 환생이 열리고, 그 뒤 삶 하나가 30~37분(회귀 3~4번)이며 삶마다 역대 최고가 +20쯤 오른다 (docs/BALANCE_SIM.md).
운명의 상점은 3종뿐이라 금방 바닥나고, 7분마다 손으로 회귀해야 하며, 예지 Lv 3~4는 환생 직후 첫 몬스터에 한 시간이 걸리는 함정이다.
즉 후반에 필요한 것은 **자동화**, **목적지**, **다양성**, 그리고 실을 쓸 곳이다.

## 1. 자료가 공통으로 말하는 것

1. **위 층은 곱셈이 아니라 규칙을 바꾼다.** Antimatter Dimensions는 층마다(Infinity → Eternity → Reality) 아래 층의 놀이 자체를 바꾼다: 자동 구매, 기술 트리, 무작위 글리프. Clicker Heroes의 초월(Transcendence)은 영혼을 더 주는 게 아니라 원시 보스 보상 배율(Transcendent Power)과 "보스 사이 구간을 줄이는" 아웃사이더를 연다. Cookie Clicker의 천상 업그레이드는 영구 슬롯·오프라인 생산·미니게임을 연다. 우리 환생은 지금 배율(숙명·인연)과 건너뛰기(예지)뿐이다.
2. **자동화는 후반의 보상이다.** AD는 첫 층에서 자동 구매를, Clicker Heroes는 오토클리커·빠른 승천·타임랩스·용병을 층 위로 가져간다. Tap Titans 2는 판(prestige)이 초반 9분에서 후반 4분으로 짧아지므로 자동화가 없으면 노동이 된다. 설계 글도 "자동화 해금은 3분 안에, 첫 프레스티지는 10~15분 안에"를 말한다. 우리는 판이 5~8분인데 회귀·결정 구매·스킬이 전부 손이다.
3. **목적지가 있어야 한다.** Clicker Heroes는 300존의 보스(Woodchip)를 잡아야 초월이 열리고, 환생 용병단은 "300km 밖의 마왕성"이 목표이며, Egg Inc는 예언의 알을 유한하게(트로피 40개) 둔다. "단순한 '100만 도달'도 방향을 준다"(7 idle games). 우리는 500 이후 "더 멀리"만 있다.
4. **후반의 다양성은 스테이지가 아니라 별도 모드에서 온다.** Almost a Hero는 500스테이지에서 Gates of Gog를 여는데 유물을 쓰지 않는 독립 모드다(문마다 효과 조합, 제한 시간, 부적 카드, 저주 문). Tap Titans 2는 레이드와 토너먼트, 한국 키우기는 던전·탑(입장권, 하루 N회)이다. 본편의 곡선을 건드리지 않고 다른 규칙을 얹는 자리다.
5. **도전 = 제한 + 한 번뿐인 고유 보상.** NGU Idle의 도전은 판을 초기화하고 제한(장비 없음, 24시간, 재환생 없음)을 걸며 기능 해금을 준다. Realm Grinder는 진영별 도전에 진영 보너스를 준다. Almost a Hero의 시간 도전 30개는 "한 번만 완료"라 파밍이 안 되고 보석·영웅 해금을 준다. 같은 코드로 새 놀이를 만드는 가장 싼 방법이다.
6. **두 번째 통화는 산술이 다르다.** Clicker Heroes의 고대 영혼은 `5 × log10(누적 영웅 영혼)`, Cookie Clicker는 세제곱근, Realm Grinder는 제곱근이다. 더 멀리 가는 값이 완만해야 "지금 초월할까"가 계산이 된다. 우리 실은 `(역대 최고 − 450) / 10`으로 스테이지에 선형이지만 스테이지가 지수라 사실상 로그다. 다만 500에 5개는 첫 삶 대비 너무 작아서 봇이 삶 2를 504에서 끝냈다.
7. **언제 초기화할지를 게임이 보여 준다.** Clicker Heroes 커뮤니티의 기준은 "시간당 고대 영혼", Tap Titans 2는 "지난 판보다 100스테이지 더". 초기화 버튼에 보상 미리보기가 붙어 있고(우리도 있다), 잘 만든 게임은 "지금 속도"까지 보여 준다.
8. **후반 UI는 감추고, 열리면 알린다.** 진행형 공개(progressive disclosure): 열리지 않은 탭·행은 보이지 않고, "다음 해금: ○○ at ×"만 보인다. AD는 "버튼이 켜지고 비용이 보여 다음 구매가 늘 뻔하게 옳다"로 배운다. 한국 키우기의 빨간 점은 "무료로 얻을 것·지금 살 수 있는 것"에만 찍는다. 도전·던전 같은 별도 모드는 전투 화면 위 아이콘(입장권 수 표시)으로 들어간다.

## 2. 게임별 후반 구조

| 게임 | 층 | 층이 주는 것 | 자동화 | 별도 모드·다양성 | 목적지 |
|---|---|---|---|---|---|
| Clicker Heroes | 승천(영웅 영혼→고대 26종) → 초월(고대 영혼→아웃사이더 5종, TP) | 아웃사이더: 오토클리커 강화, 원시 보스 사이 간격 줄임, 방치 DPS, 원시 보스 영혼, TP 상승. 고대 중 Kumawakamaru(존당 몬스터 −1), Iris(시작 존 +1), Vaagur(쿨타임 −75%)가 우리 바람의 걸음·예지·명상과 같다 | 오토클리커, 빠른 승천(루비), 타임랩스, 용병 퀘스트, 클랜 | 유물, 클랜 불멸자 | 300존 보스 → 초월 해금. 이후 "시간당 고대 영혼"이 떨어지면 초월 |
| Tap Titans 2 | 프레스티지(유물 97종·기술 트리 4갈래) | 유물 등급·세트, 기술 트리(활동/방치/스킬/진행 특화), 장비(판마다 최고 80%에서 5개 드롭), 펫 | 판 4~9분, 자동 프레스티지·자동 스킬은 상점 | 클랜 레이드(부위 카드), 토너먼트(잠재력 기준 조), 심연 토너먼트 | 최고 스테이지(MS)와 토너먼트 순위 |
| Cookie Clicker | 승천(천상 칩→천상 업그레이드 트리) | 영구 업그레이드 슬롯, 오프라인 생산, 골든 쿠키 자동, 계절 스위치, 미니게임(정원·주식·판테온·마도서) | 업그레이드로 자동 골든 쿠키 등 | 미니게임 4종, 드래곤, 설탕 덩어리 | 업적(승천 1000번 "Endless Cycle")과 그림자 업적 |
| Antimatter Dimensions | 차원 → Infinity → Eternity → Reality → 천상체 | 층마다 아래 층을 자동화·재구성. Eternity의 시간 연구 트리, Reality의 글리프(무작위)와 자동화 스크립트 | Infinity에서 자동 구매, Reality에서 스크립트 언어(진입 장벽으로 비판) | 도전 3계열(일반·Infinity·Eternity: 제한 + 보상), 천상체 5명(각자 다른 규칙의 퍼즐 보스) | 천상체를 차례로 꺾는다 |
| NGU Idle | 환생(NUMBER 배율·영구 경험치) | 보스 번호마다 기능 해금(30 시간 기계, 37 혈마법, 58 도전 …) | 기능이 곧 자동화·병렬화 | 도전(기본·24시간·장비 없음·재환생 없음 …) → 기능 해금, 타이탄(시간마다 등장), 무한 탑(ITOPOD) | 다음 보스, 다음 해금 |
| Realm Grinder | 퇴위 → 환생(R) → 승천 2(R99) | 진영·정렬(선/악/중립, R46 드래곤), 연구(R16) | 자동 구매 | 진영별 도전(힌트만 주는 숨은 조건), 유물 | R 번호 |
| Idle Slayer | 승천 트리 → 신성(Divinity) → 울트라 승천 | 미니언·포탈·어두운 신성(득실 토글) | 미니언이 오프라인 진행 | 마을 퀘스트(이야기), 이벤트 | 아스트랄 슬레이어 |
| Almost a Hero | 프레스티지(신화석 유물) | 반지·장신구·유물 | 자동 스킬 | Gates of Gog(500부터, 유물 없이 부적·광산·주점, 문 효과 조합·제한 시간·저주 문), 시간 도전 30개(한 번만) | 문 170개 |
| Egg Inc | 프레스티지(영혼 알 +10%씩) | 예언의 알(영혼 알 배율 +5%, 유한) | 차량·연구 | 계약(협동, 예언의 알), 트로피(알 종류별) | 예언의 알 전부 모으기 |
| 한국 키우기 (로엠·이세계 용병단·드루와 던전·환생 용병단) | 환생(유물·소울 포인트만 남김), 난이도 환생 | 승급·각성·유물·스킨 | 자동 전투·자동 스킬 기본 | 한계의 탑(제한 시간에 10마리 → 무한의 탑 입장권, 하루 3회), 무한의 탑(시즌 초기화·패스), 던전(하루 N회), 보스 | 마왕성(환생 용병단은 "300km 밖") |

한국 키우기의 "제한 시간 안에 10마리"는 우리 스테이지 규칙과 같다. 즉 우리 전투 코드로 탑·던전을 만들 수 있다.

## 3. UI 패턴

- **진행형 공개.** 열리지 않은 것은 감추고 "다음 해금" 한 줄만 보인다. 우리 탭 6개(용사/동료/단련/회귀/업적/설정)는 처음부터 다 보인다. 새 기능은 탭을 늘리기보다 있는 탭 안의 절(환생 절처럼)로 넣고, 열리기 전에는 한 줄 안내만 둔다. 탭이 늘면 폭이 좁아져 손가락 규칙(9절)이 깨진다.
- **빨간 점의 뜻은 하나다.** 키우기 게임의 점은 "무료로 얻을 것·지금 살 수 있는 것". 우리도 그렇게 쓰고 있다(강화·승급·단련·업적). 도전이나 자동화 토글에는 점을 찍지 않는다.
- **초기화 버튼은 보상과 속도를 보인다.** "회귀 (결정 +1.2만)"은 있다. 후반에는 "지금 판 7분 · 지난 판보다 +13"처럼 판 길이와 상승폭을 요약해 두면 "지금 회귀할까"가 계산이 된다. 자동 회귀가 있으면 그 기준(정체 N초)을 같은 자리에서 고른다.
- **자동화는 토글 줄이다.** 보스 자동 재도전처럼 켜고 끄는 한 줄(체크 + 설명). 회귀 탭 맨 위가 자리다. 스킬 자동 사용은 스킬 바 옆의 작은 "자동" 토글이 관례다.
- **메타 성장은 트리로 보인다.** Cookie Clicker 천상 트리, Tap Titans 2 기술 트리, Idle Slayer 승천 트리. 선택지가 갈래일 때 쓴다. 우리 운명의 상점은 목록이면 충분하고, 종류가 8개를 넘으면 두 갈래(자동화 / 힘)로 묶는다.
- **별도 모드의 입구는 전투 화면 위.** 던전·탑·레이드 아이콘이 전투 화면 위쪽 모서리에 있고 입장권 수가 붙는다. 우리는 처치 수(4/10) 자리 아래가 후보다. 모드 안에서는 상단 바가 붉은 알림(DangerPill)으로 "도전: 홀로 서기 · 남은 시간"을 보인다.
- **도전 목록은 업적 줄과 같은 꼴.** 이름 · 제한 · 보상 · 상태(도전 시작 / 진행 중 / 달성). 확인 창은 회귀와 같다("판을 처음부터 시작합니다").
- **엔딩은 화면 하나면 된다.** 마왕을 잡으면 짧은 연출과 "기록" 한 장(걸린 시간, 회귀·환생 횟수), 그리고 "계속하기". 방치형은 여기서 끝나지 않는다.

## 4. 우리 게임에 적용

우리 층은 Clicker Heroes와 같은 꼴이다: 회귀(결정 → 기억의 상점 7종) = 승천(영혼 → 고대), 환생(실 → 운명 3종) = 초월(고대 영혼 → 아웃사이더). 빠진 것은 1절의 넷이다.

| 순서 | 무엇 | 푸는 문제 | 크기 |
|---|---|---|---|
| 1 | **운명의 상점 확장 = 자동화 층** (예지 함정 수정 포함): 자동 회귀(정체 N초면 스스로 회귀, 결정은 정한 계획대로 자동 구매), 유산(예지가 건너뛴 스테이지 한 판 몫의 골드를 들고 시작), 스킬 자동 사용, 동료 기억(회귀 뒤 동료가 지난 판 레벨의 n%로 시작). 아웃사이더가 하는 일이다 | 7분마다 손 회귀, 실 쓸 곳 없음, 예지 함정 | 중. Game·Prestige 시그널로 되고 새 그림 없음 |
| 2 | **마왕성** (목적지): 600부터 마왕성 지역(팔레트·배경·몬스터 2~3종), 1000에 마왕(체력·시간이 다른 특별 보스), 처치하면 엔딩 화면과 무한 모드, 마왕 처치 업적·실 보너스 | "더 멀리"에 끝이 없음 | 중~대. SVG 3~4장, 지역 코드는 zones.gd에 추가 |
| 3 | **도전 판** (한 번뿐인 제한 판): 홀로 서기(동료 없이 120), 침묵의 검(스킬 없이 200), 시간의 채찍(보스 시간 절반으로 300), 빈손(장비 없이 300) … 달성하면 고유 영구 보너스(클릭 +25%, 쿨타임 −10%, 시간의 모래 상한 +5, 강화석 ×2). 환생 1회부터 연다 | 같은 500 벽 반복의 지루함 | 중. 회귀 코드 재사용, 업적 탭에 절 추가 |
| 4 | **시련의 탑** (별도 모드): 층마다 제한 시간 안에 10마리, 하루 입장 N회, 보상은 강화석·실. 한국 키우기의 한계의 탑 | 방치 중 할 일, 강화석 수급 | 대. 전투 화면 위 입구, 모드 전환, 입장권 저장 |

1 → 2 → 3 순서를 권한다. 지금 루프에서 가장 먼저 지루해지는 곳이 손 회귀이고, 그 다음이 "어디까지 가야 하나"다. 4는 1~3 뒤에도 늦지 않다.

## 5. 자료

읽은 페이지만 적는다. 팬덤 위키(clickerheroes·ngu-idle·antimatter-dimensions)와 나무위키는 이 환경에서 열리지 않아 블로그·wiki.gg·공식 글로 대신했다.

| 자료 | 무엇을 배우나 |
|---|---|
| [Clicker Heroes Transcendence Guide](https://blog.clickerheroes.com/clicker-heroes-transcendence-guide-outsiders-souls-explained/), [Best Time to Transcend](https://blog.clickerheroes.com/best-time-to-transcend-when-to-hit-zone-300-and-beyond/) | 초월이 남기는 것과 지우는 것, 아웃사이더 5종, TP 소프트캡 25%, "시간당 고대 영혼" 기준 |
| [Top Ancients Picks](https://blog.clickerheroes.com/top-ancients-picks-in-clicker-heroes-a-comprehensive-guide/), [Ancients 위키](https://clickerheroes.fandom.com/wiki/Ancients) | 고대 26종. Kumawakamaru·Iris·Vaagur가 우리 상점과 대응 |
| [Tap Titans 2 Tips & Tricks](https://www.bluestacks.com/blog/game-guides/tap-titans-2/tt2-tips-tricks-en.html), [v2.0 패치 노트](https://gamehive.com/blog/tap-titans-2-v20-patch-notes-/), [토너먼트 가이드](https://theidlegamer.com/tap-titans-2-tournament-guide/) | 유물 97종, 판마다 장비 드롭, 레이드 카드, 잠재력 기준 토너먼트 조, 판 길이 9→4분 |
| [Cookie Clicker Ascension guide](https://cookieclicker.wiki.gg/wiki/Ascension_guide), [Heavenly Chips](https://cookieclicker.fandom.com/wiki/Heavenly_Chips) | 천상 트리의 갈래, 영구 슬롯, 미니게임 해금, 승천 1000번 업적 |
| [Antimatter Dimensions 리뷰](https://playwanderer.online/game-reviews/antimatter-dimensions), [위키 허브](https://antimatterdimensions.online/wiki/) | 층마다 규칙을 바꾸는 구조, 천상체 = 퍼즐 보스, 스크립트 자동화의 진입 장벽 비판 |
| [NGU Idle Guide 2장](https://sayolove.github.io/ngu-guide/en/chapters/chapter-2/), [Challenges](https://ngu-idle.fandom.com/wiki/Challenges) | 보스 번호별 해금, 도전 = 초기화 + 제한 + 기능 해금 |
| [Realm Grinder Reincarnation](https://realm-grinder.fandom.com/wiki/Reincarnation) | 환생 파워, 진영 도전, R16 연구, R99 승천 2 |
| [Idle Slayer Endgame](https://tap-guides.com/2025/10/08/idle-slayer-endgame-strategies/) | 승천 트리 → 신성 → 울트라 승천, 미니언 오프라인 |
| [Almost a Hero Gates of Gog](https://almostahero.wiki.gg/wiki/Gates_of_Gog_Guide), [Time Challenges](https://almostahero.wiki.gg/wiki/Time_Challenges) | 유물을 안 쓰는 별도 모드, 문 효과 조합·저주 문, 한 번뿐인 시간 도전 30개 |
| [Egg Inc 예언의 알](https://egg-inc.fandom.com/wiki/Earnings_Bonus/Eggs_of_Prophecy) | 유한한 메타 통화(트로피 40개)가 목적지가 된다 |
| [로엠 키우기 한계의 탑](https://on.com2us.com/press/%EC%BB%B4%ED%88%AC%EC%8A%A4%ED%99%80%EB%94%A9%EC%8A%A4-%EB%B0%A9%EC%B9%98%ED%98%95-rpg-%EB%A1%9C%EC%97%A0-%ED%82%A4%EC%9A%B0%EA%B8%B0-%EC%A0%84%EC%82%AC%ED%8E%B8-%EC%8B%A0%EA%B7%9C-%EC%BD%98/), [환생 용병단](https://www.ggemguide.com/mobile_view.htm?uid=5382), [드루와 던전](https://namu.wiki/w/%EB%93%9C%EB%A3%A8%EC%99%80%20%EB%8D%98%EC%A0%84%20-%20%EB%B0%A9%EC%B9%98%ED%98%95%20RPG) | 제한 시간에 10마리 → 입장권, 하루 3회, 유물만 남는 환생, 마왕성 목표, 난이도 환생 |
| [I Built 7 Idle Games in 30 Days](https://dev.to/aguier/i-built-7-idle-games-in-30-days-what-i-learned-about-incremental-design-5d3f), [The Math of Idle Games III](https://www.gamedeveloper.com/design/the-math-of-idle-games-part-iii), [Machinations: idle games](https://machinations.io/articles/idle-games-and-how-to-design-them) | 자동화 3분·프레스티지 10~15분, 목적지 없는 방치형은 첫 세션 뒤 이탈, 프레스티지 통화의 산술, 다음 2~3개만 보이기 |
| [Progressive Disclosure 패턴](https://ui-patterns.com/patterns/ProgressiveDisclosure), [인벤: 블소 UI](https://www.inven.co.kr/webzine/news/?news=87324) | 진행형 공개, 빨간 점 = 무료로 얻을 것 |
