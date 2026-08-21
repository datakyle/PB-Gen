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
  // Perfect schedules (whist tournaments)
  //
  // For these group sizes a schedule exists in which every pair partners
  // exactly once and opposes exactly twice — precisely what an Americano is
  // reaching for. The tables were constructed offline (cyclic development,
  // plus a direct search for 9, which admits no cyclic base) and each was
  // verified against both conditions before being encoded here.
  //
  // Encoding: one character per player index in base 36; each group of four
  // characters is one game, as team1 then team2.
  // ==========================================================================
  const WHIST = {
    5: "14232034314042010312",
    8: "70132645712430567235416073465201745063127561042376021534",
    9: "123456780257364801683745045816270367182506241738051328470823154607142635",
    12: "b01329674a58b1243a785069b2354089617ab346519a7280b45762a08391b568730194a2b6798412a503b78a95230614b890a6341725b9a107452836ba0218563947",
    13: "14273c865b9a253840976cab364951a870bc475a62b981c0586b73ca9201697c840ba3127a80951cb4238b91a620c5349ca2b7310645a0b3c8421756b1c409532867c2051a64397803162b754a89",
    16: "f012369b4dc85ae7f12347ac5ed96b08f23458bd60ea7c19f34569ce710b8d2af4567ad0821c9e3bf5678be1932da04cf6789c02a43eb15df789ad13b540c26ef89abe24c651d370f9abc035d762e481fabcd146e8730592fbcde257098416a3fcde03681a9527b4fde014792ba638c5fe01258a3cb749d6",
    17: "12384fca596d7gbe23495gdb6a7e80cf345a60ec7b8f91dg456b71fd8c9ga2e0567c82ge9da0b3f1678d930faeb1c4g2789ea41gbfc2d50389afb520cgd3e6149abgc631d0e4f725abc0d742e1f5g836bcd1e853f2g60947cde2f964g3071a58def3ga7504182b69efg40b8615293c7afg051c97263a4d8bg0162da8374b5e9c01273eb9485c6fad",
    20: "j012359f4ech6iad7b8gj12346ag5fdi70be8c9hj23457bh6ge081cf9daij34568ci7hf192dgaeb0j45679d08ig2a3ehbfc1j5678ae190h3b4ficgd2j6789bf2a1i4c5g0dhe3j789acg3b205d6h1eif4j89abdh4c316e7i2f0g5j9abcei5d427f803g1h6jabcdf06e538g914h2i7jbcdeg17f649ha25i308jcdefh28g75aib360419jdefgi39h86b0c47152ajefgh04ai97c1d58263bjfghi15b0a8d2e69374cjghi026c1b9e3f7a485djhi0137d2caf4g8b596eji01248e3dbg5h9c6a7f",
    21: "12364dcj5i8e7hfa9bkg23475edk6j9f8igbac0h34586fe07kag9jhcbd1i45697gf180bhakidce2j567a8hg291cib0jedf3k678b9ih3a2djc1kfeg40789caji4b3ekd20gfh5189adbkj5c4f0e31hgi629abec0k6d5g1f42ihj73abcfd107e6h2g53jik84bcdge218f7i3h64kj095cdehf329g8j4i750k1a6defig43ah9k5j86102b7efgjh54bia06k97213c8fghki65cjb170a8324d9ghi0j76dkc281b9435eahij1k87e0d392ca546fbijk2098f1e4a3db657gcjk031a9g2f5b4ec768hdk0142bah3g6c5fd879ie01253cbi4h7d6ge98ajf",
  };

  function whistRounds(v) {
    const s = WHIST[v];
    if (!s) return null;
    const gamesPerRound = Math.floor(v / 4);
    const stride = gamesPerRound * 4;
    const rounds = [];
    for (let i = 0; i < s.length; i += stride) {
      const games = [];
      for (let g = 0; g < gamesPerRound; g++) {
        const o = i + g * 4;
        games.push([
          [parseInt(s[o], 36), parseInt(s[o + 1], 36)],
          [parseInt(s[o + 2], 36), parseInt(s[o + 3], 36)],
        ]);
      }
      rounds.push(games);
    }
    return rounds;
  }

  /** Rounds needed for everyone to partner everyone, or null if impossible. */
  function roundsForFullRotation(playerCount, courts) {
    const seats = courts * 4;
    const playing = Math.min(playerCount, seats - (seats % 4));
    const inUse = Math.floor(playing / 4);
    if (inUse < 1) return null;
    return Math.ceil((playerCount * (playerCount - 1)) / 2 / (2 * inUse));
  }

  /**
   * How evenly the draw worked out, once player strengths are known: the gap
   * between the luckiest and unluckiest player's average partner, and how
   * lopsided the average match was.
   */
  function strengthStats(players, schedule, strength) {
    if (!strength) return {};
    const vals = players.map((p) => (strength[p] != null ? strength[p] : 0));
    const mean = vals.reduce((a, b) => a + b, 0) / (vals.length || 1);
    const sd = Math.sqrt(vals.reduce((a, b) => a + (b - mean) ** 2, 0) / (vals.length || 1));
    if (sd <= 1e-9) return {};
    const z = {};
    players.forEach((p, i) => { z[p] = (vals[i] - mean) / sd; });

    const sum = {}, count = {};
    players.forEach((p) => { sum[p] = 0; count[p] = 0; });
    let gapTotal = 0, games = 0;
    for (const m of schedule) {
      const t1 = [m.team1.player1, m.team1.player2], t2 = [m.team2.player1, m.team2.player2];
      sum[t1[0]] += z[t1[1]]; count[t1[0]]++; sum[t1[1]] += z[t1[0]]; count[t1[1]]++;
      sum[t2[0]] += z[t2[1]]; count[t2[0]]++; sum[t2[1]] += z[t2[0]]; count[t2[1]]++;
      gapTotal += Math.abs((z[t1[0]] + z[t1[1]]) - (z[t2[0]] + z[t2[1]]));
      games++;
    }
    const avg = players.filter((p) => count[p]).map((p) => sum[p] / count[p]);
    if (!avg.length) return {};
    return {
      partnerLuckSpread: Math.max(...avg) - Math.min(...avg),
      averageTeamGap: games ? gapTotal / games : 0,
    };
  }

  /** What a finished schedule actually delivers. */
  function analyzeSchedule(players, schedule, restingByRound, availability, strength) {
    const partner = new Map(), oppose = new Map();
    const games = {}, rests = {};
    for (const p of players) { games[p] = 0; rests[p] = 0; }
    const roundSet = new Set();
    for (const m of schedule) {
      roundSet.add(m.round);
      const t1 = [m.team1.player1, m.team1.player2];
      const t2 = [m.team2.player1, m.team2.player2];
      const k1 = pairKey(t1[0], t1[1]), k2 = pairKey(t2[0], t2[1]);
      partner.set(k1, (partner.get(k1) || 0) + 1);
      partner.set(k2, (partner.get(k2) || 0) + 1);
      for (const a of t1) for (const b of t2) {
        const k = pairKey(a, b);
        oppose.set(k, (oppose.get(k) || 0) + 1);
      }
      for (const p of [...t1, ...t2]) if (games[p] !== undefined) games[p]++;
    }
    if (restingByRound) {
      for (const r of Object.keys(restingByRound)) {
        for (const p of restingByRound[r]) if (rests[p] !== undefined) rests[p]++;
      }
    }
    const n = players.length;
    const totalPairs = (n * (n - 1)) / 2;
    const pv = [...partner.values()], ov = [...oppose.values()];
    const gv = Object.values(games), rv = Object.values(rests);
    return {
      rounds: roundSet.size,
      totalPairs,
      partnered: partner.size,
      partnerCoverage: totalPairs ? partner.size / totalPairs : 0,
      partnerMax: pv.length ? Math.max(...pv) : 0,
      opponentMax: ov.length ? Math.max(...ov) : 0,
      opponentMin: ov.length ? Math.min(...ov) : 0,
      gamesMin: gv.length ? Math.min(...gv) : 0,
      gamesMax: gv.length ? Math.max(...gv) : 0,
      gamesSpread: gv.length ? Math.max(...gv) - Math.min(...gv) : 0,
      restSpread: rv.length ? Math.max(...rv) - Math.min(...rv) : 0,
      restMax: rv.length ? Math.max(...rv) : 0,
      // A complete rotation: everyone partnered everyone, nobody twice.
      perfectRotation: partner.size === totalPairs && pv.every((c) => c === 1),
      // With people arriving late or leaving early, a games-played range is
      // expected rather than unfair, so say which case this is.
      partialAttendance: !!availability && Object.keys(availability).length > 0,
      ...strengthStats(players, schedule, strength),
    };
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
  const W_BALANCE = 45;    // strength-fairness weight, subordinate to repeats
  const AVOID_COST = 1e7;   // effectively a ban, without making rounds impossible


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

      // Advanced constraints. Locked pairs always partner when both are on;
      // avoided pairs never partner unless there is no legal alternative.
      this.lockedPairs = (o.lockedPairs || []).map(([a, b]) => pairKey(a, b));
      this.avoidSet = new Set((o.avoidPairs || []).map(([a, b]) => pairKey(a, b)));

      // Availability windows, as { name: { from, to } } with zero-based,
      // inclusive round numbers. Absent means present for the whole session.
      // Someone who has not arrived yet is not "resting" — they are away, and
      // must not be counted against anyone's share of sit-outs.
      this.availability = o.availability || null;

      // Optional strength-aware fairness. Strengths are z-scored on the way in
      // so the weights below mean the same thing whatever scale they arrive on
      // (hand-set levels, or point difference earned so far).
      this.balanceMode = o.balanceMode || null;   // "fair" | "close" | null
      this.wBalance = o.wBalance != null ? o.wBalance : W_BALANCE;
      this.strength = null;
      if (this.balanceMode && o.strength) {
        const vals = this.players.map((p) => (o.strength[p] != null ? o.strength[p] : 0));
        const mean = vals.reduce((a, b) => a + b, 0) / (vals.length || 1);
        const varr = vals.reduce((a, b) => a + (b - mean) ** 2, 0) / (vals.length || 1);
        const sd = Math.sqrt(varr);
        this.strength = {};
        this.players.forEach((p, i) => {
          this.strength[p] = sd > 1e-9 ? (vals[i] - mean) / sd : 0;
        });
        // Everyone identical means there is nothing to balance.
        if (sd <= 1e-9) { this.strength = null; this.balanceMode = null; }
      }
      // Running total of the strength of each player's partners so far.
      this.partnerStrengthSum = {};
      for (const p of this.players) this.partnerStrengthSum[p] = 0;

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

    /** How many courts a group of this size can actually fill. */
    _courtsFor(count) {
      const seats = this.numberOfCourts * 4;
      const playing = Math.min(count, seats - (seats % 4));
      return Math.floor(playing / 4);
    }

    _courtsInUse() {
      return this._courtsFor(this.players.length);
    }

    /** Who is actually here for this round. */
    _availableAt(round) {
      if (!this.availability) return this.players;
      return this.players.filter((p) => {
        const a = this.availability[p];
        if (!a) return true;
        if (a.from != null && round < a.from) return false;
        if (a.to != null && round > a.to) return false;
        return true;
      });
    }

    /** What it costs for these two to partner again. */
    _partnerCost(a, b) {
      const k = pairKey(a, b);
      // Priced rather than forbidden, so a round is always possible even if
      // the constraints cannot all be honoured at once.
      if (this.avoidSet.has(k)) return AVOID_COST;
      let c = this.wPartner * this._pc(k) ** 2;
      if (this.lastRoundPartners.has(k)) c += this.wRecent;

      if (this.strength) {
        const sa = this.strength[a], sb = this.strength[b];
        if (this.balanceMode === "fair") {
          // Even out the draw: push everyone's cumulative partner strength
          // toward average, so nobody is repeatedly carried or repeatedly sunk.
          c += this.wBalance * (
            (this.partnerStrengthSum[a] + sb) ** 2 +
            (this.partnerStrengthSum[b] + sa) ** 2
          );
        } else if (this.balanceMode === "close") {
          // Even out the teams: a strong player pairs with a weak one, so
          // every team lands near the same strength and games stay close.
          c += this.wBalance * ((sa + sb) ** 2);
        }
      }
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

      // Locked pairs are seated first so the rest is matched around them.
      if (this.lockedPairs.length) {
        const inPool = new Set(pool);
        for (const k of this.lockedPairs) {
          const [a, b] = k.split("|");
          if (inPool.has(a) && inPool.has(b) && !used.has(a) && !used.has(b)) {
            used.add(a); used.add(b);
            teams.push([a, b]);
          }
        }
      }

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

      const locked = new Set(this.lockedPairs);
      let improved = true;
      let passes = 0;
      while (improved && passes++ < 20) {
        improved = false;
        for (let i = 0; i < teams.length; i++) {
          for (let j = i + 1; j < teams.length; j++) {
            const [a, b] = teams[i];
            const [c, d] = teams[j];
            // never pull apart a pair the organiser locked together
            if (locked.has(pairKey(a, b)) || locked.has(pairKey(c, d))) continue;
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
    _chooseResters(candidates, count, round) {
      if (count <= 0) return [];
      const ordered = shuffleWith(candidates, () => this._rand()).sort((a, b) => {
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
      if (this.strength) {
        this.partnerStrengthSum[split.team1[0]] += this.strength[split.team1[1]];
        this.partnerStrengthSum[split.team1[1]] += this.strength[split.team1[0]];
        this.partnerStrengthSum[split.team2[0]] += this.strength[split.team2[1]];
        this.partnerStrengthSum[split.team2[1]] += this.strength[split.team2[0]];
      }
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

    /**
     * The perfect table for this group, if one applies. It requires every
     * game of a round to run at once, so it only fits when the group has
     * enough courts; otherwise the search takes over.
     */
    _whistPlan() {
      const v = this.players.length;
      const rounds = whistRounds(v);
      if (!rounds) return null;
      if (this._courtsInUse() !== Math.floor(v / 4)) return null;
      // A fixed table cannot honour locked or avoided pairs, and a custom
      // mixing preference is a request the table cannot answer either.
      if (this.lockedPairs.length || this.avoidSet.size) return null;
      // The tables assume everyone is present for every round.
      if (this.availability) return null;
      if (this.balanceMode) return null;
      if (this.wPartner !== W_PARTNER || this.wOpponent !== W_OPPONENT) return null;
      const seat = shuffleWith(this.players, () => this._rand());
      return rounds.map((games) =>
        games.map(([t1, t2]) => ({
          team1: [seat[t1[0]], seat[t1[1]]],
          team2: [seat[t2[0]], seat[t2[1]]],
        }))
      );
    }

    _roundFromPlan(games, round) {
      const playing = new Set();
      const matches = [];
      const partnersThisRound = new Set();
      games.forEach((g, i) => {
        for (const p of [...g.team1, ...g.team2]) playing.add(p);
        matches.push(this._commit(g, round, i + 1));
        partnersThisRound.add(pairKey(g.team1[0], g.team1[1]));
        partnersThisRound.add(pairKey(g.team2[0], g.team2[1]));
      });
      const resting = this.players.filter((p) => !playing.has(p));
      for (const p of resting) {
        this.restCount[p] += 1;
        this.lastRestRound[p] = round;
      }
      this.lastRoundPartners = partnersThisRound;
      return { matches, resting };
    }

    _generateRound(round) {
      const here = this._availableAt(round);
      const courts = this._courtsFor(here.length);

      // Too few people present to fill even one court.
      if (courts < 1) {
        this.lastRoundPartners = new Set();
        return { matches: [], resting: here.slice(), away: this._awayAt(round) };
      }

      const playing = courts * 4;
      const resting = this._chooseResters(here, here.length - playing, round);
      const restingSet = new Set(resting);
      for (const p of resting) {
        this.restCount[p] += 1;
        this.lastRestRound[p] = round;
      }
      const pool = here.filter((p) => !restingSet.has(p));

      const courtsForRound = this._optimiseRound(pool);
      const matches = [];
      const partnersThisRound = new Set();
      courtsForRound.forEach((split, i) => {
        matches.push(this._commit(split, round, i + 1));
        partnersThisRound.add(pairKey(split.team1[0], split.team1[1]));
        partnersThisRound.add(pairKey(split.team2[0], split.team2[1]));
      });
      this.lastRoundPartners = partnersThisRound;
      return { matches, resting, away: this._awayAt(round) };
    }

    /** Players not present for this round at all. */
    _awayAt(round) {
      if (!this.availability) return [];
      const here = new Set(this._availableAt(round));
      return this.players.filter((p) => !here.has(p));
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
        this.partnerStrengthSum[p] = 0;
      }

      // Use the perfect table where one exists, and let the search carry on
      // past the end of it if more rounds were asked for.
      const plan = this._whistPlan();
      this.usedPerfectTable = false;

      this.awayByRound = {};
      for (let round = 0; round < this.numberOfRounds; round++) {
        const fromPlan = plan && round < plan.length;
        const { matches, resting, away } = fromPlan
          ? this._roundFromPlan(plan[round], round)
          : this._generateRound(round);
        if (fromPlan) this.usedPerfectTable = true;
        schedule = schedule.concat(matches);
        this.restingPlayersByRound[round] = resting;
        if (away && away.length) this.awayByRound[round] = away;
      }
      return {
        schedule,
        restingByRound: this.restingPlayersByRound,
        awayByRound: this.awayByRound,
      };
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
        if (this.strength) {
          const add = (x, y) => {
            if (this.partnerStrengthSum[x] !== undefined && this.strength[y] !== undefined) {
              this.partnerStrengthSum[x] += this.strength[y];
            }
          };
          add(m.team1.player1, m.team1.player2); add(m.team1.player2, m.team1.player1);
          add(m.team2.player1, m.team2.player2); add(m.team2.player2, m.team2.player1);
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
        const hereThisRound = new Set(this._availableAt(r));
        for (const p of this.players) {
          // Away is not the same as resting, so only count people who were here.
          if (!played.has(p) && hereThisRound.has(p)) {
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

    /**
     * Rebuild only the rounds that have not been played.
     *
     * Rounds up to and including `keepThrough` are replayed to restore the
     * fairness state, then everything after is generated afresh. Nothing that
     * has already happened is touched, so recorded scores survive — which is
     * what makes this safe to run mid-session.
     */
    generateRemaining(existingSchedule, keepThrough) {
      if (this.players.length < 4) return null;
      if (this.numberOfCourts < 1) return null;

      this.partnerCount = new Map();
      this.opponentCount = new Map();
      this.lastRoundPartners = new Set();
      this.restingPlayersByRound = {};
      this.awayByRound = {};
      for (const p of this.players) {
        this.gamesPlayed[p] = 0;
        this.restCount[p] = 0;
        this.lastRestRound[p] = -1;
        this.partnerStrengthSum[p] = 0;
      }

      const kept = existingSchedule.filter((m) => m.round <= keepThrough);
      this._replay(kept);

      let fresh = [];
      for (let round = keepThrough + 1; round < this.numberOfRounds; round++) {
        const { matches, resting, away } = this._generateRound(round);
        fresh = fresh.concat(matches);
        this.restingPlayersByRound[round] = resting;
        if (away && away.length) this.awayByRound[round] = away;
      }
      return {
        schedule: fresh,
        restingByRound: this.restingPlayersByRound,
        awayByRound: this.awayByRound,
        keptThrough: keepThrough,
      };
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
        this.partnerStrengthSum[p] = 0;
      }
      this._replay(existingSchedule);

      const { matches, resting, away } = this._generateRound(newRound);
      if (matches.length === 0) {
        this.numberOfRounds -= 1;
        return null;
      }
      this.restingPlayersByRound[newRound] = resting;
      return { matches, resting, away: away || [] };
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
    analyzeSchedule,
    roundsForFullRotation,
    hasPerfectTable: (n) => !!WHIST[n],
    _internals: { pairKey, uniqueNonEmpty, sortByPredicate, whistRounds },
  };
});
