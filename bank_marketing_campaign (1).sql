-- =====================================================================
-- BANK MARKETING CAMPAIGN - SQL ANALYSIS (PostgreSQL)
-- Table: bank_marketing_campaign
-- Loaded from bank_marketing_master.csv (output of the Python notebook).
-- subscribed: 1 = subscribed, 0 = did not subscribe.
-- AVG(subscribed) = response rate, because the column is 1/0.
-- data_split: 'train' / 'test'. Model results are checked on 'test' only.
-- =====================================================================


-- 0. CREATE TABLE AND LOAD THE CSV
DROP TABLE IF EXISTS bank_marketing_campaign;

CREATE TABLE bank_marketing_campaign (
    customer_id                    INTEGER PRIMARY KEY,
    age                            INTEGER,
    job                            VARCHAR(20),
    marital                        VARCHAR(10),
    education                      VARCHAR(10),
    "default"                      VARCHAR(3),
    balance                        INTEGER,
    housing                        VARCHAR(3),
    loan                           VARCHAR(3),
    contact                        VARCHAR(10),
    day                            INTEGER,
    month                          VARCHAR(3),
    duration                       INTEGER,
    campaign                       INTEGER,
    pdays                          INTEGER,
    previous                       INTEGER,
    poutcome                       VARCHAR(10),
    y                              VARCHAR(3),
    subscribed                     INTEGER,
    age_group                      VARCHAR(10),
    contact_band                   VARCHAR(15),
    balance_000                    NUMERIC(10,3),
    predicted_response_probability NUMERIC(6,4),
    targeting_segment              VARCHAR(10),
    data_split                     VARCHAR(5)
);

-- Run in psql (change the path to where the file is saved):
-- \copy bank_marketing_campaign FROM 'bank_marketing_master.csv' WITH (FORMAT csv, HEADER true);


-- 1. OVERALL CAMPAIGN PERFORMANCE
-- What is the size and response rate of the campaign?
SELECT
    COUNT(*) AS total_customers,
    SUM(subscribed) AS total_subscribers,
    COUNT(*) - SUM(subscribed) AS non_subscribers,
    ROUND(AVG(subscribed::numeric) * 100, 2) AS response_rate
FROM bank_marketing_campaign;


-- 2. RESPONSE BY PREVIOUS CAMPAIGN OUTCOME
-- Does the result of the previous campaign tell us about the current response?
SELECT
    poutcome,
    COUNT(*) AS total_customers,
    SUM(subscribed) AS total_subscribers,
    ROUND(AVG(subscribed::numeric) * 100, 2) AS response_rate
FROM bank_marketing_campaign
GROUP BY poutcome
ORDER BY response_rate DESC;


-- 3. RESPONSE BY AGE GROUP
-- Which life stage responds best?
-- ORDER BY MIN(age) keeps the groups in age order ('<=30' would otherwise sort last).
SELECT
    age_group,
    COUNT(*) AS total_customers,
    SUM(subscribed) AS total_subscribers,
    ROUND(AVG(subscribed::numeric) * 100, 2) AS response_rate
FROM bank_marketing_campaign
GROUP BY age_group
ORDER BY MIN(age);


-- 4. RESPONSE BY NUMBER OF CALLS
-- How does response change as the bank calls a customer more times?
SELECT
    contact_band,
    COUNT(*) AS total_customers,
    SUM(subscribed) AS total_subscribers,
    ROUND(AVG(subscribed::numeric) * 100, 2) AS response_rate
FROM bank_marketing_campaign
GROUP BY contact_band
ORDER BY MIN(campaign);


-- 5. PREVIOUS RESPONDERS: DOES A HOUSING LOAN MATTER?
-- Among customers who said yes in the previous campaign,
-- do customers without a housing loan respond better?
SELECT
    housing,
    COUNT(*) AS total_customers,
    SUM(subscribed) AS total_subscribers,
    ROUND(AVG(subscribed::numeric) * 100, 2) AS response_rate
FROM bank_marketing_campaign
WHERE poutcome = 'success'
GROUP BY housing
ORDER BY response_rate DESC;


-- 6. JOBS THAT BEAT THE OVERALL RESPONSE RATE (SUBQUERY)
-- Which jobs respond better than the campaign average?
SELECT
    job,
    COUNT(*) AS total_customers,
    SUM(subscribed) AS total_subscribers,
    ROUND(AVG(subscribed::numeric) * 100, 2) AS response_rate
FROM bank_marketing_campaign
GROUP BY job
HAVING AVG(subscribed::numeric) > (
    SELECT AVG(subscribed::numeric)
    FROM bank_marketing_campaign
)
ORDER BY response_rate DESC;


-- 7. TOP JOB + AGE GROUP SEGMENTS (CTE + WINDOW FUNCTION)
-- Step 1 (CTE): response rate for each job + age group.
--               HAVING COUNT(*) >= 100 removes small groups whose rates are unreliable.
-- Step 2: rank the segments from best to worst using RANK().
WITH segment_performance AS (
    SELECT
        job,
        age_group,
        COUNT(*) AS total_customers,
        ROUND(AVG(subscribed::numeric) * 100, 2) AS response_rate
    FROM bank_marketing_campaign
    GROUP BY job, age_group
    HAVING COUNT(*) >= 100
)
SELECT
    job,
    age_group,
    total_customers,
    response_rate,
    RANK() OVER (ORDER BY response_rate DESC) AS response_rank
FROM segment_performance
ORDER BY response_rank
LIMIT 10;


-- 8. MODEL TARGETING SEGMENTS: LIFT ON TEST CUSTOMERS (CTE)
-- Checks the Python model's segments on customers it never saw.
-- Lift = segment response rate / overall test response rate.
WITH test_customers AS (
    SELECT *
    FROM bank_marketing_campaign
    WHERE data_split = 'test'
),
overall AS (
    SELECT AVG(subscribed::numeric) AS overall_rate
    FROM test_customers
)
SELECT
    t.targeting_segment,
    COUNT(*) AS total_customers,
    SUM(t.subscribed) AS total_subscribers,
    ROUND(AVG(t.subscribed::numeric) * 100, 2) AS response_rate,
    ROUND(AVG(t.subscribed::numeric) / MAX(o.overall_rate), 2) AS lift,
    ROUND(COUNT(*)::numeric / SUM(t.subscribed), 2) AS calls_per_subscriber
FROM test_customers t
CROSS JOIN overall o
GROUP BY t.targeting_segment
ORDER BY response_rate DESC;


-- 9. CALL PLAN: CUMULATIVE SUBSCRIBERS REACHED (WINDOW FUNCTION)
-- If the bank calls segments from best to worst, what share of
-- subscribers does it reach at each step? (test customers only)
WITH segment_totals AS (
    SELECT
        targeting_segment,
        COUNT(*) AS total_customers,
        SUM(subscribed) AS total_subscribers,
        AVG(subscribed::numeric) AS response_rate
    FROM bank_marketing_campaign
    WHERE data_split = 'test'
    GROUP BY targeting_segment
)
SELECT
    targeting_segment,
    total_customers,
    total_subscribers,
    SUM(total_customers) OVER (ORDER BY response_rate DESC) AS cumulative_customers,
    SUM(total_subscribers) OVER (ORDER BY response_rate DESC) AS cumulative_subscribers,
    ROUND(SUM(total_subscribers) OVER (ORDER BY response_rate DESC) * 100.0
          / SUM(total_subscribers) OVER (), 2) AS pct_subscribers_reached
FROM segment_totals
ORDER BY response_rate DESC;
