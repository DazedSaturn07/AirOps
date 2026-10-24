# AirOps — Airline Disruption Analysis

AirOps analyzes **5.82 million US flight observations from 2015** to help an operations reader compare arrival reliability, cancellations and disruption patterns. It combines Python, MySQL, Excel and Power BI with consistent metric definitions and independent checks.

[Problem statement](PROBLEM_STATEMENT.md) · [Power BI source](power_bi/AirOps_Disruption.pbip) · [Excel workbook](excel/AirOps_Validation.xlsx) · [Metric definitions](notebooks/reference/metric_dictionary.csv)

![Power BI operations overview](power_bi/screenshots/Operations%20overview.png)

## The problem and the result

Flight counts alone do not explain reliability: a busy route can have many delays while still performing well as a percentage of eligible arrivals. Cancellations, diversions and missing outcomes also need separate treatment.

AirOps turns the source records into comparable indicators, carrier and time comparisons, and route detail that can be traced back to source observations. The output supports prioritizing investigations. It does not claim that an airline implemented changes or achieved savings.

## Main findings

| Indicator | Result |
|---|---:|
| Source observations | 5,819,079 |
| Eligible arrivals | 5,714,008 |
| Custom on-time rate, arrival delay ≤15 minutes | 82.09% |
| Cancelled observations | 89,884 |
| Cancellation rate, out of scheduled observations | 1.54% |
| Severe arrival delay >60 minutes, out of eligible arrivals | 5.58% |

February has the highest cancellation rate at approximately **4.78%**, while June has the lowest custom on-time rate at approximately **77.27%**. Late-aircraft attribution is the largest recorded category, with **24,961,931 minutes**. These are observed patterns requiring operational context, not proof of their underlying causes.

## Repository structure

| Location | Purpose |
|---|---|
| `notebooks/01_source_profile.ipynb` | Source verification, data profile and quality issues |
| `notebooks/02_clean_transform.ipynb` | Typed fact, lineage fields and a deterministic validation sample |
| `notebooks/03_analysis.ipynb` | Analysis, independent raw-source reconciliation and exports |
| `notebooks/reference/` | Data dictionary, metric rules and source-to-target mapping |
| `sql/` | Six ordered MySQL scripts and a checked execution/export helper |
| `excel/AirOps_Validation.xlsx` | Sample formulas, reconciliation, chart, exceptions and native PivotTable |
| `power_bi/` | Editable report/model source, DAX, Power Query, screenshots and validation results |

The notebooks are published without execution outputs. The report screenshots, workbook and [Power BI comparison results](power_bi/validation.csv) provide compact examples of the completed analysis. Raw data, generated handoffs, local connection settings and working caches are excluded from the repository.

## Reproduce the analysis

**Requirements:** Python 3.11 or later, MySQL 8.0 with its command-line client, and Power BI Desktop for the report. Desktop Excel is needed to recalculate and refresh the workbook's native PivotTable. Allow sufficient disk space for the source CSV, Parquet fact and SQL handoffs.

### 1. Prepare the source and Python environment

Clone the repository:

~~~bash
git clone https://github.com/DazedSaturn07/AirOps.git
cd AirOps
~~~

Obtain the [US DOT 2015 Flight Delays and Cancellations dataset](https://www.kaggle.com/datasets/usdot/flight-delays). Extract `flights.csv`, `airlines.csv` and `airports.csv` into `notebooks/data/raw/`. The included [manifest](notebooks/data/raw/manifest.json) records the source file sizes and hashes used for this analysis. Notebook 01 checks that the supplied files match; review any mismatch before proceeding.

Create and activate a virtual environment for your shell, then install the requirements and launch Jupyter:

~~~bash
python -m venv .venv
~~~

On Windows PowerShell, activate it with `.\.venv\Scripts\Activate.ps1`. On macOS/Linux, use `source .venv/bin/activate`.

~~~bash
python -m pip install -r requirements.txt
python -m jupyterlab
~~~

### 2. Run the three notebooks in order

Open Jupyter from the repository root. Select the Python environment and run **01 → 02 → 03** sequentially, inspecting the checks before moving on.

The workflow preserves all source observations, writes the full typed fact and a **45,461-row checking sample** under `notebooks/data/processed/`, and writes analysis/control files under `notebooks/data/exports/`. Execution and quality records are generated under `notebooks/data/quality/`.

The sample is used for Excel validation. Power BI analyzes the full fact.

### 3. Run the independent MySQL checks

Start a local MySQL 8.0 server and make the `mysql` client available on PATH. From the repository root:

~~~bash
python sql/run_sql.py --user YOUR_MYSQL_USER
~~~

The helper prompts privately for the password, creates the `airops360` schema, loads empty destination tables, checks existing data before reuse, executes the ordered scripts and exports reconciliations. It does not save the password. An initial load requires an account permitted to create/load the schema and configure LOCAL INFILE if disabled; the helper restores the server's original LOCAL INFILE setting.

The scripts cover setup, loading, model views, metric marts, validation and analysis. The helper resolves load-file paths automatically. If executing `02_load.sql` manually, resolve its relative paths from the repository root and check that the destination tables are empty before loading.

### 4. Explore Excel and Power BI

**Excel:** open [AirOps_Validation.xlsx](excel/AirOps_Validation.xlsx). Overview shows sample metrics; Reconciliation compares ten formula-derived results against Python/SQL controls; Carrier review includes a native PivotTable. Sample and Exceptions retain the underlying checking records.

The workbook is an embedded sample snapshot. Refresh All refreshes its PivotTable, not the source CSVs. For a changed dataset, replace the Sample table and matching Controls values from regenerated exports, preserve the eligible-delay formula, update Exceptions, recalculate and refresh the PivotTable. Compare sample results with sample controls, not full-population values.

**Power BI:** open [AirOps_Disruption.pbip](power_bi/AirOps_Disruption.pbip) in a current Power BI Desktop version that supports PBIP/PBIR. Keep its `.Report` and `.SemanticModel` folders alongside it. Set **ProjectFolder** to the absolute path of your cloned repository using Transform data → Edit parameters, then apply and Refresh.

The model imports the generated Parquet fact and the supplied airline lookup. MySQL is the independent validation stage; the Power BI model uses local files and does not require a database credential. Its four tables are fact_flight, Airline, Calendar and a disconnected DelayCause selector, with two active single-direction relationships and 30 measures. See [DAX](power_bi/dax_measures.dax) and [the fact query](power_bi/power_query_template.m).

The large full-data PBIX is excluded from Git. The editable project and [screenshots](power_bi/screenshots/) are included; a fresh clone must generate the local data before refreshing the report.

## Report pages and interactions

1. **Operations overview:** monthly arrival performance and carrier cancellation rates.
2. **Carrier and route reliability:** carrier comparisons and high-late-rate routes passing a minimum-volume screen.
3. **Airport patterns:** origin/destination code comparisons and unresolved-identifier coverage.
4. **Recorded delay attribution:** five recorded categories and selected carrier components.
5. **Time and seasonality:** scheduled local departure hour, monthly cancellations and peak periods.
6. **Route detail:** selected-route KPIs, monthly performance and source observations.

Carrier/month slicers synchronize across the visible pages. Right-click a route to drill through, use Back to return, and hover chart points for a contextual tooltip. Reset clears slicers; it does not remove a drillthrough filter or every chart selection. In Desktop editing mode, activate report buttons with Ctrl+click. Tables and category bars scroll where needed.

## Validation and interpretation

The completed snapshot was checked across tools:

- **22** independent raw-source/fact metric comparisons.
- **44** MySQL full/sample comparisons and **105** filtered comparisons.
- **10** native Excel formula checks, PivotTable refresh and missing-outcome/threshold checks.
- **136** native Power BI comparisons: 22 full baseline, 105 filtered and nine empty-context checks, including checks after reopening and refreshing the PBIX.

The [comparison CSV](power_bi/validation.csv) records metric-level expected and actual values. Counts and integer-minute sums compare exactly; floating-point rates and means use a tolerance of 1e-10.

Arrival rates exclude cancellations, diversions and missing arrival delays. This project uses a **custom on-time threshold of ≤15 minutes**, which differs from the official BTS boundary at exactly 15 minutes. Negative delays remain early arrivals.

October's **486,165 observations use unresolved numeric airport IDs**. They remain in overall/carrier totals, but full-year source-code route and airport labels are not harmonized. Recorded delay minutes are attribution, not proven causation. The optional reliability index is a project score, not an industry benchmark. See the [problem statement](PROBLEM_STATEMENT.md) for the scope and decision context.
