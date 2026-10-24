USE airops360;

-- No data is removed by these checks. Duplicate candidates are retained.
SELECT
 COUNT(*) AS scheduled_flights,
 COUNT(*) - COUNT(DISTINCT flight_key) AS duplicate_flight_keys,
 COUNT(*) - COUNT(DISTINCT source_row_number) AS duplicate_source_rows,
 COUNT(CASE WHEN flight_date IS NULL OR cancelled NOT IN (0,1) OR diverted NOT IN (0,1) THEN 1 END) AS invalid_rows,
 COUNT(CASE WHEN cancelled = 0 AND diverted = 0 AND arrival_delay_minutes IS NULL THEN 1 END) AS missing_eligible_outcomes,
 COUNT(CASE WHEN (cancelled = 1 OR diverted = 1 OR arrival_delay_minutes IS NULL) AND delay_bucket IS NOT NULL THEN 1 END) AS invalid_delay_buckets,
 COUNT(CASE WHEN origin_airport_code REGEXP '^[0-9]+$' THEN 1 END) AS numeric_origin_rows,
 COUNT(*) - COUNT(DISTINCT candidate_operational_key) AS repeated_candidate_rows
FROM fact_flight;

SELECT * FROM mart_kpi_summary;
SELECT * FROM mart_sample_kpi_summary;

-- Aggregate equal delay values before the median window, avoiding a 5.7M-row sort.
WITH frequencies AS (
 SELECT arrival_delay_minutes, COUNT(*) AS frequency
 FROM fact_flight
 WHERE cancelled = 0 AND diverted = 0 AND arrival_delay_minutes IS NOT NULL
 GROUP BY arrival_delay_minutes
), ranked AS (
 SELECT arrival_delay_minutes,
        SUM(frequency) OVER (ORDER BY arrival_delay_minutes) AS cumulative_count,
        SUM(frequency) OVER () AS population_size
 FROM frequencies
)
SELECT (
 MIN(CASE WHEN cumulative_count >= FLOOR((population_size + 1)/2) THEN arrival_delay_minutes END) +
 MIN(CASE WHEN cumulative_count >= FLOOR((population_size + 2)/2) THEN arrival_delay_minutes END)
)/2 AS median_arrival_delay_minutes
FROM ranked;

WITH frequencies AS (
 SELECT arrival_delay_minutes, COUNT(*) AS frequency
 FROM validation_sample
 WHERE cancelled = 0 AND diverted = 0 AND arrival_delay_minutes IS NOT NULL
 GROUP BY arrival_delay_minutes
), ranked AS (
 SELECT arrival_delay_minutes,
        SUM(frequency) OVER (ORDER BY arrival_delay_minutes) AS cumulative_count,
        SUM(frequency) OVER () AS population_size
 FROM frequencies
)
SELECT (
 MIN(CASE WHEN cumulative_count >= FLOOR((population_size + 1)/2) THEN arrival_delay_minutes END) +
 MIN(CASE WHEN cumulative_count >= FLOOR((population_size + 2)/2) THEN arrival_delay_minutes END)
)/2 AS median_arrival_delay_minutes
FROM ranked;

SELECT candidate_operational_key, COUNT(*) AS occurrences
FROM fact_flight
GROUP BY candidate_operational_key
HAVING COUNT(*) > 1
ORDER BY occurrences DESC
LIMIT 20;
