/*
 * Zero-dependency test suite for the PB Gen web engine.
 * Run:  node web/tests/engine.test.js
 */
const E = require("../js/engine.js");

let passed = 0, failed = 0;
const failures = [];
function assert(cond, msg) {
  if (cond) passed++;
  else { failed++; failures.push(msg); console.error("  ✗ " + msg); }
}
function group(name, fn) { console.log("\n" + name); fn(); }
function names(n) { return Array.from({ length: n }, (_, i) => "P" + (i + 1)); }

// ---------------------------------------------------------------------------
group("SeededRNG — determinism & range", () => {
  const a = new E.SeededRNG(12345n);
  const b = new E.SeededRNG(12345n);
  let same = true;
  for (let i = 0; i < 1000; i++) if (a.next() !== b.next()) same = false;
  assert(same, "same seed => identical 64-bit stream");

  const c = new E.SeededRNG(999n);
  let inRange = true;
  for (let i = 0; i < 10000; i++) {
    const d = c.nextDouble();
    if (d < 0 || d >= 1) inRange = false;
  }
  assert(inRange, "nextDouble stays in [0,1)");

  const d1 = new E.SeededRNG(1n).next();
  const d2 = new E.SeededRNG(2n).next();
  assert(d1 !== d2, "different seeds => different output");
});

// ---------------------------------------------------------------------------
group("Scheduler — structural invariants (broad sweep)", () => {
  const playerCounts = [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 16, 20, 24];
  let configs = 0;
  for (const n of playerCounts) {
    const maxCourts = Math.max(1, Math.floor(n / 4));
    for (let courts = 1; courts <= Math.min(maxCourts, 5); courts++) {
      for (const rounds of [1, 3, 5, 8]) {
        for (const seed of [1n, 42n, 7777n]) {
          const s = new E.AmericanoScheduler(names(n), rounds, courts, seed);
          const result = s.generateSchedule();
          configs++;
          assert(result !== null, `n=${n} c=${courts} r=${rounds} generates a schedule`);
          if (!result) continue;

          const seats = courts * 4;
          const expectPlaying = Math.min(n, seats - (seats % 4));
          const expectCourts = expectPlaying / 4;

          // Group matches by round.
          const byRound = {};
          for (const m of result.schedule) (byRound[m.round] = byRound[m.round] || []).push(m);

          for (let r = 0; r < rounds; r++) {
            const roundMatches = byRound[r] || [];
            assert(roundMatches.length === expectCourts, `n=${n} c=${courts} r${r}: ${expectCourts} matches`);

            const appear = {};
            for (const p of names(n)) appear[p] = 0;
            for (const m of roundMatches) {
              const four = [m.team1.player1, m.team1.player2, m.team2.player1, m.team2.player2];
              assert(new Set(four).size === 4, `n=${n} c=${courts} r${r}: 4 distinct players per match`);
              for (const p of four) appear[p]++;
              // courts numbered 1..expectCourts
              assert(m.court >= 1 && m.court <= expectCourts, "court number in range");
            }
            const resting = result.restingByRound[r] || [];
            for (const p of resting) appear[p]++;

            let dupes = 0, missing = 0;
            for (const p of names(n)) { if (appear[p] > 1) dupes++; if (appear[p] === 0) missing++; }
            assert(dupes === 0, `n=${n} c=${courts} seed r${r}: nobody appears twice`);
            assert(missing === 0, `n=${n} c=${courts} r${r}: everyone accounted for`);
            assert(resting.length === n - expectPlaying, `n=${n} c=${courts} r${r}: correct rest count`);
          }
        }
      }
    }
  }
  console.log(`  (swept ${configs} schedule configurations)`);
});

// ---------------------------------------------------------------------------
group("Scheduler — no repeat partnerships until unique pairs exhausted", () => {
  // 4 players: only 3 unique partnerships possible (AB, AC, AD... actually
  // 6 pairs). Over a few rounds with 1 court, each round uses 2 partnerships.
  const s = new E.AmericanoScheduler(names(8), 3, 2, 42n);
  const res = s.generateSchedule();
  const partnerCount = {};
  for (const m of res.schedule) {
    for (const t of [m.team1, m.team2]) {
      const k = E._internals.pairKey(t.player1, t.player2);
      partnerCount[k] = (partnerCount[k] || 0) + 1;
    }
  }
  // 8 players, 28 unique pairs, only 12 partnerships formed over 3 rounds ->
  // should all be unique.
  const maxRepeat = Math.max(...Object.values(partnerCount));
  assert(maxRepeat === 1, `8 players/3 rounds: no repeat partnerships (max=${maxRepeat})`);
});

// ---------------------------------------------------------------------------
group("Scheduler — rest rotation fairness", () => {
  const s = new E.AmericanoScheduler(names(5), 10, 1, 3n);
  const res = s.generateSchedule();
  const restCount = {};
  for (const p of names(5)) restCount[p] = 0;
  for (const r of Object.keys(res.restingByRound))
    for (const p of res.restingByRound[r]) restCount[p]++;
  const vals = Object.values(restCount);
  const spread = Math.max(...vals) - Math.min(...vals);
  assert(spread <= 1, `5 players/10 rounds: rests balanced within 1 (spread=${spread}, ${vals.join(",")})`);
  const total = vals.reduce((a, b) => a + b, 0);
  assert(total === 10, `total rests = 10 (got ${total})`);
});

group("Scheduler — games played fairness", () => {
  const s = new E.AmericanoScheduler(names(6), 12, 1, 5n);
  const res = s.generateSchedule();
  const played = {};
  for (const p of names(6)) played[p] = 0;
  for (const m of res.schedule)
    for (const p of [m.team1.player1, m.team1.player2, m.team2.player1, m.team2.player2]) played[p]++;
  const vals = Object.values(played);
  const spread = Math.max(...vals) - Math.min(...vals);
  // The original rest heuristic rotates by last-rested-round, which keeps play
  // even but not perfectly equal over long runs; a spread of ≤2 is expected.
  assert(spread <= 2, `6 players/12 rounds: games played balanced within 2 (spread=${spread}, ${vals.join(",")})`);
});

// ---------------------------------------------------------------------------
group("Scheduler — additional round", () => {
  const s = new E.AmericanoScheduler(names(8), 3, 2, 100n);
  const res = s.generateSchedule();
  const roundsBefore = new Set(res.schedule.map((m) => m.round)).size;
  const add = s.generateAdditionalRound(res.schedule);
  assert(add !== null, "additional round generated");
  assert(add.matches.length === 2, "additional round has 2 matches (2 courts)");
  assert(add.matches.every((m) => m.round === roundsBefore), "new matches use the next round index");
  const four = add.matches.flatMap((m) => [m.team1.player1, m.team1.player2, m.team2.player1, m.team2.player2]);
  assert(new Set(four).size === four.length, "no duplicate players in the added round");
});

// ---------------------------------------------------------------------------
group("Scheduler — edge cases", () => {
  const tooFew = new E.AmericanoScheduler(names(3), 3, 1, 1n).generateSchedule();
  assert(tooFew === null, "fewer than 4 players returns null");

  // duplicate / empty names are filtered
  const s = new E.AmericanoScheduler(["A", "A", "B", "C", "D", ""], 2, 1, 1n);
  assert(s.players.length === 4, "duplicate and empty names filtered (A,B,C,D)");
  const r = s.generateSchedule();
  assert(r !== null, "valid schedule after filtering");

  // More courts than players can fill -> only fills what fits.
  const s2 = new E.AmericanoScheduler(names(6), 2, 5, 1n);
  const r2 = s2.generateSchedule();
  const round0 = r2.schedule.filter((m) => m.round === 0);
  assert(round0.length === 1, "6 players + 5 courts => only 1 match fits per round");
});

// ---------------------------------------------------------------------------
group("Leaderboard — scoring & sorting", () => {
  const players = ["A", "B", "C", "D"];
  const schedule = [
    { round: 0, court: 1,
      team1: { player1: "A", player2: "B" }, team2: { player1: "C", player2: "D" },
      team1Score: 11, team2Score: 6, winningTeam: 1 },
  ];
  const resting = {};
  let board = E.computeLeaderboard(players, schedule, resting, { pointsPerWin: 1 });
  assert(board.A.wins === 1 && board.A.pointDifferential === 5, "winner: +1 win, +5 diff");
  assert(board.C.losses === 1 && board.C.pointDifferential === -5, "loser: +1 loss, -5 diff");
  assert(board.A.score === 1, "winner score += pointsPerWin");

  // Undecided match (tie / no scores) contributes nothing.
  const board2 = E.computeLeaderboard(players, [
    { round: 0, court: 1, team1: { player1: "A", player2: "B" }, team2: { player1: "C", player2: "D" },
      team1Score: 0, team2Score: 0, winningTeam: null },
  ], {}, {});
  assert(Object.values(board2).every((s) => s.wins === 0 && s.losses === 0), "undecided match ignored");

  // Rests counted.
  const board3 = E.computeLeaderboard(["A", "B", "C", "D", "E"], [], { 0: ["E"], 1: ["A"] }, {});
  assert(board3.E.rests === 1 && board3.A.rests === 1, "rests tallied from restingByRound");

  // Sorting: default (score) = wins desc then diff desc.
  const stats = {
    A: { name: "A", wins: 2, losses: 0, pointDifferential: 3, rests: 1 },
    B: { name: "B", wins: 2, losses: 0, pointDifferential: 9, rests: 0 },
    C: { name: "C", wins: 0, losses: 2, pointDifferential: -12, rests: 2 },
  };
  const sorted = E.sortLeaderboard(stats, "score");
  assert(sorted[0].name === "B", "tie on wins broken by point differential (B ahead of A)");
  assert(sorted[2].name === "C", "fewest wins last");

  const byName = E.sortLeaderboard(stats, "name");
  assert(byName[0].name === "A" && byName[2].name === "C", "name sort alphabetical");

  const byRests = E.sortLeaderboard(stats, "rests");
  assert(byRests[0].name === "B", "rest sort ascending (fewest rests first)");
});

// ---------------------------------------------------------------------------
group("Determinism end-to-end", () => {
  const a = new E.AmericanoScheduler(names(9), 6, 2, 2024n).generateSchedule();
  const b = new E.AmericanoScheduler(names(9), 6, 2, 2024n).generateSchedule();
  const strip = (r) => r.schedule.map((m) => [m.round, m.court, m.team1.player1, m.team1.player2, m.team2.player1, m.team2.player2]);
  assert(JSON.stringify(strip(a)) === JSON.stringify(strip(b)), "same seed => identical schedule");
});

// ---------------------------------------------------------------------------
console.log("\n" + "=".repeat(50));
console.log(`Passed: ${passed}   Failed: ${failed}`);
if (failed > 0) {
  console.log("\nFailures:");
  for (const f of failures) console.log("  - " + f);
  process.exit(1);
}
console.log("All tests passed ✅");
