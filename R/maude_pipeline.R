# MAUDE post-market trending - one-script pipeline (R)
# Run from the project folder. Raw FDA .txt files are kept outside the repo in C:/maude_data/raw.

library(readr); library(dplyr); library(DBI); library(RSQLite)
library(lubridate); library(qicharts2); library(ggplot2)

PRODUCT_CODE <- "LOX"          # PTCA balloon catheters. Alternative: "NIQ" (coronary drug-eluting stents)
RAW <- "C:/maude_data/raw"
dir.create("outputs", showWarnings = FALSE)

# ---- 1. Find the files (check these lists look right) ------------------------------------
all_txt       <- list.files(RAW, "\\.txt$", ignore.case = TRUE, full.names = TRUE)
nm            <- basename(all_txt)
master_files  <- all_txt[grepl("^mdrfoi", nm, ignore.case = TRUE)]
device_files  <- all_txt[grepl("^(foidev|device)", nm, ignore.case = TRUE) & !grepl("problem", nm, ignore.case = TRUE)]
problem_files <- all_txt[grepl("^foidev", nm, ignore.case = TRUE) & grepl("problem", nm, ignore.case = TRUE)]
print(list(master = master_files, device = device_files, problems = problem_files))
stopifnot(length(master_files) > 0, length(device_files) > 0)

# ---- 2. Reader: pipe-delimited, keep only the columns we need ---------------------------
# If `keys` is given, the file is read in chunks of 500,000 rows and only rows whose
# MDR_REPORT_KEY is in `keys` are kept. This keeps memory use small for the huge master file.
read_maude <- function(f, wanted, keys = NULL) {
  opts <- list(delim = "|", quote = "", escape_double = FALSE,
               locale = locale(encoding = "latin1"), progress = FALSE)
  hdr  <- names(do.call(read_delim, c(list(file = f, n_max = 0,
                                           col_types = cols(.default = col_character()), show_col_types = FALSE), opts)))
  keep <- hdr[toupper(hdr) %in% wanted]
  message(basename(f), ": columns kept = ", paste(keep, collapse = ", "))
  stopifnot(length(keep) >= 2)
  ct <- do.call(cols_only, setNames(rep(list(col_character()), length(keep)), keep))
  if (is.null(keys)) {
    df <- do.call(read_delim, c(list(file = f, col_types = ct, show_col_types = FALSE), opts))
  } else {
    cb <- DataFrameCallback$new(function(x, pos) {
      names(x) <- tolower(names(x)); x[x$mdr_report_key %in% keys, ] })
    df <- do.call(read_delim_chunked, c(list(file = f, callback = cb, chunk_size = 500000,
                                             col_types = ct), opts))
  }
  names(df) <- tolower(names(df))
  df
}

# ---- 3. Device file: keep only the product code we study --------------------------------
device <- bind_rows(lapply(device_files, read_maude,
                           wanted = c("MDR_REPORT_KEY", "DEVICE_REPORT_PRODUCT_CODE", "MANUFACTURER_D_NAME", "BRAND_NAME"))) |>
  filter(device_report_product_code == PRODUCT_CODE) |>
  group_by(mdr_report_key) |>
  summarise(manufacturer = first(manufacturer_d_name), brand = first(brand_name), .groups = "drop")
message("Reports for ", PRODUCT_CODE, ": ", nrow(device))

# ---- 4. Master file: keep only those reports --------------------------------------------
master <- bind_rows(lapply(master_files, function(f)
  read_maude(f, c("MDR_REPORT_KEY", "EVENT_TYPE", "DATE_RECEIVED", "DATE_OF_EVENT"),
             keys = device$mdr_report_key)))

cat("\nEvent type values (expect D, IN, M, O):\n"); print(table(master$event_type, useNA = "ifany"))
cat("\nDate samples (check the format):\n"); print(head(master$date_received, 5))

to_date <- function(x) as.Date(parse_date_time(x, orders = c("Ymd", "dmY", "mdY"), quiet = TRUE))
reports <- master |>
  distinct(mdr_report_key, .keep_all = TRUE) |>
  mutate(date_received = to_date(date_received), date_of_event = to_date(date_of_event),
         month = format(date_received, "%Y-%m")) |>
  inner_join(device, by = "mdr_report_key") |>
  filter(!is.na(date_received))

# ---- 5. Problem codes (these files have NO header row: report key | problem code number) --
keys <- device$mdr_report_key
problems <- bind_rows(lapply(problem_files, function(f) {
  cb <- DataFrameCallback$new(function(x, pos) x[x$mdr_report_key %in% keys, ])
  read_delim_chunked(f, callback = cb, chunk_size = 500000, delim = "|", quote = "",
                     escape_double = FALSE, col_names = c("mdr_report_key", "problem_code"),
                     col_types = cols(.default = col_character()),
                     locale = locale(encoding = "latin1"), progress = FALSE)
})) |> distinct()
message("Problem-code rows kept: ", nrow(problems))

# ---- 6. Write to SQLite and run the numbered SQL files -----------------------------------
con <- dbConnect(SQLite(), "maude.sqlite")
dbWriteTable(con, "maude_reports", reports |> mutate(across(c(date_received, date_of_event), as.character)),
             overwrite = TRUE)
dbWriteTable(con, "maude_problems", problems, overwrite = TRUE)

for (f in sort(list.files("sql", "^0[1-5].*\\.sql$", full.names = TRUE))) {
  res <- dbGetQuery(con, paste(readLines(f), collapse = "\n"))
  write_csv(res, file.path("outputs", sub("\\.sql$", ".csv", basename(f))))
  cat("\n", basename(f), "\n"); print(head(res, 10))
}

# ---- 7. Reporting lag (event date -> FDA received date) ----------------------------------
lag <- reports |>
  mutate(lag_days = as.numeric(date_received - date_of_event)) |>
  filter(!is.na(lag_days), lag_days >= 0) |>
  group_by(month) |> summarise(median_lag_days = median(lag_days), reports = n(), .groups = "drop")
write_csv(lag, "outputs/06_reporting_lag.csv")

# ---- 8. SPC charts (drop the latest month: it is usually incomplete) ----------------------
monthly <- dbGetQuery(con, paste(readLines("sql/04_serious_proportion.sql"), collapse = "\n")) |>
  mutate(month = as.Date(paste0(month, "-01"))) |> arrange(month)
monthly <- monthly[-nrow(monthly), ]

# p' (Laney) chart: adjusts for the extra variation that ordinary p-charts flag as false signals
p_chart <- qic(month, serious, n = total, data = monthly, chart = "pp", x.angle = 45,
               title = paste0("Proportion of death/injury reports by month (", PRODUCT_CODE, ", MAUDE)"),
               ylab = "Proportion of reports", xlab = "Month received")
ggsave("outputs/spc_serious_proportion.png", p_chart, width = 9, height = 5, dpi = 150)

c_chart <- qic(month, total, data = monthly, chart = "c", x.angle = 45,
               title = paste0("Monthly report count (", PRODUCT_CODE, ", MAUDE)"))
ggsave("outputs/spc_monthly_counts.png", c_chart, width = 9, height = 5, dpi = 150)

dbDisconnect(con)
cat("\nDone. Look in outputs/ and check the numbers against FDA's MAUDE web search for one month.\n")