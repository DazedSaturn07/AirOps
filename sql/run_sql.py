"""Run AirOps SQL files and save checked handoffs. Passwords are never saved.

Run from the project root: python sql/run_sql.py --user root
Or use a private mysql_config_editor login: --login-path airops
Only empty AirOps tables load. Existing rows must match every source field.
"""
import argparse
import csv
import getpass
import hashlib
import json
import os
import re
import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from decimal import Decimal
from itertools import zip_longest
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "notebooks" / "data"
EXPORT = DATA / "exports"
QUALITY = DATA / "quality"
DATABASE = "airops360"
COUNTS_AND_SUMS = {
    "scheduled_flights", "cancelled_flights", "diverted_flights", "arrived_flights",
    "on_time_arrivals", "delay_over_15_flights", "severe_delay_flights",
    "arrival_delay_minutes", "arrival_delay_non_null_flights",
    "air_system_delay_minutes", "security_delay_minutes", "airline_delay_minutes",
    "late_aircraft_delay_minutes", "weather_delay_minutes",
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--user", default="root")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", default=3306, type=int)
    parser.add_argument("--login-path")
    args = parser.parse_args()
    executable = shutil.which("mysql")
    if not executable:
        raise RuntimeError("mysql.exe is not on PATH. Install the MySQL command-line client.")
    inputs = {"stg_flight": DATA / "processed" / "fact_flight.tsv",
              "validation_sample": DATA / "processed" / "validation_sample.tsv"}
    for path in [*inputs.values(), EXPORT / "python_kpi_summary.csv",
                 EXPORT / "python_sample_kpi_summary.csv", EXPORT / "python_report_checks.csv"]:
        if not path.is_file():
            raise FileNotFoundError(f"Missing {path}. Run notebooks 01, 02 and 03 first.")
    environment = os.environ.copy()
    if args.login_path:
        auth = [f"--login-path={args.login_path}"]
    else:
        environment["MYSQL_PWD"] = getpass.getpass(f"MySQL password for {args.user}: ")
        auth = ["--no-defaults", f"--user={args.user}", f"--host={args.host}", f"--port={args.port}"]
    command = [executable, *auth, "--default-character-set=utf8mb4",
               "--connect-timeout=10", "--local-infile=1"]

    def query(sql, database=True):
        sql = (f"USE {DATABASE};\n" if database else "") + sql
        result = subprocess.run(command + ["--xml"], input=sql, text=True,
                                encoding="utf-8", env=environment, capture_output=True)
        if result.returncode:
            raise RuntimeError(result.stderr.strip())
        sets = []
        for block in re.findall(r"<resultset\b.*?</resultset>", result.stdout, re.S):
            root = ET.fromstring(block)
            sets.append([{field.attrib["name"]: field.text for field in row}
                         for row in root.findall("row")])
        return sets

    def check_contents(table, path):
        metadata = query(f"SHOW COLUMNS FROM {table};")[0]
        names = [column["Field"] for column in metadata]
        with path.open(encoding="utf-8", newline="") as handle:
            reader = csv.DictReader(handle, delimiter="\t")
            if set(reader.fieldnames) != set(names) or len(reader.fieldnames) != len(names):
                raise RuntimeError(f"{table}: source and database columns differ")
            expected_columns = reader.fieldnames
            ordered = ", ".join(expected_columns)
            sql = f"SELECT JSON_ARRAY({ordered}) FROM {DATABASE}.{table} ORDER BY source_row_number;"
            # Streaming comparison checks all 24 fields and does not hold the fact in RAM.
            with tempfile.TemporaryFile(mode="w+", encoding="utf-8", dir=QUALITY) as errors:
                process = subprocess.Popen(command + ["--batch", "--raw", "--skip-column-names"],
                                           stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                           stderr=errors, text=True, encoding="utf-8", env=environment)
                try:
                    process.stdin.write(sql)
                    process.stdin.close()
                    types = {column["Field"]: column["Type"].lower() for column in metadata}
                    verified = 0
                    for expected, actual_line in zip_longest(reader, process.stdout):
                        if expected is None or actual_line is None:
                            raise RuntimeError(f"{table}: row count differs during content check")
                        stored = json.loads(actual_line)
                        for field, actual in zip(expected_columns, stored):
                            original = expected[field]
                            if original == r"\N":
                                equal = actual is None
                            elif actual is None:
                                equal = False
                            elif types[field].startswith(("int", "tinyint", "bigint", "decimal", "smallint")):
                                equal = Decimal(original) == Decimal(str(actual))
                            else:
                                equal = original == str(actual)
                            if not equal:
                                raise RuntimeError(f"{table}: mismatch at source row {expected['source_row_number']}, column {field}")
                        verified += 1
                    if process.wait() != 0:
                        errors.seek(0)
                        raise RuntimeError(errors.read())
                finally:
                    process.stdout.close()
                    if process.poll() is None:
                        process.kill()
                        process.wait()
        print(f"Verified all fields: {table}, {verified:,} rows", flush=True)
        return verified

    def compare(scope, expected, actual):
        rows = []
        for name, value in expected.items():
            other = actual[name]
            missing = pd.isna(value)
            if missing:
                passed = other is None or pd.isna(other)
                difference = None
            else:
                passed = other is not None and not pd.isna(other)
                difference = float(other) - float(value) if passed else None
                tolerance = 0 if name in COUNTS_AND_SUMS else 1e-10
                passed = passed and abs(difference) <= tolerance
            rows.append({"scope": scope, "metric": name, "python_value": value,
                         "sql_value": other, "variance": difference,
                         "status": "PASS" if passed else "FAIL"})
        return rows

    def input_hash(path):
        with path.open("rb") as handle:
            return hashlib.file_digest(handle, "sha256").hexdigest()

    QUALITY.mkdir(parents=True, exist_ok=True)
    connected = query("SELECT VERSION() AS version, @@GLOBAL.local_infile AS local_infile;", False)[0][0]
    original_local = int(connected["local_infile"])
    changed_local = False
    record = {"started_at_utc": datetime.now(timezone.utc).isoformat(),
              "database": DATABASE, "mysql_version": connected["version"],
              "status": "RUNNING", "tables": {}, "source_files": {}}
    try:
        query((ROOT / "sql" / "01_setup.sql").read_text(encoding="utf-8"), False)
        loads = (ROOT / "sql" / "02_load.sql").read_text(encoding="utf-8")
        for table, path in inputs.items():
            record["source_files"][table] = {"file": str(path.relative_to(ROOT)), "sha256": input_hash(path)}
            count = int(query(f"SELECT COUNT(*) AS n FROM {table};")[0][0]["n"])
            action = "retained"
            if count == 0:
                if not original_local and not changed_local:
                    query("SET GLOBAL local_infile = 1;", False)
                    changed_local = True
                statement = next(item for item in re.findall(r"LOAD DATA LOCAL INFILE.*?;", loads, re.S)
                                 if re.search(r"INTO TABLE\s+" + table + r"\b", item))
                statement = re.sub(r"LOCAL INFILE\s*'[^']+'",
                                   lambda _: "LOCAL INFILE '" + path.as_posix().replace("'", "''") + "'", statement)
                print(f"Loading {table} ...", flush=True)
                warning_sets = query(statement + "\nSHOW WARNINGS;")
                if any(warning_sets):
                    raise RuntimeError(f"{table}: LOAD DATA produced warnings: {warning_sets[:1]}")
                action = "loaded"
            count = check_contents(table, path)
            record["tables"][table] = {"rows": count, "action": action, "content_check": "all 24 columns"}
        # Server-wide setting is restored immediately after loads, including on errors.
        if changed_local:
            query(f"SET GLOBAL local_infile = {original_local};", False)
            changed_local = False
        for file in ["03_model.sql", "04_marts.sql"]:
            query((ROOT / "sql" / file).read_text(encoding="utf-8"))
        print("Checking full/sample quality, metrics and medians ...", flush=True)
        validation = query((ROOT / "sql" / "05_validation.sql").read_text(encoding="utf-8"))
        if len(validation) != 6:
            raise RuntimeError("Unexpected validation result count")
        quality, full, sample, median, sample_median, candidates = validation
        for field in ["duplicate_flight_keys", "duplicate_source_rows", "invalid_rows", "missing_eligible_outcomes", "invalid_delay_buckets"]:
            if int(quality[0][field]) != 0:
                raise RuntimeError(f"SQL quality failed: {field} = {quality[0][field]}")
        full[0].update(median[0])
        sample[0].update(sample_median[0])
        reconciliation = []
        for scope, filename, actual in [
            ("full", "python_kpi_summary.csv", full[0]),
            ("sample", "python_sample_kpi_summary.csv", sample[0]),
        ]:
            expected = pd.read_csv(EXPORT / filename).iloc[0].to_dict()
            reconciliation.extend(compare(scope, expected, actual))
        # Same expressions as the SQL view, under matching WHERE filters.
        marts = (ROOT / "sql" / "04_marts.sql").read_text(encoding="utf-8")
        component_sql = re.search(r"CREATE OR REPLACE VIEW mart_kpi_components AS\s*(SELECT.*?FROM fact_flight);", marts, re.S).group(1)
        summary_sql = re.search(r"CREATE OR REPLACE VIEW mart_kpi_summary AS\s*(SELECT.*?FROM mart_kpi_components c);", marts, re.S).group(1)
        scopes = {"all": "1=1", "AA": "airline_code = 'AA'", "January": "MONTH(flight_date) = 1",
                  "JFK-LAX": "route_code = 'JFK-LAX'", "cancelled_only": "cancelled = 1"}
        filtered = []
        filtered_reconciliation = []
        expectations = pd.read_csv(EXPORT / "python_report_checks.csv").set_index("scope")
        for scope, where in scopes.items():
            sql = summary_sql.replace("FROM mart_kpi_components c",
                                      "FROM (" + component_sql + " WHERE " + where + ") c")
            actual = query(sql + ";")[0][0]
            filtered.append({"scope": scope, **actual})
            filtered_reconciliation.extend(compare(scope, expectations.loc[scope].to_dict(), actual))
            print(f"Checked report scope: {scope}", flush=True)
        print("Running five business analysis queries ...", flush=True)
        business = query((ROOT / "sql" / "06_analysis.sql").read_text(encoding="utf-8"))
        if len(business) != 5:
            raise RuntimeError("Unexpected business analysis result count")
        combined = reconciliation + filtered_reconciliation
        failed = [row for row in combined if row["status"] != "PASS"]
        if failed:
            pd.DataFrame(failed).to_csv(QUALITY / "sql_failed_comparisons.csv", index=False)
            raise RuntimeError(f"{len(failed)} Python/SQL comparisons failed. See data/quality/sql_failed_comparisons.csv.")
        # Promote the export set only after every check passes.
        outputs = {
            "sql_kpi_summary.csv": full, "sql_sample_kpi_summary.csv": sample,
            "sql_quality.csv": quality, "sql_candidate_duplicates.csv": candidates,
            "sql_python_reconciliation.csv": reconciliation,
            "sql_report_checks.csv": filtered, "sql_report_reconciliation.csv": filtered_reconciliation,
        }
        for name, rows in zip(["carrier", "route", "monthly", "departure_hour", "attribution"], business):
            outputs[f"sql_{name}_analysis.csv"] = rows
        outputs["sql_sample_kpis_long.csv"] = [
            {"metric": k, "value": v} for k, v in sample[0].items()
        ]
        with tempfile.TemporaryDirectory(dir=EXPORT, prefix=".sql-") as staging:
            for name, rows in outputs.items():
                columns = ["candidate_operational_key", "occurrences"] if name == "sql_candidate_duplicates.csv" else None
                pd.DataFrame(rows, columns=columns).to_csv(Path(staging) / name, index=False)
            for name in outputs:
                (Path(staging) / name).replace(EXPORT / name)
        record.update(status="PASS", finished_at_utc=datetime.now(timezone.utc).isoformat(),
                      full_sample_comparisons=len(reconciliation),
                      report_filter_comparisons=len(filtered_reconciliation),
                      quality=quality[0], exports=list(outputs),
                      maximum_absolute_variance=max(abs(row["variance"]) for row in combined if row["variance"] is not None))
        print(f"PASS: {len(reconciliation)} full/sample comparisons and {len(filtered_reconciliation)} report-filter comparisons.", flush=True)
    except Exception as error:
        record.update(status="FAILED", error=str(error), finished_at_utc=datetime.now(timezone.utc).isoformat())
        raise
    finally:
        if changed_local:
            query(f"SET GLOBAL local_infile = {original_local};", False)
        record["local_infile_restored_to"] = original_local
        (QUALITY / "sql_run.json").write_text(json.dumps(record, indent=2), encoding="utf-8")
        environment.pop("MYSQL_PWD", None)


if __name__ == "__main__":
    main()
