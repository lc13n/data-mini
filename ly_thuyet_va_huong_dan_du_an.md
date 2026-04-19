# Lý Thuyết Kho Dữ Liệu & Hướng Dẫn Thực Hiện Dự Án

> **Môn học:** Kho Dữ Liệu (Data Mining & Data Warehouse)  
> **Tài liệu tham chiếu:** DMDWv1.2.docx.pdf + Đề bài BTL  
> **Mục đích:** Nắm vững lý thuyết và ánh xạ trực tiếp vào từng bước triển khai dự án

---

## MỤC LỤC

1. [Tổng quan về Kho Dữ Liệu](#1-tổng-quan-về-kho-dữ-liệu)
2. [Kiến trúc hệ thống Kho Dữ Liệu](#2-kiến-trúc-hệ-thống-kho-dữ-liệu)
3. [Mô hình dữ liệu đa chiều](#3-mô-hình-dữ-liệu-đa-chiều)
4. [OLAP và các phép toán cơ bản](#4-olap-và-các-phép-toán-cơ-bản)
5. [Bước 1 – Tích hợp 2 nguồn dữ liệu thành IDB](#5-bước-1--tích-hợp-2-nguồn-dữ-liệu-thành-idb)
6. [Bước 2 – Thiết kế mô hình DW (Fact + Dimension)](#6-bước-2--thiết-kế-mô-hình-dw-fact--dimension)
7. [Bước 3 – Sinh dữ liệu và đổ dữ liệu ETL vào DW](#7-bước-3--sinh-dữ-liệu-và-đổ-dữ-liệu-etl-vào-dw)
8. [Bước 4 – Xác định phân cấp và xây dựng khối OLAP](#8-bước-4--xác-định-phân-cấp-và-xây-dựng-khối-olap)
9. [Bước 5 – Tạo Metadata và Index](#9-bước-5--tạo-metadata-và-index)
10. [Bước 6 – Giao diện Web OLAP](#10-bước-6--giao-diện-web-olap)
11. [9 Câu Truy Vấn Nghiệp Vụ](#11-9-câu-truy-vấn-nghiệp-vụ)
12. [Bảng điểm và checklist hoàn thiện](#12-bảng-điểm-và-checklist-hoàn-thiện)

---

## 1. Tổng Quan về Kho Dữ Liệu

### 1.1 Kho Dữ Liệu là gì?

**Kho dữ liệu (Data Warehouse - DW)** là một hệ thống tổng hợp dữ liệu từ nhiều nguồn khác nhau, được tổ chức và lưu trữ để phục vụ mục đích **phân tích và hỗ trợ quyết định** (Decision Support System), chứ không phải cho việc xử lý giao dịch hàng ngày.

> **Định nghĩa (W.H. Inmon):** "Kho dữ liệu là một tập hợp dữ liệu **hướng chủ đề** (subject-oriented), **tích hợp** (integrated), **không thay đổi** (non-volatile) và **biến thiên theo thời gian** (time-variant) được sử dụng để hỗ trợ quá trình ra quyết định của ban quản lý."

### 1.2 Bốn đặc trưng cốt lõi (theo tài liệu DMDW)

| Đặc trưng | Ý nghĩa | Ví dụ trong dự án |
|-----------|---------|-------------------|
| **Hướng chủ đề** | Dữ liệu tổ chức theo chủ đề nghiệp vụ (bán hàng, tồn kho), không theo ứng dụng | `Fact_BanHang`, `Fact_Kho` |
| **Tích hợp** | Dữ liệu từ nhiều CSDL nguồn được chuẩn hóa thành một định dạng thống nhất | Tích hợp từ `csdl_banhang` (gồm 2 DB ban đầu) |
| **Không thay đổi** | Dữ liệu trong DW chỉ được thêm vào, không sửa/xóa tùy tiện | ETL xóa sạch rồi nạp lại (Full Load) |
| **Biến thiên theo thời gian** | Mỗi bản ghi đều gắn với mốc thời gian | `TimeKey` → `Dim_ThoiGian` (Tháng/Quý/Năm) |

### 1.3 So sánh OLTP vs OLAP vs DW

| Tiêu chí | CSDL tác nghiệp (OLTP) | Kho dữ liệu (DW/OLAP) |
|---------|----------------------|----------------------|
| **Mục đích** | Xử lý giao dịch hàng ngày | Phân tích, báo cáo, hỗ trợ quyết định |
| **Dữ liệu** | Hiện tại, chi tiết | Lịch sử, tổng hợp |
| **Thao tác** | INSERT, UPDATE, DELETE | SELECT, GROUP BY, tổng hợp |
| **Người dùng** | Nhân viên nghiệp vụ | Nhà quản lý, nhà phân tích |
| **Câu hỏi trả lời** | "Ai mua hàng hôm nay?" | "Doanh thu Q3/2024 theo loại KH là bao nhiêu?" |

---

## 2. Kiến Trúc Hệ Thống Kho Dữ Liệu

### 2.1 Kiến trúc 4 tầng (từ tài liệu DMDW)

```
┌────────────────────────────────────────────────────────┐
│  TẦNG 4: Người Sử Dụng (NSD)                          │
│  → Giao diện Web, Báo cáo, Dashboard                  │
├────────────────────────────────────────────────────────┤
│  TẦNG 3: Xử lý phân tích & Khai phá                   │
│  → OLAP Engine (Drill Down, Roll Up, Slice, Dice...)   │
│  → Các Stored Procedures, Pre-computed Cubes           │
├────────────────────────────────────────────────────────┤
│  TẦNG 2: Kho Dữ Liệu + Siêu Dữ Liệu                  │
│  → DW_BanHang: Fact_BanHang, Fact_Kho                 │
│  → Dim_ThoiGian, Dim_KhachHang, Dim_MatHang...        │
│  → Metadata: Meta_Tables, Meta_Columns, Meta_Hierarchy │
├────────────────────────────────────────────────────────┤
│  TẦNG 1: Nguồn Dữ Liệu + ETL                          │
│  → csdl_banhang (IDB - Integrated Database)            │
│  → Script ETL: ETL_IDB_to_DW.sql                      │
│  → Nguồn gốc: 2 CSDL ban đầu (VanPhong + BanHang)    │
└────────────────────────────────────────────────────────┘
```

### 2.2 Luồng dữ liệu trong dự án

```
[CSDL Văn phòng đại diện]  [CSDL Bán hàng]
         │                        │
         └──────────┬─────────────┘
                    ▼
          [BƯỚC 1: Reverse Engineering]
          Chuyển ER ngược → Tích hợp IER
                    │
                    ▼
          [IDB: csdl_banhang]  ← Nguồn duy nhất tích hợp
          (9 bảng quan hệ)
                    │
                    ▼
          [BƯỚC 3: ETL - ETL_IDB_to_DW.sql]
          Extract → Transform → Load
                    │
                    ▼
          [DW_BanHang]
          ├── Dim_ThoiGian
          ├── Dim_KhachHang
          ├── Dim_MatHang
          ├── Dim_VPDD
          ├── Dim_CuaHang
          ├── Fact_BanHang
          └── Fact_Kho
                    │
                    ▼
          [BƯỚC 4: OLAP Cubes]
          Cube_DoanhThu, Cube_TonKho, Cube_KhachHang
          + Stored Procedures (Drill Down, Roll Up, Slice, Dice, Pivot)
                    │
                    ▼
          [BƯỚC 5: Metadata]
          Meta_Tables, Meta_Columns, Meta_Hierarchy
                    │
                    ▼
          [BƯỚC 6: Web App - Flask]
          Giao diện OLAP trực tuyến
```

---

## 3. Mô Hình Dữ Liệu Đa Chiều

### 3.1 Khái niệm Khối Dữ Liệu (Data Cube)

Theo tài liệu DMDW: *"Một khối dữ liệu cho phép dữ liệu được mô hình hóa và xem ở nhiều chiều (thuộc tính) khác nhau."*

- **Bảng theo chiều (Dimension Table):** Mô tả ngữ cảnh của sự kiện — KH là ai, hàng gì, khi nào
- **Bảng sự kiện (Fact Table):** Lưu trữ các **độ đo** (measure) — doanh thu, số lượng

**Ví dụ trong dự án:** Doanh thu = `SoLuongBan` × `DoanhThu` được phân tích theo 3 chiều:
- Chiều **Khách hàng** (Dim_KhachHang)
- Chiều **Mặt hàng** (Dim_MatHang)
- Chiều **Thời gian** (Dim_ThoiGian)

### 3.2 Ba loại lược đồ (từ tài liệu DMDW)

#### Lược đồ Hình Sao (Star Schema) ⭐

```
           Dim_ThoiGian
               │
Dim_KhachHang──┤
               │   Fact_BanHang   ├──Dim_MatHang
               │   (TimeKey,      │
               ├── MaKhachHang,   │
                   MaMatHang,
                   SoLuongBan,
                   DoanhThu)
```

**Dự án này dùng lược đồ Hình Sao:** Một bảng Fact ở trung tâm, các bảng Dim xung quanh. Đây là cấu trúc đơn giản, dễ truy vấn OLAP.

#### Lược đồ Hình Bông Tuyết (Snowflake Schema)
Chuẩn hóa các Dim có phân cấp thành nhiều bảng nhỏ hơn. Ví dụ: `Dim_CuaHang → Dim_ThanhPho → Dim_Bang`. **Dự án không dùng để đơn giản hóa việc query.**

#### Lược đồ Dải Thiên Hà (Galaxy Schema) — **Dự án này dùng!**

```
Dim_MatHang ──┬── Fact_BanHang ──┬── Dim_KhachHang
              │                  └── Dim_ThoiGian
              └── Fact_Kho ──────┬── Dim_CuaHang
                                 └── Dim_ThoiGian (dùng chung!)
```

Dự án có **2 bảng Fact** (`Fact_BanHang` và `Fact_Kho`) cùng chia sẻ `Dim_ThoiGian` và `Dim_MatHang` → đây là **lược đồ dải thiên hà**.

### 3.3 Phân cấp chiều (Dimension Hierarchy)

Theo DMDW: Chiều phân cấp cho phép thực hiện **Roll Up** (gom nhóm lên mức cao hơn) và **Drill Down** (đi xuống mức chi tiết hơn).

| Chiều | Phân cấp trong dự án |
|-------|---------------------|
| **Thời gian** | Tháng → Quý → Năm |
| **Địa điểm cửa hàng** | Cửa hàng → Thành phố → Bang |
| **Khách hàng** | Khách hàng → Loại KH (Du lịch/Bưu điện/Thường) |

---

## 4. OLAP và Các Phép Toán Cơ Bản

### 4.1 OLAP là gì?

**OLAP (Online Analytical Processing)** là một hệ thống hỗ trợ truy vấn và phân tích dữ liệu đa chiều một cách nhanh chóng. OLAP khác với CSDL thông thường ở chỗ nó hỗ trợ các phép toán:

### 4.2 Năm phép toán OLAP (từ tài liệu DMDW)

#### 🔽 Drill Down (Khoan xuống)
> Đi từ mức tổng quát → chi tiết hơn theo phân cấp chiều

```sql
-- Dự án: Từ Năm → Quý → Tháng
EXEC sp_DrillDown_ThoiGian             -- Xem theo Năm (tổng quát)
EXEC sp_DrillDown_ThoiGian @Nam=2024   -- Xem theo Quý trong năm 2024
EXEC sp_DrillDown_ThoiGian @Nam=2024, @Quy=3  -- Xem từng Tháng trong Q3/2024
```

#### 🔼 Roll Up (Cuộn lên)
> Đi từ mức chi tiết → tổng quát hơn (ngược lại với Drill Down)

```sql
-- Dự án: Từ Cửa hàng → Thành phố → Bang
EXEC sp_RollUp_DiaDiem @MucDo='CuaHang'   -- Chi tiết từng cửa hàng
EXEC sp_RollUp_DiaDiem @MucDo='ThanhPho'  -- Gom theo thành phố
EXEC sp_RollUp_DiaDiem @MucDo='Bang'      -- Gom theo bang (tổng quát nhất)
```

#### ✂️ Slice (Cắt lát)
> Cố định **một chiều** tại một giá trị cụ thể, xem dữ liệu trên các chiều còn lại

```sql
-- Dự án: Cắt theo Loại Khách hàng = 'Du lịch'
EXEC sp_Slice_DoanhThu @LoaiKhachHang = N'Du lịch'

-- Cắt theo Năm = 2024
EXEC sp_Slice_DoanhThu @Nam = 2024

-- Cắt theo Kích cỡ = 'L'
EXEC sp_Slice_DoanhThu @KichCo = 'L'
```

#### 🎲 Dice (Cắt khối)
> Cố định **nhiều chiều** cùng lúc (giao điểm của nhiều Slice)

```sql
-- Dự án: Cắt theo Thành phố + Mặt hàng + Khoảng thời gian
EXEC sp_Dice_TonKho 
    @MaThanhPho = 'VP1', 
    @MaMatHang  = 'MH1', 
    @NamFrom    = 2023, 
    @NamTo      = 2024
```

#### 🔄 Pivot (Xoay)
> Hoán đổi vai trò của các chiều, trình bày dữ liệu dạng ma trận chéo

```sql
-- Dự án: Doanh thu theo Năm (dòng) × Loại KH (cột)
EXEC sp_Pivot_DoanhThu
-- Kết quả:
-- Nam | Du lich | Buu dien | DL_BD | Thuong
-- 2023|  12000  |   8500   |  3200 |  5600
-- 2024|  15000  |   9200   |  4100 |  6800
```

---

## 5. Bước 1 – Tích Hợp 2 Nguồn Dữ Liệu Thành IDB

### 5.1 Lý thuyết: Kỹ thuật Reverse Engineering

Theo DMDW: *"Bước thứ nhất được gọi là công nghệ chuyển đổi ngược từ các lược đồ quan hệ sang mô hình thực thể liên kết mở rộng. Bước này được gọi là chuyển đổi ngược bởi vì thông thường khi xây dựng hệ thống CSDL chúng ta thường mô tả yêu cầu thông qua mô hình ER rồi dùng kỹ thuật chuyển đổi từ mô hình ER sang lược đồ quan hệ."*

**Quy trình 3 bước tích hợp:**
1. **Reverse Engineering:** Chuyển các bảng quan hệ → mô hình EER cho từng CSDL nguồn
2. **Schema Integration:** Tích hợp 2 mô hình EER thành 1 mô hình IER thống nhất
3. **Forward Engineering:** Chuyển IER → các bảng trong IDB, đổ dữ liệu vào

### 5.2 Phân loại quan hệ (theo DMDW)

Khi Reverse Engineering, ta phân loại từng bảng:

| Loại | Định nghĩa | Ví dụ trong dự án |
|------|-----------|-------------------|
| **PR1** (Primary Relation 1) | Khóa chính KHÔNG chứa khóa của bảng khác | `VanPhongDaiDien`, `KhachHang`, `MatHang`, `CuaHang` |
| **PR2** (Primary Relation 2) | Khóa chính CÓ CHỨA khóa của bảng khác | `KhachHangDuLich`, `KhachHangBuuDien` |
| **SR1** (Secondary Relation 1) | Khóa chính hình thành hoàn toàn từ khóa chính các bảng khác | `MatHang_DuocLuuTru`, `MatHangDuocDat` |
| **FKA** | Thuộc tính khóa ngoại trong bảng chính | `MaThanhPhoKhachHang` trong `KhachHang` |

### 5.3 Hai CSDL nguồn trong dự án

**CSDL Văn phòng đại diện** (từ đề bài):
```
KhachHang     (MaKH, TenKH, MaThanhPho, NgayDatHangDauTien)  ← PR1
KhachHangDuLich  (*MaKH, HuongDanVien, ThoiGianMua)          ← PR2
KhachHangBuuDien (*MaKH, DiaChiBuuDien, ThoiGianTaoTK)      ← PR2
```

**CSDL Bán hàng** (từ đề bài):
```
VanPhongDaiDien (MaThanhPho, TenThanhPho, DiaChiVP, Bang, TG) ← PR1
CuaHang         (MaCuaHang, *MaThanhPhoVanPhong, SDT, TG)     ← PR1+FKA
MatHang         (MaMH, MoTa, KichCo, TrongLuong, Gia, TG)     ← PR1
MatHang_DuocLuuTru  (*MaCuaHang, *MaMH, SoLuong, TG)         ← SR1
DonDatHang      (MaDon, NgayDatHang, MaKhachHang)             ← PR1+FKA
MatHangDuocDat  (*MaDon, *MaMH, SoLuongDat, GiaDat, TG)      ← SR1
```

### 5.4 Kết quả: IDB tích hợp (`csdl_banhang`)

Sau khi tích hợp, IDB gồm **9 bảng** trong `taoBang_new.sql`:

```sql
VanPhongDaiDien (MaThanhPho PK, TenThanhPho, DiaChiVP, Bang, ThoiGianBatDauHoatDong)
KhachHang       (MaKH PK, TenKH, MaThanhPhoKhachHang FK→VP, NgayDatHangDauTien)
KhachHangDuLich (MaKH PK+FK→KH, HuongDanVienDuLich, ThoiGianMua)
KhachHangBuuDien(MaKH PK+FK→KH, DiaChiBuuDien, ThoiGianTaoTaiKhoan)
CuaHang         (MaCuaHang PK, MaThanhPhoVanPhong FK→VP, SoDienThoai, ...)
MatHang         (MaMH PK, MoTa, KichCo, TrongLuong, DonGia, ...)
MatHang_DuocLuuTru (MaCuaHang FK+MaMatHang FK, SoLuongTrongKho, ThoiGianCapNhat)
DonDatHang      (MaDon PK, NgayDatHang, MaKhachHang FK→KH)
MatHangDuocDat  (MaDon FK+MaMatHang FK, SoLuongDat, GiaDat, ...)
```

---

## 6. Bước 2 – Thiết Kế Mô Hình DW (Fact + Dimension)

### 6.1 Lý thuyết: Thiết kế kho dữ liệu

Theo DMDW: *"Nghiên cứu yêu cầu của kho dữ liệu để xây dựng mô hình dữ liệu cho kho DW: gồm mấy bảng fact, độ đo trong bảng fact là gì; bảng theo chiều có mấy bảng, gồm những chiều gì."*

**Câu hỏi thiết kế cần trả lời:**
1. Đơn vị phân tích (grain) là gì?
2. Cần bao nhiêu bảng Fact?
3. Mỗi Fact có những độ đo (measure) nào?
4. Cần những chiều (dimension) nào?
5. Chiều nào có phân cấp?

### 6.2 Ánh xạ yêu cầu nghiệp vụ → Thiết kế

Từ 9 yêu cầu của đề bài, ta xác định:

| Yêu cầu đề bài | Cần thông tin gì? | → Bảng DW |
|---------------|------------------|-----------|
| Cửa hàng + mặt hàng bán ở kho | CuaHang ↔ MatHang | `Fact_Kho` + `Dim_CuaHang` + `Dim_MatHang` |
| Đơn hàng + tên KH + ngày đặt | KhachHang ↔ DonDatHang | `Fact_BanHang` + `Dim_KhachHang` + `Dim_ThoiGian` |
| Doanh thu theo loại KH | Phân loại KH | `Dim_KhachHang.LoaiKhachHang` |
| Tồn kho > ngưỡng | SoLuongTonKho | `Fact_Kho.SoLuongTonKho` |
| KH du lịch, bưu điện | Loại KH | `Dim_KhachHang.LoaiKhachHang` |

### 6.3 Thiết kế thực tế (file `taoBangFact_Dim_new.sql`)

#### Bảng Fact

```
Fact_BanHang:
  Grain: 1 dòng = 1 KH × 1 Mặt hàng × 1 Tháng
  Dimensions: MaKhachHang (FK), MaMatHang (FK), TimeKey (FK)
  Measures:   SoLuongBan (INT), DoanhThu (DECIMAL)

Fact_Kho:
  Grain: 1 dòng = 1 Mặt hàng × 1 Cửa hàng × 1 Tháng (snapshot)
  Dimensions: MaMatHang (FK), MaCuaHang (FK), TimeKey (FK)
  Measures:   SoLuongTonKho (INT)
```

#### Bảng Dimension

```
Dim_ThoiGian (TimeKey PK, Thang, Quy, Nam)
  → Phân cấp: Tháng → Quý → Năm

Dim_KhachHang (MaKH PK, TenKhachHang, MaThanhPho, LoaiKhachHang)
  → LoaiKhachHang: 'Du lịch' | 'Bưu điện' | 'Du lịch & Bưu điện' | 'Thường'

Dim_MatHang (MaMH PK, MoTa, KichCo, TrongLuong, DonGia)

Dim_VPDD (MaThanhPho PK, TenThanhPho, Bang, DiaChi)
  → Phân cấp: Thành phố → Bang

Dim_CuaHang (MaCuaHang PK, MaThanhPho FK→Dim_VPDD, Bang, SDT)
  → Phân cấp: Cửa hàng → Thành phố → Bang
```

#### Sơ đồ lược đồ dải thiên hà

```
Dim_ThoiGian ─────────────────────────────────────┐
                                                   │
Dim_KhachHang ──── Fact_BanHang ──── Dim_MatHang ─┤
                   (TimeKey FK) ←────────────────  │
                                                   │
Dim_CuaHang  ──── Fact_Kho ─────── Dim_MatHang    │
Dim_VPDD ←──────── (FK MaThanhPho)  (TimeKey FK) ──┘
```

---

## 7. Bước 3 – Sinh Dữ Liệu và Đổ Dữ Liệu ETL vào DW

### 7.1 Sinh dữ liệu (file `sinhdulieu_new.sql`)

Stored Procedure `Sp_SinhDuLieuLon_1000` sinh ngẫu nhiên **mỗi bảng 1000 dòng**:

```
VanPhongDaiDien  → 1000 văn phòng (VP1 → VP1000)
KhachHang        → 1000 khách hàng (KH1 → KH1000)
KhachHangDuLich  → 500 KH du lịch (KH1 → KH500)
KhachHangBuuDien → 500 KH bưu điện (KH501 → KH1000)
CuaHang          → 1000 cửa hàng (CH1 → CH1000)
MatHang          → 1000 mặt hàng (MH1 → MH1000)
DonDatHang       → 1000 đơn hàng (DH1 → DH1000)
MatHangDuocDat   → 1000 chi tiết đơn hàng
MatHang_DuocLuuTru → 1000 bản ghi kho
```

**Cách chạy:**
```sql
USE csdl_banhang;
EXEC Sp_SinhDuLieuLon_1000;
```

### 7.2 ETL: Extract – Transform – Load

Theo DMDW: *"Xác định cách thức để đổ dữ liệu từ IDB vào DW + Sinh dữ liệu cho các bảng của kho dữ liệu DW để chuẩn bị cho demo."*

**Dự án dùng Full Load** (file `ETL_IDB_to_DW.sql`):

| Bước | Thao tác | Chi tiết |
|------|---------|---------|
| **1. Xóa dữ liệu cũ** | `DELETE` theo thứ tự FK | Fact trước → Dim sau |
| **2. Nạp Dim_ThoiGian** | Sinh tháng từ ngày đặt hàng sớm nhất đến hiện tại | WHILE loop |
| **3. Nạp Dim_VPDD** | Lấy từ `VanPhongDaiDien` | 1:1 ánh xạ |
| **4. Nạp Dim_KhachHang** | JOIN 3 bảng KH để phân loại | CASE WHEN tạo `LoaiKhachHang` |
| **5. Nạp Dim_MatHang** | Lấy từ `MatHang` | 1:1 ánh xạ |
| **6. Nạp Dim_CuaHang** | JOIN `CuaHang` + `VanPhongDaiDien` | Lấy thêm cột `Bang` |
| **7. Nạp Fact_BanHang** | JOIN `DonDatHang` + `MatHangDuocDat` + `Dim_ThoiGian` | SUM theo grain |
| **8. Nạp Fact_Kho** | ROW_NUMBER lấy snapshot mới nhất mỗi cửa hàng/mặt hàng | Window function |
| **9. Tạo Index** | Index trên các FK của bảng Fact | Tối ưu truy vấn |

**Transform quan trọng – Phân loại khách hàng:**
```sql
-- Tại bước 4, ETL thực hiện transform:
CASE
    WHEN dl.MaKH IS NOT NULL AND bd.MaKH IS NOT NULL THEN 'Du lịch & Bưu điện'
    WHEN dl.MaKH IS NOT NULL                         THEN 'Du lịch'
    WHEN bd.MaKH IS NOT NULL                         THEN 'Bưu điện'
    ELSE                                                  'Thường'
END AS LoaiKhachHang
```

**Cách chạy:**
```sql
-- Phải dùng SQLCMD mode hoặc chạy từng phần
USE DW_BanHang;
-- Chạy toàn bộ ETL_IDB_to_DW.sql
```

---

## 8. Bước 4 – Xác Định Phân Cấp và Xây Dựng Khối OLAP

### 8.1 Lý thuyết: Pre-computed Cubes

Theo DMDW: *"Xác định các phân cấp nếu có của các chiều dữ liệu + Xây dựng các khối dữ liệu nhiều chiều cần thiết theo yêu cầu, lưu trữ sẵn các khối trong OLAP server để chuẩn bị cho việc khai thác."*

**Materialized View / Pre-computed Cube:** Thay vì JOIN toàn bộ bảng mỗi khi query, ta tính sẵn kết quả GROUP BY và lưu vào bảng `Cube_*`. Điều này giúp:
- Tăng tốc độ query OLAP lên nhiều lần
- Giảm tải cho server khi có nhiều người dùng cùng lúc

### 8.2 Ba khối OLAP trong dự án (file `OLAP_Cubes.sql`)

#### Cube_DoanhThu — Khối Doanh Thu

```
Chiều: LoaiKhachHang × MaThanhPhoKH × MaMatHang × KichCo × Nam × Quy × Thang
Độ đo: TongSoLuongBan, TongDoanhThu
Nguồn: Fact_BanHang JOIN Dim_KhachHang JOIN Dim_MatHang JOIN Dim_ThoiGian
```

**Trả lời câu hỏi:** "Doanh thu theo loại KH, theo mặt hàng, theo thời gian?"

#### Cube_TonKho — Khối Tồn Kho

```
Chiều: MaMatHang × KichCo × MaCuaHang × MaThanhPhoCH × TenThanhPho × Bang × Nam × Quy × Thang
Độ đo: TongTonKho
Nguồn: Fact_Kho JOIN Dim_MatHang JOIN Dim_CuaHang JOIN Dim_VPDD JOIN Dim_ThoiGian
```

**Trả lời câu hỏi:** "Tồn kho theo mặt hàng, cửa hàng, địa điểm, thời gian?"

#### Cube_KhachHang — Khối Phân Tích Khách Hàng

```
Chiều: LoaiKhachHang × MaThanhPho × TenThanhPho × Bang × Nam × Quy × Thang
Độ đo: SoLuongKH (COUNT DISTINCT), TongDoanhThu
Nguồn: Fact_BanHang JOIN Dim_KhachHang JOIN Dim_VPDD JOIN Dim_ThoiGian
```

**Trả lời câu hỏi:** "Phân bố khách hàng và doanh thu theo loại KH, địa lý, thời gian?"

### 8.3 Năm Stored Procedures OLAP

| SP | Phép toán | Tham số | Mô tả |
|----|---------|---------|-------|
| `sp_DrillDown_ThoiGian` | Drill Down | `@Nam`, `@Quy` | Doanh thu Năm → Quý → Tháng |
| `sp_RollUp_DiaDiem` | Roll Up | `@MucDo`, `@Nam` | Tồn kho CH → TP → Bang |
| `sp_Slice_DoanhThu` | Slice | `@LoaiKH`, `@Nam`, `@KichCo` | Cắt theo 1 chiều |
| `sp_Dice_TonKho` | Dice | `@MaTP`, `@MaMH`, `@NamFrom`, `@NamTo` | Cắt theo nhiều chiều |
| `sp_Pivot_DoanhThu` | Pivot | (không tham số) | Ma trận Năm × LoaiKH |

---

## 9. Bước 5 – Tạo Metadata và Index

### 9.1 Lý thuyết: Metadata

Theo DMDW: *"Siêu dữ liệu (Metadata) giúp bổ sung thông tin cho các dữ liệu chính trong hệ thống."*

Metadata là "dữ liệu về dữ liệu" — mô tả cấu trúc, nguồn gốc và ý nghĩa của mỗi bảng/cột trong DW, giúp:
- Người dùng hiểu được DW chứa gì
- Hệ thống tự động tài liệu hóa
- Kiểm soát chất lượng dữ liệu

### 9.2 Ba bảng Metadata trong dự án (file `Metadata.sql`)

#### Meta_Tables — Mô tả các bảng trong DW

```sql
TableName | TableType | SourceTable | Description | RowCount | LastUpdated
```

Ví dụ:
```
Fact_BanHang | Fact | DonDatHang + MatHangDuocDat | "Bảng sự kiện doanh thu..." | 1000 | ...
Dim_ThoiGian | Dimension | MONTH(NgayDatHang) | "Chiều thời gian: Tháng→Quý→Năm" | 36 | ...
```

#### Meta_Columns — Mô tả từng cột

```sql
TableName | ColumnName | DataType | KeyType | SourceColumn | Description
```

Phân loại: `PK` (khóa chính), `FK` (khóa ngoại), `Measure` (độ đo), `Attribute` (thuộc tính chiều)

#### Meta_Hierarchy — Mô tả phân cấp chiều

```sql
DimensionName | HierarchyName | LevelOrder | LevelName | ColumnName
```

Ví dụ phân cấp thời gian:
```
Dim_ThoiGian | 'Thời gian' | 1 | 'Năm'   | Nam
Dim_ThoiGian | 'Thời gian' | 2 | 'Quý'   | Quy
Dim_ThoiGian | 'Thời gian' | 3 | 'Tháng' | Thang
```

### 9.3 Các Index được tạo

```sql
-- Trong ETL_IDB_to_DW.sql (index trên Fact tables):
IX_Fact_BanHang_KH  → Fact_BanHang(MaKhachHang)  -- Tìm kiếm theo KH
IX_Fact_BanHang_MH  → Fact_BanHang(MaMatHang)    -- Tìm kiếm theo MH
IX_Fact_BanHang_TG  → Fact_BanHang(TimeKey)      -- Tìm kiếm theo thời gian
IX_Fact_Kho_MH      → Fact_Kho(MaMatHang)
IX_Fact_Kho_CH      → Fact_Kho(MaCuaHang)
IX_Fact_Kho_TK      → Fact_Kho(TimeKey)

-- Trong OLAP_Cubes.sql (index trên Cube tables):
IX_Cube_DT_Nam      → Cube_DoanhThu(Nam)
IX_Cube_DT_MH       → Cube_DoanhThu(MaMatHang)
IX_Cube_DT_KH       → Cube_DoanhThu(LoaiKhachHang)
IX_Cube_TK_MH       → Cube_TonKho(MaMatHang)
IX_Cube_TK_CH       → Cube_TonKho(MaCuaHang)
IX_Cube_TK_TP       → Cube_TonKho(MaThanhPhoCH)
```

---

## 10. Bước 6 – Giao Diện Web OLAP

### 10.1 Yêu cầu từ đề bài và thang điểm

Theo hướng dẫn BTL: *"Xây dựng giao diện với người dùng để demo các phép toán cơ bản của OLAP bao gồm khoan sâu xuống (drill down), cuộn lên (roll up), chiếu chọn (slice and dice), xoay (pivot)."*

### 10.2 Stack kỹ thuật (file `btl/webapp/app.py`)

- **Backend:** Python Flask
- **Database:** `pyodbc` kết nối SQL Server
- **Frontend:** HTML + CSS (Jinja2 templates)

### 10.3 Luồng hoạt động Web App

```
User truy cập → Flask Route → Gọi Stored Procedure → DW_BanHang → Trả về JSON/HTML
```

Các tính năng cần có:
- Chọn loại thao tác OLAP (Drill Down / Roll Up / Slice / Dice / Pivot)
- Nhập tham số (năm, loại KH, mặt hàng...)
- Hiển thị kết quả dưới dạng bảng
- Nút chuyển đổi giữa các mức phân cấp

---

## 11. 9 Câu Truy Vấn Nghiệp Vụ

Đây là **9 câu hỏi từ đề bài** mà DW phải trả lời được. Mapping với SQL trong `OLAP_Cubes.sql`:

| # | Yêu cầu đề bài | SQL trong dự án | Bảng dùng |
|---|---------------|----------------|-----------|
| Q1 | Tất cả cửa hàng + TP, bang, SĐT + MH bán ở kho đó | `SELECT DISTINCT ch, vp, mh FROM Cube_TonKho...` | Cube_TonKho |
| Q2 | Tất cả đơn hàng + tên KH + ngày đặt của 1 KH | `SUM() GROUP BY KH, Tháng WHERE KH = @MaKH` | Fact_BanHang |
| Q3 | Cửa hàng + TP + SĐT có bán MH đặt bởi 1 KH | `JOIN Fact_BanHang → Fact_Kho → Dim_CuaHang` | Fact_BanHang + Fact_Kho |
| Q4 | Địa chỉ VP + TP + bang của CH lưu kho MH > ngưỡng | `HAVING SUM(TonKho) > @SLNguong` | Cube_TonKho |
| Q5 | MH đặt + mã CH + TP bán MH đó (theo đơn KH) | `DISTINCT JOIN Fact_BanHang → Fact_Kho` | Fact_BanHang + Fact_Kho |
| Q6 | TP và bang mà 1 KH sinh sống | `JOIN Dim_KhachHang → Dim_VPDD WHERE MaKH = @x` | Dim_KhachHang |
| Q7 | Tồn kho 1 MH tại tất cả CH ở 1 TP cụ thể | `WHERE MaMatHang = @x AND MaThanhPhoCH = @y` | Cube_TonKho |
| Q8 | MH + SL đặt + KH + CH + TP của 1 đơn đặt hàng | `JOIN Fact_BanHang → Fact_Kho → Dim_CuaHang` | Fact_BanHang + Fact_Kho |
| Q9 | KH du lịch, bưu điện, cả hai loại | `GROUP BY LoaiKhachHang WHERE LoaiKH IN (...)` | Dim_KhachHang |

---

## 12. Bảng Điểm và Checklist Hoàn Thiện

### Thang điểm chính thức (từ hướng dẫn BTL)

| # | Nội dung | Điểm | File dự án | Trạng thái |
|---|---------|------|-----------|-----------|
| 1 | Tích hợp đúng dữ liệu từ 2 nguồn (đổi sang mô hình EER rồi tích hợp IER) | 0.5 | `taoBang_new.sql` (IDB) | ✅ |
| 2 | Thiết kế mô hình dữ liệu được tích hợp | 1.0 | Sơ đồ IER (cần trong báo cáo) | ⚠️ |
| 3 | Sinh dữ liệu cho các nguồn dữ liệu | 1.0 | `sinhdulieu_new.sql` | ✅ |
| 4 | Thiết kế đúng mô hình dữ liệu cho kho | 1.0 | `taoBangFact_Dim_new.sql` | ✅ |
| 5 | Cách ánh xạ để đổ dữ liệu từ IDB vào kho | 1.0 | `ETL_IDB_to_DW.sql` | ✅ |
| 6 | Tạo phân cấp để tính khối cho OLAP | 0.5 | `OLAP_Cubes.sql` (Phần 1) | ✅ |
| 7 | Tạo Metadata và các file index cần thiết | 1.0 | `Metadata.sql` | ✅ |
| 8 | Thiết kế các khối dữ liệu để thực hiện OLAP | 1.0 | `OLAP_Cubes.sql` (5 SPs) | ✅ |
| 9 | Tính sẵn các khối + Web app OLAP (drill/rollup/slice/dice) | 2.0 | `webapp/app.py` | ⚠️ |
| 10 | Viết tài liệu đầy đủ | 1.0 | `btlKhoDuLieu_new.docx` | ⚠️ |

**Tổng:** 10 điểm

### Checklist những điểm cần lưu ý

- ✅ IDB có 9 bảng đầy đủ, schema đúng đề
- ✅ DW có Lược đồ Dải Thiên Hà (2 Fact + 5 Dim)
- ✅ ETL 8 bước rõ ràng, transform phân loại KH đúng
- ✅ 3 Cube pre-computed + 5 Stored Procedure OLAP
- ✅ Metadata 3 bảng (Tables, Columns, Hierarchy)
- ✅ 12 Index (6 Fact + 6 Cube)
- ⚠️ **Cần:** Sơ đồ IER trong báo cáo Word (điểm 2)
- ⚠️ **Cần:** Sơ đồ DW (Star/Galaxy schema) trong báo cáo (điểm 4)
- ⚠️ **Cần:** Web app hiển thị đầy đủ 5 phép toán OLAP (điểm 9)
- ⚠️ **Cần:** Kiểm tra tính đúng đắn dữ liệu OLAP vs bảng nguồn (điểm 10)

---

## Phụ Lục: Thứ Tự Chạy SQL Scripts

Để triển khai toàn bộ dự án từ đầu, chạy theo thứ tự sau:

```sql
-- BƯỚC 0: Tạo và sinh dữ liệu cho IDB
1. taoBang_new.sql          -- Tạo database csdl_banhang + 9 bảng
2. sinhdulieu_new.sql       -- Sinh 1000 dòng mỗi bảng

-- BƯỚC 1: Tạo DW và Fact/Dim
3. taoBangFact_Dim_new.sql  -- Tạo database DW_BanHang + 7 bảng

-- BƯỚC 2: Chạy ETL
4. ETL_IDB_to_DW.sql        -- Đổ dữ liệu từ csdl_banhang → DW_BanHang

-- BƯỚC 3: Tạo OLAP Cubes
5. OLAP_Cubes.sql           -- Tạo 3 Cube + 5 SP + chạy 9 câu truy vấn nghiệp vụ

-- BƯỚC 4: Tạo Metadata
6. Metadata.sql             -- Tạo 3 bảng Meta_ + populate

-- BƯỚC 5: Chạy Web App
7. cd btl/webapp && python app.py
```

> **Lưu ý quan trọng:** Scripts sử dụng **cross-database reference** (`csdl_banhang.dbo.TenBang`), vì vậy cả `csdl_banhang` và `DW_BanHang` phải nằm trên **cùng một SQL Server instance**.
