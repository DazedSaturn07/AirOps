-- MySQL 8+. Run in a local non-production analytics database.
CREATE DATABASE IF NOT EXISTS airops360 CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE airops360;

CREATE TABLE IF NOT EXISTS stg_flight (
    flight_key VARCHAR(300) PRIMARY KEY,
    source_row_number BIGINT NOT NULL UNIQUE,
    flight_date DATE NULL,
    airline_code VARCHAR(8) NULL,
    flight_number VARCHAR(16) NULL,
    tail_number VARCHAR(16) NULL,
    candidate_operational_key VARCHAR(260) NOT NULL,
    origin_airport_code VARCHAR(8) NULL,
    destination_airport_code VARCHAR(8) NULL,
    scheduled_departure_hhmm CHAR(4) NULL,
    arrival_delay_minutes DECIMAL(10,2) NULL,
    departure_delay_minutes DECIMAL(10,2) NULL,
    cancelled TINYINT NOT NULL,
    diverted TINYINT NOT NULL,
    cancellation_reason_code VARCHAR(8) NULL,
    air_system_delay_minutes DECIMAL(10,2) NOT NULL,
    security_delay_minutes DECIMAL(10,2) NOT NULL,
    airline_delay_minutes DECIMAL(10,2) NOT NULL,
    late_aircraft_delay_minutes DECIMAL(10,2) NOT NULL,
    weather_delay_minutes DECIMAL(10,2) NOT NULL,
    route_code VARCHAR(20) NULL,
    departure_hour TINYINT NULL,
    peak_period TINYINT NULL,
    delay_bucket VARCHAR(32) NULL,
    KEY idx_stg_flight_date_airline (flight_date, airline_code),
    KEY idx_stg_flight_route (route_code),
    KEY idx_stg_flight_origin_destination (origin_airport_code, destination_airport_code)
);

-- Same columns for the deterministic Excel validation sample.
CREATE TABLE IF NOT EXISTS validation_sample LIKE stg_flight;
