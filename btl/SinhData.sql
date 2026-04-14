USE [DW_BanHang];
GO

SET NOCOUNT ON;

-- ============================================================
-- 1. XÓA DỮ LIỆU CŨ (đúng thứ tự FK)
-- ============================================================
DELETE FROM Fact_BanHang;
DELETE FROM Fact_Kho;

DELETE FROM Dim_CuaHang;
DELETE FROM Dim_KhachHang;
DELETE FROM Dim_MatHang;
DELETE FROM Dim_VPDD;
DELETE FROM Dim_ThoiGian;

-- ============================================================
-- 2. DIMENSION: Dim_ThoiGian (thang, quy, nam — chữ thường theo sơ đồ)
-- ============================================================
DECLARE @Nam INT = 2023;
WHILE @Nam <= 2025
BEGIN
    DECLARE @Thang INT = 1;
    WHILE @Thang <= 12
    BEGIN
        INSERT INTO Dim_ThoiGian (thang, quy, nam)
        VALUES (@Thang, ((@Thang - 1) / 3) + 1, @Nam);
        SET @Thang += 1;
    END
    SET @Nam += 1;
END

-- ============================================================
-- 3. DIMENSION: Dim_VPDD (5 thành phố)
-- ============================================================
INSERT INTO Dim_VPDD (MaThanhPho, TenThanhPho, Bang, DiaChi) VALUES
('HCM', N'Hồ Chí Minh', N'Miền Nam',   N'123 Nguyễn Huệ, Q1'),
('HN',  N'Hà Nội',       N'Miền Bắc',   N'45 Hoàn Kiếm, HK'),
('DN',  N'Đà Nẵng',      N'Miền Trung', N'88 Bạch Đằng, Hải Châu'),
('HP',  N'Hải Phòng',    N'Miền Bắc',   N'12 Lê Chân, LP'),
('CT',  N'Cần Thơ',      N'Miền Nam',   N'77 Ninh Kiều, CT');

-- ============================================================
-- 4. DIMENSION: Dim_KhachHang (500 khách hàng)
-- ============================================================
DECLARE @i INT = 1;
WHILE @i <= 500
BEGIN
    INSERT INTO Dim_KhachHang (MaKH, TenKhachHang, MaThanhPho, LoaiKhachHang)
    VALUES (
        'KH' + RIGHT('000' + CAST(@i AS VARCHAR), 3),
        N'Khách hàng ' + CAST(@i AS NVARCHAR),
        (SELECT TOP 1 MaThanhPho FROM Dim_VPDD ORDER BY NEWID()),
        CASE
            WHEN @i % 4 = 1 THEN N'Du lịch'
            WHEN @i % 4 = 2 THEN N'Bưu điện'
            WHEN @i % 4 = 3 THEN N'Du lịch & Bưu điện'
            ELSE                  N'Thường'
        END
    );
    SET @i += 1;
END

-- ============================================================
-- 5. DIMENSION: Dim_MatHang (200 mặt hàng)
-- ============================================================
SET @i = 1;
WHILE @i <= 200
BEGIN
    INSERT INTO Dim_MatHang (MaMH, MoTa, KichCo, TrongLuong, DonGia)
    VALUES (
        'MH' + RIGHT('000' + CAST(@i AS VARCHAR), 3),
        N'Mặt hàng ' + CAST(@i AS NVARCHAR),
        CASE WHEN @i % 3 = 0 THEN N'Lớn' WHEN @i % 3 = 1 THEN N'Vừa' ELSE N'Nhỏ' END,
        RAND(CHECKSUM(NEWID())) * 10,
        CAST(RAND(CHECKSUM(NEWID())) * 990 + 10 AS DECIMAL(18, 2))
    );
    SET @i += 1;
END

-- ============================================================
-- 6. DIMENSION: Dim_CuaHang (50 cửa hàng)
-- ============================================================
SET @i = 1;
WHILE @i <= 50
BEGIN
    DECLARE @maTP VARCHAR(10) = (SELECT TOP 1 MaThanhPho FROM Dim_VPDD ORDER BY NEWID());
    INSERT INTO Dim_CuaHang (MaCuaHang, MaThanhPho, Bang, SDT)
    VALUES (
        'CH' + RIGHT('000' + CAST(@i AS VARCHAR), 3),
        @maTP,
        (SELECT Bang FROM Dim_VPDD WHERE MaThanhPho = @maTP),
        '09' + RIGHT('00000000' + CAST(@i AS VARCHAR), 8)
    );
    SET @i += 1;
END

-- ============================================================
-- 7. FACT: Fact_BanHang
-- Grain: KhachHang × MatHang × ThanhPho × ThoiGian
-- Độ đo: SoLuongBan, DoanhThu
-- ============================================================
;WITH CombinedData AS (
    SELECT
        KH.MaKH,
        MH.MaMH,
        VP.MaThanhPho,
        TG.maThoiGian,
        ABS(CHECKSUM(NEWID())) % 10 + 1                         AS SoLuong,
        MH.DonGia,
        ROW_NUMBER() OVER (ORDER BY NEWID())                    AS rn
    FROM Dim_KhachHang KH
    CROSS JOIN Dim_MatHang  MH
    CROSS JOIN Dim_VPDD     VP
    CROSS JOIN Dim_ThoiGian TG
)
INSERT INTO Fact_BanHang (MaKhachHang, MaMatHang, MaThanhPho, MaThoiGian, SoLuongBan, DoanhThu)
SELECT
    MaKH,
    MaMH,
    MaThanhPho,
    maThoiGian,
    SoLuong,
    SoLuong * DonGia
FROM CombinedData
WHERE rn <= 300000;

-- ============================================================
-- 8. FACT: Fact_Kho
-- Grain: MatHang × CuaHang (snapshot tồn kho — không có chiều thời gian theo sơ đồ)
-- Độ đo: SoLuongTonKho
-- ============================================================
INSERT INTO Fact_Kho (MaMatHang, MaCuaHang, SoLuongTonKho)
SELECT
    MH.MaMH,
    CH.MaCuaHang,
    ABS(CHECKSUM(NEWID())) % 500 + 1 AS SoLuongTonKho
FROM Dim_MatHang MH
CROSS JOIN Dim_CuaHang CH;

-- ============================================================
-- 9. INDEX hỗ trợ truy vấn
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Fact_BanHang_KH')
    CREATE INDEX IX_Fact_BanHang_KH   ON Fact_BanHang (MaKhachHang);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Fact_BanHang_MH')
    CREATE INDEX IX_Fact_BanHang_MH   ON Fact_BanHang (MaMatHang);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Fact_BanHang_TP')
    CREATE INDEX IX_Fact_BanHang_TP   ON Fact_BanHang (MaThanhPho);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Fact_BanHang_TG')
    CREATE INDEX IX_Fact_BanHang_TG   ON Fact_BanHang (MaThoiGian);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Fact_Kho_MH')
    CREATE INDEX IX_Fact_Kho_MH       ON Fact_Kho (MaMatHang);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Fact_Kho_CH')
    CREATE INDEX IX_Fact_Kho_CH       ON Fact_Kho (MaCuaHang);

PRINT N'✅ DONE - Sinh dữ liệu DW_BanHang hoàn tất!';
PRINT N'   Dim_ThoiGian: 36 tháng | Dim_VPDD: 5 | Dim_KhachHang: 500 | Dim_MatHang: 200 | Dim_CuaHang: 50';
PRINT N'   Fact_BanHang: ~300.000 dòng | Fact_Kho: 200x50 = 10.000 dòng';