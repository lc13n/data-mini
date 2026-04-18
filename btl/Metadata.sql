-- ============================================================
-- METADATA cho Data Warehouse DW_BanHang
-- Mô tả cấu trúc, nguồn gốc, và ý nghĩa của từng bảng/cột
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
    SourceTable     NVARCHAR(200),      -- Bang nguon trong IDB
    Description     NVARCHAR(500),
    RowCount        INT DEFAULT 0,
    LastUpdated     DATETIME DEFAULT GETDATE()
);

INSERT INTO Meta_Tables VALUES
('Fact_BanHang', 'Fact',
 'csdl_banhang.dbo.DonDatHang + MatHangDuocDat',
 N'Bảng sự kiện ghi nhận doanh thu bán hàng theo khách hàng, mặt hàng và thời gian',
 0, GETDATE()),

('Fact_Kho', 'Fact',
 'csdl_banhang.dbo.MatHang_DuocLuuTru',
 N'Bảng sự kiện ghi nhận số lượng tồn kho của từng mặt hàng tại từng cửa hàng theo thời gian',
 0, GETDATE()),

('Dim_ThoiGian', 'Dimension',
 'Sinh từ cột NgayDatHang trong DonDatHang',
 N'Chiều thời gian: Tháng → Quý → Năm',
 0, GETDATE()),

('Dim_KhachHang', 'Dimension',
 'csdl_banhang.dbo.KhachHang + KhachHangDuLich + KhachHangBuuDien',
 N'Chiều khách hàng: tên, thành phố sinh sống, loại khách hàng (Du lịch / Bưu điện / Thường)',
 0, GETDATE()),

('Dim_MatHang', 'Dimension',
 'csdl_banhang.dbo.MatHang',
 N'Chiều mặt hàng: mô tả, kích cỡ, trọng lượng, đơn giá',
 0, GETDATE()),

('Dim_VPDD', 'Dimension',
 'csdl_banhang.dbo.VanPhongDaiDien',
 N'Chiều văn phòng đại diện / thành phố: tên thành phố, bang, địa chỉ VP',
 0, GETDATE()),

('Dim_CuaHang', 'Dimension',
 'csdl_banhang.dbo.CuaHang',
 N'Chiều cửa hàng: mã cửa hàng, thành phố, bang, số điện thoại',
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
('Fact_BanHang','MaKhachHang','VARCHAR(10)','FK','KhachHang.MaKH',   N'Khóa ngoại → Dim_KhachHang'),
('Fact_BanHang','MaMatHang',  'VARCHAR(10)','FK','MatHang.MaMH',     N'Khóa ngoại → Dim_MatHang'),
('Fact_BanHang','TimeKey',    'INT',        'FK','Dim_ThoiGian.TimeKey', N'Khóa ngoại → Dim_ThoiGian'),
('Fact_BanHang','SoLuongBan', 'INT',        'Measure','MatHangDuocDat.SoLuongDat',N'Tổng số lượng đặt (SUM)'),
('Fact_BanHang','DoanhThu',   'DECIMAL(18,2)','Measure','SoLuongDat*GiaDat',N'Tổng doanh thu (SUM)'),

-- Fact_Kho
('Fact_Kho','MaMatHang',      'VARCHAR(10)','FK','MatHang.MaMH',        N'Khóa ngoại → Dim_MatHang'),
('Fact_Kho','MaCuaHang',      'VARCHAR(10)','FK','CuaHang.MaCuaHang',   N'Khóa ngoại → Dim_CuaHang'),
('Fact_Kho','TimeKey',        'INT',        'FK','Dim_ThoiGian.TimeKey', N'Khóa ngoại → Dim_ThoiGian (tháng cập nhật tồn kho)'),
('Fact_Kho','SoLuongTonKho',  'INT',        'Measure','MatHang_DuocLuuTru.SoLuongTrongKho',N'Số lượng tồn kho tại thời điểm'),

-- Dim_ThoiGian
('Dim_ThoiGian','TimeKey','INT','PK','IDENTITY',             N'Khóa chính tự tăng'),
('Dim_ThoiGian','Thang',  'INT','Attribute','MONTH(NgayDatHang)',N'Tháng (1-12)'),
('Dim_ThoiGian','Quy',    'INT','Attribute','(Thang-1)/3+1',   N'Quý (1-4) — phân cấp con của Năm'),
('Dim_ThoiGian','Nam',    'INT','Attribute','YEAR(NgayDatHang)',N'Năm — phân cấp cao nhất của Thời gian'),

-- Dim_KhachHang
('Dim_KhachHang','MaKH',          'VARCHAR(10)', 'PK','KhachHang.MaKH',          N'Khóa chính'),
('Dim_KhachHang','TenKhachHang',  'NVARCHAR(100)','Attribute','KhachHang.TenKH', N'Tên khách hàng'),
('Dim_KhachHang','MaThanhPho',    'VARCHAR(10)', 'FK','KhachHang.MaThanhPhoKhachHang',N'Thành phố sinh sống → Dim_VPDD'),
('Dim_KhachHang','LoaiKhachHang', 'NVARCHAR(50)','Attribute','Derived',          N'Du lịch / Bưu điện / Du lịch & Bưu điện / Thường'),

-- Dim_MatHang
('Dim_MatHang','MaMH',      'VARCHAR(10)',  'PK','MatHang.MaMH',     N'Khóa chính'),
('Dim_MatHang','MoTa',      'NVARCHAR(MAX)','Attribute','MatHang.MoTa',  N'Mô tả mặt hàng'),
('Dim_MatHang','KichCo',    'NVARCHAR(50)', 'Attribute','MatHang.KichCo',N'Kích cỡ: Lớn/Vừa/Nhỏ'),
('Dim_MatHang','TrongLuong','FLOAT',        'Attribute','MatHang.TrongLuong',N'Trọng lượng (kg)'),
('Dim_MatHang','DonGia',    'DECIMAL(18,2)','Attribute','MatHang.DonGia',N'Đơn giá'),

-- Dim_VPDD
('Dim_VPDD','MaThanhPho', 'VARCHAR(10)',  'PK','VanPhongDaiDien.MaThanhPho',   N'Khóa chính'),
('Dim_VPDD','TenThanhPho','NVARCHAR(100)','Attribute','VanPhongDaiDien.TenThanhPho',N'Tên thành phố'),
('Dim_VPDD','Bang',       'NVARCHAR(50)', 'Attribute','VanPhongDaiDien.Bang',   N'Bang/Miền — phân cấp trên Thành phố'),
('Dim_VPDD','DiaChi',     'NVARCHAR(255)','Attribute','VanPhongDaiDien.DiaChiVP',N'Địa chỉ văn phòng đại diện'),

-- Dim_CuaHang
('Dim_CuaHang','MaCuaHang','VARCHAR(10)', 'PK','CuaHang.MaCuaHang',         N'Khóa chính'),
('Dim_CuaHang','MaThanhPho','VARCHAR(10)','FK','CuaHang.MaThanhPhoVanPhong',N'Thành phố → Dim_VPDD'),
('Dim_CuaHang','Bang',     'NVARCHAR(50)','Attribute','VanPhongDaiDien.Bang', N'Bang/Miền — phân cấp trên Thành phố'),
('Dim_CuaHang','SDT',      'VARCHAR(20)', 'Attribute','CuaHang.SoDienThoai',  N'Số điện thoại cửa hàng');

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
('Dim_ThoiGian', 'Thời gian', 1, N'Năm',   'Nam',   N'Cấp cao nhất'),
('Dim_ThoiGian', 'Thời gian', 2, N'Quý',   'Quy',   N'Quý trong năm'),
('Dim_ThoiGian', 'Thời gian', 3, N'Tháng', 'Thang', N'Cấp thấp nhất'),

-- Chiều Địa điểm (Cửa hàng)
('Dim_CuaHang', 'Địa điểm cửa hàng', 1, N'Bang',       'Bang',       N'Miền Bắc/Trung/Nam'),
('Dim_CuaHang', 'Địa điểm cửa hàng', 2, N'Thành phố',  'MaThanhPho', N'Thành phố của cửa hàng'),
('Dim_CuaHang', 'Địa điểm cửa hàng', 3, N'Cửa hàng',   'MaCuaHang',  N'Cấp thấp nhất'),

-- Chiều Khách hàng
('Dim_KhachHang', 'Khách hàng', 1, N'Loại khách hàng', 'LoaiKhachHang', N'Du lịch / Bưu điện / Thường'),
('Dim_KhachHang', 'Khách hàng', 2, N'Khách hàng',      'MaKH',          N'Cấp thấp nhất');

-- ========================
-- 4. CẬP NHẬT RowCount trong Meta_Tables
-- ========================
UPDATE Meta_Tables SET RowCount = (SELECT COUNT(*) FROM Fact_BanHang)  WHERE TableName = 'Fact_BanHang';
UPDATE Meta_Tables SET RowCount = (SELECT COUNT(*) FROM Fact_Kho)      WHERE TableName = 'Fact_Kho';
UPDATE Meta_Tables SET RowCount = (SELECT COUNT(*) FROM Dim_ThoiGian)  WHERE TableName = 'Dim_ThoiGian';
UPDATE Meta_Tables SET RowCount = (SELECT COUNT(*) FROM Dim_KhachHang) WHERE TableName = 'Dim_KhachHang';
UPDATE Meta_Tables SET RowCount = (SELECT COUNT(*) FROM Dim_MatHang)   WHERE TableName = 'Dim_MatHang';
UPDATE Meta_Tables SET RowCount = (SELECT COUNT(*) FROM Dim_VPDD)      WHERE TableName = 'Dim_VPDD';
UPDATE Meta_Tables SET RowCount = (SELECT COUNT(*) FROM Dim_CuaHang)   WHERE TableName = 'Dim_CuaHang';

-- ========================
-- 5. XEM KẾT QUẢ METADATA
-- ========================
SELECT TableName, TableType, RowCount, Description FROM Meta_Tables;
SELECT TableName, ColumnName, KeyType, Description FROM Meta_Columns ORDER BY TableName;
SELECT DimensionName, HierarchyName, LevelOrder, LevelName FROM Meta_Hierarchy ORDER BY DimensionName, LevelOrder;

PRINT N'✅ Metadata đã được tạo đầy đủ!';
