-- SQL Script to Set Up Database Schema with Primary Keys and Foreign Keys
-- and to Perform Various Data Transformations and Queries

-- HEADER: Primary Key Setup
-- Setting primary keys for dimension tables

ALTER TABLE dim_brand_generic
ADD PRIMARY KEY (drug_brand_generic_code);

ALTER TABLE dim_drug_form_code
MODIFY COLUMN drug_form_code VARCHAR(100) NOT NULL UNIQUE,
ADD PRIMARY KEY (drug_form_code);

ALTER TABLE dim_drug_ndc
ADD PRIMARY KEY (drug_ndc);

ALTER TABLE dim_member
ADD PRIMARY KEY (member_id);

-- HEADER: Fact Drug Table Modifications
-- Adding surrogate primary key and modifying columns

ALTER TABLE fact_drug
ADD COLUMN id INT AUTO_INCREMENT PRIMARY KEY;

ALTER TABLE fact_drug
MODIFY COLUMN drug_form_code VARCHAR(100);

-- HEADER: Foreign Key Setup
-- Establishing foreign key constraints for the fact_drug table

ALTER TABLE fact_drug
ADD FOREIGN KEY fact_drug_member_id_fk (member_id)
REFERENCES dim_member (member_id)
ON DELETE SET NULL
ON UPDATE SET NULL;

ALTER TABLE fact_drug
ADD FOREIGN KEY fact_drug_drug_ndc_fk (drug_ndc)
REFERENCES dim_drug_ndc (drug_ndc)
ON DELETE SET NULL
ON UPDATE SET NULL;

ALTER TABLE fact_drug
ADD FOREIGN KEY fact_drug_brand_generic_code_fk (drug_brand_generic_code)
REFERENCES dim_brand_generic (drug_brand_generic_code)
ON DELETE SET NULL
ON UPDATE SET NULL;

ALTER TABLE fact_drug
ADD FOREIGN KEY fact_drug_drug_form_code_fk (drug_form_code)
REFERENCES dim_drug_form_code (drug_form_code)
ON DELETE SET NULL
ON UPDATE SET NULL;

-- HEADER: Data Type Conversion
-- Updating string date columns to MySQL DATE type

-- Update the fill_date in fact_drug to MySQL's date format and alter the column type
UPDATE fact_drug
SET fill_date = STR_TO_DATE(fill_date, '%m/%d/%Y')
WHERE fill_date IS NOT NULL AND fill_date != '';

ALTER TABLE fact_drug
MODIFY COLUMN fill_date DATE;

-- Update the member_birth_date in dim_member to MySQL's date format and alter the column type
UPDATE dim_member
SET member_birth_date = STR_TO_DATE(member_birth_date, '%m/%d/%Y')
WHERE member_birth_date IS NOT NULL AND member_birth_date != '';

ALTER TABLE dim_member
MODIFY COLUMN member_birth_date DATE;

-- HEADER: Data Analysis Queries
-- Performing data analysis through various queries

-- Query to count prescriptions grouped by drug name
SELECT d.drug_name, COUNT(f.id) AS prescription_count
FROM fact_drug f
INNER JOIN dim_drug_ndc d ON f.drug_ndc = d.drug_ndc
GROUP BY d.drug_name
ORDER BY prescription_count DESC;

-- Query to categorize members by age and perform aggregate calculations
SELECT
  CASE
    WHEN m.member_age >= 65 THEN '65+'
    ELSE '< 65'
  END AS age_group,
  COUNT(f.id) AS total_prescriptions,
  COUNT(DISTINCT f.member_id) AS unique_members,
  SUM(f.copay) AS total_copay,
  SUM(f.insurancepaid) AS total_insurancepaid
FROM fact_drug f
INNER JOIN dim_member m ON f.member_id = m.member_id
GROUP BY age_group
ORDER BY age_group;

-- Query to find the most recent prescription fill date and insurance paid amount for each member
SELECT 
    member_id, 
    member_first_name, 
    member_last_name, 
    drug_name, 
    fill_date AS most_recent_fill_date, 
    insurancepaid AS most_recent_insurance_paid
FROM (
    SELECT 
        m.member_id, 
        m.member_first_name, 
        m.member_last_name, 
        d.drug_name, 
        f.fill_date, 
        f.insurancepaid,
        ROW_NUMBER() OVER (PARTITION BY f.member_id ORDER BY f.fill_date DESC) AS rn
    FROM 
        fact_drug f
    INNER JOIN dim_member m ON f.member_id = m.member_id
    INNER JOIN dim_drug_ndc d ON f.drug_ndc = d.drug_ndc
) AS subquery
WHERE 
    rn = 1
ORDER BY 
    most_recent_fill_date DESC, 
    member_id;
