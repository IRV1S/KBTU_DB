\set ON_ERROR_STOP on
\c postgres

DROP DATABASE IF EXISTS views_roles_lab WITH (FORCE);

DROP ROLE IF EXISTS
    analyst, data_viewer, report_user,
    db_creator, user_manager, admin_user,
    hr_team, finance_team, it_team,
    hr_user1, hr_user2, finance_user1,
    read_only, junior_analyst, senior_analyst,
    project_manager, temp_owner,
    viewer_role, entry_role, analyst_role, manager_role,
    alice, bob, charlie;

CREATE DATABASE views_roles_lab;

\c views_roles_lab

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

CREATE FUNCTION effective_privileges(role_name text, rel text)
RETURNS text
LANGUAGE sql
STABLE
AS $$
    SELECT COALESCE(NULLIF(concat_ws(', ',
        CASE WHEN has_table_privilege(role_name, rel, 'SELECT') THEN 'SELECT' END,
        CASE WHEN has_table_privilege(role_name, rel, 'INSERT') THEN 'INSERT' END,
        CASE WHEN has_table_privilege(role_name, rel, 'UPDATE') THEN 'UPDATE' END,
        CASE WHEN has_table_privilege(role_name, rel, 'DELETE') THEN 'DELETE' END), ''), '-')
$$;

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

CREATE VIEW employee_details AS
SELECT e.emp_name, e.salary, d.dept_name, d.location
FROM employees e
INNER JOIN departments d ON d.dept_id = e.dept_id;

SELECT * FROM employee_details;

CREATE VIEW dept_statistics AS
SELECT d.dept_name,
       COUNT(e.emp_id)         AS employee_count,
       ROUND(AVG(e.salary), 2) AS avg_salary,
       MAX(e.salary)           AS max_salary,
       MIN(e.salary)           AS min_salary
FROM departments d
LEFT JOIN employees e ON e.dept_id = d.dept_id
GROUP BY d.dept_id, d.dept_name;

SELECT * FROM dept_statistics
ORDER BY employee_count DESC, dept_name;

CREATE VIEW project_overview AS
SELECT p.project_id,
       p.project_name,
       p.budget,
       d.dept_name,
       d.location,
       COUNT(e.emp_id) AS team_size
FROM projects p
LEFT JOIN departments d ON d.dept_id = p.dept_id
LEFT JOIN employees e ON e.dept_id = p.dept_id
GROUP BY p.project_id, p.project_name, p.budget, d.dept_name, d.location;

SELECT * FROM project_overview
ORDER BY project_id;

CREATE VIEW high_earners AS
SELECT e.emp_name, e.salary, d.dept_name
FROM employees e
LEFT JOIN departments d ON d.dept_id = e.dept_id
WHERE e.salary > 55000;

SELECT * FROM high_earners;

CREATE OR REPLACE VIEW employee_details AS
SELECT e.emp_name,
       e.salary,
       d.dept_name,
       d.location,
       CASE
           WHEN e.salary > 60000 THEN 'High'
           WHEN e.salary > 50000 THEN 'Medium'
           ELSE 'Standard'
       END AS salary_grade
FROM employees e
INNER JOIN departments d ON d.dept_id = e.dept_id;

SELECT * FROM employee_details;

ALTER VIEW high_earners RENAME TO top_performers;

SELECT * FROM top_performers;

CREATE TEMP VIEW temp_view AS
SELECT emp_id, emp_name, salary
FROM employees
WHERE salary < 50000;

SELECT * FROM temp_view;

DROP VIEW temp_view;

SELECT to_regclass('temp_view') AS temp_view_after_drop;

CREATE VIEW employee_salaries AS
SELECT emp_id, emp_name, dept_id, salary
FROM employees;

UPDATE employee_salaries
SET salary = 52000
WHERE emp_name = 'John Smith';

SELECT * FROM employees WHERE emp_name = 'John Smith';

INSERT INTO employee_salaries (emp_id, emp_name, dept_id, salary)
VALUES (6, 'Alice Johnson', 102, 58000);

SELECT * FROM employees ORDER BY emp_id;

CREATE VIEW it_employees AS
SELECT emp_id, emp_name, dept_id, salary
FROM employees
WHERE dept_id = 101
WITH LOCAL CHECK OPTION;

CALL expect_error('44000', $$
    INSERT INTO it_employees (emp_id, emp_name, dept_id, salary)
    VALUES (7, 'Bob Wilson', 103, 60000)
$$);

SELECT COUNT(*) AS bob_wilson_rows FROM employees WHERE emp_id = 7;

SELECT table_name, is_updatable, is_insertable_into, check_option
FROM information_schema.views
WHERE table_schema = 'public'
ORDER BY table_name;

CREATE MATERIALIZED VIEW dept_summary_mv AS
SELECT d.dept_id,
       d.dept_name,
       COALESCE(e.total_employees, 0) AS total_employees,
       COALESCE(e.total_salaries, 0)  AS total_salaries,
       COALESCE(p.total_projects, 0)  AS total_projects,
       COALESCE(p.total_budget, 0)    AS total_budget
FROM departments d
LEFT JOIN (
    SELECT dept_id, COUNT(*) AS total_employees, SUM(salary) AS total_salaries
    FROM employees
    GROUP BY dept_id
) e ON e.dept_id = d.dept_id
LEFT JOIN (
    SELECT dept_id, COUNT(*) AS total_projects, SUM(budget) AS total_budget
    FROM projects
    GROUP BY dept_id
) p ON p.dept_id = d.dept_id
WITH DATA;

SELECT * FROM dept_summary_mv ORDER BY total_employees DESC, dept_id;

INSERT INTO employees (emp_id, emp_name, dept_id, salary)
VALUES (8, 'Charlie Brown', 101, 54000);

SELECT * FROM dept_summary_mv ORDER BY total_employees DESC, dept_id;

REFRESH MATERIALIZED VIEW dept_summary_mv;

SELECT * FROM dept_summary_mv ORDER BY total_employees DESC, dept_id;

CREATE UNIQUE INDEX dept_summary_mv_dept_id_idx ON dept_summary_mv (dept_id);

REFRESH MATERIALIZED VIEW CONCURRENTLY dept_summary_mv;

SELECT * FROM dept_summary_mv ORDER BY total_employees DESC, dept_id;

CREATE MATERIALIZED VIEW project_stats_mv AS
SELECT p.project_name,
       p.budget,
       d.dept_name,
       COUNT(e.emp_id) AS assigned_employees
FROM projects p
LEFT JOIN departments d ON d.dept_id = p.dept_id
LEFT JOIN employees e ON e.dept_id = p.dept_id
GROUP BY p.project_id, p.project_name, p.budget, d.dept_name
WITH NO DATA;

CALL expect_error('55000', $$SELECT * FROM project_stats_mv$$);

REFRESH MATERIALIZED VIEW project_stats_mv;

SELECT * FROM project_stats_mv ORDER BY project_name;

CREATE ROLE analyst;
CREATE ROLE data_viewer WITH LOGIN PASSWORD 'viewer123';
CREATE USER report_user WITH PASSWORD 'report456';

SELECT rolname FROM pg_roles WHERE rolname NOT LIKE 'pg_%' ORDER BY rolname;

CREATE ROLE db_creator WITH CREATEDB LOGIN PASSWORD 'creator789';
CREATE ROLE user_manager WITH CREATEROLE LOGIN PASSWORD 'manager101';
CREATE ROLE admin_user WITH SUPERUSER LOGIN PASSWORD 'admin999';

SELECT rolname, rolsuper, rolcreatedb, rolcreaterole, rolcanlogin,
       rolpassword IS NOT NULL AS has_password
FROM pg_authid
WHERE rolname IN ('analyst', 'data_viewer', 'report_user',
                  'db_creator', 'user_manager', 'admin_user')
ORDER BY rolname;

GRANT SELECT ON employees, departments, projects TO analyst;
GRANT ALL PRIVILEGES ON employee_details TO data_viewer;
GRANT SELECT, INSERT ON employees TO report_user;

CREATE ROLE hr_team;
CREATE ROLE finance_team;
CREATE ROLE it_team;

CREATE USER hr_user1 WITH PASSWORD 'hr001';
CREATE USER hr_user2 WITH PASSWORD 'hr002';
CREATE USER finance_user1 WITH PASSWORD 'fin001';

GRANT hr_team TO hr_user1, hr_user2;
GRANT finance_team TO finance_user1;

GRANT SELECT, UPDATE ON employees TO hr_team;
GRANT SELECT ON dept_statistics TO finance_team;

SELECT r AS role_name,
       effective_privileges(r, 'employees')        AS employees,
       effective_privileges(r, 'departments')      AS departments,
       effective_privileges(r, 'employee_details') AS employee_details,
       effective_privileges(r, 'dept_statistics')  AS dept_statistics
FROM unnest(ARRAY['analyst', 'data_viewer', 'report_user',
                  'hr_team', 'hr_user1', 'hr_user2',
                  'finance_team', 'finance_user1']) WITH ORDINALITY AS t(r, n)
ORDER BY n;

REVOKE UPDATE ON employees FROM hr_team;
REVOKE hr_team FROM hr_user2;
REVOKE ALL PRIVILEGES ON employee_details FROM data_viewer;

SELECT r AS role_name,
       effective_privileges(r, 'employees')        AS employees,
       effective_privileges(r, 'departments')      AS departments,
       effective_privileges(r, 'employee_details') AS employee_details,
       effective_privileges(r, 'dept_statistics')  AS dept_statistics
FROM unnest(ARRAY['analyst', 'data_viewer', 'report_user',
                  'hr_team', 'hr_user1', 'hr_user2',
                  'finance_team', 'finance_user1']) WITH ORDINALITY AS t(r, n)
ORDER BY n;

ALTER ROLE analyst WITH LOGIN PASSWORD 'analyst123';
ALTER ROLE user_manager WITH SUPERUSER;
ALTER ROLE analyst WITH PASSWORD NULL;
ALTER ROLE data_viewer WITH CONNECTION LIMIT 5;

SELECT rolname, rolsuper, rolcreaterole, rolcanlogin, rolconnlimit,
       rolpassword IS NOT NULL AS has_password
FROM pg_authid
WHERE rolname IN ('analyst', 'user_manager', 'data_viewer')
ORDER BY rolname;

CREATE ROLE read_only;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO read_only;

CREATE ROLE junior_analyst WITH LOGIN PASSWORD 'junior123';
CREATE ROLE senior_analyst WITH LOGIN PASSWORD 'senior123';

GRANT read_only TO junior_analyst, senior_analyst;
GRANT INSERT, UPDATE ON employees TO senior_analyst;

SELECT r AS role_name,
       effective_privileges(r, 'employees')        AS employees,
       effective_privileges(r, 'departments')      AS departments,
       effective_privileges(r, 'projects')         AS projects,
       effective_privileges(r, 'employee_details') AS employee_details
FROM unnest(ARRAY['read_only', 'junior_analyst', 'senior_analyst']) WITH ORDINALITY AS t(r, n)
ORDER BY n;

SET ROLE junior_analyst;

SELECT current_user, COUNT(*) AS visible_employees FROM employees;

CALL expect_error('42501', $$UPDATE employees SET salary = 0 WHERE emp_id = 2$$);

RESET ROLE;

BEGIN;

SET LOCAL ROLE senior_analyst;

UPDATE employees
SET salary = salary + 1000
WHERE emp_id = 2
RETURNING current_user, emp_name, salary;

ROLLBACK;

CREATE ROLE project_manager WITH LOGIN PASSWORD 'pm123';

ALTER VIEW dept_statistics OWNER TO project_manager;
ALTER TABLE projects OWNER TO project_manager;

GRANT SELECT ON employees, departments TO project_manager;

SELECT tablename, tableowner
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;

SELECT viewname, viewowner
FROM pg_views
WHERE schemaname = 'public'
ORDER BY viewname;

SELECT * FROM dept_statistics ORDER BY dept_name;

CREATE ROLE temp_owner WITH LOGIN;

CREATE TABLE temp_table (id INT);

ALTER TABLE temp_table OWNER TO temp_owner;

SELECT tablename, tableowner FROM pg_tables WHERE tablename = 'temp_table';

REASSIGN OWNED BY temp_owner TO postgres;

DROP OWNED BY temp_owner;

DROP ROLE temp_owner;

SELECT tablename, tableowner FROM pg_tables WHERE tablename = 'temp_table';

SELECT COUNT(*) AS temp_owner_exists FROM pg_roles WHERE rolname = 'temp_owner';

CREATE VIEW hr_employee_view AS
SELECT emp_id, emp_name, dept_id, salary
FROM employees
WHERE dept_id = 102;

GRANT SELECT ON hr_employee_view TO hr_team;

CREATE VIEW finance_employee_view AS
SELECT emp_id, emp_name, salary
FROM employees;

GRANT SELECT ON finance_employee_view TO finance_team;

SET ROLE hr_user1;

SELECT * FROM hr_employee_view ORDER BY emp_id;

RESET ROLE;

SET ROLE finance_user1;

SELECT * FROM finance_employee_view ORDER BY emp_id;

CALL expect_error('42501', $$SELECT * FROM employees$$);

CALL expect_error('42501', $$SELECT * FROM hr_employee_view$$);

RESET ROLE;

CREATE VIEW dept_dashboard AS
SELECT d.dept_name,
       d.location,
       COALESCE(e.employee_count, 0)  AS employee_count,
       e.avg_salary,
       COALESCE(p.active_projects, 0) AS active_projects,
       COALESCE(p.total_budget, 0)    AS total_project_budget,
       CASE
           WHEN COALESCE(e.employee_count, 0) = 0 THEN 0
           ELSE ROUND(COALESCE(p.total_budget, 0) / e.employee_count, 2)
       END AS budget_per_employee
FROM departments d
LEFT JOIN (
    SELECT dept_id, COUNT(*) AS employee_count, ROUND(AVG(salary), 2) AS avg_salary
    FROM employees
    GROUP BY dept_id
) e ON e.dept_id = d.dept_id
LEFT JOIN (
    SELECT dept_id, COUNT(*) AS active_projects, SUM(budget) AS total_budget
    FROM projects
    GROUP BY dept_id
) p ON p.dept_id = d.dept_id;

SELECT * FROM dept_dashboard ORDER BY dept_name;

ALTER TABLE projects ADD COLUMN created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

CREATE VIEW high_budget_projects AS
SELECT p.project_name,
       p.budget,
       d.dept_name,
       p.created_date,
       CASE
           WHEN p.budget > 150000 THEN 'Critical Review Required'
           WHEN p.budget > 100000 THEN 'Management Approval Needed'
           ELSE 'Standard Process'
       END AS approval_status
FROM projects p
LEFT JOIN departments d ON d.dept_id = p.dept_id
WHERE p.budget > 75000;

SELECT * FROM high_budget_projects ORDER BY budget DESC;

CREATE ROLE viewer_role;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO viewer_role;

CREATE ROLE entry_role;
GRANT viewer_role TO entry_role;
GRANT INSERT ON employees, projects TO entry_role;

CREATE ROLE analyst_role;
GRANT entry_role TO analyst_role;
GRANT UPDATE ON employees, projects TO analyst_role;

CREATE ROLE manager_role;
GRANT analyst_role TO manager_role;
GRANT DELETE ON employees, projects TO manager_role;

CREATE USER alice WITH PASSWORD 'alice123';
CREATE USER bob WITH PASSWORD 'bob123';
CREATE USER charlie WITH PASSWORD 'charlie123';

GRANT viewer_role TO alice;
GRANT analyst_role TO bob;
GRANT manager_role TO charlie;

SELECT r AS role_name,
       effective_privileges(r, 'employees')      AS employees,
       effective_privileges(r, 'projects')       AS projects,
       effective_privileges(r, 'departments')    AS departments,
       effective_privileges(r, 'dept_dashboard') AS dept_dashboard
FROM unnest(ARRAY['viewer_role', 'entry_role', 'analyst_role', 'manager_role',
                  'alice', 'bob', 'charlie']) WITH ORDINALITY AS t(r, n)
ORDER BY n;

SELECT m.rolname AS member, r.rolname AS member_of
FROM pg_auth_members am
JOIN pg_roles r ON r.oid = am.roleid
JOIN pg_roles m ON m.oid = am.member
WHERE r.rolname NOT LIKE 'pg\_%'
ORDER BY member_of, member;

SET ROLE alice;

SELECT * FROM dept_statistics ORDER BY dept_name;

CALL expect_error('42501', $$DELETE FROM projects WHERE project_id = 5$$);

RESET ROLE;

BEGIN;

SET LOCAL ROLE charlie;

DELETE FROM projects
WHERE project_id = 5
RETURNING current_user, project_id, project_name;

ROLLBACK;
