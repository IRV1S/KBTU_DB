\set ON_ERROR_STOP on
\c postgres

DROP DATABASE IF EXISTS indexes_lab WITH (FORCE);
CREATE DATABASE indexes_lab;

\c indexes_lab

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
        RAISE NOTICE '[%] %', v_state, SQLERRM
            || CASE WHEN v_detail <> '' THEN E'\nDETAIL:  ' || v_detail ELSE '' END
            || CASE WHEN v_hint <> '' THEN E'\nHINT:  ' || v_hint ELSE '' END;
END
$$;

CREATE TABLE departments (
    dept_id   INT PRIMARY KEY,
    dept_name VARCHAR(50),
    location  VARCHAR(50)
);

CREATE TABLE employees (
    emp_id   INT PRIMARY KEY,
    emp_name VARCHAR(100),
    dept_id  INT,
    salary   DECIMAL(10, 2),
    FOREIGN KEY (dept_id) REFERENCES departments (dept_id)
);

CREATE TABLE projects (
    proj_id   INT PRIMARY KEY,
    proj_name VARCHAR(100),
    budget    DECIMAL(12, 2),
    dept_id   INT,
    FOREIGN KEY (dept_id) REFERENCES departments (dept_id)
);

INSERT INTO departments VALUES
    (101, 'IT',         'Building A'),
    (102, 'HR',         'Building B'),
    (103, 'Operations', 'Building C');

INSERT INTO employees VALUES
    (1, 'John Smith',     101, 50000),
    (2, 'Jane Doe',       101, 55000),
    (3, 'Mike Johnson',   102, 48000),
    (4, 'Sarah Williams', 102, 52000),
    (5, 'Tom Brown',      103, 60000);

INSERT INTO projects VALUES
    (201, 'Website Redesign',    75000, 101),
    (202, 'Database Migration', 120000, 101),
    (203, 'HR System Upgrade',   50000, 102);

ANALYZE departments, employees, projects;

SET enable_seqscan = off;

CREATE INDEX emp_salary_idx ON employees (salary);

SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'employees'
ORDER BY indexname;

CREATE INDEX emp_dept_idx ON employees (dept_id);

SELECT * FROM employees WHERE dept_id = 101;

EXPLAIN (COSTS OFF)
SELECT * FROM employees WHERE dept_id = 101;

SELECT
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;

SELECT conrelid::regclass AS table_name,
       conname            AS constraint_name,
       contype            AS constraint_type,
       conindid::regclass AS backing_index
FROM pg_constraint
WHERE connamespace = 'public'::regnamespace
  AND contype IN ('p', 'u', 'f')
ORDER BY table_name, constraint_name;

CREATE INDEX emp_dept_salary_idx ON employees (dept_id, salary);

SELECT emp_name, salary
FROM employees
WHERE dept_id = 101 AND salary > 52000;

EXPLAIN (COSTS OFF)
SELECT emp_name, salary
FROM employees
WHERE dept_id = 101 AND salary > 52000;

CREATE INDEX emp_salary_dept_idx ON employees (salary, dept_id);

SELECT * FROM employees WHERE dept_id = 102 AND salary > 50000;

SELECT * FROM employees WHERE salary > 50000 AND dept_id = 102;

EXPLAIN (COSTS OFF)
SELECT * FROM employees WHERE dept_id = 102 AND salary > 50000;

EXPLAIN (COSTS OFF)
SELECT * FROM employees WHERE salary > 50000 AND dept_id = 102;

ALTER TABLE employees ADD COLUMN email VARCHAR(100);

UPDATE employees SET email = 'john.smith@company.com' WHERE emp_id = 1;
UPDATE employees SET email = 'jane.doe@company.com' WHERE emp_id = 2;
UPDATE employees SET email = 'mike.johnson@company.com' WHERE emp_id = 3;
UPDATE employees SET email = 'sarah.williams@company.com' WHERE emp_id = 4;
UPDATE employees SET email = 'tom.brown@company.com' WHERE emp_id = 5;

CREATE UNIQUE INDEX emp_email_unique_idx ON employees (email);

CALL expect_error('23505', $$
    INSERT INTO employees (emp_id, emp_name, dept_id, salary, email)
    VALUES (6, 'New Employee', 101, 55000, 'john.smith@company.com')
$$);

ALTER TABLE employees ADD COLUMN phone VARCHAR(20) UNIQUE;

SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'employees' AND indexname LIKE '%phone%';

CREATE INDEX emp_salary_desc_idx ON employees (salary DESC);

SELECT emp_name, salary
FROM employees
ORDER BY salary DESC;

EXPLAIN (COSTS OFF)
SELECT emp_name, salary
FROM employees
ORDER BY salary DESC;

CREATE INDEX proj_budget_nulls_first_idx ON projects (budget NULLS FIRST);

SELECT proj_name, budget
FROM projects
ORDER BY budget NULLS FIRST;

EXPLAIN (COSTS OFF)
SELECT proj_name, budget
FROM projects
ORDER BY budget NULLS FIRST;

CREATE INDEX emp_name_lower_idx ON employees (LOWER(emp_name));

SELECT * FROM employees WHERE LOWER(emp_name) = 'john smith';

EXPLAIN (COSTS OFF)
SELECT * FROM employees WHERE LOWER(emp_name) = 'john smith';

ALTER TABLE employees ADD COLUMN hire_date DATE;

UPDATE employees SET hire_date = '2020-01-15' WHERE emp_id = 1;
UPDATE employees SET hire_date = '2019-06-20' WHERE emp_id = 2;
UPDATE employees SET hire_date = '2021-03-10' WHERE emp_id = 3;
UPDATE employees SET hire_date = '2020-11-05' WHERE emp_id = 4;
UPDATE employees SET hire_date = '2018-08-25' WHERE emp_id = 5;

CREATE INDEX emp_hire_year_idx ON employees (EXTRACT(YEAR FROM hire_date));

SELECT emp_name, hire_date
FROM employees
WHERE EXTRACT(YEAR FROM hire_date) = 2020;

EXPLAIN (COSTS OFF)
SELECT emp_name, hire_date
FROM employees
WHERE EXTRACT(YEAR FROM hire_date) = 2020;

ALTER INDEX emp_salary_idx RENAME TO employees_salary_index;

SELECT indexname FROM pg_indexes WHERE tablename = 'employees' ORDER BY indexname;

DROP INDEX emp_salary_dept_idx;

REINDEX INDEX employees_salary_index;

SELECT e.emp_name, e.salary, d.dept_name
FROM employees e
JOIN departments d ON e.dept_id = d.dept_id
WHERE e.salary > 50000
ORDER BY e.salary DESC;

CREATE INDEX emp_salary_filter_idx ON employees (salary) WHERE salary > 50000;

EXPLAIN (COSTS OFF)
SELECT e.emp_name, e.salary, d.dept_name
FROM employees e
JOIN departments d ON e.dept_id = d.dept_id
WHERE e.salary > 50000
ORDER BY e.salary DESC;

CREATE INDEX proj_high_budget_idx ON projects (budget)
WHERE budget > 80000;

SELECT proj_name, budget
FROM projects
WHERE budget > 80000;

EXPLAIN (COSTS OFF)
SELECT proj_name, budget
FROM projects
WHERE budget > 80000;

ANALYZE employees;

RESET enable_seqscan;

EXPLAIN SELECT * FROM employees WHERE salary > 52000;

SET enable_seqscan = off;

EXPLAIN SELECT * FROM employees WHERE salary > 52000;

CREATE INDEX dept_name_hash_idx ON departments USING HASH (dept_name);

SELECT * FROM departments WHERE dept_name = 'IT';

EXPLAIN (COSTS OFF)
SELECT * FROM departments WHERE dept_name = 'IT';

CREATE INDEX proj_name_btree_idx ON projects (proj_name);

CREATE INDEX proj_name_hash_idx ON projects USING HASH (proj_name);

SELECT * FROM projects WHERE proj_name = 'Website Redesign';

SELECT * FROM projects WHERE proj_name > 'Database';

EXPLAIN (COSTS OFF)
SELECT * FROM projects WHERE proj_name = 'Website Redesign';

EXPLAIN (COSTS OFF)
SELECT * FROM projects WHERE proj_name > 'Database';

BEGIN;

DROP INDEX proj_name_btree_idx;

EXPLAIN (COSTS OFF)
SELECT * FROM projects WHERE proj_name = 'Website Redesign';

EXPLAIN (COSTS OFF)
SELECT * FROM projects WHERE proj_name > 'Database';

ROLLBACK;

SELECT
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexname::regclass)) AS index_size
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;

SELECT a.indexrelid::regclass AS redundant_index,
       b.indexrelid::regclass AS covered_by
FROM pg_index a
JOIN pg_class ca ON ca.oid = a.indexrelid
JOIN pg_index b ON b.indrelid = a.indrelid AND b.indexrelid <> a.indexrelid
JOIN pg_class cb ON cb.oid = b.indexrelid
WHERE ca.relnamespace = 'public'::regnamespace
  AND ca.relam = cb.relam
  AND NOT a.indisunique
  AND a.indexprs IS NULL AND b.indexprs IS NULL
  AND a.indpred IS NULL AND b.indpred IS NULL
  AND (b.indkey::text || ' ') LIKE (a.indkey::text || ' %')
  AND (a.indkey::text <> b.indkey::text OR a.indexrelid > b.indexrelid)
ORDER BY ca.relname;

DROP INDEX IF EXISTS proj_name_hash_idx;
DROP INDEX emp_salary_desc_idx;
DROP INDEX emp_dept_idx;

EXPLAIN (COSTS OFF)
SELECT e.emp_name, e.salary, d.dept_name
FROM employees e
JOIN departments d ON e.dept_id = d.dept_id
WHERE e.salary > 50000
ORDER BY e.salary DESC;

CREATE VIEW index_documentation AS
SELECT
    tablename,
    indexname,
    indexdef,
    'Improves salary-based queries' AS purpose
FROM pg_indexes
WHERE schemaname = 'public'
  AND indexname LIKE '%salary%';

SELECT * FROM index_documentation;

COMMENT ON INDEX employees_salary_index IS 'Salary filters and ORDER BY salary in both directions';
COMMENT ON INDEX emp_dept_salary_idx IS 'Employees of a department, optionally within a salary range; FK lookups by dept_id';
COMMENT ON INDEX emp_salary_filter_idx IS 'Partial index for the frequent salary > 50000 report';
COMMENT ON INDEX emp_email_unique_idx IS 'Enforces unique email and speeds up lookup by email';
COMMENT ON INDEX emp_name_lower_idx IS 'Case-insensitive search by employee name';
COMMENT ON INDEX emp_hire_year_idx IS 'Filter employees by hire year';
COMMENT ON INDEX proj_budget_nulls_first_idx IS 'ORDER BY budget NULLS FIRST without a sort step';
COMMENT ON INDEX proj_high_budget_idx IS 'Partial index for high-budget projects (budget > 80000)';
COMMENT ON INDEX proj_name_btree_idx IS 'Equality and range search by project name';
COMMENT ON INDEX dept_name_hash_idx IS 'Equality lookup by department name';

CREATE OR REPLACE VIEW index_documentation AS
SELECT
    i.tablename,
    i.indexname,
    i.indexdef,
    obj_description(i.indexname::regclass, 'pg_class') COLLATE "default" AS purpose
FROM pg_indexes i
WHERE i.schemaname = 'public'
  AND NOT EXISTS (
      SELECT 1
      FROM pg_constraint c
      WHERE c.conindid = i.indexname::regclass
  );

SELECT * FROM index_documentation ORDER BY tablename, indexname;

CREATE INDEX emp_hire_year_month_idx
    ON employees ((EXTRACT(YEAR FROM hire_date)), (EXTRACT(MONTH FROM hire_date)));

SELECT emp_name, hire_date
FROM employees
WHERE EXTRACT(YEAR FROM hire_date) = 2020
  AND EXTRACT(MONTH FROM hire_date) = 11;

EXPLAIN (COSTS OFF)
SELECT emp_name, hire_date
FROM employees
WHERE EXTRACT(YEAR FROM hire_date) = 2020
  AND EXTRACT(MONTH FROM hire_date) = 11;

CREATE UNIQUE INDEX emp_dept_email_unique_idx ON employees (dept_id, email);

BEGIN;

DROP INDEX emp_email_unique_idx;

INSERT INTO employees (emp_id, emp_name, dept_id, salary, email)
VALUES (6, 'John Smith (HR)', 102, 50000, 'john.smith@company.com')
RETURNING emp_id, dept_id, email;

CALL expect_error('23505', $$
    INSERT INTO employees (emp_id, emp_name, dept_id, salary, email)
    VALUES (7, 'John Smith (IT copy)', 101, 50000, 'john.smith@company.com')
$$);

ROLLBACK;

RESET enable_seqscan;

CREATE TABLE employees_big (
    emp_id   INT PRIMARY KEY,
    emp_name VARCHAR(100),
    dept_id  INT,
    salary   DECIMAL(10, 2)
);

INSERT INTO employees_big (emp_id, emp_name, dept_id, salary)
SELECT i,
       'Employee ' || i,
       101 + i % 3,
       30000 + (i * 7919) % 70000
FROM generate_series(1, 200000) AS i;

VACUUM ANALYZE employees_big;

EXPLAIN ANALYZE
SELECT emp_name, salary
FROM employees_big
WHERE salary BETWEEN 55000 AND 55100;

CREATE INDEX emp_big_salary_idx ON employees_big (salary);

EXPLAIN ANALYZE
SELECT emp_name, salary
FROM employees_big
WHERE salary BETWEEN 55000 AND 55100;

CREATE INDEX emp_big_salary_covering_idx ON employees_big (salary) INCLUDE (emp_name);

EXPLAIN ANALYZE
SELECT emp_name, salary
FROM employees_big
WHERE salary BETWEEN 55000 AND 55100;

SELECT indexname, pg_size_pretty(pg_relation_size(indexname::regclass)) AS index_size
FROM pg_indexes
WHERE tablename = 'employees_big'
ORDER BY indexname;
