#!/usr/bin/env python3
"""목표 스테이지까지 가장 빠른 루트 찾기 (GDD 13절).

정책 조합(회귀 배수, 스킬 사용, 결정 사용 계획, 정체 기준)마다 tools/balance_sim.tscn을 돌려 목표 도달 시간을 재고,
빠른 순서로 표를 찍는다. 시뮬레이션은 실제 게임 코드를 쓰므로 한 조합에 몇 분 걸린다. 여러 개를 나란히 돌린다.

    python3 tools/route_search.py --godot godot --goal 500 --jobs 3
"""
import argparse
import concurrent.futures
import itertools
import re
import subprocess
import sys
import time

GRID = {  # 회귀 배수 1은 120 근처에서 결정 10개짜리 회귀를 되풀이하다 10시간 안에 500에 못 닿아 뺐다
    "ratio": ["0", "2", "4"],
    "skills": ["0", "1"],
    "plan": ["sword_gold", "all"],
    "stall": ["30", "60", "120"],
}


def run_one(godot: str, project: str, goal: int, combo: dict) -> tuple:
    args = [godot, "--headless", "--path", project, "res://tools/balance_sim.tscn", "--", f"--goal={goal}"]
    args += [f"--{key}={value}" for key, value in combo.items()]
    started = time.time()
    out = subprocess.run(args, capture_output=True, text=True, timeout=7200).stdout
    match = re.search(r"SCORE=(\S+)", out)
    score = match.group(1) if match else "none"
    seconds = None if score == "none" else int(score)
    return combo, seconds, time.time() - started


def clock(seconds) -> str:
    if seconds is None:
        return "미달"
    hours, rest = divmod(int(seconds), 3600)
    minutes, secs = divmod(rest, 60)
    return f"{hours}시간 {minutes:02d}분 {secs:02d}초" if hours else f"{minutes}분 {secs:02d}초"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--project", default=".")
    parser.add_argument("--goal", type=int, default=500)
    parser.add_argument("--jobs", type=int, default=3)
    options = parser.parse_args()
    combos = [dict(zip(GRID.keys(), values)) for values in itertools.product(*GRID.values())]
    results = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=options.jobs) as pool:
        futures = [pool.submit(run_one, options.godot, options.project, options.goal, combo) for combo in combos]
        for future in concurrent.futures.as_completed(futures):
            combo, seconds, took = future.result()
            results.append((seconds if seconds is not None else float("inf"), combo, seconds))
            print(f"[{len(results)}/{len(combos)}] {combo} → {clock(seconds)} (실행 {took:.0f}초)", file=sys.stderr, flush=True)
    results.sort(key=lambda item: item[0])
    print(f"\n## 목표 {options.goal} 도달 시간 (빠른 순)\n")
    print("| 순위 | 회귀 배수 | 스킬 | 결정 사용 | 정체 기준 | 도달 시간 |")
    print("|---|---|---|---|---|---|")
    for rank, (_, combo, seconds) in enumerate(results, 1):
        skills = "사용" if combo["skills"] == "1" else "없음"
        ratio = "정체로만" if combo["ratio"] == "0" else f"×{combo['ratio']}"
        print(f"| {rank} | {ratio} | {skills} | {combo['plan']} | {combo['stall']}초 | {clock(seconds)} |")


if __name__ == "__main__":
    main()
