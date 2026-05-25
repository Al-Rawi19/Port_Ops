# DAX Measures — Documentation

## Total Container Moves
```dax
Total Container Moves = 
COUNTROWS('mart fact_container_movement')
```
Counts every row in the fact table. Responds to all active dimension 
filters (date, customer, terminal, shift).

## Avg Crane Cycle Seconds
```dax
Avg Crane Cycle Seconds = 
DIVIDE(
    SUM('mart fact_container_movement'[crane_cycle_seconds]),
    COUNTROWS('mart fact_container_movement'),
    0
)
```
Uses DIVIDE to handle zero-row context (returns 0 instead of divide-by-zero).
crane_cycle_seconds is a pre-computed integer column loaded by SSIS.

## Gate-Ins Count
```dax
Gate-Ins Count = 
CALCULATE(
    COUNTROWS('mart fact_gate_transaction'),
    'mart fact_gate_transaction'[direction] = "IN"
)
```
Uses the active relationship (gate_in_date_sk → dim_date) automatically.
The date slicer filters by gate-in date.

## Gate-Outs Count
```dax
Gate-Outs Count = 
CALCULATE(
    COUNTROWS('mart fact_gate_transaction'),
    USERELATIONSHIP('mart fact_gate_transaction'[gate_out_date_sk], 'mart dim_date'[date_sk]),
    'mart fact_gate_transaction'[direction] = "OUT"
)
```
USERELATIONSHIP activates the inactive gate_out → dim_date relationship only 
within this measure's filter context. The date slicer now filters by 
gate-out date for this measure, enabling side-by-side comparison.

## Avg Truck Turnaround Minutes
```dax
Avg Truck Turnaround Minutes = 
CALCULATE(
    AVERAGE('mart fact_gate_transaction'[truck_turnaround_minutes]),
    USERELATIONSHIP('mart fact_gate_transaction'[gate_out_date_sk], 'mart dim_date'[date_sk])
)
```
Filtered by gate-out date (same USERELATIONSHIP pattern) because turnaround 
is attributed to when the truck exits, not when it enters.

## Moves YoY %
```dax
Moves YoY % = 
VAR CurrentMoves = [Total Container Moves]
VAR PriorYearMoves = 
    CALCULATE(
        [Total Container Moves],
        SAMEPERIODLASTYEAR('mart dim_date'[full_date])
    )
RETURN
DIVIDE(
    CurrentMoves - PriorYearMoves,
    PriorYearMoves,
    BLANK()
)
```
Uses SAMEPERIODLASTYEAR for automatic calendar-aware year-ago comparison.
Returns BLANK() if prior year has no data (avoids misleading 100% growth).

## Moves 7-Day Rolling Avg
```dax
Moves 7-Day Rolling Avg = 
VAR Last_Date =
    MAX('mart dim_date'[full_date])

VAR RollingWindow =
    DATESINPERIOD(
        'mart dim_date'[full_date],
        Last_Date,
        -7,
        DAY
    )

RETURN
    CALCULATE(
        [Total Container Moves],
        RollingWindow
    ) / 7
```
DATESINPERIOD creates a 7-day window ending at the current context date.
Divides by 7 to give the daily average within that window.

## Berth Delay Avg Hours
```dax
Berth Occupancy % = 
DIVIDE(
    SUM('mart fact_vessel_call'[stay_hours]),
    DISTINCTCOUNT('mart dim_date'[full_date]) * 24,
    0
)
```
Simple average at the vessel-call grain. berth_delay_hours is a pre-computed 
DECIMAL column loaded by SSIS as (ATA - ETA) in hours.
