-- ============================================================================
-- Задание 1.2. Университетская схема: 5 отношений, 6 внешних ключей.
-- Диалект: PostgreSQL 18. В отчёте DDL приведён в диалекте SQL Server,
-- здесь он переписан под PostgreSQL; логика ключей и ссылочных действий
-- сохранена без изменений.
--
-- Скрипт идемпотентный: выполняется целиком (Ctrl+Alt+Shift+Enter) сколько
-- угодно раз и каждый раз даёт одно и то же состояние базы.
--
-- CHECK-ограничений здесь намеренно нет. В отчёте, в разделе "Замечания по
-- проектированию", их отсутствие перечислено как недостаток ЗАДАННОЙ схемы
-- (отрицательная зарплата, курс с нулём кредитов, произвольный Grade).
-- Схема воспроизведена такой, какой она задана, вместе с этими недостатками.
-- ============================================================================

-- Порядок удаления обратен порядку создания: сначала дочерние таблицы.
DROP TABLE IF EXISTS Enrollment CASCADE;
DROP TABLE IF EXISTS Course     CASCADE;
DROP TABLE IF EXISTS Student    CASCADE;
DROP TABLE IF EXISTS Professor  CASCADE;
DROP TABLE IF EXISTS Department CASCADE;


-- ----------------------------------------------------------------------------
-- 1. Department. Создаётся первой и БЕЗ внешнего ключа на Professor.
--    Professor.DeptCode ссылается на Department, а Department.ChairID -- обратно
--    на Professor: ссылочный цикл из двух узлов. Он разрывается тем, что
--    ChairID объявлен NULL, а сам внешний ключ навешивается после Professor.
-- ----------------------------------------------------------------------------
CREATE TABLE Department (
    DeptCode  CHAR(4)       NOT NULL,
    DeptName  VARCHAR(100)  NOT NULL,
    Budget    DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    ChairID   INT           NULL,          -- именно NULL разрывает цикл
    CONSTRAINT PK_Department       PRIMARY KEY (DeptCode),
    CONSTRAINT UQ_Department_Name  UNIQUE (DeptName),
    CONSTRAINT UQ_Department_Chair UNIQUE (ChairID)   -- делает FK4 связью 1:1
);


-- ----------------------------------------------------------------------------
-- 2. Professor. FK2 -> Department.
--    DeptCode -- естественный ключ, его перекодируют при реорганизации
--    факультета, поэтому ON UPDATE CASCADE. Кафедру нельзя удалить, пока на
--    ней числятся преподаватели, поэтому ON DELETE RESTRICT.
-- ----------------------------------------------------------------------------
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


-- ----------------------------------------------------------------------------
-- 3. FK4: цикл замыкается здесь, когда обе таблицы уже существуют.
--    ProfID -- суррогатный ключ, он не меняется никогда, поэтому ON UPDATE
--    NO ACTION. Уходящий заведующий не должен забирать с собой кафедру,
--    поэтому ON DELETE SET NULL -- что возможно только благодаря NULL в ChairID.
-- ----------------------------------------------------------------------------
ALTER TABLE Department
    ADD CONSTRAINT FK4_Department_Chair FOREIGN KEY (ChairID)
        REFERENCES Professor (ProfID)
        ON DELETE SET NULL ON UPDATE NO ACTION;


-- ----------------------------------------------------------------------------
-- 4. Student. FK1 -> Professor.
--    У Major внешнего ключа нет: в заданной схеме это свободный текст, из-за
--    чего 'CSCI' и 'CS' одинаково допустимы. FK7 из отчёта -- рекомендация,
--    в заданную схему он не входит и здесь не создаётся.
-- ----------------------------------------------------------------------------
CREATE TABLE Student (
    StudentID INT           NOT NULL,
    Name      VARCHAR(100)  NOT NULL,
    Email     VARCHAR(255)  NOT NULL,
    Major     CHAR(4)       NULL,
    AdvisorID INT           NULL,
    CONSTRAINT PK_Student       PRIMARY KEY (StudentID),
    CONSTRAINT UQ_Student_Email UNIQUE (Email),   -- второй потенциальный ключ
    CONSTRAINT FK1_Student_Advisor FOREIGN KEY (AdvisorID)
        REFERENCES Professor (ProfID)
        ON DELETE SET NULL ON UPDATE NO ACTION
);


-- ----------------------------------------------------------------------------
-- 5. Course. FK3 -> Department, ссылочные действия те же, что у FK2.
-- ----------------------------------------------------------------------------
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


-- ----------------------------------------------------------------------------
-- 6. Enrollment -- таблица-связка, реализующая M:N между Student и Course.
--    Первичный ключ (StudentID, CourseID, Semester). Semester обязан входить
--    в ключ: без него студент не смог бы пройти тот же курс повторно.
--    Grade в ключ не входит -- он функционально определяется тремя остальными,
--    поэтому (StudentID, CourseID, Semester, Grade) -- суперключ, но не
--    потенциальный ключ: он не минимален.
--
--    Асимметрия FK5 и FK6 сделана намеренно. Запись на курс без студента
--    лишена смысла, поэтому CASCADE. Запись с выставленной оценкой должна
--    пережить исключение курса из каталога, поэтому RESTRICT.
--
--    FK8 из отчёта (Semester -> справочник семестров) -- тоже рекомендация:
--    в заданной схеме таблицы Semester нет, поэтому здесь его нет.
-- ----------------------------------------------------------------------------
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


COMMENT ON TABLE Department IS 'Кафедра. ChairID допускает NULL -- это разрывает ссылочный цикл с Professor';
COMMENT ON TABLE Professor  IS 'Преподаватель. DeptCode NOT NULL -- участие со стороны Professor полное';
COMMENT ON TABLE Student    IS 'Студент. AdvisorID и Major допускают NULL -- участие частичное';
COMMENT ON TABLE Course     IS 'Курс каталога';
COMMENT ON TABLE Enrollment IS 'Таблица-связка M:N. Первичный ключ (StudentID, CourseID, Semester)';


-- ============================================================================
-- Данные. Порядок вставки продиктован циклом Professor <-> Department:
-- кафедры с NULL вместо заведующего -> преподаватели -> UPDATE заведующих ->
-- студенты -> курсы -> записи на курсы. В другом порядке заполнить нельзя.
-- ============================================================================

-- Шаг 1: кафедры без заведующих. Преподавателей ещё не существует.
INSERT INTO Department (DeptCode, DeptName, Budget, ChairID) VALUES
    ('CSCI', 'Computer Science', 1250000.00, NULL),
    ('MATH', 'Mathematics',       890000.00, NULL),
    ('PHYS', 'Physics',          1100000.00, NULL);

-- Шаг 2: преподаватели. Теперь кафедры для FK2 уже есть.
INSERT INTO Professor (ProfID, Name, DeptCode, Salary) VALUES
    (101, 'Aigerim Nurlanova', 'CSCI', 780000.00),
    (102, 'Daniyar Seitkali',  'CSCI', 640000.00),
    (103, 'Marat Iskakov',     'MATH', 710000.00),
    (104, 'Elena Voronova',    'PHYS', 695000.00);

-- Шаг 3: цикл замыкается. UNIQUE(ChairID) не даст назначить одного
-- преподавателя заведующим сразу двух кафедр.
UPDATE Department SET ChairID = 101 WHERE DeptCode = 'CSCI';
UPDATE Department SET ChairID = 103 WHERE DeptCode = 'MATH';
UPDATE Department SET ChairID = 104 WHERE DeptCode = 'PHYS';

-- Шаг 4: студенты. У 1004 Major и AdvisorID равны NULL: специальность ещё
-- не выбрана, куратор не назначен. Оба столбца это допускают.
INSERT INTO Student (StudentID, Name, Email, Major, AdvisorID) VALUES
    (1001, 'Erdaulet Aitzhanov', 'e.aitzhanov@kbtu.kz', 'CSCI', 101),
    (1002, 'Aruzhan Bekova',     'a.bekova@kbtu.kz',    'CSCI', 102),
    (1003, 'Timur Zhaksylyk',    't.zhaksylyk@kbtu.kz', 'MATH', 103),
    (1004, 'Dana Omarova',       'd.omarova@kbtu.kz',   NULL,   NULL);

-- Шаг 5: курсы.
INSERT INTO Course (CourseID, Title, Credits, DepartmentCode) VALUES
    ('CSCI1510', 'Introduction to Databases', 3, 'CSCI'),
    ('CSCI2620', 'Data Structures',           4, 'CSCI'),
    ('MATH1410', 'Discrete Mathematics',      3, 'MATH'),
    ('PHYS2100', 'Classical Mechanics',       4, 'PHYS');

-- Шаг 6: записи на курсы.
-- Первые две строки -- то самое повторное прохождение: студент 1001 завалил
-- CSCI1510 осенью 2024 и прошёл его заново весной 2025. Ключ из двух
-- атрибутов (StudentID, CourseID) такую пару строк запретил бы.
-- У 1003 в MATH1410 оценка NULL: курс ещё идёт.
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
