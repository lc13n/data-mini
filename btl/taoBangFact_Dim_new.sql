USE master;
GO
IF EXISTS (SELECT name FROM sys.databases WHERE name = N'DW_BanHang')
BEGIN
    -- Ngắt các kết nối đang hoạt động để có thể xóa database
    ALTER DATABASE DW_BanHang SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE DW_BanHang;
END
GO

CREATE DATABASE DW_BanHang;
GO
USE DW_BanHang;
GO

-- 1. Dim_ThoiGian
CREATE TABLE Dim_ThoiGian (
    TimeKey INT IDENTITY(1,1) PRIMARY KEY,
    Thang INT,
    Quy INT,
    Nam INT
);

-- 2. Dim_VPDD
CREATE TABLE Dim_VPDD (
    MaThanhPho VARCHAR(10) PRIMARY KEY,
    TenThanhPho NVARCHAR(100),
    Bang NVARCHAR(50),
    DiaChi NVARCHAR(255)
);

-- 3. Dim_KhachHang
CREATE TABLE Dim_KhachHang (
    MaKH VARCHAR(10) PRIMARY KEY,
    TenKhachHang NVARCHAR(100),
    MaThanhPho VARCHAR(10),
    LoaiKhachHang NVARCHAR(50)
);

-- 4. Dim_MatHang
CREATE TABLE Dim_MatHang (
    MaMH VARCHAR(10) PRIMARY KEY,
    MoTa NVARCHAR(MAX),
    KichCo NVARCHAR(50),
    TrongLuong FLOAT,
    DonGia DECIMAL(18, 2)
);

-- 5. Dim_CuaHang
CREATE TABLE Dim_CuaHang (
    MaCuaHang VARCHAR(10) PRIMARY KEY,
    MaThanhPho VARCHAR(10) REFERENCES Dim_VPDD(MaThanhPho),
    Bang NVARCHAR(50),
    SDT VARCHAR(20)
	
);

-- 6. Fact_BanHang
CREATE TABLE Fact_BanHang (
    MaKhachHang VARCHAR(10) REFERENCES Dim_KhachHang(MaKH),
    MaMatHang VARCHAR(10) REFERENCES Dim_MatHang(MaMH),
    TimeKey INT REFERENCES Dim_ThoiGian(TimeKey),
    SoLuongBan INT,
    DoanhThu DECIMAL(18, 2),
    PRIMARY KEY (MaKhachHang, MaMatHang, TimeKey)
);

-- 7. Fact_Kho
CREATE TABLE Fact_Kho (
    MaMatHang VARCHAR(10) REFERENCES Dim_MatHang(MaMH),
    MaCuaHang VARCHAR(10) REFERENCES Dim_CuaHang(MaCuaHang),
	TimeKey INT REFERENCES Dim_ThoiGian(TimeKey),
    SoLuongTonKho INT,
    PRIMARY KEY (MaMatHang, MaCuaHang, TimeKey)
);
GO