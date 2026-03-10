# Defense Sector GARCH Volatility Backtest

A quantitative finance project that implements a **volatility-timing trading strategy** across 12 U.S. defense stocks and ETFs, using GARCH-based signals to dynamically switch between long and cash positions.

Built in two parts: **Python (Google Colab)** for historical backtesting and **R (Posit Cloud)** for GARCH(1,1) forecasting.

---

## What It Does

Instead of buying and holding defense stocks, this strategy monitors rolling realized volatility. When annualized vol exceeds **25%**, the strategy exits to cash. When vol is calm, it holds the position. The intuition: avoid the worst drawdown days that tend to cluster during high-volatility regimes.

---

## Universe

| Category | Tickers |
|---|---|
| Defense Stocks | LMT, RTX, NOC, GD, BA, HII, LHX, LDOS |
| Defense ETFs | ITA, XAR, PPA, DFEN |

Data sourced via `yfinance`, starting January 2018.

---

## Project Structure

```
defense-garch-backtest/
├── README.md
├── python/
│   └── backtesting.py         # Backtest engine (Google Colab)
├── r/
│   └── garch_forecasting.R    # GARCH(1,1) forecasts (Posit Cloud)
└── data/
    ├── all_forecasts.csv       # 10-day forward vol forecasts, all tickers
    ├── forecast_summary.csv    # Summary: avg vol, max vol, signal per ticker
    └── [TICKER]_garch_vol.csv  # Historical GARCH conditional variance per ticker
```

---

## How It Works

### Part 1 — Python Backtest

**Signal generation:**
1. Compute 20-day rolling realized volatility (annualized): `RealVol = StdDev(returns, 20) × √252`
2. If `RealVol > 0.25` → Signal = 0 (flat/cash)
3. If `RealVol ≤ 0.25` → Signal = 1 (long)
4. Shift signal forward 1 day to avoid lookahead bias

**Metrics computed:** Total Return, CAGR, Sharpe Ratio, Max Drawdown, Time in Market, Final Equity

**Output:** Equity curves (strategy vs. buy & hold) for all 12 instruments

### Part 2 — R GARCH Forecasting

Fits a proper **GARCH(1,1)** model to each ticker using the `rugarch` package and generates 10-day forward volatility forecasts. These forward-looking signals are compared against the same 25% threshold to produce a current-day trading view.

---

## Current Signals (March 2026)

| Ticker | Avg Vol Forecast | Signal |
|--------|-----------------|--------|
| DFEN | 63.19% | FLAT |
| BA | 35.65% | FLAT |
| RTX | 33.67% | FLAT |
| HII | 33.34% | FLAT |
| NOC | 30.32% | FLAT |
| LHX | 29.98% | FLAT |
| LDOS | 28.39% | FLAT |
| XAR | 26.84% | FLAT |
| LMT | 26.30% | FLAT |
| **ITA** | **24.60%** | **LONG** |
| **GD** | **22.64%** | **LONG** |
| **PPA** | **21.97%** | **LONG** |

9 of 12 instruments are currently in flat/cash territory — the defense sector is in an elevated volatility regime as of early 2026.

---

## Dependencies

**Python**
```
yfinance pandas numpy matplotlib scipy
```

**R**
```r
install.packages(c("rugarch", "tidyverse"))
```

---

## Key Concepts

- **GARCH(1,1)** — Models time-varying volatility; captures volatility clustering and mean reversion
- **Realized Volatility** — Rolling historical vol used as the backtest signal proxy
- **Lookahead Bias Prevention** — Signal is shifted forward 1 period before applying positions
- **Sharpe Ratio** — Primary risk-adjusted performance metric
- **Max Drawdown** — Key risk metric; measures worst peak-to-trough portfolio decline

---

## Limitations & Future Work

- [ ] Vol threshold (25%) is fixed — should be optimized via walk-forward validation
- [ ] Transaction costs and slippage not modeled
- [ ] Replace rolling realized vol with GARCH conditional variance as the live signal
- [ ] Portfolio-level optimization (currently each ticker evaluated independently)
- [ ] Extend to other sectors for robustness testing
