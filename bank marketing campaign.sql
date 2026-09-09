-- 1. OVERALL CAMPAIGN PERFORMANCE
-- What is the overall size and response rate of the campaign?
SELECT 
COUNT(*) AS total_customers,
SUM(subscribed) AS total_subscribers,
COUNT(*)-SUM(subscribed) AS non_subscribers,
ROUND(AVG(subscribed::numeric)*100,2)AS response_rate
FROM bank_marketing_campaign;

-- 2. RESPONSE BY PREVIOUS CAMPAIGN OUTCOME
-- Does previous campaign performance provide information about
--future response?
SELECT
poutcome,
COUNT(*) AS total_customers,
SUM(subscribed) AS total_subscribers,
ROUND(AVG(subscribed::numeric)*100,2)AS response_rate
FROM bank_marketing_campaign
GROUP BY poutcome
ORDER BY response_rate DESC;

-- 3. CAMPAIGN CONTACT FREQUENCY
-- How does response vary with the number of contacts made during 
--the campaign?
SELECT
CASE
WHEN campaign=1 THEN '1 contact'
WHEN campaign BETWEEN 2 AND 3 THEN '2-3 contacts'
WHEN campaign BETWEEN 4 AND 5 THEN '4-5 contacts'
ELSE '6+ contacts'
END AS contact_band,

COUNT(*) AS total_customers,
SUM(subscribed) AS total_subscribers,
ROUND(AVG(subscribed::numeric) * 100, 2) AS response_rate
FROM bank_marketing_campaign

GROUP BY 
CASE
WHEN campaign=1 THEN '1 contact'
WHEN campaign BETWEEN 2 AND 3 THEN '2-3 contacts'
WHEN campaign BETWEEN 4 AND 5 THEN '4-5 contacts'
ELSE '6+ contacts'
END 

ORDER BY response_rate DESC;

-- 4. HIGH-PERFORMING CUSTOMER SEGMENTS
-- Which occupation-age combinations show the highest response rates
-- while still having a meaningful number of customers?
SELECT
job, age_group,
COUNT(*) AS total_customers,
SUM(subscribed) AS total_subscribers,
ROUND(AVG(subscribed::numeric) * 100, 2) AS response_rate
FROM bank_marketing_campaign
GROUP BY job,age_group
HAVING COUNT(*)>=100
ORDER BY response_rate DESC
LIMIT 10;

-- 5. HIGH-POTENTIAL CUSTOMERS WITH PRIOR CAMPAIGN SUCCESS
-- Among customers who responded successfully in the previous campaign,
-- which customer groups currently show the strongest response?
SELECT
job,
age_group,
housing,
COUNT(*) AS total_customers,
SUM(subscribed) AS total_subscribers,
ROUND(AVG(subscribed::numeric) * 100, 2) AS response_rate
FROM bank_marketing_campaign
WHERE poutcome = 'success'
GROUP BY job, age_group, housing
HAVING COUNT(*) >= 20
ORDER BY response_rate DESC;

-- 6. HIGH-RESPONSE CUSTOMER SEGMENTS USING A CTE
-- Identify sufficiently large customer segments that outperform
-- a selected response-rate threshold.
WITH segment_performance AS (
    SELECT
    job,
    age_group,
    COUNT(*) AS total_customers,
    SUM(subscribed) AS total_subscribers,
    ROUND(AVG(subscribed::numeric) * 100, 2) AS response_rate
    FROM bank_marketing_campaign
    GROUP BY job, age_group
    HAVING COUNT(*) >= 100)

SELECT
job,
age_group,
total_customers,
total_subscribers,
response_rate
FROM segment_performance
WHERE response_rate >= 15
ORDER BY response_rate DESC;

-- 7. JOB GROUPS PERFORMING ABOVE THE OVERALL CAMPAIGN RESPONSE RATE
-- Which occupation groups outperform the campaign average?
SELECT
    job,
    COUNT(*) AS total_customers,
    SUM(subscribed) AS total_subscribers,
    ROUND(AVG(subscribed::numeric) * 100, 2) AS response_rate
FROM bank_marketing_campaign
GROUP BY job
HAVING AVG(subscribed::numeric) >
    (SELECT AVG(subscribed::numeric)
     FROM bank_marketing_campaign
	 )
ORDER BY response_rate DESC;

-- 8. RANK CUSTOMER SEGMENTS BY RESPONSE RATE
-- Rank sufficiently large occupation-age segments by campaign performance.
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
ORDER BY response_rank;
