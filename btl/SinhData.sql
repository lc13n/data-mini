USE [DW_BanHang];
GO

SET NOCOUNT ON;

-- ========================
-- 1. DELETE DATA (ĐÚNG THỨ TỰ FK)
-- ========================

DELETE FROM Fact_BanHang;
DELETE FROM Fact_Kho;

DELETE FROM Dim_CuaHang;
DELETE FROM Dim_KhachHang;
DELETE FROM Dim_MatHang;
DELETE FROM Dim_VPDD;
DELETE FROM Dim_ThoiGian;

-- ========================
-- 2. INSERT DIMENSION
-- ========================

-- Dim_ThoiGian
DECLARE @Nam INT = 2023;
WHILE @Nam <= 2025
BEGIN
    DECLARE @Thang INT = 1;
    WHILE @Thang <= 12
    BEGIN
        INSERT INTO Dim_ThoiGian(Thang, Quy, Nam)
        VALUES (@Thang, ((@Thang-1)/3)+1, @Nam);

        SET @Thang += 1;
    END
    SET @Nam += 1;
END

-- Dim_VPDD
INSERT INTO Dim_VPDD VALUES
('HCM', N'Hồ Chí Minh', N'Miền Nam', N'Q1'),
('HN', N'Hà Nội', N'Miền Bắc', N'Hoàn Kiếm'),
('DN', N'Đà Nẵng', N'Miền Trung', N'Hải Châu'),
('HP', N'Hải Phòng', N'Miền Bắc', N'Lê Chân'),
('CT', N'Cần Thơ', N'Miền Nam', N'Ninh Kiều');

-- Dim_KhachHang
DECLARE @i INT = 1;
WHILE @i <= 500
BEGIN
    INSERT INTO Dim_KhachHang
    VALUES (
        'KH' + RIGHT('000'+CAST(@i AS VARCHAR),3),
        N'Khách hàng ' + CAST(@i AS NVARCHAR),
        (SELECT TOP 1 MaThanhPho FROM Dim_VPDD ORDER BY NEWID()),
        CASE WHEN @i%2=0 THEN N'VIP' ELSE N'Thường' END
    );
    SET @i += 1;
END

-- Dim_MatHang (FIX RAND)
SET @i = 1;
WHILE @i <= 200
BEGIN
    INSERT INTO Dim_MatHang
    VALUES (
        'MH' + RIGHT('000'+CAST(@i AS VARCHAR),3),
        N'Mặt hàng ' + CAST(@i AS NVARCHAR),
        CASE WHEN @i%3=0 THEN N'Lớn' ELSE N'Nhỏ' END,
        RAND(CHECKSUM(NEWID())) * 10,
        RAND(CHECKSUM(NEWID())) * 1000 + 10
    );
    SET @i += 1;
END

-- Dim_CuaHang
SET @i = 1;
WHILE @i <= 50
BEGIN
    INSERT INTO Dim_CuaHang
    VALUES (
        'CH' + RIGHT('000'+CAST(@i AS VARCHAR),3),
        (SELECT TOP 1 MaThanhPho FROM Dim_VPDD ORDER BY NEWID()),
        N'Bang ' + CAST(@i AS NVARCHAR),
        '09' + RIGHT('00000000'+CAST(@i AS VARCHAR),8)
    );
    SET @i += 1;
END

-- ========================
-- 3. INSERT FACT (KHÔNG TRÙNG PK)
-- ========================

-- Fact_BanHang (~300k)
;WITH Data AS (
    SELECT 
        KH.MaKH,
        MH.MaMH,
        TG.TimeKey,
        ABS(CHECKSUM(NEWID())) % 10 + 1 AS SoLuong,
        ROW_NUMBER() OVER (ORDER BY NEWID()) AS rn
    FROM Dim_KhachHang KH
    CROSS JOIN Dim_MatHang MH
    CROSS JOIN Dim_ThoiGian TG
)
INSERT INTO Fact_BanHang
SELECT 
    Data.MaKH,
    Data.MaMH,        -- ✅ fix
    Data.TimeKey,
    Data.SoLuong,
    Data.SoLuong * MH.DonGia
FROM Data
JOIN Dim_MatHang MH ON Data.MaMH = MH.MaMH
WHERE Data.rn <= 300000;

-- Fact_Kho (~200k)
;WITH Data AS (
    SELECT 
        MH.MaMH,
        CH.MaCuaHang,
        TG.TimeKey,
        ABS(CHECKSUM(NEWID())) % 500 AS SoLuongTonKho,
        ROW_NUMBER() OVER (ORDER BY NEWID()) AS rn
    FROM Dim_MatHang MH
    CROSS JOIN Dim_CuaHang CH
    CROSS JOIN Dim_ThoiGian TG
)
INSERT INTO Fact_Kho
SELECT 
    MaMH,
    MaCuaHang,
    TimeKey,
    SoLuongTonKho
FROM Data
WHERE rn <= 200000;

-- ========================
-- 4. INDEX (KHÔNG BỊ LỖI KHI CHẠY LẠI)
-- ========================

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Fact_BanHang_Time')
    CREATE INDEX IX_Fact_BanHang_Time ON Fact_BanHang(TimeKey);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Fact_Kho_Time')
    CREATE INDEX IX_Fact_Kho_Time ON Fact_Kho(TimeKey);

PRINT N'✅ DONE - Data Warehouse đã sẵn sàng!';