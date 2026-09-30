\set ON_ERROR_STOP on
\c postgres

DROP DATABASE IF EXISTS advanced_lab WITH (FORCE);
CREATE DATABASE advanced_lab;

\c advanced_lab

CREATE TABLE employees (
    emp_id     SERIAL PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name  VARCHAR(50) NOT NULL,
    department VARCHAR(50),
    salary     INTEGER CHECK (salary >= 0),
    hire_date  DATE,
    status     VARCHAR(20) NOT NULL DEFAULT 'Active'
);

CREATE TABLE departments (
    dept_id    SERIAL PRIMARY KEY,
    dept_name  VARCHAR(50) NOT NULL UNIQUE,
    budget     INTEGER CHECK (budget >= 0),
    manager_id INTEGER REFERENCES employees (emp_id) ON DELETE SET NULL
);

CREATE TABLE projects (
    project_id   SERIAL PRIMARY KEY,
    project_name VARCHAR(100) NOT NULL,
    dept_id      INTEGER REFERENCES departments (dept_id) ON DELETE SET NULL,
    start_date   DATE,
    end_date     DATE,
    budget       INTEGER CHECK (budget >= 0),
    CHECK (end_date >= start_date)
);

INSERT INTO employees (first_name, last_name, department, salary, hire_date, status) VALUES
    ('Alice', 'Johnson', 'IT',    85000, '2018-03-15', 'Active'),
    ('Bob',   'Smith',   'IT',    55000, '2021-06-01', 'Active'),
    ('Carol', 'White',   'Sales', 62000, '2019-02-10', 'Active'),
    ('David', 'Brown',   'Sales', 45000, '2022-09-20', 'Active'),
    ('Eva',   'Green',   'HR',    35000, '2023-05-12', 'Inactive'),
    ('Frank', 'Black',   'HR',    30000, '2024-02-01', 'Terminated'),
    ('Grace', 'Lee',     'Sales', 72000, '2017-11-30', 'Active'),
    ('Henry', 'Wilson',  'IT',    48000, '2023-08-15', 'Inactive'),
    ('Ivan',  'Petrov',  'HR',    58000, '2021-09-01', 'Inactive');

INSERT INTO employees (emp_id, first_name, last_name, department)
VALUES (DEFAULT, 'John', 'Doe', 'IT');

INSERT INTO employees (first_name, last_name, department, salary, hire_date, status)
VALUES ('Kate', 'Miller', 'Sales', DEFAULT, '2022-04-01', DEFAULT);

INSERT INTO departments (dept_name, budget, manager_id) VALUES
    ('IT',    150000, 1),
    ('Sales',  90000, 7),
    ('HR',     60000, NULL);

INSERT INTO employees (first_name, last_name, department, salary, hire_date)
VALUES ('Liam', 'Davis', 'IT', 50000 * 1.1, CURRENT_DATE);

CREATE TEMP TABLE temp_employees (LIKE employees);

INSERT INTO temp_employees
SELECT *
FROM employees
WHERE department = 'IT';

INSERT INTO projects (project_name, dept_id, start_date, end_date, budget) VALUES
    ('CRM Upgrade',    1, '2022-01-10', '2022-12-20',  40000),
    ('Data Warehouse', 1, '2023-02-01', '2024-06-30', 120000),
    ('Sales Portal',   2, '2023-03-01', '2024-03-01',  75000),
    ('HR Onboarding',  3, '2022-05-01', '2022-11-30',  20000),
    ('Mobile App',     1, '2024-01-15', '2025-01-15',  60000);

UPDATE employees
SET salary = salary * 1.1;

UPDATE employees
SET status = 'Senior'
WHERE salary > 60000
  AND hire_date < '2020-01-01';

UPDATE employees
SET department = CASE
    WHEN salary > 80000 THEN 'Management'
    WHEN salary BETWEEN 50000 AND 80000 THEN 'Senior'
    ELSE 'Junior'
END;

UPDATE employees
SET department = DEFAULT
WHERE status = 'Inactive';

INSERT INTO employees (first_name, last_name, department, salary, hire_date) VALUES
    ('Mia',    'Clark',  'IT',    90000, '2021-01-10'),
    ('Noah',   'Hall',   'IT',    85000, '2022-07-01'),
    ('Olivia', 'King',   'IT',    95000, '2020-05-20'),
    ('Paul',   'Scott',  'IT',    88000, '2023-03-15'),
    ('Quinn',  'Adams',  'Sales', 47000, '2020-08-08'),
    ('Rita',   'Young',  'Sales', 53000, '2021-12-01'),
    ('Sam',    'Turner', 'Sales', 61000, '2022-10-10');

UPDATE departments d
SET budget = (
    SELECT ROUND(AVG(e.salary) * 1.2)
    FROM employees e
    WHERE e.department = d.dept_name
)
WHERE EXISTS (
    SELECT 1
    FROM employees e
    WHERE e.department = d.dept_name
      AND e.salary IS NOT NULL
);

UPDATE employees
SET salary = salary * 1.15,
    status = 'Promoted'
WHERE department = 'Sales';

DELETE FROM employees
WHERE status = 'Terminated';

DELETE FROM employees
WHERE salary < 40000
  AND hire_date > '2023-01-01'
  AND department IS NULL;

DELETE FROM departments
WHERE dept_name NOT IN (
    SELECT DISTINCT department
    FROM employees
    WHERE department IS NOT NULL
);

DELETE FROM projects
WHERE end_date < '2023-01-01'
RETURNING *;

INSERT INTO employees (first_name, last_name, department, salary, hire_date)
VALUES ('Tom', 'Baker', NULL, NULL, CURRENT_DATE);

UPDATE employees
SET department = 'Unassigned'
WHERE department IS NULL;

DELETE FROM employees
WHERE salary IS NULL
   OR department IS NULL;

INSERT INTO employees (first_name, last_name, department, salary, hire_date)
VALUES ('Uma', 'Reed', 'IT', 72000, CURRENT_DATE)
RETURNING emp_id, first_name || ' ' || last_name AS full_name;

UPDATE employees
SET salary = salary + 5000
WHERE department = 'IT'
RETURNING emp_id, old.salary AS old_salary, new.salary AS new_salary;

DELETE FROM employees
WHERE hire_date < '2020-01-01'
RETURNING *;

INSERT INTO employees (first_name, last_name, department, salary, hire_date)
SELECT 'Victor', 'Stone', 'IT', 80000, CURRENT_DATE
WHERE NOT EXISTS (
    SELECT 1
    FROM employees
    WHERE first_name = 'Victor'
      AND last_name = 'Stone'
);

UPDATE employees e
SET salary = CASE
    WHEN (SELECT d.budget FROM departments d WHERE d.dept_name = e.department) > 100000
        THEN salary * 1.10
    ELSE salary * 1.05
END
WHERE EXISTS (
    SELECT 1
    FROM departments d
    WHERE d.dept_name = e.department
);

INSERT INTO employees (first_name, last_name, department, salary, hire_date) VALUES
    ('Anna',   'Moore',  'Marketing', 51000, '2025-01-15'),
    ('Ben',    'Taylor', 'Marketing', 49000, '2025-01-15'),
    ('Chloe',  'Martin', 'Marketing', 56000, '2025-01-15'),
    ('Daniel', 'Lewis',  'Marketing', 60000, '2025-01-15'),
    ('Ella',   'Walker', 'Marketing', 47000, '2025-01-15');

UPDATE employees
SET salary = salary * 1.10
WHERE department = 'Marketing';

CREATE TABLE employee_archive (LIKE employees INCLUDING CONSTRAINTS INCLUDING INDEXES);

BEGIN;

INSERT INTO employee_archive
SELECT *
FROM employees
WHERE status = 'Inactive';

DELETE FROM employees
WHERE status = 'Inactive';

COMMIT;

UPDATE projects p
SET end_date = end_date + 30
WHERE p.budget > 50000
  AND (
    SELECT COUNT(*)
    FROM employees e
    JOIN departments d ON d.dept_name = e.department
    WHERE d.dept_id = p.dept_id
  ) > 3;
