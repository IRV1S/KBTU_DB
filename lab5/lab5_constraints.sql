\set ON_ERROR_STOP on
\c postgres

DROP DATABASE IF EXISTS constraints_lab WITH (FORCE);
CREATE DATABASE constraints_lab;

\c constraints_lab

CREATE PROCEDURE expect_violation(expected text, stmt text)
LANGUAGE plpgsql
AS $$
DECLARE
    v_schema     text;
    v_table      text;
    v_column     text;
    v_constraint text;
    v_detail     text;
BEGIN
    EXECUTE stmt;
    RAISE EXCEPTION 'statement succeeded, expected % to be violated', expected
        USING DETAIL = stmt;
EXCEPTION
    WHEN integrity_constraint_violation THEN
        GET STACKED DIAGNOSTICS
            v_schema     = SCHEMA_NAME,
            v_table      = TABLE_NAME,
            v_column     = COLUMN_NAME,
            v_constraint = CONSTRAINT_NAME,
            v_detail     = PG_EXCEPTION_DETAIL;
        IF v_constraint = '' THEN
            SELECT c.conname INTO v_constraint
            FROM pg_constraint c
            JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = c.conkey[1]
            WHERE c.conrelid = format('%I.%I', v_schema, v_table)::regclass
              AND c.contype = 'n'
              AND a.attname = v_column;
        END IF;
        IF v_constraint IS DISTINCT FROM expected THEN
            RAISE EXCEPTION 'expected % to be violated, got %', expected, coalesce(v_constraint, '?')
                USING DETAIL = SQLERRM;
        END IF;
        RAISE NOTICE '%', SQLERRM USING DETAIL = v_detail;
END
$$;

CREATE TABLE employees (
    employee_id integer,
    first_name  text,
    last_name   text,
    age         integer CHECK (age BETWEEN 18 AND 65),
    salary      numeric CHECK (salary > 0)
);

CREATE TABLE products_catalog (
    product_id     integer,
    product_name   text,
    regular_price  numeric,
    discount_price numeric,
    CONSTRAINT valid_discount CHECK (
        regular_price > 0
        AND discount_price > 0
        AND discount_price < regular_price
    )
);

CREATE TABLE bookings (
    booking_id     integer,
    check_in_date  date,
    check_out_date date,
    num_guests     integer CHECK (num_guests BETWEEN 1 AND 10),
    CONSTRAINT valid_dates CHECK (check_out_date > check_in_date)
);

INSERT INTO employees VALUES
    (1, 'Aidar', 'Nurlanov', 25, 350000),
    (2, 'Dana',  'Seitkali', 41, 520000),
    (3, 'Marat', 'Ospanov',  18, 180000),
    (4, 'Aliya', 'Kim',      65, 610000);

INSERT INTO employees VALUES
    (5, 'Timur', 'Bekov', NULL, NULL);

CALL expect_violation('employees_age_check', $$
    INSERT INTO employees VALUES (10, 'Erlan', 'Sadykov', 17, 250000)
$$);

CALL expect_violation('employees_age_check', $$
    INSERT INTO employees VALUES (11, 'Gulnar', 'Abenova', 66, 400000)
$$);

CALL expect_violation('employees_salary_check', $$
    INSERT INTO employees VALUES (12, 'Nurlan', 'Zhakupov', 30, 0)
$$);

CALL expect_violation('employees_salary_check', $$
    INSERT INTO employees VALUES (13, 'Saule', 'Akhmetova', 28, -50000)
$$);

INSERT INTO products_catalog VALUES
    (1, 'Laptop',     450000, 399000),
    (2, 'Headphones',  35000,  29990),
    (3, 'Backpack',    18000,  17999.99);

CALL expect_violation('valid_discount', $$
    INSERT INTO products_catalog VALUES (10, 'Broken price', -5000, 1000)
$$);

CALL expect_violation('valid_discount', $$
    INSERT INTO products_catalog VALUES (11, 'Free gift', 5000, 0)
$$);

CALL expect_violation('valid_discount', $$
    INSERT INTO products_catalog VALUES (12, 'Fake sale', 5000, 5000)
$$);

CALL expect_violation('valid_discount', $$
    INSERT INTO products_catalog VALUES (13, 'Markup', 5000, 6500)
$$);

INSERT INTO bookings VALUES
    (1, '2026-11-01', '2026-11-05',  2),
    (2, '2026-12-30', '2027-01-02', 10),
    (3, '2026-11-10', '2026-11-11',  1);

CALL expect_violation('bookings_num_guests_check', $$
    INSERT INTO bookings VALUES (10, '2026-11-01', '2026-11-03', 0)
$$);

CALL expect_violation('bookings_num_guests_check', $$
    INSERT INTO bookings VALUES (11, '2026-11-01', '2026-11-03', 11)
$$);

CALL expect_violation('valid_dates', $$
    INSERT INTO bookings VALUES (12, '2026-11-05', '2026-11-05', 2)
$$);

CALL expect_violation('valid_dates', $$
    INSERT INTO bookings VALUES (13, '2026-11-05', '2026-11-01', 2)
$$);

CREATE TABLE customers (
    customer_id       integer NOT NULL,
    email             text    NOT NULL,
    phone             text,
    registration_date date    NOT NULL
);

CREATE TABLE inventory (
    item_id      integer   NOT NULL,
    item_name    text      NOT NULL,
    quantity     integer   NOT NULL CHECK (quantity >= 0),
    unit_price   numeric   NOT NULL CHECK (unit_price > 0),
    last_updated timestamp NOT NULL
);

INSERT INTO customers VALUES
    (1, 'aidar@example.com', '+7 701 555 0101', '2026-01-15'),
    (2, 'dana@example.com',  '+7 702 555 0102', '2026-02-20');

INSERT INTO inventory VALUES
    (1, 'USB-C cable', 120,  2500, '2026-10-01 09:30:00'),
    (2, 'Keyboard',      0, 15000, '2026-10-05 14:00:00'),
    (3, 'Monitor',       7, 95000, LOCALTIMESTAMP);

CALL expect_violation('customers_customer_id_not_null', $$
    INSERT INTO customers VALUES (NULL, 'nobody@example.com', NULL, '2026-03-01')
$$);

CALL expect_violation('customers_email_not_null', $$
    INSERT INTO customers VALUES (3, NULL, '+7 705 555 0103', '2026-03-01')
$$);

CALL expect_violation('customers_registration_date_not_null', $$
    INSERT INTO customers (customer_id, email) VALUES (3, 'late@example.com')
$$);

CALL expect_violation('inventory_item_id_not_null', $$
    INSERT INTO inventory VALUES (NULL, 'Mouse', 10, 5000, LOCALTIMESTAMP)
$$);

CALL expect_violation('inventory_item_name_not_null', $$
    INSERT INTO inventory VALUES (4, NULL, 10, 5000, LOCALTIMESTAMP)
$$);

CALL expect_violation('inventory_quantity_not_null', $$
    INSERT INTO inventory VALUES (4, 'Mouse', NULL, 5000, LOCALTIMESTAMP)
$$);

CALL expect_violation('inventory_unit_price_not_null', $$
    INSERT INTO inventory VALUES (4, 'Mouse', 10, NULL, LOCALTIMESTAMP)
$$);

CALL expect_violation('inventory_last_updated_not_null', $$
    INSERT INTO inventory VALUES (4, 'Mouse', 10, 5000, NULL)
$$);

CALL expect_violation('inventory_quantity_check', $$
    INSERT INTO inventory VALUES (4, 'Mouse', -1, 5000, LOCALTIMESTAMP)
$$);

CALL expect_violation('inventory_unit_price_check', $$
    INSERT INTO inventory VALUES (4, 'Mouse', 10, 0, LOCALTIMESTAMP)
$$);

INSERT INTO customers VALUES
    (3, 'marat@example.com', NULL, '2026-03-01');

INSERT INTO customers (customer_id, email, registration_date)
VALUES (4, 'aliya@example.com', CURRENT_DATE);

SELECT *
FROM customers
WHERE phone IS NULL;

CREATE TABLE users (
    user_id    integer,
    username   text UNIQUE,
    email      text UNIQUE,
    created_at timestamp
);

CREATE TABLE course_enrollments (
    enrollment_id integer,
    student_id    integer,
    course_code   text,
    semester      text,
    UNIQUE (student_id, course_code, semester)
);

INSERT INTO users VALUES
    (1, 'aidar', 'aidar@example.com', '2026-09-01 10:00:00'),
    (2, 'dana',  'dana@example.com',  '2026-09-02 11:30:00'),
    (3, 'marat', NULL,                '2026-09-03 08:15:00'),
    (4, 'aliya', NULL,                '2026-09-04 19:45:00');

CALL expect_violation('users_username_key', $$
    INSERT INTO users VALUES (5, 'aidar', 'aidar.n@example.com', LOCALTIMESTAMP)
$$);

CALL expect_violation('users_email_key', $$
    INSERT INTO users VALUES (5, 'dana_s', 'dana@example.com', LOCALTIMESTAMP)
$$);

INSERT INTO course_enrollments VALUES
    (1, 1001, 'CSCI2106', 'Fall 2026'),
    (2, 1001, 'MATH1101', 'Fall 2026'),
    (3, 1002, 'CSCI2106', 'Fall 2026'),
    (4, 1001, 'CSCI2106', 'Spring 2027');

CALL expect_violation('course_enrollments_student_id_course_code_semester_key', $$
    INSERT INTO course_enrollments VALUES (5, 1001, 'CSCI2106', 'Fall 2026')
$$);

ALTER TABLE users
    DROP CONSTRAINT users_username_key,
    DROP CONSTRAINT users_email_key,
    ADD CONSTRAINT unique_username UNIQUE (username),
    ADD CONSTRAINT unique_email UNIQUE (email);

CALL expect_violation('unique_username', $$
    INSERT INTO users VALUES (5, 'dana', 'dana.new@example.com', LOCALTIMESTAMP)
$$);

CALL expect_violation('unique_email', $$
    INSERT INTO users VALUES (5, 'aidar_n', 'aidar@example.com', LOCALTIMESTAMP)
$$);

SELECT conname, pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid = 'users'::regclass;

CREATE TABLE departments (
    dept_id   integer PRIMARY KEY,
    dept_name text NOT NULL,
    location  text
);

INSERT INTO departments VALUES
    (1, 'IT',       'Almaty'),
    (2, 'Finance',  'Astana'),
    (3, 'HR',       'Almaty'),
    (4, 'Research', NULL);

CALL expect_violation('departments_pkey', $$
    INSERT INTO departments VALUES (1, 'Marketing', 'Shymkent')
$$);

CALL expect_violation('departments_dept_id_not_null', $$
    INSERT INTO departments VALUES (NULL, 'Marketing', 'Shymkent')
$$);

CREATE TABLE student_courses (
    student_id      integer,
    course_id       integer,
    enrollment_date date,
    grade           text,
    PRIMARY KEY (student_id, course_id)
);

INSERT INTO student_courses VALUES
    (1001, 101, '2026-09-01', 'A'),
    (1001, 102, '2026-09-01', 'B+'),
    (1002, 101, '2026-09-02', NULL);

CALL expect_violation('student_courses_pkey', $$
    INSERT INTO student_courses VALUES (1001, 101, '2026-09-10', 'C')
$$);

CALL expect_violation('student_courses_course_id_not_null', $$
    INSERT INTO student_courses VALUES (1003, NULL, '2026-09-10', NULL)
$$);

CREATE TABLE employees_dept (
    emp_id    integer PRIMARY KEY,
    emp_name  text NOT NULL,
    dept_id   integer REFERENCES departments,
    hire_date date
);

INSERT INTO employees_dept VALUES
    (1, 'Aidar Nurlanov', 1,    '2024-02-01'),
    (2, 'Dana Seitkali',  2,    '2023-07-15'),
    (3, 'Marat Ospanov',  1,    '2025-03-10'),
    (4, 'Aliya Kim',      NULL, '2026-01-20');

CALL expect_violation('employees_dept_dept_id_fkey', $$
    INSERT INTO employees_dept VALUES (5, 'Timur Bekov', 99, '2026-02-01')
$$);

CREATE TABLE authors (
    author_id   integer PRIMARY KEY,
    author_name text NOT NULL,
    country     text
);

CREATE TABLE publishers (
    publisher_id   integer PRIMARY KEY,
    publisher_name text NOT NULL,
    city           text
);

CREATE TABLE books (
    book_id          integer PRIMARY KEY,
    title            text NOT NULL,
    author_id        integer REFERENCES authors,
    publisher_id     integer REFERENCES publishers,
    publication_year integer,
    isbn             text UNIQUE
);

INSERT INTO authors VALUES
    (1, 'Abai Kunanbayev',   'Kazakhstan'),
    (2, 'Mukhtar Auezov',    'Kazakhstan'),
    (3, 'Fyodor Dostoevsky', 'Russia'),
    (4, 'George Orwell',     'United Kingdom');

INSERT INTO publishers VALUES
    (1, 'Foliant',       'Astana'),
    (2, 'Atamura',       'Almaty'),
    (3, 'Penguin Books', 'London');

INSERT INTO books VALUES
    (1, 'Book of Words',        1, 1, 2020, '978-601-0000-01-1'),
    (2, 'The Path of Abai',     2, 2, 2017, '978-601-0000-02-8'),
    (3, 'Crime and Punishment', 3, 3, 2003, '978-0-14-000003-3'),
    (4, 'Nineteen Eighty-Four', 4, 3, 2008, '978-0-14-000004-0'),
    (5, 'Animal Farm',          4, 3, 2008, '978-0-14-000005-7');

CALL expect_violation('books_isbn_key', $$
    INSERT INTO books VALUES (6, 'Animal Farm (reprint)', 4, 3, 2021, '978-0-14-000005-7')
$$);

CALL expect_violation('books_author_id_fkey', $$
    INSERT INTO books VALUES (6, 'Unknown Author Book', 99, 1, 2021, '978-601-0000-06-6')
$$);

CALL expect_violation('books_publisher_id_fkey', $$
    INSERT INTO books VALUES (6, 'Self-published Book', 1, 99, 2021, '978-601-0000-06-6')
$$);

SELECT b.book_id, b.title, a.author_name, p.publisher_name, b.publication_year, b.isbn
FROM books b
JOIN authors a USING (author_id)
JOIN publishers p USING (publisher_id)
ORDER BY b.book_id;

CREATE TABLE categories (
    category_id   integer PRIMARY KEY,
    category_name text NOT NULL
);

CREATE TABLE products_fk (
    product_id   integer PRIMARY KEY,
    product_name text NOT NULL,
    category_id  integer REFERENCES categories ON DELETE RESTRICT
);

CREATE TABLE orders (
    order_id   integer PRIMARY KEY,
    order_date date NOT NULL
);

CREATE TABLE order_items (
    item_id    integer PRIMARY KEY,
    order_id   integer REFERENCES orders ON DELETE CASCADE,
    product_id integer REFERENCES products_fk,
    quantity   integer CHECK (quantity > 0)
);

INSERT INTO categories VALUES
    (1, 'Electronics'),
    (2, 'Books'),
    (3, 'Toys');

INSERT INTO products_fk VALUES
    (1, 'Smartphone',   1),
    (2, 'Headphones',   1),
    (3, 'SQL Textbook', 2);

INSERT INTO orders VALUES
    (1, '2026-10-01'),
    (2, '2026-10-05');

INSERT INTO order_items VALUES
    (1, 1, 1, 1),
    (2, 1, 2, 2),
    (3, 2, 3, 1),
    (4, 2, 2, 1);

CALL expect_violation('order_items_quantity_check', $$
    INSERT INTO order_items VALUES (5, 2, 1, 0)
$$);

CALL expect_violation('products_fk_category_id_fkey', $$
    DELETE FROM categories WHERE category_id = 1
$$);

DELETE FROM categories
WHERE category_id = 3
RETURNING *;

CALL expect_violation('order_items_product_id_fkey', $$
    DELETE FROM products_fk WHERE product_id = 3
$$);

SELECT *
FROM order_items
ORDER BY item_id;

DELETE FROM orders
WHERE order_id = 1
RETURNING *;

SELECT *
FROM order_items
ORDER BY item_id;

CREATE SCHEMA ecommerce;
SET search_path TO ecommerce, public;

CREATE TABLE customers (
    customer_id       integer PRIMARY KEY,
    name              text    NOT NULL,
    email             text    NOT NULL UNIQUE,
    phone             text,
    registration_date date    NOT NULL DEFAULT CURRENT_DATE
);

CREATE TABLE products (
    product_id     integer        PRIMARY KEY,
    name           text           NOT NULL,
    description    text,
    price          numeric(10, 2) NOT NULL CHECK (price >= 0),
    stock_quantity integer        NOT NULL DEFAULT 0 CHECK (stock_quantity >= 0)
);

CREATE TABLE orders (
    order_id     integer        PRIMARY KEY,
    customer_id  integer        NOT NULL REFERENCES customers ON DELETE RESTRICT,
    order_date   date           NOT NULL DEFAULT CURRENT_DATE,
    total_amount numeric(12, 2) NOT NULL DEFAULT 0 CHECK (total_amount >= 0),
    status       text           NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'processing', 'shipped', 'delivered', 'cancelled'))
);

CREATE TABLE order_details (
    order_detail_id integer        PRIMARY KEY,
    order_id        integer        NOT NULL REFERENCES orders ON DELETE CASCADE,
    product_id      integer        NOT NULL REFERENCES products ON DELETE RESTRICT,
    quantity        integer        NOT NULL CHECK (quantity > 0),
    unit_price      numeric(10, 2) NOT NULL CHECK (unit_price >= 0),
    UNIQUE (order_id, product_id)
);

INSERT INTO customers VALUES
    (1, 'Aidar Nurlanov', 'aidar.nurlanov@example.com', '+7 701 555 0101', '2026-01-12'),
    (2, 'Dana Seitkali',  'dana.seitkali@example.com',  '+7 702 555 0102', '2026-02-03'),
    (3, 'Marat Ospanov',  'marat.ospanov@example.com',  NULL,              '2026-03-21'),
    (4, 'Aliya Kim',      'aliya.kim@example.com',      '+7 705 555 0104', '2026-05-09'),
    (5, 'Timur Bekov',    'timur.bekov@example.com',    '+7 707 555 0105', '2026-07-30');

INSERT INTO products VALUES
    (1, 'Wireless Mouse',      '2.4 GHz, silent buttons',      7990.00, 50),
    (2, 'Mechanical Keyboard', 'Tenkeyless, brown switches',  32990.00, 20),
    (3, '27-inch Monitor',     'IPS, 2560x1440, 75 Hz',      119990.00,  8),
    (4, 'USB-C Hub',           '7-in-1, HDMI 4K, PD 100 W',   14990.00, 35),
    (5, 'Laptop Stand',        'Aluminium, adjustable',        9990.00,  0),
    (6, 'Webcam',              '1080p, built-in microphone',  19990.00, 15);

INSERT INTO orders VALUES
    (1, 1, '2026-09-01',  40980.00, 'delivered'),
    (2, 2, '2026-09-15', 134980.00, 'shipped'),
    (3, 1, '2026-10-02',  15980.00, 'processing'),
    (4, 3, '2026-10-08',  29980.00, 'pending'),
    (5, 4, '2026-10-10', 119990.00, 'cancelled');

INSERT INTO order_details VALUES
    (1, 1, 2, 1,  32990.00),
    (2, 1, 1, 1,   7990.00),
    (3, 2, 3, 1, 119990.00),
    (4, 2, 4, 1,  14990.00),
    (5, 3, 1, 2,   7990.00),
    (6, 4, 6, 1,  19990.00),
    (7, 4, 5, 1,   9990.00),
    (8, 5, 3, 1, 119990.00);

SELECT o.order_id,
       o.total_amount,
       SUM(d.quantity * d.unit_price) AS details_sum
FROM orders o
JOIN order_details d USING (order_id)
GROUP BY o.order_id, o.total_amount
ORDER BY o.order_id;

CALL expect_violation('customers_pkey', $$
    INSERT INTO customers VALUES (1, 'Erlan Sadykov', 'erlan.sadykov@example.com', NULL, CURRENT_DATE)
$$);

CALL expect_violation('customers_email_key', $$
    INSERT INTO customers VALUES (6, 'Dana S.', 'dana.seitkali@example.com', NULL, CURRENT_DATE)
$$);

CALL expect_violation('customers_name_not_null', $$
    INSERT INTO customers (customer_id, email) VALUES (6, 'anonymous@example.com')
$$);

CALL expect_violation('products_price_check', $$
    INSERT INTO products VALUES (7, 'Mouse Pad', NULL, -500, 10)
$$);

CALL expect_violation('products_stock_quantity_check', $$
    INSERT INTO products VALUES (7, 'Mouse Pad', NULL, 2990, -1)
$$);

CALL expect_violation('products_stock_quantity_check', $$
    UPDATE products SET stock_quantity = stock_quantity - 10 WHERE product_id = 3
$$);

CALL expect_violation('orders_status_check', $$
    INSERT INTO orders VALUES (6, 2, CURRENT_DATE, 7990, 'returned')
$$);

CALL expect_violation('orders_status_check', $$
    UPDATE orders SET status = 'lost' WHERE order_id = 2
$$);

CALL expect_violation('orders_total_amount_check', $$
    INSERT INTO orders VALUES (6, 2, CURRENT_DATE, -100, 'pending')
$$);

CALL expect_violation('orders_customer_id_fkey', $$
    INSERT INTO orders VALUES (6, 99, CURRENT_DATE, 7990, 'pending')
$$);

CALL expect_violation('order_details_quantity_check', $$
    INSERT INTO order_details VALUES (9, 3, 4, 0, 14990)
$$);

CALL expect_violation('order_details_order_id_fkey', $$
    INSERT INTO order_details VALUES (9, 99, 4, 1, 14990)
$$);

CALL expect_violation('order_details_product_id_fkey', $$
    INSERT INTO order_details VALUES (9, 3, 99, 1, 14990)
$$);

CALL expect_violation('order_details_order_id_product_id_key', $$
    INSERT INTO order_details VALUES (9, 3, 1, 1, 7990)
$$);

CALL expect_violation('orders_customer_id_fkey', $$
    DELETE FROM customers WHERE customer_id = 1
$$);

CALL expect_violation('order_details_product_id_fkey', $$
    DELETE FROM products WHERE product_id = 3
$$);

UPDATE orders
SET status = 'shipped'
WHERE order_id = 3
RETURNING order_id, status;

INSERT INTO orders (order_id, customer_id)
VALUES (6, 2)
RETURNING *;

DELETE FROM customers
WHERE customer_id = 5
RETURNING *;

SELECT order_id, COUNT(*) AS items
FROM order_details
GROUP BY order_id
ORDER BY order_id;

DELETE FROM orders
WHERE order_id = 5
RETURNING *;

SELECT order_id, COUNT(*) AS items
FROM order_details
GROUP BY order_id
ORDER BY order_id;

SELECT conrelid::regclass AS table_name,
       conname,
       pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE connamespace = 'ecommerce'::regnamespace
ORDER BY conrelid, contype, conname;
