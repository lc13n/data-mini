USE master;
GO
IF EXISTS (SELECT name FROM sys.databases WHERE name = N'DW_BanHang')
BEGIN
    ALTER DATABASE DW_BanHang SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE DW_BanHang;
END
GO

CREATE DATABASE DW_BanHang;
GO
USE DW_BanHang;
GO

-- ============================================================
-- CHIỀU 1: Dim_ThoiGian
-- Theo sơ đồ: maThoiGian, thang, quy, nam
-- ============================================================
CREATE TABLE Dim_ThoiGian (
    maThoiGian  INT IDENTITY(1,1) PRIMARY KEY,
    thang       INT,
    quy         INT,
    nam         INT
);

-- ============================================================
-- CHIỀU 2: Dim_VPDD (Văn phòng đại diện / Thành phố)
-- Theo sơ đồ: MaThanhPho, TenThanhPho, Bang, DiaChi
-- ============================================================
CREATE TABLE Dim_VPDD (
    MaThanhPho  VARCHAR(10) PRIMARY KEY,
    TenThanhPho NVARCHAR(100),
    Bang        NVARCHAR(50),
    DiaChi      NVARCHAR(255)
);

-- ============================================================
-- CHIỀU 3: Dim_KhachHang
-- Theo sơ đồ: MaKH, TenKhachHang, MaThanhPho, LoaiKhachHang
-- ============================================================
CREATE TABLE Dim_KhachHang (
    MaKH            VARCHAR(10) PRIMARY KEY,
    TenKhachHang    NVARCHAR(100),
    MaThanhPho      VARCHAR(10),
    LoaiKhachHang   NVARCHAR(50)
);

-- ============================================================
-- CHIỀU 4: Dim_MatHang
-- Theo sơ đồ: MaMH, MoTa, KichCo, TrongLuong, DonGia
-- ============================================================
CREATE TABLE Dim_MatHang (
    MaMH        VARCHAR(10) PRIMARY KEY,
    MoTa        NVARCHAR(MAX),
    KichCo      NVARCHAR(50),
    TrongLuong  FLOAT,
    DonGia      DECIMAL(18, 2)
);

-- ============================================================
-- CHIỀU 5: Dim_CuaHang
-- Theo sơ đồ: MaCuaHang, MaThanhPho, Bang, SDT
-- ============================================================
CREATE TABLE Dim_CuaHang (
    MaCuaHang   VARCHAR(10) PRIMARY KEY,
    MaThanhPho  VARCHAR(10) REFERENCES Dim_VPDD(MaThanhPho),
    Bang        NVARCHAR(50),
    SDT         VARCHAR(20)
);

-- ============================================================
-- FACT 1: Fact_BanHang
-- Theo sơ đồ: MaKhachHang, MaMatHang, MaThanhPho, MaThoiGian
--             + SoLuongBan, DoanhThu (độ đo)
-- ============================================================
CREATE TABLE Fact_BanHang (
    MaKhachHang VARCHAR(10)     REFERENCES Dim_KhachHang(MaKH),
    MaMatHang   VARCHAR(10)     REFERENCES Dim_MatHang(MaMH),
    MaThanhPho  VARCHAR(10)     REFERENCES Dim_VPDD(MaThanhPho),
    MaThoiGian  INT             REFERENCES Dim_ThoiGian(maThoiGian),
    SoLuongBan  INT,
    DoanhThu    DECIMAL(18, 2),
    PRIMARY KEY (MaKhachHang, MaMatHang, MaThanhPho, MaThoiGian)
);

-- ============================================================
-- FACT 2: Fact_Kho
-- Theo sơ đồ: MaMatHang, MaCuaHang + SoLuongTonKho (độ đo)
-- ============================================================
CREATE TABLE Fact_Kho (
    MaMatHang       VARCHAR(10) REFERENCES Dim_MatHang(MaMH),
    MaCuaHang       VARCHAR(10) REFERENCES Dim_CuaHang(MaCuaHang),
    SoLuongTonKho   INT,
    PRIMARY KEY (MaMatHang, MaCuaHang)
);
GO