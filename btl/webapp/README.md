# DW OLAP Web App — Node.js

## Cách chạy

```bash
# 1. Vào thư mục webapp_js
cd btl/webapp_js

# 2. Cài dependencies (chỉ cần lần đầu)
npm install

# 3. Khởi động server
node server.js

# 4. Mở trình duyệt
# http://localhost:3000
```

## Yêu cầu

- Node.js v18+
- SQL Server đang chạy với database `DW_BanHang` đã được nạp dữ liệu
- Windows Authentication (Trusted Connection)

## Nếu gặp lỗi kết nối

Mở `server.js`, tìm `DB_CONFIG` và sửa:

```js
server: 'localhost\\SQLEXPRESS',  // Nếu dùng SQL Server Express
// hoặc
server: 'TEN_MAY_TINH\\TEN_INSTANCE',
```

## Cấu trúc

```
webapp_js/
├── server.js          ← Express backend + API routes
├── package.json
└── public/
    ├── index.html     ← Giao diện chính (SPA)
    ├── style.css      ← Dark theme CSS
    └── app.js         ← Frontend JS (fetch API, Chart.js, render)
```

## API Routes

| Route | Mô tả |
|-------|-------|
| GET /api/health | Kiểm tra kết nối DB |
| GET /api/drilldown?nam=&quy= | Drill Down doanh thu |
| GET /api/rollup?muc=&nam= | Roll Up tồn kho |
| GET /api/slice?loai=&nam=&kichco= | Slice doanh thu |
| GET /api/dice?matp=&mamh=&nam_f=&nam_t= | Dice tồn kho |
| GET /api/pivot | Pivot Loại KH × Năm |
| GET /api/query/:id?makh=&mamh=&matp=&nguong= | 9 câu nghiệp vụ |
| GET /api/filters | Lấy danh sách bộ lọc |
