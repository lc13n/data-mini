# ĐÁNH GIÁ BÀI TẬP LỚN — MÔN KHO DỮ LIỆU

> **Vai trò đánh giá:** Chuyên gia thiết kế kho dữ liệu  
> **Ngày đánh giá:** 2026-04-07  
> **Tổng điểm ước tính:** ~7.6 / 10

---

## Tóm tắt điểm

| # | Tiêu chí | Điểm tối đa | Ước tính |
|---|----------|:-----------:|:--------:|
| 1 | Tích hợp 2 nguồn → IDB | 0.5 | 0.35 |
| 2 | Thiết kế mô hình dữ liệu tích hợp (IDB) | 1.0 | 0.65 |
| 3 | Sinh dữ liệu | 1.0 | 0.85 |
| 4 | Thiết kế Star Schema (mô hình DW) | 1.0 | 0.65 |
| 5 | ETL — Ánh xạ từ IDB vào DW | 1.0 | 0.85 |
| 6 | Phân cấp chiều (Hierarchy) | 0.5 | 0.50 |
| 7 | Metadata và Index | 1.0 | 0.90 |
| 8 | Khối dữ liệu OLAP | 1.0 | 0.85 |
| 9 | Web OLAP (ứng dụng + 9 câu truy vấn) | 2.0 | 1.50 |
| 10 | Tài liệu báo cáo | 1.0 | 0.50 |
| **Tổng** | | **10.0** | **~7.60** |

---

## Chi tiết từng tiêu chí

---

### 1. Tích hợp hai nguồn dữ liệu → IDB `(0.5đ)` — Ước tính: **0.35 / 0.5**

#### Đã làm tốt
- Phân loại đúng quan hệ theo bảng PR1 / PR2 / SR1 (thể hiện trong file `btlKhoDuLieu.docx`).
- Tích hợp 2 CSDL thành `csdl_banhang` với FK chính xác:  
  `KhachHang.MaThanhPhoKhachHang → VanPhongDaiDien(MaThanhPho)`.

#### Thiếu sót
- Tài liệu **không thể hiện rõ quy trình bắt buộc**:  
  `Quan hệ → ER (từng nguồn) → Tích hợp 2 ER thành IER → Sinh bảng IDB`.  
  Nếu bài chỉ gộp bảng trực tiếp mà không vẽ IER, giám khảo sẽ trừ điểm phần này.

---

### 2. Thiết kế mô hình dữ liệu tích hợp (IDB) `(1đ)` — Ước tính: **0.65 / 1.0**

#### Đã làm tốt
- `taoBang.sql` cấu trúc đúng, FK hợp lệ, đặt tên thuộc tính rõ ràng (thêm ngữ nghĩa so với đề gốc: `ThoiGianKhaiTruong`, `ThoiGianTaoTaiKhoan`, ...).
- Xử lý đúng quan hệ kế thừa: `KhachHangDuLich`, `KhachHangBuuDien` đều tham chiếu `KhachHang(MaKH)`.

#### Thiếu sót
- Không có sơ đồ ER rõ ràng trong tài liệu (chỉ thấy ảnh nhúng không đọc được dạng text từ docx).
- Cột `MaKhachHang` trong `DonDatHang` (`taoBang.sql` dòng 68) tham chiếu `KhachHang(MaKH)` nhưng tên cột không đồng nhất với tên khóa chính gốc — dễ gây nhầm lẫn khi đọc schema.

---

### 3. Sinh dữ liệu `(1đ)` — Ước tính: **0.85 / 1.0**

#### Đã làm tốt
- 200 khách hàng, phân loại du lịch / bưu điện ngẫu nhiên có kiểm soát (`NEWID()`, `CHECKSUM`).
- 5 thành phố với địa chỉ và thời gian thực tế.
- Dữ liệu đơn hàng và tồn kho có vẻ được sinh đủ (có `SinhData_IDB.sql` và `SinhData.sql`).

#### Thiếu sót nhỏ
- Không rõ tổng số đơn hàng và số dòng `MatHang_DuocLuuTru` là bao nhiêu. Để OLAP có ý nghĩa thống kê, tối thiểu cần vài trăm đơn trải đều theo tháng/năm.

---

### 4. Thiết kế Star Schema (mô hình DW) `(1đ)` — Ước tính: **0.65 / 1.0**

#### Đã làm tốt
- 2 bảng Fact hợp lý: `Fact_BanHang`, `Fact_Kho`.
- 5 chiều rõ ràng: `Dim_ThoiGian`, `Dim_KhachHang`, `Dim_MatHang`, `Dim_CuaHang`, `Dim_VPDD`.
- Độ đo (`SoLuongBan`, `DoanhThu`, `SoLuongTonKho`) phù hợp bài toán.

#### Vấn đề nghiêm trọng

> **`Fact_BanHang` thiếu chiều `MaCuaHang`**  
> Đây là lỗi thiết kế ảnh hưởng trực tiếp đến câu Q1, Q3, Q5, Q8. Không có FK đến `Dim_CuaHang` trong fact table bán hàng nên không thể truy vết đơn hàng được phục vụ bởi cửa hàng nào.

> **Mất granularity đơn hàng**  
> `Fact_BanHang` tổng hợp theo `(MaKhachHang, MaMatHang, TimeKey)` — mã đơn hàng (`MaDon`) bị mất. Câu Q2 yêu cầu "liệt kê từng đơn đặt hàng với ngày đặt hàng" nhưng không thực hiện được từ fact table này.

---

### 5. ETL — Ánh xạ từ IDB vào DW `(1đ)` — Ước tính: **0.85 / 1.0**

#### Đã làm tốt
- `ETL_IDB_to_DW.sql` viết rõ ràng, đúng thứ tự xóa/nạp theo FK, có log từng bước.
- `Dim_ThoiGian` sinh động từ phạm vi dữ liệu thực tế (`MIN(NgayDatHang)` → `GETDATE()`), không hardcode.
- `LoaiKhachHang` được derive chính xác bằng LEFT JOIN 3 bảng, xử lý đủ 4 trường hợp (Du lịch / Bưu điện / Cả hai / Thường).
- Tạo index sau khi nạp dữ liệu — đúng thứ tự tối ưu hiệu năng.

#### Thiếu sót
- `Fact_Kho` ánh xạ trực tiếp từ `ThoiGianCapNhatNhapKho` — nếu cùng một sản phẩm tại cùng cửa hàng được cập nhật nhiều lần trong một tháng, sẽ có nhiều dòng trùng `(MaMatHang, MaCuaHang, TimeKey)` vi phạm PK.

---

### 6. Phân cấp chiều (Hierarchy) `(0.5đ)` — Ước tính: **0.50 / 0.5**

Đầy đủ và chính xác, đủ điểm tối đa:

| Chiều | Phân cấp |
|-------|---------|
| `Dim_ThoiGian` | Năm → Quý → Tháng |
| `Dim_CuaHang` | Bang → Thành phố → Cửa hàng |
| `Dim_KhachHang` | Loại khách hàng → Khách hàng |

---

### 7. Metadata và Index `(1đ)` — Ước tính: **0.90 / 1.0**

#### Đã làm tốt
- `Metadata.sql` tạo đủ 3 bảng: `Meta_Tables`, `Meta_Columns`, `Meta_Hierarchy`.
- Có cập nhật `RowCount` tự động sau khi nạp dữ liệu.
- Mô tả rõ `SourceColumn`, `KeyType` cho từng cột — mức độ chuyên nghiệp cao.
- Index đầy đủ trên cả Fact tables và Cube tables (tổng cộng ~11 index).

#### Thiếu sót nhỏ
- Không có bảng metadata mô tả các Stored Procedures và Cube tables — nếu có sẽ hoàn chỉnh hơn.

---

### 8. Khối dữ liệu OLAP `(1đ)` — Ước tính: **0.85 / 1.0**

#### Đã làm tốt
- 3 Materialized Cubes: `Cube_DoanhThu`, `Cube_TonKho`, `Cube_KhachHang`.
- 5 Stored Procedures bao phủ đủ các phép toán OLAP:

| SP | Phép toán |
|----|----------|
| `sp_DrillDown_ThoiGian` | Drill Down: Năm → Quý → Tháng |
| `sp_RollUp_DiaDiem` | Roll Up: Cửa hàng → Thành phố → Bang |
| `sp_Slice_DoanhThu` | Slice: cắt theo 1 chiều cố định |
| `sp_Dice_TonKho` | Dice: cắt theo nhiều chiều |
| `sp_Pivot_DoanhThu` | Pivot: xoay doanh thu theo loại khách hàng |

#### Thiếu sót
- `Cube_KhachHang` có cấu trúc tốt nhưng ít được sử dụng trong các truy vấn nghiệp vụ.
- Không có cube cho phân tích đơn hàng theo cửa hàng (hệ quả từ lỗi thiết kế ở tiêu chí 4).

---

### 9. Web OLAP `(2đ)` — Ước tính: **1.50 / 2.0**

#### Đã làm tốt
- Flask app đầy đủ các route: `/drilldown`, `/rollup`, `/slice`, `/dice`, `/pivot`.
- Template HTML cho tất cả thao tác OLAP (`drilldown.html`, `rollup.html`, `slice.html`, `dice.html`, `pivot.html`, `index.html`).
- 9 câu truy vấn nghiệp vụ đều có trong `OLAP_Cubes.sql`.

#### Vấn đề truy vấn nghiệp vụ

| Câu | Vấn đề |
|-----|-------|
| **Q2** | Query hiển thị tổng hợp theo tháng thay vì liệt kê từng đơn đặt hàng như yêu cầu |
| **Q3** | `JOIN Fact_BanHang ⋈ Fact_Kho ON MaMatHang` → tích Descartes: trả về tất cả cửa hàng *có* mặt hàng đó, không phải cửa hàng *phục vụ đơn* |
| **Q5** | Cùng vấn đề với Q3 — kết quả sai về nghiệp vụ |
| **Q8** | Cùng vấn đề với Q3, Q5 — không xác định được cửa hàng cụ thể |

---

### 10. Tài liệu báo cáo `(1đ)` — Ước tính: **0.50 / 1.0**

#### Thiếu sót
- File `btlKhoDuLieu.docx` rất mỏng — chủ yếu là bảng phân loại quan hệ và ảnh sơ đồ nhúng.
- **Thiếu hoặc không đầy đủ** các phần bắt buộc theo đề:
  - Giới thiệu (mục tiêu, phạm vi)
  - Đặc tả chức năng (đầu vào/đầu ra)
  - Kiểm tra tính đúng đắn của dữ liệu (so sánh OLAP vs RDBMS gốc)
  - Kết luận
- Không có phần **phân công công việc nhóm** (theo yêu cầu hướng dẫn chấm điểm).

---

## Các điểm cần sửa — Ưu tiên cao

### Lỗi thiết kế (ảnh hưởng điểm nhiều nhất)

1. **Thêm `MaCuaHang` vào `Fact_BanHang`**  
   Thêm FK `MaCuaHang → Dim_CuaHang` vào fact table bán hàng để truy vết cửa hàng phục vụ đơn.

2. **Giữ granularity đơn hàng**  
   Thêm `MaDon` vào Fact hoặc tạo một bảng staging riêng (`Fact_DonHang`) giữ nguyên chi tiết từng đơn — phục vụ Q2.

3. **Sửa Q3, Q5, Q8**  
   Không JOIN 2 fact table trực tiếp qua `MaMatHang`. Thay bằng cách truy vấn từ IDB hoặc thiết kế lại Fact_BanHang có MaCuaHang.

### Tài liệu

4. **Bổ sung đủ 8 phần báo cáo** — đặc biệt phần Kiểm tra tính đúng đắn (chạy cùng query trên IDB và trên DW, so sánh kết quả).

5. **Bổ sung phân công công việc nhóm** trong tài liệu.

---

## Nhận xét tổng quan

Bài làm thể hiện hiểu biết tốt về quy trình xây dựng kho dữ liệu: ETL được viết cẩn thận, Metadata đầy đủ, Web OLAP có đủ các phép toán cơ bản. Điểm yếu chính nằm ở **thiết kế Star Schema** (thiếu chiều cửa hàng trong Fact bán hàng) dẫn đến sai sót dây chuyền ở các truy vấn nghiệp vụ, và **tài liệu báo cáo** chưa hoàn chỉnh. Khắc phục 2 vấn đề này sẽ nâng điểm lên khoảng **8.5–9.0**.
