-- Q3: Rolling 12-month report count (needs SQLite 3.25+ for window functions).
WITH monthly AS (
  SELECT month, COUNT(DISTINCT mdr_report_key) AS reports
  FROM maude_reports
  GROUP BY month
)
SELECT month, reports,
       SUM(reports) OVER (ORDER BY month ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) AS rolling_12m
FROM monthly
ORDER BY month;
