USE airops360;

-- 1. Carrier comparison. Rates use their eligible arrival populations.
SELECT airline_code, COUNT(*) AS scheduled_flights,
 COUNT(CASE WHEN cancelled = 0 AND diverted = 0 AND arrival_delay_minutes IS NOT NULL THEN 1 END) AS arrived_flights,
 1.0E0 * COUNT(CASE WHEN cancelled = 0 AND diverted = 0 AND arrival_delay_minutes <= 15 THEN 1 END) /
NULLIF(COUNT(CASE WHEN cancelled = 0 AND diverted = 0 AND arrival_delay_minutes IS NOT NULL THEN 1 END),0) AS on_time_arrival_rate,
 1.0E0 * COUNT(CASE WHEN cancelled = 1 THEN 1 END) /
COUNT(*) AS cancellation_rate
FROM fact_flight
GROUP BY airline_code
ORDER BY on_time_arrival_rate;

-- 2. Investigation candidates. Source-code routes are not fully harmonized physical routes.
SELECT route_code, COUNT(*) AS scheduled_flights,
 COUNT(CASE WHEN cancelled = 0 AND diverted = 0 AND arrival_delay_minutes IS NOT NULL THEN 1 END) AS arrived_flights,
 1.0E0 * COUNT(CASE WHEN cancelled = 0 AND diverted = 0 AND arrival_delay_minutes > 15 THEN 1 END) /
NULLIF(COUNT(CASE WHEN cancelled = 0 AND diverted = 0 AND arrival_delay_minutes IS NOT NULL THEN 1 END),0) AS delay_over_15_rate,
 1.0E0 * COUNT(CASE WHEN cancelled = 1 THEN 1 END) /
COUNT(*) AS cancellation_rate
-- EXPLAIN showed a slow secondary-index walk for this full-population grouping.
-- The fact view is SELECT * from this same staging table. Scan its clustered rows.
FROM stg_flight FORCE INDEX (PRIMARY)
GROUP BY route_code
HAVING COUNT(*) >= 1000 AND arrived_flights > 0
ORDER BY delay_over_15_rate DESC
LIMIT 50;

-- 3. Monthly trend and numeric identifier coverage.
SELECT MONTH(flight_date) AS month, COUNT(*) AS scheduled_flights,
 COUNT(CASE WHEN origin_airport_code REGEXP '^[0-9]+$' THEN 1 END) AS numeric_origin_rows,
 COUNT(CASE WHEN cancelled = 0 AND diverted = 0 AND arrival_delay_minutes IS NOT NULL THEN 1 END) AS arrived_flights,
 1.0E0 * COUNT(CASE WHEN cancelled = 0 AND diverted = 0 AND arrival_delay_minutes <= 15 THEN 1 END) /
NULLIF(COUNT(CASE WHEN cancelled = 0 AND diverted = 0 AND arrival_delay_minutes IS NOT NULL THEN 1 END),0) AS on_time_arrival_rate,
 1.0E0 * COUNT(CASE WHEN cancelled = 1 THEN 1 END) /
COUNT(*) AS cancellation_rate
FROM fact_flight
GROUP BY MONTH(flight_date)
ORDER BY month;

-- 4. Scheduled local departure hour.
SELECT departure_hour, COUNT(*) AS scheduled_flights,
 COUNT(CASE WHEN cancelled = 0 AND diverted = 0 AND arrival_delay_minutes IS NOT NULL THEN 1 END) AS arrived_flights,
 AVG(CASE WHEN cancelled = 0 AND diverted = 0 THEN arrival_delay_minutes END) AS average_arrival_delay_minutes
FROM fact_flight
GROUP BY departure_hour
ORDER BY departure_hour;

-- 5. Recorded attribution, not causal proof.
SELECT airline_code,
 SUM(air_system_delay_minutes) AS air_system_attributed_minutes,
 SUM(security_delay_minutes) AS security_attributed_minutes,
 SUM(airline_delay_minutes) AS airline_attributed_minutes,
 SUM(late_aircraft_delay_minutes) AS late_aircraft_attributed_minutes,
 SUM(weather_delay_minutes) AS weather_attributed_minutes
FROM fact_flight
GROUP BY airline_code
ORDER BY weather_attributed_minutes + late_aircraft_attributed_minutes DESC;
