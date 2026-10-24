USE airops360;

CREATE OR REPLACE VIEW dim_date AS
SELECT DISTINCT flight_date,
       YEAR(flight_date) AS calendar_year,
       MONTH(flight_date) AS calendar_month,
       QUARTER(flight_date) AS calendar_quarter
FROM stg_flight
WHERE flight_date IS NOT NULL;

CREATE OR REPLACE VIEW dim_airline AS
SELECT DISTINCT airline_code FROM stg_flight WHERE airline_code IS NOT NULL;

CREATE OR REPLACE VIEW dim_route AS
SELECT DISTINCT route_code, origin_airport_code, destination_airport_code
FROM stg_flight WHERE route_code IS NOT NULL;

CREATE OR REPLACE VIEW fact_flight AS
SELECT * FROM stg_flight;
