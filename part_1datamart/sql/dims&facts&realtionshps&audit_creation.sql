USE PortOps;
GO

CREATE TABLE mart.dim_date (
    date_sk         INT         NOT NULL PRIMARY KEY, -- format: YYYYMMDD e.g. 20250401
    full_date       DATE        NOT NULL,
    day_of_week     TINYINT     NOT NULL,   -- 1=Sunday, 7=Saturday
    day_name        NVARCHAR(10) NOT NULL,
    day_of_month    TINYINT     NOT NULL,
    day_of_year     SMALLINT    NOT NULL,
    week_of_year    TINYINT     NOT NULL,
    month_number    TINYINT     NOT NULL,
    month_name      NVARCHAR(10) NOT NULL,
    quarter         TINYINT     NOT NULL,
    year            SMALLINT    NOT NULL,
    is_weekend      BIT         NOT NULL,
    fiscal_year     SMALLINT    NOT NULL,   -- April 1 start
    fiscal_quarter  TINYINT     NOT NULL,
    fiscal_month    TINYINT     NOT NULL    -- 1=April, 12=March
);

-- Unknown/missing date placeholder
INSERT INTO mart.dim_date VALUES
(-1, '1900-01-01', 1, 'Unknown', 1, 1, 1, 1, 'Unknown', 1, 1900, 0, 1900, 1, 1);
GO

CREATE TABLE mart.dim_customer (
    customer_sk     INT          IDENTITY(1,1) PRIMARY KEY,
    customer_id     INT          NOT NULL,   -- natural key
    customer_code   NVARCHAR(10) NOT NULL,
    customer_name   NVARCHAR(100) NOT NULL,
    country         NVARCHAR(5)  NOT NULL,
    customer_tier   NVARCHAR(20) NOT NULL,   -- SCD2: tracked
    credit_limit    DECIMAL(12,2) NOT NULL,  -- SCD2: tracked
    active_flag     BIT          NOT NULL,   -- SCD1: overwrite
    onboarded_date  DATE         NULL,
    effective_from  DATE         NOT NULL,
    effective_to    DATE         NOT NULL,
    is_current      BIT          NOT NULL
);

-- Default/unknown row (used when a fact row can't find a customer)
SET IDENTITY_INSERT mart.dim_customer ON;
INSERT INTO mart.dim_customer
    (customer_sk, customer_id, customer_code, customer_name, country,
     customer_tier, credit_limit, active_flag, onboarded_date,
     effective_from, effective_to, is_current)
VALUES (-1, -1, 'UNK', 'Unknown Customer', 'UNK',
        'Unknown', 0, 0, NULL, '1900-01-01', '9999-12-31', 1);
SET IDENTITY_INSERT mart.dim_customer OFF;
GO

CREATE TABLE mart.dim_terminal (
    terminal_sk   INT          IDENTITY(1,1) PRIMARY KEY,
    terminal_id   INT          NOT NULL,
    terminal_code NVARCHAR(10) NOT NULL,
    terminal_name NVARCHAR(100) NOT NULL,
    zone          NVARCHAR(20) NOT NULL,
    terminal_type NVARCHAR(30) NOT NULL
);

SET IDENTITY_INSERT mart.dim_terminal ON;
INSERT INTO mart.dim_terminal (terminal_sk, terminal_id, terminal_code, terminal_name, zone, terminal_type)  VALUES (-1, -1, 'UNK', 'Unknown Terminal', 'UNK', 'UNK');
SET IDENTITY_INSERT mart.dim_terminal OFF;
GO

CREATE TABLE mart.dim_equipment (
    equipment_sk   INT          IDENTITY(1,1) PRIMARY KEY,
    equipment_id   INT          NOT NULL,
    equipment_code NVARCHAR(20) NOT NULL,
    equipment_type NVARCHAR(50) NOT NULL,
    terminal_id    INT          NOT NULL,
    capacity_tons  INT          NULL,
    acquired_date  DATE         NULL,
    status         NVARCHAR(20) NOT NULL
);

SET IDENTITY_INSERT mart.dim_equipment ON;
INSERT INTO mart.dim_equipment (equipment_sk,equipment_id,equipment_code,equipment_type,terminal_id,capacity_tons,acquired_date,status)VALUES (-1, -1, 'UNK', 'Unknown', -1, NULL, NULL, 'Unknown');
SET IDENTITY_INSERT mart.dim_equipment OFF;
GO

CREATE TABLE mart.dim_shift (
    shift_sk   INT          IDENTITY(1,1) PRIMARY KEY,
    shift_id   INT          NOT NULL,
    shift_code NVARCHAR(5)  NOT NULL,
    shift_name NVARCHAR(30) NOT NULL,
    start_time NVARCHAR(10) NOT NULL,
    end_time   NVARCHAR(10) NOT NULL
);

SET IDENTITY_INSERT mart.dim_shift ON;
INSERT INTO mart.dim_shift (shift_sk,shift_id,shift_code,shift_name,start_time,end_time) VALUES (-1, -1, 'UNK', 'Unknown Shift', 'N/A', 'N/A');
SET IDENTITY_INSERT mart.dim_shift OFF;
GO

USE PortOps;
GO

CREATE TABLE mart.fact_container_movement (
    movement_sk         INT          IDENTITY(1,1) PRIMARY KEY,
    movement_id         INT          NOT NULL,
    vessel_call_id      INT          NOT NULL,
    container_no        NVARCHAR(20) NOT NULL,
    container_size      NVARCHAR(10) NULL,
    move_type           NVARCHAR(20) NOT NULL,
    equipment_sk        INT          NOT NULL DEFAULT -1,
    shift_sk            INT          NOT NULL DEFAULT -1,
    customer_sk         INT          NOT NULL DEFAULT -1,
    terminal_sk         INT          NOT NULL DEFAULT -1,
    date_sk             INT          NOT NULL DEFAULT -1,
    move_start_time     DATETIME     NULL,
    move_end_time       DATETIME     NULL,
    is_reefer           BIT          NOT NULL DEFAULT 0,
    weight_tons         DECIMAL(8,2) NULL,
    crane_cycle_seconds INT          NULL   -- derived in SSIS from move_end_time - move_start_time
);

CREATE TABLE mart.fact_vessel_call (
    vessel_call_sk       INT          IDENTITY(1,1) PRIMARY KEY,
    vessel_call_id       INT          NOT NULL,
    vessel_name          NVARCHAR(100) NOT NULL,
    voyage_no            NVARCHAR(20) NOT NULL,
    customer_sk          INT          NOT NULL DEFAULT -1,
    terminal_sk          INT          NOT NULL DEFAULT -1,
    date_sk              INT          NOT NULL DEFAULT -1,  -- based on ATA date
    eta                  DATETIME     NULL,
    ata                  DATETIME     NULL,
    atd                  DATETIME     NULL,
    total_moves_planned  INT          NULL,
    total_moves_actual   INT          NULL,
    status               NVARCHAR(20) NULL,
    berth_delay_hours    DECIMAL(8,2) NULL,  -- derived in SSIS: (ata - eta) in hours
    stay_hours           DECIMAL(8,2) NULL,  -- derived in SSIS: (atd - ata) in hours
    moves_variance       INT          NULL   -- derived in SSIS: actual - planned
);

CREATE TABLE mart.fact_gate_transaction (
    gate_txn_sk             INT          IDENTITY(1,1) PRIMARY KEY,
    gate_txn_id             INT          NOT NULL,
    truck_plate             NVARCHAR(20) NULL,
    container_no            NVARCHAR(20) NULL,
    customer_sk             INT          NOT NULL DEFAULT -1,
    terminal_sk             INT          NOT NULL DEFAULT -1,
    gate_in_date_sk         INT          NOT NULL DEFAULT -1,  -- active FK to dim_date
    gate_out_date_sk        INT          NOT NULL DEFAULT -1,  -- inactive FK to dim_date
    shift_sk                INT          NOT NULL DEFAULT -1,
    direction               NVARCHAR(5)  NULL,
    gate_in_time            DATETIME     NULL,
    gate_out_time           DATETIME     NULL,
    truck_turnaround_minutes INT         NULL  -- derived in SSIS: gate_out - gate_in in minutes
);
GO


USE PortOps;
GO

/* relationships */

ALTER TABLE mart.fact_container_movement
ADD CONSTRAINT FK_fcm_equipment
FOREIGN KEY (equipment_sk)
REFERENCES mart.dim_equipment(equipment_sk);

ALTER TABLE mart.fact_container_movement
ADD CONSTRAINT FK_fcm_shift
FOREIGN KEY (shift_sk)
REFERENCES mart.dim_shift(shift_sk);

ALTER TABLE mart.fact_container_movement
ADD CONSTRAINT FK_fcm_customer
FOREIGN KEY (customer_sk)
REFERENCES mart.dim_customer(customer_sk);

ALTER TABLE mart.fact_container_movement
ADD CONSTRAINT FK_fcm_terminal
FOREIGN KEY (terminal_sk)
REFERENCES mart.dim_terminal(terminal_sk);

ALTER TABLE mart.fact_container_movement
ADD CONSTRAINT FK_fcm_date
FOREIGN KEY (date_sk)
REFERENCES mart.dim_date(date_sk);

GO



ALTER TABLE mart.fact_vessel_call
ADD CONSTRAINT FK_fvc_customer
FOREIGN KEY (customer_sk)
REFERENCES mart.dim_customer(customer_sk);

ALTER TABLE mart.fact_vessel_call
ADD CONSTRAINT FK_fvc_terminal
FOREIGN KEY (terminal_sk)
REFERENCES mart.dim_terminal(terminal_sk);

ALTER TABLE mart.fact_vessel_call
ADD CONSTRAINT FK_fvc_date
FOREIGN KEY (date_sk)
REFERENCES mart.dim_date(date_sk);

GO




ALTER TABLE mart.fact_gate_transaction
ADD CONSTRAINT FK_fgt_customer
FOREIGN KEY (customer_sk)
REFERENCES mart.dim_customer(customer_sk);

ALTER TABLE mart.fact_gate_transaction
ADD CONSTRAINT FK_fgt_terminal
FOREIGN KEY (terminal_sk)
REFERENCES mart.dim_terminal(terminal_sk);

ALTER TABLE mart.fact_gate_transaction
ADD CONSTRAINT FK_fgt_shift
FOREIGN KEY (shift_sk)
REFERENCES mart.dim_shift(shift_sk);

ALTER TABLE mart.fact_gate_transaction
ADD CONSTRAINT FK_fgt_gate_in_date
FOREIGN KEY (gate_in_date_sk)
REFERENCES mart.dim_date(date_sk);

ALTER TABLE mart.fact_gate_transaction
ADD CONSTRAINT FK_fgt_gate_out_date
FOREIGN KEY (gate_out_date_sk)
REFERENCES mart.dim_date(date_sk);

GO


/* auditing */

USE PortOps;
GO

CREATE TABLE audit.package_log (
    log_id        INT           IDENTITY(1,1) PRIMARY KEY,
    package_name  NVARCHAR(100) NOT NULL,
    start_time    DATETIME      NOT NULL DEFAULT GETDATE(),
    end_time      DATETIME      NULL,
    rows_source   INT           NULL,
    rows_staging  INT           NULL,
    rows_target   INT           NULL,
    status        NVARCHAR(20)  NOT NULL DEFAULT 'Running',  -- Running / Success / Failed
    error_message NVARCHAR(MAX) NULL
);

CREATE TABLE audit.load_errors (
    error_id      INT           IDENTITY(1,1) PRIMARY KEY,
    log_id        INT           NULL,
    package_name  NVARCHAR(100) NOT NULL,
    table_name    NVARCHAR(100) NOT NULL,
    error_time    DATETIME      NOT NULL DEFAULT GETDATE(),
    source_key    NVARCHAR(50)  NULL,
    error_code    INT           NULL,
    error_desc    NVARCHAR(500) NULL
);
GO

