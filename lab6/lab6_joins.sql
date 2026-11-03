\set ON_ERROR_STOP on
\c postgres

DROP DATABASE IF EXISTS joins_lab WITH (FORCE);
CREATE DATABASE joins_lab;

\c joins_lab

CREATE TABLE employees (
    emp_id   INT PRIMARY KEY,
    emp_name VARCHAR(50),
    dept_id  INT,
    salary   DECIMAL(10, 2)
);

CREATE TABLE departments (
    dept_id   INT PRIMARY KEY,
    dept_name VARCHAR(50),
    location  VARCHAR(50)
);

CREATE TABLE projects (
    project_id   INT PRIMARY KEY,
    project_name VARCHAR(50),
    dept_id      INT,
    budget       DECIMAL(10, 2)
);

INSERT INTO employees (emp_id, emp_name, dept_id, salary) VALUES
    (1, 'John Smith',     101, 50000),
    (2, 'Jane Doe',       102, 60000),
    (3, 'Mike Johnson',   101, 55000),
    (4, 'Sarah Williams', 103, 65000),
    (5, 'Tom Brown',      NULL, 45000);

INSERT INTO departments (dept_id, dept_name, location) VALUES
    (101, 'IT',        'Building A'),
    (102, 'HR',        'Building B'),
    (103, 'Finance',   'Building C'),
    (104, 'Marketing', 'Building D');

INSERT INTO projects (project_id, project_name, dept_id, budget) VALUES
    (1, 'Website Redesign',  101,  100000),
    (2, 'Employee Training', 102,   50000),
    (3, 'Budget Analysis',   103,   75000),
    (4, 'Cloud Migration',   101,  150000),
    (5, 'AI Research',       NULL, 200000);

SELECT e.emp_name, d.dept_name
FROM employees e
CROSS JOIN departments d
ORDER BY e.emp_id, d.dept_id;

SELECT COUNT(*) AS total_rows,
       (SELECT COUNT(*) FROM employees)   AS n_employees,
       (SELECT COUNT(*) FROM departments) AS m_departments
FROM employees e
CROSS JOIN departments d;

SELECT e.emp_name, d.dept_name
FROM employees e, departments d
ORDER BY e.emp_id, d.dept_id;

SELECT e.emp_name, d.dept_name
FROM employees e
INNER JOIN departments d ON TRUE
ORDER BY e.emp_id, d.dept_id;

SELECT e.emp_name, p.project_name, 'Available' AS availability
FROM employees e
CROSS JOIN projects p
ORDER BY e.emp_name, p.project_name;

SELECT e.emp_name, d.dept_name, d.location
FROM employees e
INNER JOIN departments d ON e.dept_id = d.dept_id
ORDER BY e.emp_id;

SELECT emp_name, dept_name, location
FROM employees
INNER JOIN departments USING (dept_id)
ORDER BY emp_id;

SELECT *
FROM employees e
INNER JOIN departments d ON e.dept_id = d.dept_id
ORDER BY e.emp_id;

SELECT *
FROM employees
INNER JOIN departments USING (dept_id)
ORDER BY emp_id;

SELECT emp_name, dept_name, location
FROM employees
NATURAL INNER JOIN departments
ORDER BY emp_id;

SELECT e.emp_name, d.dept_name, p.project_name
FROM employees e
INNER JOIN departments d ON e.dept_id = d.dept_id
INNER JOIN projects p ON d.dept_id = p.dept_id
ORDER BY e.emp_name, p.project_name;

SELECT e.emp_name, e.dept_id AS emp_dept, d.dept_id AS dept_dept, d.dept_name
FROM employees e
LEFT JOIN departments d ON e.dept_id = d.dept_id
ORDER BY e.emp_id;

SELECT emp_name, dept_id, dept_name, location
FROM employees
LEFT JOIN departments USING (dept_id)
ORDER BY emp_id;

SELECT e.emp_name, e.dept_id
FROM employees e
LEFT JOIN departments d ON e.dept_id = d.dept_id
WHERE d.dept_id IS NULL;

SELECT d.dept_name, COUNT(e.emp_id) AS employee_count
FROM departments d
LEFT JOIN employees e ON d.dept_id = e.dept_id
GROUP BY d.dept_id, d.dept_name
ORDER BY employee_count DESC, d.dept_name;

SELECT e.emp_name, d.dept_name
FROM employees e
RIGHT JOIN departments d ON e.dept_id = d.dept_id
ORDER BY d.dept_id, e.emp_name;

SELECT e.emp_name, d.dept_name
FROM departments d
LEFT JOIN employees e ON d.dept_id = e.dept_id
ORDER BY d.dept_id, e.emp_name;

SELECT d.dept_name, d.location
FROM employees e
RIGHT JOIN departments d ON e.dept_id = d.dept_id
WHERE e.emp_id IS NULL;

SELECT e.emp_name, e.dept_id AS emp_dept, d.dept_id AS dept_dept, d.dept_name
FROM employees e
FULL JOIN departments d ON e.dept_id = d.dept_id
ORDER BY e.emp_id, d.dept_id;

SELECT d.dept_name, p.project_name, p.budget
FROM departments d
FULL JOIN projects p ON d.dept_id = p.dept_id
ORDER BY d.dept_id, p.project_id;

SELECT
    CASE
        WHEN e.emp_id IS NULL THEN 'Department without employees'
        WHEN d.dept_id IS NULL THEN 'Employee without department'
        ELSE 'Matched'
    END AS record_status,
    e.emp_name,
    d.dept_name
FROM employees e
FULL JOIN departments d ON e.dept_id = d.dept_id
WHERE e.emp_id IS NULL OR d.dept_id IS NULL;

SELECT e.emp_name, d.dept_name, e.salary
FROM employees e
LEFT JOIN departments d ON e.dept_id = d.dept_id AND d.location = 'Building A'
ORDER BY e.emp_id;

SELECT e.emp_name, d.dept_name, e.salary
FROM employees e
LEFT JOIN departments d ON e.dept_id = d.dept_id
WHERE d.location = 'Building A'
ORDER BY e.emp_id;

SELECT e.emp_name, d.dept_name, e.salary
FROM employees e
INNER JOIN departments d ON e.dept_id = d.dept_id AND d.location = 'Building A'
ORDER BY e.emp_id;

SELECT e.emp_name, d.dept_name, e.salary
FROM employees e
INNER JOIN departments d ON e.dept_id = d.dept_id
WHERE d.location = 'Building A'
ORDER BY e.emp_id;

SELECT
    d.dept_name,
    e.emp_name,
    e.salary,
    p.project_name,
    p.budget
FROM departments d
LEFT JOIN employees e ON d.dept_id = e.dept_id
LEFT JOIN projects p ON d.dept_id = p.dept_id
ORDER BY d.dept_name, e.emp_name, p.project_name;

ALTER TABLE employees ADD COLUMN manager_id INT;

UPDATE employees SET manager_id = 3 WHERE emp_id = 1;
UPDATE employees SET manager_id = 3 WHERE emp_id = 2;
UPDATE employees SET manager_id = NULL WHERE emp_id = 3;
UPDATE employees SET manager_id = 3 WHERE emp_id = 4;
UPDATE employees SET manager_id = 3 WHERE emp_id = 5;

SELECT
    e.emp_name AS employee,
    m.emp_name AS manager
FROM employees e
LEFT JOIN employees m ON e.manager_id = m.emp_id
ORDER BY e.emp_id;

SELECT d.dept_name, ROUND(AVG(e.salary), 2) AS avg_salary
FROM departments d
INNER JOIN employees e ON d.dept_id = e.dept_id
GROUP BY d.dept_id, d.dept_name
HAVING AVG(e.salary) > 50000
ORDER BY avg_salary DESC;

SELECT d.dept_name, ROUND(s.avg_salary, 2) AS avg_salary
FROM departments d
INNER JOIN (
    SELECT dept_id, AVG(salary) AS avg_salary
    FROM employees
    GROUP BY dept_id
) s ON s.dept_id = d.dept_id
WHERE s.avg_salary > 50000
ORDER BY avg_salary DESC;

SELECT COUNT(*) AS cross_join_rows
FROM generate_series(1, 5) AS table1
CROSS JOIN generate_series(1, 10) AS table2;

SELECT e.emp_name, d.dept_name
FROM employees e
LEFT JOIN departments d ON e.dept_id = d.dept_id
ORDER BY e.emp_id;

SELECT e.emp_name, d.dept_name
FROM departments d
RIGHT JOIN employees e ON e.dept_id = d.dept_id
ORDER BY e.emp_id;

SELECT e.emp_name, e.dept_id AS emp_dept, d.dept_id AS dept_dept, d.dept_name
FROM employees e
LEFT JOIN departments d ON e.dept_id = d.dept_id
UNION ALL
SELECT e.emp_name, e.dept_id, d.dept_id, d.dept_name
FROM employees e
RIGHT JOIN departments d ON e.dept_id = d.dept_id
WHERE e.emp_id IS NULL
ORDER BY emp_name, dept_dept;

SELECT e.emp_name, d.dept_name, dp.project_count
FROM employees e
INNER JOIN departments d ON d.dept_id = e.dept_id
INNER JOIN (
    SELECT dept_id, COUNT(*) AS project_count
    FROM projects
    GROUP BY dept_id
    HAVING COUNT(*) > 1
) dp ON dp.dept_id = e.dept_id
ORDER BY e.emp_name;

SELECT
    e.emp_name  AS employee,
    m1.emp_name AS manager,
    m2.emp_name AS managers_manager,
    m3.emp_name AS top_manager
FROM employees e
LEFT JOIN employees m1 ON e.manager_id = m1.emp_id
LEFT JOIN employees m2 ON m1.manager_id = m2.emp_id
LEFT JOIN employees m3 ON m2.manager_id = m3.emp_id
ORDER BY e.emp_id;

WITH RECURSIVE chain AS (
    SELECT emp_id AS start_id,
           emp_name::text AS path,
           manager_id,
           0 AS depth
    FROM employees
    UNION ALL
    SELECT c.start_id,
           c.path || ' -> ' || m.emp_name,
           m.manager_id,
           c.depth + 1
    FROM chain c
    INNER JOIN employees m ON m.emp_id = c.manager_id
)
SELECT DISTINCT ON (start_id) start_id AS emp_id, depth AS levels_above, path AS reporting_chain
FROM chain
ORDER BY start_id, depth DESC;

SELECT d.dept_name, e1.emp_name AS employee_1, e2.emp_name AS employee_2
FROM employees e1
INNER JOIN employees e2 ON e1.dept_id = e2.dept_id AND e1.emp_id < e2.emp_id
INNER JOIN departments d ON d.dept_id = e1.dept_id
ORDER BY d.dept_name, e1.emp_name, e2.emp_name;
