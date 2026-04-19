/**
 * DW OLAP Web Application — Node.js + Express Backend
 * Kết nối SQL Server (DW_BanHang) qua Windows Authentication
 */

const express = require('express');
const sql     = require('mssql');
const path    = require('path');

const app  = express();
const PORT = 3000;

// ─── Cấu hình kết nối SQL Server ───────────────────────────────────────────
// Dùng SQL Server Authentication (username + password)
// Đảm bảo SQL Server đã bật chế độ "SQL Server and Windows Authentication mode"
const DB_CONFIG = {
  server:   process.env.DB_SERVER   || 'localhost',
  port:     process.env.DB_PORT     ? parseInt(process.env.DB_PORT) : 1433,
  database: process.env.DB_NAME     || 'DW_BanHang',
  user:     process.env.DB_USER     || 'sa',
  password: process.env.DB_PASSWORD || '123456',
  options: {
    instanceName:           process.env.DB_INSTANCE || 'SQLEXPRESS',
    trustServerCertificate: true,
    encrypt:                false,
    enableArithAbort:       true,
  },
  pool: {
    max: 10,
    min: 0,
    idleTimeoutMillis: 30000,
  },
};

let pool;

async function getPool() {
  if (!pool) {
    pool = await sql.connect(DB_CONFIG);
    console.log('✅ Kết nối SQL Server thành công → DW_BanHang');
  }
  return pool;
}

// ─── Middleware ─────────────────────────────────────────────────────────────
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// ─── Helper: thực thi query và trả về { columns, rows } ────────────────────
async function runQuery(sqlText, params = {}) {
  const p = await getPool();
  const req = p.request();
  for (const [key, val] of Object.entries(params)) {
    if (val === null || val === undefined) {
      req.input(key, sql.NVarChar, null);
    } else if (typeof val === 'number' && Number.isInteger(val)) {
      req.input(key, sql.Int, val);
    } else if (typeof val === 'number') {
      req.input(key, sql.Decimal(18, 2), val);
    } else {
      req.input(key, sql.NVarChar, String(val));
    }
  }
  const result = await req.query(sqlText);
  const columns = result.recordset.columns
    ? Object.keys(result.recordset.columns)
    : result.recordset.length > 0 ? Object.keys(result.recordset[0]) : [];
  return { columns, rows: result.recordset };
}

// ─── API: Health check ───────────────────────────────────────────────────────
app.get('/api/health', async (req, res) => {
  try {
    await getPool();
    res.json({ status: 'ok', database: 'DW_BanHang', timestamp: new Date() });
  } catch (e) {
    res.status(500).json({ status: 'error', message: e.message });
  }
});

// ─── API: DRILL DOWN — Doanh thu Năm → Quý → Tháng ─────────────────────────
app.get('/api/drilldown', async (req, res) => {
  try {
    const nam = req.query.nam ? parseInt(req.query.nam) : null;
    const quy = req.query.quy ? parseInt(req.query.quy) : null;

    let sqlText, params, level;

    if (!nam) {
      sqlText = `
        SELECT Nam, SUM(TongDoanhThu) AS DoanhThu, SUM(TongSoLuongBan) AS SoLuong
        FROM Cube_DoanhThu
        GROUP BY Nam ORDER BY Nam`;
      params = {}; level = 'nam';
    } else if (!quy) {
      sqlText = `
        SELECT Nam, Quy, SUM(TongDoanhThu) AS DoanhThu, SUM(TongSoLuongBan) AS SoLuong
        FROM Cube_DoanhThu WHERE Nam = @nam
        GROUP BY Nam, Quy ORDER BY Quy`;
      params = { nam }; level = 'quy';
    } else {
      sqlText = `
        SELECT Nam, Quy, Thang, SUM(TongDoanhThu) AS DoanhThu, SUM(TongSoLuongBan) AS SoLuong
        FROM Cube_DoanhThu WHERE Nam = @nam AND Quy = @quy
        GROUP BY Nam, Quy, Thang ORDER BY Thang`;
      params = { nam, quy }; level = 'thang';
    }

    const { columns, rows } = await runQuery(sqlText, params);
    res.json({ level, columns, rows, nam, quy });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ─── API: ROLL UP — Tồn kho CH → TP → Bang ─────────────────────────────────
app.get('/api/rollup', async (req, res) => {
  try {
    const muc = req.query.muc || 'cuahang';
    let nam   = req.query.nam ? parseInt(req.query.nam) : null;

    if (!nam) {
      const { rows } = await runQuery('SELECT MAX(Nam) AS MaxNam FROM Cube_TonKho');
      nam = rows[0]?.MaxNam || new Date().getFullYear();
    }

    let sqlText;
    if (muc === 'cuahang') {
      sqlText = `
        SELECT MaCuaHang, TenThanhPho, Bang, SUM(TongTonKho) AS TonKho
        FROM Cube_TonKho WHERE Nam = @nam
        GROUP BY MaCuaHang, TenThanhPho, Bang ORDER BY TonKho DESC`;
    } else if (muc === 'thanhpho') {
      sqlText = `
        SELECT TenThanhPho, Bang, SUM(TongTonKho) AS TonKho
        FROM Cube_TonKho WHERE Nam = @nam
        GROUP BY TenThanhPho, Bang ORDER BY TonKho DESC`;
    } else {
      sqlText = `
        SELECT Bang, SUM(TongTonKho) AS TonKho
        FROM Cube_TonKho WHERE Nam = @nam
        GROUP BY Bang ORDER BY TonKho DESC`;
    }

    const { columns, rows } = await runQuery(sqlText, { nam });
    res.json({ muc, nam, columns, rows });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ─── API: SLICE — Cắt 1 chiều ───────────────────────────────────────────────
app.get('/api/slice', async (req, res) => {
  try {
    const loai   = req.query.loai   || null;
    const nam    = req.query.nam    ? parseInt(req.query.nam) : null;
    const kichco = req.query.kichco || null;

    const sqlText = `
      SELECT LoaiKhachHang, Nam, Quy, KichCo,
             SUM(TongSoLuongBan) AS SoLuong,
             SUM(TongDoanhThu)   AS DoanhThu
      FROM Cube_DoanhThu
      WHERE (@loai   IS NULL OR LoaiKhachHang = @loai)
        AND (@nam    IS NULL OR Nam            = @nam)
        AND (@kichco IS NULL OR KichCo         = @kichco)
      GROUP BY LoaiKhachHang, Nam, Quy, KichCo
      ORDER BY Nam, Quy`;

    const { columns, rows } = await runQuery(sqlText, { loai, nam, kichco });
    res.json({ columns, rows, filters: { loai, nam, kichco } });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ─── API: DICE — Cắt nhiều chiều ────────────────────────────────────────────
app.get('/api/dice', async (req, res) => {
  try {
    const matp  = req.query.matp  || null;
    const mamh  = req.query.mamh  || null;
    const nam_f = req.query.nam_f ? parseInt(req.query.nam_f) : null;
    const nam_t = req.query.nam_t ? parseInt(req.query.nam_t) : null;

    const sqlText = `
      SELECT MaMatHang, MoTaMatHang, KichCo,
             TenThanhPho, Bang,
             Nam, Quy, Thang, SUM(TongTonKho) AS TonKho
      FROM Cube_TonKho
      WHERE (@matp  IS NULL OR MaThanhPhoCH = @matp)
        AND (@mamh  IS NULL OR MaMatHang    = @mamh)
        AND (@nam_f IS NULL OR Nam          >= @nam_f)
        AND (@nam_t IS NULL OR Nam          <= @nam_t)
      GROUP BY MaMatHang, MoTaMatHang, KichCo, TenThanhPho, Bang, Nam, Quy, Thang
      ORDER BY Nam, Thang`;

    const { columns, rows } = await runQuery(sqlText, { matp, mamh, nam_f, nam_t });
    res.json({ columns, rows, filters: { matp, mamh, nam_f, nam_t } });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ─── API: PIVOT — Doanh thu LoaiKH × Năm ────────────────────────────────────
app.get('/api/pivot', async (req, res) => {
  try {
    const sqlText = `
      SELECT Nam,
        ISNULL(SUM(CASE WHEN LoaiKhachHang = N'Du lịch'  THEN TongDoanhThu END), 0) AS DuLich,
        ISNULL(SUM(CASE WHEN LoaiKhachHang = N'Bưu điện' THEN TongDoanhThu END), 0) AS BuuDien,
        ISNULL(SUM(CASE WHEN LoaiKhachHang = N'Cả hai'   THEN TongDoanhThu END), 0) AS CaHai,
        SUM(TongDoanhThu) AS TongCong
      FROM Cube_DoanhThu
      GROUP BY Nam ORDER BY Nam`;

    const { columns, rows } = await runQuery(sqlText);
    res.json({ columns, rows });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ─── API: 9 Câu Truy Vấn Nghiệp Vụ ─────────────────────────────────────────
app.get('/api/query/:id', async (req, res) => {
  try {
    const id     = parseInt(req.params.id);
    const makh   = req.query.makh   || 'KH0001';
    const mamh   = req.query.mamh   || 'MH0013';
    const matp   = req.query.matp   || 'HN';
    const nguong = req.query.nguong ? parseInt(req.query.nguong) : 100;

    const queryMap = {
      1: {
        label: 'Tất cả cửa hàng + TP, bang, SĐT và mặt hàng bán ở kho đó',
        sql: `
          SELECT DISTINCT ch.MaCuaHang, vp.TenThanhPho, vp.Bang, ch.SoDienThoai,
            mh.MaMatHang, mh.MoTa, mh.KichCo, mh.TrongLuong, mh.DonGia
          FROM Cube_TonKho tk
          JOIN Dim_CuaHang ch ON tk.MaCuaHang = ch.MaCuaHang
          JOIN Dim_VPDD    vp ON ch.MaThanhPho = vp.MaThanhPho
          JOIN Dim_MatHang mh ON tk.MaMatHang  = mh.MaMatHang
          ORDER BY ch.MaCuaHang, mh.MaMatHang`,
        params: {},
      },
      2: {
        label: 'Tất cả đơn hàng + tên KH + thống kê của một khách hàng',
        sql: `
          SELECT kh.MaKhachHang, kh.TenKhachHang, tg.Nam, tg.Thang,
                 SUM(f.SoLuongBan) AS TongSoLuong, SUM(f.DoanhThu) AS DoanhThu
          FROM Fact_BanHang f
          JOIN Dim_KhachHang kh ON f.MaKhachHang = kh.MaKhachHang
          JOIN Dim_ThoiGian  tg ON f.MaThoiGian  = tg.MaThoiGian
          WHERE kh.MaKhachHang = @makh
          GROUP BY kh.MaKhachHang, kh.TenKhachHang, tg.Nam, tg.Thang
          ORDER BY tg.Nam, tg.Thang`,
        params: { makh },
      },
      3: {
        label: 'Cửa hàng + tên TP + SĐT có bán mặt hàng đặt bởi 1 KH cụ thể',
        sql: `
          SELECT DISTINCT ch.MaCuaHang, vp.TenThanhPho, ch.SoDienThoai, mh.MaMatHang, mh.MoTa
          FROM Fact_BanHang fb
          JOIN Dim_KhachHang kh ON fb.MaKhachHang = kh.MaKhachHang
          JOIN Fact_Kho      fk ON fb.MaMatHang   = fk.MaMatHang
          JOIN Dim_CuaHang   ch ON fk.MaCuaHang   = ch.MaCuaHang
          JOIN Dim_VPDD      vp ON ch.MaThanhPho  = vp.MaThanhPho
          JOIN Dim_MatHang   mh ON fb.MaMatHang   = mh.MaMatHang
          WHERE kh.MaKhachHang = @makh`,
        params: { makh },
      },
      4: {
        label: 'Địa chỉ VP + tên TP + bang của CH lưu kho một MH với SL > ngưỡng',
        sql: `
          SELECT vp.TenThanhPho, vp.Bang, vp.DiaChi, ch.MaCuaHang,
                 SUM(tk.TongTonKho) AS TonKho
          FROM Cube_TonKho tk
          JOIN Dim_CuaHang ch ON tk.MaCuaHang = ch.MaCuaHang
          JOIN Dim_VPDD    vp ON ch.MaThanhPho = vp.MaThanhPho
          WHERE tk.MaMatHang = @mamh
          GROUP BY vp.TenThanhPho, vp.Bang, vp.DiaChi, ch.MaCuaHang
          HAVING SUM(tk.TongTonKho) > @nguong
          ORDER BY TonKho DESC`,
        params: { mamh, nguong },
      },
      5: {
        label: 'Mặt hàng đặt + mô tả + mã CH + tên TP bán mặt hàng đó (theo đơn KH)',
        sql: `
          SELECT DISTINCT kh.TenKhachHang, mh.MaMatHang, mh.MoTa, ch.MaCuaHang, vp.TenThanhPho
          FROM Fact_BanHang fb
          JOIN Dim_KhachHang kh ON fb.MaKhachHang = kh.MaKhachHang
          JOIN Dim_MatHang   mh ON fb.MaMatHang   = mh.MaMatHang
          JOIN Fact_Kho      fk ON fb.MaMatHang   = fk.MaMatHang
          JOIN Dim_CuaHang   ch ON fk.MaCuaHang   = ch.MaCuaHang
          JOIN Dim_VPDD      vp ON ch.MaThanhPho  = vp.MaThanhPho
          WHERE kh.MaKhachHang = @makh`,
        params: { makh },
      },
      6: {
        label: 'Thành phố và bang mà 1 khách hàng sinh sống',
        sql: `
          SELECT kh.MaKhachHang, kh.TenKhachHang, vp.TenThanhPho, vp.Bang
          FROM Dim_KhachHang kh
          JOIN Dim_VPDD vp ON kh.MaThanhPho = vp.MaThanhPho
          WHERE kh.MaKhachHang = @makh`,
        params: { makh },
      },
      7: {
        label: 'Tồn kho của 1 mặt hàng tại tất cả CH ở 1 thành phố cụ thể',
        sql: `
          SELECT ch.MaCuaHang, vp.TenThanhPho, SUM(tk.TongTonKho) AS TonKho
          FROM Cube_TonKho tk
          JOIN Dim_CuaHang ch ON tk.MaCuaHang = ch.MaCuaHang
          JOIN Dim_VPDD    vp ON ch.MaThanhPho = vp.MaThanhPho
          WHERE tk.MaMatHang = @mamh AND tk.MaThanhPhoCH = @matp
          GROUP BY ch.MaCuaHang, vp.TenThanhPho
          ORDER BY TonKho DESC`,
        params: { mamh, matp },
      },
      8: {
        label: 'Mặt hàng + SL đặt + KH + CH + TP của một đơn đặt hàng cụ thể',
        sql: `
          SELECT kh.TenKhachHang, mh.MaMatHang, mh.MoTa,
                 SUM(fb.SoLuongBan) AS SoLuong, SUM(fb.DoanhThu) AS DoanhThu,
                 ch.MaCuaHang, vp.TenThanhPho
          FROM Fact_BanHang fb
          JOIN Dim_KhachHang kh ON fb.MaKhachHang = kh.MaKhachHang
          JOIN Dim_MatHang   mh ON fb.MaMatHang   = mh.MaMatHang
          JOIN Fact_Kho      fk ON fb.MaMatHang   = fk.MaMatHang
          JOIN Dim_CuaHang   ch ON fk.MaCuaHang   = ch.MaCuaHang
          JOIN Dim_VPDD      vp ON ch.MaThanhPho  = vp.MaThanhPho
          WHERE kh.MaKhachHang = @makh
          GROUP BY kh.TenKhachHang, mh.MaMatHang, mh.MoTa, ch.MaCuaHang, vp.TenThanhPho`,
        params: { makh },
      },
      9: {
        label: 'Khách hàng du lịch, bưu điện, cả hai loại và thường',
        sql: `
          SELECT LoaiKhachHang, COUNT(*) AS SoLuong
          FROM Dim_KhachHang
          WHERE LoaiKhachHang IN (N'Du lịch', N'Bưu điện', N'Cả hai')
          GROUP BY LoaiKhachHang
          ORDER BY SoLuong DESC`,
        params: {},
      },
    };

    if (!queryMap[id]) {
      return res.status(404).json({ error: `Query Q${id} không tồn tại` });
    }

    const { label, sql: sqlText, params } = queryMap[id];
    const { columns, rows } = await runQuery(sqlText, params);
    res.json({ id, label, columns, rows, params: { makh, mamh, matp, nguong } });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ─── API: Filter options ─────────────────────────────────────────────────────
app.get('/api/filters', async (req, res) => {
  try {
    const [loaiRes, namDTRes, kichcoRes, namTKRes, tpRes, mhRes] = await Promise.all([
      runQuery('SELECT DISTINCT LoaiKhachHang AS val FROM Cube_DoanhThu ORDER BY 1'),
      runQuery('SELECT DISTINCT Nam           AS val FROM Cube_DoanhThu ORDER BY 1'),
      runQuery('SELECT DISTINCT KichCo        AS val FROM Cube_DoanhThu ORDER BY 1'),
      runQuery('SELECT DISTINCT Nam           AS val FROM Cube_TonKho   ORDER BY 1'),
      runQuery('SELECT DISTINCT MaThanhPhoCH  AS ma, TenThanhPho AS ten FROM Cube_TonKho ORDER BY 2'),
      runQuery('SELECT DISTINCT MaMatHang     AS ma, MoTaMatHang AS ten FROM Cube_TonKho ORDER BY 1'),
    ]);
    res.json({
      loaiKH:    loaiRes.rows.map(r => r.val),
      namDT:     namDTRes.rows.map(r => r.val),
      kichCo:    kichcoRes.rows.map(r => r.val),
      namTK:     namTKRes.rows.map(r => r.val),
      thanhPho:  tpRes.rows,
      matHang:   mhRes.rows,
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ─── SPA Fallback ────────────────────────────────────────────────────────────
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// ─── Start Server ────────────────────────────────────────────────────────────
app.listen(PORT, async () => {
  console.log(`\n🚀 DW OLAP App đang chạy tại http://localhost:${PORT}`);
  console.log(`📊 Kết nối tới: ${DB_CONFIG.server} → ${DB_CONFIG.database}\n`);
  try { await getPool(); } catch (e) {
    console.error('⚠️  Lỗi kết nối DB:', e.message);
    console.error('   → Kiểm tra SQL Server đang chạy và tên instance đúng');
  }
});
