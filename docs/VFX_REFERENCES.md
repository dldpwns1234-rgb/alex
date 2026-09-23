# 검격 연출 레퍼런스

용사의 탭 공격 연출(검격 자국, 타격 반응)을 감으로 고치지 않기 위해 모은 자료. 2026-09-23 기준.
목표는 두 가지다: **검으로 읽힐 것**(마법·에너지가 아니라), **연타(초당 10회)에도 버틸 것**.
우리 조건: SD(2등신) 캐릭터, 굵은 어두운 외곽선의 벡터 그림체, 옆에서 보는 2D, 용사는 왼쪽·몬스터는 오른쪽.

## 1. 자료가 공통으로 말하는 것

여러 출처가 독립적으로 같은 말을 한다. 이것을 기준으로 삼는다.

1. **초승달, 그리고 깃발.** 자국은 하나의 매끈한 초승달 곡선이다. 앞머리(칼이 지금 있는 쪽)가 두껍고 꼬리로 갈수록 가늘어져 바늘처럼 끝난다. 이 비대칭이 "시간이 흘렀다, 빠르다"를 말한다. 두께가 고르면 고리처럼 보인다.
2. **축은 어깨(손)다.** 칼은 어깨·팔꿈치를 축으로 호를 그리며 휘둘러지므로 자국의 곡률은 그 축을 따른다. 그래서 왼쪽에 선 용사의 자국은 늘 몬스터 쪽으로 불룩하다. 뒤집으면 반대편에서 벤 것이 된다.
3. **생김새는 세 단계다.** 모든 슬래시 에셋이 같은 수명을 산다. ① 얇은 조각으로 나타나 ② 한두 프레임 안에 꽉 찬 초승달이 되며 심이 가장 밝고(이때 닿는다) ③ 꼬리부터 깎여 나가 가는 가닥 몇 개로 흩어지고 사라진다. 전체가 균일하게 투명해지는 것은 유령·마법의 문법이다. **꼬리부터 침식되는 것이 검의 문법이다.**
4. **끝은 갈라지고 휘어진다.** 만화·셀 스타일 자국은 꼬리가 두세 가닥의 붓 자국으로 갈라지고, 앞머리는 살짝 안으로 말린다(쉼표 모양). 이 붓 자국이 속도감을 준다. 둥근 끝(round cap)은 쓰지 않는다.
5. **색은 강철이다.** 흰 심 + 옅은 회청색 중간 톤 + 어두운 외곽선의 2~3톤. 노랑·주황·발광(glow)은 불·마법·에너지로 읽힌다. 픽셀 에셋들도 흰색과 연한 파랑을 쓴다.
6. **얇으면 빠르고 날카롭다, 두꺼우면 무겁다.** 가는 선 여러 개는 연속 참격(난무), 두껍고 살짝 일그러진 한 줄은 강타. 같은 자국을 크기만 바꿔 쓰지 말고 이 문법으로 단발과 연타를 구분한다.
7. **베인 자국은 몬스터 위에.** 만화의 흰 검격은 "칼날에 반사된 빛 + 갈라지는 공기"다. 대상에는 칼날 궤적을 따라 베인 자국(가는 선)을 남기거나 먼지를 낸다. 마법은 베인 자국을 남기지 않는다.
8. **자국은 짧고, 반응은 길다.** 자국 자체는 30fps 기준 4~8프레임(0.13~0.27초). 타격감은 자국이 아니라 맞는 순간의 반응에서 온다: 히트 스톱, 흰 번쩍임, 밀림·납작해짐, 화면 흔들림, 파편, 숫자. 대상은 오히려 멈춰 있어야 속도가 대비된다.

## 2. 형태 원칙 자료

| 자료 | 무엇을 배우나 |
|---|---|
| [Jason Tomlee, Slash Shape Fundamentals](https://jasontomlee.itch.io/slashfx/devlog/629732/tutorial-2-slash-shape-fundamentals) | 초승달·깃발 비례·"actor의 휘두름을 따르는 곡률"을 그림 세 장으로 보여준다. 정점 모양은 1~2프레임만 존재. 잡 픽셀이 흐름을 망친다 |
| [タテラボ, 剣の軌道(剣撃エフェクト)の奥義](https://tatelab.sorajima.jp/textbook/KVy9qgoj) | 어깨·팔꿈치 축의 호, 가는 선=빠름·두꺼운 선=무거움, 가는 선 여러 개=연속 참격, 강타에는 파편, 대상은 정지 |
| [CLIP STUDIO TIPS, Manga Action Effects Using "White"](https://tips.clip-studio.com/en-us/articles/10167) | 흰 검격 = 칼날 반사광 + 갈라지는 공기. 대상에 궤적을 따라 베인 자국을 낸다 |
| [Game Effect Academy, シンプルなスラッシュ](https://unity-effect.com/368/) | 실루엣은 실제 칼 궤적(원호)을 따르고, 심이 밝고 가장자리가 어두워야 입체감이 난다 |
| [お絵かき図鑑, 炎・雷・水・斬撃エフェクトの描き方](https://oekaki-zukan.com/articles/4262) | 궤적 앞머리만 발광시키는 레이어 기법 (참고용, 우리는 발광을 쓰지 않는다) |
| [Realtime VFX, Sword Slash help](https://realtimevfx.com/t/sword-slash-help/9407) | 3D 쪽 논의지만 요점은 같다: 트레일은 생각보다 크게, 접촉점의 2차 파편이 없으면 약해 보인다, 기존 게임의 슬래시를 관찰해 원리를 익혀라 |
| [Pixel Tutorial - Sword Slash Animation](https://itch.io/t/2489691/pixel-tutorial-sword-slash-animation) | 예비 동작(anticipation) 1프레임 → 베기 → 회복. 예비 동작이 무게를 만든다 |

## 3. 타격감 원칙 자료

| 자료 | 무엇을 배우나 |
|---|---|
| [사쿠라이, Stop for Big Moments!](https://www.youtube.com/watch?v=OdVkEOzdCPw) | 히트 스톱: 맞는 순간 아주 짧게 멈추면 공격에 무게가 실린다 |
| [사쿠라이, Eight Hit Stop Techniques](https://www.youtube.com/watch?v=tycbMSjDDLg) | 스매시브라더스의 히트 스톱 8기법. 공격자·피격자 중 누구를 얼마나 멈추는지, 떨림을 섞는지 |
| [사쿠라이, Flash, Blast, and Smoke](https://www.youtube.com/watch?v=ZDopYzDX-Jg) | 타격 효과는 번쩍임 → 터짐 → 연기의 순서로 단계가 있다. 자국 하나로 끝내지 않는다 |
| [사쿠라이, Visual Effects in Slow Motion](https://pokemonblog.com/2023/02/28/video-super-smash-bros-ultimate-director-masahiro-sakurai-takes-a-deliberate-look-at-visual-effects-in-slow-motion/) | 효과를 느리게 보며 뜯어본다. 실제 속도에서 읽히도록 설계해야 한다 |
| [Vlambeer, The Art of Screenshake](https://www.youtube.com/watch?v=AJdEqssNZ-U) | 화면 흔들림·히트 스톱·넉백·파편 등 30가지 기법을 켜고 끄며 보여준다 (재현 프로젝트: [colinbellino/screenshake](https://github.com/colinbellino/screenshake)) |
| [Juice it or lose it](https://youtu.be/Fy0aCDmgnxg) | "주스는 이미 되는 것 위에 얹는 것"이다. 연출로 게임을 구하려 하지 않는다 |
| [GDQuest, Juicing up your game attacks](https://www.gdquest.com/library/juicy_attack/) | 고도 기준 정리: 예비 동작, 스미어, 이징, `lerp` 넉백, 흰 번쩍임 셰이더, 파티클, 떠오르는 숫자, 히트 스톱, 피격 회전 |

## 4. 게임 레퍼런스

직접 플레이 영상을 보고 판단할 것. 우리 그림체와 가까운 순서.

- **Hollow Knight** — 검격의 교과서. 흰 초승달에 어두운 테두리, 4프레임 남짓, 위·아래·앞 방향이 분명하다. 맞으면 흰 번쩍임, 가는 흰 파편, 짧은 히트 스톱과 반동. [The Effects Animation of Hollow Knight](https://www.youtube.com/watch?v=SIJtfr-PO4Y), [슬래시 재현 튜토리얼](https://www.youtube.com/watch?v=OBAGSY9Iqik), [스프라이트 시트 모음](https://www.spriters-resource.com/pc_computer/hollowknight/)
- **Katana ZERO** — 얇고 날카로운 흰 호, 강한 히트 스톱과 슬로모션. "가늘수록 날카롭다"의 극단
- **Dead Cells** — 칼 자체가 스미어(뭉개짐)로 호가 되는 방식. 자국 없이도 검격이 읽힌다
- **던전앤파이터 (귀검사)** — 국내 2D 횡스크롤 타격감의 기준. 흰 참격 + 흰 파편 + 히트 스톱 + 흔들림. [웨펀마스터 스킬 목록](https://namu.wiki/w/%EC%9B%A8%ED%8E%80%EB%A7%88%EC%8A%A4%ED%84%B0(%EB%8D%98%EC%A0%84%20%EC%95%A4%20%ED%8C%8C%EC%9D%B4%ED%84%B0)/%EC%8A%A4%ED%82%AC)에서 영상 참고
- **Tap Titans 2** — 같은 장르(탭 클리커). 탭 참격 모양을 "Slash" 장비로 갈아 끼우게 만들었을 만큼 탭 연출이 핵심 상품이다. 초당 여러 번 탭해도 읽히는 크기·수명이 참고점. [Slashes 위키](https://tap-titans-2.fandom.com/wiki/Slashes)
- **Guardian Tales** — SD 캐릭터의 검격. 작은 몸에 어울리는 자국 크기 비율

## 5. 직접 볼 수 있는 에셋 (미리보기와 라이선스)

그림체가 달라도 "형태의 수명"을 보는 데 좋다. 미리보기 GIF를 프레임별로 펼쳐 확인했다.

| 에셋 | 스타일 | 배운 점 | 라이선스 |
|---|---|---|---|
| [sugawara_studio, Cel-Shaded Style Slash](https://sugawara-studio.itch.io/cel-shaded-style-slash-animation-asset-free) | 애니메이션 셀 스타일, 500×500, 24프레임 | **우리 그림체에 가장 가깝다.** 붓 자국처럼 갈라진 굵은 초승달에 검은 외곽선. 꽉 찬 채로 나타나 꼬리부터 깎여 사라진다 | 무료판(빨강) 상업 이용 가능, 크레딧 불필요, 재배포 금지. 색 변형 $2.99 |
| [Frostwindz, Pixel Art VFX - Slashes](https://frostwindz.itch.io/pixel-art-slashes) | 픽셀, 3가지 형태 × 5색 | 쉼표형·갈고리형·발톱형 세 실루엣. 얇은 쐐기 → 초승달 → 꼬리 침식의 3단계가 또렷하다. 흰 심 + 중간 톤 + 어두운 테두리 | 이름만큼 내기(무료 가능), 상업 이용 가능 |
| [OpenGameArt, Pixel art sword slash effect](https://opengameart.org/content/pixel-art-sword-slash-effect) | 픽셀 9프레임, 64×47 | 얇은 선 → 부푼 초승달(흰 심) → 가닥으로 흩어짐. 가장 작고 단순한데도 검으로 읽힌다 | CC0 |
| [flimzy, Weapon Slash](https://flimzy.itch.io/weapon-slash) | 픽셀 17프레임, 32×32 | 작은 호가 자라 초승달이 되고 가늘어져 사라짐 | 페이지 확인 |
| [Met.Pxl, Pixel Art Sword VFX](https://metpxl.itch.io/pixel-art-sword-vfx-attack-slash-animation-pack) | 픽셀 6프레임 | 초승달 뒤에 잔 파편이 흩어지며 꺼짐 | 페이지 확인 |
| [Cethiel, Weapon Slash - Effect](https://opengameart.org/content/weapon-slash-effect) | 2D, 5종 × 4색 | 색 변형 예시 | CC0 |
| [ぴぽや 戦闘エフェクト 基本セット](https://pipoya.net/sozai/assets/effects/effect-battle-basic-set/) / [斬撃 素材集](https://pipoya.net/sozai/assets/effects/pipoya-game-effect-material-collection/) | 일본 RPG 스타일 | 참격 8종 × 8색 세트. RPG 쪽 문법 | 기본 세트 무료(이용 규약 확인), 참격집 유료(상업 가능, 재배포 금지) |
| [CartoonCoffee, 2D Sword Slash VFX](https://cartooncoffee.itch.io/2d-sword-slash-vfx) | 파티클 발광 | **반례.** 파랗게 빛나는 부채꼴·고리 80종. 보기엔 화려하지만 우리가 "마법 같다"고 느낀 바로 그 문법 | $19.99 |

## 6. 우리 게임에 적용할 안 (확정 전)

위 원칙을 지금 구현(scenes/battle/slash_fx.gd)에 대입하면 고칠 것이 분명하다.

| 항목 | 지금 | 레퍼런스 기준 |
|---|---|---|
| 굵기 분포 | 가운데(0.35~0.6)가 두껍고 양 끝 뾰족 | 앞머리 쪽(0.6~0.75)이 가장 두껍고 꼬리로 길게 가늘어지는 깃발형 |
| 끝 모양 | 매끈한 바늘 | 꼬리는 2~3가닥으로 갈라짐, 앞머리는 살짝 말림 |
| 색 | 흰 면 + 어두운 외곽선 | 흰 심 + 옅은 회청색 중간 톤 + 어두운 외곽선 (3톤). 치명타도 노랑·주황 대신 더 굵고 크게 |
| 수명 | 즉시 나타나 균일하게 투명해짐 (0.12초) | 얇은 조각(1프레임) → 꽉 찬 초승달(접촉, 2프레임) → 꼬리부터 침식(3~4프레임) → 사라짐. 총 0.13~0.2초 |
| 잔상 | 같은 모양 한 줄 | 가는 가닥 1~2개가 꼬리 쪽에만 |
| 베인 자국 | 가는 흰 선 0.24초 | 유지. 침식 단계에 맞춰 같이 가늘어지게 |
| 난무(연타) | 0.9배 축소, 잔상 없음 | 굵은 초승달 대신 **가는 선 여러 개**(연속 참격의 문법). 크기가 아니라 굵기로 구분 |
| 파편 | 흰 줄기 8알 | 유지. 강타(치명타·처치)에만 양을 늘림 |
| 히트 스톱·흔들림·밀림 | 있음 | 유지. 사쿠라이 기법대로 피격자만 멈추고 공격자는 아주 짧게 |

## 7. 결정할 것

- 셀 스타일(sugawara: 붓 자국, 갈라진 꼬리)과 픽셀 스타일(Frostwindz, OGA: 깔끔한 3톤 초승달) 중 어느 쪽 인상이 우리 그림체에 맞는지. 둘 다 "꼬리 침식" 수명은 같다
- 난무를 "가는 선 여러 개"로 갈지, 지금처럼 작은 초승달로 갈지
- 치명타를 색(주황)으로 구분할지, 크기·굵기·X자로만 구분할지

## 8. 결정과 적용 (2026-09-23)

- 방향: **Frostwindz 픽셀 슬래시**의 문법. 치명타는 주황색으로 구분한다
- 적용: tools/make_slash_frames.gd가 프레임 6장(조각 → 쉼표 → 초승달 → 침식 → 조각 → 티끌)을 SVG로 만들고 scenes/battle/slash_fx.gd가 플립북으로 재생한다. 단발 0.21초, 난무는 가는 프레임만 0.105초. 색은 흰 심 + 강철빛 #cfe0f0 + 외곽선. 호의 축은 용사의 어깨 높이
- 뺀 것: 잔상 겹치기, 몬스터 위의 베인 자국 선 (침식 프레임의 가닥이 그 역할을 한다)
- 연타 재조정: 연타 중 두꺼운 프레임(쉼표·침식 1)과 치명타의 두꺼운 X자가 초당 몇 번씩 덩어리로 보였다. 난무는 두께 없는 가는 선 프레임(6·7)만, 각도·자리 고정, 치명타도 가는 선을 주황으로. 불꽃·접촉 불꽃·숫자 펀치·흔들림도 줄임
