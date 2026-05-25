# Port_Ops

## Setup Steps

1. Install SQL Server 2022 Developer Edition and SSMS
2. Run scripts in order: schema_&_db_creation.sql → staging_creation.sql → dims&facts&realtionshps&audit_creation.sql → populate_dim_date.sql
3. Open SSIS solution in Visual Studio 2022
4. Update the ExcelFilePath project parameter to point to PortOps_SourceData.xlsx
5. Run 00_Master.dtsx
6. Open dashboard.pbix in Power BI Desktop, refresh data

## Tool Versions
- SQL Server 2022 Developer
- Visual Studio 2022 with SSIS Projects 2022 extension
- Power BI Desktop last edition

## Assumptions
- The data window April 2025 – March 2026 is the reporting year
- CustomerHistory effective dates stored as Excel serial numbers are converted using the standard OLE Automation epoch (1899-12-30 base, adjusted -2 for Excel's 1900 leap year bug)
- Fiscal year is April 1 to March 31

---

## Written Question Answers

### SCD Type 1 vs Type 2
type 1 --> overwrite the existing row with the new value 
i implement this with customer_code so when customer_code change in source it reflect 
on mart with overwrite but only change the last value of customer_code in mart not the hsitorical rows of it if it has is_current = 0 multiple times and is_current = 1 it will overwtire only the 
row with is_current = 1
type 2 --> it add a new row to track history by 3 columns (date from, date to, is_current)
i implenet this with cutomer_tier so when customer_tier change it reflect in mart as new row 
it change the old row the (date to) to the date of the run and (is_current become 0)
and the new row the (date from beocme the date of run) and (date to become null or to a very distant future ) and is_current = 1.

### Why Surrogate Keys in Fact Tables
First, natural keys are volatile: if a customer_code ever changes, natural-key 
joins break every fact row referencing that code. Surrogate keys are immutable.
Second, SCD Type 2 creates multiple rows per natural key (e.g., customer_id = 3 
has two dim_customer rows). If fact tables referenced customer_id instead of 
customer_sk, there would be no way to know which historical version of the 
customer a given move was associated with. Surrogate keys make the join 
unambiguous and version-aware.

### Out-of-Range dim_date Dates
Any fact row whose date_sk doesn't match a row in dim_date will fail the Lookup 
and be redirected to the audit.load_errors table rather than being silently 
dropped. The pipeline logs a warning, completes without failure, and the 
reconciliation count identifies the discrepancy. To prevent this long-term, 
I would extend dim_date generation to include a rolling 2-year forward window, 
check the min/max dates in staging before running the mart load, and if any 
date is outside the range, auto-extend dim_date before proceeding.

### SSIS SCD Wizard
The built-in Wizard generates a row-by-row OLE DB Command component to issue 
individual UPDATE statements for Type 2 expirations — this does not scale.
At 100K+ rows it can be 10–100x slower than a set-based UPDATE via SQL. 
The Wizard also uses a poorly-optimised internal hash comparison that loads 
all columns into memory regardless of which columns are tracked. Additionally, 
Wizard-generated SSIS XML is notoriously difficult to maintain or modify — 
components are embedded as black boxes. A manual implementation with Lookup 
(full cache), Conditional Split, OLE DB Command (for expirations), and OLE DB 
Destination (for inserts) is transparent, debuggable, and production-grade.
scd wizard it doing disk i/o row by row to check the defference but with lookup
it load the table i cache and check the defference on the memory not doing 
multiple disk i/os and it much faster in memory than disk.

### Row-Count Reconciliation
After each package run, a final Execute SQL Task counts rows in staging and 
target. If the difference exceeds a 1% threshold, the task inserts a 
'Warning - Row Count Mismatch' row into audit.package_log and raises a 
non-fatal RAISERROR (severity 1) so the package completes but the discrepancy 
is visible in the audit log. For a hard mismatch (complete empty target), 
severity 16 stops the package entirely via RAISERROR. The reconciliation 
query is in the 00_Master package so it always runs as the final step.

### Role of the Staging Layer
Staging decouples extraction from transformation. Data lands in staging in 
its raw form, preserving source fidelity and making re-processing possible 
without re-reading the source file. Without staging, any transformation error 
would corrupt partially-loaded fact tables and require a full re-extraction. 
Staging also enables data quality checks before mart load — if the Excel 
file contains garbage, we detect it in staging before it reaches the mart.

### Power BI — One Active Relationship
Power BI allows only one active relationship between two tables to prevent 
filter ambiguity: if two paths existed, a DAX filter would propagate through 
both simultaneously, creating indeterminate results. For gate_transaction, 
both gate_in_date_sk and gate_out_date_sk point to dim_date. If both were 
active, a date slicer could not unambiguously know which to filter. 
One active (gate-in) and one inactive (gate-out) is the correct design; 
USERELATIONSHIP in a specific measure temporarily activates the inactive path 
within a controlled evaluation context.

### USERELATIONSHIP vs CROSSFILTER
USERELATIONSHIP replaces the active relationship with an inactive one for 
the duration of a measure's calculation — used when you want a different 
join path to dim_date (like gate_out_date_sk instead of gate_in_date_sk).
CROSSFILTER changes the direction (one-way vs bi-directional) of an existing 
active relationship — used when you want dim tables to filter each other.
For the gate date scenario, USERELATIONSHIP is correct because I am switching 
which date column drives the filter, not changing filter direction.

### Date Slicer Not Responding — Investigation Order
1. Confirm the visual uses a measure that routes through dim_date, not a 
   direct date column from a fact table (direct columns bypass the relationship).
2. Check that dim_date is marked as the Date Table in Modeling settings.
3. Check that the relationship between the fact table and dim_date is active 
   and on the correct columns (date_sk = date_sk, not full_date = date_sk).
4. Check if the measure uses USERELATIONSHIP for a specific relationship — if so, 
   the slicer on the other date column won't affect it (by design).
5. Check if a visual-level filter is overriding the slicer filter.
