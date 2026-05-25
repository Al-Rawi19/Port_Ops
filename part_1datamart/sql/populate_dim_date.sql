USE PortOps;
GO

DECLARE @StartDate DATE = '2020-01-01';
DECLARE @EndDate   DATE = '2028-12-31';
DECLARE @Date      DATE = @StartDate;

-- Clear existing rows except the unknown row
DELETE FROM mart.dim_date WHERE date_sk > 0;

WHILE @Date <= @EndDate
BEGIN
    DECLARE @FiscalMonth  TINYINT;
    DECLARE @FiscalQtr    TINYINT;
    DECLARE @FiscalYear   SMALLINT;
    DECLARE @MonthNum     TINYINT = MONTH(@Date);
    DECLARE @YearNum      SMALLINT = YEAR(@Date);

    -- Fiscal year starts April 1
    -- Fiscal month: April=1, May=2, ..., March=12
    SET @FiscalMonth = CASE
        WHEN @MonthNum >= 4 THEN @MonthNum - 3
        ELSE @MonthNum + 9
    END;

    SET @FiscalYear  = CASE WHEN @MonthNum >= 4 THEN @YearNum ELSE @YearNum - 1 END;
    SET @FiscalQtr   = CEILING(@FiscalMonth / 3.0);

    INSERT INTO mart.dim_date (
        date_sk, full_date, day_of_week, day_name, day_of_month,
        day_of_year, week_of_year, month_number, month_name,
        quarter, year, is_weekend, fiscal_year, fiscal_quarter, fiscal_month
    ) VALUES (
        CAST(FORMAT(@Date, 'yyyyMMdd') AS INT),  -- e.g. 20250401
        @Date,
        DATEPART(WEEKDAY, @Date),
        DATENAME(WEEKDAY, @Date),
        DAY(@Date),
        DATEPART(DAYOFYEAR, @Date),
        DATEPART(ISO_WEEK, @Date),
        @MonthNum,
        DATENAME(MONTH, @Date),
        DATEPART(QUARTER, @Date),
        @YearNum,
        CASE WHEN DATEPART(WEEKDAY, @Date) IN (1, 7) THEN 1 ELSE 0 END,
        @FiscalYear,
        @FiscalQtr,
        @FiscalMonth
    );

    SET @Date = DATEADD(DAY, 1, @Date);
END;

SELECT  * FROM mart.dim_date ORDER BY date_sk;
SELECT COUNT(*) FROM mart.dim_date;
