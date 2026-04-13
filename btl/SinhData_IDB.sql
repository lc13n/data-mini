USE csdl_banhang;
GO

SET NOCOUNT ON;

-- ========================
-- 1. XÓA DỮ LIỆU CŨ (đúng thứ tự FK)
-- ========================
DELETE FROM MatHangDuocDat;
DELETE FROM DonDatHang;
DELETE FROM MatHang_DuocLuuTru;
DELETE FROM MatHang;
DELETE FROM CuaHang;
DELETE FROM KhachHangDuLich;
DELETE FROM KhachHangBuuDien;
DELETE FROM KhachHang;
DELETE FROM VanPhongDaiDien;

-- ========================
-- 2. VĂN PHÒNG ĐẠI DIỆN (5 thành phố)
-- ========================
INSERT INTO VanPhongDaiDien VALUES
('HCM', N'Hồ Chí Minh', N'123 Nguyễn Huệ, Q1',    N'Miền Nam', '2010-01-01'),
('HN',  N'Hà Nội',       N'45 Hoàn Kiếm, HK',       N'Miền Bắc', '2010-03-01'),
('DN',  N'Đà Nẵng',      N'88 Bạch Đằng, Hải Châu', N'Miền Trung','2012-06-01'),
('HP',  N'Hải Phòng',    N'12 Lê Chân, LP',          N'Miền Bắc', '2013-09-01'),
('CT',  N'Cần Thơ',      N'77 Ninh Kiều, CT',        N'Miền Nam', '2015-01-01');

-- ========================
-- 3. KHÁCH HÀNG (200 KH)
-- ========================
DECLARE @i INT = 1;
DECLARE @maTPs TABLE (MaTP VARCHAR(10));
INSERT INTO @maTPs VALUES ('HCM'),('HN'),('DN'),('HP'),('CT');

WHILE @i <= 200
BEGIN
    DECLARE @maTP VARCHAR(10) = (
        SELECT TOP 1 MaTP FROM @maTPs ORDER BY NEWID()
    );
    INSERT INTO KhachHang VALUES (
        'KH' + RIGHT('000'+CAST(@i AS VARCHAR),3),
        N'Khách hàng ' + CAST(@i AS NVARCHAR),
        @maTP,
        DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 1825, '2023-01-01')
    );
    SET @i += 1;
END

-- ========================
-- 4. KHÁCH HÀNG DU LỊCH (50 KH lẻ)
-- ========================
DECLARE @hdv TABLE (Ten NVARCHAR(100));
INSERT INTO @hdv VALUES
(N'Nguyễn Văn A'),(N'Trần Thị B'),(N'Lê Văn C'),(N'Phạm Thị D'),(N'Hoàng Văn E');

SET @i = 1;
WHILE @i <= 100
BEGIN
    DECLARE @hdvTen NVARCHAR(100) = (SELECT TOP 1 Ten FROM @hdv ORDER BY NEWID());
    INSERT INTO KhachHangDuLich VALUES (
        'KH' + RIGHT('000'+CAST(@i*2-1 AS VARCHAR),3),
        @hdvTen,
        DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 365, '2024-01-01')
    );
    SET @i += 1;
END

-- ========================
-- 5. KHÁCH HÀNG BƯU ĐIỆN (50 KH chẵn)
-- ========================
SET @i = 1;
WHILE @i <= 100
BEGIN
    INSERT INTO KhachHangBuuDien VALUES (
        'KH' + RIGHT('000'+CAST(@i*2 AS VARCHAR),3),
        N'Địa chỉ bưu điện ' + CAST(@i AS NVARCHAR) + N', TP.HCM',
        DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 730, '2024-01-01')
    );
    SET @i += 1;
END

-- ========================
-- 6. CỬA HÀNG (30 cửa hàng)
-- ========================
SET @i = 1;
WHILE @i <= 30
BEGIN
    DECLARE @maTPCH VARCHAR(10) = (SELECT TOP 1 MaTP FROM @maTPs ORDER BY NEWID());
    INSERT INTO CuaHang VALUES (
        'CH' + RIGHT('000'+CAST(@i AS VARCHAR),3),
        @maTPCH,
        '09' + RIGHT('00000000'+CAST(10000000+@i AS VARCHAR),8),
        DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 2000, '2023-01-01')
    );
    SET @i += 1;
END

-- ========================
-- 7. MẶT HÀNG (100 mặt hàng)
-- ========================
SET @i = 1;
WHILE @i <= 100
BEGIN
    INSERT INTO MatHang VALUES (
        'MH' + RIGHT('000'+CAST(@i AS VARCHAR),3),
        N'Mặt hàng ' + CAST(@i AS NVARCHAR),
        CASE WHEN @i % 3 = 0 THEN N'Lớn'
             WHEN @i % 3 = 1 THEN N'Vừa'
             ELSE N'Nhỏ' END,
        RAND(CHECKSUM(NEWID())) * 15 + 0.5,
        CAST(RAND(CHECKSUM(NEWID())) * 990 + 10 AS DECIMAL(18,2)),
        DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 365, '2024-01-01')
    );
    SET @i += 1;
END

-- ========================
-- 8. MẶT HÀNG ĐƯỢC LƯU TRỮ (mỗi cửa hàng lưu ~20 mặt hàng ngẫu nhiên)
-- ========================
DECLARE @ch VARCHAR(10), @mh VARCHAR(10);
DECLARE cur_ch CURSOR FOR SELECT MaCuaHang FROM CuaHang;
OPEN cur_ch;
FETCH NEXT FROM cur_ch INTO @ch;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @i = 1;
    WHILE @i <= 20
    BEGIN
        SET @mh = 'MH' + RIGHT('000'+CAST(ABS(CHECKSUM(NEWID())) % 100 + 1 AS VARCHAR),3);
        IF NOT EXISTS (
            SELECT 1 FROM MatHang_DuocLuuTru
            WHERE MaCuaHang = @ch AND MaMatHang = @mh
        )
        BEGIN
            INSERT INTO MatHang_DuocLuuTru VALUES (
                @ch, @mh,
                ABS(CHECKSUM(NEWID())) % 500 + 1,
                DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 180, GETDATE())
            );
        END
        SET @i += 1;
    END
    FETCH NEXT FROM cur_ch INTO @ch;
END
CLOSE cur_ch; DEALLOCATE cur_ch;

-- ========================
-- 9. ĐƠN ĐẶT HÀNG (500 đơn)
-- ========================
SET @i = 1;
WHILE @i <= 500
BEGIN
    DECLARE @maKH VARCHAR(10) = 'KH' + RIGHT('000'+CAST(ABS(CHECKSUM(NEWID())) % 200 + 1 AS VARCHAR),3);
    INSERT INTO DonDatHang VALUES (
        'DDH' + RIGHT('0000'+CAST(@i AS VARCHAR),4),
        DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 730, GETDATE()),
        @maKH
    );
    SET @i += 1;
END

-- ========================
-- 10. MẶT HÀNG ĐƯỢC ĐẶT (mỗi đơn có 1-5 mặt hàng)
-- ========================
DECLARE @maDon VARCHAR(10);
DECLARE cur_don CURSOR FOR SELECT MaDon FROM DonDatHang;
OPEN cur_don;
FETCH NEXT FROM cur_don INTO @maDon;
WHILE @@FETCH_STATUS = 0
BEGIN
    DECLARE @soMH INT = ABS(CHECKSUM(NEWID())) % 5 + 1;
    SET @i = 1;
    WHILE @i <= @soMH
    BEGIN
        SET @mh = 'MH' + RIGHT('000'+CAST(ABS(CHECKSUM(NEWID())) % 100 + 1 AS VARCHAR),3);
        IF NOT EXISTS (
            SELECT 1 FROM MatHangDuocDat
            WHERE MaDon = @maDon AND MaMatHang = @mh
        )
        BEGIN
            DECLARE @gia DECIMAL(18,2) = (
                SELECT TOP 1 DonGia FROM MatHang WHERE MaMH = @mh
            );
            INSERT INTO MatHangDuocDat VALUES (
                @maDon, @mh,
                ABS(CHECKSUM(NEWID())) % 10 + 1,
                @gia,
                DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 730, GETDATE())
            );
        END
        SET @i += 1;
    END
    FETCH NEXT FROM cur_don INTO @maDon;
END
CLOSE cur_don; DEALLOCATE cur_don;

PRINT N'✅ DONE - Sinh dữ liệu CSDL nguồn hoàn tất!';
PRINT N'   VanPhongDaiDien: 5 | KhachHang: 200 | CuaHang: 30 | MatHang: 100';
PRINT N'   DonDatHang: 500 | KhachHangDuLich: 100 | KhachHangBuuDien: 100';
