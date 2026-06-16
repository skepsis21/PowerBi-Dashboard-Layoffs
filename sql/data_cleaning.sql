-- DATA CLEANING

-- 1. Remove Duplicates
-- 2. Standardize the Data and Fix Errors
-- 3. Null Values or Blank Values
-- 4. Remove Any Columns

SELECT * FROM layoffs;

-------------------------------------------------------
-- 1. Remove Duplicates
-------------------------------------------------------

DROP TABLE IF EXISTS layoffs_staging;

CREATE TABLE layoffs_staging LIKE layoffs;

ALTER TABLE layoffs_staging ADD COLUMN row_num INT;

INSERT INTO layoffs_staging
SELECT *,
ROW_NUMBER() OVER(
    PARTITION BY company, location, industry, total_laid_off, `date`, stage, country, funds_raised_millions
) AS row_num
FROM layoffs;

-------------------------------------------------------
-- 🔥 SAFE MODE FIX (IMPORTANT — BEFORE DELETE)
-------------------------------------------------------

SET SQL_SAFE_UPDATES = 0;

-------------------------------------------------------
-- Remove duplicates
-------------------------------------------------------

DELETE FROM layoffs_staging
WHERE row_num > 1;

-------------------------------------------------------
-- 2. Standardize DATA
-------------------------------------------------------

UPDATE layoffs_staging
SET 
    company  = TRIM(company),
    location = TRIM(location),
    industry = TRIM(industry),
    country  = TRIM(country),
    stage    = TRIM(stage);

UPDATE layoffs_staging
SET industry = 'Crypto'
WHERE industry LIKE 'Crypto%';

UPDATE layoffs_staging
SET industry = NULL
WHERE industry = '';

-------------------------------------------------------
-- Date fix
-------------------------------------------------------

UPDATE layoffs_staging
SET `date` = STR_TO_DATE(`date`, '%m/%d/%Y');

ALTER TABLE layoffs_staging
MODIFY COLUMN `date` DATE;

-------------------------------------------------------
-- Numeric cleaning
-------------------------------------------------------

UPDATE layoffs_staging
SET total_laid_off = NULL
WHERE total_laid_off = 0;

ALTER TABLE layoffs_staging
MODIFY COLUMN total_laid_off INT;

-------------------------------------------------------
-- 🔥 FIX: percentage_laid_off CLEANING BEFORE TYPE CHANGE
-------------------------------------------------------

UPDATE layoffs_staging
SET percentage_laid_off = NULL
WHERE percentage_laid_off = ''
   OR percentage_laid_off IS NULL
   OR percentage_laid_off NOT REGEXP '^-?[0-9]+(\\.[0-9]+)?$';

ALTER TABLE layoffs_staging
MODIFY COLUMN percentage_laid_off DECIMAL(6,2);

-------------------------------------------------------
-- Country cleanup
-------------------------------------------------------

UPDATE layoffs_staging
SET country = TRIM(TRAILING '.' FROM country)
WHERE country LIKE 'United States%';

-------------------------------------------------------
-- Fill missing industry
-------------------------------------------------------

UPDATE layoffs_staging t1
JOIN layoffs_staging t2
    ON t1.company = t2.company
SET t1.industry = t2.industry
WHERE t1.industry IS NULL
  AND t2.industry IS NOT NULL;

-------------------------------------------------------
-- Remove fully empty rows
-------------------------------------------------------

DELETE FROM layoffs_staging
WHERE total_laid_off IS NULL
  AND percentage_laid_off IS NULL;

-------------------------------------------------------
-- Turn safe mode back on (good practice)
-------------------------------------------------------

SET SQL_SAFE_UPDATES = 1;

-------------------------------------------------------
-- Final cleanup
-------------------------------------------------------

ALTER TABLE layoffs_staging
DROP COLUMN row_num;

SELECT * FROM layoffs_staging;

