-- Q5: Which device problem codes are reported most often?
SELECT problem_code, COUNT(DISTINCT mdr_report_key) AS reports
FROM maude_problems
GROUP BY problem_code
ORDER BY reports DESC
LIMIT 15;
