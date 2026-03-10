# =============================================================
#  GARCH(1,1) Volatility Model — Defense Stocks & ETFs
#  Platform : RStudio / Posit Cloud
#  Output   : Conditional vol plots + multi-day forecasts
#             Exports forecasts to /data/ for use in backtest
# =============================================================
# ── Install dependencies (run once) ──────────────────────────
pkgs <- c("quantmod", "rugarch", "ggplot2", "dplyr", "tidyr", "writexl")
install.packages(setdiff(pkgs, rownames(installed.packages())))
library(quantmod)
library(rugarch)
library(ggplot2)
library(dplyr)
library(tidyr)
library(writexl)
# ============================================================
#  ✏️  CONFIGURE HERE
# ============================================================
TICKERS <- c(
# 8 Defense Stocks
"LMT", "RTX", "NOC", "GD", "BA", "HII", "LHX", "LDOS",
# 4 Defense ETFs
"ITA", "XAR", "PPA", "DFEN"
)
START_DATE  <- "2018-01-01"
END_DATE    <- Sys.Date()
N_AHEAD     <- 10          # number of days to forecast ahead
VOL_THRESH  <- 0.25        # annualised vol threshold for signal export
# ============================================================
dir.create("data", showWarnings = FALSE)
# GARCH(1,1) specification
garch_spec <- ugarchspec(
variance.model    = list(model = "sGARCH", garchOrder = c(1, 1)),
mean.model        = list(armaOrder = c(1, 0), include.mean = TRUE),
distribution.model = "norm"
)
# Storage for all forecasts (used in summary export)
all_forecasts <- list()
run_garch <- function(ticker) {
cat("\n=== Processing:", ticker, "===\n")
# ── Fetch data ──────────────────────────────────────────────
raw <- tryCatch(
getSymbols(ticker, src = "yahoo",
from = START_DATE, to = END_DATE,
auto.assign = FALSE),
error = function(e) { cat("  Download failed:", e$message, "\n"); return(NULL) }
)
if (is.null(raw)) return(NULL)
prices  <- Ad(raw)
returns <- na.omit(diff(log(prices)))
# ── Fit GARCH(1,1) ──────────────────────────────────────────
fit <- tryCatch(
ugarchfit(spec = garch_spec, data = returns, solver = "hybrid"),
error = function(e) { cat("  Fit failed:", e$message, "\n"); return(NULL) }
)
if (is.null(fit)) return(NULL)
# ── Coefficients ────────────────────────────────────────────
cat("\n--- Coefficients ---\n")
print(round(coef(fit), 6))
persistence <- sum(coef(fit)[c("alpha1", "beta1")])
cat(sprintf("  Persistence (alpha+beta): %.4f\n", persistence))
# ── Conditional volatility (annualised) ─────────────────────
vol_daily <- sigma(fit)
vol_ann   <- vol_daily * sqrt(252)
vol_df    <- data.frame(
Date       = index(vol_daily),
Vol_Daily  = as.numeric(vol_daily),
Vol_Ann    = as.numeric(vol_ann),
Ticker     = ticker
)
# ── Multi-day forecast ──────────────────────────────────────
fc      <- ugarchforecast(fit, n.ahead = N_AHEAD)
fc_vol  <- as.numeric(sigma(fc)) * sqrt(252)   # annualised
fc_dates <- seq.Date(as.Date(END_DATE) + 1,
by = "day", length.out = N_AHEAD)
fc_df <- data.frame(
Date    = fc_dates,
Vol_Ann = fc_vol,
Ticker  = ticker
)
cat(sprintf("\n--- %d-Day Vol Forecast (annualised) ---\n", N_AHEAD))
print(fc_df[, c("Date", "Vol_Ann")])
# Signal column: 1 = low vol (go long), 0 = high vol (go flat)
fc_df$Signal <- ifelse(fc_df$Vol_Ann < VOL_THRESH, 1, 0)
# ── Plot 1: Conditional Volatility ──────────────────────────
p1 <- ggplot(vol_df, aes(x = Date, y = Vol_Ann)) +
geom_line(color = "#2196F3", linewidth = 0.6) +
geom_hline(yintercept = VOL_THRESH, linetype = "dashed",
color = "red", linewidth = 0.5) +
annotate("text", x = min(vol_df$Date), y = VOL_THRESH + 0.01,
label = paste("Threshold:", VOL_THRESH), hjust = 0,
color = "red", size = 3.2) +
labs(
title    = paste(ticker, "— Annualised Conditional Volatility (GARCH 1,1)"),
subtitle = paste("Period:", START_DATE, "to", END_DATE),
x = NULL, y = "Annualised Volatility"
) +
theme_minimal(base_size = 12) +
theme(plot.title = element_text(face = "bold"))
print(p1)
# ── Plot 2: Multi-day Forecast ───────────────────────────────
last_hist <- tail(vol_df, 60)   # last 60 days for context
last_hist$Type <- "Historical"
fc_plot <- fc_df[, c("Date", "Vol_Ann")]
fc_plot$Type <- "Forecast"
combined <- bind_rows(
last_hist[, c("Date", "Vol_Ann", "Type")],
fc_plot
)
p2 <- ggplot(combined, aes(x = Date, y = Vol_Ann, color = Type, linetype = Type)) +
geom_line(linewidth = 0.9) +
scale_color_manual(values = c("Historical" = "#2196F3", "Forecast" = "#FF5722")) +
scale_linetype_manual(values = c("Historical" = "solid", "Forecast" = "dashed")) +
geom_hline(yintercept = VOL_THRESH, linetype = "dotted",
color = "darkred", linewidth = 0.5) +
labs(
title    = paste(ticker, paste0("— ", N_AHEAD, "-Day Vol Forecast")),
subtitle = paste("Red dashed = forecast | Threshold:", VOL_THRESH),
x = NULL, y = "Annualised Volatility", color = NULL, linetype = NULL
) +
theme_minimal(base_size = 12) +
theme(plot.title = element_text(face = "bold"),
legend.position = "top")
print(p2)
# ── Save outputs ─────────────────────────────────────────────
write.csv(vol_df, file.path("data", paste0(ticker, "_garch_vol.csv")),
row.names = FALSE)
write.csv(fc_df,  file.path("data", paste0(ticker, "_garch_forecast.csv")),
row.names = FALSE)
cat("  Saved vol + forecast CSVs to data/\n")
return(fc_df)
}
# ── Run all tickers ───────────────────────────────────────────
results <- lapply(TICKERS, run_garch)
names(results) <- TICKERS
# ── Export combined forecast summary ─────────────────────────
combined_fc <- bind_rows(results)
write.csv(combined_fc,
file.path("data", "all_forecasts.csv"),
row.names = FALSE)
cat("\n\n========== FORECAST SUMMARY ==========\n")
summary_tbl <- combined_fc %>%
group_by(Ticker) %>%
summarise(
Avg_Vol_Forecast = round(mean(Vol_Ann), 4),
Max_Vol_Forecast = round(max(Vol_Ann),  4),
Signal_Days_Long = sum(Signal)
) %>%
arrange(desc(Avg_Vol_Forecast))
print(summary_tbl)
write.csv(summary_tbl,
file.path("data", "forecast_summary.csv"),
row.names = FALSE)
cat("\nAll outputs saved to data/\n")
list.files()
savehistory("garch_forecasting.R")
