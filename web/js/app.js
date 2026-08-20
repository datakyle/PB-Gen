/*
 * app.js — PB Gen web UI controller (vanilla JS, no build step).
 *
 * Screens: Start → Setup → Play / Standings.
 * Setup is a step you pass through once, not a permanent tab, so the two
 * things you use during a session (Play, Standings) are the only tabs.
 */
(function () {
  "use strict";

  const E = window.Engine;
  const Store = window.Store;
  const appEl = document.getElementById("app");
  const sheetHost = document.getElementById("sheet-host");
  const toastEl = document.getElementById("toast");

  const LIMITS = {
    minPlayers: 4, minRounds: 1, maxRounds: 10, minCourts: 1, maxCourts: 5,
    pointsPerWin: 1, maxScore: 30,
    minTarget: 7, maxTarget: 21, defaultTarget: 11,
  };
  const MINUTES_PER_ROUND = 12; // rough, for the plan estimate

  // ------------------------------------------------------------------ icons
  const P = {
    back: '<path d="M15 5l-7 7 7 7"/>',
    fwd: '<path d="M9 5l7 7-7 7"/>',
    trophy: '<path d="M7 4h10v3a5 5 0 0 1-10 0V4z"/><path d="M7 6H4v1a3 3 0 0 0 3 3M17 6h3v1a3 3 0 0 1-3 3M9 15h6M8 20h8M12 15v5"/>',
    people: '<circle cx="9" cy="8" r="3"/><path d="M3 20a6 6 0 0 1 12 0"/><path d="M16 6a3 3 0 0 1 0 6M21 20a6 6 0 0 0-5-5.9"/>',
    gear: '<circle cx="12" cy="12" r="3.2"/><path d="M12 3v2.5M12 18.5V21M4.5 4.5l1.8 1.8M17.7 17.7l1.8 1.8M3 12h2.5M18.5 12H21M4.5 19.5l1.8-1.8M17.7 6.3l1.8-1.8"/>',
    calplus: '<rect x="3.5" y="5" width="17" height="15" rx="2.5"/><path d="M3.5 9h17M8 3v4M16 3v4M12 12v5M9.5 14.5h5"/>',
    plus: '<circle cx="12" cy="12" r="9"/><path d="M12 8v8M8 12h8"/>',
    folder: '<path d="M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>',
    warn: '<path d="M12 3l9 16H3z"/><path d="M12 10v4M12 17h.01"/>',
    minus: '<circle cx="12" cy="12" r="9"/><path d="M8 12h8"/>',
    personadd: '<circle cx="9" cy="8" r="3.2"/><path d="M3 20a6 6 0 0 1 11 0"/><path d="M18 8v6M15 11h6"/>',
    chevd: '<path d="M6 9l6 6 6-6"/>',
    chevr: '<path d="M9 6l6 6-6 6"/>',
    check: '<circle cx="12" cy="12" r="9"/><path d="M8 12.5l2.5 2.5 5-5.5"/>',
    seat: '<path d="M5 11V6a1 1 0 0 1 2 0v5M17 11h2a1 1 0 0 1 1 1v3M5 11h11a1 1 0 0 1 1 1v3M6 15v4M18 15v4"/>',
    medal: '<circle cx="12" cy="14" r="5"/><path d="M9 9L6 3M15 9l3-6M10.5 14l1.5-1 1.5 1-.6 2 .6 2-1.5-1-1.5 1 .6-2z"/>',
    person: '<circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/>',
    refresh: '<path d="M4 12a8 8 0 0 1 13.7-5.6L20 8M20 4v4h-4"/><path d="M20 12a8 8 0 0 1-13.7 5.6L4 16M4 20v-4h4"/>',
    trash: '<path d="M4 7h16M9 7V5a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2M6 7l1 13a1 1 0 0 0 1 1h8a1 1 0 0 0 1-1l1-13"/>',
    x: '<path d="M6 6l12 12M18 6L6 18"/>',
    dropdown: '<circle cx="12" cy="12" r="9"/><path d="M8.5 11l3.5 3 3.5-3"/>',
    spinner: '<path d="M12 3a9 9 0 1 0 9 9" fill="none"/>',
    cal: '<rect x="3.5" y="5" width="17" height="15" rx="2.5"/><path d="M3.5 9.5h17M8 3v4M16 3v4"/>',
    chart: '<path d="M5 20V11M12 20V4M19 20v-6"/>',
    pencil: '<path d="M4 20h4L19 9a2.1 2.1 0 0 0-3-3L5 17v3z"/><path d="M14.5 6.5l3 3"/>',
    info: '<circle cx="12" cy="12" r="9"/><path d="M12 11v5M12 8h.01"/>',
    pball: '<circle cx="12" cy="12" r="9"/><circle cx="9.5" cy="9" r="1.1" fill="currentColor" stroke="none"/><circle cx="14.5" cy="9" r="1.1" fill="currentColor" stroke="none"/><circle cx="9.5" cy="13.5" r="1.1" fill="currentColor" stroke="none"/><circle cx="14.5" cy="13.5" r="1.1" fill="currentColor" stroke="none"/><circle cx="12" cy="16.5" r="1.1" fill="currentColor" stroke="none"/>',
  };
  function icon(name, cls) {
    return `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"${cls ? ` class="${cls}"` : ""}>${P[name] || ""}</svg>`;
  }

  // ------------------------------------------------------------------ utils
  function esc(s) {
    return String(s == null ? "" : s).replace(/[&<>"']/g, (c) =>
      ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
  }
  let toastTimer = null;
  function toast(msg) {
    toastEl.textContent = msg;
    toastEl.hidden = false;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => (toastEl.hidden = true), 2400);
  }
  function closeSheet() { sheetHost.hidden = true; sheetHost.innerHTML = ""; }
  function openSheet(html) {
    sheetHost.innerHTML = `<div class="sheet" role="dialog" aria-modal="true">${html}</div>`;
    sheetHost.hidden = false;
    sheetHost.onclick = (e) => { if (e.target === sheetHost) closeSheet(); };
    // Wire the freshly-injected sheet controls (render()/wire() don't cover
    // on-demand sheets because they're empty at render time).
    sheetHost.querySelectorAll("[data-act]").forEach((n) => {
      n.addEventListener("click", onAction);
      n.addEventListener("keydown", (e) => {
        if ((e.key === "Enter" || e.key === " ") && n.getAttribute("role") === "button") { e.preventDefault(); onAction(e); }
      });
    });
  }

  // ------------------------------------------------------------------ state
  const state = {
    view: "start", // start | saved | setup | main
    tab: 0,        // 0 = Play, 1 = Standings
    t: null,       // current tournament record
    editingSaved: false,
    expanded: new Set(),
    sort: "score",
    addingRound: false,
    addRoundError: null,
    awaiting: null, // { id, team } — winner tapped, waiting on the other score
  };

  // ------------------------------------------------------------- tournament
  function nonEmpty(players) { return players.filter((p) => p.trim() !== ""); }
  function duplicates(players) {
    const seen = {}, dup = new Set();
    for (const p of nonEmpty(players)) {
      const k = p.trim();
      seen[k] = (seen[k] || 0) + 1;
      if (seen[k] > 1) dup.add(k);
    }
    return dup;
  }
  function canGenerate(t) {
    return nonEmpty(t.players).length >= LIMITS.minPlayers && duplicates(t.players).size === 0;
  }
  // A court needs 4 players, so offering more courts than the group can fill
  // would be a control that does nothing.
  function maxCourtsFor(playerCount) {
    return Math.max(1, Math.min(LIMITS.maxCourts, Math.floor(playerCount / 4)));
  }

  function defaultName() {
    const day = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"][new Date().getDay()];
    let base = day + " Session";
    if (!Store.exists(base)) return base;
    for (let i = 2; i < 100; i++) {
      if (!Store.exists(base + " " + i)) return base + " " + i;
    }
    return base;
  }

  function saveCurrent() {
    if (!state.t) return;
    Store.save(state.t);
    Store.setCurrentName(state.t.name);
  }

  function newTournament() {
    state.t = {
      name: defaultName(),
      players: ["", "", "", ""],
      numberOfRounds: 5,
      numberOfCourts: 1,
      pointsTarget: LIMITS.defaultTarget,
      pointsPerWin: LIMITS.pointsPerWin,
      seed: null,
      schedule: [],
      restingByRound: {},
    };
    state.view = "setup";
    render();
  }

  /** Plain-English description of what the current settings will produce. */
  function plan(t) {
    const n = nonEmpty(t.players).length;
    if (n < LIMITS.minPlayers) return null;
    const seats = t.numberOfCourts * 4;
    const playing = Math.min(n, seats - (seats % 4));
    const courtsUsed = Math.floor(playing / 4);
    const sittingOut = n - playing;
    const r = t.numberOfRounds;

    const slots = r * playing;
    const base = Math.floor(slots / n);
    const rem = slots % n;

    let games;
    if (sittingOut === 0) games = `Everyone plays all ${r} ${r === 1 ? "game" : "games"}.`;
    else if (rem === 0) games = `Everyone plays ${base} ${base === 1 ? "game" : "games"} and sits out ${r - base}.`;
    else games = `Everyone plays ${base}–${base + 1} games, taking turns sitting out.`;

    const mins = r * MINUTES_PER_ROUND;
    const time = mins >= 60
      ? `${Math.floor(mins / 60)} hr${mins % 60 ? " " + (mins % 60) + " min" : ""}`
      : `${mins} min`;

    return {
      head: `${r} ${r === 1 ? "round" : "rounds"} · ${n} players · ${courtsUsed} ${courtsUsed === 1 ? "court" : "courts"}`,
      body: `${games} About ${time}.`,
    };
  }

  function generateSchedule() {
    const t = state.t;
    const players = nonEmpty(t.players).map((p) => p.trim());
    const seed = E.makeSeed();
    const scheduler = new E.AmericanoScheduler(players, t.numberOfRounds, t.numberOfCourts, seed);
    const result = scheduler.generateSchedule();
    if (!result) { toast("Could not build a schedule from these players."); return; }
    t.seed = String(seed);
    t.players = players;
    t.schedule = result.schedule;
    t.restingByRound = result.restingByRound;
    const producedRounds = new Set(result.schedule.map((m) => m.round)).size;
    state.expanded = new Set([0]);
    saveCurrent();
    state.view = "main";
    state.tab = 0;
    render();
    if (producedRounds < t.numberOfRounds) {
      toast(`Built ${producedRounds} of ${t.numberOfRounds} rounds — the rest need more players.`);
    }
  }

  function addRound() {
    const t = state.t;
    if (state.addingRound || !t.schedule.length) return;
    state.addingRound = true;
    state.addRoundError = null;
    render();
    setTimeout(() => {
      const scheduler = new E.AmericanoScheduler(t.players, t.numberOfRounds, t.numberOfCourts, BigInt(t.seed || E.makeSeed()));
      const res = scheduler.generateAdditionalRound(t.schedule.slice());
      if (!res) {
        state.addRoundError = "Can't add another round — every fair pairing has been used.";
      } else {
        const newRound = res.matches[0].round;
        t.schedule = t.schedule.concat(res.matches);
        t.restingByRound[newRound] = res.resting;
        t.numberOfRounds = newRound + 1;
        state.expanded.add(newRound);
        saveCurrent();
      }
      state.addingRound = false;
      render();
    }, 60);
  }

  /** Record a finished match: winner scored `winScore`, the other `loseScore`. */
  function commitResult(matchId, winnerTeam, winScore, loseScore) {
    const m = state.t.schedule.find((x) => x.id === matchId);
    if (!m) return;
    if (winnerTeam === 1) { m.team1Score = winScore; m.team2Score = loseScore; }
    else { m.team2Score = winScore; m.team1Score = loseScore; }
    m.winningTeam = m.team1Score === m.team2Score ? null : (m.team1Score > m.team2Score ? 1 : 2);
    state.awaiting = null;
    saveCurrent();
    render();
  }

  /** Clear a recorded result so it can be entered again. */
  function setMatchResult(matchId) {
    const m = state.t.schedule.find((x) => x.id === matchId);
    if (!m) return;
    m.team1Score = 0; m.team2Score = 0; m.winningTeam = null;
    saveCurrent();
    render();
  }

  function leaderboardStats() {
    const t = state.t;
    return E.computeLeaderboard(t.players, t.schedule, t.restingByRound, { pointsPerWin: t.pointsPerWin });
  }

  // ============================================================ RENDER
  function render() {
    if (state.view === "start") appEl.innerHTML = viewStart();
    else if (state.view === "saved") appEl.innerHTML = viewSaved();
    else if (state.view === "setup") appEl.innerHTML = viewSetup();
    else appEl.innerHTML = viewMain();
    wire();
  }

  // ------------------------------------------------------------ START view
  function viewStart() {
    const hasSaved = Store.listTournaments().length > 0;
    return `
    <div class="screen">
      <section class="hero-tile">
        <span class="brand-glyph">${icon("pball")}</span>
        <div class="wordmark-lg">PB GEN</div>
        <div class="hero-tagline">Everyone rotates partners.<br>Best individual record wins.</div>
      </section>

      <div class="start-body">
        <button class="btn btn-primary" data-act="newTournament">New tournament</button>
        ${hasSaved ? `<button class="row-link" data-act="goSaved"><span>Saved tournaments</span>${icon("chevr")}</button>` : ""}
        <button class="row-link" data-act="howItWorks"><span>How Americano works</span>${icon("chevr")}</button>
      </div>
    </div>`;
  }

  // ------------------------------------------------------------ SAVED view
  function viewSaved() {
    const list = Store.listTournaments();
    return `
    <div class="screen">
      <div class="brand-head-sm">
        <button class="round-icon-btn" data-act="backFromSaved" aria-label="Back">${icon("back")}</button>
        <h1>Saved</h1>
        ${list.length ? `<button class="round-icon-btn" data-act="toggleEdit" aria-label="${state.editingSaved ? "Done" : "Edit"}">${state.editingSaved ? icon("check") : icon("trash")}</button>` : `<span style="width:44px"></span>`}
      </div>
      <div class="scroll no-tabbar">
        ${list.length === 0 ? `
          <div class="empty-state">
            ${icon("folder")}
            <h3>Nothing saved yet</h3>
            <p>Tournaments you create are kept on this device.</p>
          </div>` : `
          <div class="saved-list">
            ${list.map((n) => `
              <div class="saved-item" data-act="loadSaved" data-name="${esc(n)}" role="button" tabindex="0">
                <span class="trophy">${icon("trophy")}</span>
                <span class="nm">${esc(n)}</span>
                ${state.editingSaved
                  ? `<button class="icon-btn danger" data-act="deleteSaved" data-name="${esc(n)}" aria-label="Delete ${esc(n)}">${icon("minus")}</button>`
                  : `<span class="chev">${icon("chevr")}</span>`}
              </div>`).join("")}
          </div>`}
        <div style="margin-top:18px">
          <button class="btn btn-secondary" data-act="newTournament">${icon("plus")} New tournament</button>
        </div>
        <div class="reset-foot">
          <button class="chip-btn red" data-act="resetApp">${icon("refresh")} Reset app</button>
          <p>Deletes every tournament on this device.</p>
        </div>
      </div>
    </div>`;
  }

  // ------------------------------------------------------------ SETUP view
  function viewSetup() {
    const t = state.t;
    const dupes = duplicates(t.players);
    const count = nonEmpty(t.players).length;
    const ready = canGenerate(t);
    const editing = t.schedule.length > 0;
    const maxCourts = maxCourtsFor(count);
    const p = plan(t);

    return `
    <div class="screen">
      <div class="brand-head-sm">
        <button class="round-icon-btn" data-act="backFromSetup" aria-label="Back">${icon("back")}</button>
        <h1>${editing ? "Edit" : "New tournament"}</h1>
        <span style="width:44px"></span>
      </div>

      <div class="scroll no-tabbar">
        <div class="card">
          <h3 class="card-title"><span class="ico">${icon("people")}</span> Who's playing? <span class="count">(${count})</span></h3>
          <div id="player-list">
            ${t.players.map((name, i) => playerRow(name, i, dupes)).join("")}
          </div>
          <button class="link-btn" data-act="addPlayer">${icon("personadd")} Add player</button>
          ${count < LIMITS.minPlayers ? `<p class="hint-line">Americano needs at least 4 players.</p>` : ""}
        </div>

        <div id="dupe-warn">${dupes.size ? dupeWarn() : ""}</div>

        <div class="card">
          ${settingRow("Rounds", "rounds", t.numberOfRounds, LIMITS.minRounds, LIMITS.maxRounds)}
          <div id="courts-slot">${courtsRow(t, maxCourts)}</div>
          ${settingRow("Games to", "target", t.pointsTarget, LIMITS.minTarget, LIMITS.maxTarget)}
          <div class="name-row">
            <label for="tname">Name</label>
            <input id="tname" class="name-input" type="text" autocomplete="off" maxlength="40"
              value="${esc(t.name)}" placeholder="${esc(defaultName())}" />
          </div>
        </div>

        <div id="plan-box">${p ? planBox(p) : ""}</div>

        <button class="btn btn-primary" id="generate-btn" data-act="generate" ${ready ? "" : "disabled"}>
          ${editing ? "Rebuild schedule" : "Generate schedule"}
        </button>
        ${editing ? `<p class="hint-line center">Rebuilding creates new matchups and clears any scores.</p>` : ""}
      </div>
    </div>`;
  }

  // Courts only make sense once there are enough players for a second court.
  function courtsRow(t, maxCourts) {
    return maxCourts > 1
      ? settingRow("Courts", "courts", t.numberOfCourts, LIMITS.minCourts, maxCourts)
      : "";
  }

  function planBox(p) {
    return `<div class="plan">
      <div class="plan-head">${esc(p.head)}</div>
      <div class="plan-body">${esc(p.body)}</div>
    </div>`;
  }

  function playerRow(name, i, dupes) {
    const isDupe = name.trim() !== "" && dupes.has(name.trim());
    const canRemove = state.t.players.length > LIMITS.minPlayers;
    return `
    <div class="player-row">
      <span class="idx">${i + 1}</span>
      <input class="field player-input ${isDupe ? "dupe" : ""}" data-i="${i}" type="text" autocomplete="off"
        placeholder="Player ${i + 1}" value="${esc(name)}" maxlength="24" />
      ${canRemove ? `<button class="icon-btn danger" data-act="removePlayer" data-i="${i}" aria-label="Remove player ${i + 1}">${icon("minus")}</button>` : ""}
    </div>`;
  }
  function dupeWarn() {
    return `<div class="warn-band">${icon("warn")} Two players have the same name — make each one different.</div>`;
  }
  function settingRow(label, key, val, min, max) {
    return `
    <div class="setting-row">
      <span class="label">${label}</span>
      <span class="stepper">
        <button data-act="stepDown" data-key="${key}" ${val <= min ? "disabled" : ""} aria-label="Fewer ${label.toLowerCase()}">−</button>
        <span class="val">${val}</span>
        <button data-act="stepUp" data-key="${key}" ${val >= max ? "disabled" : ""} aria-label="More ${label.toLowerCase()}">+</button>
      </span>
    </div>`;
  }

  // ------------------------------------------------------------- MAIN view
  function viewMain() {
    const body = state.tab === 0 ? tabPlay() : tabStandings();
    const tabs = [["Play", "cal"], ["Standings", "chart"]];
    return `
    <div class="screen">
      ${body}
      <div class="tabbar" role="tablist">
        ${tabs.map(([t, ic], i) => `<button role="tab" class="${state.tab === i ? "active" : ""}" data-act="tab" data-i="${i}" aria-selected="${state.tab === i}">${icon(ic)}<span>${t}</span></button>`).join("")}
      </div>
    </div>`;
  }

  function tabHeader(title) {
    return `
    <div class="tab-head">
      <h1>${title}</h1>
      <button class="tourney-chip" data-act="tournamentMenu" aria-label="Tournament options">
        <span class="name">${esc(state.t.name)}</span>
        ${icon("dropdown")}
      </button>
    </div>`;
  }

  // -------------------------------------------------------------- PLAY tab
  function tabPlay() {
    const t = state.t;
    if (!t.schedule.length) {
      return `<div class="scroll">${tabHeader("Play")}
        <div class="empty-state">${icon("cal")}<h3>No schedule yet</h3>
        <p>Add players and generate a schedule to get started.</p>
        <button class="btn btn-primary" style="margin-top:18px" data-act="editSetup">Set up tournament</button>
        </div></div>`;
    }
    const rounds = [];
    for (let r = 0; r < t.numberOfRounds; r++) rounds.push(r);
    return `<div class="scroll">
      ${tabHeader("Play")}
      ${rounds.map((r) => roundCard(r)).join("")}
      <div style="height:6px"></div>
      <button class="btn btn-secondary" data-act="addRound" ${state.addingRound ? "disabled" : ""}>
        ${state.addingRound ? `${icon("spinner", "spin")} Adding round…` : `${icon("plus")} Add round`}
      </button>
      ${state.addRoundError ? `<div class="add-round-err">${esc(state.addRoundError)}</div>` : ""}
    </div>`;
  }

  function roundCard(r) {
    const t = state.t;
    const matches = t.schedule.filter((m) => m.round === r);
    const resting = t.restingByRound[r] || t.restingByRound[String(r)] || [];
    const open = state.expanded.has(r);
    const done = matches.filter((m) => m.winningTeam).length;
    const preview = matches.length === 1
      ? `${esc(matches[0].team1.player1)} & ${esc(matches[0].team1.player2)} vs ${esc(matches[0].team2.player1)} & ${esc(matches[0].team2.player2)}`
      : `${matches.length} matches`;
    return `
    <div class="round-card ${open ? "open" : ""}">
      <button class="round-head" data-act="toggleRound" data-r="${r}" aria-expanded="${open}">
        <span>
          <span class="rd">Round ${r + 1}</span>
          ${open ? "" : `<div class="preview">${preview}</div>`}
        </span>
        <span class="right">
          <span class="progress-pill ${done === matches.length && matches.length ? "done" : ""}">${done}/${matches.length}</span>
          <span class="chev">${icon("chevd")}</span>
        </span>
      </button>
      <div class="round-body">
        ${matches.map((m) => matchView(m)).join("")}
        ${resting.length ? `<div class="resting">${icon("seat")} Sitting out: ${resting.map(esc).join(", ")}</div>` : ""}
      </div>
    </div>`;
  }

  function teamName(team) { return esc(team.player1) + " & " + esc(team.player2); }

  /**
   * Scoring is "tap the team that won", then tap how many the other team got.
   * Two taps, no modal — it happens courtside, one-handed.
   */
  function matchView(m) {
    const t = state.t;
    const target = t.pointsTarget || LIMITS.defaultTarget;
    const decided = m.winningTeam === 1 || m.winningTeam === 2;
    const awaiting = state.awaiting && state.awaiting.id === m.id ? state.awaiting.team : null;
    const winner = awaiting || m.winningTeam;

    function row(teamNo) {
      const team = teamNo === 1 ? m.team1 : m.team2;
      const isWinner = winner === teamNo;
      const score = decided ? (teamNo === 1 ? m.team1Score : m.team2Score) : (isWinner && awaiting ? target : null);
      return `
      <button class="team-pick ${isWinner ? "won" : ""} ${winner && !isWinner ? "lost" : ""}"
        data-act="pickWinner" data-id="${m.id}" data-team="${teamNo}"
        aria-label="${teamName(team)} won">
        ${isWinner ? `<span class="tp-check">${icon("check")}</span>` : `<span class="tp-dot"></span>`}
        <span class="tp-names">${teamName(team)}</span>
        ${score !== null ? `<span class="tp-score">${score}</span>` : ""}
      </button>`;
    }

    let strip = "";
    if (awaiting) {
      const loserTeam = awaiting === 1 ? m.team2 : m.team1;
      const chips = [];
      for (let n = 0; n < target; n++) {
        chips.push(`<button class="chip" data-act="pickLoserScore" data-id="${m.id}" data-n="${n}">${n}</button>`);
      }
      strip = `
      <div class="score-strip">
        <div class="strip-q">How many did ${teamName(loserTeam)} get?</div>
        <div class="chip-row">${chips.join("")}
          <button class="chip other" data-act="otherScore" data-id="${m.id}">Other…</button>
        </div>
      </div>`;
    } else if (decided) {
      strip = `<div class="score-strip"><button class="strip-link" data-act="changeScore" data-id="${m.id}">Change score</button></div>`;
    } else {
      strip = `<div class="score-strip"><div class="strip-hint">Tap the team that won</div></div>`;
    }

    return `
    <div class="match">
      <div class="court">Court ${m.court}</div>
      ${row(1)}
      ${row(2)}
      ${strip}
    </div>`;
  }

  // --------------------------------------------------------- STANDINGS tab
  function tabStandings() {
    const t = state.t;
    const stats = leaderboardStats();
    const rows = E.sortLeaderboard(stats, state.sort);
    const played = t.schedule.filter((m) => m.winningTeam).length;
    // Every option here produces a genuinely different order.
    const sorts = [["score", "Rank"], ["diff", "Diff"], ["rests", "Sat out"], ["name", "Name"]];
    if (!t.schedule.length || played === 0) {
      return `<div class="scroll">${tabHeader("Standings")}
        <div class="empty-state">${icon("trophy")}<h3>No results yet</h3>
        <p>Enter a score on the Play tab and standings will appear here.</p></div></div>`;
    }
    return `<div class="scroll">
      ${tabHeader("Standings")}
      <div class="segmented" role="tablist">
        ${sorts.map(([k, l]) => `<button class="${state.sort === k ? "active" : ""}" data-act="sort" data-k="${k}">${l}</button>`).join("")}
      </div>
      ${rows.map((s, i) => lbRow(s, i + 1)).join("")}
      <p class="legend">${state.sort === "score"
        ? "Ranked by wins, then points difference."
        : state.sort === "diff" ? "Sorted by points difference — points scored minus points conceded."
        : state.sort === "rests" ? "Sorted by who has sat out least."
        : "Sorted by name."}</p>
    </div>`;
  }

  function lbRow(s, pos) {
    const rankIco = pos === 1 ? icon("trophy") : pos <= 3 ? icon("medal") : icon("person");
    const topCls = pos <= 3 ? `top${pos}` : "";
    const diff = s.pointDifferential;
    const diffStr = diff > 0 ? `+${diff}` : `${diff}`;
    return `
    <div class="lb-row ${topCls}">
      <span class="lb-rank"><span class="rankico">${rankIco}</span><span class="num">${pos}</span></span>
      <span class="lb-name">${esc(s.name)}</span>
      <span class="lb-stats">
        <span class="stat"><span class="v">${diffStr}</span><span class="l">Diff</span></span>
        <span class="stat"><span class="v">${s.wins}</span><span class="l">Won</span></span>
        <span class="stat"><span class="v">${s.losses}</span><span class="l">Lost</span></span>
        <span class="stat rest"><span class="v">${s.rests}</span><span class="l">Sat</span></span>
      </span>
    </div>`;
  }

  // ============================================================ SHEETS
  function howSheet() {
    openSheet(`
      <div class="grabber"></div>
      <h3>How Americano works</h3>
      <div class="how-list">
        <div class="how-item">
          <span class="how-n">1</span>
          <div><b>Partners change every round.</b> You play alongside a different person each time, so nobody is stuck with a fixed team.</div>
        </div>
        <div class="how-item">
          <span class="how-n">2</span>
          <div><b>You're scored individually.</b> Wins and points difference follow you, not your pair.</div>
        </div>
        <div class="how-item">
          <span class="how-n">3</span>
          <div><b>Everyone plays evenly.</b> If the numbers don't divide neatly, sitting out is shared equally.</div>
        </div>
      </div>
      <div class="sheet-actions">
        <button class="btn btn-primary" data-act="closeSheet">Got it</button>
      </div>`);
  }

  function scoreSheet(matchId, team) {
    const m = state.t.schedule.find((x) => x.id === matchId);
    const cur = team === 1 ? m.team1Score : m.team2Score;
    const nums = [];
    for (let i = 0; i <= LIMITS.maxScore; i++) nums.push(i);
    openSheet(`
      <div class="grabber"></div>
      <h3>Their score</h3>
      <p>How many did ${teamName(team === 1 ? m.team1 : m.team2)} get?</p>
      <div class="num-grid">
        ${nums.map((n) => `<button class="${n === cur ? "sel" : ""}" data-act="pickScore" data-id="${matchId}" data-team="${team}" data-n="${n}">${n}</button>`).join("")}
      </div>`);
  }

  function tournamentMenuSheet() {
    openSheet(`
      <div class="grabber"></div>
      <h3>${esc(state.t.name)}</h3>
      <div class="sheet-actions">
        <button class="btn btn-secondary" data-act="editSetup">${icon("pencil")} Edit players & rounds</button>
        <button class="btn btn-secondary" data-act="howItWorks">${icon("info")} How Americano works</button>
        <button class="btn btn-secondary" data-act="goSaved">${icon("folder")} Saved tournaments</button>
        <button class="btn btn-secondary" data-act="newTournament">${icon("plus")} New tournament</button>
      </div>`);
  }

  function confirmSheet(opts) {
    openSheet(`
      <div class="grabber"></div>
      <h3>${esc(opts.title)}</h3>
      <p>${esc(opts.body)}</p>
      <div class="sheet-actions">
        <button class="btn btn-primary" style="background:var(--red)" data-act="${opts.act}">${esc(opts.confirm)}</button>
        <button class="btn btn-ghost" data-act="closeSheet">Cancel</button>
      </div>`);
  }

  // ============================================================ WIRING
  function wire() {
    appEl.querySelectorAll("[data-act]").forEach((node) => {
      node.addEventListener("click", onAction);
      node.addEventListener("keydown", (e) => {
        if ((e.key === "Enter" || e.key === " ") && node.getAttribute("role") === "button") { e.preventDefault(); onAction(e); }
      });
    });

    // Tournament name (setup screen) — never blocks anything.
    const tname = document.getElementById("tname");
    if (tname) {
      tname.addEventListener("input", (e) => { state.t.name = e.target.value; });
      tname.addEventListener("blur", () => {
        if (!state.t.name.trim()) state.t.name = defaultName();
        saveCurrent();
      });
    }

    // Player names — update without a full re-render so focus is kept.
    appEl.querySelectorAll(".player-input").forEach((inp) => {
      inp.addEventListener("input", (e) => {
        state.t.players[Number(e.target.dataset.i)] = e.target.value;
        refreshSetupLive();
      });
      inp.addEventListener("blur", saveCurrent);
    });
  }

  /** Update the parts of Setup that depend on player names, without re-rendering. */
  function refreshSetupLive() {
    const t = state.t;
    const dupes = duplicates(t.players);
    const count = nonEmpty(t.players).length;

    appEl.querySelectorAll(".player-input").forEach((inp) => {
      const v = inp.value.trim();
      inp.classList.toggle("dupe", v !== "" && dupes.has(v));
    });
    const countEl = appEl.querySelector(".card-title .count");
    if (countEl) countEl.textContent = `(${count})`;
    const warn = document.getElementById("dupe-warn");
    if (warn) warn.innerHTML = dupes.size ? dupeWarn() : "";

    // Courts can't exceed what the group can fill; the control appears and
    // disappears as the player count crosses a multiple of four. Until someone
    // sets it deliberately, use every court the group can fill — otherwise
    // people sit out for no reason.
    const maxCourts = maxCourtsFor(count);
    if (t.courtsTouched) {
      if (t.numberOfCourts > maxCourts) t.numberOfCourts = maxCourts;
    } else {
      t.numberOfCourts = maxCourts;
    }
    const slot = document.getElementById("courts-slot");
    if (slot) {
      const want = courtsRow(t, maxCourts);
      if (slot.innerHTML.trim() !== want.trim()) {
        slot.innerHTML = want;
        slot.querySelectorAll("[data-act]").forEach((n) => n.addEventListener("click", onAction));
      }
    }

    const planEl = document.getElementById("plan-box");
    if (planEl) {
      const p = plan(t);
      planEl.innerHTML = p ? planBox(p) : "";
    }
    const gen = document.getElementById("generate-btn");
    if (gen) gen.disabled = !canGenerate(t);
  }

  function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)); }

  function onAction(e) {
    const node = e.currentTarget;
    const act = node.dataset.act;
    const t = state.t;
    switch (act) {
      case "newTournament":
        closeSheet();
        if (t) saveCurrent();
        newTournament();
        break;
      case "howItWorks": closeSheet(); howSheet(); break;
      case "goSaved":
        closeSheet();
        if (t) saveCurrent();
        state.editingSaved = false;
        state.view = "saved";
        render();
        break;
      case "backFromSaved":
        state.view = t ? (t.schedule.length ? "main" : "setup") : "start";
        render();
        break;
      case "backFromSetup":
        if (t && t.schedule.length) { saveCurrent(); state.view = "main"; }
        else { state.t = null; Store.setCurrentName(""); state.view = "start"; }
        render();
        break;
      case "toggleEdit": state.editingSaved = !state.editingSaved; render(); break;
      case "loadSaved": {
        const rec = Store.load(node.dataset.name);
        if (rec) {
          state.t = rec;
          Store.setCurrentName(rec.name);
          closeSheet();
          state.view = rec.schedule && rec.schedule.length ? "main" : "setup";
          state.tab = 0;
          state.expanded = new Set([0]);
          render();
        }
        break;
      }
      case "deleteSaved": {
        e.stopPropagation();
        const name = node.dataset.name;
        Store.delete(name);
        if (state.t && state.t.name === name) state.t = null;
        if (!Store.listTournaments().length) state.editingSaved = false;
        render();
        break;
      }
      case "editSetup":
        closeSheet();
        state.view = "setup";
        render();
        break;
      case "tab": state.tab = Number(node.dataset.i); render(); break;
      case "tournamentMenu": tournamentMenuSheet(); break;
      case "addPlayer":
        t.players.push("");
        saveCurrent(); render();
        setTimeout(() => {
          const inputs = appEl.querySelectorAll(".player-input");
          const last = inputs[inputs.length - 1];
          if (last) last.focus();
        }, 0);
        break;
      case "removePlayer": {
        t.players.splice(Number(node.dataset.i), 1);
        while (t.players.length < LIMITS.minPlayers) t.players.push("");
        t.numberOfCourts = Math.min(t.numberOfCourts, maxCourtsFor(nonEmpty(t.players).length));
        saveCurrent(); render(); break;
      }
      case "stepUp":
      case "stepDown": {
        const delta = act === "stepUp" ? 1 : -1;
        if (node.dataset.key === "rounds") {
          t.numberOfRounds = clamp(t.numberOfRounds + delta, LIMITS.minRounds, LIMITS.maxRounds);
        } else if (node.dataset.key === "target") {
          t.pointsTarget = clamp(t.pointsTarget + delta, LIMITS.minTarget, LIMITS.maxTarget);
        } else {
          t.courtsTouched = true;
          t.numberOfCourts = clamp(t.numberOfCourts + delta, LIMITS.minCourts, maxCourtsFor(nonEmpty(t.players).length));
        }
        saveCurrent(); render(); break;
      }
      case "generate":
        if (t.schedule.length) {
          const scored = t.schedule.filter((m) => m.winningTeam).length;
          if (scored > 0) {
            confirmSheet({
              title: "Rebuild schedule?",
              body: `This creates new matchups and clears ${scored} recorded ${scored === 1 ? "score" : "scores"}.`,
              confirm: "Rebuild",
              act: "confirmGenerate",
            });
            break;
          }
        }
        generateSchedule();
        break;
      case "confirmGenerate": closeSheet(); generateSchedule(); break;
      case "toggleRound": {
        const r = Number(node.dataset.r);
        if (state.expanded.has(r)) state.expanded.delete(r); else state.expanded.add(r);
        render(); break;
      }
      case "pickWinner": {
        // Tapping a team marks it the winner and asks for the other team's
        // score. Tapping the other team just switches the winner.
        state.awaiting = { id: node.dataset.id, team: Number(node.dataset.team) };
        render();
        break;
      }
      case "pickLoserScore": {
        const a = state.awaiting;
        if (!a || a.id !== node.dataset.id) break;
        const loserScore = Number(node.dataset.n);
        const target = t.pointsTarget || LIMITS.defaultTarget;
        commitResult(a.id, a.team, target, loserScore);
        break;
      }
      case "otherScore": {
        // Escape hatch: the winner didn't finish on the target score.
        const a = state.awaiting;
        if (!a || a.id !== node.dataset.id) break;
        scoreSheet(a.id, a.team === 1 ? 2 : 1);
        break;
      }
      case "changeScore":
        state.awaiting = null;
        setMatchResult(node.dataset.id, null);
        break;
      case "pickScore": {
        // From the "Other…" grid: the tapped number is the loser's score.
        const a = state.awaiting;
        closeSheet();
        if (a && a.id === node.dataset.id) {
          commitResult(a.id, a.team, t.pointsTarget || LIMITS.defaultTarget, Number(node.dataset.n));
        }
        break;
      }
      case "addRound": addRound(); break;
      case "sort": state.sort = node.dataset.k; render(); break;
      case "resetApp":
        confirmSheet({
          title: "Reset app?",
          body: "This permanently deletes every tournament and score on this device.",
          confirm: "Reset everything",
          act: "confirmReset",
        });
        break;
      case "confirmReset":
        Store.resetAll(); closeSheet();
        state.t = null; state.view = "start"; state.tab = 0;
        toast("Everything cleared.");
        render(); break;
      case "closeSheet": closeSheet(); break;
    }
  }

  // ============================================================ BOOT
  function boot() {
    const current = Store.getCurrentName();
    if (current) {
      const rec = Store.load(current);
      if (rec) {
        rec.restingByRound = rec.restingByRound || {};
        rec.pointsPerWin = rec.pointsPerWin || LIMITS.pointsPerWin;
        rec.pointsTarget = rec.pointsTarget || LIMITS.defaultTarget;
        rec.players = rec.players || ["", "", "", ""];
        state.t = rec;
        if (rec.schedule && rec.schedule.length) {
          // Pick up where the session left off, on the round still being played.
          state.view = "main";
          state.tab = 0;
          const firstUnfinished = [];
          for (let r = 0; r < rec.numberOfRounds; r++) {
            const ms = rec.schedule.filter((m) => m.round === r);
            if (ms.length && ms.some((m) => !m.winningTeam)) { firstUnfinished.push(r); break; }
          }
          state.expanded = new Set([firstUnfinished.length ? firstUnfinished[0] : 0]);
        } else {
          state.view = "setup";
        }
      }
    }
    render();
  }
  boot();
})();
