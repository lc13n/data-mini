# ĐÁNH GIÁ BÀI TẬP LỚN — MÔN KHO DỮ LIỆU
## Theo quy trình 6 bước — Review cập nhật lần cuối

> **Vai trò:** Giảng viên chấm bài
> **Ngày đánh giá:** 2026-04-18
> **Căn cứ:** Hướng dẫn và cách chấm điểm bài tập lớn KDL
> **Trạng thái:** Review toàn bộ dự án sau khi sửa

---

## Tổng quan điểm ước tính

| Bước | Nội dung | Điểm tối đa | Ước tính | Trạng thái |
|------|----------|:-----------:|:--------:|-----------|
| 1 | Tích hợp 2 nguồn → IDB | 1.5 | **0.70** | ⚠️ Thiếu sơ đồ IER |
| 2 | Thiết kế Star Schema DW | 1.0 | **0.70** | ⚠️ Mất granularity đơn hàng |
| 3 | ETL + Sinh dữ liệu | 2.0 | **1.50** | ⚠️ sinhdulieu_new dùng sai tên DB |
| 4 | Phân cấp + OLAP Cubes | 1.5 | **1.30** | ✅ Nhất quán với schema mới |
| 5 | Metadata + Index | 1.0 | **0.80** | ✅ Đầy đủ |
| 6 | Giao diện Web OLAP | 2.0 | **1.60** | ⚠️ Q2/Q3/Q5/Q8 có hạn chế |
| **Tổng** | | **9.0** | **~6.60** | |

---

---

# BƯỚC 1 — Tích hợp 2 nguồn dữ liệu thành IDB

> **Điểm tối đa:** 0.5đ (tích hợp đúng) + 1.0đ (thiết kế IDB)

---

## 1.1 Quy trình ER → IER → IDB

### Đề bài — 2 CSDL nguồn tách biệt

**DB1 – Văn phòng đại diện (CSDL khách hàng):**
- `KhachHang (Mã KH, Tên KH, Mã Thành phố, Ngày đặt hàng đầu tiên)`
- `KhachHangDuLich (*Mã KH, Hướng dẫn viên du lịch, Thời gian)`
- `KhachHangBuuDien (*Mã KH, Địa chỉ bưu điện, Thời gian)`

**DB2 – Bán hàng:**
- `VanPhongDaiDien (Mã Thành phố, Tên TP, Địa chỉ VP, Bang, Thời gian)`
- `CuaHang (Mã cửa hàng, *Mã Thành phố, Số điện thoại, Thời gian)`
- `MatHang (Mã MH, Mô tả, Kích cỡ, Trọng lượng, Giá, Thời gian)`
- `MatHang_DuocLuuTru (*Mã cửa hàng, *Mã mặt hàng, Số lượng trong kho, Thời gian)`
- `DonDatHang (Mã đơn, Ngày đặt hàng, Mã Khách hàng)`
- `MatHangDuocDat (*Mã đơn, *Mã mặt hàng, Số lượng đặt, Giá đặt, Thời gian)`

### ✅ Đúng (`taoBang_new.sql`)
- Đủ 9 bảng, ánh xạ đúng lược đồ đề bài.
- FK constraints hợp lệ: `KhachHang.MaThanhPhoKhachHang → VanPhongDaiDien(MaThanhPho)`.
- Kế thừa `KhachHangDuLich / KhachHangBuuDien → KhachHang` đúng (PK = FK).
- Composite PK `(MaCuaHang, MaMatHang)` và `(MaDon, MaMatHang)` đúng chuẩn.
- Các cột `Thời gian` đề bài yêu cầu đều được thể hiện (`ThoiGianBatDauHoatDong`, `ThoiGianMua`, `ThoiGianKhaiTruong`, …).

### ❌ Còn thiếu

| Vấn đề | Phân tích |
|--------|-----------|
| **Không có sơ đồ ER-1, ER-2 riêng biệt** | Quy trình bắt buộc: vẽ ER từng nguồn → tích hợp thành IER. Bài gộp thẳng vào 1 DB. |
| **Không có IER (Integrated ER)** | Không có tài liệu mô tả quá trình tích hợp và phân tích xung đột giữa 2 nguồn. |
| **Không phân tích xung đột** | `MaThanhPho` xuất hiện ở cả DB1 (trong KhachHang) và DB2 (trong VanPhongDaiDien) — cần mô tả cách giải quyết. |

### ⚠️ Ảnh hưởng
Giám khảo không thể kiểm chứng IDB có sinh đúng từ IER. Đây là điểm trừ phương pháp luận.

### 🔧 Cần bổ sung
1. Vẽ **ER-1** cho DB Văn phòng (KhachHang, KhachHangDuLich, KhachHangBuuDien).
2. Vẽ **ER-2** cho DB Bán hàng (VanPhongDaiDien, CuaHang, MatHang, …).
3. Vẽ **IER** tích hợp với phân tích xung đột.
4. Mô tả cách `taoBang_new.sql` được sinh từ IER.

### Ước tính điểm Bước 1: **0.70 / 1.5**

---

---

# BƯỚC 2 — Thiết kế mô hình dữ liệu cho kho DW (Star Schema)

> **Điểm tối đa:** 1.0đ

---

## 2.1 Cấu trúc Star Schema hiện tại (`taoBangFact_Dim_new.sql`)

**2 bảng Fact:**
```sql
Fact_BanHang (MaKhachHang, MaMatHang, TimeKey,
              SoLuongBan, DoanhThu)
              PK: (MaKhachHang, MaMatHang, TimeKey)

Fact_Kho     (MaMatHang, MaCuaHang, TimeKey, SoLuongTonKho)
              PK: (MaMatHang, MaCuaHang, TimeKey)
```

**5 bảng Dimension:**
```
Dim_ThoiGian  (TimeKey IDENTITY PK, Thang, Quy, Nam)
Dim_VPDD      (MaThanhPho PK, TenThanhPho, Bang, DiaChi)
Dim_KhachHang (MaKH PK, TenKhachHang, MaThanhPho, LoaiKhachHang)
Dim_MatHang   (MaMH PK, MoTa, KichCo, TrongLuong, DonGia)
Dim_CuaHang   (MaCuaHang PK, MaThanhPho FK→Dim_VPDD, Bang, SDT)
```

### ✅ Đúng

| Điểm tốt | Lý do |
|----------|-------|
| 2 bảng Fact phân biệt rõ | `Fact_BanHang` (sự kiện bán), `Fact_Kho` (trạng thái kho) |
| `Fact_Kho` có chiều thời gian | `TimeKey` cho phép theo dõi tồn kho theo tháng — tốt hơn snapshot tĩnh |
| Độ đo phù hợp | `SoLuongBan`, `DoanhThu` (additive); `SoLuongTonKho` (semi-additive) |
| `LoaiKhachHang` derived | Kết hợp từ KhachHangDuLich + KhachHangBuuDien — đúng nghiệp vụ |
| `Dim_ThoiGian` dùng `TimeKey` surrogate | Chuẩn thiết kế DW, tránh phụ thuộc vào natural key |

### ❌ Vấn đề thiết kế

| Vấn đề | Phân tích | Ảnh hưởng |
|--------|-----------|-----------|
| **Fact_BanHang mất granularity đơn hàng** | PK là `(MaKhachHang, MaMatHang, TimeKey)` → mã đơn `MaDon` bị mất. Nhiều đơn cùng KH, cùng MH, cùng tháng sẽ bị gộp. | Q2 yêu cầu "liệt kê *từng đơn đặt hàng* với ngày đặt" → **không trả lời được** từ Fact_BanHang. |
| **Fact_BanHang không có chiều CuaHang** | Không có FK `MaCuaHang → Dim_CuaHang`. Không biết đơn hàng được phục vụ bởi cửa hàng nào. | Q3, Q5, Q8 yêu cầu tìm cửa hàng bán cho KH → phải join chéo 2 fact tables qua `MaMatHang`, cho kết quả **rộng hơn thực tế** (mọi CH có mặt hàng đó, không phải CH thực sự phục vụ). |

### ⚠️ Lưu ý
- Hai vấn đề trên là **hạn chế thiết kế cố hữu** — nằm trong `taoBangFact_Dim_new.sql` (file _new do bạn đặt). Nghĩa là đây là **quyết định thiết kế** chứ không phải lỗi code.
- Trong bối cảnh bài tập lớn, giảng viên có thể chấp nhận nếu có giải thích rõ ràng trong báo cáo.

### Ước tính điểm Bước 2: **0.70 / 1.0**

---

---

# BƯỚC 3 — ETL từ IDB vào DW + Sinh dữ liệu

> **Điểm tối đa:** 1.0đ (ETL) + 1.0đ (Sinh dữ liệu) = 2.0đ

---

## 3.1 Sinh dữ liệu IDB (`sinhdulieu_new.sql`)

### 🔴 LỖI NGHIÊM TRỌNG: Sai tên database

```sql
-- Dòng 1 của sinhdulieu_new.sql:
USE QuanLyBanHang;   ← ❌ SAI

-- Dòng 1 của taoBang_new.sql:
CREATE Database csdl_banhang;  ← ✅ IDB thực sự tên này
```

**File `sinhdulieu_new.sql` USE `QuanLyBanHang`** nhưng IDB được tạo bởi `taoBang_new.sql` có tên `csdl_banhang`. ETL cũng reference `csdl_banhang.dbo.*`. ⟹ **Sinh dữ liệu sẽ chạy vào database sai hoặc lỗi runtime.**

### ⚠️ Vấn đề dữ liệu sinh

| Vấn đề | Chi tiết | Ảnh hưởng |
|--------|----------|-----------|
| **KH du lịch & bưu điện không giao nhau** | Dòng 48-53: `ID <= 500` → DuLich, `ID > 500` → BuuDien. Hai tập **không giao nhau**. | `LoaiKhachHang = 'Du lịch & Bưu điện'` sẽ **không bao giờ xuất hiện** trong DW. Đề bài yêu cầu "KH cả 2 loại" → Q9 trả kết quả = 0. |
| **Đơn hàng dồn vào ~42 ngày** | Dòng 79: `DATEADD(HOUR, -ID, GETDATE())` → 1000 giờ ≈ 42 ngày. | Dim_ThoiGian chỉ có 1-2 tháng. Drill Down theo Năm/Quý gần như vô nghĩa (chỉ 1 năm, 1 quý). |
| **Mỗi đơn chỉ 1 mặt hàng** | Dòng 84-91: 1 INSERT per ID → 1000 dòng = 1 item/đơn. | Chi tiết đơn hàng rất mỏng, vùng dữ liệu cho aggregate bị hẹp. |
| **Tồn kho 1-1** | Dòng 94-100: `CH{ID} + MH{ID}` → mỗi CH chỉ có 1 MH. | Cube_TonKho rất thưa, Q7 (tồn kho MH tại các CH ở 1 TP) hầu như chỉ trả 1 dòng. |

### ✅ Đã đúng

| Điểm tốt | Chi tiết |
|----------|----------|
| Dùng Stored Procedure | Gọn gàng, dễ tái thực thi |
| 1000 dòng mỗi bảng | Đủ yêu cầu số lượng tối thiểu |
| CTE tạo dãy số nhanh | Kỹ thuật tốt, không dùng WHILE loop chậm |
| Xóa dữ liệu cũ đúng thứ tự FK | Bảng con trước, bảng cha sau |
| NEWID()/CHECKSUM cho random | ĐÚng kỹ thuật sinh ngẫu nhiên trong SQL Server |

### Ước tính sinh dữ liệu: **0.60 / 1.0** *(trừ nặng vì sai tên DB + dữ liệu thiếu đa dạng)*

---

## 3.2 ETL (`ETL_IDB_to_DW.sql`)

### ✅ Đúng — Nhất quán hoàn toàn với schema mới

| Điểm tốt | Chi tiết |
|----------|----------|
| Tên cột nhất quán | `Thang, Quy, Nam, TimeKey` khớp với `taoBangFact_Dim_new.sql` |
| Thứ tự xóa/nạp đúng FK | DELETE Fact → Dim; INSERT Dim → Fact |
| `Dim_ThoiGian` sinh từ dữ liệu thực | `MIN(NgayDatHang)` → `GETDATE()`, không hardcode |
| `LoaiKhachHang` derive 4 loại | Du lịch / Bưu điện / Du lịch & Bưu điện / Thường |
| `Fact_BanHang` GROUP BY đúng 3 chiều | `(MaKhachHang, MaMatHang, TimeKey)` — khớp PK |
| `Fact_Kho` ROW_NUMBER lấy snapshot mới nhất | Tránh vi phạm PK, JOIN Dim_ThoiGian qua Thang+Nam |
| Log từng bước `[1/7]...[8/8]` | Dễ debug và kiểm chứng |
| Index tạo sau bulk insert | Đúng thứ tự tối ưu hiệu năng |
| Index cho TimeKey trên cả 2 Fact | `IX_Fact_BanHang_TG`, `IX_Fact_Kho_TK` |

### ⚠️ Lưu ý nhỏ

| Vấn đề | Mức độ |
|--------|--------|
| `Dim_KhachHang.MaThanhPho` không có FK constraint trong schema | Thiếu tham chiếu đến `Dim_VPDD` — hợp lệ nhưng không chặt |
| `@@ROWCOUNT` ở dòng 43 chỉ trả 1 (WHILE loop) | Log sai cho Dim_ThoiGian, nên dùng `SELECT COUNT(*)` thay thế |

### Ước tính ETL: **0.90 / 1.0**

### Ước tính tổng Bước 3: **1.50 / 2.0**

---

---

# BƯỚC 4 — Phân cấp chiều + OLAP Cubes

> **Điểm tối đa:** 0.5đ (phân cấp) + 1.0đ (OLAP cubes) = 1.5đ

---

## 4.1 Phân cấp chiều

### ✅ Đúng — Phân cấp hợp lý, khớp với Metadata

| Chiều | Phân cấp | Số cấp | Khai báo trong |
|-------|----------|--------|----------------|
| Dim_ThoiGian | **Năm → Quý → Tháng** | 3 | `Meta_Hierarchy` + SP DrillDown |
| Dim_CuaHang | **Bang → Thành phố → Cửa hàng** | 3 | `Meta_Hierarchy` + SP RollUp |
| Dim_KhachHang | **Loại KH → Khách hàng** | 2 | `Meta_Hierarchy` |
| Dim_VPDD | **Bang → Thành phố** | 2 | Implicit (thông qua Dim_CuaHang) |

### Ước tính phân cấp: **0.50 / 0.5** ✅

---

## 4.2 OLAP Cubes (`OLAP_Cubes.sql`)

### ✅ Nhất quán hoàn toàn với schema mới

**3 Materialized Cubes:**

| Cube | Chiều | Độ đo | JOIN |
|------|-------|-------|------|
| `Cube_DoanhThu` | LoaiKH × MaThanhPhoKH × MatHang × ThoiGian | TongSoLuongBan, TongDoanhThu | Fact_BanHang ⋈ Dim_KhachHang ⋈ Dim_MatHang ⋈ Dim_ThoiGian |
| `Cube_TonKho` | MatHang × CuaHang × ThanhPho × ThoiGian | TongTonKho | Fact_Kho ⋈ Dim_MatHang ⋈ Dim_CuaHang ⋈ Dim_VPDD ⋈ Dim_ThoiGian |
| `Cube_KhachHang` | LoaiKH × ThanhPho × ThoiGian | SoLuongKH, TongDoanhThu | Fact_BanHang ⋈ Dim_KhachHang ⋈ Dim_VPDD ⋈ Dim_ThoiGian |

- Tất cả JOIN dùng `f.TimeKey = tg.TimeKey` — ✅ đúng schema mới.
- `Cube_TonKho` có JOIN `Dim_ThoiGian` — ✅ vì `Fact_Kho` giờ có `TimeKey`.
- `Cube_KhachHang` lấy thông tin địa lý qua `Dim_KhachHang.MaThanhPho → Dim_VPDD` — ✅ đúng vì `Fact_BanHang` không còn `MaThanhPho`.
- Index trên các Cube — ✅.

**5 Stored Procedures:**

| SP | Phép toán | Đánh giá |
|----|----------|----------|
| `sp_DrillDown_ThoiGian(@Nam, @Quy)` | **Drill Down**: Năm → Quý → Tháng | ✅ Logic đúng, 3 mức IF/ELSE |
| `sp_RollUp_DiaDiem(@MucDo, @Nam)` | **Roll Up**: CuaHang → ThanhPho → Bang | ✅ Dùng `MAX(Nam)` khi không truyền @Nam |
| `sp_Slice_DoanhThu(@LoaiKH, @Nam, @KichCo)` | **Slice**: cắt 1 chiều | ✅ Filter NULL-safe |
| `sp_Dice_TonKho(@MaTP, @MaMH, @NamFrom, @NamTo)` | **Dice**: cắt nhiều chiều | ✅ Range filter cho năm |
| `sp_Pivot_DoanhThu` | **Pivot**: LoaiKH × Năm | ✅ PIVOT syntax đúng |

### ⚠️ Vấn đề 9 câu truy vấn nghiệp vụ (trong OLAP_Cubes.sql)

| Câu | Yêu cầu đề bài | Approach hiện tại | Đánh giá |
|-----|----------------|-------------------|----------|
| Q1 | CH + TP + SĐT + tất cả MH bán ở kho đó | `Cube_TonKho JOIN Dim_CuaHang JOIN Dim_VPDD JOIN Dim_MatHang` | ✅ Đúng |
| **Q2** | *Từng* đơn hàng + tên KH + *ngày* đặt | `Fact_BanHang` GROUP BY tháng → chỉ ra tổng hợp | ⚠️ Không liệt kê được từng đơn (MaDon bị mất). Giám khảo chú ý sẽ trừ. |
| **Q3** | CH bán MH được đặt bởi KH nào đó | `Fact_BanHang ⋈ Fact_Kho ON MaMatHang` | ⚠️ Trả về TẤT CẢ CH có MH đó trong kho, không phải CH thực sự phục vụ. Kết quả rộng hơn yêu cầu. |
| Q4 | VP + TP + Bang của CH lưu MH > ngưỡng | `Cube_TonKho HAVING` | ✅ Đúng |
| **Q5** | MH đặt + mô tả + mã CH + tên TP bán MH | Tương tự Q3 | ⚠️ Cùng vấn đề — cross-fact join |
| Q6 | TP + Bang KH sinh sống | `Dim_KhachHang JOIN Dim_VPDD` | ✅ Đúng |
| Q7 | Tồn kho MH tại CH ở 1 TP | `Cube_TonKho + filter` | ✅ Đúng |
| **Q8** | MH + SL + KH + CH + TP của đơn hàng | Tương tự Q3/Q5 | ⚠️ Cross-fact join |
| Q9 | KH du lịch, bưu điện, cả hai | `GROUP BY LoaiKhachHang` | ✅ Logic đúng (nhưng dữ liệu sinh không có KH "cả hai") |

**Tóm tắt:** 5/9 câu đúng hoàn toàn; 4/9 câu (Q2, Q3, Q5, Q8) có hạn chế do thiết kế schema — đây là **hệ quả** từ Bước 2, không phải lỗi code.

### Ước tính điểm Bước 4: **1.30 / 1.5**

---

---

# BƯỚC 5 — Metadata và các file Index

> **Điểm tối đa:** 1.0đ

---

## 5.1 Metadata (`Metadata.sql`)

### ✅ Đầy đủ 3 bảng Meta — Nhất quán với schema mới

**`Meta_Tables`** (7 bảng):

| TableName | TableType | Đánh giá |
|-----------|-----------|----------|
| Fact_BanHang | Fact | ✅ Source đúng: DonDatHang + MatHangDuocDat |
| Fact_Kho | Fact | ✅ Mô tả có "theo thời gian" — khớp schema mới có TimeKey |
| Dim_ThoiGian | Dimension | ✅ |
| Dim_KhachHang | Dimension | ✅ Source đúng: 3 bảng KH |
| Dim_MatHang | Dimension | ✅ |
| Dim_VPDD | Dimension | ✅ |
| Dim_CuaHang | Dimension | ✅ |

**`Meta_Columns`** — Kiểm tra nhất quán:

| Bảng | Cột | Đúng? |
|------|-----|-------|
| Fact_BanHang | MaKhachHang, MaMatHang, **TimeKey**, SoLuongBan, DoanhThu | ✅ Không còn MaThanhPho |
| Fact_Kho | MaMatHang, MaCuaHang, **TimeKey**, SoLuongTonKho | ✅ Có TimeKey |
| Dim_ThoiGian | **TimeKey** PK, **Thang**, **Quy**, **Nam** | ✅ Tên cột đúng |
| Dim_KhachHang | MaKH, TenKhachHang, MaThanhPho, LoaiKhachHang | ✅ |
| Dim_MatHang | MaMH, MoTa, KichCo, TrongLuong, DonGia | ✅ |
| Dim_VPDD | MaThanhPho, TenThanhPho, Bang, DiaChi | ✅ |
| Dim_CuaHang | MaCuaHang, MaThanhPho, Bang, SDT | ✅ |

**`Meta_Hierarchy`** — 3 chiều phân cấp mô tả đầy đủ ✅

**RowCount** tự cập nhật qua UPDATE ✅

### ⚠️ Thiếu sót nhỏ

| Vấn đề | Mức độ |
|--------|--------|
| Không có metadata cho Cube tables (Cube_DoanhThu, Cube_TonKho, Cube_KhachHang) | Nhỏ |
| Không có metadata cho 5 Stored Procedures | Nhỏ |

---

## 5.2 Index

### ✅ Đầy đủ

**Trong ETL_IDB_to_DW.sql** (trên Fact tables):
- `IX_Fact_BanHang_KH` → MaKhachHang
- `IX_Fact_BanHang_MH` → MaMatHang
- `IX_Fact_BanHang_TG` → **TimeKey** ✅
- `IX_Fact_Kho_MH` → MaMatHang
- `IX_Fact_Kho_CH` → MaCuaHang
- `IX_Fact_Kho_TK` → **TimeKey** ✅ (mới thêm)

**Trong OLAP_Cubes.sql** (trên Cube tables):
- `IX_Cube_DT_Nam`, `IX_Cube_DT_MH`, `IX_Cube_DT_KH`
- `IX_Cube_TK_MH`, `IX_Cube_TK_CH`, `IX_Cube_TK_TP`

Tất cả dùng `IF NOT EXISTS` — ✅ idempotent.

### Ước tính điểm Bước 5: **0.80 / 1.0**

---

---

# BƯỚC 6 — Giao diện Web OLAP

> **Điểm tối đa:** 2.0đ

---

## 6.1 Kiến trúc ứng dụng

| Thành phần | Công nghệ | File |
|------------|-----------|------|
| Backend | Flask (Python) | `webapp/app.py` |
| Database | pyodbc → SQL Server | `DW_BanHang` |
| Templates | Jinja2 HTML | 8 files trong `webapp/templates/` |
| Dependency | pyodbc, Flask | `requirements.txt` |

---

## 6.2 5 phép toán OLAP (`app.py`)

| Route | Phép toán | Nguồn dữ liệu | Đánh giá |
|-------|----------|----------------|----------|
| `/drilldown?nam=&quy=` | **Drill Down**: Năm → Quý → Tháng | `Cube_DoanhThu` | ✅ 3 level, IF/ELSE đúng |
| `/rollup?muc=&nam=` | **Roll Up**: CuaHang → ThanhPho → Bang | `Cube_TonKho` | ✅ MAX(Nam) động thay vì hardcode |
| `/slice?loai=&nam=&kichco=` | **Slice**: cắt 1 chiều cố định | `Cube_DoanhThu` | ✅ Filter NULL-safe, dropdown động |
| `/dice?matp=&mamh=&nam_f=&nam_t=` | **Dice**: cắt nhiều chiều | `Cube_TonKho` | ✅ Range filter, dropdown động |
| `/pivot` | **Pivot**: LoaiKH × Năm | `Cube_DoanhThu` | ✅ CASE WHEN pivot |

**Tất cả route đều nhất quán với tên cột schema mới** (`Nam, Quy, Thang, TimeKey`) ✅

---

## 6.3 9 câu truy vấn nghiệp vụ (`/query/<qid>`)

| Câu | Yêu cầu | Logic trong app.py | Đúng? |
|-----|---------|-------------------|-------|
| Q1 | CH + TP + SĐT + MH bán | `Cube_TonKho JOIN Dim_*` | ✅ |
| **Q2** | *Từng* đơn hàng + tên KH + ngày | `Fact_BanHang GROUP BY Nam, Thang` — ra tổng hợp tháng, không phải từng đơn | ⚠️ |
| **Q3** | CH bán MH đặt bởi KH | `Fact_BanHang ⋈ Fact_Kho ON MaMatHang` → cross-fact | ⚠️ |
| Q4 | VP + TP + Bang CH lưu MH > ngưỡng | `Cube_TonKho HAVING` | ✅ |
| **Q5** | MH + mã CH + TP bán MH (theo đơn KH) | Tương tự Q3 → cross-fact | ⚠️ |
| Q6 | TP + Bang KH sinh sống | `Dim_KhachHang JOIN Dim_VPDD` | ✅ |
| Q7 | TK MH tại CH ở 1 TP | `Cube_TonKho + filter` | ✅ |
| **Q8** | MH + SL + KH + CH + TP | Tương tự Q3/Q5 → cross-fact | ⚠️ |
| Q9 | KH du lịch / bưu điện / cả hai | `GROUP BY LoaiKhachHang` | ✅ |

Kết quả: **5/9 câu đúng hoàn toàn, 4/9 câu có hạn chế** do schema.

*Lưu ý:* Q3/Q5/Q8 dùng `Fact_BanHang ⋈ Fact_Kho ON MaMatHang` — khi `Fact_Kho` giờ có thêm `TimeKey` trong PK `(MaMatHang, MaCuaHang, TimeKey)`, JOIN chỉ trên `MaMatHang` sẽ nhân bản kết quả lên thêm vì mỗi tổ hợp `(MaMatHang, MaCuaHang)` có thể xuất hiện nhiều tháng. Kết quả bị phình thêm so với trước.

---

## 6.4 Vấn đề kỹ thuật

| Vấn đề | Mức độ |
|--------|--------|
| Không có `try/except` trong `query()` — lỗi DB sẽ crash app | ⚠️ Trung bình |
| Không có connection pooling | Thấp |
| Giá trị mặc định `KH1, MH1, VP1` | ✅ Khớp format `sinhdulieu_new.sql` |
| Tên cột Cube khớp app.py | ✅ Nhất quán |

### Ước tính điểm Bước 6: **1.60 / 2.0**

---

---

# TỔNG HỢP

## Bảng điểm chi tiết

| Bước | Nội dung | Tối đa | Ước tính | Ghi chú chính |
|------|----------|:------:|:--------:|--------------|
| **1** | Tích hợp 2 nguồn → IDB | 1.5 | **0.70** | Thiếu ER-1/ER-2/IER |
| **2** | Thiết kế Star Schema DW | 1.0 | **0.70** | Mất MaDon + thiếu MaCuaHang trong Fact_BanHang |
| **3** | ETL + Sinh dữ liệu | 2.0 | **1.50** | ETL tốt ✅ — Sinh dữ liệu sai tên DB + thiếu đa dạng |
| **4** | Phân cấp + OLAP Cubes | 1.5 | **1.30** | Cubes + SP nhất quán ✅ — 4/9 query bị hạn chế |
| **5** | Metadata + Index | 1.0 | **0.80** | Đầy đủ ✅ — Thiếu metadata cho Cubes/SP |
| **6** | Giao diện Web OLAP | 2.0 | **1.60** | 5 phép OLAP ✅ — 4/9 query ⚠️ |
| | **Tổng** | **9.0** | **~6.60** | |

---

## Việc cần làm — theo ưu tiên

### 🔴 Bắt buộc — Ảnh hưởng runtime

**1. Sửa tên database trong `sinhdulieu_new.sql`**
```sql
-- Dòng 1: sửa
USE QuanLyBanHang;   →   USE csdl_banhang;
```
Nếu không sửa, sinh dữ liệu sẽ chạy vào DB khác hoặc lỗi.
Ảnh hưởng: **Runtime error**, quyết định bài chạy được hay không.

**2. Cho KhachHang giao nhau giữa DuLich và BuuDien**
```sql
-- Hiện tại: ID <= 500 → DuLich, ID > 500 → BuuDien (không giao nhau)
-- Sửa: Ví dụ ID <= 600 → DuLich, ID > 400 → BuuDien
-- → ID 401-600 sẽ thuộc cả hai → LoaiKhachHang = 'Du lịch & Bưu điện'
```
Ảnh hưởng: Q9 sẽ có kết quả, LoaiKhachHang đa dạng hơn → **+0.1đ**

**3. Mở rộng phạm vi ngày đặt hàng**
```sql
-- Hiện tại: DATEADD(HOUR, -ID, ...) → chỉ ~42 ngày
-- Sửa: DATEADD(DAY, -(ABS(CHECKSUM(NEWID())) % 730), ...) → 2 năm
```
Ảnh hưởng: Drill Down theo Năm/Quý có ý nghĩa → **+0.1đ**

### 🟡 Quan trọng — Ảnh hưởng điểm báo cáo

**4. Bổ sung sơ đồ IER trong tài liệu docx** → **+0.5đ Bước 1**

**5. Viết đầy đủ 8 phần báo cáo theo đề** (đặc biệt phần "Kiểm tra tính đúng đắn") → **+0.5đ**

### 🟢 Cải thiện

**6. Thêm `try/except` trong Flask `query()`**

**7. Thêm metadata cho Cube tables và Stored Procedures** → **+0.1đ Bước 5**

---

## Nhận xét tổng quan

Phần **code SQL** (ETL, Metadata, OLAP Cubes) và **web app** viết tốt, nhất quán hoàn toàn với schema mới (`TimeKey`, `Thang/Quy/Nam`). Điểm yếu chính:

1. **Lỗi kỹ thuật nhỏ nhưng chặn runtime**: `sinhdulieu_new.sql` USE sai tên DB, dữ liệu sinh thiếu đa dạng thời gian và loại KH.
2. **Hạn chế thiết kế**: Fact_BanHang mất granularity đơn hàng và thiếu chiều CuaHang → 4/9 câu truy vấn không trả lời chính xác yêu cầu đề bài.
3. **Tài liệu**: Thiếu sơ đồ IER, thiếu phần kiểm tra tính đúng đắn.

Khắc phục mục 1 (sửa sinhdulieu_new.sql) là việc dễ nhất và có tác động lớn nhất. Mục 2 là hạn chế cố hữu của schema (file _new). Mục 3 cần viết tay trong docx.
