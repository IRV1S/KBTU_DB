\set ON_ERROR_STOP on
\c postgres

DROP DATABASE IF EXISTS citybike_lab WITH (FORCE);
CREATE DATABASE citybike_lab;

\c citybike_lab

CREATE PROCEDURE expect_error(expected_state text, stmt text)
LANGUAGE plpgsql
AS $$
DECLARE
    v_state  text;
    v_detail text;
    v_hint   text;
BEGIN
    EXECUTE stmt;
    RAISE EXCEPTION 'statement succeeded, expected SQLSTATE %', expected_state
        USING DETAIL = stmt;
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS
            v_state  = RETURNED_SQLSTATE,
            v_detail = PG_EXCEPTION_DETAIL,
            v_hint   = PG_EXCEPTION_HINT;
        IF v_state IS DISTINCT FROM expected_state THEN
            RAISE;
        END IF;
        RAISE NOTICE '[%] ERROR:  %', v_state, SQLERRM
            || CASE WHEN v_detail <> '' THEN E'\nDETAIL:  ' || v_detail ELSE '' END
            || CASE WHEN v_hint <> '' THEN E'\nHINT:  ' || v_hint ELSE '' END;
END
$$;

\echo '=== Part 1: Database Setup ==='

CREATE TABLE stations (
    station_id   INT PRIMARY KEY,
    station_name VARCHAR(50) NOT NULL,
    city         VARCHAR(40) NOT NULL,
    capacity     INT NOT NULL
);

CREATE TABLE bikes (
    bike_id    INT PRIMARY KEY,
    model      VARCHAR(50) NOT NULL,
    station_id INT REFERENCES stations (station_id),
    daily_rate NUMERIC(8, 2) NOT NULL
);

CREATE TABLE members (
    member_id INT PRIMARY KEY,
    full_name VARCHAR(60) NOT NULL,
    city      VARCHAR(40) NOT NULL,
    joined_on DATE NOT NULL
);

CREATE TABLE rentals (
    rental_id  INT PRIMARY KEY,
    member_id  INT REFERENCES members (member_id),
    bike_id    INT REFERENCES bikes (bike_id),
    start_date DATE NOT NULL,
    end_date   DATE,
    fee        NUMERIC(8, 2)
);

INSERT INTO stations VALUES
    (10, 'Central Park', 'Almaty',   4),
    (20, 'Riverside',    'Almaty',   3),
    (30, 'Expo Gate',    'Astana',   5),
    (40, 'Old Town',     'Shymkent', 2),
    (50, 'Depot',        'Astana',   0);

INSERT INTO bikes VALUES
    (101, 'City Cruiser', 10,  4.50),
    (102, 'City Cruiser', 10,  4.50),
    (103, 'Mountain X',   20,  7.00),
    (104, 'Mountain X',   30,  7.00),
    (105, 'Road Sprint',  30,  9.25),
    (106, 'Folding Mini', 40,  3.75),
    (107, 'Cargo Hauler', 20, 12.00),
    (108, 'Road Sprint',  10,  9.25);

INSERT INTO members VALUES
    (1, 'Aisha Nurlanova', 'Almaty',   DATE '2023-03-14'),
    (2, 'Daniyar Serik',   'Almaty',   DATE '2023-07-02'),
    (3, 'Marta Kowalski',  'Astana',   DATE '2024-01-20'),
    (4, 'Chen Wei',        'Astana',   DATE '2024-05-11'),
    (5, 'Omar Haddad',     'Shymkent', DATE '2024-09-30'),
    (6, 'Elena Petrova',   'Almaty',   DATE '2025-02-05');

INSERT INTO rentals VALUES
    ( 1, 1, 101, DATE '2024-04-05', DATE '2024-04-08', 13.50),
    ( 2, 1, 103, DATE '2024-06-11', DATE '2024-06-16', 35.00),
    ( 3, 1, 108, DATE '2025-02-02', DATE '2025-02-04', 18.50),
    ( 4, 1, 102, DATE '2025-05-20', DATE '2025-05-27', 31.50),
    ( 5, 2, 101, DATE '2024-05-01', DATE '2024-05-02',  4.50),
    ( 6, 2, 107, DATE '2024-11-15', DATE '2024-11-19', 48.00),
    ( 7, 2, 107, DATE '2025-03-08', DATE '2025-03-14', 72.00),
    ( 8, 3, 104, DATE '2024-02-14', DATE '2024-02-18', 28.00),
    ( 9, 3, 105, DATE '2024-08-03', DATE '2024-08-06', 27.75),
    (10, 3, 104, DATE '2025-01-09', DATE '2025-01-10',  7.00),
    (11, 3, 105, DATE '2025-06-01', DATE '2025-06-09', 74.00),
    (12, 4, 104, DATE '2024-07-19', DATE '2024-07-21', 14.00),
    (13, 4, 105, DATE '2025-04-12', DATE '2025-04-15', 27.75),
    (14, 4, 103, DATE '2025-07-23', DATE '2025-07-29', 42.00),
    (15, 5, 106, DATE '2024-10-05', DATE '2024-10-12', 26.25),
    (16, 5, 106, DATE '2025-01-18', DATE '2025-01-20',  7.50),
    (17, 5, 106, DATE '2025-08-14', DATE '2025-08-21', 26.25),
    (18, 2, 102, DATE '2025-09-02', DATE '2025-09-05', 13.50),
    (19, 1, 101, DATE '2025-10-10', NULL,              NULL),
    (20, 4, 108, DATE '2024-12-28', DATE '2025-01-03', 55.50),
    (21, 3, 103, DATE '2025-02-26', DATE '2025-03-02', 28.00),
    (22, 5, 104, DATE '2025-05-05', DATE '2025-05-08', 21.00);

SELECT (SELECT COUNT(*) FROM stations) AS stations,
       (SELECT COUNT(*) FROM bikes)    AS bikes,
       (SELECT COUNT(*) FROM members)  AS members,
       (SELECT COUNT(*) FROM rentals)  AS rentals;

\echo '=== Part 2: Worked example inc() ==='

CREATE OR REPLACE FUNCTION inc(val INTEGER) RETURNS INTEGER AS $$
DECLARE
    result INTEGER;
BEGIN
    result := val + 1;
    RETURN result;
END; $$
LANGUAGE plpgsql;

SELECT inc(10);

\echo '=== Exercise 2.1: A function over one row ==='

CREATE OR REPLACE FUNCTION rental_days(p_rental_id INT) RETURNS INT AS $$
DECLARE
    v_days INT;
BEGIN
    SELECT end_date - start_date
    INTO v_days
    FROM rentals
    WHERE rental_id = p_rental_id;
    RETURN v_days;
END; $$
LANGUAGE plpgsql;

SELECT rental_days(2);
SELECT rental_days(11);
SELECT rental_days(19);
SELECT rental_days(999);

SELECT v.rental_id,
       rental_days(v.rental_id) AS days,
       EXISTS (SELECT 1 FROM rentals r WHERE r.rental_id = v.rental_id) AS rental_exists
FROM (VALUES (19), (999)) AS v(rental_id);

\echo '=== Exercise 2.2: A function over many rows ==='

CREATE OR REPLACE FUNCTION member_rental_count(p_member_id INT) RETURNS INT AS $$
DECLARE
    v_count INT;
BEGIN
    SELECT COUNT(*)
    INTO v_count
    FROM rentals
    WHERE member_id = p_member_id;
    RETURN v_count;
END; $$
LANGUAGE plpgsql;

SELECT v.member_id, member_rental_count(v.member_id) AS rental_count
FROM (VALUES (1), (5), (6), (99)) AS v(member_id);

\echo '=== Exercise 2.3: Returning text ==='

CREATE OR REPLACE FUNCTION station_city(p_station_id INT) RETURNS VARCHAR AS $$
DECLARE
    v_city VARCHAR;
BEGIN
    SELECT city
    INTO v_city
    FROM stations
    WHERE station_id = p_station_id;
    RETURN v_city;
END; $$
LANGUAGE plpgsql;

SELECT station_city(30);
SELECT station_city(77);

\echo '=== Exercise 2.4: Using a function inside a query ==='

SELECT rental_id, member_id, rental_days(rental_id) AS days
FROM rentals
WHERE rental_days(rental_id) > 4
ORDER BY days DESC, rental_id;

\echo '=== Exercise 3.1: IN parameters ==='

CREATE OR REPLACE FUNCTION fee_with_discount(p_fee NUMERIC, p_percent NUMERIC) RETURNS NUMERIC AS $$
BEGIN
    RETURN ROUND(p_fee * (1 - p_percent / 100), 2);
END; $$
LANGUAGE plpgsql;

SELECT fee_with_discount(74.00, 15);

\echo '=== Exercise 3.2: OUT parameters ==='

CREATE OR REPLACE FUNCTION member_stats(
    p_member_id    INT,
    OUT rental_cnt INT,
    OUT total_fee  NUMERIC,
    OUT last_start DATE)
AS $$
BEGIN
    SELECT COUNT(*), COALESCE(SUM(fee), 0), MAX(start_date)
    INTO rental_cnt, total_fee, last_start
    FROM rentals
    WHERE member_id = p_member_id;
END; $$
LANGUAGE plpgsql;

SELECT member_stats(3);
SELECT * FROM member_stats(3);
SELECT * FROM member_stats(6);

\echo '=== Exercise 3.3: INOUT parameters ==='

CREATE OR REPLACE FUNCTION apply_late_fee(INOUT p_fee NUMERIC) AS $$
BEGIN
    p_fee := p_fee + 5.00;
END; $$
LANGUAGE plpgsql;

SELECT fee AS original_fee, apply_late_fee(fee) AS with_late_fee
FROM rentals
WHERE rental_id = 1;

\echo '=== Exercise 3.4: VARIADIC parameters ==='

CREATE OR REPLACE FUNCTION fee_summary(
    VARIADIC p_fees NUMERIC[],
    OUT total   NUMERIC,
    OUT average NUMERIC,
    OUT largest NUMERIC)
AS $$
BEGIN
    SELECT SUM(p_fees[i]), ROUND(AVG(p_fees[i]), 2), MAX(p_fees[i])
    INTO total, average, largest
    FROM generate_subscripts(p_fees, 1) AS g(i);
END; $$
LANGUAGE plpgsql;

SELECT * FROM fee_summary(13.50, 35.00, 18.50, 31.50);

SELECT * FROM fee_summary(VARIADIC ARRAY(
    SELECT fee FROM rentals WHERE member_id = 1 AND fee IS NOT NULL
));

CALL expect_error('42883', $$SELECT * FROM fee_summary()$$);

SELECT * FROM fee_summary(VARIADIC ARRAY[]::NUMERIC[]);

\echo '=== Exercise 4.1: A function with one parameter ==='

CREATE OR REPLACE FUNCTION total_fees(p_member_id INT) RETURNS NUMERIC AS $$
DECLARE
    v_total NUMERIC;
BEGIN
    SELECT COALESCE(SUM(fee), 0)
    INTO v_total
    FROM rentals
    WHERE member_id = p_member_id;
    RETURN v_total;
END; $$
LANGUAGE plpgsql;

SELECT total_fees(1);
SELECT total_fees(6);

\echo '=== Exercise 4.2: Overloading the name ==='

CREATE OR REPLACE FUNCTION total_fees(p_member_id INT, p_from_date DATE)
RETURNS NUMERIC AS $$
DECLARE
    v_total NUMERIC;
BEGIN
    SELECT COALESCE(SUM(fee), 0)
    INTO v_total
    FROM rentals
    WHERE member_id = p_member_id
      AND start_date >= p_from_date;
    RETURN v_total;
END; $$
LANGUAGE plpgsql;

SELECT total_fees(1, DATE '2024-01-01');
SELECT total_fees(1, DATE '2025-01-01');

\df total_fees

SELECT oid::regprocedure AS signature, pg_get_function_result(oid) AS returns
FROM pg_proc
WHERE proname = 'total_fees'
ORDER BY oid;

\echo '=== Exercise 4.3: Giving a parameter a default value ==='

CREATE OR REPLACE FUNCTION total_fees(p_member_id INT,
                                      p_from_date DATE DEFAULT DATE '2025-01-01')
RETURNS NUMERIC AS $$
DECLARE
    v_total NUMERIC;
BEGIN
    SELECT COALESCE(SUM(fee), 0)
    INTO v_total
    FROM rentals
    WHERE member_id = p_member_id
      AND start_date >= p_from_date;
    RETURN v_total;
END; $$
LANGUAGE plpgsql;

CALL expect_error('42725', $$SELECT total_fees(1)$$);

\echo '=== Exercise 4.4: Resolving the ambiguity ==='

CALL expect_error('42725', $$DROP FUNCTION total_fees$$);

DROP FUNCTION total_fees(INTEGER);

SELECT total_fees(1);

\echo '=== Exercise 4.5: Overloading on type, not just on count ==='

CREATE OR REPLACE FUNCTION total_fees(p_full_name VARCHAR) RETURNS NUMERIC AS $$
DECLARE
    v_total NUMERIC;
BEGIN
    SELECT COALESCE(SUM(r.fee), 0)
    INTO v_total
    FROM members m
    JOIN rentals r ON r.member_id = m.member_id
    WHERE m.full_name = p_full_name;
    RETURN v_total;
END; $$
LANGUAGE plpgsql;

SELECT total_fees('Aisha Nurlanova');
SELECT total_fees(1);

\df total_fees

\echo '=== Exercise 5.1: Search by pattern ==='

CREATE OR REPLACE FUNCTION find_bikes(p_pattern VARCHAR)
RETURNS TABLE (found_id INT, found_model VARCHAR, found_rate NUMERIC) AS $$
BEGIN
    RETURN QUERY
    SELECT b.bike_id, b.model, b.daily_rate
    FROM bikes b
    WHERE b.model ILIKE p_pattern
    ORDER BY b.bike_id;
END; $$
LANGUAGE plpgsql;

SELECT * FROM find_bikes('%road%');
SELECT * FROM find_bikes('%Mini');
SELECT find_bikes('%road%');

\echo '=== Exercise 5.2: A table from a join ==='

CREATE OR REPLACE FUNCTION member_history(p_member_id INT)
RETURNS TABLE (rental_no INT, bike_model VARCHAR, station VARCHAR, days INT, amount NUMERIC) AS $$
BEGIN
    RETURN QUERY
    SELECT r.rental_id, b.model, s.station_name, r.end_date - r.start_date, r.fee
    FROM rentals r
    JOIN bikes b ON b.bike_id = r.bike_id
    LEFT JOIN stations s ON s.station_id = b.station_id
    WHERE r.member_id = p_member_id
    ORDER BY r.start_date;
END; $$
LANGUAGE plpgsql;

SELECT * FROM member_history(3);

\echo '=== Exercise 5.3: When the column names collide ==='

CREATE OR REPLACE FUNCTION bike_list(p_station_id INT)
RETURNS TABLE (bike_id INT, model VARCHAR) AS $$
BEGIN
    RETURN QUERY SELECT bike_id, model FROM bikes WHERE station_id = p_station_id;
END; $$ LANGUAGE plpgsql;

CALL expect_error('42702', $$SELECT * FROM bike_list(10)$$);

CALL expect_error('42P13', $sql$
CREATE OR REPLACE FUNCTION bike_list(p_station_id INT)
RETURNS TABLE (out_bike_id INT, out_model VARCHAR) AS $$
BEGIN
    RETURN QUERY SELECT bike_id, model FROM bikes WHERE station_id = p_station_id;
END; $$ LANGUAGE plpgsql
$sql$);

DROP FUNCTION bike_list(INT);

CREATE FUNCTION bike_list(p_station_id INT)
RETURNS TABLE (out_bike_id INT, out_model VARCHAR) AS $$
BEGIN
    RETURN QUERY
    SELECT bike_id, model
    FROM bikes
    WHERE station_id = p_station_id
    ORDER BY bike_id;
END; $$ LANGUAGE plpgsql;

SELECT * FROM bike_list(10);

DROP FUNCTION bike_list(INT);

CREATE FUNCTION bike_list(p_station_id INT)
RETURNS TABLE (bike_id INT, model VARCHAR) AS $$
BEGIN
    RETURN QUERY
    SELECT b.bike_id, b.model
    FROM bikes b
    WHERE b.station_id = p_station_id
    ORDER BY b.bike_id;
END; $$ LANGUAGE plpgsql;

SELECT * FROM bike_list(10);

\echo '=== Exercise 5.4: Casting the output ==='

CREATE OR REPLACE FUNCTION station_board(p_city VARCHAR)
RETURNS TABLE (s_name VARCHAR, s_bikes INT, s_free INT) AS $$
BEGIN
    RETURN QUERY
    SELECT s.station_name,
           COUNT(b.bike_id),
           s.capacity - COUNT(b.bike_id)
    FROM stations s
    LEFT JOIN bikes b ON b.station_id = s.station_id
    WHERE s.city = p_city
    GROUP BY s.station_id, s.station_name, s.capacity
    ORDER BY s.station_name;
END; $$ LANGUAGE plpgsql;

CALL expect_error('42804', $$SELECT * FROM station_board('Almaty')$$);

CREATE OR REPLACE FUNCTION station_board(p_city VARCHAR)
RETURNS TABLE (s_name VARCHAR, s_bikes INT, s_free INT) AS $$
BEGIN
    RETURN QUERY
    SELECT s.station_name,
           COUNT(b.bike_id)::INT,
           (s.capacity - COUNT(b.bike_id))::INT
    FROM stations s
    LEFT JOIN bikes b ON b.station_id = s.station_id
    WHERE s.city = p_city
    GROUP BY s.station_id, s.station_name, s.capacity
    ORDER BY s.station_name;
END; $$ LANGUAGE plpgsql;

SELECT * FROM station_board('Almaty');
SELECT * FROM station_board('Astana');

\echo '=== Exercise 6.1: An anonymous block ==='

DO $$
<<rental_report>>
DECLARE
    total_rentals INTEGER := 0;
BEGIN
    SELECT COUNT(*) INTO total_rentals FROM rentals;
    RAISE NOTICE 'The rentals table holds % rows.', total_rentals;
END rental_report $$;

CALL expect_error('42601', $sql$
DO $$
<<rental_report>>
DECLARE
    total_rentals INTEGER := 0;
BEGIN
    SELECT COUNT(*) INTO total_rentals FROM rentals;
    RAISE NOTICE 'The rentals table holds % rows.', total_rentals;
END rental_summary $$
$sql$);

\echo '=== Exercise 6.2: A subblock and a hidden variable ==='

DO $$
<<rental_report>>
DECLARE
    total_rentals INTEGER := 0;
    fee_total     NUMERIC;
BEGIN
    SELECT COUNT(*) INTO total_rentals FROM rentals;
    RAISE NOTICE 'The rentals table holds % rows.', total_rentals;

    SELECT SUM(fee) INTO fee_total FROM rentals;
    RAISE NOTICE '1) outer fee_total before the subblock: %', fee_total;

    DECLARE
        fee_total NUMERIC;
    BEGIN
        SELECT SUM(fee) INTO fee_total
        FROM rentals
        WHERE start_date >= DATE '2025-01-01';
        RAISE NOTICE '2) subblock fee_total: %', fee_total;
        RAISE NOTICE '3) outer fee_total via label: %', rental_report.fee_total;
    END;

    RAISE NOTICE '4) outer fee_total after the subblock: %', fee_total;
END rental_report $$;

\echo '=== Exercise 6.3: Declarations are local ==='

CALL expect_error('42703', $sql$
DO $$
<<rental_report>>
DECLARE
    fee_total NUMERIC;
BEGIN
    SELECT SUM(fee) INTO fee_total FROM rentals;

    DECLARE
        recent_total NUMERIC;
    BEGIN
        SELECT SUM(fee) INTO recent_total
        FROM rentals
        WHERE start_date >= DATE '2025-01-01';
        RAISE NOTICE 'first subblock: recent_total = %', recent_total;
    END;

    BEGIN
        RAISE NOTICE 'second subblock: recent_total = %', recent_total;
    END;
END rental_report $$
$sql$);

DO $$
<<rental_report>>
DECLARE
    fee_total    NUMERIC;
    recent_total NUMERIC;
BEGIN
    SELECT SUM(fee) INTO fee_total FROM rentals;

    BEGIN
        SELECT SUM(fee) INTO recent_total
        FROM rentals
        WHERE start_date >= DATE '2025-01-01';
        RAISE NOTICE 'first subblock: recent_total = %', recent_total;
    END;

    BEGIN
        RAISE NOTICE 'second subblock: recent_total = % of %', recent_total, fee_total;
    END;
END rental_report $$;

\echo '=== Exercise 6.4: From a block to a function ==='

CREATE OR REPLACE FUNCTION fee_split(
    p_from_date      DATE,
    OUT before_total NUMERIC,
    OUT after_total  NUMERIC)
AS $$
BEGIN
    SELECT COALESCE(SUM(fee) FILTER (WHERE start_date <  p_from_date), 0),
           COALESCE(SUM(fee) FILTER (WHERE start_date >= p_from_date), 0)
    INTO before_total, after_total
    FROM rentals;
END; $$
LANGUAGE plpgsql;

SELECT f.before_total,
       f.after_total,
       f.before_total + f.after_total   AS sum_of_parts,
       (SELECT SUM(fee) FROM rentals)   AS table_total
FROM fee_split(DATE '2025-01-01') AS f;

\echo '=== Exercise 7.1: Station occupancy ==='

CREATE OR REPLACE FUNCTION station_load(
    p_station_id     INT,
    OUT bikes_parked INT,
    OUT capacity_pct NUMERIC)
AS $$
DECLARE
    v_capacity INT;
BEGIN
    SELECT capacity INTO v_capacity FROM stations WHERE station_id = p_station_id;

    SELECT COUNT(*) INTO bikes_parked FROM bikes WHERE station_id = p_station_id;

    IF v_capacity > 0 THEN
        capacity_pct := ROUND(bikes_parked * 100.0 / v_capacity, 1);
    ELSE
        capacity_pct := NULL;
    END IF;
END; $$
LANGUAGE plpgsql;

SELECT s.station_id, s.station_name, l.*
FROM stations s, LATERAL station_load(s.station_id) l
ORDER BY s.station_id;

\echo '=== Exercise 7.2: Top members, with a default ==='

CREATE OR REPLACE FUNCTION top_members(p_limit INT DEFAULT 3)
RETURNS TABLE (member_name VARCHAR, rental_count INT, amount_spent NUMERIC) AS $$
BEGIN
    RETURN QUERY
    SELECT m.full_name,
           COUNT(r.rental_id)::INT,
           COALESCE(SUM(r.fee), 0)
    FROM members m
    LEFT JOIN rentals r ON r.member_id = m.member_id
    GROUP BY m.member_id, m.full_name
    ORDER BY COALESCE(SUM(r.fee), 0) DESC, m.member_id
    LIMIT p_limit;
END; $$
LANGUAGE plpgsql;

SELECT * FROM top_members();
SELECT * FROM top_members(6);

\echo '=== Exercise 7.3: An invoice for an open rental ==='

CREATE OR REPLACE FUNCTION rental_invoice(p_rental_id INT)
RETURNS TABLE (member_name VARCHAR, bike_model VARCHAR, days INT, amount_owed NUMERIC, status TEXT) AS $$
BEGIN
    RETURN QUERY
    SELECT m.full_name,
           b.model,
           COALESCE(r.end_date, CURRENT_DATE) - r.start_date,
           ROUND((COALESCE(r.end_date, CURRENT_DATE) - r.start_date) * b.daily_rate, 2),
           CASE WHEN r.end_date IS NULL THEN 'OPEN' ELSE 'CLOSED' END
    FROM rentals r
    JOIN members m ON m.member_id = r.member_id
    JOIN bikes b ON b.bike_id = r.bike_id
    WHERE r.rental_id = p_rental_id;
END; $$
LANGUAGE plpgsql
STABLE;

SELECT * FROM rental_invoice(11);
SELECT * FROM rental_invoice(19);

SELECT i.amount_owed, r.fee AS stored_fee, i.amount_owed = r.fee AS matches
FROM rental_invoice(11) AS i, rentals r
WHERE r.rental_id = 11;

SELECT CURRENT_DATE AS run_date, proname, provolatile
FROM pg_proc
WHERE proname = 'rental_invoice';

\echo '=== Exercise 7.4: A report per city ==='

CREATE OR REPLACE FUNCTION city_report(
    p_city           VARCHAR,
    OUT member_count INT,
    OUT rental_count INT,
    OUT revenue      NUMERIC)
AS $$
BEGIN
    SELECT COUNT(DISTINCT m.member_id), COUNT(r.rental_id), COALESCE(SUM(r.fee), 0)
    INTO member_count, rental_count, revenue
    FROM members m
    LEFT JOIN rentals r ON r.member_id = m.member_id
    WHERE m.city = p_city;
END; $$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION city_report(
    p_city           VARCHAR,
    p_from_date      DATE,
    OUT member_count INT,
    OUT rental_count INT,
    OUT revenue      NUMERIC)
AS $$
BEGIN
    SELECT COUNT(DISTINCT m.member_id), COUNT(r.rental_id), COALESCE(SUM(r.fee), 0)
    INTO member_count, rental_count, revenue
    FROM members m
    LEFT JOIN rentals r ON r.member_id = m.member_id
    WHERE m.city = p_city
      AND r.start_date >= p_from_date;
END; $$
LANGUAGE plpgsql;

SELECT 'date filter in WHERE' AS version, * FROM city_report('Almaty', DATE '2025-01-01');

CREATE OR REPLACE FUNCTION city_report(
    p_city           VARCHAR,
    p_from_date      DATE,
    OUT member_count INT,
    OUT rental_count INT,
    OUT revenue      NUMERIC)
AS $$
BEGIN
    SELECT COUNT(DISTINCT m.member_id), COUNT(r.rental_id), COALESCE(SUM(r.fee), 0)
    INTO member_count, rental_count, revenue
    FROM members m
    LEFT JOIN rentals r ON r.member_id = m.member_id
                       AND r.start_date >= p_from_date
    WHERE m.city = p_city;
END; $$
LANGUAGE plpgsql;

SELECT 'date filter in ON' AS version, * FROM city_report('Almaty', DATE '2025-01-01');

SELECT * FROM city_report('Almaty');

SELECT c.city, 'all time' AS period, r.*
FROM (SELECT DISTINCT city FROM members) c, LATERAL city_report(c.city) r
UNION ALL
SELECT c.city, 'since 2025-01-01', r.*
FROM (SELECT DISTINCT city FROM members) c, LATERAL city_report(c.city, DATE '2025-01-01') r
ORDER BY city, period;

\echo '=== Challenge 1: busiest_station ==='

CREATE OR REPLACE FUNCTION busiest_station(p_from_date DATE DEFAULT DATE '2024-01-01')
RETURNS TABLE (top_station_id INT, top_station_name VARCHAR, rented_days INT) AS $$
BEGIN
    RETURN QUERY
    SELECT s.station_id, s.station_name, SUM(r.end_date - r.start_date)::INT
    FROM rentals r
    JOIN bikes b ON b.bike_id = r.bike_id
    JOIN stations s ON s.station_id = b.station_id
    WHERE r.start_date >= p_from_date
      AND r.end_date IS NOT NULL
    GROUP BY s.station_id, s.station_name
    ORDER BY 3 DESC, s.station_id
    LIMIT 1;
END; $$
LANGUAGE plpgsql;

SELECT * FROM busiest_station();
SELECT * FROM busiest_station(DATE '2025-01-01');

\echo '=== Challenge 2: FOR ... LOOP vs a single SELECT ==='

CREATE OR REPLACE FUNCTION member_activity_report() RETURNS INT AS $$
DECLARE
    rec     RECORD;
    v_count INT := 0;
BEGIN
    FOR rec IN
        SELECT m.member_id,
               m.full_name,
               COUNT(r.rental_id)      AS rentals,
               COALESCE(SUM(r.fee), 0) AS spent
        FROM members m
        LEFT JOIN rentals r ON r.member_id = m.member_id
        GROUP BY m.member_id, m.full_name
        ORDER BY m.member_id
    LOOP
        RAISE NOTICE '% (member %): % rentals, % spent', rec.full_name, rec.member_id, rec.rentals, rec.spent;
        v_count := v_count + 1;
    END LOOP;
    RETURN v_count;
END; $$
LANGUAGE plpgsql;

SELECT member_activity_report() AS members_reported;

SELECT m.member_id,
       m.full_name,
       COUNT(r.rental_id)      AS rentals,
       COALESCE(SUM(r.fee), 0) AS spent
FROM members m
LEFT JOIN rentals r ON r.member_id = m.member_id
GROUP BY m.member_id, m.full_name
ORDER BY m.member_id;

\echo '=== Challenge 3: RAISE EXCEPTION in rental_days() ==='

CREATE OR REPLACE FUNCTION rental_days(p_rental_id INT) RETURNS INT AS $$
DECLARE
    v_days INT;
BEGIN
    SELECT end_date - start_date
    INTO v_days
    FROM rentals
    WHERE rental_id = p_rental_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'rental % does not exist', p_rental_id
            USING ERRCODE = 'no_data_found';
    END IF;

    RETURN v_days;
END; $$
LANGUAGE plpgsql;

SELECT rental_days(2);
SELECT rental_days(19);

CALL expect_error('P0002', $$SELECT rental_days(999)$$);

CALL expect_error('P0002', $$
    SELECT v.id, rental_days(v.id)
    FROM (VALUES (1), (2), (999)) AS v(id)
$$);

\echo '=== Challenge 4: fee_report(INT), fee_report(VARCHAR), fee_report(TEXT) ==='

CREATE OR REPLACE FUNCTION fee_report(p_member_id INT) RETURNS TEXT AS $$
DECLARE
    v_report TEXT;
BEGIN
    SELECT format('member %s (%s): %s rentals, %s total',
                  m.member_id, m.full_name, COUNT(r.rental_id), COALESCE(SUM(r.fee), 0))
    INTO v_report
    FROM members m
    LEFT JOIN rentals r ON r.member_id = m.member_id
    WHERE m.member_id = p_member_id
    GROUP BY m.member_id, m.full_name;
    RETURN v_report;
END; $$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fee_report(p_full_name VARCHAR) RETURNS TEXT AS $$
BEGIN
    RETURN 'VARCHAR version -> '
        || fee_report((SELECT member_id FROM members WHERE full_name = p_full_name));
END; $$
LANGUAGE plpgsql;

SELECT fee_report(1);
SELECT fee_report('Aisha Nurlanova');

CREATE OR REPLACE FUNCTION fee_report(p_full_name TEXT) RETURNS TEXT AS $$
BEGIN
    RETURN 'TEXT version -> '
        || fee_report((SELECT member_id FROM members WHERE full_name = p_full_name));
END; $$
LANGUAGE plpgsql;

\df fee_report

SELECT fee_report('Aisha Nurlanova');
SELECT fee_report('Aisha Nurlanova'::VARCHAR);
SELECT fee_report(full_name) FROM members WHERE member_id = 1;

\echo '=== Challenge 5: CREATE PROCEDURE and CALL ==='

CREATE OR REPLACE PROCEDURE close_rental(p_rental_id INT, p_end_date DATE DEFAULT CURRENT_DATE)
LANGUAGE plpgsql
AS $$
DECLARE
    v_start DATE;
    v_rate  NUMERIC;
BEGIN
    SELECT r.start_date, b.daily_rate
    INTO v_start, v_rate
    FROM rentals r
    JOIN bikes b ON b.bike_id = r.bike_id
    WHERE r.rental_id = p_rental_id
      AND r.end_date IS NULL
    FOR UPDATE OF r;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'rental % does not exist or is already closed', p_rental_id
            USING ERRCODE = 'no_data_found';
    END IF;

    IF p_end_date < v_start THEN
        RAISE EXCEPTION 'end date % is before start date %', p_end_date, v_start
            USING ERRCODE = 'invalid_parameter_value';
    END IF;

    UPDATE rentals
    SET end_date = p_end_date,
        fee      = (p_end_date - v_start) * v_rate
    WHERE rental_id = p_rental_id;

    COMMIT;
END; $$;

CREATE OR REPLACE FUNCTION commit_inside_function() RETURNS VOID AS $$
BEGIN
    COMMIT;
END; $$
LANGUAGE plpgsql;

CALL expect_error('2D000', $$SELECT commit_inside_function()$$);

DROP FUNCTION commit_inside_function();

CALL expect_error('22023', $$CALL close_rental(19, DATE '2025-10-01')$$);

CALL close_rental(19, DATE '2025-10-15');

SELECT * FROM rentals WHERE rental_id = 19;

SELECT * FROM rental_invoice(19);

CALL expect_error('P0002', $$CALL close_rental(19, DATE '2025-10-20')$$);
