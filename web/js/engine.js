/*
 * engine.js — PB Gen tournament engine (web port)
 *
 * A faithful JavaScript port of the app's Swift core:
 *   - SeededRandomNumberGenerator.swift  -> SeededRNG
 *   - AmericanoScheduler.swift           -> AmericanoScheduler
 *   - LeaderboardViewModel scoring       -> computeLeaderboard
 *
 * Pure logic only (no DOM / storage), so it runs in the browser and under
 * Node for the test suite. Preserves the original algorithm's behaviour:
 * play-deficit fairness, repeat-partnership avoidance until unique pairs are
 * exhausted (then "allow repeats" mode), and fair rest rotation.
 */
(function (root, factory) {
  const api = factory();
  if (typeof module === "object" && module.exports) module.exports = api;
  else root.Engine = api;
})(typeof self !== "undefined" ? self : this, function () {
  "use strict";

  // ==========================================================================
  // Seeded RNG — port of SeededRandomNumberGenerator (64-bit LCG via BigInt).
  //   state = state &* 6364136223846793005 &+ 1
  //   result = state ^ (state >> 21)
  // ==========================================================================
  const MASK64 = (1n << 64n) - 1n;
  const MUL = 6364136223846793005n;

  class SeededRNG {
    constructor(seed) {
      this.state = BigInt.asUintN(64, BigInt(seed));
    }
    next() {
      this.state = (this.state * MUL + 1n) & MASK64;
      return (this.state ^ (this.state >> 21n)) & MASK64;
    }
    // Float in [0, 1) using the top 53 bits.
    nextDouble() {
      return Number(this.next() >> 11n) / 9007199254740992; // 2^53
    }
    // Float in [0, upper).
    nextUpTo(upper) {
      return this.nextDouble() * upper;
    }
  }

  function makeSeed() {
    if (typeof crypto !== "undefined" && crypto.getRandomValues) {
      const a = new Uint32Array(2);
      crypto.getRandomValues(a);
      return (BigInt(a[0]) << 32n) | BigInt(a[1]);
    }
    // Node / fallback — good enough for seeding.
    return BigInt(Math.floor(Math.random() * 0x100000000)) << 32n |
           BigInt(Math.floor(Math.random() * 0x100000000));
  }

  // ==========================================================================
  // Helpers
  // ==========================================================================
  function pairKey(a, b) {
    return a < b ? a + "|" + b : b + "|" + a;
  }

  // Stable sort driven by a Swift-style "areInIncreasingOrder" predicate
  // that returns true when `a` should come before `b`.
  function sortByPredicate(arr, isBefore) {
    return arr
      .map((v, i) => [v, i])
      .sort((x, y) => {
        if (isBefore(x[0], y[0])) return -1;
        if (isBefore(y[0], x[0])) return 1;
        return x[1] - y[1]; // stable
      })
      .map((p) => p[0]);
  }

  function uniqueNonEmpty(players) {
    const seen = new Set();
    const out = [];
    for (const p of players) {
      const name = String(p == null ? "" : p);
      if (!name) continue;
      if (seen.has(name)) continue;
      seen.add(name);
      out.push(name);
    }
    return out;
  }

  // ==========================================================================
  // AmericanoScheduler
  // ==========================================================================
  class AmericanoScheduler {
    constructor(players, numberOfRounds, numberOfCourts, seed) {
      this.players = uniqueNonEmpty(players);
      this.numberOfRounds = numberOfRounds;
      this.numberOfCourts = numberOfCourts;
      this.seed = seed == null ? makeSeed() : seed;
      this.rng = new SeededRNG(this.seed);

      this.playerStats = {};
      this.usedPairs = new Set();
      this.pairUsageCount = new Map();
      this.lastRestRound = {};
      this.restingPlayersByRound = {};
      this.totalPossiblePairs = (this.players.length * (this.players.length - 1)) / 2;
      this.allowRepeats = false;

      for (const p of this.players) {
        this.lastRestRound[p] = -1;
        this.playerStats[p] = this._newStats();
      }
    }

    _newStats() {
      return { gamesPlayed: 0, uniquePairs: new Set(), lastPlayedRound: -1 };
    }

    _usage(key) {
      return this.pairUsageCount.get(key) || 0;
    }

    // --- fairness scoring (port of calculatePlayDeficitScore) ---------------
    calculatePlayDeficitScore(player, currentRound) {
      const stats = this.playerStats[player];
      if (!stats) return 0;
      const roundCount = Math.max(currentRound + 1, 1);
      const gamesPlayedScore = stats.gamesPlayed / roundCount;
      const uniquePairsScore = stats.uniquePairs.size / Math.max(this.players.length - 1, 1);
      const roundsSinceLastPlayed = currentRound - stats.lastPlayedRound;
      return 0.4 * (1.0 - gamesPlayedScore) +
             0.4 * (1.0 - uniquePairsScore) +
             0.2 * roundsSinceLastPlayed;
    }

    _updatePlayerStats(team1, team2, round) {
      const all = [team1.player1, team1.player2, team2.player1, team2.player2];
      for (const player of all) {
        const stats = this.playerStats[player] || this._newStats();
        stats.gamesPlayed += 1;
        stats.lastPlayedRound = round;
        if (player === team1.player1) stats.uniquePairs.add(team1.player2);
        else if (player === team1.player2) stats.uniquePairs.add(team1.player1);
        else if (player === team2.player1) stats.uniquePairs.add(team2.player2);
        else stats.uniquePairs.add(team2.player1);
        this.playerStats[player] = stats;
      }
    }

    _updatePairUsage(team1, team2) {
      const pair1 = pairKey(team1.player1, team1.player2);
      const pair2 = pairKey(team2.player1, team2.player2);
      this.usedPairs.add(pair1);
      this.usedPairs.add(pair2);
      this.pairUsageCount.set(pair1, this._usage(pair1) + 1);
      this.pairUsageCount.set(pair2, this._usage(pair2) + 1);
      const opp = [
        pairKey(team1.player1, team2.player1),
        pairKey(team1.player1, team2.player2),
        pairKey(team1.player2, team2.player1),
        pairKey(team1.player2, team2.player2),
      ];
      for (const k of opp) this.pairUsageCount.set(k, this._usage(k) + 1);
    }

    _averagePairUsage(player, opponents) {
      let sum = 0;
      for (const o of opponents) sum += this._usage(pairKey(player, o));
      return sum / opponents.length;
    }

    _validateRoundBalance() {
      const counts = Object.values(this.playerStats).map((s) => s.gamesPlayed);
      if (counts.length === 0) return true;
      return Math.max(...counts) - Math.min(...counts) <= 1;
    }

    // --- public API ---------------------------------------------------------
    generateSchedule() {
      if (this.players.length < 4) return null;
      if (this.numberOfCourts < 1) return null;

      let schedule = [];
      this.restingPlayersByRound = {};
      this.usedPairs = new Set();
      this.pairUsageCount = new Map();
      this.allowRepeats = false;
      for (const p of this.players) this.playerStats[p] = this._newStats();

      for (let round = 0; round < this.numberOfRounds; round++) {
        if (!this.allowRepeats && this.usedPairs.size >= this.totalPossiblePairs) {
          this.allowRepeats = true;
        }
        let { matches, resting } = this._generateRound(round);
        // If unique-pair mode dead-ends before all pairs are formally
        // exhausted, permit repeats and retry rather than silently dropping
        // the round (the original app could return fewer rounds than asked).
        if (matches.length === 0 && !this.allowRepeats) {
          this.allowRepeats = true;
          ({ matches, resting } = this._generateRound(round));
        }
        if (matches.length === 0) {
          if (round === 0) return null;
          return { schedule, restingByRound: this.restingPlayersByRound };
        }
        schedule = schedule.concat(matches);
        this.restingPlayersByRound[round] = resting;
      }
      return { schedule, restingByRound: this.restingPlayersByRound };
    }

    _generateRound(round) {
      // Sort players by play deficit (descending — neediest first).
      let available = sortByPredicate(this.players, (p1, p2) =>
        this.calculatePlayDeficitScore(p1, round) > this.calculatePlayDeficitScore(p2, round)
      );

      const maxMatches = Math.min(this.numberOfCourts, Math.floor(available.length / 4));
      const maxPlayersThisRound = maxMatches * 4;
      const playersToRest = available.length - maxPlayersThisRound;

      let resting = [];
      if (playersToRest > 0) {
        const restCandidates = sortByPredicate(available, (p1, p2) => {
          const r1 = this.lastRestRound[p1] ?? -1;
          const r2 = this.lastRestRound[p2] ?? -1;
          if (r1 !== r2) return r1 < r2;
          return (this.playerStats[p1]?.gamesPlayed ?? 0) > (this.playerStats[p2]?.gamesPlayed ?? 0);
        });
        resting = restCandidates.slice(0, playersToRest);
        const restingSet = new Set(resting);
        available = available.filter((p) => !restingSet.has(p));
        for (const p of resting) this.lastRestRound[p] = round;
      }

      const matches = this._generateMatchesWithBacktracking(available, round, 1);
      if (matches) {
        for (const m of matches) {
          this._updatePlayerStats(m.team1, m.team2, round);
          this._updatePairUsage(m.team1, m.team2);
        }
        return { matches, resting };
      }
      return { matches: [], resting };
    }

    _generateMatchesWithBacktracking(availablePlayers, round, courtNumber) {
      const matches = [];
      let remaining = availablePlayers.slice();

      if (remaining.length === 0) return matches;
      if (remaining.length < 4) return null;

      const player1 = remaining.shift();

      // No "previous round" pairs are available inside a fresh recursion
      // (existingSchedule is empty in the Swift call), matching the original.
      const previousPairs = new Set();

      const potentialPartners = sortByPredicate(remaining, (a, b) => {
        const pa = pairKey(player1, a);
        const pb = pairKey(player1, b);
        if (this.allowRepeats) {
          if (previousPairs.has(pa) && !previousPairs.has(pb)) return false;
          if (!previousPairs.has(pa) && previousPairs.has(pb)) return true;
          const rf = this.rng.nextUpTo(0.3);
          return this._usage(pa) + rf < this._usage(pb);
        }
        return this._usage(pa) < this._usage(pb);
      });

      for (const partner1 of potentialPartners) {
        const team1Pair = pairKey(player1, partner1);
        if (!this.allowRepeats && this.usedPairs.has(team1Pair)) continue;

        const playersForTeam2 = remaining.filter((p) => p !== partner1);

        const team2Candidates = sortByPredicate(playersForTeam2, (a, b) => {
          if (this.allowRepeats) {
            const av1 = this._averagePairUsage(a, [player1, partner1]);
            const av2 = this._averagePairUsage(b, [player1, partner1]);
            const rf = this.rng.nextUpTo(0.3);
            return av1 + rf < av2;
          }
          return this._averagePairUsage(a, [player1, partner1]) <
                 this._averagePairUsage(b, [player1, partner1]);
        });

        for (const player2 of team2Candidates) {
          const remainingForTeam2 = team2Candidates.filter((p) => p !== player2);

          const potentialPartners2 = sortByPredicate(remainingForTeam2, (a, b) => {
            const pa = pairKey(player2, a);
            const pb = pairKey(player2, b);
            if (this.allowRepeats) {
              if (previousPairs.has(pa) && !previousPairs.has(pb)) return false;
              if (!previousPairs.has(pa) && previousPairs.has(pb)) return true;
              const rf = this.rng.nextUpTo(0.3);
              return this._usage(pa) + rf < this._usage(pb);
            }
            return this._usage(pa) < this._usage(pb);
          });

          for (const partner2 of potentialPartners2) {
            const team2Pair = pairKey(player2, partner2);
            if (!this.allowRepeats && this.usedPairs.has(team2Pair)) continue;
            if (this.allowRepeats && previousPairs.has(team1Pair) && previousPairs.has(team2Pair)) continue;

            const team1 = { player1: player1, player2: partner1 };
            const team2 = { player1: player2, player2: partner2 };
            const match = {
              id: uuid(),
              round,
              court: courtNumber,
              team1,
              team2,
              team1Score: 0,
              team2Score: 0,
              winningTeam: null,
            };

            const used = new Set([partner1, player2, partner2]);
            const nextPlayers = remaining.filter((p) => !used.has(p));

            const rest = this._generateMatchesWithBacktracking(nextPlayers, round, courtNumber + 1);
            if (rest) {
              matches.push(match);
              for (const m of rest) matches.push(m);
              return matches;
            }
          }
        }
      }
      return null;
    }

    generateAdditionalRound(existingSchedule) {
      const newRound = (existingSchedule.length ? existingSchedule[existingSchedule.length - 1].round : -1) + 1;
      this.numberOfRounds += 1;

      // Rebuild usage/stats from the existing schedule so fairness continues.
      for (const m of existingSchedule) {
        this._updatePairUsage(m.team1, m.team2);
        this._updatePlayerStats(m.team1, m.team2, m.round);
      }
      if (!this.allowRepeats && this.usedPairs.size >= this.totalPossiblePairs) {
        this.allowRepeats = true;
      }

      const { matches, resting } = this._generateRound(newRound);
      if (matches.length === 0) {
        this.numberOfRounds -= 1;
        return null;
      }
      this.restingPlayersByRound[newRound] = resting;
      return { matches, resting };
    }
  }

  // Lightweight UUID (RFC4122 v4-ish) — crypto when available.
  function uuid() {
    if (typeof crypto !== "undefined" && crypto.randomUUID) return crypto.randomUUID();
    let s = "";
    for (let i = 0; i < 32; i++) {
      s += Math.floor(Math.random() * 16).toString(16);
      if (i === 7 || i === 11 || i === 15 || i === 19) s += "-";
    }
    return s;
  }

  // ==========================================================================
  // Leaderboard scoring (port of LeaderboardViewModel semantics).
  // Recomputed from the schedule each time — avoids the incremental
  // double-count that the original could hit on repeated score edits.
  // ==========================================================================
  function computeLeaderboard(players, schedule, restingByRound, opts) {
    const pointsPerWin = (opts && opts.pointsPerWin) || 1;
    const stats = {};
    for (const p of players) {
      stats[p] = { name: p, wins: 0, losses: 0, pointDifferential: 0, rests: 0, gamesPlayed: 0, score: 0 };
    }

    for (const m of schedule) {
      const decided = m.winningTeam === 1 || m.winningTeam === 2;
      if (!decided) continue;
      const diff = Math.abs((m.team1Score || 0) - (m.team2Score || 0));
      const winners = m.winningTeam === 1 ? m.team1 : m.team2;
      const losers = m.winningTeam === 1 ? m.team2 : m.team1;
      for (const p of [winners.player1, winners.player2]) {
        if (!stats[p]) continue;
        stats[p].wins += 1;
        stats[p].gamesPlayed += 1;
        stats[p].pointDifferential += diff;
        stats[p].score += pointsPerWin;
      }
      for (const p of [losers.player1, losers.player2]) {
        if (!stats[p]) continue;
        stats[p].losses += 1;
        stats[p].gamesPlayed += 1;
        stats[p].pointDifferential -= diff;
      }
    }

    if (restingByRound) {
      for (const round of Object.keys(restingByRound)) {
        for (const p of restingByRound[round]) {
          if (stats[p]) stats[p].rests += 1;
        }
      }
    }

    return stats;
  }

  const SORT_ORDERS = ["name", "score", "wins", "losses", "rests"];

  function sortLeaderboard(statsMap, sortOrder) {
    const entries = Object.values(statsMap).filter((s) => s.name && s.name.trim() !== "");
    entries.sort((a, b) => {
      switch (sortOrder) {
        case "name":
          return a.name.toLowerCase().localeCompare(b.name.toLowerCase());
        case "wins":
          return b.wins - a.wins || b.pointDifferential - a.pointDifferential;
        case "losses":
          return a.losses - b.losses || b.pointDifferential - a.pointDifferential;
        case "rests":
          return a.rests - b.rests || b.pointDifferential - a.pointDifferential;
        case "score":
        default:
          if (b.wins !== a.wins) return b.wins - a.wins;
          return b.pointDifferential - a.pointDifferential;
      }
    });
    return entries;
  }

  return {
    SeededRNG,
    AmericanoScheduler,
    computeLeaderboard,
    sortLeaderboard,
    SORT_ORDERS,
    makeSeed,
    uuid,
    _internals: { pairKey, uniqueNonEmpty, sortByPredicate },
  };
});
