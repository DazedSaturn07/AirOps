USE airops360;

-- Additive components. COUNT(CASE...) returns zero rather than counting NULL outcomes.
CREATE OR REPLACE VIEW mart_kpi_components AS
SELECT COUNT(*) AS scheduled_flights,
       COUNT(CASE WHEN cancelled = 1 THEN 1 END) AS cancelled_flights,
       COUNT(CASE WHEN diverted = 1 THEN 1 END) AS diverted_flights,
       COUNT(CASE WHEN cancelled = 0 AND diverted = 0 AND arrival_delay_minutes IS NOT NULL THEN 1 END) AS arrived_flights,
       COUNT(CASE WHEN cancelled = 0 AND diverted = 0 AND arrival_delay_minutes <= 15 THEN 1 END) AS on_time_arrivals,
       COUNT(CASE WHEN cancelled = 0 AND diverted = 0 AND arrival_delay_minutes > 15 THEN 1 END) AS delay_over_15_flights,
       COUNT(CASE WHEN cancelled = 0 AND diverted = 0 AND arrival_delay_minutes > 60 THEN 1 END) AS severe_delay_flights,
       COALESCE(SUM(CASE WHEN cancelled = 0 AND diverted = 0 THEN arrival_delay_minutes END), 0) AS arrival_delay_minutes,
       COUNT(CASE WHEN cancelled = 0 AND diverted = 0 AND arrival_delay_minutes IS NOT NULL THEN 1 END) AS arrival_delay_non_null_flights,
       COALESCE(SUM(air_system_delay_minutes), 0) AS air_system_delay_minutes,
       COALESCE(SUM(security_delay_minutes), 0) AS security_delay_minutes,
       COALESCE(SUM(airline_delay_minutes), 0) AS airline_delay_minutes,
       COALESCE(SUM(late_aircraft_delay_minutes), 0) AS late_aircraft_delay_minutes,
       COALESCE(SUM(weather_delay_minutes), 0) AS weather_delay_minutes
FROM fact_flight;

CREATE OR REPLACE VIEW mart_kpi_summary AS
SELECT c.*,
       1.0E0 * on_time_arrivals / NULLIF(arrived_flights, 0) AS on_time_arrival_rate,
       1.0E0 * arrival_delay_minutes / NULLIF(arrived_flights, 0) AS average_arrival_delay_minutes,
       1.0E0 * delay_over_15_flights / NULLIF(arrived_flights, 0) AS delay_over_15_rate,
       1.0E0 * severe_delay_flights / NULLIF(arrived_flights, 0) AS severe_delay_rate,
       1.0E0 * cancelled_flights / NULLIF(scheduled_flights, 0) AS cancellation_rate,
       1.0E0 * diverted_flights / NULLIF(scheduled_flights, 0) AS diversion_rate,
       GREATEST(0, 100 - 50 * 1.0E0 * delay_over_15_flights / NULLIF(arrived_flights, 0)
                           - 50 * 1.0E0 * cancelled_flights / NULLIF(scheduled_flights, 0)) AS route_reliability_index
FROM mart_kpi_components c;

CREATE OR REPLACE VIEW mart_route_performance AS
SELECT route_code, airline_code, flight_date,
       COUNT(*) AS scheduled_flights,
       COUNT(CASE WHEN cancelled = 1 THEN 1 END) AS cancelled_flights,
       COUNT(CASE WHEN diverted = 1 THEN 1 END) AS diverted_flights,
       COUNT(CASE WHEN cancelled = 0 AND diverted = 0 AND arrival_delay_minutes IS NOT NULL THEN 1 END) AS arrived_flights,
       COUNT(CASE WHEN cancelled = 0 AND diverted = 0 AND arrival_delay_minutes > 15 THEN 1 END) AS late_flights,
       COUNT(CASE WHEN cancelled = 0 AND diverted = 0 AND arrival_delay_minutes > 60 THEN 1 END) AS severe_delay_flights,
       1.0E0 * SUM(cancelled = 1) / NULLIF(COUNT(*), 0) AS cancellation_rate,
       1.0E0 * SUM(cancelled = 0 AND diverted = 0 AND arrival_delay_minutes > 15)
           / NULLIF(SUM(cancelled = 0 AND diverted = 0 AND arrival_delay_minutes IS NOT NULL), 0) AS delay_over_15_rate
FROM fact_flight
GROUP BY route_code, airline_code, flight_date;

CREATE OR REPLACE VIEW mart_exceptions AS
SELECT flight_key, flight_date, airline_code, route_code, arrival_delay_minutes,
       cancelled, diverted, delay_bucket
FROM fact_flight
WHERE cancelled = 1 OR diverted = 1 OR arrival_delay_minutes > 60 OR flight_date IS NULL;

-- Same independent SQL definitions for the Excel validation sample.
CREATE OR REPLACE VIEW mart_sample_kpi_components AS
SELECT COUNT(*) AS scheduled_flights,
       COUNT(CASE WHEN cancelled = 1 THEN 1 END) AS cancelled_flights,
       COUNT(CASE WHEN diverted = 1 THEN 1 END) AS diverted_flights,
       COUNT(CASE WHEN cancelled = 0 AND diverted = 0 AND arrival_delay_minutes IS NOT NULL THEN 1 END) AS arrived_flights,
       COUNT(CASE WHEN cancelled = 0 AND diverted = 0 AND arrival_delay_minutes <= 15 THEN 1 END) AS on_time_arrivals,
       COUNT(CASE WHEN cancelled = 0 AND diverted = 0 AND arrival_delay_minutes > 15 THEN 1 END) AS delay_over_15_flights,
       COUNT(CASE WHEN cancelled = 0 AND diverted = 0 AND arrival_delay_minutes > 60 THEN 1 END) AS severe_delay_flights,
       COALESCE(SUM(CASE WHEN cancelled = 0 AND diverted = 0 THEN arrival_delay_minutes END), 0) AS arrival_delay_minutes,
       COUNT(CASE WHEN cancelled = 0 AND diverted = 0 AND arrival_delay_minutes IS NOT NULL THEN 1 END) AS arrival_delay_non_null_flights,
       COALESCE(SUM(air_system_delay_minutes), 0) AS air_system_delay_minutes,
       COALESCE(SUM(security_delay_minutes), 0) AS security_delay_minutes,
       COALESCE(SUM(airline_delay_minutes), 0) AS airline_delay_minutes,
       COALESCE(SUM(late_aircraft_delay_minutes), 0) AS late_aircraft_delay_minutes,
       COALESCE(SUM(weather_delay_minutes), 0) AS weather_delay_minutes
FROM validation_sample;

CREATE OR REPLACE VIEW mart_sample_kpi_summary AS
SELECT c.*,
       1.0E0 * on_time_arrivals / NULLIF(arrived_flights, 0) AS on_time_arrival_rate,
       1.0E0 * arrival_delay_minutes / NULLIF(arrived_flights, 0) AS average_arrival_delay_minutes,
       1.0E0 * delay_over_15_flights / NULLIF(arrived_flights, 0) AS delay_over_15_rate,
       1.0E0 * severe_delay_flights / NULLIF(arrived_flights, 0) AS severe_delay_rate,
       1.0E0 * cancelled_flights / NULLIF(scheduled_flights, 0) AS cancellation_rate,
       1.0E0 * diverted_flights / NULLIF(scheduled_flights, 0) AS diversion_rate,
       GREATEST(0, 100 - 50 * 1.0E0 * delay_over_15_flights / NULLIF(arrived_flights, 0)
                           - 50 * 1.0E0 * cancelled_flights / NULLIF(scheduled_flights, 0)) AS route_reliability_index
FROM mart_sample_kpi_components c;
