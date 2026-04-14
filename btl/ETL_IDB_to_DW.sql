-- ============================================================
-- ETL: Chuyển dữ liệu từ csdl_banhang → DW_BanHang
-- Theo schema mới từ image2.png:
--   Dim_ThoiGian: maThoiGian, thang, quy, nam
--   Fact_BanHang: MaKhachHang, MaMatHang, MaThanhPho, MaThoiGian, SoLuongBan, DoanhThu
--   Fact_Kho:     MaMatHang, MaCuaHang, SoLuongTonKho (không có chiều thời gian)
-- ============================================================
USE DW_BanHang;
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

PRINT N'[1/7] Đã xóa dữ liệu cũ trong DW';

-- ============================================================
-- 2. NẠP Dim_ThoiGian
-- Sinh tháng từ ngày đặt hàng sớm nhất đến hiện tại
-- ============================================================
DECLARE @minDate DATE = (
    SELECT MIN(CAST(NgayDatHang AS DATE)) FROM csdl_banhang.dbo.DonDatHang
);
DECLARE @maxDate DATE = GETDATE();
DECLARE @d DATE = DATEFROMPARTS(YEAR(@minDate), MONTH(@minDate), 1);

WHILE @d <= @maxDate
BEGIN
    INSERT INTO Dim_ThoiGian (thang, quy, nam)
    VALUES (MONTH(@d), (MONTH(@d) - 1) / 3 + 1, YEAR(@d));
    SET @d = DATEADD(MONTH, 1, @d);
END

PRINT N'[2/7] Đã nạp Dim_ThoiGian: ' + CAST(@@ROWCOUNT AS VARCHAR) + N' bản ghi';

-- ============================================================
-- 3. NẠP Dim_VPDD
-- ============================================================
INSERT INTO Dim_VPDD (MaThanhPho, TenThanhPho, Bang, DiaChi)
SELECT MaThanhPho, TenThanhPho, Bang, DiaChiVP
FROM csdl_banhang.dbo.VanPhongDaiDien;

PRINT N'[3/7] Đã nạp Dim_VPDD: ' + CAST(@@ROWCOUNT AS VARCHAR) + N' bản ghi';

-- ============================================================
-- 4. NẠP Dim_KhachHang
-- Kết hợp KhachHang + KhachHangDuLich + KhachHangBuuDien → LoaiKhachHang
-- ============================================================
INSERT INTO Dim_KhachHang (MaKH, TenKhachHang, MaThanhPho, LoaiKhachHang)
SELECT
    kh.MaKH,
    kh.TenKH,
    kh.MaThanhPhoKhachHang,
    CASE
        WHEN dl.MaKH IS NOT NULL AND bd.MaKH IS NOT NULL THEN N'Du lịch & Bưu điện'
        WHEN dl.MaKH IS NOT NULL                         THEN N'Du lịch'
        WHEN bd.MaKH IS NOT NULL                         THEN N'Bưu điện'
        ELSE                                                  N'Thường'
    END AS LoaiKhachHang
FROM csdl_banhang.dbo.KhachHang kh
LEFT JOIN csdl_banhang.dbo.KhachHangDuLich  dl ON kh.MaKH = dl.MaKH
LEFT JOIN csdl_banhang.dbo.KhachHangBuuDien bd ON kh.MaKH = bd.MaKH;

PRINT N'[4/7] Đã nạp Dim_KhachHang: ' + CAST(@@ROWCOUNT AS VARCHAR) + N' bản ghi';

-- ============================================================
-- 5. NẠP Dim_MatHang
-- ============================================================
INSERT INTO Dim_MatHang (MaMH, MoTa, KichCo, TrongLuong, DonGia)
SELECT MaMH, MoTa, KichCo, TrongLuong, DonGia
FROM csdl_banhang.dbo.MatHang;

PRINT N'[5/7] Đã nạp Dim_MatHang: ' + CAST(@@ROWCOUNT AS VARCHAR) + N' bản ghi';

-- ============================================================
-- 6. NẠP Dim_CuaHang
-- ============================================================
INSERT INTO Dim_CuaHang (MaCuaHang, MaThanhPho, Bang, SDT)
SELECT
    ch.MaCuaHang,
    ch.MaThanhPhoVanPhong,
    vp.Bang,
    ch.SoDienThoai
FROM csdl_banhang.dbo.CuaHang ch
JOIN csdl_banhang.dbo.VanPhongDaiDien vp ON ch.MaThanhPhoVanPhong = vp.MaThanhPho;

PRINT N'[6/7] Đã nạp Dim_CuaHang: ' + CAST(@@ROWCOUNT AS VARCHAR) + N' bản ghi';

-- ============================================================
-- 7. NẠP Fact_BanHang
-- Grain: KhachHang × MatHang × ThanhPho(KH) × ThoiGian(tháng đặt)
-- MaThanhPho lấy từ thành phố của khách hàng → Dim_VPDD
-- ============================================================
INSERT INTO Fact_BanHang (MaKhachHang, MaMatHang, MaThanhPho, MaThoiGian, SoLuongBan, DoanhThu)
SELECT
    ddh.MaKhachHang,
    mhd.MaMatHang,
    kh.MaThanhPho,                             -- Thành phố khách hàng → Dim_VPDD
    tg.maThoiGian,
    SUM(mhd.SoLuongDat)                        AS SoLuongBan,
    SUM(mhd.SoLuongDat * mhd.GiaDat)          AS DoanhThu
FROM csdl_banhang.dbo.DonDatHang ddh
JOIN csdl_banhang.dbo.MatHangDuocDat  mhd ON ddh.MaDon          = mhd.MaDon
JOIN Dim_KhachHang                    kh  ON ddh.MaKhachHang     = kh.MaKH
JOIN Dim_ThoiGian                     tg  ON tg.thang = MONTH(ddh.NgayDatHang)
                                          AND tg.nam   = YEAR(ddh.NgayDatHang)
GROUP BY ddh.MaKhachHang, mhd.MaMatHang, kh.MaThanhPho, tg.maThoiGian;

PRINT N'[7/7] Đã nạp Fact_BanHang: ' + CAST(@@ROWCOUNT AS VARCHAR) + N' bản ghi';

-- ============================================================
-- 8. NẠP Fact_Kho
-- Grain: MatHang × CuaHang (snapshot tồn kho mới nhất)
-- Không có chiều thời gian theo sơ đồ image2.png
-- ============================================================
INSERT INTO Fact_Kho (MaMatHang, MaCuaHang, SoLuongTonKho)
SELECT
    MaMatHang,
    MaCuaHang,
    SoLuongTrongKho
FROM (
    SELECT
        MaMatHang,
        MaCuaHang,
        SoLuongTrongKho,
        ROW_NUMBER() OVER (
            PARTITION BY MaMatHang, MaCuaHang
            ORDER BY ThoiGianCapNhatNhapKho DESC  -- Lấy snapshot mới nhất
        ) AS rn
    FROM csdl_banhang.dbo.MatHang_DuocLuuTru
) t
WHERE rn = 1;

PRINT N'[8/8] Đã nạp Fact_Kho: ' + CAST(@@ROWCOUNT AS VARCHAR) + N' bản ghi';

-- ============================================================
-- 9. INDEX
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Fact_BanHang_KH')
    CREATE INDEX IX_Fact_BanHang_KH  ON Fact_BanHang (MaKhachHang);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Fact_BanHang_MH')
    CREATE INDEX IX_Fact_BanHang_MH  ON Fact_BanHang (MaMatHang);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Fact_BanHang_TP')
    CREATE INDEX IX_Fact_BanHang_TP  ON Fact_BanHang (MaThanhPho);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Fact_BanHang_TG')
    CREATE INDEX IX_Fact_BanHang_TG  ON Fact_BanHang (MaThoiGian);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Fact_Kho_MH')
    CREATE INDEX IX_Fact_Kho_MH      ON Fact_Kho (MaMatHang);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Fact_Kho_CH')
    CREATE INDEX IX_Fact_Kho_CH      ON Fact_Kho (MaCuaHang);

PRINT N'✅ ETL HOÀN TẤT - DW_BanHang đã được nạp đầy đủ từ csdl_banhang!';
