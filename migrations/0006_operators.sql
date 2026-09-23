-- Phase A: operator identity for the acknowledge/action workflow.
-- The observe/act boundary: the public dashboard reads freely; ACTIONS
-- (acknowledging an alarm, completing an isolation step, resolving an
-- incident) require an authenticated operator. This table is the "who".
--
-- Passwords are stored as bcrypt hashes, never plaintext. The audit
-- tables (Phase C) reference operator_id so every action is attributable.

CREATE TABLE IF NOT EXISTS operator (
    operator_id  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    username     text NOT NULL UNIQUE,
    display_name text NOT NULL,
    role         text NOT NULL DEFAULT 'operator',   -- operator | supervisor
    pw_hash      text NOT NULL,                        -- bcrypt
    created_at   timestamptz NOT NULL DEFAULT now(),
    last_login   timestamptz
);

-- Acknowledgment: an operator has taken ownership of an incident.
-- One ack per (episode, operator) — re-acking is idempotent.
CREATE TABLE IF NOT EXISTS alarm_ack (
    alarm_id     uuid NOT NULL REFERENCES alarm_events(alarm_id),
    operator_id  uuid NOT NULL REFERENCES operator(operator_id),
    acked_at     timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (alarm_id, operator_id)
);

-- Audit trail (Phase C): every action, append-only, attributable.
-- No UPDATE/DELETE in the app — this is the immutable record of who
-- did what and when, the way a safety/regulated system requires.
CREATE TABLE IF NOT EXISTS plan_action (
    action_id    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    alarm_id     uuid NOT NULL REFERENCES alarm_events(alarm_id),
    operator_id  uuid NOT NULL REFERENCES operator(operator_id),
    kind         text NOT NULL,          -- ack | step_done | resolved | false_alarm
    detail       jsonb NOT NULL DEFAULT '{}',   -- e.g. {"step": 3}
    at           timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS plan_action_alarm_idx ON plan_action (alarm_id, at);

GRANT SELECT, INSERT, UPDATE ON operator TO hazshield;
GRANT SELECT, INSERT ON alarm_ack TO hazshield;
GRANT SELECT, INSERT ON plan_action TO hazshield;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO hazshield;
