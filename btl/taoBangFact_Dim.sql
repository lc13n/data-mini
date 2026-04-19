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
    MaThoiGian INT IDENTITY(1,1) PRIMARY KEY,
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
    MaKhachHang VARCHAR(10) PRIMARY KEY,
    TenKhachHang NVARCHAR(100),
    MaThanhPho VARCHAR(10),
    LoaiKhachHang NVARCHAR(50)
);

-- 4. Dim_MatHang
CREATE TABLE Dim_MatHang (
    MaMatHang VARCHAR(10) PRIMARY KEY,
    MoTa NVARCHAR(MAX),
    KichCo NVARCHAR(50),
    TrongLuong FLOAT,
    DonGia DECIMAL(18, 2)
);

-- 5. Dim_CuaHang
CREATE TABLE Dim_CuaHang (
    MaCuaHang VARCHAR(10) PRIMARY KEY,
    MaThanhPho VARCHAR(10) REFERENCES Dim_VPDD(MaThanhPho),
    SoDienThoai VARCHAR(20)
	
);

-- 6. Fact_BanHang
CREATE TABLE Fact_BanHang (
    MaKhachHang VARCHAR(10) REFERENCES Dim_KhachHang(MaKhachHang),
    MaMatHang VARCHAR(10) REFERENCES Dim_MatHang(MaMatHang),
    MaThoiGian INT REFERENCES Dim_ThoiGian(MaThoiGian),
    SoLuongBan INT,
    DoanhThu DECIMAL(18, 2),
    PRIMARY KEY (MaKhachHang, MaMatHang, MaThoiGian)
);

-- 7. Fact_Kho
CREATE TABLE Fact_Kho (
    MaMatHang VARCHAR(10) REFERENCES Dim_MatHang(MaMatHang),
    MaCuaHang VARCHAR(10) REFERENCES Dim_CuaHang(MaCuaHang),
	MaThoiGian INT REFERENCES Dim_ThoiGian(MaThoiGian),
    SoLuongTonKho INT,
	GiaTriTonKho INT,
    PRIMARY KEY (MaMatHang, MaCuaHang, MaThoiGian)
);
GO