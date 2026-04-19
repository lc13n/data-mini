-- ============================================================
-- METADATA cho Data Warehouse DW_BanHang
-- Mô tả cấu trúc, nguồn gốc, và ý nghĩa của từng bảng/cột
-- Dữ liệu được sinh trực tiếp vào DW qua SinhDuLieuChoBangFACT.sql
-- ============================================================
USE DW_BanHang;
GO

-- ========================
-- 1. BẢNG MÔ TẢ CÁC BẢNG TRONG DW
-- ========================
IF OBJECT_ID('dbo.Meta_Tables', 'U') IS NOT NULL DROP TABLE Meta_Tables;

CREATE TABLE Meta_Tables (
    TableName       NVARCHAR(100) PRIMARY KEY,
    TableType       NVARCHAR(20),       -- 'Fact' hoac 'Dimension'
    SourceTable     NVARCHAR(200),      -- Nguon du lieu
    Description     NVARCHAR(500),
    [RowCount]      INT DEFAULT 0,
    LastUpdated     DATETIME DEFAULT GETDATE()
);

INSERT INTO Meta_Tables VALUES
('Fact_BanHang', 'Fact',
 'SinhDuLieuChoBangFACT.sql (sinh trực tiếp)',
 N'Bảng sự kiện ghi nhận doanh thu bán hàng theo khách hàng, mặt hàng và thời gian',
 0, GETDATE()),

('Fact_Kho', 'Fact',
 'SinhDuLieuChoBangFACT.sql (sinh trực tiếp)',
 N'Bảng sự kiện ghi nhận số lượng tồn kho của từng mặt hàng tại từng cửa hàng theo thời gian',
 0, GETDATE()),

('Dim_ThoiGian', 'Dimension',
 'SinhDuLieuChoBangFACT.sql (sinh trực tiếp)',
 N'Chiều thời gian: Tháng → Quý → Năm (2023–2025)',
 0, GETDATE()),

('Dim_KhachHang', 'Dimension',
 'SinhDuLieuChoBangFACT.sql (sinh trực tiếp)',
 N'Chiều khách hàng: tên, thành phố sinh sống, loại khách hàng (Du lịch / Bưu điện / Cả hai)',
 0, GETDATE()),

('Dim_MatHang', 'Dimension',
 'SinhDuLieuChoBangFACT.sql (sinh trực tiếp)',
 N'Chiều mặt hàng: mô tả, kích cỡ, trọng lượng, đơn giá',
 0, GETDATE()),

('Dim_VPDD', 'Dimension',
 'SinhDuLieuChoBangFACT.sql (sinh trực tiếp)',
 N'Chiều văn phòng đại diện / thành phố: tên thành phố, bang/miền, địa chỉ VP',
 0, GETDATE()),

('Dim_CuaHang', 'Dimension',
 'SinhDuLieuChoBangFACT.sql (sinh trực tiếp)',
 N'Chiều cửa hàng: mã cửa hàng, thành phố, số điện thoại',
 0, GETDATE());

-- ========================
-- 2. BẢNG MÔ TẢ CỘT TRONG TỪNG BẢNG
-- ========================
IF OBJECT_ID('dbo.Meta_Columns', 'U') IS NOT NULL DROP TABLE Meta_Columns;

CREATE TABLE Meta_Columns (
    TableName       NVARCHAR(100),
    ColumnName      NVARCHAR(100),
    DataType        NVARCHAR(50),
    KeyType         NVARCHAR(20),   -- 'PK', 'FK', 'Measure', 'Attribute'
    SourceColumn    NVARCHAR(200),
    Description     NVARCHAR(500),
    PRIMARY KEY (TableName, ColumnName)
);

INSERT INTO Meta_Columns VALUES
-- Fact_BanHang
('Fact_BanHang','MaKhachHang','VARCHAR(10)','FK','Dim_KhachHang.MaKhachHang', N'Khóa ngoại → Dim_KhachHang'),
('Fact_BanHang','MaMatHang',  'VARCHAR(10)','FK','Dim_MatHang.MaMatHang',     N'Khóa ngoại → Dim_MatHang'),
('Fact_BanHang','MaThoiGian', 'INT',        'FK','Dim_ThoiGian.MaThoiGian',   N'Khóa ngoại → Dim_ThoiGian'),
('Fact_BanHang','SoLuongBan', 'INT',        'Measure','Sinh ngẫu nhiên',       N'Số lượng bán (1–10)'),
('Fact_BanHang','DoanhThu',   'DECIMAL(18,2)','Measure','SoLuongBan * DonGia', N'Doanh thu = SL × Đơn giá'),

-- Fact_Kho
('Fact_Kho','MaMatHang',      'VARCHAR(10)','FK','Dim_MatHang.MaMatHang',      N'Khóa ngoại → Dim_MatHang'),
('Fact_Kho','MaCuaHang',      'VARCHAR(10)','FK','Dim_CuaHang.MaCuaHang',      N'Khóa ngoại → Dim_CuaHang'),
('Fact_Kho','MaThoiGian',     'INT',        'FK','Dim_ThoiGian.MaThoiGian',    N'Khóa ngoại → Dim_ThoiGian'),
('Fact_Kho','SoLuongTonKho',  'INT',        'Measure','Sinh ngẫu nhiên',        N'Số lượng tồn kho (0–499)'),
('Fact_Kho','GiaTriTonKho',   'INT',        'Measure','SoLuongTonKho * DonGia', N'Giá trị tồn kho = SL × Đơn giá'),

-- Dim_ThoiGian
('Dim_ThoiGian','MaThoiGian','INT','PK','IDENTITY(1,1)',  N'Khóa chính tự tăng'),
('Dim_ThoiGian','Thang',     'INT','Attribute','1–12',    N'Tháng trong năm (1–12)'),
('Dim_ThoiGian','Quy',       'INT','Attribute','1–4',     N'Quý (1–4) — phân cấp con của Năm'),
('Dim_ThoiGian','Nam',       'INT','Attribute','2023–2025',N'Năm — phân cấp cao nhất của Thời gian'),

-- Dim_KhachHang
('Dim_KhachHang','MaKhachHang',   'VARCHAR(10)', 'PK','KH0001–KH1000',         N'Khóa chính'),
('Dim_KhachHang','TenKhachHang',  'NVARCHAR(100)','Attribute','Sinh ngẫu nhiên',N'Tên khách hàng (họ + tên đệm + tên)'),
('Dim_KhachHang','MaThanhPho',    'VARCHAR(10)', 'FK','Dim_VPDD.MaThanhPho',    N'Thành phố sinh sống → Dim_VPDD'),
('Dim_KhachHang','LoaiKhachHang', 'NVARCHAR(50)','Attribute','n%3 phân loại',   N'Du lịch / Bưu điện / Cả hai'),

-- Dim_MatHang
('Dim_MatHang','MaMatHang', 'VARCHAR(10)',  'PK','MH0013–MH0212',         N'Khóa chính'),
('Dim_MatHang','MoTa',      'NVARCHAR(MAX)','Attribute','Sinh ngẫu nhiên', N'Mô tả mặt hàng (loại + giới tính)'),
('Dim_MatHang','KichCo',    'NVARCHAR(50)', 'Attribute','S/M/L/XL/XXL',   N'Kích cỡ'),
('Dim_MatHang','TrongLuong','FLOAT',        'Attribute','0.00–1.49',       N'Trọng lượng (kg)'),
('Dim_MatHang','DonGia',    'DECIMAL(18,2)','Attribute','100k–1000k*1000', N'Đơn giá (VNĐ)'),

-- Dim_VPDD
('Dim_VPDD','MaThanhPho', 'VARCHAR(10)',  'PK','HN/HCM/DN/...',                N'Khóa chính — mã thành phố'),
('Dim_VPDD','TenThanhPho','NVARCHAR(100)','Attribute','Tên đầy đủ TP',         N'Tên thành phố'),
('Dim_VPDD','Bang',       'NVARCHAR(50)', 'Attribute','Miền Bắc/Trung/Nam/Tây',N'Miền — phân cấp trên Thành phố'),
('Dim_VPDD','DiaChi',     'NVARCHAR(255)','Attribute','Tên quận/huyện',         N'Địa chỉ văn phòng đại diện'),

-- Dim_CuaHang
('Dim_CuaHang','MaCuaHang',   'VARCHAR(10)', 'PK','CH0021–CH0100',              N'Khóa chính'),
('Dim_CuaHang','MaThanhPho',  'VARCHAR(10)', 'FK','Dim_VPDD.MaThanhPho',        N'Thành phố của cửa hàng → Dim_VPDD'),
('Dim_CuaHang','SoDienThoai', 'VARCHAR(20)', 'Attribute','09xxxxxxxx',           N'Số điện thoại cửa hàng');

-- ========================
-- 3. BẢNG MÔ TẢ PHÂN CẤP CHIỀU (Hierarchy)
-- ========================
IF OBJECT_ID('dbo.Meta_Hierarchy', 'U') IS NOT NULL DROP TABLE Meta_Hierarchy;

CREATE TABLE Meta_Hierarchy (
    HierarchyID     INT IDENTITY(1,1) PRIMARY KEY,
    DimensionName   NVARCHAR(100),
    HierarchyName   NVARCHAR(100),
    LevelOrder      INT,
    LevelName       NVARCHAR(100),
    ColumnName      NVARCHAR(100),
    Description     NVARCHAR(300)
);

INSERT INTO Meta_Hierarchy (DimensionName, HierarchyName, LevelOrder, LevelName, ColumnName, Description) VALUES
-- Chiều Thời gian
('Dim_ThoiGian', 'Thời gian', 1, N'Năm',   'Nam',   N'Cấp cao nhất — 2023/2024/2025'),
('Dim_ThoiGian', 'Thời gian', 2, N'Quý',   'Quy',   N'Quý trong năm (1–4)'),
('Dim_ThoiGian', 'Thời gian', 3, N'Tháng', 'Thang', N'Cấp thấp nhất (1–12)'),

-- Chiều Địa điểm (Cửa hàng)
('Dim_CuaHang', 'Địa điểm cửa hàng', 1, N'Bang',       'Bang_VPDD',  N'Miền Bắc/Trung/Nam/Tây (qua Dim_VPDD)'),
('Dim_CuaHang', 'Địa điểm cửa hàng', 2, N'Thành phố',  'MaThanhPho', N'Thành phố của cửa hàng'),
('Dim_CuaHang', 'Địa điểm cửa hàng', 3, N'Cửa hàng',   'MaCuaHang',  N'Cấp thấp nhất'),

-- Chiều Khách hàng
('Dim_KhachHang', 'Khách hàng', 1, N'Loại khách hàng', 'LoaiKhachHang', N'Du lịch / Bưu điện / Cả hai'),
('Dim_KhachHang', 'Khách hàng', 2, N'Khách hàng',      'MaKhachHang',   N'Cấp thấp nhất');

-- ========================
-- 4. CẬP NHẬT RowCount trong Meta_Tables
-- ========================
UPDATE Meta_Tables SET [RowCount] = (SELECT COUNT(*) FROM Fact_BanHang)  WHERE TableName = 'Fact_BanHang';
UPDATE Meta_Tables SET [RowCount] = (SELECT COUNT(*) FROM Fact_Kho)      WHERE TableName = 'Fact_Kho';
UPDATE Meta_Tables SET [RowCount] = (SELECT COUNT(*) FROM Dim_ThoiGian)  WHERE TableName = 'Dim_ThoiGian';
UPDATE Meta_Tables SET [RowCount] = (SELECT COUNT(*) FROM Dim_KhachHang) WHERE TableName = 'Dim_KhachHang';
UPDATE Meta_Tables SET [RowCount] = (SELECT COUNT(*) FROM Dim_MatHang)   WHERE TableName = 'Dim_MatHang';
UPDATE Meta_Tables SET [RowCount] = (SELECT COUNT(*) FROM Dim_VPDD)      WHERE TableName = 'Dim_VPDD';
UPDATE Meta_Tables SET [RowCount] = (SELECT COUNT(*) FROM Dim_CuaHang)   WHERE TableName = 'Dim_CuaHang';

-- ========================
-- 5. XEM KẾT QUẢ METADATA
-- ========================
SELECT TableName, TableType, SourceTable, [RowCount], Description FROM Meta_Tables;
SELECT TableName, ColumnName, DataType, KeyType, Description FROM Meta_Columns ORDER BY TableName;
SELECT DimensionName, HierarchyName, LevelOrder, LevelName FROM Meta_Hierarchy ORDER BY DimensionName, LevelOrder;

PRINT N'✅ Metadata đã được tạo đầy đủ!';
