import Foundation

enum Schema {
    static let createClaudeTurns = """
        CREATE TABLE claude_turns (
            id                          INTEGER PRIMARY KEY AUTOINCREMENT,
            ts                          INTEGER NOT NULL,
            session_id                  TEXT    NOT NULL,
            project_path                TEXT    NOT NULL,
            model                       TEXT    NOT NULL,
            input_tokens                INTEGER NOT NULL,
            output_tokens               INTEGER NOT NULL,
            cache_creation_input_tokens INTEGER NOT NULL DEFAULT 0,
            cache_read_input_tokens     INTEGER NOT NULL DEFAULT 0,
            cost_usd                    REAL    NOT NULL,
            jsonl_path                  TEXT    NOT NULL,
            jsonl_line_no               INTEGER NOT NULL,
            UNIQUE (jsonl_path, jsonl_line_no)
        )
        """

    static let createCodexObservations = """
        CREATE TABLE codex_observations (
            id                       INTEGER PRIMARY KEY AUTOINCREMENT,
            ts                       INTEGER NOT NULL,
            session_id               TEXT    NOT NULL,
            cwd                      TEXT,
            plan_type                TEXT,
            primary_used_percent     REAL    NOT NULL,
            primary_window_minutes   INTEGER NOT NULL,
            primary_resets_at        INTEGER NOT NULL,
            secondary_used_percent   REAL,
            secondary_window_minutes INTEGER,
            secondary_resets_at      INTEGER,
            raw_rate_limits_json     TEXT    NOT NULL,
            jsonl_path               TEXT    NOT NULL,
            jsonl_line_no            INTEGER NOT NULL,
            UNIQUE (jsonl_path, jsonl_line_no)
        )
        """

    static let createFileCursors = """
        CREATE TABLE file_cursors (
            jsonl_path          TEXT    PRIMARY KEY,
            source              TEXT    NOT NULL,
            last_ingested_line  INTEGER NOT NULL DEFAULT 0,
            last_ingested_at    INTEGER NOT NULL,
            file_size_at_cursor INTEGER NOT NULL
        )
        """

    static let createLimitsState = """
        CREATE TABLE limits_state (
            source                          TEXT PRIMARY KEY,
            ceiling_usd                     REAL NOT NULL,
            last_calibrated_at              INTEGER,
            calibration_anchor_event_id     INTEGER
        )
        """

    static let createDailyAggregates = """
        CREATE TABLE daily_aggregates (
            date            TEXT NOT NULL,
            source          TEXT NOT NULL,
            turn_count      INTEGER NOT NULL,
            total_cost_usd  REAL,
            total_tokens    INTEGER,
            PRIMARY KEY (date, source)
        )
        """

    static let indexes: [String] = [
        "CREATE INDEX idx_claude_turns_ts ON claude_turns(ts DESC)",
        "CREATE INDEX idx_claude_turns_session ON claude_turns(session_id)",
        "CREATE INDEX idx_codex_obs_ts ON codex_observations(ts DESC)",
        "CREATE INDEX idx_codex_obs_session ON codex_observations(session_id)",
    ]
}
