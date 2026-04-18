USE QuanLyBanHang;
GO

CREATE OR ALTER PROCEDURE Sp_SinhDuLieuLon_1000
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Dọn dẹp dữ liệu cũ (Xóa bảng con trước, bảng cha sau)
    DELETE FROM MatHangDuocDat;
    DELETE FROM MatHang_DuocLuuTru;
    DELETE FROM DonDatHang;
    DELETE FROM CuaHang;
    DELETE FROM MatHang;
    DELETE FROM KhachHangDuLich;
    DELETE FROM KhachHangBuuDien;
    DELETE FROM KhachHang;
    DELETE FROM VanPhongDaiDien;

    -- CTE để tạo dãy số từ 1 đến 1000 nhanh chóng
    ;WITH Numbers AS (
        SELECT TOP 1000 ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS ID
        FROM sys.all_columns a CROSS JOIN sys.all_columns b
    )
    SELECT ID INTO #T1000 FROM Numbers;

    -- 2. Sinh 1000 Văn phòng đại diện
    INSERT INTO VanPhongDaiDien (MaThanhPho, TenThanhPho, DiaChiVP, Bang, ThoiGianBatDauHoatDong)
    SELECT 
        'VP' + CAST(ID AS VARCHAR),
        N'Thành phố ' + LEFT(CAST(NEWID() AS VARCHAR(36)), 8),
        N'Địa chỉ số ' + CAST(ID AS VARCHAR) + ' ' + LEFT(CAST(NEWID() AS VARCHAR(36)), 10),
        N'Bang ' + CHAR(65 + (ID % 26)),
        DATEADD(DAY, -(ID % 3650), GETDATE())
    FROM #T1000;

    -- 3. Sinh 1000 Khách hàng
    INSERT INTO KhachHang (MaKH, TenKH, MaThanhPhoKhachHang, NgayDatHangDauTien)
    SELECT 
        'KH' + CAST(ID AS VARCHAR),
        N'Khách hàng ' + LEFT(CAST(NEWID() AS VARCHAR(36)), 6),
        'VP' + CAST((ABS(CHECKSUM(NEWID())) % 1000) + 1 AS VARCHAR), -- Lấy ngẫu nhiên từ 1000 VP
        DATEADD(DAY, -(ID % 2000), GETDATE())
    FROM #T1000;

    -- 4. Chia 1000 khách hàng vào 2 nhóm con (500 mỗi bên)
    INSERT INTO KhachHangDuLich (MaKH, HuongDanVienDuLich, ThoiGianMua)
    SELECT 'KH' + CAST(ID AS VARCHAR), N'HDV ' + LEFT(CAST(NEWID() AS VARCHAR(36)), 5), GETDATE()
    FROM #T1000 WHERE ID <= 500;

    INSERT INTO KhachHangBuuDien (MaKH, DiaChiBuuDien, ThoiGianTaoTaiKhoan)
    SELECT 'KH' + CAST(ID AS VARCHAR), N'Hòm thư ' + CAST(ID AS VARCHAR), GETDATE()
    FROM #T1000 WHERE ID > 500;

    -- 5. Sinh 1000 Cửa hàng
    INSERT INTO CuaHang (MaCuaHang, MaThanhPhoVanPhong, SoDienThoai, ThoiGianKhaiTruong)
    SELECT 
        'CH' + CAST(ID AS VARCHAR),
        'VP' + CAST((ABS(CHECKSUM(NEWID())) % 1000) + 1 AS VARCHAR),
        '09' + RIGHT('00000000' + CAST(ABS(CHECKSUM(NEWID())) % 100000000 AS VARCHAR), 8),
        DATEADD(DAY, -(ID % 500), GETDATE())
    FROM #T1000;

    -- 6. Sinh 1000 Mặt hàng
    INSERT INTO MatHang (MaMH, MoTa, KichCo, TrongLuong, DonGia, ThoiGianCapNhatMatHang)
    SELECT 
        'MH' + CAST(ID AS VARCHAR),
        N'Mô tả hàng hóa loại ' + CAST(ID AS VARCHAR),
        CASE WHEN ID % 3 = 0 THEN 'S' WHEN ID % 3 = 1 THEN 'M' ELSE 'L' END,
        ROUND(RAND(CHECKSUM(NEWID())) * 50, 2),
        (ABS(CHECKSUM(NEWID())) % 500 + 10) * 1000,
        GETDATE()
    FROM #T1000;

    -- 7. Sinh 1000 Đơn hàng
    INSERT INTO DonDatHang (MaDon, NgayDatHang, MaKhachHang)
    SELECT 
        'DH' + CAST(ID AS VARCHAR),
        DATEADD(HOUR, -ID, GETDATE()),
        'KH' + CAST(ID AS VARCHAR)
    FROM #T1000;

    -- 8. Sinh 1000 Chi tiết đơn hàng
    INSERT INTO MatHangDuocDat (MaDon, MaMatHang, SoLuongDat, GiaDat, ThoiGianDuocDat)
    SELECT 
        'DH' + CAST(ID AS VARCHAR),
        'MH' + CAST((ABS(CHECKSUM(NEWID())) % 1000) + 1 AS VARCHAR),
        (ID % 10) + 1,
        (ABS(CHECKSUM(NEWID())) % 500 + 10) * 1000,
        GETDATE()
    FROM #T1000;

    -- 9. Sinh 1000 Mặt hàng lưu trữ (Tồn kho)
    INSERT INTO MatHang_DuocLuuTru (MaCuaHang, MaMatHang, SoLuongTrongKho, ThoiGianCapNhatNhapKho)
    SELECT 
        'CH' + CAST(ID AS VARCHAR),
        'MH' + CAST(ID AS VARCHAR),
        ABS(CHECKSUM(NEWID())) % 500,
        GETDATE()
    FROM #T1000;

    DROP TABLE #T1000;
    PRINT N'Thành công: Mỗi bảng đã có tối thiểu 1000 dòng dữ liệu ngẫu nhiên!';
END;
GO

-- Thực thi
EXEC Sp_SinhDuLieuLon_1000;