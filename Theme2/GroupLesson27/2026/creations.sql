BEGIN;

CREATE SCHEMA IF NOT EXISTS oiaz_train;

SET search_path = oiaz_train, public;

DROP TABLE IF EXISTS report_item;

DROP TABLE IF EXISTS report;

DROP TABLE IF EXISTS unit;

CREATE TABLE unit (
    unit_id BIGSERIAL PRIMARY KEY,
    unit_code TEXT NOT NULL UNIQUE,
    unit_name TEXT NOT NULL
);

CREATE TABLE report (
    report_id BIGSERIAL PRIMARY KEY,
    report_date DATE NOT NULL,
    unit_id BIGINT NOT NULL REFERENCES unit (unit_id),
    report_type TEXT NOT NULL CHECK (
        report_type IN ('SITREP', 'SPOTREP')
    ),
    severity SMALLINT NOT NULL CHECK (severity BETWEEN 1 AND 5)
);

CREATE TABLE report_item (
    item_id BIGSERIAL PRIMARY KEY,
    report_id BIGINT NOT NULL REFERENCES report (report_id) ON DELETE CASCADE,
    metric TEXT NOT NULL CHECK (
        metric IN ('engagements', 'enemy_kia')
    ),
    value INT NOT NULL CHECK (value >= 0)
);

CREATE INDEX report_date_idx ON report (report_date);

CREATE INDEX report_unit_date_idx ON report (unit_id, report_date DESC);

CREATE INDEX report_item_report_idx ON report_item (report_id);

CREATE INDEX report_item_metric_idx ON report_item (metric);

INSERT INTO
    unit (unit_code, unit_name)
VALUES (
        'TR-01',
        'Навчальний підрозділ 1'
    ),
    (
        'TR-02',
        'Навчальний підрозділ 2'
    ),
    (
        'TR-03',
        'Навчальний підрозділ 3'
    )
ON CONFLICT (unit_code) DO NOTHING;

WITH
    u AS (
        SELECT unit_id
        FROM unit
    ),
    r AS (
        INSERT INTO
            report (
                report_date,
                unit_id,
                report_type,
                severity
            )
        SELECT (
                now() - (random() * interval '30 days')
            )::date, (
                SELECT unit_id
                FROM u
                ORDER BY random()
                LIMIT 1
            ), (ARRAY['SITREP', 'SPOTREP']) [1 + (random() * 1)::int], 1 + (random() * 4)::int
        FROM generate_series(1, 3000)
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
            r.severity * (1 + (random() * 4)::int)
        )
        WHEN 'enemy_kia' THEN (
            r.severity * (random() * 6)::int
        )
    END
FROM r
    CROSS JOIN (
        VALUES ('engagements'), ('enemy_kia')
    ) AS m (metric);

COMMIT;