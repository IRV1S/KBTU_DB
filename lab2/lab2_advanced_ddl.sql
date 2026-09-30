-- ============================================================================
-- Лабораторная работа 2. Advanced DDL Operations.
-- Диалект: PostgreSQL 18. Запуск: из psql, подключившись к базе postgres
-- под суперпользователем (CREATE TABLESPACE требует прав суперпользователя):
--
--     psql -U postgres -d postgres -f lab2_advanced_ddl.sql
--
-- Скрипт использует мета-команду \c для переключения между базами, поэтому
-- рассчитан именно на psql. CREATE/DROP DATABASE нельзя выполнять внутри
-- транзакции, так что autocommit должен быть включён (в psql он включён).
--
-- Перед запуском каталоги табличных пространств должны существовать, быть
-- пустыми и принадлежать пользователю, от которого работает сервер:
--   Linux:   sudo mkdir -p /data/students /data/courses
--            sudo chown postgres:postgres /data/students /data/courses
--   Windows: путь '/data/students' означает C:\data\students на диске,
--            где установлен сервер; служба PostgreSQL должна иметь права
--            на запись в эти каталоги.
--
-- Скрипт идемпотентный: блок 0 удаляет всё, что создаёт предыдущий запуск.
-- ============================================================================

\set ON_ERROR_STOP on
\c postgres


-- ----------------------------------------------------------------------------
-- 0. Очистка после предыдущего запуска.
--    university_test помечена как шаблон, а шаблонную базу удалить нельзя,
--    поэтому сначала снимаем флаг. ALTER DATABASE, в отличие от DROP, можно
--    выполнять внутри DO-блока, что позволяет проверить существование базы.
--    WITH (FORCE) обрывает чужие подключения к удаляемой базе.
-- ----------------------------------------------------------------------------
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_database WHERE datname = 'university_test') THEN
        ALTER DATABASE university_test IS_TEMPLATE false;
    END IF;
END
$$;

DROP DATABASE IF EXISTS university_backup      WITH (FORCE);
DROP DATABASE IF EXISTS university_main        WITH (FORCE);
DROP DATABASE IF EXISTS university_archive     WITH (FORCE);
DROP DATABASE IF EXISTS university_test        WITH (FORCE);
DROP DATABASE IF EXISTS university_distributed WITH (FORCE);
-- Табличное пространство удаляется только после баз, которые в нём лежат.
DROP TABLESPACE IF EXISTS student_data;
DROP TABLESPACE IF EXISTS course_data;


-- ============================================================================
-- Part 1. Multiple Database Management
-- ============================================================================

-- Task 1.1. Базы данных с параметрами ----------------------------------------

-- 1. Владелец - текущий пользователь, шаблон template0, кодировка UTF8.
--    Кодировку, отличную от кодировки template1, можно задать только при
--    копировании из template0, поэтому эти два параметра идут в паре.
--    В отличие от CREATE TABLESPACE, CREATE DATABASE не принимает ключевое
--    слово CURRENT_USER в OWNER, поэтому имя текущего пользователя
--    подставляет psql из своей переменной USER.
CREATE DATABASE university_main
    OWNER      = :"USER"
    TEMPLATE   = template0
    ENCODING   = 'UTF8';

-- 2. Не более 50 одновременных подключений.
CREATE DATABASE university_archive
    TEMPLATE         = template0
    CONNECTION LIMIT = 50;

-- 3. Шаблонная база: её сможет клонировать любой пользователь с правом
--    CREATEDB, а не только владелец.
CREATE DATABASE university_test
    IS_TEMPLATE      = true
    CONNECTION LIMIT = 10;


-- Task 1.2. Табличные пространства --------------------------------------------

-- На Windows сервер принимает '/data/students' как абсолютный путь, но
-- ссылка (junction) pg_tblspc/<oid>, которую он создаёт, без буквы диска
-- не открывается, и первый же объект в табличном пространстве падает с
-- "could not create directory". Поэтому на Windows к пути дописывается диск C:,
-- на Linux/macOS путь остаётся ровно таким, как в задании.
SELECT CASE WHEN version() ILIKE '%windows%' THEN 'C:' ELSE '' END AS drive \gset
\set students_dir :drive'/data/students'
\set courses_dir  :drive'/data/courses'

CREATE TABLESPACE student_data
    LOCATION :'students_dir';

CREATE TABLESPACE course_data
    OWNER CURRENT_USER
    LOCATION :'courses_dir';

-- LATIN9 (ISO-8859-15) несовместима с UTF-8 и Windows-локалями кластера,
-- поэтому для неё явно указана локаль C, которая подходит к любой кодировке.
-- Без этого CREATE DATABASE падает с ошибкой "encoding LATIN9 does not match
-- locale". Смена кодировки, как и выше, требует TEMPLATE template0.
CREATE DATABASE university_distributed
    TEMPLATE   = template0
    ENCODING   = 'LATIN9'
    LC_COLLATE = 'C'
    LC_CTYPE   = 'C'
    TABLESPACE = student_data;


-- ============================================================================
-- Part 2. Complex Table Creation
-- Все таблицы Parts 2-5.1 создаются в базе university_main.
-- ============================================================================
\c university_main

-- Task 2.1. University Management System ---------------------------------------

CREATE TABLE students (
    student_id      SERIAL PRIMARY KEY,
    first_name      VARCHAR(50),
    last_name       VARCHAR(50),
    email           VARCHAR(100),
    phone           CHAR(15),
    date_of_birth   DATE,
    enrollment_date DATE,
    gpa             NUMERIC(3,2),        -- 0.00 .. 9.99, для GPA 0.00-4.00 достаточно
    is_active       BOOLEAN,
    graduation_year SMALLINT
);

CREATE TABLE professors (
    professor_id     SERIAL PRIMARY KEY,
    first_name       VARCHAR(50),
    last_name        VARCHAR(50),
    email            VARCHAR(100),
    office_number    VARCHAR(20),
    hire_date        DATE,
    salary           NUMERIC(12,2),      -- "large decimal": до 9 999 999 999.99
    is_tenured       BOOLEAN,
    years_experience INTEGER
);

CREATE TABLE courses (
    course_id      SERIAL PRIMARY KEY,
    course_code    CHAR(8),
    course_title   VARCHAR(100),
    description    TEXT,
    credits        SMALLINT,
    max_enrollment INTEGER,
    course_fee     NUMERIC(10,2),
    is_online      BOOLEAN,
    created_at     TIMESTAMP WITHOUT TIME ZONE
);


-- Task 2.2. Time-based and Specialized Tables -----------------------------------

CREATE TABLE class_schedule (
    schedule_id  SERIAL PRIMARY KEY,
    course_id    INTEGER,
    professor_id INTEGER,
    classroom    VARCHAR(20),
    class_date   DATE,
    start_time   TIME WITHOUT TIME ZONE,
    end_time     TIME WITHOUT TIME ZONE,
    duration     INTERVAL
);

CREATE TABLE student_records (
    record_id             SERIAL PRIMARY KEY,
    student_id            INTEGER,
    course_id             INTEGER,
    semester              VARCHAR(20),
    year                  INTEGER,
    grade                 CHAR(2),
    attendance_percentage NUMERIC(4,1),  -- 0.0 .. 100.0
    submission_timestamp  TIMESTAMP WITH TIME ZONE,
    last_updated          TIMESTAMP WITH TIME ZONE
);


-- ============================================================================
-- Part 3. Advanced ALTER TABLE Operations
-- ============================================================================

-- Task 3.1. Modifying Existing Tables -------------------------------------------

-- students
ALTER TABLE students ADD COLUMN middle_name    VARCHAR(30);
ALTER TABLE students ADD COLUMN student_status VARCHAR(20);
ALTER TABLE students ALTER COLUMN phone TYPE VARCHAR(20);
ALTER TABLE students ALTER COLUMN student_status SET DEFAULT 'ACTIVE';
ALTER TABLE students ALTER COLUMN gpa SET DEFAULT 0.00;

-- professors
ALTER TABLE professors ADD COLUMN department_code CHAR(5);
ALTER TABLE professors ADD COLUMN research_area   TEXT;
ALTER TABLE professors ALTER COLUMN years_experience TYPE SMALLINT;
ALTER TABLE professors ALTER COLUMN is_tenured SET DEFAULT false;
ALTER TABLE professors ADD COLUMN last_promotion_date DATE;

-- courses
ALTER TABLE courses ADD COLUMN prerequisite_course_id INTEGER;
ALTER TABLE courses ADD COLUMN difficulty_level       SMALLINT;
ALTER TABLE courses ALTER COLUMN course_code TYPE VARCHAR(10);
ALTER TABLE courses ALTER COLUMN credits SET DEFAULT 3;
ALTER TABLE courses ADD COLUMN lab_required BOOLEAN DEFAULT false;


-- Task 3.2. Column Management Operations ----------------------------------------

-- class_schedule
ALTER TABLE class_schedule ADD COLUMN room_capacity INTEGER;
ALTER TABLE class_schedule DROP COLUMN duration;
ALTER TABLE class_schedule ADD COLUMN session_type VARCHAR(15);
ALTER TABLE class_schedule ALTER COLUMN classroom TYPE VARCHAR(30);
ALTER TABLE class_schedule ADD COLUMN equipment_needed TEXT;

-- student_records
ALTER TABLE student_records ADD COLUMN extra_credit_points NUMERIC(4,1);
ALTER TABLE student_records ALTER COLUMN grade TYPE VARCHAR(5);
ALTER TABLE student_records ALTER COLUMN extra_credit_points SET DEFAULT 0.0;
ALTER TABLE student_records ADD COLUMN final_exam_date DATE;
ALTER TABLE student_records DROP COLUMN last_updated;


-- ============================================================================
-- Part 4. Table Relationships and Management
-- ============================================================================

-- Task 4.1. Additional Supporting Tables ----------------------------------------

CREATE TABLE departments (
    department_id    SERIAL PRIMARY KEY,
    department_name  VARCHAR(100),
    department_code  CHAR(5),
    building         VARCHAR(50),
    phone            VARCHAR(15),
    budget           NUMERIC(15,2),      -- "large decimal"
    established_year INTEGER
);

CREATE TABLE library_books (
    book_id               SERIAL PRIMARY KEY,
    isbn                  CHAR(13),      -- ISBN-13 всегда ровно 13 цифр
    title                 VARCHAR(200),
    author                VARCHAR(100),
    publisher             VARCHAR(100),
    publication_date      DATE,
    price                 NUMERIC(8,2),
    is_available          BOOLEAN,
    acquisition_timestamp TIMESTAMP WITHOUT TIME ZONE
);

CREATE TABLE student_book_loans (
    loan_id     SERIAL PRIMARY KEY,
    student_id  INTEGER,
    book_id     INTEGER,
    loan_date   DATE,
    due_date    DATE,
    return_date DATE,
    fine_amount NUMERIC(8,2),
    loan_status VARCHAR(20)
);


-- Task 4.2. Table Modifications for Integration ---------------------------------

-- 1. Столбцы под будущие внешние ключи; сами ограничения FOREIGN KEY
--    по условию задания пока не создаются.
ALTER TABLE professors ADD COLUMN department_id INTEGER;
ALTER TABLE students   ADD COLUMN advisor_id    INTEGER;
ALTER TABLE courses    ADD COLUMN department_id INTEGER;

-- 2. Справочные таблицы.
CREATE TABLE grade_scale (
    grade_id       SERIAL PRIMARY KEY,
    letter_grade   CHAR(2),
    min_percentage NUMERIC(4,1),
    max_percentage NUMERIC(4,1),
    gpa_points     NUMERIC(3,2)
);

CREATE TABLE semester_calendar (
    semester_id           SERIAL PRIMARY KEY,
    semester_name         VARCHAR(20),
    academic_year         INTEGER,
    start_date            DATE,
    end_date              DATE,
    registration_deadline TIMESTAMP WITH TIME ZONE,
    is_current            BOOLEAN
);


-- ============================================================================
-- Part 5. Table Deletion and Cleanup
-- ============================================================================

-- Task 5.1. Conditional Table Operations ----------------------------------------

-- 1. IF EXISTS превращает ошибку об отсутствующей таблице в NOTICE.
DROP TABLE IF EXISTS student_book_loans;
DROP TABLE IF EXISTS library_books;
DROP TABLE IF EXISTS grade_scale;

-- 2. grade_scale с дополнительным столбцом description.
CREATE TABLE grade_scale (
    grade_id       SERIAL PRIMARY KEY,
    letter_grade   CHAR(2),
    min_percentage NUMERIC(4,1),
    max_percentage NUMERIC(4,1),
    gpa_points     NUMERIC(3,2),
    description    TEXT
);

-- 3. CASCADE удаляет вместе с таблицей зависящие от неё объекты
--    (внешние ключи в других таблицах, представления). Сейчас таких нет,
--    но без CASCADE команда упала бы, как только они появятся.
DROP TABLE IF EXISTS semester_calendar CASCADE;

CREATE TABLE semester_calendar (
    semester_id           SERIAL PRIMARY KEY,
    semester_name         VARCHAR(20),
    academic_year         INTEGER,
    start_date            DATE,
    end_date              DATE,
    registration_deadline TIMESTAMP WITH TIME ZONE,
    is_current            BOOLEAN
);


-- Task 5.2. Database Cleanup ------------------------------------------------------

-- Удалять базу, к которой подключён сам сеанс, нельзя, и использовать её
-- как шаблон, пока к ней кто-то подключён, тоже нельзя. Поэтому уходим
-- обратно в postgres.
\c postgres

-- Шаблонную базу PostgreSQL удалить не даст ("cannot drop a template
-- database"), поэтому сначала снимаем с university_test флаг IS_TEMPLATE.
ALTER DATABASE university_test IS_TEMPLATE false;
DROP DATABASE IF EXISTS university_test;
DROP DATABASE IF EXISTS university_distributed;

-- Копия university_main со всеми таблицами из Parts 2-5.
CREATE DATABASE university_backup
    TEMPLATE = university_main;
