/*
 * app.js — PB Gen web UI controller (vanilla JS, no build step).
 * Renders the Create / Saved / Details / Schedule / Leaderboard screens and
 * wires them to the engine + localStorage store.
 */
(function () {
  "use strict";

  const E = window.Engine;
  const Store = window.Store;
  const appEl = document.getElementById("app");
  const sheetHost = document.getElementById("sheet-host");
  const toastEl = document.getElementById("toast");

  const LIMITS = { minPlayers: 4, minRounds: 1, maxRounds: 10, minCourts: 1, maxCourts: 5, pointsPerWin: 1, maxScore: 30 };

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
    toastTimer = setTimeout(() => (toastEl.hidden = true), 2200);
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
    view: "create", // create | saved | main
    tab: 0,
    draft: { type: "americano", name: "" },
    t: null, // current tournament record
    editingPlayers: false,
    expanded: new Set(),
    sort: "score",
    addingRound: false,
    addRoundError: null,
  };

  // --------------------------------------------------------- tournament ops
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

  function saveCurrent() {
    if (!state.t) return;
    Store.save(state.t);
    Store.setCurrentName(state.t.name);
  }

  function startTournament() {
    const name = state.draft.name.trim();
    if (!name) return;
    if (Store.exists(name)) {
      const rec = Store.load(name);
      if (rec) { state.t = rec; Store.setCurrentName(name); state.view = "main"; state.tab = 0; render(); return; }
    }
    state.t = {
      name,
      type: state.draft.type,
      players: ["", "", "", ""],
      numberOfRounds: 3,
      numberOfCourts: 1,
      pointsPerWin: LIMITS.pointsPerWin,
      seed: null,
      schedule: [],
      restingByRound: {},
    };
    saveCurrent();
    state.view = "main";
    state.tab = 0;
    render();
  }

  function generateSchedule() {
    const t = state.t;
    const players = nonEmpty(t.players).map((p) => p.trim());
    const seed = E.makeSeed();
    const scheduler = new E.AmericanoScheduler(players, t.numberOfRounds, t.numberOfCourts, seed);
    const result = scheduler.generateSchedule();
    if (!result) { toast("Could not generate a schedule."); return; }
    t.seed = String(seed);
    t.players = players;
    t.schedule = result.schedule;
    t.restingByRound = result.restingByRound;
    const producedRounds = new Set(result.schedule.map((m) => m.round)).size;
    state.expanded = new Set([0]);
    saveCurrent();
    state.tab = 1;
    render();
    if (producedRounds < t.numberOfRounds) {
      toast(`Generated ${producedRounds} of ${t.numberOfRounds} rounds (limited by players).`);
    }
  }

  function addRound() {
    const t = state.t;
    if (state.addingRound || !t.schedule.length) return;
    state.addingRound = true;
    state.addRoundError = null;
    render();
    // Let the spinner paint, then compute.
    setTimeout(() => {
      const scheduler = new E.AmericanoScheduler(t.players, t.numberOfRounds, t.numberOfCourts, BigInt(t.seed || E.makeSeed()));
      const res = scheduler.generateAdditionalRound(t.schedule.slice());
      if (!res) {
        state.addRoundError = "Unable to generate an additional round. All fair pairings may be exhausted.";
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

  function setMatchScore(matchId, team, value) {
    const m = state.t.schedule.find((x) => x.id === matchId);
    if (!m) return;
    if (team === 1) m.team1Score = value; else m.team2Score = value;
    if (m.team1Score === m.team2Score) m.winningTeam = null;
    else m.winningTeam = m.team1Score > m.team2Score ? 1 : 2;
    saveCurrent();
    render();
  }

  function leaderboardStats() {
    const t = state.t;
    return E.computeLeaderboard(t.players, t.schedule, t.restingByRound, { pointsPerWin: t.pointsPerWin });
  }

  // ============================================================ RENDER
  function render() {
    if (state.view === "create") appEl.innerHTML = viewCreate();
    else if (state.view === "saved") appEl.innerHTML = viewSaved();
    else appEl.innerHTML = viewMain();
    wire();
  }

  // ---------------------------------------------------------- CREATE view
  function viewCreate() {
    const canStart = state.draft.name.trim() !== "" && state.draft.type === "americano";
    const hasSaved = Store.listTournaments().length > 0;
    const types = [
      { id: "americano", label: "Americano", on: true },
      { id: "single", label: "Single Elimination", on: false },
      { id: "double", label: "Double Elimination", on: false },
    ];
    return `
    <div class="screen create">
      <div class="brand-head">
        <button class="round-icon-btn" data-act="goSaved" ${hasSaved ? "" : "disabled"} aria-label="Saved tournaments">${icon("back")}</button>
        <div class="wordmark">PB GEN</div>
        <div style="width:44px"></div>
      </div>

      <div class="create-body">
        <div class="card type-card">
          <h2>What kind of tournament<br>would you like to create?</h2>
          ${types.map((ty) => `
            <button class="type-opt ${state.draft.type === ty.id ? "selected" : ""} ${ty.on ? "" : "disabled"}"
              data-act="pickType" data-type="${ty.id}" ${ty.on ? "" : "disabled"}>
              ${ty.label}${ty.on ? "" : '<span class="soon">SOON</span>'}
            </button>`).join("")}
        </div>

        <div class="name-block">
          <label for="tname">NAME OF TOURNAMENT</label>
          <input id="tname" class="field" type="text" autocomplete="off" placeholder="e.g. Saturday Social"
            value="${esc(state.draft.name)}" maxlength="40" />
        </div>
      </div>

      <div class="start-wrap">
        <button class="start-btn" data-act="start" ${canStart ? "" : "disabled"} aria-label="Start tournament">${icon("fwd")}</button>
        <div class="start-label">START</div>
      </div>
    </div>`;
  }

  // ---------------------------------------------------------- SAVED view
  function viewSaved() {
    const list = Store.listTournaments();
    return `
    <div class="screen">
      <div class="brand-head">
        <button class="round-icon-btn" data-act="backFromSaved" aria-label="Back">${icon("back")}</button>
        <div class="wordmark" style="font-size:20px;letter-spacing:2px">SAVED</div>
        <button class="round-icon-btn" data-act="toggleEdit" aria-label="Edit">${state.editingPlayers ? icon("check") : icon("trash")}</button>
      </div>
      <div class="scroll no-tabbar">
        ${list.length === 0 ? `
          <div class="empty-state">
            ${icon("folder")}
            <h3>No Saved Tournaments</h3>
            <p>Create your first tournament to get started.</p>
          </div>` : `
          <div class="saved-list">
            ${list.map((n) => `
              <div class="saved-item" data-act="loadSaved" data-name="${esc(n)}" role="button" tabindex="0">
                <span class="trophy">${icon("trophy")}</span>
                <span class="nm">${esc(n)}</span>
                ${state.editingPlayers
                  ? `<button class="icon-btn del" data-act="deleteSaved" data-name="${esc(n)}" aria-label="Delete ${esc(n)}">${icon("minus")}</button>`
                  : `<span class="chev">${icon("chevr")}</span>`}
              </div>`).join("")}
          </div>`}
        <div style="margin-top:18px">
          <button class="btn btn-secondary" data-act="newFromSaved">${icon("plus")} New Tournament</button>
        </div>
      </div>
    </div>`;
  }

  // ---------------------------------------------------------- MAIN view
  function viewMain() {
    let body = "";
    if (state.tab === 0) body = tabDetails();
    else if (state.tab === 1) body = tabSchedule();
    else body = tabLeaderboard();
    const tabs = ["Details", "Schedule", "Leaderboard"];
    return `
    <div class="screen">
      ${body}
      <div class="tabbar" role="tablist">
        ${tabs.map((t, i) => `<button role="tab" class="${state.tab === i ? "active" : ""}" data-act="tab" data-i="${i}" aria-selected="${state.tab === i}">${t}</button>`).join("")}
      </div>
    </div>`;
  }

  function tabHeader(title) {
    const t = state.t;
    return `
    <div class="tab-head">
      <h1>${title}</h1>
      <button class="tourney-chip" data-act="switchTourney">
        <span class="dot">${icon("trophy")}</span>
        <span class="name">${esc(t.name.toUpperCase())}</span>
        ${icon("dropdown")}
      </button>
    </div>`;
  }

  // ---------------------------------------------------------- DETAILS tab
  function tabDetails() {
    const t = state.t;
    const dupes = duplicates(t.players);
    const validCount = nonEmpty(t.players).length;
    const gen = canGenerate(t);
    return `
    <div class="scroll">
      ${tabHeader("DETAILS")}

      <div class="card">
        <h3 class="card-title"><span style="color:var(--orange)" class="ico">${icon("trophy")}</span> Tournament Info</h3>
        <div class="info-row"><span class="k">Name</span><span class="v">${esc(t.name)}</span></div>
        <div class="info-row"><span class="k">Format</span><span class="v">Americano</span></div>
      </div>

      <div class="card">
        <h3 class="card-title"><span style="color:var(--blue)" class="ico">${icon("people")}</span> Players <span class="count">(${validCount})</span></h3>
        <div id="player-list">
          ${t.players.map((name, i) => playerRow(name, i, dupes)).join("")}
        </div>
        <button class="link-btn" data-act="addPlayer">${icon("personadd")} Add Player</button>
      </div>

      <div id="dupe-warn">${dupes.size ? dupeWarn() : ""}</div>

      <div class="card">
        <h3 class="card-title"><span style="color:var(--purple)" class="ico">${icon("gear")}</span> Game Settings</h3>
        ${settingRow("Rounds", "rounds", t.numberOfRounds, LIMITS.minRounds, LIMITS.maxRounds)}
        ${settingRow("Courts", "courts", t.numberOfCourts, LIMITS.minCourts, LIMITS.maxCourts)}
      </div>

      <button class="btn btn-primary" id="generate-btn" data-act="generate" ${gen ? "" : "disabled"}>
        ${icon("calplus")} ${t.schedule.length ? "Regenerate Schedule" : "Generate Schedule"}
      </button>
      ${t.schedule.length ? `<p style="text-align:center;color:var(--ink-3);font-size:12px;margin:8px 0 0">Regenerating creates a new schedule and clears scores.</p>` : ""}

      <div style="height:14px"></div>
      <button class="btn btn-secondary" data-act="newTournament">${icon("plus")} Create New Tournament</button>
      <div style="height:8px"></div>
      <button class="btn btn-secondary" data-act="goSaved">${icon("folder")} View Saved Tournaments</button>

      <div style="height:14px"></div>
      <div class="card danger-zone">
        <h3 class="card-title"><span class="ico">${icon("warn")}</span> Danger Zone</h3>
        <button class="chip-btn red" data-act="resetApp">${icon("refresh")} Reset App</button>
      </div>
    </div>`;
  }

  function playerRow(name, i, dupes) {
    const isDupe = name.trim() !== "" && dupes.has(name.trim());
    const canRemove = state.editingPlayers && state.t.players.length > LIMITS.minPlayers;
    return `
    <div class="player-row">
      <span class="idx">${i + 1}</span>
      <input class="field player-input ${isDupe ? "dupe" : ""}" data-i="${i}" type="text" autocomplete="off"
        placeholder="Player ${i + 1}" value="${esc(name)}" maxlength="24" />
      ${canRemove ? `<button class="icon-btn danger" data-act="removePlayer" data-i="${i}" aria-label="Remove player ${i + 1}">${icon("minus")}</button>` : ""}
    </div>`;
  }
  function dupeWarn() {
    return `<div class="warn-band">${icon("warn")} Duplicate names detected — make each name unique.</div>`;
  }
  function settingRow(label, key, val, min, max) {
    return `
    <div class="setting-row">
      <span class="label">${label}</span>
      <span class="stepper">
        <button data-act="stepDown" data-key="${key}" ${val <= min ? "disabled" : ""} aria-label="Decrease ${label}">−</button>
        <span class="val">${val}</span>
        <button data-act="stepUp" data-key="${key}" ${val >= max ? "disabled" : ""} aria-label="Increase ${label}">+</button>
      </span>
    </div>`;
  }

  // ---------------------------------------------------------- SCHEDULE tab
  function tabSchedule() {
    const t = state.t;
    if (!t.schedule.length) {
      return `<div class="scroll">${tabHeader("SCHEDULE")}
        <div class="empty-state">${icon("calplus")}<h3>No Schedule Yet</h3>
        <p>Add players in Details, then tap Generate Schedule.</p></div></div>`;
    }
    const rounds = [];
    for (let r = 0; r < t.numberOfRounds; r++) rounds.push(r);
    return `<div class="scroll">
      ${tabHeader("SCHEDULE")}
      ${rounds.map((r) => roundCard(r)).join("")}
      <div style="height:6px"></div>
      <button class="btn btn-primary" data-act="addRound" ${state.addingRound ? "disabled" : ""}>
        ${state.addingRound ? `${icon("spinner", "spin")} Adding Round…` : `${icon("plus")} Add Round`}
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
          <span class="rd">RD ${r + 1}</span>
          ${open ? "" : `<div class="preview">${preview}</div>`}
        </span>
        <span class="right">
          <span class="progress-pill">${done}/${matches.length}</span>
          <span class="chev">${icon("chevd")}</span>
        </span>
      </button>
      <div class="round-body">
        ${matches.map((m) => matchView(m)).join("")}
        ${resting.length ? `<div class="resting">${icon("seat")} Resting: ${resting.map(esc).join(", ")}</div>` : ""}
      </div>
    </div>`;
  }

  function matchView(m) {
    const w1 = m.winningTeam === 1, w2 = m.winningTeam === 2;
    return `
    <div class="match">
      <div class="court">Court ${m.court}</div>
      <div class="team-row ${w1 ? "win" : ""}">
        <span class="names">${esc(m.team1.player1)} & ${esc(m.team1.player2)} ${w1 ? `<span class="check">${icon("check")}</span>` : ""}</span>
        <button class="score-btn ${w1 ? "win" : ""}" data-act="score" data-id="${m.id}" data-team="1">${m.team1Score}</button>
      </div>
      <div class="vs-div">VS</div>
      <div class="team-row ${w2 ? "win" : ""}">
        <span class="names">${esc(m.team2.player1)} & ${esc(m.team2.player2)} ${w2 ? `<span class="check">${icon("check")}</span>` : ""}</span>
        <button class="score-btn ${w2 ? "win" : ""}" data-act="score" data-id="${m.id}" data-team="2">${m.team2Score}</button>
      </div>
    </div>`;
  }

  // ---------------------------------------------------------- LEADERBOARD tab
  function tabLeaderboard() {
    const t = state.t;
    const stats = leaderboardStats();
    const rows = E.sortLeaderboard(stats, state.sort);
    const played = t.schedule.filter((m) => m.winningTeam).length;
    const sorts = [["name", "Name"], ["score", "Pts"], ["wins", "W"], ["losses", "L"], ["rests", "R"]];
    if (!t.schedule.length || played === 0) {
      return `<div class="scroll">${tabHeader("LEADERBOARD")}
        <div class="empty-state">${icon("trophy")}<h3>No Results Yet</h3>
        <p>Generate a schedule and record some match scores to see the standings.</p></div></div>`;
    }
    return `<div class="scroll">
      ${tabHeader("LEADERBOARD")}
      <div class="segmented" role="tablist">
        ${sorts.map(([k, l]) => `<button class="${state.sort === k ? "active" : ""}" data-act="sort" data-k="${k}">${l}</button>`).join("")}
      </div>
      ${rows.map((s, i) => lbRow(s, i + 1)).join("")}
    </div>`;
  }

  function lbRow(s, pos) {
    const rankIco = pos === 1 ? icon("trophy") : pos <= 3 ? icon("medal") : icon("person");
    const rankColor = pos === 1 ? "var(--gold)" : pos === 2 ? "var(--silver)" : pos === 3 ? "var(--bronze)" : "var(--blue)";
    const topCls = pos <= 3 ? `top${pos}` : "";
    const diff = s.pointDifferential;
    const diffCls = diff > 0 ? "pos" : diff < 0 ? "neg" : "";
    const diffStr = diff > 0 ? `+${diff}` : `${diff}`;
    return `
    <div class="lb-row ${topCls}">
      <span class="lb-rank"><span style="color:${rankColor}">${rankIco}</span><span class="num">${pos}</span></span>
      <span class="lb-name">${esc(s.name)}</span>
      <span class="lb-stats">
        <span class="stat ${diffCls}"><span class="v">${diffStr}</span><span class="l">Pts</span></span>
        <span class="stat"><span class="v">${s.wins}</span><span class="l">W</span></span>
        <span class="stat"><span class="v">${s.losses}</span><span class="l">L</span></span>
        <span class="stat rest"><span class="v">${s.rests}</span><span class="l">R</span></span>
      </span>
    </div>`;
  }

  // ============================================================ SHEETS
  function scoreSheet(matchId, team) {
    const m = state.t.schedule.find((x) => x.id === matchId);
    const cur = team === 1 ? m.team1Score : m.team2Score;
    const nums = [];
    for (let i = 0; i <= LIMITS.maxScore; i++) nums.push(i);
    openSheet(`
      <div class="grabber"></div>
      <h3>Select Score</h3>
      <p>${esc(team === 1 ? m.team1.player1 + " & " + m.team1.player2 : m.team2.player1 + " & " + m.team2.player2)}</p>
      <div class="num-grid">
        ${nums.map((n) => `<button class="${n === cur ? "sel" : ""}" data-act="pickScore" data-id="${matchId}" data-team="${team}" data-n="${n}">${n}</button>`).join("")}
      </div>`);
  }

  function switchTourneySheet() {
    const list = Store.listTournaments();
    openSheet(`
      <div class="grabber"></div>
      <h3>Switch Tournament</h3>
      <p>Your saved tournaments</p>
      <div class="saved-list" style="max-height:50vh;overflow-y:auto">
        ${list.map((n) => `
          <div class="saved-item" data-act="loadSaved" data-name="${esc(n)}" role="button" tabindex="0">
            <span class="trophy">${icon("trophy")}</span>
            <span class="nm">${esc(n)}${n === state.t.name ? " ✓" : ""}</span>
            <span class="chev">${icon("chevr")}</span>
          </div>`).join("")}
      </div>
      <div class="sheet-actions">
        <button class="btn btn-secondary" data-act="newTournament">${icon("plus")} New Tournament</button>
      </div>`);
  }

  function confirmResetSheet() {
    openSheet(`
      <div class="grabber"></div>
      <h3>Reset App?</h3>
      <p>This permanently deletes all tournaments and scores on this device. This cannot be undone.</p>
      <div class="sheet-actions">
        <button class="btn btn-primary" style="background:var(--red)" data-act="confirmReset">Reset Everything</button>
        <button class="btn btn-ghost" data-act="closeSheet">Cancel</button>
      </div>`);
  }

  // ============================================================ WIRING
  function wire() {
    // click delegation
    appEl.querySelectorAll("[data-act]").forEach((node) => {
      node.addEventListener("click", onAction);
      node.addEventListener("keydown", (e) => {
        if ((e.key === "Enter" || e.key === " ") && node.getAttribute("role") === "button") { e.preventDefault(); onAction(e); }
      });
    });
    sheetHost.querySelectorAll("[data-act]").forEach((n) => n.addEventListener("click", onAction));

    // create name input
    const tname = document.getElementById("tname");
    if (tname) {
      tname.addEventListener("input", (e) => {
        state.draft.name = e.target.value;
        const btn = appEl.querySelector('[data-act="start"]');
        if (btn) btn.disabled = state.draft.name.trim() === "";
      });
      tname.addEventListener("keydown", (e) => { if (e.key === "Enter" && state.draft.name.trim()) startTournament(); });
    }

    // player name inputs — update without full re-render (preserve focus)
    appEl.querySelectorAll(".player-input").forEach((inp) => {
      inp.addEventListener("input", (e) => {
        const i = Number(e.target.dataset.i);
        state.t.players[i] = e.target.value;
        refreshDetailsLive();
      });
      inp.addEventListener("blur", saveCurrent);
    });
  }

  // Live-update pieces of the Details tab that depend on player names,
  // without re-rendering (which would drop input focus).
  function refreshDetailsLive() {
    const t = state.t;
    const dupes = duplicates(t.players);
    // duplicate field highlight
    appEl.querySelectorAll(".player-input").forEach((inp) => {
      const v = inp.value.trim();
      inp.classList.toggle("dupe", v !== "" && dupes.has(v));
    });
    // count
    const countEl = appEl.querySelector(".card-title .count");
    if (countEl) countEl.textContent = `(${nonEmpty(t.players).length})`;
    // warn band
    const warn = document.getElementById("dupe-warn");
    if (warn) warn.innerHTML = dupes.size ? dupeWarn() : "";
    // generate button
    const gen = document.getElementById("generate-btn");
    if (gen) gen.disabled = !canGenerate(t);
  }

  function onAction(e) {
    const node = e.currentTarget;
    const act = node.dataset.act;
    const t = state.t;
    switch (act) {
      case "pickType":
        if (node.disabled) return;
        state.draft.type = node.dataset.type; render(); break;
      case "start": startTournament(); break;
      case "goSaved": if (state.t) saveCurrent(); state.editingPlayers = false; state.view = "saved"; render(); break;
      case "backFromSaved": state.view = state.t ? "main" : "create"; render(); break;
      case "newFromSaved":
      case "newTournament":
        if (state.t) saveCurrent();
        closeSheet();
        state.draft = { type: "americano", name: "" };
        state.t = null; Store.setCurrentName("");
        state.view = "create"; render(); break;
      case "toggleEdit": state.editingPlayers = !state.editingPlayers; render(); break;
      case "loadSaved": {
        const rec = Store.load(node.dataset.name);
        if (rec) { state.t = rec; Store.setCurrentName(rec.name); closeSheet(); state.view = "main"; state.tab = 0; state.expanded = new Set([0]); render(); }
        break;
      }
      case "deleteSaved": {
        e.stopPropagation();
        Store.delete(node.dataset.name);
        if (state.t && state.t.name === node.dataset.name) { state.t = null; }
        render(); break;
      }
      case "tab": state.tab = Number(node.dataset.i); render(); break;
      case "switchTourney": switchTourneySheet(); break;
      case "addPlayer":
        t.players.push(""); saveCurrent(); render();
        setTimeout(() => { const inputs = appEl.querySelectorAll(".player-input"); const last = inputs[inputs.length - 1]; if (last) last.focus(); }, 0);
        break;
      case "removePlayer": {
        const i = Number(node.dataset.i);
        t.players.splice(i, 1);
        while (t.players.length < LIMITS.minPlayers) t.players.push("");
        saveCurrent(); render(); break;
      }
      case "stepUp":
      case "stepDown": {
        const key = node.dataset.key;
        const delta = act === "stepUp" ? 1 : -1;
        if (key === "rounds") t.numberOfRounds = clamp(t.numberOfRounds + delta, LIMITS.minRounds, LIMITS.maxRounds);
        else t.numberOfCourts = clamp(t.numberOfCourts + delta, LIMITS.minCourts, LIMITS.maxCourts);
        saveCurrent(); render(); break;
      }
      case "generate": generateSchedule(); break;
      case "toggleRound": {
        const r = Number(node.dataset.r);
        if (state.expanded.has(r)) state.expanded.delete(r); else state.expanded.add(r);
        render(); break;
      }
      case "score": scoreSheet(node.dataset.id, Number(node.dataset.team)); break;
      case "pickScore":
        setMatchScore(node.dataset.id, Number(node.dataset.team), Number(node.dataset.n));
        closeSheet(); break;
      case "addRound": addRound(); break;
      case "sort": state.sort = node.dataset.k; render(); break;
      case "resetApp": confirmResetSheet(); break;
      case "confirmReset":
        Store.resetAll(); closeSheet();
        state.t = null; state.draft = { type: "americano", name: "" };
        state.view = "create"; state.tab = 0; toast("App reset."); render(); break;
      case "closeSheet": closeSheet(); break;
    }
  }
  function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)); }

  // ============================================================ BOOT
  function boot() {
    const current = Store.getCurrentName();
    if (current) {
      const rec = Store.load(current);
      if (rec) {
        // migrate any missing fields
        rec.restingByRound = rec.restingByRound || {};
        rec.pointsPerWin = rec.pointsPerWin || LIMITS.pointsPerWin;
        state.t = rec;
        state.view = "main";
        state.tab = 0;
        if (rec.schedule && rec.schedule.length) state.expanded = new Set([0]);
      }
    }
    render();
  }
  boot();
})();
