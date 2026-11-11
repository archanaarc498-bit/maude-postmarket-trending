-- Q1: How many reports per month, split by event type (death, injury, malfunction, other)?
SELECT month, event_type, COUNT(DISTINCT mdr_report_key) AS reports
FROM maude_reports
GROUP BY month, event_type
ORDER BY month, event_type;
