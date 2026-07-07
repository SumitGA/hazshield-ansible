-- Raw telemetry firehose. Narrow row, 2h chunks, compressed after 4h,
-- dropped after 48h. The UI never reads this table directly — it reads
-- the continuous aggregates below.

CREATE TABLE IF NOT EXISTS sensor_readings (
    time        timestamptz NOT NULL,
    sensor_id   uuid NOT NULL,
    value       real NOT NULL,
    quality     smallint NOT NULL DEFAULT 0   -- 0=good, 1=suspect, 2=degraded-sampled
);

SELECT create_hypertable('sensor_readings', 'time',
    chunk_time_interval => INTERVAL '2 hours',
    if_not_exists => TRUE);

CREATE INDEX IF NOT EXISTS sr_sensor_time_idx
    ON sensor_readings (sensor_id, time DESC);

ALTER TABLE sensor_readings SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'sensor_id',
    timescaledb.compress_orderby = 'time DESC'
);

SELECT add_compression_policy('sensor_readings', INTERVAL '4 hours', if_not_exists => TRUE);
SELECT add_retention_policy('sensor_readings', INTERVAL '48 hours', if_not_exists => TRUE);

-- 10-second rollup: powers live UI charts.
CREATE MATERIALIZED VIEW IF NOT EXISTS sensor_readings_10s
WITH (timescaledb.continuous) AS
SELECT time_bucket('10 seconds', time) AS bucket,
       sensor_id,
       avg(value) AS avg_v, min(value) AS min_v, max(value) AS max_v,
       count(*)   AS n
FROM sensor_readings
GROUP BY bucket, sensor_id
WITH NO DATA;

SELECT add_continuous_aggregate_policy('sensor_readings_10s',
    start_offset => INTERVAL '1 hour',
    end_offset   => INTERVAL '10 seconds',
    schedule_interval => INTERVAL '10 seconds',
    if_not_exists => TRUE);

SELECT add_retention_policy('sensor_readings_10s', INTERVAL '30 days', if_not_exists => TRUE);

-- 5-minute rollup: history views, capacity trends.
CREATE MATERIALIZED VIEW IF NOT EXISTS sensor_readings_5m
WITH (timescaledb.continuous) AS
SELECT time_bucket('5 minutes', time) AS bucket,
       sensor_id,
       avg(value) AS avg_v, min(value) AS min_v, max(value) AS max_v,
       count(*)   AS n
FROM sensor_readings
GROUP BY bucket, sensor_id
WITH NO DATA;

SELECT add_continuous_aggregate_policy('sensor_readings_5m',
    start_offset => INTERVAL '1 day',
    end_offset   => INTERVAL '5 minutes',
    schedule_interval => INTERVAL '5 minutes',
    if_not_exists => TRUE);

SELECT add_retention_policy('sensor_readings_5m', INTERVAL '365 days', if_not_exists => TRUE);
