-- ============================================================
-- BƯỚC 8: THIẾT KẾ CÁC KHỐI DỮ LIỆU OLAP
-- Database: DW_BanHang
-- ============================================================
USE DW_BanHang;
GO

-- ============================================================
-- PHẦN 1: TẠO CÁC BẢNG KHỐI PRE-COMPUTED (Materialized Cubes)
-- ============================================================

-- Xóa khối cũ nếu tồn tại
IF OBJECT_ID('Cube_DoanhThu',   'U') IS NOT NULL DROP TABLE Cube_DoanhThu;
IF OBJECT_ID('Cube_TonKho',     'U') IS NOT NULL DROP TABLE Cube_TonKho;
IF OBJECT_ID('Cube_KhachHang',  'U') IS NOT NULL DROP TABLE Cube_KhachHang;

-- ========================
-- KHỐI 1: Doanh thu (KhachHang × MatHang × ThoiGian)
-- ========================
CREATE TABLE Cube_DoanhThu (
    LoaiKhachHang   NVARCHAR(50),
    MaThanhPhoKH    VARCHAR(10),
    MaMatHang       VARCHAR(10),
    MoTaMatHang     NVARCHAR(MAX),
    KichCo          NVARCHAR(50),
    Nam             INT,
    Quy             INT,
    Thang           INT,
    TongSoLuongBan  INT,
    TongDoanhThu    DECIMAL(18,2)
);

INSERT INTO Cube_DoanhThu
SELECT
    kh.LoaiKhachHang,
    kh.MaThanhPho       AS MaThanhPhoKH,
    mh.MaMH             AS MaMatHang,
    mh.MoTa             AS MoTaMatHang,
    mh.KichCo,
    tg.Nam,
    tg.Quy,
    tg.Thang,
    SUM(f.SoLuongBan)   AS TongSoLuongBan,
    SUM(f.DoanhThu)     AS TongDoanhThu
FROM Fact_BanHang f
JOIN Dim_KhachHang kh ON f.MaKhachHang = kh.MaKH
JOIN Dim_MatHang   mh ON f.MaMatHang   = mh.MaMH
JOIN Dim_ThoiGian  tg ON f.TimeKey     = tg.TimeKey
GROUP BY kh.LoaiKhachHang, kh.MaThanhPho, mh.MaMH, mh.MoTa, mh.KichCo, tg.Nam, tg.Quy, tg.Thang;

CREATE INDEX IX_Cube_DT_Nam    ON Cube_DoanhThu(Nam);
CREATE INDEX IX_Cube_DT_MH     ON Cube_DoanhThu(MaMatHang);
CREATE INDEX IX_Cube_DT_KH     ON Cube_DoanhThu(LoaiKhachHang);

PRINT N'✅ Cube_DoanhThu: ' + CAST(@@ROWCOUNT AS VARCHAR) + N' dòng';

-- ========================
-- KHỐI 2: Tồn kho (MatHang × CuaHang × ThoiGian)
-- ========================
CREATE TABLE Cube_TonKho (
    MaMatHang       VARCHAR(10),
    MoTaMatHang     NVARCHAR(MAX),
    KichCo          NVARCHAR(50),
    MaCuaHang       VARCHAR(10),
    MaThanhPhoCH    VARCHAR(10),
    TenThanhPho     NVARCHAR(100),
    Bang            NVARCHAR(50),
    Nam             INT,
    Quy             INT,
    Thang           INT,
    TongTonKho      INT
);

INSERT INTO Cube_TonKho
SELECT
    mh.MaMH,
    mh.MoTa,
    mh.KichCo,
    ch.MaCuaHang,
    ch.MaThanhPho,
    vp.TenThanhPho,
    ch.Bang,
    tg.Nam,
    tg.Quy,
    tg.Thang,
    SUM(f.SoLuongTonKho) AS TongTonKho
FROM Fact_Kho f
JOIN Dim_MatHang  mh ON f.MaMatHang  = mh.MaMH
JOIN Dim_CuaHang  ch ON f.MaCuaHang  = ch.MaCuaHang
JOIN Dim_VPDD     vp ON ch.MaThanhPho = vp.MaThanhPho
JOIN Dim_ThoiGian tg ON f.TimeKey     = tg.TimeKey
GROUP BY mh.MaMH, mh.MoTa, mh.KichCo, ch.MaCuaHang, ch.MaThanhPho, vp.TenThanhPho, ch.Bang, tg.Nam, tg.Quy, tg.Thang;

CREATE INDEX IX_Cube_TK_MH  ON Cube_TonKho(MaMatHang);
CREATE INDEX IX_Cube_TK_CH  ON Cube_TonKho(MaCuaHang);
CREATE INDEX IX_Cube_TK_TP  ON Cube_TonKho(MaThanhPhoCH);

PRINT N'✅ Cube_TonKho: ' + CAST(@@ROWCOUNT AS VARCHAR) + N' dòng';

-- ========================
-- KHỐI 3: Khách hàng theo loại & thành phố
-- ========================
CREATE TABLE Cube_KhachHang (
    LoaiKhachHang   NVARCHAR(50),
    MaThanhPho      VARCHAR(10),
    TenThanhPho     NVARCHAR(100),
    Bang            NVARCHAR(50),
    Nam             INT,
    Quy             INT,
    Thang           INT,
    SoLuongKH       INT,
    TongDoanhThu    DECIMAL(18,2)
);

INSERT INTO Cube_KhachHang
SELECT
    kh.LoaiKhachHang,
    kh.MaThanhPho,
    vp.TenThanhPho,
    vp.Bang,
    tg.Nam,
    tg.Quy,
    tg.Thang,
    COUNT(DISTINCT f.MaKhachHang) AS SoLuongKH,
    SUM(f.DoanhThu)               AS TongDoanhThu
FROM Fact_BanHang f
JOIN Dim_KhachHang kh ON f.MaKhachHang = kh.MaKH
JOIN Dim_VPDD      vp ON kh.MaThanhPho  = vp.MaThanhPho
JOIN Dim_ThoiGian  tg ON f.TimeKey      = tg.TimeKey
GROUP BY kh.LoaiKhachHang, kh.MaThanhPho, vp.TenThanhPho, vp.Bang, tg.Nam, tg.Quy, tg.Thang;

PRINT N'✅ Cube_KhachHang: ' + CAST(@@ROWCOUNT AS VARCHAR) + N' dòng';

GO

-- ============================================================
-- PHẦN 2: STORED PROCEDURES CHO CÁC THAO TÁC OLAP
-- ============================================================

-- ========================
-- SP1: DRILL DOWN — Doanh thu từ Năm → Quý → Tháng
-- ========================
IF OBJECT_ID('sp_DrillDown_ThoiGian', 'P') IS NOT NULL DROP PROC sp_DrillDown_ThoiGian;
GO
CREATE PROCEDURE sp_DrillDown_ThoiGian
    @Nam    INT = NULL,
    @Quy    INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @Nam IS NULL
        -- Mức Năm
        SELECT Nam, SUM(TongDoanhThu) AS DoanhThu, SUM(TongSoLuongBan) AS SoLuong
        FROM Cube_DoanhThu
        GROUP BY Nam ORDER BY Nam;
    ELSE IF @Quy IS NULL
        -- Mức Quý (drill down từ Năm)
        SELECT Nam, Quy, SUM(TongDoanhThu) AS DoanhThu, SUM(TongSoLuongBan) AS SoLuong
        FROM Cube_DoanhThu
        WHERE Nam = @Nam
        GROUP BY Nam, Quy ORDER BY Quy;
    ELSE
        -- Mức Tháng (drill down từ Quý)
        SELECT Nam, Quy, Thang, SUM(TongDoanhThu) AS DoanhThu, SUM(TongSoLuongBan) AS SoLuong
        FROM Cube_DoanhThu
        WHERE Nam = @Nam AND Quy = @Quy
        GROUP BY Nam, Quy, Thang ORDER BY Thang;
END
GO

-- ========================
-- SP2: ROLL UP — Tồn kho từ Cửa hàng → Thành phố → Bang
-- ========================
IF OBJECT_ID('sp_RollUp_DiaDiem', 'P') IS NOT NULL DROP PROC sp_RollUp_DiaDiem;
GO
CREATE PROCEDURE sp_RollUp_DiaDiem
    @MucDo  NVARCHAR(20) = 'CuaHang',  -- 'CuaHang' | 'ThanhPho' | 'Bang'
    @Nam    INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @NamFilter INT = ISNULL(@Nam, YEAR(GETDATE()));
    IF @MucDo = 'CuaHang'
        SELECT MaCuaHang, TenThanhPho, Bang, SUM(TongTonKho) AS TonKho
        FROM Cube_TonKho WHERE Nam = @NamFilter
        GROUP BY MaCuaHang, TenThanhPho, Bang ORDER BY TonKho DESC;
    ELSE IF @MucDo = 'ThanhPho'
        SELECT TenThanhPho, Bang, SUM(TongTonKho) AS TonKho
        FROM Cube_TonKho WHERE Nam = @NamFilter
        GROUP BY TenThanhPho, Bang ORDER BY TonKho DESC;
    ELSE
        SELECT Bang, SUM(TongTonKho) AS TonKho
        FROM Cube_TonKho WHERE Nam = @NamFilter
        GROUP BY Bang ORDER BY TonKho DESC;
END
GO

-- ========================
-- SP3: SLICE — Cắt theo một chiều cố định
-- ========================
IF OBJECT_ID('sp_Slice_DoanhThu', 'P') IS NOT NULL DROP PROC sp_Slice_DoanhThu;
GO
CREATE PROCEDURE sp_Slice_DoanhThu
    @LoaiKhachHang  NVARCHAR(50) = NULL,
    @Nam            INT          = NULL,
    @KichCo         NVARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        LoaiKhachHang, Nam, Quy, KichCo,
        SUM(TongSoLuongBan) AS SoLuong,
        SUM(TongDoanhThu)   AS DoanhThu
    FROM Cube_DoanhThu
    WHERE (@LoaiKhachHang IS NULL OR LoaiKhachHang = @LoaiKhachHang)
      AND (@Nam            IS NULL OR Nam           = @Nam)
      AND (@KichCo         IS NULL OR KichCo        = @KichCo)
    GROUP BY LoaiKhachHang, Nam, Quy, KichCo
    ORDER BY Nam, Quy;
END
GO

-- ========================
-- SP4: DICE — Cắt theo nhiều chiều
-- ========================
IF OBJECT_ID('sp_Dice_TonKho', 'P') IS NOT NULL DROP PROC sp_Dice_TonKho;
GO
CREATE PROCEDURE sp_Dice_TonKho
    @MaThanhPho     VARCHAR(10)  = NULL,
    @MaMatHang      VARCHAR(10)  = NULL,
    @NamFrom        INT          = NULL,
    @NamTo          INT          = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        MaMatHang, MoTaMatHang, KichCo,
        TenThanhPho, Bang,
        Nam, Quy, Thang,
        SUM(TongTonKho) AS TonKho
    FROM Cube_TonKho
    WHERE (@MaThanhPho IS NULL OR MaThanhPhoCH = @MaThanhPho)
      AND (@MaMatHang  IS NULL OR MaMatHang    = @MaMatHang)
      AND (@NamFrom    IS NULL OR Nam          >= @NamFrom)
      AND (@NamTo      IS NULL OR Nam          <= @NamTo)
    GROUP BY MaMatHang, MoTaMatHang, KichCo, TenThanhPho, Bang, Nam, Quy, Thang
    ORDER BY Nam, Thang;
END
GO

-- ========================
-- SP5: PIVOT — Doanh thu theo Loại KH (cột) × Năm (dòng)
-- ========================
IF OBJECT_ID('sp_Pivot_DoanhThu', 'P') IS NOT NULL DROP PROC sp_Pivot_DoanhThu;
GO
CREATE PROCEDURE sp_Pivot_DoanhThu
AS
BEGIN
    SET NOCOUNT ON;
    SELECT Nam,
        ISNULL([Du lịch],            0) AS [Du lich],
        ISNULL([Bưu điện],           0) AS [Buu dien],
        ISNULL([Du lịch & Bưu điện], 0) AS [DL_BD],
        ISNULL([Thường],             0) AS [Thuong]
    FROM (
        SELECT Nam, LoaiKhachHang, TongDoanhThu
        FROM Cube_DoanhThu
    ) src
    PIVOT (
        SUM(TongDoanhThu)
        FOR LoaiKhachHang IN ([Du lịch],[Bưu điện],[Du lịch & Bưu điện],[Thường])
    ) pvt
    ORDER BY Nam;
END
GO

-- ============================================================
-- PHẦN 3: 9 CÂU TRUY VẤN NGHIỆP VỤ (từ đề bài)
-- ============================================================

-- Q1: Tất cả cửa hàng + thành phố, bang, SĐT + mặt hàng bán ở kho đó
SELECT DISTINCT
    ch.MaCuaHang, vp.TenThanhPho, ch.Bang, ch.SDT,
    mh.MaMH, mh.MoTa, mh.KichCo, mh.TrongLuong, mh.DonGia
FROM Cube_TonKho tk
JOIN Dim_CuaHang ch ON tk.MaCuaHang  = ch.MaCuaHang
JOIN Dim_VPDD    vp ON ch.MaThanhPho = vp.MaThanhPho
JOIN Dim_MatHang mh ON tk.MaMatHang  = mh.MaMH
ORDER BY ch.MaCuaHang, mh.MaMH;

-- Q2: Tất cả đơn hàng + tên KH + ngày đặt của một khách hàng
DECLARE @MaKHQ2 VARCHAR(10) = 'KH001';
SELECT
    kh.MaKH, kh.TenKhachHang,
    SUM(f.SoLuongBan) AS TongSoLuong,
    SUM(f.DoanhThu)   AS TongDoanhThu,
    tg.Nam, tg.Thang
FROM Fact_BanHang f
JOIN Dim_KhachHang kh ON f.MaKhachHang = kh.MaKH
JOIN Dim_ThoiGian  tg ON f.TimeKey      = tg.TimeKey
WHERE kh.MaKH = @MaKHQ2
GROUP BY kh.MaKH, kh.TenKhachHang, tg.Nam, tg.Thang
ORDER BY tg.Nam, tg.Thang;

-- Q3: Cửa hàng + tên TP + SĐT có bán mặt hàng được đặt bởi 1 KH cụ thể
DECLARE @MaKHQ3 VARCHAR(10) = 'KH001';
SELECT DISTINCT ch.MaCuaHang, vp.TenThanhPho, ch.SDT, mh.MaMH, mh.MoTa
FROM Fact_BanHang fb
JOIN Dim_KhachHang kh ON fb.MaKhachHang = kh.MaKH
JOIN Fact_Kho      fk ON fb.MaMatHang   = fk.MaMatHang
JOIN Dim_CuaHang   ch ON fk.MaCuaHang   = ch.MaCuaHang
JOIN Dim_VPDD      vp ON ch.MaThanhPho  = vp.MaThanhPho
JOIN Dim_MatHang   mh ON fb.MaMatHang   = mh.MaMH
WHERE kh.MaKH = @MaKHQ3;

-- Q4: Địa chỉ VP + tên TP + bang của các CH lưu kho MH với SL > ngưỡng
DECLARE @MaMHQ4 VARCHAR(10) = 'MH001';
DECLARE @SLNguong INT = 100;
SELECT DISTINCT vp.TenThanhPho, vp.Bang, vp.DiaChi, ch.MaCuaHang, SUM(tk.TongTonKho) AS TonKho
FROM Cube_TonKho tk
JOIN Dim_CuaHang ch ON tk.MaCuaHang  = ch.MaCuaHang
JOIN Dim_VPDD    vp ON ch.MaThanhPho = vp.MaThanhPho
WHERE tk.MaMatHang = @MaMHQ4
GROUP BY vp.TenThanhPho, vp.Bang, vp.DiaChi, ch.MaCuaHang
HAVING SUM(tk.TongTonKho) > @SLNguong
ORDER BY TonKho DESC;

-- Q5: Mặt hàng đặt + mô tả + mã CH + tên TP bán mặt hàng đó (theo đơn KH)
DECLARE @MaKHQ5 VARCHAR(10) = 'KH001';
SELECT DISTINCT
    kh.MaKH, kh.TenKhachHang,
    mh.MaMH, mh.MoTa,
    ch.MaCuaHang, vp.TenThanhPho
FROM Fact_BanHang fb
JOIN Dim_KhachHang kh ON fb.MaKhachHang = kh.MaKH
JOIN Dim_MatHang   mh ON fb.MaMatHang   = mh.MaMH
JOIN Fact_Kho      fk ON fb.MaMatHang   = fk.MaMatHang
JOIN Dim_CuaHang   ch ON fk.MaCuaHang   = ch.MaCuaHang
JOIN Dim_VPDD      vp ON ch.MaThanhPho  = vp.MaThanhPho
WHERE kh.MaKH = @MaKHQ5;

-- Q6: Thành phố và bang mà 1 KH sinh sống
DECLARE @MaKHQ6 VARCHAR(10) = 'KH001';
SELECT kh.MaKH, kh.TenKhachHang, vp.TenThanhPho, vp.Bang
FROM Dim_KhachHang kh
JOIN Dim_VPDD      vp ON kh.MaThanhPho = vp.MaThanhPho
WHERE kh.MaKH = @MaKHQ6;

-- Q7: Tồn kho của 1 MH tại tất cả CH ở 1 TP cụ thể
DECLARE @MaMHQ7  VARCHAR(10) = 'MH001';
DECLARE @MaTPQ7  VARCHAR(10) = 'HCM';
SELECT ch.MaCuaHang, vp.TenThanhPho, SUM(tk.TongTonKho) AS TonKho
FROM Cube_TonKho tk
JOIN Dim_CuaHang ch ON tk.MaCuaHang  = ch.MaCuaHang
JOIN Dim_VPDD    vp ON ch.MaThanhPho = vp.MaThanhPho
WHERE tk.MaMatHang = @MaMHQ7 AND tk.MaThanhPhoCH = @MaTPQ7
GROUP BY ch.MaCuaHang, vp.TenThanhPho
ORDER BY TonKho DESC;

-- Q8: MH + SL đặt + KH + CH + TP của một đơn đặt hàng cụ thể
DECLARE @MaKHQ8 VARCHAR(10) = 'KH001';
SELECT
    kh.MaKH, kh.TenKhachHang,
    mh.MaMH, mh.MoTa,
    SUM(fb.SoLuongBan)  AS SoLuong,
    SUM(fb.DoanhThu)    AS DoanhThu,
    ch.MaCuaHang, vp.TenThanhPho
FROM Fact_BanHang fb
JOIN Dim_KhachHang kh ON fb.MaKhachHang = kh.MaKH
JOIN Dim_MatHang   mh ON fb.MaMatHang   = mh.MaMH
JOIN Fact_Kho      fk ON fb.MaMatHang   = fk.MaMatHang
JOIN Dim_CuaHang   ch ON fk.MaCuaHang   = ch.MaCuaHang
JOIN Dim_VPDD      vp ON ch.MaThanhPho  = vp.MaThanhPho
WHERE kh.MaKH = @MaKHQ8
GROUP BY kh.MaKH, kh.TenKhachHang, mh.MaMH, mh.MoTa, ch.MaCuaHang, vp.TenThanhPho;

-- Q9: KH du lịch, KH bưu điện, KH cả hai loại
SELECT
    LoaiKhachHang,
    COUNT(*) AS SoLuong
FROM Dim_KhachHang
WHERE LoaiKhachHang IN (N'Du lịch', N'Bưu điện', N'Du lịch & Bưu điện')
GROUP BY LoaiKhachHang;

-- Chi tiết
SELECT MaKH, TenKhachHang, LoaiKhachHang
FROM Dim_KhachHang
WHERE LoaiKhachHang IN (N'Du lịch', N'Bưu điện', N'Du lịch & Bưu điện')
ORDER BY LoaiKhachHang, MaKH;

PRINT N'✅ OLAP_Cubes.sql hoàn tất - 3 khối + 5 SP + 9 câu truy vấn nghiệp vụ';
