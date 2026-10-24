-- Run from the repository root after checking that the destination is empty.
-- sql/run_sql.py resolves these relative filenames to absolute paths automatically.
USE airops360;
SELECT COUNT(*) AS existing_rows FROM stg_flight;

LOAD DATA LOCAL INFILE 'notebooks/data/processed/fact_flight.tsv'
INTO TABLE stg_flight
CHARACTER SET utf8mb4
FIELDS TERMINATED BY '\t' ESCAPED BY '\\'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(source_row_number,
 flight_date,
 airline_code,
 flight_number,
 tail_number,
 origin_airport_code,
 destination_airport_code,
 scheduled_departure_hhmm,
 arrival_delay_minutes,
 departure_delay_minutes,
 cancelled,
 diverted,
 cancellation_reason_code,
 air_system_delay_minutes,
 security_delay_minutes,
 airline_delay_minutes,
 late_aircraft_delay_minutes,
 weather_delay_minutes,
 route_code,
 departure_hour,
 peak_period,
 delay_bucket,
 candidate_operational_key,
 flight_key);
SHOW WARNINGS;
SELECT COUNT(*) AS loaded_rows FROM stg_flight;

-- Initial sample load only. The helper skips populated tables after content checks.
LOAD DATA LOCAL INFILE 'notebooks/data/processed/validation_sample.tsv'
INTO TABLE validation_sample
CHARACTER SET utf8mb4
FIELDS TERMINATED BY '\t' ESCAPED BY '\\'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(source_row_number, flight_date, airline_code, flight_number, tail_number,
 origin_airport_code, destination_airport_code, scheduled_departure_hhmm,
 arrival_delay_minutes, departure_delay_minutes, cancelled, diverted,
 cancellation_reason_code, air_system_delay_minutes, security_delay_minutes,
 airline_delay_minutes, late_aircraft_delay_minutes, weather_delay_minutes,
 route_code, departure_hour, peak_period, delay_bucket, candidate_operational_key, flight_key);
SHOW WARNINGS;
SELECT COUNT(*) AS sample_rows FROM validation_sample;
