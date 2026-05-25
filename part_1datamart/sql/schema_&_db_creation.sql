CREATE DATABASE PortOps;
GO

USE PortOps;
GO

CREATE SCHEMA stg;-- staging: raw data lands here first
GO
CREATE SCHEMA mart;  -- mart: clean dimensional tables
GO
CREATE SCHEMA audit; -- audit: logs every package run
GO

