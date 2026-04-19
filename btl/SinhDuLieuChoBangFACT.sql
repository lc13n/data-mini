use DW_BanHang;
go

DELETE FROM Fact_BanHang;
DELETE FROM Fact_Kho;
DELETE FROM Dim_CuaHang;
DELETE FROM Dim_ThoiGian;
DELETE FROM Dim_KhachHang;
DELETE FROM Dim_MatHang;
DELETE FROM Dim_VPDD;

INSERT INTO Dim_ThoiGian (Thang, Quy, Nam)
VALUES 
(1,1,2023),(2,1,2023),(3,1,2023),
(4,2,2023),(5,2,2023),(6,2,2023),
(7,3,2023),(8,3,2023),(9,3,2023),
(10,4,2023),(11,4,2023),(12,4,2023),

(1,1,2024),(2,1,2024),(3,1,2024),
(4,2,2024),(5,2,2024),(6,2,2024),
(7,3,2024),(8,3,2024),(9,3,2024),
(10,4,2024),(11,4,2024),(12,4,2024),

(1,1,2025),(2,1,2025),(3,1,2025),
(4,2,2025),(5,2,2025),(6,2,2025),
(7,3,2025),(8,3,2025),(9,3,2025),
(10,4,2025),(11,4,2025),(12,4,2025);


INSERT INTO Dim_VPDD VALUES
('HN', N'Hà Nội', N'Miền Bắc', N'Cầu Giấy'),
('HCM', N'TP.HCM', N'Miền Nam', N'Quận 1'),
('DN', N'Đà Nẵng', N'Miền Trung', N'Hải Châu'),
('HP', N'Hải Phòng', N'Miền Bắc', N'Lê Chân'),
('CT', N'Cần Thơ', N'Miền Tây', N'Ninh Kiều'),
('BD', N'Bình Dương', N'Miền Nam', N'Thủ Dầu Một'),
('NA', N'Nghệ An', N'Miền Trung', N'Vinh'),
('QN', N'Quảng Ninh', N'Miền Bắc', N'Hạ Long'),
('KH', N'Khánh Hòa', N'Miền Trung', N'Nha Trang'),
('LA', N'Long An', N'Miền Nam', N'Tân An');

INSERT INTO Dim_KhachHang (MaKhachHang, TenKhachHang, MaThanhPho, LoaiKhachHang)
SELECT 
    'KH' + RIGHT('0000' + CAST(n AS VARCHAR), 4),

    -- Random tên người Việt
    Ho + ' ' + TenDem + ' ' + Ten,

    MaTP,

    -- Thay đổi logic loại khách hàng ở đây
    CASE n % 3 
        WHEN 0 THEN N'Du lịch' 
        WHEN 1 THEN N'Bưu điện' 
        ELSE N'Cả hai' 
    END
FROM (
    SELECT TOP 1000
        ROW_NUMBER() OVER (ORDER BY NEWID()) AS n,

        -- Họ
        CASE ABS(CHECKSUM(NEWID())) % 6
            WHEN 0 THEN N'Nguyễn'
            WHEN 1 THEN N'Trần'
            WHEN 2 THEN N'Lê'
            WHEN 3 THEN N'Phạm'
            WHEN 4 THEN N'Hoàng'
            ELSE N'Vũ'
        END AS Ho,

        -- Tên đệm
        CASE ABS(CHECKSUM(NEWID())) % 6
            WHEN 0 THEN N'Văn'
            WHEN 1 THEN N'Thị'
            WHEN 2 THEN N'Hữu'
            WHEN 3 THEN N'Đức'
            WHEN 4 THEN N'Minh'
            ELSE N'Quang'
        END AS TenDem,

        -- Tên chính
        CASE ABS(CHECKSUM(NEWID())) % 10
            WHEN 0 THEN N'Anh'
            WHEN 1 THEN N'Bình'
            WHEN 2 THEN N'Châu'
            WHEN 3 THEN N'Dũng'
            WHEN 4 THEN N'Hà'
            WHEN 5 THEN N'Huy'
            WHEN 6 THEN N'Linh'
            WHEN 7 THEN N'Nam'
            WHEN 8 THEN N'Trang'
            ELSE N'Tuấn'
        END AS Ten,

        -- Thành phố
        CASE ABS(CHECKSUM(NEWID())) % 10
            WHEN 0 THEN 'HN'
            WHEN 1 THEN 'HCM'
            WHEN 2 THEN 'DN'
            WHEN 3 THEN 'HP'
            WHEN 4 THEN 'CT'
            WHEN 5 THEN 'BD'
            WHEN 6 THEN 'NA'
            WHEN 7 THEN 'QN'
            WHEN 8 THEN 'KH'
            ELSE 'LA'
        END AS MaTP

    FROM sys.objects CROSS JOIN sys.columns -- Join thêm bảng để đảm bảo có đủ 1000 dòng nếu sys.objects ít dữ liệu
) t;

INSERT INTO Dim_MatHang (MaMatHang, MoTa, KichCo, TrongLuong, DonGia)
SELECT TOP 200
    'MH' + RIGHT('000' + CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) + 12 AS VARCHAR), 4),

    -- Mô tả sản phẩm
    CASE ABS(CHECKSUM(NEWID())) % 6
        WHEN 0 THEN N'Áo thun ' 
        WHEN 1 THEN N'Áo sơ mi '
        WHEN 2 THEN N'Quần jean '
        WHEN 3 THEN N'Giày sneaker '
        WHEN 4 THEN N'Túi xách '
        ELSE N'Balo '
    END
    +
    CASE ABS(CHECKSUM(NEWID())) % 5
        WHEN 0 THEN N'nam'
        WHEN 1 THEN N'nữ'
        WHEN 2 THEN N'unisex'
        WHEN 3 THEN N'thể thao'
        ELSE N'cao cấp'
    END,

    -- Kích cỡ
    CASE ABS(CHECKSUM(NEWID())) % 5
        WHEN 0 THEN N'S'
        WHEN 1 THEN N'M'
        WHEN 2 THEN N'L'
        WHEN 3 THEN N'XL'
        ELSE N'XXL'
    END,

    -- Trọng lượng: Dùng CHECKSUM thay cho RAND để đảm bảo tính ngẫu nhiên mỗi dòng
    CAST(ABS(CHECKSUM(NEWID())) % 150 / 100.0 AS FLOAT), 
    
    -- Đơn giá
    (ABS(CHECKSUM(NEWID())) % 900 + 100) * 1000
FROM master..spt_values; -- Thêm bảng nguồn ở đây


INSERT INTO Dim_CuaHang
SELECT 
    'CH' + RIGHT('000' + CAST(number + 20 AS VARCHAR), 4),
    CASE number % 10
        WHEN 0 THEN 'HN'
        WHEN 1 THEN 'HCM'
        WHEN 2 THEN 'DN'
        WHEN 3 THEN 'HP'
        WHEN 4 THEN 'CT'
        WHEN 5 THEN 'BD'
        WHEN 6 THEN 'NA'
        WHEN 7 THEN 'QN'
        WHEN 8 THEN 'KH'
        ELSE 'LA'
    END,
    '09' + CAST(20000000 + number AS VARCHAR)
FROM master..spt_values
WHERE type = 'P' AND number BETWEEN 21 AND 100;



INSERT INTO Fact_BanHang (MaKhachHang, MaMatHang, MaThoiGian, SoLuongBan, DoanhThu)
SELECT TOP 150000 
    t.MaKhachHang, t.MaMatHang, t.MaThoiGian, 
    t.SL, 
    t.SL * MH.DonGia -- Tính lại doanh thu chuẩn
FROM (
    SELECT DISTINCT -- Đảm bảo không trùng Primary Key
        KH.MaKhachHang, 
        MH.MaMatHang, 
        TG.MaThoiGian,
        ABS(CHECKSUM(NEWID())) % 10 + 1 AS SL
    FROM Dim_KhachHang KH
    CROSS JOIN Dim_MatHang MH
    CROSS JOIN Dim_ThoiGian TG
) t
JOIN Dim_MatHang MH ON t.MaMatHang = MH.MaMatHang;

-- Chỉnh sửa Fact_Kho: Đảm bảo không trùng PK
INSERT INTO Fact_Kho (MaMatHang, MaCuaHang, MaThoiGian, SoLuongTonKho, GiaTriTonKho)
SELECT TOP 200000 
    t.MaMatHang, t.MaCuaHang, t.MaThoiGian, 
    t.SLTon, 
    t.SLTon * MH.DonGia
FROM (
    SELECT DISTINCT 
        MH.MaMatHang, 
        CH.MaCuaHang, 
        TG.MaThoiGian,
        ABS(CHECKSUM(NEWID())) % 500 AS SLTon
    FROM Dim_MatHang MH
    CROSS JOIN Dim_CuaHang CH
    CROSS JOIN Dim_ThoiGian TG
) t
JOIN Dim_MatHang MH ON t.MaMatHang = MH.MaMatHang;