-- Q2: Which manufacturers have the most reports for this product code?
SELECT manufacturer, COUNT(DISTINCT mdr_report_key) AS reports
FROM maude_reports
GROUP BY manufacturer
ORDER BY reports DESC
LIMIT 10;
