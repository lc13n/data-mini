USE master;
GO

ALTER DATABASE IDBBanHang
SET SINGLE_USER
WITH ROLLBACK IMMEDIATE;
GO

DROP DATABASE IDBBanHang;
	CREATE Database IDBBanHang
	GO
	USE IDBBanHang;
	GO

	-- 1. Bảng Văn phòng đại diện
	CREATE TABLE VanPhongDaiDien (
		MaThanhPho VARCHAR(10) PRIMARY KEY,
		TenThanhPho NVARCHAR(100),
		DiaChiVP NVARCHAR(255),
		Bang NVARCHAR(50),
		ThoiGianBatDauHoatDong DATETIME
	);

	-- 2. Bảng Khách hàng
	CREATE TABLE KhachHang (
		MaKH VARCHAR(10) PRIMARY KEY,
		TenKH NVARCHAR(100),
		MaThanhPhoKhachHang VARCHAR(10),
		NgayDatHangDauTien DATE
	);

	-- 3. Bảng Khách hàng du lịch (Kế thừa/Mở rộng từ KhachHang)
	CREATE TABLE KhachHangDuLich (
		MaKH VARCHAR(10) PRIMARY KEY REFERENCES KhachHang(MaKH),
		HuongDanVienDuLich NVARCHAR(100),
		ThoiGianMua DATETIME
	);

	-- 4. Bảng Khách hàng bưu điện
	CREATE TABLE KhachHangBuuDien (
		MaKH VARCHAR(10) PRIMARY KEY REFERENCES KhachHang(MaKH),
		DiaChiBuuDien NVARCHAR(255),
		ThoiGianTaoTaiKhoan DATETIME
	);

	-- 5. Bảng Cửa hàng
	CREATE TABLE CuaHang (
		MaCuaHang VARCHAR(10) PRIMARY KEY,
		MaThanhPhoVanPhong VARCHAR(10) REFERENCES VanPhongDaiDien(MaThanhPho),
		SoDienThoai VARCHAR(20),
		ThoiGianKhaiTruong DATETIME
	);

	-- 6. Bảng Mặt hàng
	CREATE TABLE MatHang (
		MaMH VARCHAR(10) PRIMARY KEY,
		MoTa NVARCHAR(MAX),
		KichCo NVARCHAR(50),
		TrongLuong FLOAT,
		DonGia DECIMAL(18, 2),
		ThoiGianCapNhatMatHang DATETIME
	);

	-- 7. Bảng Mặt hàng được lưu trữ (Kho)
	CREATE TABLE MatHangDuocLuuTru (
		MaCuaHang VARCHAR(10) REFERENCES CuaHang(MaCuaHang),
		MaMatHang VARCHAR(10) REFERENCES MatHang(MaMH),
		SoLuongTrongKho INT,
		ThoiGianCapNhatNhapKho DATETIME,
		PRIMARY KEY (MaCuaHang, MaMatHang)
	);

	-- 8. Bảng Đơn đặt hàng
	CREATE TABLE DonDatHang (
		MaDon VARCHAR(10) PRIMARY KEY,
		NgayDatHang DATETIME,
		MaKhachHang VARCHAR(10) REFERENCES KhachHang(MaKH)
	);

	-- 9. Bảng Mặt hàng được đặt (Chi tiết đơn hàng)
	CREATE TABLE MatHangDuocDat (
		MaDon VARCHAR(10) REFERENCES DonDatHang(MaDon),
		MaMatHang VARCHAR(10) REFERENCES MatHang(MaMH),
		SoLuongDat INT,
		GiaDat DECIMAL(18, 2),
		ThoiGianDuocDat DATETIME,
		PRIMARY KEY (MaDon, MaMatHang)
	);
	GO