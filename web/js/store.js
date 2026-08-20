/*
 * store.js — persistence layer (browser localStorage).
 *
 * Mirrors the app's multi-tournament model:
 *   - a list of saved tournament names
 *   - one record per tournament (players, settings, schedule, resting)
 *   - the "current" tournament name
 *
 * A tournament record:
 * {
 *   name, players: [..], numberOfRounds, numberOfCourts, pointsPerWin, seed,
 *   schedule: [Match], restingByRound: { round: [names] }
 * }
 */
(function (root) {
  "use strict";

  const KEYS = {
    saved: "pbgen.savedTournaments",
    current: "pbgen.currentTournament",
    record: (name) => "pbgen.tournament." + name,
  };

  function readJSON(key, fallback) {
    try {
      const raw = localStorage.getItem(key);
      return raw == null ? fallback : JSON.parse(raw);
    } catch (e) {
      return fallback;
    }
  }
  function writeJSON(key, value) {
    try {
      localStorage.setItem(key, JSON.stringify(value));
    } catch (e) {
      /* storage full / disabled — app still works in-memory this session */
    }
  }

  const Store = {
    listTournaments() {
      return readJSON(KEYS.saved, []);
    },
    getCurrentName() {
      try { return localStorage.getItem(KEYS.current) || ""; } catch (e) { return ""; }
    },
    setCurrentName(name) {
      try {
        if (name) localStorage.setItem(KEYS.current, name);
        else localStorage.removeItem(KEYS.current);
      } catch (e) {}
    },
    load(name) {
      return readJSON(KEYS.record(name), null);
    },
    save(record) {
      if (!record || !record.name) return;
      const list = Store.listTournaments();
      if (!list.includes(record.name)) {
        list.push(record.name);
        writeJSON(KEYS.saved, list);
      }
      writeJSON(KEYS.record(record.name), record);
    },
    exists(name) {
      return Store.listTournaments().includes(name);
    },
    delete(name) {
      const list = Store.listTournaments().filter((n) => n !== name);
      writeJSON(KEYS.saved, list);
      try { localStorage.removeItem(KEYS.record(name)); } catch (e) {}
      if (Store.getCurrentName() === name) Store.setCurrentName("");
    },
    /** Beta features are opt-in and stay on until turned off. */
    isBeta() {
      try { return localStorage.getItem("pbgen.beta") === "1"; } catch (e) { return false; }
    },
    setBeta(on) {
      try {
        if (on) localStorage.setItem("pbgen.beta", "1");
        else localStorage.removeItem("pbgen.beta");
      } catch (e) {}
    },
    resetAll() {
      const list = Store.listTournaments();
      for (const n of list) {
        try { localStorage.removeItem(KEYS.record(n)); } catch (e) {}
      }
      try {
        localStorage.removeItem(KEYS.saved);
        localStorage.removeItem(KEYS.current);
      } catch (e) {}
    },
  };

  root.Store = Store;
})(typeof self !== "undefined" ? self : this);
