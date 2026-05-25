USE PortOps;
GO


CREATE TABLE stg.customers (
    customer_id      INT,
    customer_code    NVARCHAR(10),
    customer_name    NVARCHAR(100),
    country          NVARCHAR(5),
    customer_tier    NVARCHAR(20),
    credit_limit     DECIMAL(12,2),
    active_flag      BIT,
    onboarded_date   FLOAT  -- Excel stores dates as floats; convert in SSIS
);

CREATE TABLE stg.customer_history (
    customer_id      INT,
    effective_from   FLOAT,        -- Excel serial number → converted later
    effective_to     NVARCHAR(20), -- Mix of Excel serial AND '9999-12-31' string
    customer_tier    NVARCHAR(20),
    credit_limit     DECIMAL(12,2),
    change_reason    NVARCHAR(50)
);

CREATE TABLE stg.terminals (
    terminal_id    INT,
    terminal_code  NVARCHAR(10),
    terminal_name  NVARCHAR(100),
    zone           NVARCHAR(20),
    terminal_type  NVARCHAR(30)
);

CREATE TABLE stg.equipment (
    equipment_id    INT,
    equipment_code  NVARCHAR(20),
    equipment_type  NVARCHAR(50),
    terminal_id     INT,
    capacity_tons   INT,
    acquired_date   FLOAT,  -- Excel float date
    status          NVARCHAR(20)
);

CREATE TABLE stg.shifts (
    shift_id    INT,
    shift_code  NVARCHAR(5),
    shift_name  NVARCHAR(30),
    start_time  NVARCHAR(10),
    end_time    NVARCHAR(10)
);

CREATE TABLE stg.vessel_calls (
    vessel_call_id      INT,
    vessel_name         NVARCHAR(100),
    voyage_no           NVARCHAR(20),
    customer_id         INT,
    terminal_id         INT,
    eta                 FLOAT,  -- Excel float
    ata                 FLOAT,
    atd                 FLOAT,
    total_moves_planned INT,
    total_moves_actual  INT,
    status              NVARCHAR(20)
);

CREATE TABLE stg.container_movements (
    movement_id     INT,
    vessel_call_id  INT,
    container_no    NVARCHAR(20),
    container_size  NVARCHAR(10),
    move_type       NVARCHAR(20),
    equipment_id    INT,
    shift_id        INT,
    customer_id     INT,
    terminal_id     INT,
    move_start_time FLOAT,  -- Excel float
    move_end_time   FLOAT,
    is_reefer       BIT,
    weight_tons     DECIMAL(8,2)
);

CREATE TABLE stg.gate_transactions (
    gate_txn_id    INT,
    truck_plate    NVARCHAR(20),
    container_no   NVARCHAR(20),
    customer_id    INT,
    terminal_id    INT,
    direction      NVARCHAR(5),
    gate_in_time   FLOAT,  -- Excel float
    gate_out_time  FLOAT,
    shift_id       INT
);
GO