-- 3.2

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
 AS SELECT Org_id, Abbreviation, Name, Zip_Code, Street, City, 'Research_Facility' AS Organisation_Type FROM Organisation NATURAL JOIN Res_facility
    UNION
    SELECT Org_id, Abbreviation, Name, Zip_code, Street, City, 'University' AS Organisation_Type FROM Organisation NATURAL JOIN University
    UNION
    SELECT Org_id, Abbreviation, Name, Zip_code, Street, City, 'Company' AS Organisation_Type FROM Organisation NATURAL JOIN Company
    ORDER BY Org_id ASC;


-- 3.3
SELECT P.Project_id,Title
FROM
  (SELECT Project_id,Title FROM Project
  WHERE DATEDIFF(CURDATE(), Start_date) >= 0 AND DATEDIFF(CURDATE(), Finish_date) <= 0) AS P
  JOIN (SELECT Project_id FROM Project_in_Field WHERE Field_name = "variable") AS F
  ON P.Project_id = F.Project_id;


SELECT First_name, Last_name
FROM
    (SELECT Project_id, First_name, Last_name
    FROM
      (SELECT Project_id, First_name, Last_name
      FROM Researcher NATURAL JOIN Participates) AS PARP
      NATURAL JOIN
      (SELECT Project_id FROM Project
      WHERE DATEDIFF(CURDATE(), Start_date) >=365 AND DATEDIFF(CURDATE(), Finish_date) < 0) AS RPY) AS RES
    NATURAL JOIN Project_in_Field F
  WHERE Field_name = "variable";


-- 3.4
SELECT OrgProj1.Org_id AS Org_id, OrgProj2.Year as Year_1, OrgProj1.Year as Year_2, OrgProj1.Projects_in_year AS Projects_in_year FROM
    (SELECT Org_id, YEAR(Start_date) as Year, count(Project_id)  AS Projects_in_year FROM
    Organisation NATURAL JOIN Project
    GROUP BY Org_id, YEAR(Start_date)
    HAVING count(Project_id) >= 10) AS OrgProj1
    JOIN
    (SELECT Org_id, YEAR(Start_date) as Year, count(Project_id) AS Projects_in_year FROM
    Organisation NATURAL JOIN Project
    GROUP BY Org_id, YEAR(Start_date)
    HAVING count(Project_id) >= 10) AS OrgProj2
    ON OrgProj1.Org_id = OrgProj2.Org_id AND OrgProj1.Year = OrgProj2.Year + 1 AND OrgProj1.Projects_in_year = OrgProj2.Projects_in_year;


-- 3.5
SELECT PF1.Field_name AS Field_name_1, PF2.Field_name AS Field_name_2, count(PF1.Project_id) AS Projects_per_field_pair FROM
Project_in_Field as PF1 INNER JOIN Project_in_Field as PF2 on PF1.Project_id = PF2.Project_id AND PF1.Field_name < PF2.Field_name
GROUP BY PF1.Field_name, PF2.Field_name
ORDER BY Projects_per_field_pair DESC
LIMIT 3;


-- 3.6
SELECT First_name,Last_name,count(Project_id) AS Count_Projects
FROM
  (SELECT * FROM
	  (SELECT Researcher_id,First_name,Last_name FROM Researcher
	   WHERE DATEDIFF(CURDATE(), Birthdate) < 40*365) AS R
	   NATURAL JOIN Participates PART) AS RES
   NATURAL JOIN
   (SELECT Project_id FROM Project
   WHERE DATEDIFF(CURDATE(), Start_date) >= 0 AND DATEDIFF(CURDATE(), Finish_date) <= 0) AS P
GROUP BY Researcher_id
ORDER BY count(Project_id) DESC;


-- 3.7
SELECT EX.Name AS Executive_name, Pr.Name AS Organisation_name, sum(Funding_amount) AS Total_amount
FROM Executive EX JOIN
    (SELECT P.Org_id,Name,Funding_amount,Executive_id
     FROM Project P JOIN
          (SELECT Org_id,Name FROM Company NATURAL JOIN Organisation) AS CP
                                             ON P.Org_id = CP.Org_id) AS PR
	 ON EX.Executive_id = PR.Executive_id
GROUP BY EX.Executive_id, PR.Org_id
ORDER BY sum(Funding_amount) DESC
LIMIT 5;


-- 3.8
SELECT First_name, Last_name, Number_of_Projects
FROM
  Researcher R
  JOIN
  (SELECT Researcher_id, count(PR.Project_id) AS Number_of_Projects
  FROM
    ((SELECT Project_id FROM Project)
    EXCEPT
    (SELECT P.Project_id
    FROM Project P JOIN Deliverable D ON P.Project_id = D.Project_id)) AS PR
    JOIN
    Participates PART
    ON PR.Project_id = PART.Project_id
  GROUP BY Researcher_id
  HAVING count(PR.Project_id)>=5) AS PWD
  ON R.Researcher_id = PWD.Researcher_id
ORDER BY Number_of_Projects DESC;
