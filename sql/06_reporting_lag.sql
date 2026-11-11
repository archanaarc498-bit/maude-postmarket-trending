-- Q6: Per month, how many days pass between the event and FDA receiving the report (median is computed in R)?
SELECT month, date_of_event, date_received
FROM maude_reports
WHERE date_of_event IS NOT NULL AND date_received IS NOT NULL;
