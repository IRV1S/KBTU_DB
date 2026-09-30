SELECT s.name AS student, c.title AS course, e.semester, e.grade
FROM Enrollment e
    JOIN Student s ON s.StudentID = e.StudentID
    JOIN Course  c ON c.CourseID  = e.CourseID
ORDER BY s.name, e.semester;

SELECT * FROM Enrollment
WHERE StudentID = 1001 AND CourseID = 'CSCI1510'
ORDER BY Semester;

INSERT INTO Enrollment VALUES (1001, 'CSCI1510', '2024FA', 'B');

BEGIN;
    DELETE FROM Student WHERE StudentID = 1004;
    SELECT count(*) AS enrollment_rows_left FROM Enrollment;
ROLLBACK;

DELETE FROM Course WHERE CourseID = 'CSCI1510';

BEGIN;
    DELETE FROM Professor WHERE ProfID = 102;
    SELECT StudentID, Name, AdvisorID FROM Student WHERE StudentID = 1002;
ROLLBACK;

BEGIN;
    DELETE FROM Professor WHERE ProfID = 101;
    SELECT DeptCode, DeptName, ChairID FROM Department WHERE DeptCode = 'CSCI';
ROLLBACK;

DELETE FROM Department WHERE DeptCode = 'PHYS';

UPDATE Department SET ChairID = 101 WHERE DeptCode = 'MATH';

BEGIN;
    UPDATE Department SET DeptCode = 'COMP' WHERE DeptCode = 'CSCI';
    SELECT 'Professor' AS tbl, ProfID::text AS id, DeptCode AS dept
        FROM Professor WHERE DeptCode = 'COMP'
    UNION ALL
    SELECT 'Course', CourseID, DepartmentCode
        FROM Course WHERE DepartmentCode = 'COMP';
ROLLBACK;

BEGIN;
    INSERT INTO Department (DeptCode, DeptName, Budget, ChairID)
        VALUES ('CHEM', 'Chemistry', 500000.00, NULL);
    SELECT DeptCode, DeptName, ChairID FROM Department ORDER BY DeptCode;
ROLLBACK;

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
