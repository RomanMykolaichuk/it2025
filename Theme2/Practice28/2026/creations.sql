BEGIN;

DROP SCHEMA IF EXISTS oiaz CASCADE;

CREATE SCHEMA oiaz;

SET search_path = oiaz, public;

CREATE TABLE unit (
    unit_id BIGSERIAL PRIMARY KEY,
    unit_code TEXT NOT NULL UNIQUE,
    unit_name TEXT NOT NULL
);

CREATE TABLE report (
    report_id BIGSERIAL PRIMARY KEY,
    report_date DATE NOT NULL,
    report_dt TIMESTAMPTZ NOT NULL,
    unit_id BIGINT NOT NULL REFERENCES unit (unit_id),
    direction TEXT NOT NULL CHECK (
        direction IN ('N', 'E', 'S', 'W', 'C')
    ),
    report_type TEXT NOT NULL CHECK (
        report_type IN ('SITREP', 'SPOTREP', 'LOGREP')
    ),
    severity SMALLINT NOT NULL CHECK (severity BETWEEN 1 AND 5),
    summary TEXT NOT NULL
);

CREATE TABLE report_item (
    item_id BIGSERIAL PRIMARY KEY,
    report_id BIGINT NOT NULL REFERENCES report (report_id) ON DELETE CASCADE,
    metric TEXT NOT NULL CHECK (
        metric IN (
            'engagements',
            'enemy_kia',
            'enemy_eq',
            'drone_mentions',
            'ew_mentions'
        )
    ),
    value INT NOT NULL CHECK (value >= 0)
);

CREATE INDEX report_date_idx ON report (report_date);

CREATE INDEX report_dt_idx ON report (report_dt);

CREATE INDEX report_unit_dt_idx ON report (unit_id, report_dt DESC);

CREATE INDEX report_item_report_idx ON report_item (report_id);

CREATE INDEX report_item_metric_idx ON report_item (metric);

INSERT INTO
    unit (unit_code, unit_name)
VALUES ('U-03BN', '3-й батальйон'),
    ('U-07BN', '7-й батальйон'),
    ('U-12BN', '12-й батальйон'),
    ('U-21CO', '21-ша рота'),
    ('U-05CO', '5-та рота');

WITH
    u AS (
        SELECT unit_id
        FROM unit
    ),
    r AS (
        INSERT INTO
            report (
                report_date,
                report_dt,
                unit_id,
                direction,
                report_type,
                severity,
                summary
            )
        SELECT (dt)::date,
            dt,
            (
                SELECT unit_id
                FROM u
                ORDER BY random()
                LIMIT 1
            ),
            (
                ARRAY['N', 'E', 'S', 'W', 'C']
            ) [1 + (random() * 4)::int],
            (
                ARRAY['SITREP', 'SPOTREP', 'LOGREP']
            ) [1 + (random() * 2)::int],
            1 + (random() * 4)::int,
            'Report #' || gs::text || ' | key points generated'
        FROM (
                SELECT gs, now() - (
                        random() * interval '3 months'
                    ) AS dt
                FROM generate_series(1, 20000) gs
            ) x
        RETURNING
            report_id,
            severity
    )
INSERT INTO
    report_item (report_id, metric, value)
SELECT
    r.report_id,
    m.metric,
    CASE m.metric
        WHEN 'engagements' THEN (
            r.severity * (1 + (random() * 5)::int)
        )
        WHEN 'enemy_kia' THEN (
            r.severity * (random() * 12)::int
        )
        WHEN 'enemy_eq' THEN (
            r.severity * (random() * 6)::int
        )
        WHEN 'drone_mentions' THEN ((random() * 10)::int)
        WHEN 'ew_mentions' THEN ((random() * 8)::int)
    END
FROM r
    CROSS JOIN (
        VALUES ('engagements'), ('enemy_kia'), ('enemy_eq'), ('drone_mentions'), ('ew_mentions')
    ) AS m (metric);

COMMIT;