# Post-market trending of coronary balloon catheter reports (FDA MAUDE)

**Status:** initial analysis complete. A Power BI dashboard of these results is planned.

## Question
Do monthly reports for PTCA balloon catheters (FDA product code LOX) show unusual changes in volume, in the share of death/injury reports, or in reporting delay?

## Data
Public FDA MAUDE files (master, device, device problem), January 2021 to October 2026, downloaded from the FDA "MDR Data Files" page. The raw files are not stored in this repository. The latest month (October 2026) is incomplete and was left out of the charts.

## Method
R reads the three files, keeps product code LOX (10,194 reports), and writes a small local SQLite database. Numbered SQL files each answer one question (monthly volume by event type, rolling 12-month count, share of death/injury reports, problem codes, reporting lag). Statistical process control charts (a p' chart for the proportion of death/injury reports and a c chart for monthly counts) flag unusual months.

## Results
- Typical monthly volume is about 110 to 170 reports. Most reports are malfunctions (8,580 of 10,194), then injuries (1,430) and deaths (178).
- Outside two months, about 12% of reports each month are deaths or injuries.
- February 2025 (65% of 248 reports) and May 2025 (73% of 343 reports) fall above the p' chart upper limit.
- Median delay between event and FDA receipt is stable at about 14 to 24 days, but was 228 days in February 2025 and 506 days in May 2025. This suggests those months contain many late-submitted reports about older events. The cause was not investigated here.
- The c chart flags more months than the p' chart because monthly counts vary more than a simple count chart assumes. The p' chart is more reliable for this data.

Charts: `outputs/spc_serious_proportion.png` and `outputs/spc_monthly_counts.png`.

## Spot-check against the FDA web search

For September 2025 (date received 1-30 Sep, product code LOX), this pipeline counts 148 unique reports (3 deaths, 10 injuries, 135 malfunctions). The FDA MAUDE web search returned 145 records for the same filters, a difference of 3 (about 2%). There are no duplicate report keys in the pipeline output, so the cause of the difference is not yet identified.

## Limitations (read before interpreting)
- MAUDE has no sales or units-in-use figures, so complaint rates cannot be calculated. FDA states that MAUDE is not intended to compare event rates across devices.
- Reports are voluntary or delayed, can be duplicated, and a rise in reports does not prove a rise in device problems. Publicity and recalls also change reporting.
- Problem codes are numeric and are not yet translated to the FDA's descriptions.
- This project does not compare manufacturers.

## Reproduce
1. Download the FDA files named above into a folder outside the repository.
2. Set `RAW` at the top of `R/maude_pipeline.R` to that folder.
3. Run `R/maude_pipeline.R`.
