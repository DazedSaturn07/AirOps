# Problem statement

Airline operations teams need to distinguish recurring disruption patterns from isolated incidents. A high delay count can reflect a busy carrier or route rather than poor performance, while a low average delay can hide cancellations, diversions and severe delays.

AirOps uses the supplied 2015 US flight dataset to produce a consistent, explainable view of arrival reliability and disruption. Its intended reader is an operations analyst or manager deciding which patterns deserve further investigation.

## Questions

- How do arrival reliability, cancellation and severe-delay rates differ across carriers and months?
- Which source-code routes and airport patterns warrant investigation after checking observation volume?
- How does performance vary by scheduled local departure hour?
- Which recorded delay-attribution categories account for the most minutes?

## Approach

Python profiles and transforms the source while preserving lineage and missing outcomes. MySQL independently calculates and checks the same metrics. Excel validates a manageable sample using formulas and a native PivotTable. Power BI presents the full population through filters, comparisons and route drillthrough.

The analysis retains all **5,819,079 source observations**. Counts and rates are shown together, and arrival metrics use a defined eligible population rather than silently treating missing outcomes as zero delay.

## Delivered outcome

The project provides a six-page report, a sample validation workbook, readable analysis notebooks, SQL checks and documented metric definitions. It identifies patterns such as February's higher cancellation rate, June's lower custom on-time rate and the large recorded late-aircraft attribution total.

This solves the analytical reporting problem: turning a large flight-record dataset into comparable, traceable operational indicators. It supports prioritizing investigations; it does not demonstrate that an airline changed its operations or achieved cost savings.

## Scope and limits

- One row represents a source observation, not a guaranteed unique physical flight.
- Arrival rates exclude cancelled, diverted and missing-delay observations. Cancellation and diversion use scheduled observations as their denominator.
- The project retains a **custom on-time threshold of arrival delay ≤15 minutes**. This differs from the official BTS boundary at exactly 15 minutes.
- October's **486,165 observations use unresolved numeric airport identifiers**. Overall and carrier totals include them, but source-code route and airport labels are not harmonized across the year.
- Comparisons are observational. Recorded attribution does not establish root cause, controllability or savings.
- The Excel sample is deterministic and intended for checking calculations, not statistical inference.

See the [README](README.md) for the repository structure, results and reproduction workflow.
