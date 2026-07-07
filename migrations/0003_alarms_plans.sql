-- Alarm EPISODES (open/escalate/clear), not per-breaching-reading rows.
-- Permanent retention: this is the safety audit trail.

DO $$ BEGIN
    CREATE TYPE alarm_severity AS ENUM ('warn','critical');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE alarm_state AS ENUM ('open','escalated','cleared');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS alarm_events (
    alarm_id    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    sensor_id   uuid NOT NULL REFERENCES sensor(sensor_id),
    zone_id     uuid NOT NULL REFERENCES zone(zone_id),
    severity    alarm_severity NOT NULL,
    state       alarm_state NOT NULL DEFAULT 'open',
    opened_at   timestamptz NOT NULL DEFAULT now(),
    last_seen   timestamptz NOT NULL DEFAULT now(),
    cleared_at  timestamptz,
    peak_value  double precision NOT NULL,
    n_readings  bigint NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS alarm_open_idx
    ON alarm_events (state, opened_at DESC) WHERE state <> 'cleared';
CREATE INDEX IF NOT EXISTS alarm_zone_idx ON alarm_events (zone_id, opened_at DESC);

-- AI isolation plans. prompt_hash enables dedupe: identical hazard
-- context => reuse the cached plan instead of burning an Ollama slot.

DO $$ BEGIN
    CREATE TYPE plan_status AS ENUM ('pending','generating','ready','failed','fallback');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS isolation_plans (
    plan_id     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    alarm_id    uuid NOT NULL REFERENCES alarm_events(alarm_id),
    model       text NOT NULL,
    prompt_hash text NOT NULL,
    plan        jsonb,
    status      plan_status NOT NULL DEFAULT 'pending',
    latency_ms  integer,
    created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS plan_hash_idx ON isolation_plans (prompt_hash, created_at DESC);
CREATE INDEX IF NOT EXISTS plan_alarm_idx ON isolation_plans (alarm_id);
