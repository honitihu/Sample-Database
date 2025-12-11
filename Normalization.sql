/*
   ===========================
   STEP 1: DATABASE CREATION
   ===========================
*/

-- Check if the database already exists before creating it
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = N'HospitalManagement')
BEGIN
    CREATE DATABASE [HospitalManagement];
END
GO

-- Switch the context to the new database
USE [HospitalManagement];
GO

/*
   ========================
   STEP 2: CREATE TABLES
   ========================
*/

-- 1. Patients Table
-- Contains basic patient information
IF OBJECT_ID('dbo.Patients', 'U') IS NOT NULL
    DROP TABLE dbo.Patients;

CREATE TABLE Patients (
    Ma_BN INT PRIMARY KEY NOT NULL,                                -- PK: Mã Bệnh Nhân
    Ho_va_ten NVARCHAR(255) NOT NULL,                              -- Họ và tên
    Nam_sinh INT,                                                  -- Năm sinh
    Phai NVARCHAR(255),                                            -- Phái (Giới tính)
    Dia_chi NVARCHAR(255),                                         -- Địa chỉ
    Dien_thoai NVARCHAR(255),                                      -- Điện thoại
    So_the NVARCHAR(255),                                          -- Số thẻ (Bảo hiểm/Khám bệnh)
    Ma_KCB INT                                                     -- Mã KCB (Mã Cơ Sở Khám Bệnh)
);
GO

-- 2. Staffs Table
-- Create a Surrogate Key as an ID for each unique staff (Người thu, Bác sĩ chỉ định, Bác sĩ thực hiện, Người tiếp nhận)
IF OBJECT_ID('dbo.Staffs', 'U') IS NOT NULL
    DROP TABLE dbo.Staffs;

CREATE TABLE Staffs (
    StaffID INT PRIMARY KEY IDENTITY(1,1) NOT NULL,                 -- PK, Surrogate Key
    StaffName NVARCHAR(255) UNIQUE NOT NULL                        -- Tên nhân viên/bác sĩ
);
GO

-- 3. Services Table
-- Contains details about the medical services/procedures
IF OBJECT_ID('dbo.Services', 'U') IS NOT NULL
    DROP TABLE dbo.Services;

CREATE TABLE Services (
    Ma_DV NVARCHAR(50) PRIMARY KEY NOT NULL,                       -- PK: Mã Dịch Vụ
    Ten_dich_vu NVARCHAR(255) NOT NULL,                            -- Tên dịch vụ
    DVT NVARCHAR(255),                                             -- Đơn vị tính
    Loai_vien_phi NVARCHAR(255),                                   -- Loại viện phí
    Nhom_vien_phi NVARCHAR(255),                                   -- Nhóm viện phí
    Gia_goc INT,                                                   -- Giá gốc
    Gia_mua INT,                                                   -- Giá mua
    Gia_ban INT                                                    -- Giá bán
);
GO

-- 4. Receipts Table
-- Contains core receipt/billing information (shared attributes in the JSON)
IF OBJECT_ID('dbo.Receipts', 'U') IS NOT NULL
    DROP TABLE dbo.Receipts;

CREATE TABLE Receipts (
    So_bien_lai INT PRIMARY KEY NOT NULL,                        -- PK: Số biên lai
    Ngay_thu DATETIME NOT NULL,                                  -- Ngày thu
    Nguoi_thu_ID INT NOT NULL,                                   -- FK to Staffs (Người thu)
    Ngay_vao DATETIME,                                           -- Ngày vào (using DATETIME for better representation than FLOAT)
    Ngay_ra DATETIME,                                            -- Ngày ra (using DATETIME for better representation than FLOAT)

    FOREIGN KEY (Nguoi_thu_ID) REFERENCES Staffs(StaffID)
);
GO

-- 5. Visits Table
-- Creates a Surrogate Key for each Visit entry
-- The central table linking a patient's visit to the staff, diagnosis, and receipts
-- Contains references to Patients, Staffs, and Receipts
IF OBJECT_ID('dbo.Visits', 'U') IS NOT NULL
    DROP TABLE dbo.Visits;

CREATE TABLE Visits (
    VisitID INT PRIMARY KEY IDENTITY(1,1) NOT NULL,                -- PK: Mã Lượt Khám
    Ma_BN INT NOT NULL,                                            -- FK to Patients
    So_bien_lai INT NOT NULL,                                      -- FK to Receipts

    Bac_si_chi_dinh_ID INT,                                        -- FK to Staffs (Bác sĩ chỉ định)
    Bac_si_thuc_hien_ID INT,                                       -- FK to Staffs (Bác sĩ thực hiện)
    Nguoi_tiep_nhan_ID INT,                                        -- FK to Staffs (Người tiếp nhận)
    
    Khoa_phong_chi_dinh NVARCHAR(255),                             -- Khoa phòng chỉ định
    Doi_tuong NVARCHAR(255),                                       -- Đối tượng

    FOREIGN KEY (Ma_BN) REFERENCES Patients(Ma_BN),
    FOREIGN KEY (So_bien_lai) REFERENCES Receipts(So_bien_lai),
    FOREIGN KEY (Bac_si_chi_dinh_ID) REFERENCES Staffs(StaffID),
    FOREIGN KEY (Bac_si_thuc_hien_ID) REFERENCES Staffs(StaffID),
    FOREIGN KEY (Nguoi_tiep_nhan_ID) REFERENCES Staffs(StaffID)
);
GO

-- 6. Diagnosis Table
-- Creates a Surrogate Key for each Diagnosis entry linked to a Visit
-- Contains diagnosis codes and text (linked to a Visit)
IF OBJECT_ID('dbo.Diagnosis', 'U') IS NOT NULL
    DROP TABLE dbo.Diagnosis;

CREATE TABLE Diagnosis (
    DiagnosisID INT PRIMARY KEY IDENTITY(1,1) NOT NULL,             -- PK
    VisitID INT NOT NULL,                                           -- FK to Visits
    Chuan_doan NVARCHAR(255),                                      -- Chẩn đoán chính
    Ma_ICD NVARCHAR(255),                                          -- Mã ICD chính
    Chuan_doan_kem_theo NVARCHAR(255),                              -- Chẩn đoán kèm theo
    Ma_ICD_kem_theo NVARCHAR(255),                                  -- Mã ICD kèm theo
    Xu_tri NVARCHAR(255),                                           -- Xử trí
    
    FOREIGN KEY (VisitID) REFERENCES Visits(VisitID)
);
GO

-- 7. ServiceDetails Table
-- The junction table creates a Surrogate Key linking each Visit to the specific Services received and associated costs
-- Contains the detailed billing information for each service rendered during a visit
IF OBJECT_ID('dbo.ServiceDetails', 'U') IS NOT NULL
    DROP TABLE dbo.ServiceDetails;

CREATE TABLE ServiceDetails (
    DetailID INT PRIMARY KEY IDENTITY(1,1) NOT NULL,               -- PK, Surrogate Key
    VisitID INT NOT NULL,                                          -- FK to Visits
    Ma_DV NVARCHAR(50) NOT NULL,                                   -- FK to Services

    So_bien_lai INT NOT NULL,                                      -- Số biên lai (redundant FK, but useful for quick querying)
    So_luong FLOAT,                                                -- Số lượng (FLOAT suggested by the JSON data)
    So_tien FLOAT,                                                 -- Số tiền
    Thuc_thu FLOAT,                                                -- Thực thu
    Mien_giam FLOAT,                                               -- Miễn/giảm

    FOREIGN KEY (VisitID) REFERENCES Visits(VisitID),
    FOREIGN KEY (Ma_DV) REFERENCES Services(Ma_DV)
);
GO

/*
   =================================================
   STEP 3: INSER DATA INTO THE NORMALIZED TABLES
   =================================================
*/

USE [HospitalManagement];
GO

-- Before inserting, we need to convert OADate to DATETIME
IF OBJECT_ID('dbo.OADateToDatetime') IS NOT NULL DROP FUNCTION dbo.OADateToDatetime;
GO
CREATE FUNCTION dbo.OADateToDatetime (@OADate FLOAT)
RETURNS DATETIME
AS
BEGIN
    RETURN DATEADD(day, CAST(@OADate AS INT), 
                   DATEADD(ms, CAST((@OADate - CAST(@OADate AS INT)) * 1000 * 60 * 60 * 24 AS INT), 
                           '1899-12-30'));
END
GO

-- Load JSON data from file into a variable
DECLARE @json_data NVARCHAR(MAX);
SELECT @json_data = BulkColumn
FROM OPENROWSET(
    BULK N'C:\Users\ASUS\Documents\Hung\Sample-Database\LK T01.23.json', 
    SINGLE_NCLOB) 
    AS j; 

SET @json_data = LTRIM(RTRIM(@json_data));
IF LEFT(@json_data, 1) != '[' AND RIGHT(@json_data, 1) != ']'
BEGIN
    -- If outer brackets are missing, wrap the content to make it a valid JSON array
    SET @json_data = '[' + @json_data + ']';
END

---------------------------------------------
-- PARSE JSON INTO A TEMPORARY STAGING TABLE
---------------------------------------------
IF OBJECT_ID('tempdb..#TempJSONData') IS NOT NULL DROP TABLE #TempJSONData;
IF OBJECT_ID('tempdb..#UniqueStaffNames') IS NOT NULL DROP TABLE #UniqueStaffNames;


SELECT
    -- Patient Details
    j.[Mã BN] AS Ma_BN,
    j.[Họ và tên] AS Ho_va_ten,
    j.[Năm sinh] AS Nam_sinh,
    j.[Phái] AS Phai,
    j.[Địa chỉ] AS Dia_chi,
    j.[Điện thoại] AS Dien_thoai,
    j.[Số thẻ] AS So_the,
    j.[Mã KCB] AS Ma_KCB,

    -- Receipt/Visit Details
    j.[Số biên lai] AS So_bien_lai,
    j.[Ngày thu] AS Ngay_thu_STR,
    dbo.OADateToDatetime(j.[Ngày vào]) AS Ngay_vao_DT, 
    dbo.OADateToDatetime(j.[Ngày ra]) AS Ngay_ra_DT,    
    
    -- Staff Names
    j.[Người thu] AS Nguoi_thu,
    j.[Bác sĩ chỉ định] AS Bac_si_chi_dinh,
    j.[Bác sĩ thực hiện] AS Bac_si_thuc_hien,
    j.[Người tiếp nhận] AS Nguoi_tiep_nhan,

    -- Service Details
    j.[Mã DV] AS Ma_DV,
    j.[Tên dịch vụ] AS Ten_dich_vu,
    j.[ĐVT] AS DVT,
    j.[Loại viện phí] AS Loai_vien_phi,
    j.[Nhóm viện phí] AS Nhom_vien_phi,
    j.[Giá gốc] AS Gia_goc,
    j.[Giá mua] AS Gia_mua,
    j.[Giá bán] AS Gia_ban,

    -- Service Transaction Details
    j.[Số lượng] AS So_luong,
    j.[Số tiền] AS So_tien,
    j.[Thực thu] AS Thuc_thu,
    j.[Miễn/giảm] AS Mien_giam,

    -- Diagnosis Details
    j.[Khoa phòng chỉ định] AS Khoa_phong_chi_dinh,
    j.[Đối tượng] AS Doi_tuong,
    j.[Chẩn đoán] AS Chuan_doan,
    j.[Mã ICD] AS Ma_ICD,
    j.[Chẩn đoán kèm theo] AS Chuan_doan_kem_theo,
    j.[Mã ICD kèm theo] AS Ma_ICD_kem_theo,
    j.[Xử trí] AS Xu_tri
INTO #TempJSONData
FROM OPENJSON(@json_data, N'$')
WITH (
    -- Column Definitions
    [Mã BN]                 INT                 N'$."Mã BN"',
    [Họ và tên]             NVARCHAR(255)       N'$."Họ và tên"',
    [Năm sinh]              INT                 N'$."Năm sinh"',
    [Phái]                  NVARCHAR(255)       N'$."Phái"',
    [Địa chỉ]               NVARCHAR(255)       N'$."Địa chỉ"',
    [Điện thoại]            NVARCHAR(255)       N'$."Điện thoại"',
    [Số thẻ]                NVARCHAR(255)       N'$."Số thẻ"',
    [Mã KCB]                INT                 N'$."Mã KCB"',
    [Số biên lai]           INT                 N'$."Số biên lai"',
    [Ngày thu]              NVARCHAR(255)       N'$."Ngày thu"',
    [Ngày vào]              FLOAT               N'$."Ngày vào"', 
    [Ngày ra]               FLOAT               N'$."Ngày ra"', 
    [Người thu]             NVARCHAR(255)       N'$."Người thu"',
    [Bác sĩ chỉ định]       NVARCHAR(255)       N'$."Bác sĩ chỉ định"',
    [Bác sĩ thực hiện]      NVARCHAR(255)       N'$."Bác sĩ thực hiện"',
    [Người tiếp nhận]       NVARCHAR(255)       N'$."Người tiếp nhận"',
    [Mã DV]                 NVARCHAR(50)        N'$."Mã DV"',
    [Tên dịch vụ]           NVARCHAR(255)       N'$."Tên dịch vụ"',
    [ĐVT]                   NVARCHAR(255)       N'$."ĐVT"',
    [Loại viện phí]         NVARCHAR(255)       N'$."Loại viện phí"',
    [Nhóm viện phí]         NVARCHAR(255)       N'$."Nhóm viện phí"',
    [Giá gốc]               INT                 N'$."Giá gốc"',
    [Giá mua]               INT                 N'$."Giá mua"',
    [Giá bán]               INT                 N'$."Giá bán"',
    [Số lượng]              FLOAT               N'$."Số lượng"',
    [Số tiền]               FLOAT               N'$."Số tiền"',
    [Thực thu]              FLOAT               N'$."Thực thu"',
    [Miễn/giảm]             FLOAT               N'$."Miễn\/giảm"',
    [Khoa phòng chỉ định]   NVARCHAR(255)       N'$."Khoa phòng chỉ định"',
    [Đối tượng]             NVARCHAR(255)       N'$."Đối tượng"',
    [Chẩn đoán]             NVARCHAR(255)       N'$."Chẩn đoán"',
    [Mã ICD]                NVARCHAR(255)       N'$."Mã ICD"',
    [Chẩn đoán kèm theo]    NVARCHAR(255)       N'$."Chẩn đoán kèm theo"',
    [Mã ICD kèm theo]       NVARCHAR(255)       N'$."Mã ICD kèm theo"',
    [Xử trí]                NVARCHAR(255)       N'$."Xử trí"'
) AS j;

-------------------------------
-- INSERT/UPDATE STATIC TABLES 
-------------------------------

-- A. Insert Unique Staffs 
SELECT DISTINCT StaffName
INTO #UniqueStaffNames
FROM (
    SELECT Nguoi_thu AS StaffName FROM #TempJSONData WHERE Nguoi_thu IS NOT NULL
    UNION
    SELECT Bac_si_chi_dinh FROM #TempJSONData WHERE Bac_si_chi_dinh IS NOT NULL
    UNION
    SELECT Bac_si_thuc_hien FROM #TempJSONData WHERE Bac_si_thuc_hien IS NOT NULL
    UNION
    SELECT Nguoi_tiep_nhan FROM #TempJSONData WHERE Nguoi_tiep_nhan IS NOT NULL
) AS AllStaffNames
EXCEPT
SELECT StaffName FROM Staffs;

INSERT INTO Staffs (StaffName)
SELECT StaffName FROM #UniqueStaffNames;

-- B. Insert unique Services
INSERT INTO Services (Ma_DV, Ten_dich_vu, DVT, Loai_vien_phi, Nhom_vien_phi, Gia_goc, Gia_mua, Gia_ban)
SELECT DISTINCT 
    Ma_DV, Ten_dich_vu, DVT, Loai_vien_phi, Nhom_vien_phi, Gia_goc, Gia_mua, Gia_ban
FROM #TempJSONData
WHERE Ma_DV IS NOT NULL
EXCEPT 
SELECT 
    Ma_DV, Ten_dich_vu, DVT, Loai_vien_phi, Nhom_vien_phi, Gia_goc, Gia_mua, Gia_ban
FROM Services;

-- C. Insert unique Patients
MERGE INTO Patients AS Target
USING (
    SELECT DISTINCT Ma_BN, Ho_va_ten, Nam_sinh, Phai, Dia_chi, Dien_thoai, So_the, Ma_KCB
    FROM #TempJSONData
    WHERE Ma_BN IS NOT NULL
) AS Source
ON (Target.Ma_BN = Source.Ma_BN)
WHEN NOT MATCHED THEN
    INSERT (Ma_BN, Ho_va_ten, Nam_sinh, Phai, Dia_chi, Dien_thoai, So_the, Ma_KCB)
    VALUES (Source.Ma_BN, Source.Ho_va_ten, Source.Nam_sinh, Source.Phai, Source.Dia_chi, Source.Dien_thoai, Source.So_the, Source.Ma_KCB);


------------------------------
-- INSERT TRANSACTIONAL DATA 
------------------------------

-- D. INSERT INTO RECEIPTS TABLE
MERGE INTO Receipts AS Target
USING (
    SELECT DISTINCT 
        t.So_bien_lai,
        CAST(t.Ngay_thu_STR AS DATETIME) AS Ngay_thu,
        s.StaffID AS Nguoi_thu_ID, -- *** LOOKUP: Join to get StaffID ***
        t.Ngay_vao_DT AS Ngay_vao,
        t.Ngay_ra_DT AS Ngay_ra
    FROM #TempJSONData t
    -- JOIN on Staffs table to get the ID for the 'Người thu'
    INNER JOIN Staffs s ON t.Nguoi_thu = s.StaffName
    WHERE t.So_bien_lai IS NOT NULL
) AS Source
ON (Target.So_bien_lai = Source.So_bien_lai)
WHEN NOT MATCHED THEN
    INSERT (So_bien_lai, Ngay_thu, Nguoi_thu_ID, Ngay_vao, Ngay_ra)
    VALUES (Source.So_bien_lai, Source.Ngay_thu, Source.Nguoi_thu_ID, Source.Ngay_vao, Source.Ngay_ra);

-- E. INSERT INTO VISITS TABLE (using multiple JOINS for Staff IDs)
INSERT INTO Visits (Ma_BN, So_bien_lai, Bac_si_chi_dinh_ID, Bac_si_thuc_hien_ID, Nguoi_tiep_nhan_ID, Khoa_phong_chi_dinh, Doi_tuong)
SELECT DISTINCT
    t.Ma_BN,
    t.So_bien_lai,
    s_cd.StaffID AS Bac_si_chi_dinh_ID,    -- Lookup 1: Bs Chỉ Định ID
    s_th.StaffID AS Bac_si_thuc_hien_ID,   -- Lookup 2: Bs Thực Hiện ID
    s_tn.StaffID AS Nguoi_tiep_nhan_ID,    -- Lookup 3: Người Tiếp Nhận ID
    t.Khoa_phong_chi_dinh,
    t.Doi_tuong
FROM #TempJSONData t
-- Lookup for Bac_si_chi_dinh
INNER JOIN Staffs s_cd ON t.Bac_si_chi_dinh = s_cd.StaffName
-- Lookup for Bac_si_thuc_hien (Use LEFT JOIN if this column can be NULL)
LEFT JOIN Staffs s_th ON t.Bac_si_thuc_hien = s_th.StaffName
-- Lookup for Nguoi_tiep_nhan
INNER JOIN Staffs s_tn ON t.Nguoi_tiep_nhan = s_tn.StaffName
WHERE t.Ma_BN IS NOT NULL AND t.So_bien_lai IS NOT NULL
EXCEPT 
SELECT 
    v.Ma_BN, v.So_bien_lai, v.Bac_si_chi_dinh_ID, v.Bac_si_thuc_hien_ID, v.Nguoi_tiep_nhan_ID, v.Khoa_phong_chi_dinh, v.Doi_tuong
FROM Visits v;

-- F. Insert Diagnosis 
INSERT INTO Diagnosis (VisitID, Chuan_doan, Ma_ICD, Chuan_doan_kem_theo, Ma_ICD_kem_theo, Xu_tri)
SELECT DISTINCT
    v.VisitID,
    t.Chuan_doan,
    t.Ma_ICD,
    t.Chuan_doan_kem_theo,
    t.Ma_ICD_kem_theo,
    t.Xu_tri
FROM #TempJSONData t
INNER JOIN Visits v ON t.Ma_BN = v.Ma_BN AND t.So_bien_lai = v.So_bien_lai
EXCEPT 
SELECT 
    d.VisitID, d.Chuan_doan, d.Ma_ICD, d.Chuan_doan_kem_theo, d.Ma_ICD_kem_theo, d.Xu_tri
FROM Diagnosis d
INNER JOIN Visits v ON d.VisitID = v.VisitID
INNER JOIN #TempJSONData t ON v.Ma_BN = t.Ma_BN AND v.So_bien_lai = t.So_bien_lai;

-- G. Insert ServiceDetails 
INSERT INTO ServiceDetails (VisitID, Ma_DV, So_bien_lai, So_luong, So_tien, Thuc_thu, Mien_giam)
SELECT 
    v.VisitID,
    t.Ma_DV,
    t.So_bien_lai,
    t.So_luong,
    t.So_tien,
    t.Thuc_thu,
    ISNULL(t.Mien_giam, 0)
FROM #TempJSONData t
INNER JOIN Visits v ON t.Ma_BN = v.Ma_BN AND t.So_bien_lai = v.So_bien_lai
WHERE t.Ma_DV IS NOT NULL
EXCEPT 
SELECT 
    sd.VisitID, sd.Ma_DV, sd.So_bien_lai, sd.So_luong, sd.So_tien, sd.Thuc_thu, sd.Mien_giam
FROM ServiceDetails sd
INNER JOIN Visits v ON sd.VisitID = v.VisitID
INNER JOIN #TempJSONData t ON v.Ma_BN = t.Ma_BN AND v.So_bien_lai = t.So_bien_lai;

-- VERIFY INSERTIONS BY COUNTING ROWS IN EACH TABLE

SELECT 'Patients' AS TableName, COUNT(*) AS RowsCount
FROM dbo.Patients;

SELECT 'Staffs' AS TableName, COUNT(*) AS RowsCount
FROM dbo.Staffs;

SELECT 'Services' AS TableName, COUNT(*) AS RowsCount
FROM dbo.Services;

SELECT 'Receipts' AS TableName, COUNT(*) AS RowsCount
FROM dbo.Receipts;

SELECT 'Visits' AS TableName, COUNT(*) AS RowsCount
FROM dbo.Visits;

SELECT 'ServiceDetails' AS TableName, COUNT(*) AS RowsCount
FROM dbo.ServiceDetails;

SELECT 'Diagnosis' AS TableName, COUNT(*) AS RowsCount
FROM dbo.Diagnosis;

SELECT TOP (10) *
FROM #TempJSONData;

SELECT 
    COUNT(*)                               AS TotalRows,
    COUNT(Ma_BN)                           AS NonNull_Ma_BN,
    COUNT(Ma_DV)                           AS NonNull_Ma_DV,
    COUNT(So_bien_lai)                     AS NonNull_So_bien_lai,
    COUNT(Nguoi_thu)                       AS NonNull_Nguoi_thu,
    COUNT(Bac_si_chi_dinh)                 AS NonNull_Bac_si_chi_dinh,
    COUNT(Bac_si_thuc_hien)                AS NonNull_Bac_si_thuc_hien,
    COUNT(Nguoi_tiep_nhan)                 AS NonNull_Nguoi_tiep_nhan
FROM #TempJSONData;

-- Cleanup
DROP TABLE #TempJSONData;
DROP TABLE #UniqueStaffNames;
GO