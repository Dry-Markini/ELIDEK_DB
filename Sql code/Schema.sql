SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0;
SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;
SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='TRADITIONAL';

DROP SCHEMA IF EXISTS ELIDEK;
CREATE SCHEMA ELIDEK;
USE ELIDEK;


CREATE TABLE Project (
  Project_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  Title VARCHAR(45) NOT NULL,
  Summary VARCHAR(500),
  Funding_amount DECIMAL(9,2) NOT NULL
    CHECK(Funding_amount>=100000 AND Funding_amount<=1000000),
  Start_date DATE NOT NULL,
  Finish_date DATE NOT NULL,
  Duration INT AS (DATEDIFF(Finish_date,Start_date)/365),
  Program_id INT UNSIGNED NOT NULL,
  Executive_id INT UNSIGNED NOT NULL,
  Org_id INT UNSIGNED NOT NULL,
  Researcher_id_sup INT UNSIGNED NOT NULL,
  Researcher_id_eval INT UNSIGNED NOT NULL,
  Eval_date DATE NOT NULL CHECK (Eval_date < Start_date),
  Eval_grade DECIMAL(3,1) NOT NULL CHECK(Eval_grade >= 0.0 AND Eval_grade <= 10.0),
  PRIMARY KEY  (Project_id),
  FOREIGN KEY  (Program_id) REFERENCES Program (Program_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  FOREIGN KEY  (Executive_id) REFERENCES Executive(Executive_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  FOREIGN KEY  (Org_id) REFERENCES Organisation(Org_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  FOREIGN KEY  (Researcher_id_sup) REFERENCES Researcher(Researcher_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  FOREIGN KEY  (Researcher_id_eval) REFERENCES Researcher(Researcher_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CHECK(DATEDIFF(Finish_date, Start_date) >= 365 AND
        DATEDIFF(Finish_date, Start_date) <= 4*365)
);

CREATE TABLE Deliverable (
  Project_id INT UNSIGNED NOT NULL,
  Title VARCHAR(45) NOT NULL,
  Summary VARCHAR(500),
  Due_date DATE NOT NULL,
  PRIMARY KEY(Project_id,Title),
  FOREIGN KEY(Project_id) REFERENCES Project(Project_id)
    ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Program (
  Program_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  Name VARCHAR(45) NOT NULL,
  Administration VARCHAR(45) NOT NULL,
  PRIMARY KEY (Program_id)
);

CREATE TABLE Executive (
  Executive_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  Name VARCHAR(45) NOT NULL,
  PRIMARY KEY (Executive_id)
);

CREATE TABLE Fields (
  Field_name VARCHAR(45) NOT NULL,
  PRIMARY KEY (Field_name)
);

CREATE TABLE Project_in_Field (
  Project_id INT UNSIGNED NOT NULL,
  Field_name VARCHAR(45) NOT NULL,
  PRIMARY KEY (Project_id, Field_name),
  FOREIGN KEY (Project_id) REFERENCES Project(Project_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (Field_name) REFERENCES Fields(Field_name)
    ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Organisation (
  Org_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  Abbreviation VARCHAR(45) NOT NULL,
  Name VARCHAR(45) NOT NULL,
  Zip_code CHAR(5) NOT NULL,
  Street VARCHAR(45) NOT NULL,
  City VARCHAR(45) NOT NULL,
  PRIMARY KEY (Org_id)
);

CREATE TABLE Res_facility (
  Org_id INT UNSIGNED NOT NULL,
  Min_budget DECIMAL(14,2) NOT NULL,
  Priv_budget DECIMAL(14,2) NOT NULL,
  PRIMARY KEY (Org_id),
  FOREIGN KEY (Org_id) REFERENCES Organisation (Org_id)
    ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE University (
  Org_id INT UNSIGNED NOT NULL,
  Min_budget DECIMAL(14,2) NOT NULL,
  PRIMARY KEY (Org_id),
  FOREIGN KEY (Org_id) REFERENCES Organisation (Org_id)
      ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Company (
  Org_id INT UNSIGNED NOT NULL,
  Equity DECIMAL(14,2) NOT NULL,
  PRIMARY KEY (Org_id),
  FOREIGN KEY (Org_id) REFERENCES Organisation (Org_id)
        ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Phone_inst (
  Number VARCHAR(15) NOT NULL,
  Org_id INT UNSIGNED NOT NULL,
  PRIMARY KEY (Number),
  FOREIGN KEY (Org_id) REFERENCES Organisation (Org_id)
        ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Researcher (
  Researcher_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  First_name VARCHAR(45) NOT NULL,
  Last_name VARCHAR(45) NOT NULL,
  Sex CHAR(6),
  Birthdate DATE NOT NULL,
  Org_id INT UNSIGNED NOT NULL,
  Start_date DATE NOT NULL CHECK(Start_date > Birthdate),
  PRIMARY KEY  (Researcher_id),
  FOREIGN KEY (Org_id) REFERENCES Organisation(Org_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE Participates (
  Project_id INT UNSIGNED NOT NULL,
  Researcher_id INT UNSIGNED NOT NULL,
  PRIMARY KEY (Project_id, Researcher_id),
  FOREIGN KEY (Project_id) REFERENCES Project(Project_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (Researcher_id) REFERENCES Researcher(Researcher_id)
    ON DELETE CASCADE ON UPDATE CASCADE
);

-- INDEXES

create index p_startdate_index on project(Start_Date);
create index p_finishdate_index on project(Finish_Date);
create index r_birthdate_index on researcher(Birthdate);


--
-- VIEWS (3.2)
--

CREATE VIEW Projects_per_Researcher
  AS SELECT PPART.Researcher_id, PPART.First_name, PPART.Last_name, P.Org_id, P.Project_id, P.Title FROM
    ((SELECT * FROM Researcher R NATURAL JOIN Participates Part) AS PPart
    JOIN Project P ON P.Project_id = PPart.Project_id);


CREATE VIEW Projects_per_Researcher_count
  AS SELECT Researcher_id, First_name, Last_name, count(Project_id) AS Number_of_Projects FROM
     (SELECT * FROM Researcher NATURAL JOIN Participates) AS RP
     GROUP BY Researcher_id
     ORDER BY count(Project_id) DESC;


CREATE VIEW Organisation_type
 AS SELECT Org_id, Abbreviation, Name, Zip_Code, Street, City, 'Research_Facility' AS Organisation_Type, Min_budget, Priv_budget, NULL as Equity FROM Organisation NATURAL JOIN Res_facility
    UNION
    SELECT Org_id, Abbreviation, Name, Zip_code, Street, City, 'University' AS Organisation_Type, Min_budget, NULL as Priv_budget, NULL as Equity  FROM Organisation NATURAL JOIN University
    UNION
    SELECT Org_id, Abbreviation, Name, Zip_code, Street, City, 'Company' AS Organisation_Type, NULL as Min_budget, NULL as Priv_budget, Equity  FROM Organisation NATURAL JOIN Company
    ORDER BY Org_id ASC;



--  !!!!!!!!!!!!!!!!!!!!
--  TRIGGERS FOR Project
--  !!!!!!!!!!!!!!!!!!!!

delimiter //
CREATE TRIGGER Project_trig_insert
AFTER INSERT ON Project
FOR EACH ROW
BEGIN
  -- Eval_date cannot be a future date
  IF new.Eval_date > CURDATE() THEN
	DELETE FROM Project WHERE Project_id = new.Project_id;
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Eval_date cannot be a future date';
  END IF;

  -- A reseacher who evaluates a project must not work for
  -- the organisation that manages the project
  IF exists (select * from Researcher R WHERE new.Researcher_id_eval = R.Researcher_id AND new.Org_id = R.Org_id)
  THEN
	DELETE FROM Project WHERE Project_id = new.Project_id;
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='A reseacher who evaluates a project must not work for the organisation that manages the project';
  END IF;

  -- Project supervisor must be in "participates"
  INSERT INTO Participates values (new.Project_id,new.Researcher_id_sup);
END;
//
delimiter ;

delimiter //
CREATE TRIGGER Project_trig_update
BEFORE UPDATE ON Project
FOR EACH ROW
BEGIN
  -- Eval_date cannot be a future date
  IF new.Eval_date > CURDATE() THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Eval_date cannot be a future date';
  END IF;

  -- Project supervisor must be in "participates"
  IF NOT EXISTS(SELECT * FROM Participates WHERE Researcher_id = new.Researcher_id_sup)
  THEN INSERT INTO Participates Values(new.Project_id,new.Researcher_id_sup);
  END IF;

  -- A reseacher who evaluates a project must not particiate in the project
  IF EXISTS (SELECT * FROM Participates PART WHERE new.Researcher_id_eval = PART.Researcher_id AND new.Project_id = PART.Project_id)
  THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='A reseacher who evaluates a project must not particiate in the project';
  END IF;

  -- A reseacher who evaluates a project must not work for
  -- the organisation that manages the project
  IF EXISTS (SELECT * FROM Researcher R WHERE new.Researcher_id_eval = R.Researcher_id AND new.Org_id = R.Org_id)
  THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT= 'A reseacher who evaluates a project must not work for the organisation that manages the project';
  END IF;
END;
//
delimiter ;



--  !!!!!!!!!!!!!!!!!!!!!!!!!
--  TRIGGERS FOR Deliverable
--  !!!!!!!!!!!!!!!!!!!!!!!!!

delimiter //
CREATE TRIGGER Deliverable_trig_insert
BEFORE INSERT ON Deliverable
FOR EACH ROW
BEGIN
  -- Duedate of Deliverable must be between Start_date and Finish_date of Project
  IF exists (select * from Project P WHERE new.Project_id = P.Project_id AND (new.Due_date < P.Start_date OR new.Due_date > P.Finish_date))
  THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Duedate of Deliverable must be between Start_date and Finish_date of Project';
  END IF;
END;
//
delimiter ;


delimiter //
CREATE TRIGGER Deliverable_trig_update
BEFORE UPDATE ON Deliverable
FOR EACH ROW
BEGIN
  -- Duedate of Deliverable must be between Start_date and Finish_date of Project
  IF exists (select * from Project P WHERE new.Project_id = P.Project_id AND (new.Due_date < P.Start_date OR new.Due_date > P.Finish_date))
  THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Duedate of Deliverable must be between Start_date and Finish_date of Project';
  END IF;
END;
//
delimiter ;



--  !!!!!!!!!!!!!!!!!!!!!!!!!
--  TRIGGERS FOR Participates
--  !!!!!!!!!!!!!!!!!!!!!!!!!

delimiter //
CREATE TRIGGER Participates_trig_insert
BEFORE INSERT ON Participates
FOR EACH ROW
BEGIN
  -- A reseacher who evaluates a project must not particiate in the project
  IF EXISTS (SELECT * FROM Project P WHERE new.Project_id = P.Project_id AND new.Researcher_id = P.Researcher_id_eval)
  THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='A reseacher who evaluates a project must not particiate in the project';
  END IF;

  -- A researcher can only participate in the projects managed by
  -- the organisation they work for
  IF (SELECT Org_id FROM Project P WHERE new.Project_id = P.Project_id) != (SELECT Org_id FROM Researcher R WHERE new.Researcher_id = R.Researcher_id)
  THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='A researcher can only participate in the projects managed by the organisation they work for';
    END IF;

 -- The start date of researcher must be older than start date of project
  IF (SELECT Start_date FROM Project P WHERE new.Project_id = P.Project_id) < (SELECT Start_date FROM Researcher R WHERE new.Researcher_id = R.Researcher_id)
  THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='The start date of the researcher must be older than start date of project';
  END IF;
END;
//
delimiter ;

delimiter //
CREATE TRIGGER Participates_trig_update
BEFORE UPDATE ON Participates
FOR EACH ROW
BEGIN
  -- A reseacher who evaluates a project must not particiate in the project
  IF EXISTS (SELECT * FROM Project P WHERE new.Project_id = P.Project_id AND new.Researcher_id = P.Researcher_id_eval)
  THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='A reseacher who evaluates a project must not particiate in the project';
  END IF;

  -- A researcher can only participate in the projects managed by
  -- the organisation they work for
  IF (SELECT Org_id FROM Project P WHERE new.Project_id = P.Project_id) != (SELECT Org_id FROM Researcher R WHERE new.Researcher_id = R.Researcher_id)
  THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='A researcher can only participate in the projects managed by the organisation they work for';
    END IF;
END;
//
delimiter ;

delimiter //
CREATE TRIGGER Participates_trig_delete
BEFORE DELETE ON Participates
FOR EACH ROW
BEGIN
  -- A reseacher who supervises a project cannot be deleted from participates
  IF EXISTS (SELECT * FROM Project P WHERE old.Project_id = P.Project_id AND old.Researcher_id = P.Researcher_id_sup)
  THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='A reseacher who supervises a project cannot be deleted from participates';
  END IF;
END;
//
delimiter ;


--  !!!!!!!!!!!!!!!!!!!!!!!
--  TRIGGERS FOR Researcher
--  !!!!!!!!!!!!!!!!!!!!!!!

delimiter //
CREATE TRIGGER Researcher_trig_update
BEFORE UPDATE ON Researcher
FOR EACH ROW
BEGIN
  -- A reseacher who evaluates a project must not work for the organisation that manages the project
  IF new.Org_id IN (SELECT Org_id FROM Project P WHERE new.Researcher_id = P.Researcher_id_eval)
  THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='A reseacher who evaluates a project must not work for the organisation that manages the project';
  END IF;
END;
//
delimiter ;
