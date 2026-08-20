/*
 * engine.js — PB Gen tournament engine (web port)
 *
 * A faithful JavaScript port of the app's Swift core:
 *   - SeededRandomNumberGenerator.swift  -> SeededRNG
 *   - AmericanoScheduler.swift           -> AmericanoScheduler
 *   - LeaderboardViewModel scoring       -> computeLeaderboard
 *
 * Pure logic only (no DOM / storage), so it runs in the browser and under
 * Node for the test suite.
 *
 * The scheduler has since moved past the original Swift approach. Rather than
 * a greedy walk with a hard no-repeat rule for partnerships and nothing at all
 * for opponents, each round is now chosen by scoring finished rounds on both
 * together. See the notes above AmericanoScheduler.
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

  /** Fisher-Yates using a supplied [0,1) source, so results stay seeded. */
  function shuffleWith(array, rnd) {
    const a = array.slice();
    for (let i = a.length - 1; i > 0; i--) {
      const j = Math.floor(rnd() * (i + 1));
      const t = a[i]; a[i] = a[j]; a[j] = t;
    }
    return a;
  }

  // ==========================================================================
  // AmericanoScheduler
  //
  // Each round is chosen by scoring whole arrangements rather than by walking
  // a greedy list, so partnerships and opponents are balanced together instead
  // of one being a hard rule and the other an afterthought.
  //
  // Cost of an arrangement (lower is better):
  //     W_PARTNER  x (times these two have already partnered)^2
  //   + W_OPPONENT x (times these two have already met as opponents)^2
  //   + W_RECENT   if this exact partnership happened in the previous round
  //
  // Squaring matters: a fourth repeat costs far more than a first, which is
  // what spreads repeats evenly instead of piling them on the same people.
  // Because any split of the playing group is a legal arrangement, a round can
  // never fail to generate — repeats are simply expensive, never forbidden.
  // ==========================================================================
  const W_PARTNER = 100;
  const W_OPPONENT = 6;
  const W_RECENT = 40;
  const RESTARTS = 8;


  class AmericanoScheduler {
    constructor(players, numberOfRounds, numberOfCourts, seed, options) {
      this.players = uniqueNonEmpty(players);
      this.numberOfRounds = numberOfRounds;
      this.numberOfCourts = numberOfCourts;
      this.seed = seed == null ? makeSeed() : seed;
      this.rng = new SeededRNG(this.seed);

      // Weights are overridable so a future "advanced mode" can expose the
      // partnership/opponent trade-off without touching the search.
      const o = options || {};
      this.wPartner = o.wPartner != null ? o.wPartner : W_PARTNER;
      this.wOpponent = o.wOpponent != null ? o.wOpponent : W_OPPONENT;
      this.wRecent = o.wRecent != null ? o.wRecent : W_RECENT;
      this.restarts = o.restarts != null ? o.restarts : RESTARTS;

      // Partnerships and oppositions are counted separately: they answer
      // different questions and conflating them made the chooser treat a
      // frequent opponent as a worn-out partner.
      this.partnerCount = new Map();
      this.opponentCount = new Map();

      this.gamesPlayed = {};
      this.restCount = {};
      this.lastRestRound = {};
      this.lastRoundPartners = new Set();
      this.restingPlayersByRound = {};
      this.totalPossiblePairs = (this.players.length * (this.players.length - 1)) / 2;

      for (const p of this.players) {
        this.gamesPlayed[p] = 0;
        this.restCount[p] = 0;
        this.lastRestRound[p] = -1;
      }
    }

    _pc(k) { return this.partnerCount.get(k) || 0; }
    _oc(k) { return this.opponentCount.get(k) || 0; }
    _rand() { return this.rng.nextDouble(); }

    /** How many courts this group can actually fill. */
    _courtsInUse() {
      const seats = this.numberOfCourts * 4;
      const playing = Math.min(this.players.length, seats - (seats % 4));
      return Math.floor(playing / 4);
    }

    /** What it costs for these two to partner again. */
    _partnerCost(a, b) {
      const k = pairKey(a, b);
      let c = this.wPartner * this._pc(k) ** 2;
      if (this.lastRoundPartners.has(k)) c += this.wRecent;
      return c;
    }

    /** What it costs for these two teams to meet. */
    _opponentCost(t1, t2) {
      let c = 0;
      for (const a of t1) {
        for (const b of t2) c += this.wOpponent * this._oc(pairKey(a, b)) ** 2;
      }
      return c;
    }

    /**
     * Stage 1 — pair the pool into teams, preferring partnerships that have
     * happened least. This is a matching problem, so it is solved as one:
     * randomised greedy seeds refined by swapping partners between two teams.
     * Attacking partnerships directly is what lets a complete rotation
     * actually complete, which a positional hill-climb kept missing.
     */
    _matchPartners(pool) {
      // A plain shuffled pass, repeated from _optimiseRound. Deterministic
      // orderings (such as most-constrained-first) were measurably worse here:
      // they collapse the variety between restarts, and the variety is what
      // finds a clean round.
      const order = shuffleWith(pool, () => this._rand());
      const used = new Set();
      const teams = [];
      for (const p of order) {
        if (used.has(p)) continue;
        used.add(p);
        let pick = null;
        let pickCost = Infinity;
        for (const q of order) {
          if (q === p || used.has(q)) continue;
          const c = this._partnerCost(p, q) + this._rand() * 1e-3;
          if (c < pickCost) { pickCost = c; pick = q; }
        }
        if (pick === null) break; // odd pool; cannot happen with 4c players
        used.add(pick);
        teams.push([p, pick]);
      }

      let improved = true;
      let passes = 0;
      while (improved && passes++ < 20) {
        improved = false;
        for (let i = 0; i < teams.length; i++) {
          for (let j = i + 1; j < teams.length; j++) {
            const [a, b] = teams[i];
            const [c, d] = teams[j];
            const cur = this._partnerCost(a, b) + this._partnerCost(c, d);
            const alt1 = this._partnerCost(a, c) + this._partnerCost(b, d);
            const alt2 = this._partnerCost(a, d) + this._partnerCost(b, c);
            if (alt1 < cur - 1e-9 && alt1 <= alt2) {
              teams[i] = [a, c]; teams[j] = [b, d]; improved = true;
            } else if (alt2 < cur - 1e-9) {
              teams[i] = [a, d]; teams[j] = [b, c]; improved = true;
            }
          }
        }
      }
      return teams;
    }

    /**
     * Stage 2 — put the teams onto courts, two per court, so that repeat
     * opponents are spread as evenly as possible. With at most five courts
     * this is small enough to solve exactly.
     */
    _pairTeamsIntoCourts(teams) {
      if (teams.length === 2) return [{ team1: teams[0], team2: teams[1] }];

      if (teams.length <= 12) {
        let bestPairs = null;
        let bestCost = Infinity;
        const search = (remaining, acc, cost) => {
          if (cost >= bestCost) return; // prune
          if (remaining.length === 0) { bestCost = cost; bestPairs = acc.slice(); return; }
          const a = remaining[0];
          for (let i = 1; i < remaining.length; i++) {
            const b = remaining[i];
            const rest = remaining.filter((_, k) => k !== 0 && k !== i);
            acc.push({ team1: a, team2: b });
            search(rest, acc, cost + this._opponentCost(a, b));
            acc.pop();
          }
        };
        search(teams, [], 0);
        return bestPairs;
      }

      // Greedy fallback for unusually large court counts.
      const pool = teams.slice();
      const out = [];
      while (pool.length > 1) {
        const a = pool.shift();
        let bi = 0;
        let bc = Infinity;
        for (let i = 0; i < pool.length; i++) {
          const c = this._opponentCost(a, pool[i]);
          if (c < bc) { bc = c; bi = i; }
        }
        out.push({ team1: a, team2: pool.splice(bi, 1)[0] });
      }
      return out;
    }

    /**
     * Try several partner matchings and keep the one whose *finished* round is
     * cheapest — partnerships and opponents judged together. Scoring only the
     * matching would hand stage 2 a set of teams it cannot pair up well.
     */
    _optimiseRound(pool) {
      let best = null;
      let bestCost = Infinity;
      for (let r = 0; r < this.restarts; r++) {
        const teams = this._matchPartners(pool);
        const pairs = this._pairTeamsIntoCourts(teams);
        let cost = 0;
        for (const t of teams) cost += this._partnerCost(t[0], t[1]);
        for (const p of pairs) cost += this._opponentCost(p.team1, p.team2);
        if (cost < bestCost) {
          bestCost = cost;
          best = pairs;
          if (cost === 0) break; // nothing repeats at all
        }
      }
      return best;
    }

    /** Choose who sits out: level the totals first, then who waited longest. */
    _chooseResters(count, round) {
      if (count <= 0) return [];
      const ordered = shuffleWith(this.players, () => this._rand()).sort((a, b) => {
        if (this.restCount[a] !== this.restCount[b]) return this.restCount[a] - this.restCount[b];
        if (this.lastRestRound[a] !== this.lastRestRound[b]) return this.lastRestRound[a] - this.lastRestRound[b];
        return this.gamesPlayed[b] - this.gamesPlayed[a];
      });
      return ordered.slice(0, count);
    }

    _commit(split, round, court) {
      const p1 = pairKey(split.team1[0], split.team1[1]);
      const p2 = pairKey(split.team2[0], split.team2[1]);
      this.partnerCount.set(p1, this._pc(p1) + 1);
      this.partnerCount.set(p2, this._pc(p2) + 1);
      for (const a of split.team1) {
        for (const b of split.team2) {
          const k = pairKey(a, b);
          this.opponentCount.set(k, this._oc(k) + 1);
        }
      }
      for (const p of [...split.team1, ...split.team2]) this.gamesPlayed[p] += 1;
      return {
        id: uuid(),
        round,
        court,
        team1: { player1: split.team1[0], player2: split.team1[1] },
        team2: { player1: split.team2[0], player2: split.team2[1] },
        team1Score: 0,
        team2Score: 0,
        winningTeam: null,
      };
    }

    _generateRound(round) {
      const courts = this._courtsInUse();
      const playing = courts * 4;

      const resting = this._chooseResters(this.players.length - playing, round);
      const restingSet = new Set(resting);
      for (const p of resting) {
        this.restCount[p] += 1;
        this.lastRestRound[p] = round;
      }
      const pool = this.players.filter((p) => !restingSet.has(p));

      const courtsForRound = this._optimiseRound(pool);
      const matches = [];
      const partnersThisRound = new Set();
      courtsForRound.forEach((split, i) => {
        matches.push(this._commit(split, round, i + 1));
        partnersThisRound.add(pairKey(split.team1[0], split.team1[1]));
        partnersThisRound.add(pairKey(split.team2[0], split.team2[1]));
      });
      this.lastRoundPartners = partnersThisRound;
      return { matches, resting };
    }

    generateSchedule() {
      if (this.players.length < 4) return null;
      if (this.numberOfCourts < 1) return null;

      let schedule = [];
      this.restingPlayersByRound = {};
      this.partnerCount = new Map();
      this.opponentCount = new Map();
      this.lastRoundPartners = new Set();
      for (const p of this.players) {
        this.gamesPlayed[p] = 0;
        this.restCount[p] = 0;
        this.lastRestRound[p] = -1;
      }

      for (let round = 0; round < this.numberOfRounds; round++) {
        const { matches, resting } = this._generateRound(round);
        schedule = schedule.concat(matches);
        this.restingPlayersByRound[round] = resting;
      }
      return { schedule, restingByRound: this.restingPlayersByRound };
    }

    /** Rebuild counters from a schedule so an added round continues fairly. */
    _replay(existingSchedule) {
      const byRound = new Map();
      for (const m of existingSchedule) {
        if (!byRound.has(m.round)) byRound.set(m.round, []);
        byRound.get(m.round).push(m);
        const p1 = pairKey(m.team1.player1, m.team1.player2);
        const p2 = pairKey(m.team2.player1, m.team2.player2);
        this.partnerCount.set(p1, this._pc(p1) + 1);
        this.partnerCount.set(p2, this._pc(p2) + 1);
        for (const a of [m.team1.player1, m.team1.player2]) {
          for (const b of [m.team2.player1, m.team2.player2]) {
            const k = pairKey(a, b);
            this.opponentCount.set(k, this._oc(k) + 1);
          }
        }
        for (const p of [m.team1.player1, m.team1.player2, m.team2.player1, m.team2.player2]) {
          if (this.gamesPlayed[p] !== undefined) this.gamesPlayed[p] += 1;
        }
      }
      // Anyone absent from a round was sitting it out.
      const rounds = [...byRound.keys()].sort((a, b) => a - b);
      for (const r of rounds) {
        const played = new Set();
        for (const m of byRound.get(r)) {
          played.add(m.team1.player1); played.add(m.team1.player2);
          played.add(m.team2.player1); played.add(m.team2.player2);
        }
        for (const p of this.players) {
          if (!played.has(p)) {
            this.restCount[p] += 1;
            this.lastRestRound[p] = r;
          }
        }
      }
      const last = rounds.length ? rounds[rounds.length - 1] : null;
      this.lastRoundPartners = new Set();
      if (last !== null) {
        for (const m of byRound.get(last)) {
          this.lastRoundPartners.add(pairKey(m.team1.player1, m.team1.player2));
          this.lastRoundPartners.add(pairKey(m.team2.player1, m.team2.player2));
        }
      }
    }

    generateAdditionalRound(existingSchedule) {
      if (this.players.length < 4) return null;
      const newRound = (existingSchedule.length ? existingSchedule[existingSchedule.length - 1].round : -1) + 1;
      this.numberOfRounds += 1;

      this.partnerCount = new Map();
      this.opponentCount = new Map();
      for (const p of this.players) {
        this.gamesPlayed[p] = 0;
        this.restCount[p] = 0;
        this.lastRestRound[p] = -1;
      }
      this._replay(existingSchedule);

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

  const SORT_ORDERS = ["name", "score", "diff", "wins", "losses", "rests"];

  function sortLeaderboard(statsMap, sortOrder) {
    const entries = Object.values(statsMap).filter((s) => s.name && s.name.trim() !== "");
    entries.sort((a, b) => {
      switch (sortOrder) {
        case "name":
          return a.name.toLowerCase().localeCompare(b.name.toLowerCase());
        // Points difference on its own — distinct from "score", which ranks by
        // wins first and only uses difference to break ties.
        case "diff":
          return b.pointDifferential - a.pointDifferential || b.wins - a.wins;
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
