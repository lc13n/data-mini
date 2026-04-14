# ĐÁNH GIÁ BÀI TẬP LỚN — MÔN KHO DỮ LIỆU
## Theo quy trình 6 bước (Cập nhật sau khi sửa)

> **Vai trò:** Giảng viên chấm bài
> **Ngày đánh giá:** 2026-04-14
> **Căn cứ:** Hướng dẫn và cách chấm điểm bài tập lớn KDL

---

## Tổng quan điểm ước tính (sau khi sửa)

| Bước | Nội dung | Điểm tối đa | Ước tính | Trạng thái |
|------|----------|:-----------:|:--------:|-----------|
| 1 | Tích hợp 2 nguồn → IDB | 1.5 | **0.70** | ⚠️ Còn thiếu IER |
| 2 | Thiết kế Star Schema DW | 1.0 | **0.85** | ✅ Đã sửa theo image2.png |
| 3 | ETL + Sinh dữ liệu | 2.0 | **1.80** | ✅ Đã cập nhật schema mới |
| 4 | Hierarchy + OLAP Cubes | 1.5 | **1.00** | ⚠️ OLAP_Cubes.sql chưa cập nhật |
| 5 | Metadata + Index | 1.0 | **0.70** | ⚠️ Metadata.sql chưa cập nhật |
| 6 | Giao diện Web OLAP | 2.0 | **1.75** | ✅ Q2/Q3/Q5/Q8 đã sửa |
| **Tổng** | | **9.0** | **~6.80** | |

---

---

# BƯỚC 1 — Tích hợp 2 nguồn dữ liệu thành IDB

> **Điểm tối đa:** 0.5đ (tích hợp đúng) + 1.0đ (thiết kế IDB)

---

## 1.1 Quy trình ER → IER → IDB

### Đề bài — 2 CSDL nguồn tách biệt

**DB1 – Văn phòng đại diện:**
- `KhachHang (Mã KH, Tên KH, Mã Thành phố, Ngày đặt hàng đầu tiên)`
- `KhachHangDuLich (*Mã KH, Hướng dẫn viên, Thời gian)`
- `KhachHangBuuDien (*Mã KH, Địa chỉ bưu điện, Thời gian)`

**DB2 – Bán hàng:**
- `VanPhongDaiDien (Mã Thành phố, Tên TP, Địa chỉ VP, Bang, Thời gian)`
- `CuaHang, MatHang, MatHang_DuocLuuTru, DonDatHang, MatHangDuocDat`

### ✅ Đúng (`taoBang.sql`)
- Đủ 9 bảng, ánh xạ đúng lược đồ đề bài.
- FK constraints hợp lệ, kiểu dữ liệu phù hợp.
- Quan hệ kế thừa `KhachHangDuLich / KhachHangBuuDien → KhachHang` đúng (PK = FK).
- Composite PK cho bảng nhiều-nhiều đúng chuẩn.

### ❌ Còn thiếu

| Vấn đề | Phân tích |
|--------|-----------|
| **Không có sơ đồ ER-1, ER-2 riêng biệt** | Quy trình bắt buộc: vẽ ER từng nguồn → mới tích hợp thành IER. Bài gộp thẳng vào 1 DB không qua bước này. |
| **Không có IER (Integrated ER)** | Không có tài liệu/ảnh mô tả rõ quá trình tích hợp và phân tích xung đột giữa 2 nguồn. |

### ⚠️ Ảnh hưởng
Giám khảo không thể kiểm chứng IDB có sinh đúng từ IER. Đây là điểm trừ về phương pháp luận.

### 🔧 Cần bổ sung
1. Vẽ **ER-1** cho DB Văn phòng, **ER-2** cho DB Bán hàng.
2. Vẽ **IER** tích hợp với phân tích xung đột (`Mã Thành phố` xuất hiện ở cả 2 DB).
3. Thuyết minh cách `taoBang.sql` được sinh từ IER.

### Ước tính điểm Bước 1: **0.70 / 1.5**

---

---

# BƯỚC 2 — Thiết kế mô hình dữ liệu cho kho DW (Star Schema)

> **Điểm tối đa:** 1.0đ ✅ **ĐÃ SỬA theo `image2.png`**

---

## 2.1 Cấu trúc Star Schema hiện tại (`taoBangFact_Dim.sql`)

**2 bảng Fact:**
```sql
Fact_BanHang (MaKhachHang, MaMatHang, MaThanhPho, MaThoiGian,
              SoLuongBan, DoanhThu)
              PK: (MaKhachHang, MaMatHang, MaThanhPho, MaThoiGian)

Fact_Kho     (MaMatHang, MaCuaHang, SoLuongTonKho)
              PK: (MaMatHang, MaCuaHang)
```

**5 bảng Dimension:**
```
Dim_ThoiGian  (maThoiGian, thang, quy, nam)
Dim_VPDD      (MaThanhPho, TenThanhPho, Bang, DiaChi)
Dim_KhachHang (MaKH, TenKhachHang, MaThanhPho, LoaiKhachHang)
Dim_MatHang   (MaMH, MoTa, KichCo, TrongLuong, DonGia)
Dim_CuaHang   (MaCuaHang, MaThanhPho, Bang, SDT)
```

### ✅ Đúng — Khớp hoàn toàn với sơ đồ image2.png

| Điểm tốt | Lý do |
|----------|-------|
| `Fact_BanHang` có `MaThanhPho → Dim_VPDD` | Phân tích doanh thu theo địa lý (thành phố khách hàng) |
| `Dim_ThoiGian` đúng tên cột theo sơ đồ | `maThoiGian, thang, quy, nam` — nhất quán |
| `Fact_Kho` đơn giản hóa | Snapshot tồn kho theo `(MatHang × CuaHang)` — hợp lý |
| 2 bảng Fact phân biệt rõ | Fact_BanHang (sự kiện bán), Fact_Kho (trạng thái kho) |
| Độ đo phù hợp | `SoLuongBan`, `DoanhThu` (additive); `SoLuongTonKho` |

### ⚠️ Lưu ý thiết kế
- `Fact_BanHang.MaThanhPho` = thành phố của **khách hàng** (không phải cửa hàng phục vụ) — đây là quyết định thiết kế hợp lệ, phù hợp với mục tiêu phân tích theo vùng.
- `Fact_Kho` không có chiều thời gian (chỉ lưu snapshot hiện tại) — đúng theo sơ đồ.

### Ước tính điểm Bước 2: **0.85 / 1.0**

---

---

# BƯỚC 3 — ETL từ IDB vào DW + Sinh dữ liệu

> **Điểm tối đa:** 1.0đ + 1.0đ = 2.0đ ✅ **ĐÃ CẬP NHẬT**

---

## 3.1 ETL (`ETL_IDB_to_DW.sql`) — Đã cập nhật theo schema mới

### ✅ Đúng

| Điểm tốt | Chi tiết |
|----------|----------|
| Thứ tự xóa/nạp đúng FK | DELETE Fact → Dim; INSERT Dim → Fact |
| `Dim_ThoiGian` sinh từ dữ liệu thực | `MIN(NgayDatHang) → GETDATE()`, không hardcode |
| `LoaiKhachHang` derive đầy đủ 4 loại | Du lịch / Bưu điện / Du lịch & Bưu điện / Thường |
| `Fact_BanHang.MaThanhPho` lấy từ `Dim_KhachHang.MaThanhPho` | Đúng logic — thành phố của khách hàng |
| `Fact_Kho` dùng `ROW_NUMBER()` lấy snapshot mới nhất | Tránh vi phạm PK khi 1 mặt hàng được cập nhật nhiều lần/tháng |
| Log từng bước `[1/7]...[8/8]` | Dễ debug |
| Index tạo sau bulk insert | Đúng thứ tự tối ưu |
| Cột `maThoiGian`, `thang`, `quy`, `nam` nhất quán | Đúng schema mới |

### Ước tính: **1.0 / 1.0**

---

## 3.2 Sinh dữ liệu IDB (`SinhData_IDB.sql`)

### ✅ Đúng (không thay đổi, vẫn tốt)

| Đối tượng | Số lượng |
|-----------|----------|
| VanPhongDaiDien | 5 TP với địa chỉ thực |
| KhachHang | 200 |
| KhachHangDuLich | 100 (KH lẻ) |
| KhachHangBuuDien | 100 (KH chẵn) |
| CuaHang | 30 |
| MatHang | 100 |
| MatHang_DuocLuuTru | ~600 (30×20) |
| DonDatHang | 500 |
| MatHangDuocDat | ~1250 (1-5 MH/đơn) |

### Ước tính: **0.85 / 1.0**

---

## 3.3 Sinh dữ liệu DW (`SinhData.sql`) — Đã cập nhật

### ✅ Đúng

| Cải tiến | Chi tiết |
|---------|----------|
| `Dim_ThoiGian` đúng cột mới | `thang, quy, nam` thay vì `Thang, Quy, Nam` |
| `Fact_BanHang` đúng 4 chiều | `MaKhachHang × MaMatHang × MaThanhPho × MaThoiGian` |
| `Fact_Kho` đơn giản | `MatHang × CuaHang` — không cần TimeKey |
| `LoaiKhachHang` đủ 4 loại | `Du lịch / Bưu điện / Du lịch & Bưu điện / Thường` (đã sửa so với phiên bản cũ chỉ có VIP/Thường) |
| `Dim_CuaHang.Bang` lấy từ Dim_VPDD | Nhất quán, không hardcode |
| ~300.000 dòng Fact_BanHang, 10.000 Fact_Kho | Đủ dữ liệu demo |

### Ước tính điểm Bước 3: **1.80 / 2.0**

---

---

# BƯỚC 4 — Phân cấp chiều + OLAP Cubes

> **Điểm tối đa:** 0.5đ + 1.0đ = 1.5đ  ⚠️ **OLAP_Cubes.sql CHƯA CẬP NHẬT**

---

## 4.1 Phân cấp chiều

### ✅ Đúng — Phân cấp hợp lý

| Chiều | Phân cấp | Số cấp |
|-------|----------|--------|
| Dim_ThoiGian | **Năm → Quý → Tháng** | 3 |
| Dim_CuaHang | **Bang → Thành phố → Cửa hàng** | 3 |
| Dim_KhachHang | **Loại KH → Khách hàng** | 2 |
| Dim_VPDD | **Bang → Thành phố** | 2 |

---

## 4.2 OLAP Cubes (`OLAP_Cubes.sql`)

### ❌ CHƯA CẬP NHẬT — Vẫn dùng tên cột schema cũ

```sql
-- Dòng 48 — LỖI: dùng tên cột CŨ
JOIN Dim_ThoiGian tg ON f.TimeKey = tg.TimeKey
--                         ↑ sai              ↑ sai
-- Phải là:
JOIN Dim_ThoiGian tg ON f.MaThoiGian = tg.maThoiGian
```

**Danh sách lỗi trong OLAP_Cubes.sql:**

| Vị trí | Lỗi | Sửa thành |
|--------|-----|-----------|
| Dòng 48 | `f.TimeKey = tg.TimeKey` | `f.MaThoiGian = tg.maThoiGian` |
| Dòng 40-42 | `tg.Nam, tg.Quy, tg.Thang` | `tg.nam, tg.quy, tg.thang` |
| Dòng 83-84 | Cube_TonKho JOIN Dim_ThoiGian | Fact_Kho không còn TimeKey — bỏ join này |
| SP DrillDown | Dùng `Nam, Quy, Thang` | Đổi thành `nam, quy, thang` |
| SP RollUp | Dùng `Nam` | Đổi thành `nam` |

### ⚠️ Ảnh hưởng
Nếu chạy `OLAP_Cubes.sql` ngay bây giờ sẽ lỗi runtime — cột `TimeKey` không tồn tại trong schema mới.

### 🔧 Cần sửa ngay
Cập nhật toàn bộ `OLAP_Cubes.sql` đổi:
- `TimeKey` → `maThoiGian`
- `tg.Nam / tg.Quy / tg.Thang` → `tg.nam / tg.quy / tg.thang`
- Bỏ JOIN Dim_ThoiGian trong Cube_TonKho (vì Fact_Kho không còn TimeKey)

### Ước tính điểm Bước 4: **1.00 / 1.5** *(điểm bị kéo do Cubes lỗi)*

---

---

# BƯỚC 5 — Metadata và các file Index

> **Điểm tối đa:** 1.0đ  ⚠️ **Metadata.sql CHƯA CẬP NHẬT**

---

## 5.1 Metadata (`Metadata.sql`) — Chưa cập nhật schema mới

### ❌ Lỗi hiện tại

| Vấn đề | Cột sai | Nên là |
|--------|---------|--------|
| `Meta_Columns` mô tả `TimeKey` cho Fact_BanHang | `TimeKey` | `MaThoiGian` |
| `Meta_Columns` thiếu `MaThanhPho` trong Fact_BanHang | — | Thêm vào |
| `Meta_Hierarchy` Dim_ThoiGian dùng `Thang, Quy, Nam` | Chữ hoa | `thang, quy, nam` |
| Fact_Kho mô tả có TimeKey | `TimeKey` | Bỏ — Fact_Kho không có chiều thời gian |
| Không có metadata cho Cube tables | — | Cần bổ sung |

### ✅ Vẫn đúng
- Cấu trúc 3 bảng Meta: `Meta_Tables`, `Meta_Columns`, `Meta_Hierarchy` — chuẩn.
- `RowCount` tự cập nhật sau load.
- `SourceColumn` trace được từ DW về IDB.

---

## 5.2 Index

### ✅ Đa phần đúng
- Index IF NOT EXISTS trên Fact tables.
- `ETL_IDB_to_DW.sql` tạo index đúng tên cột mới (`MaThoiGian`, `MaThanhPho`).

### ❌ Chưa đồng bộ
- `OLAP_Cubes.sql` tạo index trên `Nam, Quy, Thang` (chữ hoa) — sẽ sai với cột `nam/quy/thang` mới.

### Ước tính điểm Bước 5: **0.70 / 1.0**

---

---

# BƯỚC 6 — Giao diện Web OLAP

> **Điểm tối đa:** 2.0đ ✅ **ĐÃ SỬA Q2/Q3/Q5/Q8**

---

## 6.1 5 phép toán OLAP (`app.py`)

| Route | Phép toán | Đánh giá |
|-------|----------|----------|
| `/drilldown?nam=&quy=` | **Drill Down**: Năm → Quý → Tháng | ✅ |
| `/rollup?muc=&nam=` | **Roll Up**: CuaHang → ThanhPho → Bang | ✅ |
| `/slice` | **Slice**: cắt 1 chiều, filter NULLIF đúng | ✅ Đã sửa bug None/'' |
| `/dice` | **Dice**: cắt nhiều chiều | ✅ |
| `/pivot` | **Pivot**: LoaiKH × Năm | ✅ |

---

## 6.2 9 câu truy vấn nghiệp vụ — Sau khi sửa

| Câu | Yêu cầu | Logic sau sửa | Đúng/Sai |
|-----|---------|--------------|----------|
| Q1 | CH + TP + SĐT + MH bán | Cube_TonKho JOIN đúng | ✅ |
| **Q2** | Từng đơn hàng + tên KH + ngày | Query từ **IDB** `csdl_banhang.dbo.DonDatHang` → liệt kê từng `MaDon` | ✅ Đã sửa |
| **Q3** | CH bán MH đặt bởi KH | Query IDB: `DonDatHang → MatHangDuocDat → MatHang_DuocLuuTru → CuaHang` | ✅ Đã sửa |
| Q4 | VP + Bang + CH lưu MH > ngưỡng | Cube_TonKho + HAVING | ✅ |
| **Q5** | MH + mã CH + TP bán | Query IDB tương tự Q3 | ✅ Đã sửa |
| Q6 | TP + Bang KH sinh sống | Dim_KhachHang JOIN Dim_VPDD | ✅ |
| Q7 | TK MH tại CH ở 1 TP | Cube_TonKho + filter TP | ✅ |
| **Q8** | MH + SL + KH + CH + TP | Query IDB: đúng `SUM(SoLuongDat * GiaDat)` | ✅ Đã sửa |
| Q9 | KH du lịch / bưu điện / cả hai | GROUP BY LoaiKhachHang | ✅ |

**9/9 câu đúng về logic nghiệp vụ sau khi sửa** ✅

### ⚠️ Còn thiếu sót kỹ thuật nhỏ

| Vấn đề | Mức độ |
|--------|--------|
| Không có try/except trong `query()` — lỗi DB crash app | Cao |
| Không có connection pool | Trung bình |
| Các route OLAP vẫn dùng tên cột cũ (`Nam, Quy, Thang`) — sẽ sai sau khi Cubes cập nhật | Cao |

> ⚠️ **Lưu ý quan trọng:** Sau khi cập nhật `OLAP_Cubes.sql` sang tên cột mới (`nam, quy, thang`), cần sửa lại các route `/drilldown`, `/rollup`, `/slice`, `/pivot` trong `app.py` để dùng tên cột mới.

### Ước tính điểm Bước 6: **1.75 / 2.0**

---

---

# TỔNG HỢP CÔNG VIỆC CÒN LẠI

## Bảng điểm sau khi sửa

| Bước | Nội dung | Tối đa | Ước tính | Trạng thái |
|------|----------|:------:|:--------:|-----------|
| **1** | Tích hợp 2 nguồn → IDB | 1.5 | **0.70** | ⚠️ Thiếu IER |
| **2** | Thiết kế Star Schema DW | 1.0 | **0.85** | ✅ Khớp image2.png |
| **3** | ETL + Sinh dữ liệu | 2.0 | **1.80** | ✅ Đã cập nhật |
| **4** | Hierarchy + OLAP Cubes | 1.5 | **1.00** | ⚠️ Cubes lỗi tên cột |
| **5** | Metadata + Index | 1.0 | **0.70** | ⚠️ Metadata chưa cập nhật |
| **6** | Giao diện Web OLAP | 2.0 | **1.75** | ✅ 9/9 câu đúng |
| | **Tổng** | **9.0** | **~6.80** | |

---

## Việc cần làm ngay (để tăng điểm)

### 🔴 Bắt buộc — ảnh hưởng runtime

**1. Cập nhật `OLAP_Cubes.sql`** ← **Quan trọng nhất**
- Đổi `TimeKey` → `maThoiGian`
- Đổi `tg.Nam/Quy/Thang` → `tg.nam/quy/thang`
- Bỏ JOIN Dim_ThoiGian trong Cube_TonKho
- Ảnh hưởng: **+0.35đ** Bước 4

**2. Cập nhật routes trong `app.py` sau khi sửa Cubes**
- Các route dùng `Nam, Quy, Thang` chữ hoa từ Cubes → phải đổi thành chữ thường
- Ảnh hưởng: **+0.1đ** Bước 6

### 🟡 Quan trọng — ảnh hưởng điểm

**3. Cập nhật `Metadata.sql`**
- Đổi cột `TimeKey` → `MaThoiGian` trong `Meta_Columns`
- Thêm `MaThanhPho` cho Fact_BanHang
- Bỏ `TimeKey` khỏi mô tả Fact_Kho
- Ảnh hưởng: **+0.2đ** Bước 5

**4. Thêm try/except trong `query()` của Flask**
```python
def query(sql, params=None):
    try:
        conn = get_conn()
        cur = conn.cursor()
        cur.execute(sql, params or [])
        cols = [c[0] for c in cur.description]
        rows = [dict(zip(cols, r)) for r in cur.fetchall()]
        conn.close()
        return cols, rows
    except Exception as e:
        return ['Lỗi'], [{'Lỗi': str(e)}]
```

### 🟢 Nên có — hoàn thiện bài

**5. Bổ sung IER** — vẽ sơ đồ tích hợp 2 ER, ảnh hưởng **+0.5đ** Bước 1
