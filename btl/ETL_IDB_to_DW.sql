-- ============================================================
-- ETL: Chuyển dữ liệu từ csdl_banhang → DW_BanHang
-- Thực hiện sau khi đã chạy taoBang.sql và SinhData_IDB.sql
-- ============================================================
USE DW_BanHang;
GO

SET NOCOUNT ON;

-- ========================
-- 1. XÓA DỮ LIỆU CŨ TRONG DW (đúng thứ tự FK)
-- ========================
DELETE FROM Fact_BanHang;
DELETE FROM Fact_Kho;
DELETE FROM Dim_CuaHang;
DELETE FROM Dim_KhachHang;
DELETE FROM Dim_MatHang;
DELETE FROM Dim_VPDD;
DELETE FROM Dim_ThoiGian;

PRINT N'[1/6] Đã xóa dữ liệu cũ trong DW';

-- ========================
-- 2. NẠP Dim_ThoiGian
-- Lấy tất cả tháng từ ngày đặt hàng sớm nhất đến hiện tại
-- ========================
DECLARE @minDate DATE = (
    SELECT MIN(CAST(NgayDatHang AS DATE)) FROM csdl_banhang.dbo.DonDatHang
);
DECLARE @maxDate DATE = GETDATE();
DECLARE @d DATE = DATEFROMPARTS(YEAR(@minDate), MONTH(@minDate), 1);

WHILE @d <= @maxDate
BEGIN
    INSERT INTO Dim_ThoiGian (Thang, Quy, Nam)
    VALUES (MONTH(@d), (MONTH(@d)-1)/3+1, YEAR(@d));
    SET @d = DATEADD(MONTH, 1, @d);
END

PRINT N'[2/6] Đã nạp Dim_ThoiGian: ' + CAST(@@ROWCOUNT AS VARCHAR) + N' bản ghi';

-- ========================
-- 3. NẠP Dim_VPDD
-- Ánh xạ từ VanPhongDaiDien
-- ========================
INSERT INTO Dim_VPDD (MaThanhPho, TenThanhPho, Bang, DiaChi)
SELECT
    MaThanhPho,
    TenThanhPho,
    Bang,
    DiaChiVP
FROM csdl_banhang.dbo.VanPhongDaiDien;

PRINT N'[3/6] Đã nạp Dim_VPDD: ' + CAST(@@ROWCOUNT AS VARCHAR) + N' bản ghi';

-- ========================
-- 4. NẠP Dim_KhachHang
-- Kết hợp KhachHang + KhachHangDuLich + KhachHangBuuDien để xác định LoaiKhachHang
-- ========================
INSERT INTO Dim_KhachHang (MaKH, TenKhachHang, MaThanhPho, LoaiKhachHang)
SELECT
    kh.MaKH,
    kh.TenKH,
    kh.MaThanhPhoKhachHang,
    CASE
        WHEN dl.MaKH IS NOT NULL AND bd.MaKH IS NOT NULL THEN N'Du lịch & Bưu điện'
        WHEN dl.MaKH IS NOT NULL                         THEN N'Du lịch'
        WHEN bd.MaKH IS NOT NULL                         THEN N'Bưu điện'
        ELSE N'Thường'
    END AS LoaiKhachHang
FROM csdl_banhang.dbo.KhachHang kh
LEFT JOIN csdl_banhang.dbo.KhachHangDuLich dl ON kh.MaKH = dl.MaKH
LEFT JOIN csdl_banhang.dbo.KhachHangBuuDien bd ON kh.MaKH = bd.MaKH;

PRINT N'[4/6] Đã nạp Dim_KhachHang: ' + CAST(@@ROWCOUNT AS VARCHAR) + N' bản ghi';

-- ========================
-- 5. NẠP Dim_MatHang
-- ========================
INSERT INTO Dim_MatHang (MaMH, MoTa, KichCo, TrongLuong, DonGia)
SELECT MaMH, MoTa, KichCo, TrongLuong, DonGia
FROM csdl_banhang.dbo.MatHang;

PRINT N'[5/6] Đã nạp Dim_MatHang: ' + CAST(@@ROWCOUNT AS VARCHAR) + N' bản ghi';

-- ========================
-- 6. NẠP Dim_CuaHang
-- ========================
INSERT INTO Dim_CuaHang (MaCuaHang, MaThanhPho, Bang, SDT)
SELECT
    ch.MaCuaHang,
    ch.MaThanhPhoVanPhong,
    vp.Bang,
    ch.SoDienThoai
FROM csdl_banhang.dbo.CuaHang ch
JOIN csdl_banhang.dbo.VanPhongDaiDien vp ON ch.MaThanhPhoVanPhong = vp.MaThanhPho;

PRINT N'[6/6] Đã nạp Dim_CuaHang: ' + CAST(@@ROWCOUNT AS VARCHAR) + N' bản ghi';

-- ========================
-- 7. NẠP Fact_BanHang
-- Nguồn: DonDatHang × MatHangDuocDat
-- Độ đo: SoLuongBan, DoanhThu
-- ========================
INSERT INTO Fact_BanHang (MaKhachHang, MaMatHang, TimeKey, SoLuongBan, DoanhThu)
SELECT
    ddh.MaKhachHang,
    mhd.MaMatHang,
    tg.TimeKey,
    SUM(mhd.SoLuongDat)                          AS SoLuongBan,
    SUM(mhd.SoLuongDat * mhd.GiaDat)             AS DoanhThu
FROM csdl_banhang.dbo.DonDatHang ddh
JOIN csdl_banhang.dbo.MatHangDuocDat mhd ON ddh.MaDon = mhd.MaDon
JOIN Dim_ThoiGian tg
    ON tg.Thang = MONTH(ddh.NgayDatHang)
    AND tg.Nam  = YEAR(ddh.NgayDatHang)
GROUP BY ddh.MaKhachHang, mhd.MaMatHang, tg.TimeKey;

PRINT N'[7/7] Đã nạp Fact_BanHang: ' + CAST(@@ROWCOUNT AS VARCHAR) + N' bản ghi';

-- ========================
-- 8. NẠP Fact_Kho
-- Nguồn: MatHang_DuocLuuTru
-- Độ đo: SoLuongTonKho (snapshot theo tháng cập nhật)
-- ========================
INSERT INTO Fact_Kho (MaMatHang, MaCuaHang, TimeKey, SoLuongTonKho)
SELECT
    kho.MaMatHang,
    kho.MaCuaHang,
    tg.TimeKey,
    kho.SoLuongTrongKho
FROM csdl_banhang.dbo.MatHang_DuocLuuTru kho
JOIN Dim_ThoiGian tg
    ON tg.Thang = MONTH(kho.ThoiGianCapNhatNhapKho)
    AND tg.Nam  = YEAR(kho.ThoiGianCapNhatNhapKho);

PRINT N'[8/8] Đã nạp Fact_Kho: ' + CAST(@@ROWCOUNT AS VARCHAR) + N' bản ghi';

-- ========================
-- 9. TẠO INDEX (nếu chưa có)
-- ========================
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Fact_BanHang_Time')
    CREATE INDEX IX_Fact_BanHang_Time   ON Fact_BanHang(TimeKey);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Fact_BanHang_KH')
    CREATE INDEX IX_Fact_BanHang_KH     ON Fact_BanHang(MaKhachHang);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Fact_BanHang_MH')
    CREATE INDEX IX_Fact_BanHang_MH     ON Fact_BanHang(MaMatHang);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Fact_Kho_Time')
    CREATE INDEX IX_Fact_Kho_Time       ON Fact_Kho(TimeKey);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Fact_Kho_CH')
    CREATE INDEX IX_Fact_Kho_CH         ON Fact_Kho(MaCuaHang);

PRINT N'✅ ETL HOÀN TẤT - DW_BanHang đã được nạp đầy đủ từ csdl_banhang!';
