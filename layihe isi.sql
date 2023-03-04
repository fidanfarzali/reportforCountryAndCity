CREATE TABLE customer(customer_no NUMBER PRIMARY KEY,
                      customer_type VARCHAR2(2),
                      customer_full_name VARCHAR2(100),
                      address_line1 VARCHAR2(100),
                      address_line3 VARCHAR2(100),
                      address_line2 VARCHAR2(100),
                      address_line4 VARCHAR2(100),
                      country VARCHAR2(100),
                      LANGUAGE VARCHAR2(10),
                      branch_id NUMBER REFERENCES branchh(branch_id),
                      SHEXS_VES_NO VARCHAR2(25),
                      LIMIT NUMBER,
                      limit_ccy NUMBER)
                      
CREATE TABLE branchh(branch_id NUMBER PRIMARY KEY,
                    branch_description VARCHAR2(100))
CREATE TABLE valyutalar(val_id VARCHAR2(10),
                        val_code NUMBER PRIMARY KEY)
CREATE TABLE mezenneler(mezenne_tarixi DATE,
                        val_code NUMBER REFERENCES valyutalar(val_code),
                        mezenne NUMBER) 
SELECT * FROM customer FOR UPDATE;
SELECT * FROM branchh FOR UPDATE;
SELECT * FROM valyutalar FOR UPDATE;
SELECT * FROM mezenneler FOR UPDATE;
   --FORMA 1          
SELECT v.customer_type, NVL(SUM(v.a),0) AS baki_seher_uzre_limit_summa, 
NVL(sum(v.b),0) AS sumqayit_seher_uzre_limit_summa,
NVL(SUM(v.c),0) AS mingecevir_seher_uzre_limit_summa FROM 
(SELECT s.customer_type,
(SELECT s.limit*customer_operationn.curr(s.limit_ccy,to_date('24/feb/2019','dd/mm/yyyy'))
FROM branchh  b WHERE b.branch_id=s.branch_id
 AND  S.BRANCH_ID IN(0,1,3)) AS a,
(SELECT s.limit*customer_operationn.curr(s.limit_ccy,to_date('24/feb/2019','dd/mm/yyyy'))
FROM branchh  b WHERE b.branch_id=s.branch_id 
 AND  S.BRANCH_ID=2) AS b,
(SELECT s.limit*customer_operationn.curr(s.limit_ccy,to_date('24/feb/2019','dd/mm/yyyy')) 
FROM branchh  b WHERE b.branch_id=s.branch_id 
 AND  S.BRANCH_ID=4) AS c
 FROM customer s) v
GROUP BY v.customer_type;--cost 4 24 byte
--forma 2 1- ci usul
SELECT d.customer_type,
NVL(SUM(CASE WHEN d1.branch_id IN(0,1,3) 
THEN (d.limit*customer_operationn.curr(d.limit_ccy,to_date('24/feb/2019','dd/mm/yyyy')))END),0)
AS baki_seher_uzre_limit_summa, 
NVL(SUM(CASE WHEN d1.branch_id=2 
THEN (d.limit*customer_operationn.curr(d.limit_ccy,to_date('24/feb/2019','dd/mm/yyyy')))END),0)
AS sumqayit_seher_uzre_limit_summa,
NVL(SUM(CASE WHEN d1.branch_id=4 
THEN (d.limit*customer_operationn.curr(d.limit_ccy,to_date('24/feb/2019','dd/mm/yyyy')))END),0)
AS mingecevir_seher_uzre_limit_summa
FROM customer d LEFT JOIN branchh d1 ON d.branch_id=d1.branch_id
GROUP BY d.customer_type--cost 4 30 byte
--FORMA 2  2-CI USUL
WITH t AS(
SELECT s.country,s.customer_type,
s.limit*customer_operationn.curr(s.limit_ccy,m.mezenne_tarixi) AS lim
FROM customer s
LEFT JOIN mezenneler m ON m.val_code=s.limit_ccy AND m.mezenne_tarixi=('01.mar.2019'))
SELECT customer_TYPE,
        SUM(CASE WHEN country='AZ' THEN TRUNC(lim/1000) END) AS Azerbaycan,
        SUM(CASE WHEN country='TYR' THEN TRUNC(lim/1000) END) AS Turkiye,
        SUM(CASE WHEN country='RU' THEN TRUNC(lim/1000) END) AS Rusiya,
        SUM(CASE WHEN country=NVL(COUNTRY,'AZ') THEN 1 END) AS azerbaycan_say,
        SUM(CASE WHEN country='TYR' THEN 1 END) AS turkiye_say,
        SUM(CASE WHEN country='RU' THEN 1 END) AS Rusiya_say
FROM t 
GROUP BY customer_type--COST 7 48 BYTE
--formA 2  3-CI USUL
SELECT C1.CUSTOMER_TYPE,
 SUM(CASE WHEN country='AZ' 
THEN (c1.limit*customer_operationn.curr(c1.limit_ccy,to_date('01/mar/2019','dd/mm/yyyy')))/1000 END) AS Azerbaycan,
 SUM(CASE WHEN country='TYR' 
THEN (c1.limit*customer_operationn.curr(c1.limit_ccy,to_date('01/mar/2019','dd/mm/yyyy')))/1000 END) AS Turkiye,
 SUM(CASE WHEN country='RU' 
THEN (c1.limit*customer_operationn.curr(c1.limit_ccy,to_date('01/mar/2019','dd/mm/yyyy')))/1000 END) AS Rusiya,
 SUM(CASE WHEN country=NVL(COUNTRY,'AZ') 
THEN 1 END) AS azerbaycan_say,
 SUM(CASE WHEN country='TYR' 
THEN 1 END) AS turkiye_say,
 SUM(CASE WHEN country='RU' 
THEN 1 END) AS Rusiya_say
FROM CUSTOMER C1
GROUP BY C1.CUSTOMER_TYPE--COST 4 24 BYTE
---INDEX YARATMAQ
PRIMARY KEY CONSTRAINT olduguna gore branchh ve customer TABLEda customer_no ve branch_id columnda
 avtomatik olaraq UNIQUE INDEX yaranib
 create index index_valyuta on valyutalar(val_id)
--package yaratmaq specification
create or replace package customer_operationn
IS
FUNCTION curr(valyuta number,p_DATE DATE)
RETURN NUMBER;
procedure  Update_Customer(customerid number);
procedure  Update_Customer(customer_id number,customer_type varchar2);
end;
---package yaratmaq body
create or replace package  body customer_operationn
IS
--function
FUNCTION curr(valyuta number,p_DATE DATE)
RETURN NUMBER
IS
v_mezenne NUMBER;
BEGIN
  SELECT m.mezenne INTO v_mezenne
  FROM mezenneler m
  WHERE m.val_code=valyuta AND m.mezenne_tarixi=p_date;
  RETURN v_mezenne;
  EXCEPTION WHEN no_data_found THEN
  dbms_output.put_line('no data found');
  WHEN too_many_rows THEN
   dbms_output.put_line(' too many rows');
  WHEN OTHERS THEN
   dbms_output.put_line('Diger');
END;
procedure  Update_Customer(customerid number)
 is
begin
 update customer s set s.address_line2=SUBSTR(s.address_line2,1,5)||'#'
  WHERE s.customer_no=customerid;
 END;
 PROCEDURE Update_Customer(customer_id number,customer_type varchar2)
  IS
  BEGIN
  UPDATE customer s SET s.address_line1=SUBSTR(s.address_line1,1,5)||s.address_line2
  WHERE s.customer_no=customer_id AND s.customer_type=customer_type;
  END;
 END;
    
SELECT * FROM user_errors e WHERE   e.name=UPPER('customer_operationn')
---function run
 SELECT   curr(840,TO_date('01.mar.2019','dd.mm.yyyy')) FROM dual
---procedure-1 run
BEGIN
 customer_operationn.Update_Customer(5664567,'H');
END;
---procedure-2 run
BEGIN
 customer_operationn.Update_Customer(3979212);
END;

SELECT * FROM customer
SELECT LEVEL   FROM DUAL
CONNECT BY LEVEL <= 5;--CONNECT BY LEVEL NE ISE YARAYIR
Select Rownum FROM dual
CONNECT BY Rownum <= 5
--KAPITAL BANK MUSAHIBE SUALI
CREATE TABLE D_SALAR_INFO(EMP_ID NUMBER,
                          EMP_NAME VARCHAR2(55),
                          SALARY NUMBER,
                          MANAGER_ID NUMBER)
SELECT * FROM D_SALAR_INFO FOR UPDATE
--menecer maasindan cox maas alan isci
1--10000--4--5000+
2--15000--5--12000+
3--10000--4---5000+
4--5000--2-15000
5--12000-6--12000
6--12000--2--15000
7--9000--2--15000
8--5000-2--15000
   
CREATE TABLE employeess(emp_id NUMBER,
                        NAME VARCHAR2(25))
CREATE TABLE salary(emp_id NUMBER,salary NUMBER)
SELECT * FROM employeess FOR UPDATE;
SELECT * FROM salary FOR UPDATE;
SELECT *
FROM employeess  S LEFT JOIN SALARY D
ON  S.EMP_ID=D.EMP_ID

--1ci usul
SELECT b.team_1,b.a AS matches_played,NVL(c.b,0) AS no_of_wins,b.a-NVL(c.b,0) AS no_of_losses
FROM
(SELECT T.TEAM_1, COUNT(T.TEAM_1) AS a   FROM 
(SELECT d1.team_1
FROM d_football_games d1
GROUP BY d1.team_1
UNION ALL
SELECT D2.TEAM_2
FROM d_Football_Games D2 
GROUP BY D2.TEAM_2) T
GROUP BY T.TEAM_1) b
LEFT JOIN 
(SELECT  d3.winner,COUNT(d3.winner) AS b
 FROM d_football_games d3
 GROUP BY d3.winner) c 
ON b.team_1=c.winner


SELECT B.*,NVL(A.no_of_wins,0),B.matches_played-NVL(A.no_of_wins,0) AS no_of_losses
FROM
   (SELECT  t.team_1,COUNT(t.say) matches_played FROM
   (SELECT  d5.team_1,COUNT(d5.team_1) AS say FROM d_football_games d5
   GROUP  BY d5.team_1
UNION ALL
SELECT d5.team_2,COUNT(d5.team_1) FROM d_football_games d5
GROUP BY d5.team_2)T
GROUP BY t.team_1)B
LEFT JOIN
(SELECT d5.winner,COUNT(d5.winner) AS no_Of_wins    FROM d_football_games d5
GROUP BY d5.winner)A
ON B.TEAM_1=A.WINNER








