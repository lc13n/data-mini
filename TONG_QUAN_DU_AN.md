# Tài liệu Tổng Quan Dự Án

## 1. Mục đích của tài liệu này

Tài liệu này được viết để giúp một người mới có thể nắm nhanh toàn bộ dự án trong thư mục `btl/` mà không cần tự mò từng file từ đầu. Nội dung được tổng hợp từ:

- mã nguồn SQL và Python trong dự án,
- cấu trúc thư mục hiện tại,
- tài liệu mô tả đề bài đã được trích xuất trong workspace,
- hai file review nội bộ: `review.md` và `review_6buoc.md`.

Nếu cần một câu ngắn gọn nhất thì:

> Đây là một đồ án **Kho dữ liệu (Data Warehouse)** cho bài toán **bán hàng**, gồm các bước từ mô hình dữ liệu tích hợp, sinh dữ liệu, ETL vào DW, tạo cube OLAP, rồi dựng một webapp Flask để demo các thao tác Drill Down, Roll Up, Slice, Dice, Pivot và 9 truy vấn nghiệp vụ.

---

## 2. Dự án này giải bài toán gì?

Theo đề bài, doanh nghiệp có:

- nhiều cửa hàng ở nhiều thành phố/bang,
- dữ liệu khách hàng nằm ở một nguồn,
- dữ liệu bán hàng và tồn kho nằm ở một nguồn khác,
- nhu cầu phân tích xoay quanh khách hàng, đơn hàng, tồn kho, địa điểm và thời gian.

Mục tiêu của đồ án là:

1. Tích hợp dữ liệu từ 2 nguồn thành một cơ sở dữ liệu tích hợp.
2. Thiết kế kho dữ liệu dạng Star Schema.
3. Nạp dữ liệu từ nguồn tích hợp sang DW bằng ETL.
4. Tạo các khối dữ liệu phục vụ OLAP.
5. Làm ứng dụng web để demo phân tích OLAP.

Nói cách khác, dự án không chỉ là vài script SQL rời rạc, mà là một pipeline tương đối đầy đủ:

```text
Đề bài / Nguồn dữ liệu logic
    -> CSDL tích hợp (IDB)
    -> Data Warehouse (DW)
    -> Cube / truy vấn OLAP
    -> Web app để demo phân tích
```

---

## 3. Cấu trúc thư mục quan trọng

### 3.1. Các file SQL chính

| File | Vai trò |
|---|---|
| `taoBang_new.sql` | Tạo cơ sở dữ liệu tích hợp `csdl_banhang` và 9 bảng nguồn |
| `sinhdulieu_new.sql` | Sinh dữ liệu mẫu cho `csdl_banhang` |
| `taoBangFact_Dim_new.sql` | Tạo kho dữ liệu `DW_BanHang` với các bảng fact/dimension |
| `ETL_IDB_to_DW.sql` | ETL dữ liệu từ `csdl_banhang` sang `DW_BanHang` |
| `Metadata.sql` | Tạo metadata cho DW |
| `OLAP_Cubes.sql` | Tạo các cube vật lý, stored procedure OLAP và 9 truy vấn nghiệp vụ |

### 3.2. Phần ứng dụng web

| File / thư mục | Vai trò |
|---|---|
| `webapp/app.py` | Backend Flask kết nối SQL Server và render giao diện |
| `webapp/requirements.txt` | Dependencies Python |
| `webapp/templates/` | Các trang HTML cho dashboard, thao tác OLAP và kết quả truy vấn |

### 3.3. Tài liệu và file phụ trợ

| File | Ghi chú |
|---|---|
| `btlKhoDuLieu_new.docx` | Bản báo cáo/tài liệu dự án |
| `btlKhoDuLieu_old.docx` | Bản cũ |
| `review.md` | Review chi tiết theo tiêu chí chấm |
| `review_6buoc.md` | Review theo quy trình 6 bước |
| `taoBang_old.sql`, `SinhData_old.sql`, `taoBangFact_Dim_old.sql` | Bản thiết kế cũ |

Điểm quan trọng: phần mã đang vận hành đồng bộ chủ yếu nằm ở bộ file có hậu tố `_new`, cộng với `webapp/`.

---

## 4. Bức tranh kiến trúc tổng thể

### 4.1. Luồng xử lý end-to-end

```text
1) taoBang_new.sql
   Tạo CSDL tích hợp csdl_banhang

2) sinhdulieu_new.sql
   Sinh dữ liệu mẫu vào csdl_banhang

3) taoBangFact_Dim_new.sql
   Tạo Data Warehouse DW_BanHang

4) ETL_IDB_to_DW.sql
   Đổ dữ liệu từ csdl_banhang sang DW_BanHang

5) Metadata.sql
   Ghi metadata cho các bảng/cột/hierarchy

6) OLAP_Cubes.sql
   Tạo cube vật lý + stored procedures + truy vấn nghiệp vụ

7) webapp/app.py
   Đọc từ DW_BanHang / cube và hiển thị trên web
```

### 4.2. Công nghệ đang dùng

| Thành phần | Công nghệ |
|---|---|
| CSDL | Microsoft SQL Server |
| Truy cập DB từ Python | `pyodbc` |
| Backend web | Flask |
| Giao diện | Jinja2 + Bootstrap 5 CDN |
| Kiểu xác thực DB | `Trusted_Connection=yes` |

### 4.3. Tên các database chính

| Database | Vai trò |
|---|---|
| `csdl_banhang` | CSDL tích hợp / dữ liệu nguồn sau khi gom |
| `DW_BanHang` | Kho dữ liệu phục vụ phân tích |

---

## 5. CSDL tích hợp `csdl_banhang`

File tạo schema: `taoBang_new.sql`

Đây là lớp dữ liệu nghiệp vụ “gần nguồn”, trước khi chuyển sang mô hình kho dữ liệu.

### 5.1. Các bảng trong IDB

| Bảng | Ý nghĩa |
|---|---|
| `VanPhongDaiDien` | Thành phố, địa chỉ VP, bang, thời gian hoạt động |
| `KhachHang` | Thông tin khách hàng cơ bản |
| `KhachHangDuLich` | Phần mở rộng của khách du lịch |
| `KhachHangBuuDien` | Phần mở rộng của khách đặt qua bưu điện |
| `CuaHang` | Cửa hàng thuộc một thành phố |
| `MatHang` | Danh mục mặt hàng |
| `MatHang_DuocLuuTru` | Tồn kho của mặt hàng tại cửa hàng |
| `DonDatHang` | Đơn đặt hàng |
| `MatHangDuocDat` | Chi tiết mặt hàng trong đơn |

### 5.2. Quan hệ nghiệp vụ chính

- Một khách hàng thuộc một thành phố.
- Một thành phố có văn phòng đại diện.
- Một cửa hàng thuộc một thành phố.
- Một đơn đặt hàng thuộc về một khách hàng.
- Một đơn có thể chứa nhiều mặt hàng.
- Một cửa hàng lưu nhiều mặt hàng trong kho.

### 5.3. Điểm đáng chú ý trong thiết kế

- `KhachHangDuLich` và `KhachHangBuuDien` là kiểu mở rộng từ `KhachHang`, dùng chung `MaKH`.
- `MatHang_DuocLuuTru` dùng khóa chính kép `(MaCuaHang, MaMatHang)`.
- `MatHangDuocDat` dùng khóa chính kép `(MaDon, MaMatHang)`.

### 5.4. Nhận xét

Mô hình này đã phản ánh tương đối rõ nghiệp vụ vận hành. Tuy nhiên, nó chủ yếu thể hiện **kết quả tích hợp cuối cùng**, còn tài liệu về bước đi từ ER nguồn -> IER -> IDB chưa thật rõ trong repo.

---

## 6. Sinh dữ liệu mẫu

File chính: `sinhdulieu_new.sql`

Script này tạo một stored procedure `Sp_SinhDuLieuLon_1000` để sinh dữ liệu quy mô 1000 dòng cho hầu hết các bảng.

### 6.1. Script đang làm gì

- Xóa dữ liệu cũ theo thứ tự tránh lỗi FK.
- Tạo dãy số từ 1 đến 1000 bằng CTE.
- Sinh:
  - 1000 văn phòng đại diện,
  - 1000 khách hàng,
  - 1000 cửa hàng,
  - 1000 mặt hàng,
  - 1000 đơn hàng,
  - 1000 dòng chi tiết đơn,
  - 1000 bản ghi tồn kho.

### 6.2. Điểm mạnh

- Dùng CTE sinh dữ liệu nhanh.
- Có xóa dữ liệu cũ trước khi nạp.
- Có mức dữ liệu đủ để demo ETL và OLAP.

### 6.3. Hạn chế hiện tại cần biết

Đây là phần rất quan trọng nếu bạn muốn hiểu đúng trạng thái dự án:

1. `sinhdulieu_new.sql` đang dùng:

```sql
USE QuanLyBanHang;
```

trong khi database được tạo ở `taoBang_new.sql` lại là:

```sql
CREATE DATABASE csdl_banhang;
```

Nghĩa là nếu chạy nguyên xi, script sinh dữ liệu có thể đổ vào nhầm DB hoặc lỗi runtime.

2. Nhóm khách hàng du lịch và bưu điện đang bị tách đôi hoàn toàn:

- `ID <= 500` vào `KhachHangDuLich`
- `ID > 500` vào `KhachHangBuuDien`

Do đó gần như **không có khách hàng thuộc cả hai loại**.

3. Ngày đặt hàng được sinh bằng `DATEADD(HOUR, -ID, GETDATE())`, nên dữ liệu dồn vào khoảng hơn 40 ngày gần nhất. Điều này làm phân tích theo năm/quý kém phong phú.

4. `MatHang_DuocLuuTru` hiện đang sinh kiểu 1 cửa hàng gắn với 1 mặt hàng theo cùng chỉ số ID, nên dữ liệu tồn kho hơi thưa.

---

## 7. Data Warehouse `DW_BanHang`

File tạo schema: `taoBangFact_Dim_new.sql`

Đây là trái tim phân tích của dự án. Mô hình được thiết kế theo dạng gần với Star Schema.

### 7.1. Các dimension

| Bảng | Cột chính | Vai trò |
|---|---|---|
| `Dim_ThoiGian` | `TimeKey, Thang, Quy, Nam` | Chiều thời gian |
| `Dim_VPDD` | `MaThanhPho, TenThanhPho, Bang, DiaChi` | Chiều địa lý cấp thành phố / VP |
| `Dim_KhachHang` | `MaKH, TenKhachHang, MaThanhPho, LoaiKhachHang` | Chiều khách hàng |
| `Dim_MatHang` | `MaMH, MoTa, KichCo, TrongLuong, DonGia` | Chiều mặt hàng |
| `Dim_CuaHang` | `MaCuaHang, MaThanhPho, Bang, SDT` | Chiều cửa hàng |

### 7.2. Các fact

| Bảng | Grain hiện tại | Measure |
|---|---|---|
| `Fact_BanHang` | `KhachHang x MatHang x ThoiGian(tháng)` | `SoLuongBan`, `DoanhThu` |
| `Fact_Kho` | `MatHang x CuaHang x ThoiGian` | `SoLuongTonKho` |

### 7.3. Cách hiểu nhanh mô hình sao

```text
                Dim_ThoiGian
                     |
Dim_KhachHang -- Fact_BanHang -- Dim_MatHang

Dim_ThoiGian
     |
Fact_Kho -- Dim_MatHang
     |
Dim_CuaHang -- Dim_VPDD
```

### 7.4. Ý nghĩa thiết kế

- `Fact_BanHang` dùng để phân tích doanh thu và sản lượng bán.
- `Fact_Kho` dùng để phân tích tồn kho theo địa điểm và thời gian.
- `Dim_ThoiGian` dùng surrogate key `TimeKey`, đúng tinh thần DW.
- `LoaiKhachHang` trong `Dim_KhachHang` là thuộc tính suy diễn từ hai bảng con.

### 7.5. Hạn chế thiết kế rất quan trọng

Nếu bạn cần hiểu dự án ở mức “đọc code rồi đánh giá được đúng/sai”, đây là điểm mấu chốt:

1. `Fact_BanHang` **không có `MaDon`**.

Điều này làm mất granularity cấp đơn hàng. Kết quả là các truy vấn kiểu “liệt kê từng đơn” không thể trả lời đúng hoàn toàn từ fact này.

2. `Fact_BanHang` **không có `MaCuaHang`**.

Nghĩa là từ dữ liệu bán hàng, hệ thống không biết đơn đó được phục vụ bởi cửa hàng nào. Đây là nguyên nhân chính khiến một số truy vấn nghiệp vụ phải join vòng qua `Fact_Kho` và cho kết quả chưa thật chính xác.

---

## 8. Luồng ETL từ IDB sang DW

File chính: `ETL_IDB_to_DW.sql`

### 8.1. Các bước ETL

1. Xóa dữ liệu cũ trong DW theo đúng thứ tự FK.
2. Sinh `Dim_ThoiGian` từ đơn hàng sớm nhất đến thời điểm hiện tại.
3. Đổ `Dim_VPDD` từ `VanPhongDaiDien`.
4. Đổ `Dim_KhachHang` từ `KhachHang` + `KhachHangDuLich` + `KhachHangBuuDien`.
5. Đổ `Dim_MatHang` từ `MatHang`.
6. Đổ `Dim_CuaHang` từ `CuaHang` và `VanPhongDaiDien`.
7. Tổng hợp sang `Fact_BanHang`.
8. Nạp `Fact_Kho` bằng snapshot mới nhất.
9. Tạo index.

### 8.2. Cách tính `LoaiKhachHang`

`LoaiKhachHang` được suy ra như sau:

- có trong `KhachHangDuLich` và `KhachHangBuuDien` -> `Du lịch & Bưu điện`
- chỉ có trong `KhachHangDuLich` -> `Du lịch`
- chỉ có trong `KhachHangBuuDien` -> `Bưu điện`
- không có ở cả hai -> `Thường`

### 8.3. Cách nạp `Fact_BanHang`

ETL join:

- `DonDatHang`
- `MatHangDuocDat`
- `Dim_ThoiGian`

rồi group theo:

- `MaKhachHang`
- `MaMatHang`
- `TimeKey`

Nghĩa là doanh thu đang được tổng hợp theo **tháng**, không giữ chi tiết từng đơn.

### 8.4. Cách nạp `Fact_Kho`

Script dùng `ROW_NUMBER()` để lấy bản ghi tồn kho mới nhất cho từng cặp:

- `MaMatHang`
- `MaCuaHang`

rồi map sang `TimeKey` theo tháng/năm của lần cập nhật đó.

### 8.5. Đánh giá phần ETL

Đây là một trong những phần tốt nhất của dự án:

- rõ ràng,
- có log `PRINT`,
- xóa/nạp đúng thứ tự,
- có index sau khi nạp,
- nhất quán với schema DW hiện tại.

---

## 9. Metadata và hierarchy

File chính: `Metadata.sql`

Dự án có một lớp metadata riêng cho DW, đây là điểm khá tốt vì nhiều đồ án sinh viên thường bỏ qua phần này.

### 9.1. Các bảng metadata

| Bảng | Chức năng |
|---|---|
| `Meta_Tables` | Mô tả bảng, loại bảng, nguồn gốc, mô tả, số dòng |
| `Meta_Columns` | Mô tả từng cột, kiểu dữ liệu, vai trò PK/FK/Measure/Attribute |
| `Meta_Hierarchy` | Mô tả phân cấp của các dimension |

### 9.2. Các hierarchy đang được mô tả

| Dimension | Hierarchy |
|---|---|
| `Dim_ThoiGian` | Năm -> Quý -> Tháng |
| `Dim_CuaHang` | Bang -> Thành phố -> Cửa hàng |
| `Dim_KhachHang` | Loại khách hàng -> Khách hàng |

### 9.3. Ý nghĩa thực tế

Lớp metadata này giúp:

- đọc hiểu hệ thống dễ hơn,
- giải thích measure/attribute rõ hơn,
- bám sát yêu cầu môn học về metadata và hierarchy.

---

## 10. Các cube OLAP

File chính: `OLAP_Cubes.sql`

Dự án dùng cách tạo **materialized cube table** thay vì dùng một OLAP server phức tạp riêng. Với phạm vi môn học, đây là một cách làm hợp lý để demo.

### 10.1. `Cube_DoanhThu`

Nguồn:

- `Fact_BanHang`
- `Dim_KhachHang`
- `Dim_MatHang`
- `Dim_ThoiGian`

Chiều chính:

- loại khách hàng,
- thành phố khách hàng,
- mặt hàng,
- thời gian.

Measure:

- `TongSoLuongBan`
- `TongDoanhThu`

### 10.2. `Cube_TonKho`

Nguồn:

- `Fact_Kho`
- `Dim_MatHang`
- `Dim_CuaHang`
- `Dim_VPDD`
- `Dim_ThoiGian`

Chiều chính:

- mặt hàng,
- cửa hàng,
- thành phố,
- bang,
- thời gian.

Measure:

- `TongTonKho`

### 10.3. `Cube_KhachHang`

Nguồn:

- `Fact_BanHang`
- `Dim_KhachHang`
- `Dim_VPDD`
- `Dim_ThoiGian`

Mục tiêu:

- xem khách hàng theo loại và địa lý,
- gắn thêm tổng doanh thu.

Cube này tồn tại nhưng mức độ sử dụng trong webapp hiện không nhiều bằng 2 cube đầu.

---

## 11. Các thao tác OLAP được hỗ trợ

Phần này xuất hiện ở cả SQL stored procedure lẫn giao diện web.

### 11.1. Drill Down

- Route: `/drilldown`
- Cube dùng: `Cube_DoanhThu`
- Luồng: `Năm -> Quý -> Tháng`

### 11.2. Roll Up

- Route: `/rollup`
- Cube dùng: `Cube_TonKho`
- Luồng: `Cửa hàng -> Thành phố -> Bang`

### 11.3. Slice

- Route: `/slice`
- Cube dùng: `Cube_DoanhThu`
- Bộ lọc chính: `LoaiKhachHang`, `Nam`, `KichCo`

### 11.4. Dice

- Route: `/dice`
- Cube dùng: `Cube_TonKho`
- Bộ lọc chính: `MaThanhPho`, `MaMatHang`, khoảng năm

### 11.5. Pivot

- Route: `/pivot`
- Cube dùng: `Cube_DoanhThu`
- Trục xoay: `LoaiKhachHang x Nam`

### 11.6. Stored procedures tương ứng

| Procedure | Mục đích |
|---|---|
| `sp_DrillDown_ThoiGian` | Drill down theo thời gian |
| `sp_RollUp_DiaDiem` | Roll up theo địa điểm |
| `sp_Slice_DoanhThu` | Slice doanh thu |
| `sp_Dice_TonKho` | Dice tồn kho |
| `sp_Pivot_DoanhThu` | Pivot doanh thu |

---

## 12. 9 truy vấn nghiệp vụ

Ngoài 5 thao tác OLAP chuẩn, dự án còn có 9 truy vấn nghiệp vụ theo đề bài. Chúng xuất hiện ở:

- cuối file `OLAP_Cubes.sql`,
- route `/query/<qid>` trong `webapp/app.py`.

### 12.1. Danh sách 9 truy vấn

| Q | Nội dung ngắn |
|---|---|
| Q1 | Cửa hàng + thành phố + bang + SĐT + các mặt hàng lưu/bán ở kho đó |
| Q2 | Đơn hàng của một khách hàng |
| Q3 | Cửa hàng bán mặt hàng mà một khách hàng đã đặt |
| Q4 | VP/TP/Bang của cửa hàng lưu kho một mặt hàng với tồn kho vượt ngưỡng |
| Q5 | Mặt hàng khách đã đặt và cửa hàng/thành phố bán mặt hàng đó |
| Q6 | Thành phố và bang nơi khách hàng sinh sống |
| Q7 | Tồn kho của một mặt hàng tại các cửa hàng trong một thành phố |
| Q8 | Mặt hàng + số lượng + khách hàng + cửa hàng + thành phố của một đơn |
| Q9 | Thống kê khách du lịch, bưu điện, và cả hai loại |

### 12.2. Truy vấn nào đang đáng tin hơn?

| Truy vấn | Đánh giá ngắn |
|---|---|
| Q1 | Tương đối ổn |
| Q2 | Bị giới hạn vì fact không giữ `MaDon` |
| Q3 | Bị giới hạn vì `Fact_BanHang` không có `MaCuaHang` |
| Q4 | Tương đối ổn |
| Q5 | Bị giới hạn tương tự Q3 |
| Q6 | Ổn |
| Q7 | Ổn |
| Q8 | Bị giới hạn tương tự Q3 và còn mất granularity đơn hàng |
| Q9 | Logic ổn, nhưng dữ liệu mẫu có thể không sinh ra nhóm “cả hai loại” |

### 12.3. Tại sao Q2, Q3, Q5, Q8 có vấn đề?

Nguyên nhân gốc nằm ở thiết kế DW:

- `Fact_BanHang` không có `MaDon`, nên không còn mức chi tiết “từng đơn”.
- `Fact_BanHang` không có `MaCuaHang`, nên không biết chính xác cửa hàng nào phục vụ.

Vì vậy các truy vấn phải join vòng qua `Fact_Kho` dựa trên `MaMatHang`, mà cách join này dễ trả về “mọi cửa hàng có mặt hàng đó”, không chắc là “cửa hàng phục vụ đơn hàng thật”.

---

## 13. Ứng dụng web Flask

File chính: `webapp/app.py`

### 13.1. Backend làm gì?

`app.py` khá gọn:

- tạo `Flask app`,
- kết nối SQL Server qua `pyodbc`,
- có hàm `query(sql, params)` để chạy SQL và trả dữ liệu dạng list of dict,
- render template HTML cho từng route.

### 13.2. Cấu hình kết nối hiện tại

Ứng dụng đang kết nối theo chuỗi:

```text
DRIVER={ODBC Driver 17 for SQL Server};
SERVER=localhost;
DATABASE=DW_BanHang;
Trusted_Connection=yes;
```

Điều này có nghĩa:

- SQL Server phải chạy trên máy local,
- database `DW_BanHang` phải tồn tại,
- máy phải có `ODBC Driver 17 for SQL Server`.

### 13.3. Giao diện người dùng

Thư mục `templates/` gồm:

| File | Vai trò |
|---|---|
| `base.html` | Layout chung, sidebar điều hướng |
| `index.html` | Dashboard tổng quan |
| `drilldown.html` | Giao diện drill down |
| `rollup.html` | Giao diện roll up |
| `slice.html` | Giao diện slice |
| `dice.html` | Giao diện dice |
| `pivot.html` | Giao diện pivot |
| `query_result.html` | Trang kết quả cho Q1..Q9 |

### 13.4. Trải nghiệm UI hiện tại

- UI dùng Bootstrap nên khá dễ nhìn và dễ demo.
- Sidebar tách rõ 2 nhóm:
  - thao tác OLAP,
  - 9 câu nghiệp vụ.
- Dashboard trang chủ hiển thị số lượng:
  - 2 fact table,
  - 5 dimension table,
  - 3 cube,
  - 5 thao tác OLAP.

### 13.5. Hạn chế kỹ thuật ở webapp

1. Hàm `query()` chưa có `try/except`, nên nếu lỗi DB thì app dễ văng lỗi thẳng ra ngoài.
2. Không có connection pooling.
3. App đang query trực tiếp SQL viết tay trong route, chưa tách tầng service/repository.

Tuy vậy, với mục đích demo môn học thì cấu trúc này vẫn đủ dùng và dễ đọc.

---

## 14. Cách chạy dự án

Nếu bạn muốn dựng lại dự án từ đầu trên máy Windows + SQL Server, đây là thứ tự hợp lý nhất.

### 14.1. Chuẩn bị

- Cài SQL Server.
- Cài `ODBC Driver 17 for SQL Server`.
- Cài Python.

### 14.2. Tạo và nạp dữ liệu

Chạy lần lượt các script SQL sau trong SSMS:

1. `taoBang_new.sql`
2. `sinhdulieu_new.sql`
3. `taoBangFact_Dim_new.sql`
4. `ETL_IDB_to_DW.sql`
5. `Metadata.sql`
6. `OLAP_Cubes.sql`

### 14.3. Lưu ý trước khi chạy

Nên sửa dòng đầu của `sinhdulieu_new.sql` từ:

```sql
USE QuanLyBanHang;
```

thành:

```sql
USE csdl_banhang;
```

### 14.4. Chạy webapp

Trong thư mục `webapp/`:

```bash
pip install -r requirements.txt
python app.py
```

Sau đó mở:

```text
http://localhost:5000
```

---

## 15. Điểm mạnh của dự án

Nếu nhìn như một đồ án môn học, dự án có nhiều điểm tốt:

1. Có pipeline gần như đầy đủ từ dữ liệu nguồn đến web demo.
2. Tách rõ lớp IDB, DW, cube và webapp.
3. ETL viết khá mạch lạc.
4. Có metadata và hierarchy riêng.
5. Có đủ 5 thao tác OLAP cơ bản.
6. Có 9 truy vấn nghiệp vụ để bám sát đề bài.
7. Phần web đủ trực quan để thuyết trình/demo.

---

## 16. Hạn chế và rủi ro hiện tại

Đây là phần bạn nên đọc kỹ để hiểu đúng dự án ở trạng thái hiện tại, tránh nhầm rằng mọi thứ đã hoàn hảo.

### 16.1. Vấn đề dữ liệu mẫu

- Sai tên DB ở `sinhdulieu_new.sql`.
- Không sinh ra tự nhiên nhóm khách hàng “Du lịch & Bưu điện”.
- Dữ liệu thời gian chưa trải dài, nên drill down theo năm/quý chưa thật giàu ý nghĩa.
- Tồn kho sinh hơi đơn giản.

### 16.2. Vấn đề thiết kế DW

- `Fact_BanHang` thiếu `MaDon`.
- `Fact_BanHang` thiếu `MaCuaHang`.

Đây là hai điểm ảnh hưởng mạnh nhất tới độ đúng của các truy vấn nghiệp vụ.

### 16.3. Vấn đề truy vấn nghiệp vụ

Các truy vấn Q2, Q3, Q5, Q8 đang có giới hạn logic, không phải chỉ là lỗi cú pháp hay lỗi nhỏ.

### 16.4. Vấn đề tài liệu học thuật

Theo review trong repo, báo cáo còn thiếu hoặc chưa thể hiện đủ:

- ER riêng của từng nguồn,
- IER sau khi tích hợp,
- phần kiểm tra tính đúng đắn dữ liệu,
- phần kết luận/phân công công việc đầy đủ.

---

## 17. Nếu muốn nâng cấp dự án thì nên làm gì trước?

Nếu bạn hoặc nhóm muốn cải thiện dự án thật sự, thứ tự ưu tiên nên là:

1. Sửa `sinhdulieu_new.sql` để đúng tên DB và sinh dữ liệu đa dạng hơn.
2. Thiết kế lại `Fact_BanHang` để giữ được:
   - `MaDon`,
   - `MaCuaHang`.
3. Viết lại Q2, Q3, Q5, Q8 sau khi đã sửa schema.
4. Bổ sung tài liệu ER -> IER -> IDB.
5. Thêm kiểm thử đối chiếu giữa dữ liệu nguồn và dữ liệu OLAP.
6. Bọc `query()` trong `try/except` ở Flask.

---

## 18. Thứ tự đọc code khuyến nghị cho người mới

Nếu bạn chỉ có 30-60 phút để nắm dự án, hãy đọc theo thứ tự sau:

1. `taoBang_new.sql`
2. `taoBangFact_Dim_new.sql`
3. `ETL_IDB_to_DW.sql`
4. `OLAP_Cubes.sql`
5. `webapp/app.py`
6. `webapp/templates/index.html`
7. `review.md`
8. `review_6buoc.md`

Lý do:

- đọc `taoBang_new.sql` để hiểu nghiệp vụ nguồn,
- đọc `taoBangFact_Dim_new.sql` để hiểu mô hình phân tích,
- đọc `ETL_IDB_to_DW.sql` để hiểu dữ liệu biến đổi ra sao,
- đọc `OLAP_Cubes.sql` để hiểu phần demo phân tích,
- đọc `app.py` để hiểu web dùng dữ liệu đó như thế nào.

---

## 19. Kết luận ngắn gọn

Đây là một dự án kho dữ liệu tương đối đầy đủ cho bài toán bán hàng:

- có mô hình dữ liệu tích hợp,
- có DW,
- có ETL,
- có metadata,
- có cube,
- có webapp demo OLAP.

Phần mạnh nhất của dự án là tính end-to-end và sự hiện diện của đủ các lớp từ dữ liệu đến giao diện. Phần yếu nhất nằm ở:

- chất lượng dữ liệu mẫu,
- thiết kế `Fact_BanHang`,
- độ chính xác của một số truy vấn nghiệp vụ,
- độ đầy đủ của tài liệu học thuật.

Nếu bạn nắm được 4 lớp sau thì xem như đã hiểu phần lớn dự án:

```text
IDB -> DW -> Cube -> Flask Web
```

Và nếu cần nhớ đúng “điểm nghẽn” lớn nhất của hệ thống hiện tại, thì đó là:

```text
Fact_BanHang đang quá tổng hợp:
thiếu MaDon và thiếu MaCuaHang.
```

