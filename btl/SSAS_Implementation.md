# Hướng Dẫn Triển Khai SSAS Multidimensional

## Thông tin môi trường

| Thành phần | Giá trị |
|---|---|
| SQL Server (dữ liệu) | `localhost\SQLEXPRESS` |
| Database | `DW_BanHang` |
| SSAS instance | `localhost\SSAS_DW` |
| SSAS Database (sau deploy) | `DW_BanHang_AS` |
| SQL Auth | `sa` / `123456` |

---

## Phase 1 — Tạo Project trong Visual Studio

1. Mở **Visual Studio 2022**
2. Bấm **"Create a new project"**
3. Ô search gõ: `Analysis Services`
4. Chọn template: **"Analysis Services Multidimensional and Data Mining Project"**
5. Bấm **Next**
6. Điền:
   - **Project name:** `DW_BanHang_SSAS`
   - **Location:** `C:\Users\ASUS\Desktop\data-mini\btl\ssas`
7. Bấm **Create**

> Kết quả: VS mở project mới với Solution Explorer bên phải có các thư mục:
> `Data Sources`, `Data Source Views`, `Dimensions`, `Cubes`, `Mining Structures`

---

## Phase 2 — Tạo Data Source

> Đây là kết nối từ SSAS → SQL Server (DW_BanHang tại SQLEXPRESS)

### Bước 2.1
Trong **Solution Explorer** (panel phải):
- Chuột phải vào **"Data Sources"**
- Chọn **"New Data Source..."**

### Bước 2.2 — Wizard mở ra
- Màn hình "Welcome" → bấm **Next**

### Bước 2.3 — Select how to define the connection
- Chọn: **"Create a data source based on an existing or new connection"**
- Bấm **"New..."**

### Bước 2.4 — Connection Manager
Điền thông tin:
| Trường | Giá trị |
|---|---|
| Provider | `Native OLE DB\SQL Server Native Client 11.0` |
| Server name | `localhost\SQLEXPRESS` |
| Authentication | `Use SQL Server Authentication` |
| User name | `sa` |
| Password | `123456` |
| Database | `DW_BanHang` |

→ Bấm **"Test Connection"** → phải hiện "Test connection succeeded"  
→ Bấm **OK**

### Bước 2.5
- Màn hình "Impersonation Information":
  - Chọn **"Use the service account"**
- Bấm **Next**

### Bước 2.6
- Data source name: `DW_BanHang`
- Bấm **Finish** ✅

---

## Phase 3 — Tạo Data Source View (DSV)

> DSV là "sơ đồ" cho SSAS thấy cấu trúc bảng và quan hệ giữa chúng

### Bước 3.1
Trong **Solution Explorer**:
- Chuột phải **"Data Source Views"**
- Chọn **"New Data Source View..."**

### Bước 3.2 — Chọn Data Source
- Chọn `DW_BanHang` vừa tạo
- Bấm **Next**

### Bước 3.3 — Chọn bảng ⚠️ QUAN TRỌNG
Ở danh sách **Available objects**, chọn **tất cả 7 bảng** (giữ Ctrl + click từng cái):
```
Dim_CuaHang
Dim_KhachHang
Dim_MatHang
Dim_ThoiGian
Dim_VPDD
Fact_BanHang
Fact_Kho
```
→ Bấm **">"** để chuyển sang **Included objects**  
→ Bấm **Next**

### Bước 3.4
- Name: `DW_BanHang`
- Bấm **Finish** ✅

> Kết quả: DSV Designer mở ra, hiển thị 7 bảng với đường nối (quan hệ) giữa chúng.
> Nếu thấy các đường nối đã tự động xuất hiện = đúng (SSAS đọc FK từ DB).
> Nếu không thấy đường nối → làm thêm Bước 3.5.

### Bước 3.5 — Kiểm tra relationship (nếu thiếu)
Trong DSV Designer, chuột phải vùng trắng → **"New Relationship"** → tạo từng cái:

| From Table / Column | To Table / Column |
|---|---|
| `Fact_BanHang.MaKhachHang` | `Dim_KhachHang.MaKhachHang` |
| `Fact_BanHang.MaMatHang` | `Dim_MatHang.MaMatHang` |
| `Fact_BanHang.MaThoiGian` | `Dim_ThoiGian.MaThoiGian` |
| `Fact_Kho.MaMatHang` | `Dim_MatHang.MaMatHang` |
| `Fact_Kho.MaCuaHang` | `Dim_CuaHang.MaCuaHang` |
| `Fact_Kho.MaThoiGian` | `Dim_ThoiGian.MaThoiGian` |
| `Dim_CuaHang.MaThanhPho` | `Dim_VPDD.MaThanhPho` |
| `Dim_KhachHang.MaThanhPho` | `Dim_VPDD.MaThanhPho` |

---

## Phase 4 — Tạo 5 Dimensions

> Mỗi dimension tương ứng 1 bảng Dim_*

---

### Dimension 1: Dim_ThoiGian

**Bước 4.1.1** — Trong Solution Explorer → chuột phải **"Dimensions"** → **"New Dimension..."**

**Bước 4.1.2** — Wizard:
- "Select Creation Method": chọn **"Use an existing table"** → Next

**Bước 4.1.3** — Specify Source Information:
| Trường | Giá trị |
|---|---|
| Data source view | `DW_BanHang` |
| Main table | `Dim_ThoiGian` |
| Key columns | `MaThoiGian` |
| Name column | `Thang` |

→ Next

**Bước 4.1.4** — Select Dimension Attributes:
Tick các cột sau:
```
☑ Thang
☑ Quy
☑ Nam
```
→ Next

**Bước 4.1.5** — Name: `Dim ThoiGian` → **Finish** ✅

**Bước 4.1.6** — Tạo Hierarchy trong Dimension Designer vừa mở:
- Tab **"Dimension Structure"**
- Kéo `Nam` từ Attributes vào vùng **Hierarchies** → đổi tên hierarchy thành `Thoi Gian`
- Kéo tiếp `Quy` vào dưới `Nam`
- Kéo tiếp `Thang` vào dưới `Quy`

> Kết quả hierarchy: `Nam` → `Quy` → `Thang`

---

### Dimension 2: Dim_VPDD

**Bước 4.2.1** — Chuột phải **"Dimensions"** → **"New Dimension..."**

**Bước 4.2.2**:
- Creation Method: **"Use an existing table"** → Next
- Main table: `Dim_VPDD`
- Key columns: `MaThanhPho`
- Name column: `TenThanhPho`
→ Next

**Bước 4.2.3** — Tick attributes:
```
☑ TenThanhPho
☑ Bang
☑ DiaChi
```
→ Next → Name: `Dim VPDD` → **Finish** ✅

**Bước 4.2.4** — Tạo Hierarchy `Dia Ly`:
- Kéo `Bang` vào Hierarchies → đặt tên `Dia Ly`
- Kéo `TenThanhPho` vào dưới `Bang`

---

### Dimension 3: Dim_KhachHang

**Bước 4.3.1** — New Dimension:
- Main table: `Dim_KhachHang`
- Key: `MaKhachHang`
- Name column: `TenKhachHang`
→ Next

**Bước 4.3.2** — Tick attributes:
```
☑ TenKhachHang
☑ LoaiKhachHang
☑ MaThanhPho
```
→ Next → Name: `Dim KhachHang` → **Finish** ✅

**Bước 4.3.3** — Tạo Hierarchy `Phan Loai KH`:
- Kéo `LoaiKhachHang` vào Hierarchies → đặt tên `Phan Loai KH`
- Kéo `MaKhachHang` vào dưới

---

### Dimension 4: Dim_MatHang

**Bước 4.4.1** — New Dimension:
- Main table: `Dim_MatHang`
- Key: `MaMatHang`
- Name column: `MoTa`
→ Next

**Bước 4.4.2** — Tick:
```
☑ MoTa
☑ KichCo
☑ TrongLuong
☑ DonGia
```
→ Next → Name: `Dim MatHang` → **Finish** ✅

---

### Dimension 5: Dim_CuaHang

**Bước 4.5.1** — New Dimension:
- Main table: `Dim_CuaHang`
- Key: `MaCuaHang`
- Name column: `MaCuaHang`
→ Next

**Bước 4.5.2** — Tick:
```
☑ MaThanhPho
☑ SoDienThoai
```
→ Next → Name: `Dim CuaHang` → **Finish** ✅

---

## Phase 5 — Tạo Cube

### Bước 5.1
Trong Solution Explorer → chuột phải **"Cubes"** → **"New Cube..."**

### Bước 5.2
- Creation Method: **"Use existing tables"** → Next

### Bước 5.3 — Select Measure Group Tables ⚠️
Tick **cả 2 bảng Fact**:
```
☑ Fact_BanHang
☑ Fact_Kho
```
→ Next

### Bước 5.4 — Select Measures ⚠️
Bỏ tick những cột không cần, **giữ lại**:

**Fact BanHang:**
```
☑ So Luong Ban   (SoLuongBan)
☑ Doanh Thu      (DoanhThu)
☑ Fact Ban Hang Count
```

**Fact Kho:**
```
☑ So Luong Ton Kho   (SoLuongTonKho)
☑ Gia Tri Ton Kho    (GiaTriTonKho)
☑ Fact Kho Count
```
→ Next

### Bước 5.5 — Select Existing Dimensions
Tick **tất cả 5 dimensions** vừa tạo:
```
☑ Dim ThoiGian
☑ Dim VPDD
☑ Dim KhachHang
☑ Dim MatHang
☑ Dim CuaHang
```
→ Next

### Bước 5.6
- Cube name: `DW BanHang`
- Bấm **Finish** ✅

### Bước 5.7 — Kiểm tra Dimension Usage
Trong **Cube Designer** → tab **"Dimension Usage"**:

Kiểm tra bảng sau (các ô có ký hiệu = đã link, ô trống = chưa link):

| | Dim ThoiGian | Dim KhachHang | Dim MatHang | Dim CuaHang | Dim VPDD |
|---|---|---|---|---|---|
| **Fact BanHang** | Regular | Regular | Regular | - | - |
| **Fact Kho** | Regular | - | Regular | Regular | - |

> Nếu ô nào để trống mà cần link: double-click ô đó → chọn Regular → chọn cột khóa tương ứng.

---

## Phase 6 — Cấu hình Deploy + Deploy

### Bước 6.1 — Cấu hình deployment server
- Chuột phải **project** (DW_BanHang_SSAS) trong Solution Explorer → **"Properties"**
- Tab **"Deployment"**:

| Trường | Giá trị |
|---|---|
| Server | `localhost\SSAS_DW` |
| Database | `DW_BanHang_AS` |

→ Bấm **OK**

### Bước 6.2 — Deploy
- Menu **Build** → **"Deploy DW_BanHang_SSAS"**
- Chờ Output window hiển thị: `========== Deploy: 1 succeeded ==========`

### Bước 6.3 — Process Full
- Trong SSMS → kết nối tới `localhost\SSAS_DW` chọn **Analysis Services**
- Expand: `DW_BanHang_AS` → `Cubes` → `DW BanHang`
- Chuột phải → **"Process..."** → **Process Full** → **OK**
- Chờ hoàn tất → **Close**

### Bước 6.4 — Test MDX trong SSMS
Mở **New MDX Query** → chạy thử:
```mdx
SELECT [Measures].[Doanh Thu] ON COLUMNS,
       [Dim ThoiGian].[Thoi Gian].[Nam].MEMBERS ON ROWS
FROM [DW BanHang];
```
> Nếu ra bảng số liệu = thành công ✅

---

## Phase 7 — Cập nhật Webapp

### Bước 7.1 — Cài package
```bash
cd C:\Users\ASUS\Desktop\data-mini\btl\webapp
npm install node-adodb
```

### Bước 7.2 — Thêm vào đầu `server.js`
```javascript
const ADODB = require('node-adodb');

// Kết nối SSAS — KHÔNG phải SQLEXPRESS
const ssasConn = ADODB.open(
  'Provider=MSOLAP;' +
  'Data Source=localhost\\SSAS_DW;' +
  'Initial Catalog=DW_BanHang_AS;' +
  'Integrated Security=SSPI;'
);

async function runMDX(mdx) {
  const result = await ssasConn.query(mdx);
  return result;
}
```

### Bước 7.3 — Đổi các endpoint OLAP sang MDX

**`/api/drilldown`:**
```javascript
// Mức Năm
const mdx = `
  SELECT [Measures].[Doanh Thu] ON COLUMNS,
         [Dim ThoiGian].[Thoi Gian].[Nam].MEMBERS ON ROWS
  FROM [DW BanHang]`;

// Mức Quý (khi có @nam)
const mdx = `
  SELECT [Measures].[Doanh Thu] ON COLUMNS,
         [Dim ThoiGian].[Thoi Gian].[Quy].MEMBERS ON ROWS
  FROM [DW BanHang]
  WHERE [Dim ThoiGian].[Nam].&[${nam}]`;

// Mức Tháng (khi có @nam + @quy)
const mdx = `
  SELECT [Measures].[Doanh Thu] ON COLUMNS,
         [Dim ThoiGian].[Thoi Gian].[Thang].MEMBERS ON ROWS
  FROM [DW BanHang]
  WHERE ([Dim ThoiGian].[Nam].&[${nam}],
         [Dim ThoiGian].[Quy].&[${quy}])`;
```

**`/api/rollup`:**
```javascript
// Mức Bang
const mdx = `
  SELECT [Measures].[Ton Kho] ON COLUMNS,
         [Dim CuaHang].[Dia Diem CH].[Bang].MEMBERS ON ROWS
  FROM [DW BanHang]`;

// Mức ThanhPho
const mdx = `
  SELECT [Measures].[Ton Kho] ON COLUMNS,
         [Dim CuaHang].[Dia Diem CH].[TenThanhPho].MEMBERS ON ROWS
  FROM [DW BanHang]`;
```

**`/api/slice`:**
```javascript
const mdx = `
  SELECT [Measures].[Doanh Thu] ON COLUMNS,
         [Dim ThoiGian].[Thoi Gian].[Nam].MEMBERS ON ROWS
  FROM [DW BanHang]
  WHERE [Dim KhachHang].[Phan Loai KH].[LoaiKhachHang].&[${loai}]`;
```

**`/api/pivot`:**
```javascript
const mdx = `
  SELECT [Dim KhachHang].[LoaiKhachHang].MEMBERS ON COLUMNS,
         [Dim ThoiGian].[Thoi Gian].[Nam].MEMBERS ON ROWS
  FROM [DW BanHang]
  WHERE [Measures].[Doanh Thu]`;
```

> **9 câu queries nghiệp vụ (Q1–Q9):** Giữ nguyên `mssql` + SQL — KHÔNG cần đổi.

---

## Phase 8 — Dọn dẹp OLAP_Cubes.sql

Sau khi SSAS hoạt động ổn, trong `OLAP_Cubes.sql`:

**Xóa** phần PHẦN 1 (Cube tables):
```
-- Xóa: IF OBJECT_ID('Cube_DoanhThu' ...) DROP TABLE ...
-- Xóa: CREATE TABLE Cube_DoanhThu ...
-- Xóa: CREATE TABLE Cube_TonKho ...
-- Xóa: CREATE TABLE Cube_KhachHang ...
```

**Xóa** phần PHẦN 2 (5 Stored Procedures):
```
-- Xóa: sp_DrillDown_ThoiGian
-- Xóa: sp_RollUp_DiaDiem
-- Xóa: sp_Slice_DoanhThu
-- Xóa: sp_Dice_TonKho
-- Xóa: sp_Pivot_DoanhThu
```

**Giữ nguyên:** Phần PHẦN 3 — 9 câu truy vấn nghiệp vụ Q1–Q9.

---

## Tóm tắt instance — tránh nhầm lẫn

| Dùng ở đâu | Instance |
|---|---|
| SQL Server (DW_BanHang data) | `localhost\SQLEXPRESS` |
| Data Source trong VS (Phase 2) | `localhost\SQLEXPRESS` ← lấy dữ liệu |
| Deployment Server trong VS (Phase 6) | `localhost\SSAS_DW` ← deploy cube |
| SSMS kết nối Analysis Services | `localhost\SSAS_DW` ← kiểm tra |
| `node-adodb` trong server.js | `localhost\SSAS_DW` ← webapp query |
