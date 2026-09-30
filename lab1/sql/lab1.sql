DROP TABLE IF EXISTS Enrollment CASCADE;
DROP TABLE IF EXISTS Course     CASCADE;
DROP TABLE IF EXISTS Student    CASCADE;
DROP TABLE IF EXISTS Professor  CASCADE;
DROP TABLE IF EXISTS Department CASCADE;

CREATE TABLE Department (
    DeptCode  CHAR(4)       NOT NULL,
    DeptName  VARCHAR(100)  NOT NULL,
    Budget    DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    ChairID   INT           NULL,
    CONSTRAINT PK_Department       PRIMARY KEY (DeptCode),
    CONSTRAINT UQ_Department_Name  UNIQUE (DeptName),
    CONSTRAINT UQ_Department_Chair UNIQUE (ChairID)
);

CREATE TABLE Professor (
    ProfID    INT           NOT NULL,
    Name      VARCHAR(100)  NOT NULL,
    DeptCode  CHAR(4)       NOT NULL,
    Salary    DECIMAL(10,2) NULL,
    CONSTRAINT PK_Professor PRIMARY KEY (ProfID),
    CONSTRAINT FK2_Professor_Department FOREIGN KEY (DeptCode)
        REFERENCES Department (DeptCode)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

ALTER TABLE Department
    ADD CONSTRAINT FK4_Department_Chair FOREIGN KEY (ChairID)
        REFERENCES Professor (ProfID)
        ON DELETE SET NULL ON UPDATE NO ACTION;

CREATE TABLE Student (
    StudentID INT           NOT NULL,
    Name      VARCHAR(100)  NOT NULL,
    Email     VARCHAR(255)  NOT NULL,
    Major     CHAR(4)       NULL,
    AdvisorID INT           NULL,
    CONSTRAINT PK_Student       PRIMARY KEY (StudentID),
    CONSTRAINT UQ_Student_Email UNIQUE (Email),
    CONSTRAINT FK1_Student_Advisor FOREIGN KEY (AdvisorID)
        REFERENCES Professor (ProfID)
        ON DELETE SET NULL ON UPDATE NO ACTION
);

CREATE TABLE Course (
    CourseID       CHAR(8)      NOT NULL,
    Title          VARCHAR(150) NOT NULL,
    Credits        SMALLINT     NOT NULL,
    DepartmentCode CHAR(4)      NOT NULL,
    CONSTRAINT PK_Course PRIMARY KEY (CourseID),
    CONSTRAINT FK3_Course_Department FOREIGN KEY (DepartmentCode)
        REFERENCES Department (DeptCode)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE Enrollment (
    StudentID INT        NOT NULL,
    CourseID  CHAR(8)    NOT NULL,
    Semester  CHAR(6)    NOT NULL,
    Grade     VARCHAR(2) NULL,
    CONSTRAINT PK_Enrollment PRIMARY KEY (StudentID, CourseID, Semester),
    CONSTRAINT FK5_Enrollment_Student FOREIGN KEY (StudentID)
        REFERENCES Student (StudentID)
        ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT FK6_Enrollment_Course FOREIGN KEY (CourseID)
        REFERENCES Course (CourseID)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

INSERT INTO Department (DeptCode, DeptName, Budget, ChairID) VALUES
    ('CSCI', 'Computer Science', 1250000.00, NULL),
    ('MATH', 'Mathematics',       890000.00, NULL),
    ('PHYS', 'Physics',          1100000.00, NULL);

INSERT INTO Professor (ProfID, Name, DeptCode, Salary) VALUES
    (101, 'Aigerim Nurlanova', 'CSCI', 780000.00),
    (102, 'Daniyar Seitkali',  'CSCI', 640000.00),
    (103, 'Marat Iskakov',     'MATH', 710000.00),
    (104, 'Elena Voronova',    'PHYS', 695000.00);

UPDATE Department SET ChairID = 101 WHERE DeptCode = 'CSCI';
UPDATE Department SET ChairID = 103 WHERE DeptCode = 'MATH';
UPDATE Department SET ChairID = 104 WHERE DeptCode = 'PHYS';

INSERT INTO Student (StudentID, Name, Email, Major, AdvisorID) VALUES
    (1001, 'Erdaulet Aitzhanov', 'e.aitzhanov@kbtu.kz', 'CSCI', 101),
    (1002, 'Aruzhan Bekova',     'a.bekova@kbtu.kz',    'CSCI', 102),
    (1003, 'Timur Zhaksylyk',    't.zhaksylyk@kbtu.kz', 'MATH', 103),
    (1004, 'Dana Omarova',       'd.omarova@kbtu.kz',   NULL,   NULL);

INSERT INTO Course (CourseID, Title, Credits, DepartmentCode) VALUES
    ('CSCI1510', 'Introduction to Databases', 3, 'CSCI'),
    ('CSCI2620', 'Data Structures',           4, 'CSCI'),
    ('MATH1410', 'Discrete Mathematics',      3, 'MATH'),
    ('PHYS2100', 'Classical Mechanics',       4, 'PHYS');

INSERT INTO Enrollment (StudentID, CourseID, Semester, Grade) VALUES
    (1001, 'CSCI1510', '2024FA', 'F'),
    (1001, 'CSCI1510', '2025SP', 'A'),
    (1001, 'CSCI2620', '2025SP', 'B+'),
    (1002, 'CSCI1510', '2024FA', 'A-'),
    (1002, 'CSCI2620', '2025SP', 'B'),
    (1003, 'MATH1410', '2025SP', NULL),
    (1004, 'CSCI1510', '2025SP', 'C+'),
    (1004, 'PHYS2100', '2025SP', 'B-');

SELECT 'Department' AS relation, count(*) FROM Department
UNION ALL SELECT 'Professor',  count(*) FROM Professor
UNION ALL SELECT 'Student',    count(*) FROM Student
UNION ALL SELECT 'Course',     count(*) FROM Course
UNION ALL SELECT 'Enrollment', count(*) FROM Enrollment;
