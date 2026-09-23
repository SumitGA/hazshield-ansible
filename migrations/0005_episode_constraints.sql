-- Phase 3: one live episode per sensor, enforced by the database.
-- This partial unique index is the ON CONFLICT target for the worker's
-- atomic upsert in episodes.py. Two workers processing the same sensor
-- concurrently cannot double-open an episode; the loser's INSERT becomes
-- an UPDATE. Idempotent via IF NOT EXISTS.
CREATE UNIQUE INDEX IF NOT EXISTS alarm_one_live_per_sensor
    ON alarm_events (sensor_id) WHERE state <> 'cleared';
