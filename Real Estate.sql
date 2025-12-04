IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'stg') EXEC('CREATE SCHEMA stg');
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'dwh') EXEC('CREATE SCHEMA dwh');
GO



select count( * )  from dwh.dimagent

TRUNCATE TABLE dwh.dimagent;


select count (* ) from dwh.dimcampaign



/********************************************
  STAGING TABLES (one per CSV)
  - Keep as raw as possible (nullable) so loads don't fail
********************************************/
select top 10 * from stg.viewings
-- Agents
IF OBJECT_ID('stg.Agents','U') IS NULL
CREATE TABLE stg.Agents (
  AgentID         VARCHAR(50) NOT NULL,
  AgentName       VARCHAR(200) NULL,
  Region          VARCHAR(100) NULL,
  City            VARCHAR(100) NULL,
  JoinDate        DATE        NULL,
  ExperienceYears INT         NULL
);
GO


-- Campaigns
IF OBJECT_ID('stg.Campaigns','U') IS NULL
CREATE TABLE stg.Campaigns (
  CampaignID   VARCHAR(50)  NOT NULL,
  ListingID    VARCHAR(50)  NULL,
  StartDate    DATE         NULL,
  EndDate      DATE         NULL,
  Channel      VARCHAR(100) NULL,
  Cost         DECIMAL(18,2) NULL
);
GO

-- Data Dictionary 
IF OBJECT_ID('stg.Data_Dictionary','U') IS NULL
CREATE TABLE stg.Data_Dictionary (
  [File]   VARCHAR(200) NOT NULL,
  [Column]   VARCHAR(200) NOT NULL,
  [Description] VARCHAR(1000) NULL
);
GO


-- Leads
IF OBJECT_ID('stg.Leads','U') IS NULL
CREATE TABLE stg.Leads (
  LeadID      VARCHAR(50)  NOT NULL,
  ListingID   VARCHAR(50)  NULL,
  LeadDate    DATE         NULL,
  Source      VARCHAR(100) NULL,
  LeadScore   INT          NULL
);
GO


-- Listings
IF OBJECT_ID('stg.Listings','U') IS NULL
CREATE TABLE stg.Listings (
  ListingID    VARCHAR(50) NOT NULL,
  PropertyID   VARCHAR(50) NULL,
  AgentID      VARCHAR(50) NULL,
  ListDate     DATE        NULL,
  Status       VARCHAR(50) NULL,
  AskingPrice  DECIMAL(18,2) NULL,
  Currency     VARCHAR(10) NULL,
  EndDate      DATE        NULL
);
GO

-- Offers
IF OBJECT_ID('stg.Offers','U') IS NULL
CREATE TABLE stg.Offers (
  OfferID     VARCHAR(50) NOT NULL,
  ListingID   VARCHAR(50) NULL,
  OfferDate   DATE        NULL,
  OfferPrice  DECIMAL(18,2) NULL,
  OfferStatus VARCHAR(50) NULL
);
GO

-- Properties
IF OBJECT_ID('stg.Properties','U') IS NULL
CREATE TABLE stg.Properties (
  PropertyID   VARCHAR(50) NOT NULL,
  Region       VARCHAR(100) NULL,
  City         VARCHAR(100) NULL,
  PropertyType VARCHAR(100) NULL,
  Bedrooms     INT          NULL,
  Bathrooms    INT          NULL,
  AreaSqft     INT          NULL,
  YearBuilt    INT          NULL
);
GO

-- Transactions
IF OBJECT_ID('stg.Transactions','U') IS NULL
CREATE TABLE stg.Transactions (
  TransactionID VARCHAR(50) NOT NULL,
  ListingID     VARCHAR(50) NULL,
  AgentID       VARCHAR(50) NULL,
  PropertyID    VARCHAR(50) NULL,
  OfferDate     DATE        NULL,
  ClosingDate   DATE        NULL,
  SalePrice     DECIMAL(18,2) NULL,
);
GO

-- Viewings
IF OBJECT_ID('stg.Viewings','U') IS NULL
CREATE TABLE stg.Viewings (
  ViewingID       VARCHAR(50) NOT NULL,
  ListingID       VARCHAR(50) NULL,
  ViewingDate     DATE        NULL,
  DurationMinutes INT         NULL,
  Feedback        VARCHAR(200) NULL
);
GO


/********************************************
  DWH: Data dictionary table (metadata store)
********************************************/
IF OBJECT_ID('dwh.Data_Dictionary','U') IS NULL
CREATE TABLE dwh.Data_Dictionary (
  id INT IDENTITY(1,1) PRIMARY KEY,
  file_name VARCHAR(200) NOT NULL,
  column_name VARCHAR(200) NOT NULL,
  description VARCHAR(1000) NULL,
  created_at DATETIME2 DEFAULT SYSUTCDATETIME()
);
GO

/********************************************
  DWH DIMENSIONS (surrogate keys)
  - DimAgent, DimProperty, DimListing, DimCampaign, DimDate, DimLead
********************************************/

-- Date dimension (simple)
IF OBJECT_ID('dwh.DimDate','U') IS NULL
CREATE TABLE dwh.DimDate (
  DateKey      INT IDENTITY(1,1) PRIMARY KEY, -- surrogate
  FullDate     DATE NOT NULL,
  YearNum      INT NULL,
  MonthNum     INT NULL,
  DayNum       INT NULL,
  WeekOfYear   INT NULL,
  Quarter      INT NULL,
  IsWeekend    BIT NULL
);
GO


-- Agent dimension
IF OBJECT_ID('dwh.DimAgent','U') IS NULL
CREATE TABLE dwh.DimAgent (
  AgentSK      INT IDENTITY(1,1) PRIMARY KEY,
  AgentID      VARCHAR(50) NOT NULL, -- natural key from source
  AgentName    VARCHAR(200) NULL,
  Region       VARCHAR(100) NULL,
  City         VARCHAR(100) NULL,
  JoinDate     DATE NULL,
  ExperienceYears INT NULL,
  EffectiveFrom DATETIME2 DEFAULT SYSUTCDATETIME(),
  EffectiveTo   DATETIME2 NULL,
  IsActive      BIT DEFAULT 1
);
GO

UPDATE dwh.DimAgent
SET
    EffectiveFrom = ISNULL(EffectiveFrom, SYSUTCDATETIME()),
    IsActive      = ISNULL(IsActive, 1);


-------------------------------------------------------------------------------------------------------

-- Property dimension
IF OBJECT_ID('dwh.DimProperty','U') IS NULL
CREATE TABLE dwh.DimProperty (
  PropertySK   INT IDENTITY(1,1) PRIMARY KEY,
  PropertyID   VARCHAR(50) NOT NULL,
  Region       VARCHAR(100) NULL,
  City         VARCHAR(100) NULL,
  PropertyType VARCHAR(100) NULL,
  Bedrooms     INT NULL,
  Bathrooms    INT NULL,
  AreaSqft     INT NULL,
  YearBuilt    INT NULL,
  EffectiveFrom DATETIME2 DEFAULT SYSUTCDATETIME(),
  EffectiveTo   DATETIME2 NULL,
  IsActive      BIT DEFAULT 1
);
GO

-- Listing dimension
IF OBJECT_ID('dwh.DimListing','U') IS NULL
CREATE TABLE dwh.DimListing (
  ListingSK    INT IDENTITY(1,1) PRIMARY KEY,
  ListingID    VARCHAR(50) NOT NULL,
  PropertyID   VARCHAR(50) NULL,
  AgentID      VARCHAR(50) NULL,
  ListDate     DATE NULL,
  Status       VARCHAR(50) NULL,
  AskingPrice  DECIMAL(18,2) NULL,
  Currency     VARCHAR(10) NULL,
  EffectiveFrom DATETIME2 DEFAULT SYSUTCDATETIME(),
  EffectiveTo   DATETIME2 NULL,
  IsActive      BIT DEFAULT 1
);
GO

-- Campaign dimension
IF OBJECT_ID('dwh.DimCampaign','U') IS NULL
CREATE TABLE dwh.DimCampaign (
  CampaignSK   INT IDENTITY(1,1) PRIMARY KEY,
  CampaignID   VARCHAR(50) NOT NULL,
  Channel      VARCHAR(100) NULL,
  StartDate    DATE NULL,
  EndDate      DATE NULL,
  Cost         DECIMAL(18,2) NULL,
  EffectiveFrom DATETIME2 DEFAULT SYSUTCDATETIME(),
  EffectiveTo   DATETIME2 NULL
);
GO

-- Lead dimension (if you want lead attributes)
IF OBJECT_ID('dwh.DimLead','U') IS NULL
CREATE TABLE dwh.DimLead (
  LeadSK       INT IDENTITY(1,1) PRIMARY KEY,
  LeadID       VARCHAR(50) NOT NULL,
  ListingID    VARCHAR(50) NULL,
  Source       VARCHAR(100) NULL,
  LeadScore    INT NULL,
  LeadDate     DATE NULL
);
GO

/********************************************
  DWH FACT TABLES
  - FactTransaction (sales), FactOffer, FactViewing, FactLead
  - Use surrogate keys linking to dims where appropriate
********************************************/

-- Fact: Transactions / Sales
IF OBJECT_ID('dwh.FactTransaction','U') IS NULL
CREATE TABLE dwh.FactTransaction (
  TransactionSK INT IDENTITY(1,1) PRIMARY KEY,
  TransactionID VARCHAR(50) NULL,
  ListingSK     INT NULL,
  PropertySK    INT NULL,
  AgentSK       INT NULL,
  DateSK        INT NULL,      -- link to DimDate (e.g. closing date)
  OfferDateSK   INT NULL,
  SalePrice     DECIMAL(18,2) NULL,
  Currency      VARCHAR(10) NULL,
  CONSTRAINT FK_FactTransaction_ListingSK FOREIGN KEY (ListingSK) REFERENCES dwh.DimListing(ListingSK),
  CONSTRAINT FK_FactTransaction_PropertySK FOREIGN KEY (PropertySK) REFERENCES dwh.DimProperty(PropertySK),
  CONSTRAINT FK_FactTransaction_AgentSK FOREIGN KEY (AgentSK) REFERENCES dwh.DimAgent(AgentSK)
);
GO

-- Fact: Offers (tracking offers)
IF OBJECT_ID('dwh.FactOffer','U') IS NULL
CREATE TABLE dwh.FactOffer (
  OfferSK     INT IDENTITY(1,1) PRIMARY KEY,
  OfferID     VARCHAR(50) NULL,
  ListingSK   INT NULL,
  DateSK      INT NULL,  -- offer date
  OfferPrice  DECIMAL(18,2) NULL,
  OfferStatus VARCHAR(50) NULL,
  CONSTRAINT FK_FactOffer_ListingSK FOREIGN KEY (ListingSK) REFERENCES dwh.DimListing(ListingSK)
);
GO

-- Fact: Viewings
IF OBJECT_ID('dwh.FactViewing','U') IS NULL
CREATE TABLE dwh.FactViewing (
  ViewingSK      INT IDENTITY(1,1) PRIMARY KEY,
  ViewingID      VARCHAR(50) NULL,
  ListingSK      INT NULL,
  DateSK         INT NULL,
  DurationMinutes INT NULL,
  Feedback       VARCHAR(200) NULL,
  CONSTRAINT FK_FactViewing_ListingSK FOREIGN KEY (ListingSK) REFERENCES dwh.DimListing(ListingSK)
);
GO



-- Fact: Leads / Conversions
IF OBJECT_ID('dwh.FactLead','U') IS NULL
CREATE TABLE dwh.FactLead (
  LeadFactSK   INT IDENTITY(1,1) PRIMARY KEY,
  LeadID       VARCHAR(50) NULL,
  ListingSK    INT NULL,
  DateSK       INT NULL,
  Source       VARCHAR(100) NULL,
  LeadScore    INT NULL,
  IsConverted  BIT NULL
);
GO

/********************************************
  Index suggestions (create as needed)
********************************************/
-- Example: index on natural keys for faster lookup during SCD/merge
IF OBJECT_ID('tempdb..#tmp') IS NOT NULL DROP TABLE #tmp;
-- create indexes as needed, e.g. on staging for faster MERGE:
-- CREATE NONCLUSTERED INDEX IX_stg_Listings_ListingID ON stg.Listings(ListingID);
-- CREATE NONCLUSTERED INDEX IX_dwh_DimAgent_AgentID ON dwh.DimAgent(AgentID);

PRINT 'All CREATE TABLE scripts executed (staging + DWH).';
GO





-- Make sure you are connected to the correct database (realestatedatabase)
-- Run the whole script in one batch.

-- 1) Create schema if not exists
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'meta')
BEGIN
    EXEC('CREATE SCHEMA meta');
END;
GO

-- 2) Create mapping table if not exists
IF NOT EXISTS (
    SELECT 1 FROM sys.objects 
    WHERE object_id = OBJECT_ID(N'meta.FileToTable') AND type = 'U'
)
BEGIN
    CREATE TABLE meta.FileToTable (
      FileName     NVARCHAR(200) PRIMARY KEY,
      StagingTable NVARCHAR(200),
      DataFlowName NVARCHAR(200) NULL,
      DWHTable     NVARCHAR(200) NULL
    );
END;
GO

-- 3) Insert mapping rows (safe to re-run - will not insert duplicates)
INSERT INTO meta.FileToTable (FileName, StagingTable, DataFlowName, DWHTable)
SELECT 'Agents.csv','stg.Agents','stgagent_to_Dim_agent','dwh.DimAgent'
WHERE NOT EXISTS (SELECT 1 FROM meta.FileToTable WHERE FileName = 'Agents.csv');

INSERT INTO meta.FileToTable (FileName, StagingTable, DataFlowName, DWHTable)
SELECT 'Campaigns.csv','stg.Campaigns','stgcampaign_to_DimCampaign','dwh.DimCampaign'
WHERE NOT EXISTS (SELECT 1 FROM meta.FileToTable WHERE FileName = 'Campaigns.csv');

INSERT INTO meta.FileToTable (FileName, StagingTable, DataFlowName, DWHTable)
SELECT 'Data_Dictionary.csv','stg.Data_Dictionary',NULL,NULL
WHERE NOT EXISTS (SELECT 1 FROM meta.FileToTable WHERE FileName = 'Data_Dictionary.csv');

INSERT INTO meta.FileToTable (FileName, StagingTable, DataFlowName, DWHTable)
SELECT 'Leads.csv','stg.Leads','stglead_to_DimLead','dwh.DimLead'
WHERE NOT EXISTS (SELECT 1 FROM meta.FileToTable WHERE FileName = 'Leads.csv');

INSERT INTO meta.FileToTable (FileName, StagingTable, DataFlowName, DWHTable)
SELECT 'Listings.csv','stg.Listings','stglisting_to_DimListing','dwh.DimListing'
WHERE NOT EXISTS (SELECT 1 FROM meta.FileToTable WHERE FileName = 'Listings.csv');

INSERT INTO meta.FileToTable (FileName, StagingTable, DataFlowName, DWHTable)
SELECT 'Offers.csv','stg.Offers','stgoffer_to_FactOffer','dwh.FactOffer'
WHERE NOT EXISTS (SELECT 1 FROM meta.FileToTable WHERE FileName = 'Offers.csv');

INSERT INTO meta.FileToTable (FileName, StagingTable, DataFlowName, DWHTable)
SELECT 'Properties.csv','stg.Properties','stgproperty_to_DimProperty','dwh.DimProperty'
WHERE NOT EXISTS (SELECT 1 FROM meta.FileToTable WHERE FileName = 'Properties.csv');

INSERT INTO meta.FileToTable (FileName, StagingTable, DataFlowName, DWHTable)
SELECT 'Transactions.csv','stg.Transactions','stgtransaction_to_FactTrans','dwh.FactTransaction'
WHERE NOT EXISTS (SELECT 1 FROM meta.FileToTable WHERE FileName = 'Transactions.csv');

INSERT INTO meta.FileToTable (FileName, StagingTable, DataFlowName, DWHTable)
SELECT 'Viewings.csv','stg.Viewings','stgviewing_to_FactViewing','dwh.FactViewing'
WHERE NOT EXISTS (SELECT 1 FROM meta.FileToTable WHERE FileName = 'Viewings.csv');
GO

-- Quick check:
SELECT * FROM meta.FileToTable ORDER BY FileName;




CREATE OR ALTER PROCEDURE meta.sp_GetMapping
  @FileName NVARCHAR(200)
AS
BEGIN
  SET NOCOUNT ON;
  SELECT StagingTable, DataFlowName, DWHTable
  FROM meta.FileToTable
  WHERE FileName = @FileName;
END;
GO






CREATE OR ALTER PROCEDURE meta.sp_DQ_StgTable
  @TableName NVARCHAR(200)
AS
BEGIN
  SET NOCOUNT ON;

  DECLARE @sql NVARCHAR(MAX);
  DECLARE @rows INT;
  DECLARE @schema sysname;
  DECLARE @tbl sysname;

  -- split schema and table (works when input is schema.table)
  SET @schema = PARSENAME(@TableName,2);
  SET @tbl = PARSENAME(@TableName,1);

  IF @schema IS NULL OR @tbl IS NULL
  BEGIN
    RAISERROR('TableName must be provided as schema.table',16,1);
    RETURN;
  END

  SET @sql = N'SELECT @r = COUNT(*) FROM ' + QUOTENAME(@schema) + N'.' + QUOTENAME(@tbl);
  EXEC sp_executesql @sql, N'@r INT OUTPUT', @r = @rows OUTPUT;

  IF @rows > 0
    SELECT 'PASS' AS DQStatus, @rows AS RowsChecked;
  ELSE
    SELECT 'FAIL' AS DQStatus, @rows AS RowsChecked;
END;
GO



IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'meta') 
  EXEC('CREATE SCHEMA meta');
GO

IF OBJECT_ID('meta.sp_LogMissingFile','P') IS NOT NULL
  DROP PROCEDURE meta.sp_LogMissingFile;
GO

CREATE PROCEDURE meta.sp_LogMissingFile
  @FileName NVARCHAR(200),
  @ErrorMsg NVARCHAR(1000) = NULL
AS
BEGIN
  SET NOCOUNT ON;

  IF OBJECT_ID('meta.FileImportErrors','U') IS NULL
  BEGIN
    CREATE TABLE meta.FileImportErrors (
      id INT IDENTITY(1,1) PRIMARY KEY,
      FileName NVARCHAR(200),
      ErrorMsg NVARCHAR(1000),
      LoggedAt DATETIME2 DEFAULT SYSUTCDATETIME()
    );
  END

  INSERT INTO meta.FileImportErrors (FileName, ErrorMsg)
  VALUES (@FileName, @ErrorMsg);
END;
GO





CREATE OR ALTER PROCEDURE dwh.usp_LoadDimAgent
AS
BEGIN
    SET NOCOUNT ON;

    -- Insert distinct agents from staging
    INSERT INTO dwh.DimAgent
        (AgentID, AgentName, Region, City, JoinDate, ExperienceYears)
    SELECT DISTINCT
        a.AgentID,
        a.AgentName,
        a.Region,
        a.City,
        a.JoinDate,
        a.ExperienceYears
    FROM stg.Agents a;
END;
GO



-------------------------------------DIM Property-----------------------------------

CREATE OR ALTER PROCEDURE dwh.usp_LoadDimProperty
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dwh.DimProperty
        (PropertyID, Region, City, PropertyType,
         Bedrooms, Bathrooms, AreaSqft, YearBuilt)
    SELECT DISTINCT
        p.PropertyID,
        p.Region,
        p.City,
        p.PropertyType,
        p.Bedrooms,
        p.Bathrooms,
        p.AreaSqft,
        p.YearBuilt
    FROM stg.Properties p;
END;
GO




--------------------------------DIM Listing---------------------------------------
CREATE OR ALTER PROCEDURE dwh.usp_LoadDimListing
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dwh.DimListing
        (ListingID, PropertyID, AgentID,
         ListDate, Status, AskingPrice, Currency)
    SELECT DISTINCT
        l.ListingID,
        l.PropertyID,
        l.AgentID,
        l.ListDate,
        l.Status,
        l.AskingPrice,
        l.Currency
    FROM stg.Listings l;
END;
GO


 -----------------------------DIM Campaigns-------------------------

CREATE OR ALTER PROCEDURE dwh.usp_LoadDimCampaign
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dwh.DimCampaign
        (CampaignID, Channel, StartDate, EndDate, Cost)
    SELECT DISTINCT
        c.CampaignID,
        c.Channel,
        c.StartDate,
        c.EndDate,
        c.Cost
    FROM stg.Campaigns c;
END;
GO


-----------------------DIM Lead------------------------------
CREATE OR ALTER PROCEDURE dwh.usp_LoadDimLead
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dwh.DimLead
        (LeadID, ListingID, Source, LeadScore, LeadDate)
    SELECT DISTINCT
        l.LeadID,
        l.ListingID,
        l.Source,
        l.LeadScore,
        l.LeadDate
    FROM stg.Leads l;
END;
GO

-------------------------------DIM dimdate--------------------

CREATE OR ALTER PROCEDURE dwh.usp_LoadDimDate
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH AllDates AS (
        SELECT DISTINCT ListDate      AS FullDate FROM stg.Listings      WHERE ListDate      IS NOT NULL
        UNION
        SELECT DISTINCT OfferDate     FROM stg.Offers        WHERE OfferDate     IS NOT NULL
        UNION
        SELECT DISTINCT ClosingDate   FROM stg.Transactions  WHERE ClosingDate   IS NOT NULL
        UNION
        SELECT DISTINCT ViewingDate   FROM stg.Viewings      WHERE ViewingDate   IS NOT NULL
        UNION
        SELECT DISTINCT LeadDate      FROM stg.Leads         WHERE LeadDate      IS NOT NULL
    )
    INSERT INTO dwh.DimDate
        (FullDate, YearNum, MonthNum, DayNum, WeekOfYear, Quarter, IsWeekend)
    SELECT
        d.FullDate,
        YEAR(d.FullDate),
        MONTH(d.FullDate),
        DAY(d.FullDate),
        DATEPART(WEEK, d.FullDate),
        DATEPART(QUARTER, d.FullDate),
        CASE WHEN DATENAME(WEEKDAY, d.FullDate) IN ('Saturday','Sunday') THEN 1 ELSE 0 END
    FROM AllDates d;
END;
GO



---Fact Transaction---

CREATE OR ALTER PROCEDURE dwh.usp_LoadFactTransaction
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dwh.FactTransaction
        (TransactionID, ListingSK, PropertySK, AgentSK,
         DateSK, OfferDateSK, SalePrice)
    SELECT
        t.TransactionID,
        dl.ListingSK,
        dp.PropertySK,
        da.AgentSK,
        dd_close.DateKey      AS DateSK,
        dd_offer.DateKey      AS OfferDateSK,
        t.SalePrice
    FROM stg.Transactions t
    LEFT JOIN dwh.DimListing  dl ON dl.ListingID  = t.ListingID
    LEFT JOIN dwh.DimProperty dp ON dp.PropertyID = t.PropertyID
    LEFT JOIN dwh.DimAgent    da ON da.AgentID    = t.AgentID
    LEFT JOIN dwh.DimDate     dd_close ON dd_close.FullDate = t.ClosingDate
    LEFT JOIN dwh.DimDate     dd_offer ON dd_offer.FullDate = t.OfferDate;
END;
GO



--------------------------------------FACT offer-------------------------

CREATE OR ALTER PROCEDURE dwh.usp_LoadFactOffer
AS
BEGIN
    SET NOCOUNT ON;

    TRUNCATE TABLE dwh.FactOffer;

    INSERT INTO dwh.FactOffer
    (
        OfferID,
        ListingSK,
        DateSK,
        OfferPrice,
        OfferStatus
    )
    SELECT
        o.OfferID,
        dl.ListingSK,
        dd.DateKey,
        o.OfferPrice,
        o.OfferStatus
    FROM stg.Offers o
    JOIN dwh.DimListing dl ON dl.ListingID = o.ListingID
    LEFT JOIN dwh.DimDate dd ON dd.FullDate = o.OfferDate;
END;
GO

--------FACT viewing------

CREATE OR ALTER PROCEDURE dwh.usp_LoadFactViewing
AS
BEGIN
    SET NOCOUNT ON;

    TRUNCATE TABLE dwh.FactViewing;

    INSERT INTO dwh.FactViewing
    (
        ViewingID,
        ListingSK,
        DateSK,
        DurationMinutes,
        Feedback
    )
    SELECT
        v.ViewingID,
        dl.ListingSK,
        dd.DateKey,
        v.DurationMinutes,
        v.Feedback
    FROM stg.Viewings v
    JOIN dwh.DimListing dl ON dl.ListingID = v.ListingID
    LEFT JOIN dwh.DimDate dd ON dd.FullDate = v.ViewingDate;
END;
GO


------Fact Lead--------

CREATE OR ALTER PROCEDURE dwh.usp_LoadFactLead
AS
BEGIN
    SET NOCOUNT ON;

    TRUNCATE TABLE dwh.FactLead;

    INSERT INTO dwh.FactLead
    (
        LeadID,
        ListingSK,
        DateSK,
        Source,
        LeadScore,
        IsConverted
    )
    SELECT
        l.LeadID,
        dl.ListingSK,
        dd.DateKey,
        l.Source,
        l.LeadScore,
        CASE WHEN t.TransactionID IS NULL THEN 0 ELSE 1 END AS IsConverted
    FROM stg.Leads l
    JOIN dwh.DimListing dl ON dl.ListingID = l.ListingID
    LEFT JOIN dwh.DimDate dd ON dd.FullDate = l.LeadDate
    LEFT JOIN stg.Transactions t ON t.ListingID = l.ListingID; -- simple conversion logic
END;
GO


------------Master Procedure-------

CREATE OR ALTER PROCEDURE dwh.usp_LoadWarehouse
AS
BEGIN
    SET NOCOUNT ON;

    --------------------------------------------------------
    -- 1. Disable foreign keys on FACT tables
    --------------------------------------------------------
    ALTER TABLE dwh.FactTransaction NOCHECK CONSTRAINT ALL;
    ALTER TABLE dwh.FactOffer       NOCHECK CONSTRAINT ALL;
    ALTER TABLE dwh.FactViewing     NOCHECK CONSTRAINT ALL;
    ALTER TABLE dwh.FactLead        NOCHECK CONSTRAINT ALL;

    --------------------------------------------------------
    -- 2. Delete from FACT tables (to avoid FK issues)
    --------------------------------------------------------
    DELETE FROM dwh.FactTransaction;
    DELETE FROM dwh.FactOffer;
    DELETE FROM dwh.FactViewing;
    DELETE FROM dwh.FactLead;

    --------------------------------------------------------
    -- 3. Delete from DIM tables (full reload, no duplicates)
    --------------------------------------------------------
    DELETE FROM dwh.DimAgent;
    DELETE FROM dwh.DimProperty;
    DELETE FROM dwh.DimListing;
    DELETE FROM dwh.DimCampaign;
    DELETE FROM dwh.DimLead;
    DELETE FROM dwh.DimDate;   -- (optional if you want static dates)

    -- Optional: reseed identities back to 0, so next insert starts at 1
    DBCC CHECKIDENT ('dwh.DimAgent',      RESEED, 0);
    DBCC CHECKIDENT ('dwh.DimProperty',   RESEED, 0);
    DBCC CHECKIDENT ('dwh.DimListing',    RESEED, 0);
    DBCC CHECKIDENT ('dwh.DimCampaign',   RESEED, 0);
    DBCC CHECKIDENT ('dwh.DimLead',       RESEED, 0);
    DBCC CHECKIDENT ('dwh.DimDate',       RESEED, 0);

    DBCC CHECKIDENT ('dwh.FactTransaction', RESEED, 0);
    DBCC CHECKIDENT ('dwh.FactOffer',       RESEED, 0);
    DBCC CHECKIDENT ('dwh.FactViewing',     RESEED, 0);
    DBCC CHECKIDENT ('dwh.FactLead',        RESEED, 0);

    --------------------------------------------------------
    -- 4. Load DIMENSIONS
    --------------------------------------------------------
    EXEC dwh.usp_LoadDimAgent;
    EXEC dwh.usp_LoadDimProperty;
    EXEC dwh.usp_LoadDimListing;
    EXEC dwh.usp_LoadDimCampaign;
    EXEC dwh.usp_LoadDimLead;
    EXEC dwh.usp_LoadDimDate;      

    --------------------------------------------------------
    -- 5. Load FACTS
    --------------------------------------------------------
    EXEC dwh.usp_LoadFactTransaction;
    EXEC dwh.usp_LoadFactOffer;
    EXEC dwh.usp_LoadFactViewing;
    EXEC dwh.usp_LoadFactLead;

    --------------------------------------------------------
    -- 6. Re-enable & validate FKs on FACT tables
    --------------------------------------------------------
    ALTER TABLE dwh.FactTransaction WITH CHECK CHECK CONSTRAINT ALL;
    ALTER TABLE dwh.FactOffer       WITH CHECK CHECK CONSTRAINT ALL;
    ALTER TABLE dwh.FactViewing     WITH CHECK CHECK CONSTRAINT ALL;
    ALTER TABLE dwh.FactLead        WITH CHECK CHECK CONSTRAINT ALL;
END;
GO