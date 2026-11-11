-- Q4: Each month, how many reports were deaths or injuries out of all reports? (feeds the p-chart)
SELECT month,
       COUNT(DISTINCT mdr_report_key) AS total,
       COUNT(DISTINCT CASE WHEN event_type IN ('D','IN') THEN mdr_report_key END) AS serious
FROM maude_reports
GROUP BY month
ORDER BY month;
