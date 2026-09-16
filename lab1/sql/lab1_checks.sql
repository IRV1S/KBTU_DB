-- ============================================================================
-- Проверки к схеме из lab1.sql. Показывают, что ограничения работают
-- на живых данных.
--
-- ЭТОТ ФАЙЛ ЦЕЛИКОМ НЕ ЗАПУСКАТЬ. Часть запросов обязана падать с ошибкой --
-- в этом и смысл проверки. Выполнять по одному блоку: выделить блок мышью
-- и нажать Ctrl+Enter.
--
-- Всё, что меняет данные, обёрнуто в BEGIN ... ROLLBACK, поэтому после любой
-- проверки база возвращается в исходное состояние.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 0. Что вообще лежит в базе
-- ----------------------------------------------------------------------------
SELECT s.name AS student, c.title AS course, e.semester, e.grade
FROM Enrollment e
    JOIN Student s ON s.StudentID = e.StudentID
    JOIN Course  c ON c.CourseID  = e.CourseID
ORDER BY s.name, e.semester;


-- ----------------------------------------------------------------------------
-- 1. Зачем Semester входит в первичный ключ
--    Студент 1001 проходил CSCI1510 дважды: 'F' осенью, 'A' весной.
--    Ключ из двух атрибутов (StudentID, CourseID) вторую строку запретил бы.
-- ----------------------------------------------------------------------------
SELECT * FROM Enrollment
WHERE StudentID = 1001 AND CourseID = 'CSCI1510'
ORDER BY Semester;

-- А вот полный дубликат ключа база не пропустит.
-- ОЖИДАЕТСЯ ОШИБКА 23505: duplicate key value violates unique constraint
INSERT INTO Enrollment VALUES (1001, 'CSCI1510', '2024FA', 'B');


-- ----------------------------------------------------------------------------
-- 2. FK5 CASCADE против FK6 RESTRICT -- намеренная асимметрия
-- ----------------------------------------------------------------------------

-- FK5: удаляем студента -- его записи на курсы уходят следом.
-- Было 8 строк в Enrollment, у студента 1004 их две, останется 6.
BEGIN;
    DELETE FROM Student WHERE StudentID = 1004;
    SELECT count(*) AS enrollment_rows_left FROM Enrollment;
ROLLBACK;

-- FK6: удалить курс, на который кто-то записан, нельзя.
-- Запись с выставленной оценкой должна пережить исключение курса из каталога.
-- ОЖИДАЕТСЯ ОШИБКА 23503: update or delete on table "course" violates
-- foreign key constraint "fk6_enrollment_course"
DELETE FROM Course WHERE CourseID = 'CSCI1510';


-- ----------------------------------------------------------------------------
-- 3. FK1 SET NULL -- уволившийся преподаватель не забирает с собой студентов
--    У 1002 куратор -- преподаватель 102. После его удаления AdvisorID
--    становится NULL, а сам студент остаётся.
-- ----------------------------------------------------------------------------
BEGIN;
    DELETE FROM Professor WHERE ProfID = 102;
    SELECT StudentID, Name, AdvisorID FROM Student WHERE StudentID = 1002;
ROLLBACK;


-- ----------------------------------------------------------------------------
-- 4. FK4 SET NULL -- уходящий заведующий не забирает с собой кафедру
--    Преподаватель 101 заведует CSCI. Кафедра остаётся, ChairID обнуляется.
--    Именно это и требует, чтобы ChairID допускал NULL.
-- ----------------------------------------------------------------------------
BEGIN;
    DELETE FROM Professor WHERE ProfID = 101;
    SELECT DeptCode, DeptName, ChairID FROM Department WHERE DeptCode = 'CSCI';
ROLLBACK;


-- ----------------------------------------------------------------------------
-- 5. FK2 RESTRICT -- кафедру нельзя удалить, пока на ней есть преподаватели
--    Сначала их нужно перевести. На PHYS числится преподаватель 104.
--    ОЖИДАЕТСЯ ОШИБКА 23503
-- ----------------------------------------------------------------------------
DELETE FROM Department WHERE DeptCode = 'PHYS';


-- ----------------------------------------------------------------------------
-- 6. Почему FK4 -- это 1:1, а не N:1
--    Внешний ключ сам по себе всегда даёт N:1: без UNIQUE(ChairID) одного
--    преподавателя можно было бы назначить заведующим двух кафедр сразу.
--    101 уже заведует CSCI, пробуем назначить его же на MATH.
--    ОЖИДАЕТСЯ ОШИБКА 23505: нарушение uq_department_chair
-- ----------------------------------------------------------------------------
UPDATE Department SET ChairID = 101 WHERE DeptCode = 'MATH';


-- ----------------------------------------------------------------------------
-- 7. ON UPDATE CASCADE на естественном ключе
--    DeptCode перекодируют при реорганизации факультета. Переименование
--    кафедры само расходится по Professor и Course.
-- ----------------------------------------------------------------------------
BEGIN;
    UPDATE Department SET DeptCode = 'COMP' WHERE DeptCode = 'CSCI';
    SELECT 'Professor' AS tbl, ProfID::text AS id, DeptCode AS dept
        FROM Professor WHERE DeptCode = 'COMP'
    UNION ALL
    SELECT 'Course', CourseID, DepartmentCode
        FROM Course WHERE DepartmentCode = 'COMP';
ROLLBACK;

-- Обратите внимание: Student.Major остался 'CSCI'. Каскад его не тронул,
-- потому что у Major внешнего ключа нет -- это тот самый свободный текст,
-- на который указывает отчёт. FK7 из отчёта чинит ровно это.


-- ----------------------------------------------------------------------------
-- 8. Ссылочный цикл Professor <-> Department
--    Кафедра может существовать без заведующего -- только благодаря этому
--    базу вообще можно заполнить. Будь ChairID объявлен NOT NULL, ни одна
--    из двух таблиц не приняла бы свою первую строку.
-- ----------------------------------------------------------------------------
BEGIN;
    INSERT INTO Department (DeptCode, DeptName, Budget, ChairID)
        VALUES ('CHEM', 'Chemistry', 500000.00, NULL);
    SELECT DeptCode, DeptName, ChairID FROM Department ORDER BY DeptCode;
ROLLBACK;


-- ----------------------------------------------------------------------------
-- 9. Все внешние ключи схемы -- глазами самой СУБД
--    Полезно, если попросят показать, что ссылочные действия именно такие,
--    как заявлено в отчёте.
-- ----------------------------------------------------------------------------
SELECT
    c.conname                          AS constraint_name,
    src.relname                        AS child_table,
    tgt.relname                        AS parent_table,
    CASE c.confdeltype WHEN 'a' THEN 'NO ACTION' WHEN 'r' THEN 'RESTRICT'
                       WHEN 'c' THEN 'CASCADE'   WHEN 'n' THEN 'SET NULL'
                       WHEN 'd' THEN 'SET DEFAULT' END AS on_delete,
    CASE c.confupdtype WHEN 'a' THEN 'NO ACTION' WHEN 'r' THEN 'RESTRICT'
                       WHEN 'c' THEN 'CASCADE'   WHEN 'n' THEN 'SET NULL'
                       WHEN 'd' THEN 'SET DEFAULT' END AS on_update
FROM pg_constraint c
    JOIN pg_class src ON src.oid = c.conrelid
    JOIN pg_class tgt ON tgt.oid = c.confrelid
WHERE c.contype = 'f'
  AND connamespace = 'public'::regnamespace
ORDER BY c.conname;
