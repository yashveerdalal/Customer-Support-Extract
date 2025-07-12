DROP DATABASE IF EXISTS CustomerSupport;
CREATE DATABASE CustomerSupport;
USE CustomerSupport;

SET GLOBAL local_infile = 1;

CREATE TABLE IF NOT EXISTS TicketsSource (
    TicketID INT,
    CustomerName TEXT,
    CustomerEmail TEXT,
    CustomerAge INT,
    CustomerGender TEXT,
    ProductPurchased TEXT,
    DateOfPurchase TEXT,
    TicketType TEXT,
    TicketSubject TEXT,
    TicketDescription TEXT,
    TicketStatus TEXT,
    Resolution TEXT,
    TicketPriority TEXT,
    TicketChannel TEXT,
    FirstResponseTime TEXT,
    TimeToResolution TEXT,
    CustomerSatisfactionRating FLOAT
);

LOAD DATA LOCAL INFILE '/Users/yashdalal/Desktop/customer_support_tickets.csv'
INTO TABLE TicketsSource
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

DROP TABLE IF EXISTS StageA;
CREATE TABLE StageA AS
SELECT
  TRIM(TicketID)            AS TicketID,
  TRIM(CustomerName)        AS CustomerName,
  TRIM(CustomerEmail)       AS CustomerEmail,
  TRIM(CustomerAge)         AS CustomerAge,
  TRIM(CustomerGender)      AS CustomerGender,
  TRIM(ProductPurchased)    AS ProductPurchased,
  TRIM(DateOfPurchase)      AS DateOfPurchase,
  TRIM(TicketType)          AS TicketType,
  TRIM(TicketSubject)       AS TicketSubject,
  TRIM(TicketDescription)   AS TicketDescription,
  TRIM(TicketStatus)        AS TicketStatus,
  TRIM(Resolution)          AS Resolution,
  TRIM(TicketPriority)      AS TicketPriority,
  TRIM(TicketChannel)       AS TicketChannel,
  TRIM(FirstResponseTime)   AS FirstResponseTime,
  TRIM(TimeToResolution)    AS TimeToResolution,
  CAST(TRIM(CustomerSatisfactionRating) AS DECIMAL(5,2)) AS CustomerSatisfactionRating
FROM TicketsSource;

DROP TABLE IF EXISTS StageB;
CREATE TABLE StageB AS SELECT * FROM StageA;

/* 1. blank names → Unknown */
UPDATE StageB
SET CustomerName = 'Unknown'
WHERE CustomerName IS NULL OR CustomerName = '';

/* 2. ages outside 10‑100 → NULL */
UPDATE StageB
SET CustomerAge = NULL
WHERE CustomerAge < 10 OR CustomerAge > 100;

/* 3. delete bad e‑mails */
DELETE FROM StageB
WHERE CustomerEmail NOT REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$';

/* 4. gender standardise */
UPDATE StageB
SET CustomerGender = 'other'
WHERE CustomerGender IS NULL
   OR TRIM(CustomerGender) = ''
   OR LOWER(TRIM(CustomerGender)) NOT IN ('male','female');

/* 5. remove duplicates on (CustomerName, ProductPurchased) */
WITH dupes AS (
  SELECT
    TicketID,
    ROW_NUMBER() OVER (
      PARTITION BY CustomerName, ProductPurchased
      ORDER BY TicketID
    ) AS rn
  FROM StageB
)
DELETE s
FROM StageB AS s
JOIN dupes AS d ON s.TicketID = d.TicketID
WHERE d.rn > 1;

/* final sanity counts */
SELECT
  COUNT(*)                         AS total_rows,
  SUM(CustomerAge IS NULL)         AS null_age_rows,
  SUM(CustomerName = 'Unknown')    AS unknown_names,
  SUM(CustomerGender = 'other')    AS other_gender_rows
FROM StageB;
