/**
 * DW OLAP Web Application — Node.js + Express Backend
 *
 * Kiến trúc kết nối:
 *   SQL Server (SQLEXPRESS → DW_BanHang) : Filter options + 9 câu query nghiệp vụ (Q1-Q9)
 *   SSAS       (SSAS_DW → DW_BanHang_SSAS) : 5 phép OLAP qua MDX
 *                                             (DrillDown, RollUp, Slice, Dice, Pivot)
 */

require('dotenv').config();
const express = require('express');
const sql     = require('mssql');
const path    = require('path');

// ─── SSAS / MDX Connection (node-adodb → MSOLAP) ────────────────────────────
let ssasConn;
const SSAS_SERVER = process.env.SSAS_SERVER || 'localhost\\SSAS_DW';
const SSAS_CATALOG = process.env.SSAS_CATALOG || 'DW_BanHang_SSAS';

try {
  const ADODB = require('node-adodb');
  ssasConn = ADODB.open(
    'Provider=MSOLAP;'               +
    `Data Source=${SSAS_SERVER};`    +
    `Initial Catalog=${SSAS_CATALOG};` +
    'Integrated Security=SSPI;'
  );
  console.log(`✅ SSAS connection initialized → ${SSAS_CATALOG} @ ${SSAS_SERVER}`);
} catch (e) {
  console.warn('⚠️  node-adodb chưa cài. Chạy: npm install node-adodb');
}

const app  = express();
const PORT = 3000;

// ─── SQL Server Config (cho 9 query nghiệp vụ + filter) ─────────────────────
const DB_OPTIONS = {
  trustServerCertificate: true,
  encrypt:                false,
  enableArithAbort:       true,
};

if (process.env.DB_INSTANCE) {
  DB_OPTIONS.instanceName = process.env.DB_INSTANCE;
}

const DB_CONFIG = {
  server:   process.env.DB_SERVER   || 'localhost',
  port:     process.env.DB_PORT     ? parseInt(process.env.DB_PORT) : 1433,
  database: process.env.DB_NAME     || 'DW_BanHang',
  user:     process.env.DB_USER     || 'sa',
  password: process.env.DB_PASSWORD || '123456',
  options:  DB_OPTIONS,
  pool: { max: 10, min: 0, idleTimeoutMillis: 30000 },
};

let pool;

async function getPool() {
  if (!pool) {
    pool = await sql.connect(DB_CONFIG);
    console.log('✅ Kết nối SQL Server thành công → DW_BanHang');
  }
  return pool;
}

// ─── Middleware ──────────────────────────────────────────────────────────────
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// ─── Helper: chạy SQL query, trả về { columns, rows } ───────────────────────
async function runQuery(sqlText, params = {}) {
  const p   = await getPool();
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
  const result  = await req.query(sqlText);
  const columns = result.recordset.columns
    ? Object.keys(result.recordset.columns)
    : result.recordset.length > 0 ? Object.keys(result.recordset[0]) : [];
  return { columns, rows: result.recordset };
}

// ─── Helper: chạy MDX query → SSAS, trả về { columns, rows } ────────────────
async function runMDX(mdx) {
  if (!ssasConn) {
    throw new Error('SSAS chưa kết nối. Chạy: npm install node-adodb rồi restart server.');
  }
  const rawRows = await ssasConn.query(mdx);
  if (!Array.isArray(rawRows) || rawRows.length === 0) {
    return { columns: [], rows: [] };
  }

  // Normalize tên cột MDX dạng "[Dim X].[H].[Level]" → "Level"
  const rawCols = Object.keys(rawRows[0]);
  const colMap  = {};
  const skipProps = ['MEMBER_CAPTION', 'MEMBER_KEY', 'MEMBER_UNIQUE_NAME', 'MEMBER_NAME', 'MEMBER_TYPE'];
  rawCols.forEach(rawKey => {
    let nice = rawKey;
    if (rawKey.includes('].')) {
      const parts = rawKey.replace(/\[|\]/g, '').split('.');
      nice = parts[parts.length - 1];
      if (skipProps.includes(nice) && parts.length > 1) {
        nice = parts[parts.length - 2];
      }
    }
    colMap[rawKey] = nice;
  });

  const columns = [...new Set(Object.values(colMap))];
  const rows    = rawRows.map(row => {
    const obj = {};
    rawCols.forEach(k => { obj[colMap[k]] = row[k]; });
    return obj;
  });
  return { columns, rows };
}

// ─── Helper: đổi tên cột sau khi runMDX (MDX trả về tên có space) ───────────
function renameResult({ columns, rows }, map) {
  const newCols = columns.map(c => map[c] !== undefined ? map[c] : c);
  const newRows = rows.map(r => {
    const obj = {};
    columns.forEach(c => { obj[map[c] !== undefined ? map[c] : c] = r[c]; });
    return obj;
  });
  return { columns: newCols, rows: newRows };
}

// ─── API: Health check ───────────────────────────────────────────────────────
app.get('/api/health', async (req, res) => {
  try {
    await getPool();
    res.json({
      status:    'ok',
      sqlServer: `${DB_CONFIG.server}\\${DB_CONFIG.options.instanceName} → ${DB_CONFIG.database}`,
      ssas:      ssasConn ? 'localhost\\SSAS_DW → DW_BanHang_SSAS' : 'not connected',
      timestamp: new Date(),
    });
  } catch (e) {
    res.status(500).json({ status: 'error', message: e.message });
  }
});

// ─── API: DRILL DOWN — Doanh thu Năm → Quý → Tháng (MDX → SSAS) ─────────────
// ?                    → tổng doanh thu theo Năm
// ?nam=2023            → drill down vào 2023, kết quả theo Quý
// ?nam=2023&quy=1      → drill down vào Q1/2023, kết quả theo Tháng
app.get('/api/drilldown', async (req, res) => {
  try {
    const nam = req.query.nam ? parseInt(req.query.nam) : null;
    const quy = req.query.quy ? parseInt(req.query.quy) : null;
    let mdx, level;

    if (!nam) {
      level = 'nam';
      mdx = `
        SELECT {[Measures].[Doanh Thu],[Measures].[So Luong Ban]} ON COLUMNS,
               NON EMPTY [Dim Thoi Gian].[Thoi Gian].[Nam].MEMBERS ON ROWS
        FROM [DW Ban Hang]`;
    } else if (!quy) {
      level = 'quy';
      mdx = `
        SELECT {[Measures].[Doanh Thu],[Measures].[So Luong Ban]} ON COLUMNS,
               NON EMPTY [Dim Thoi Gian].[Thoi Gian].[Nam].&[${nam}].Children ON ROWS
        FROM [DW Ban Hang]`;
    } else {
      level = 'thang';
      mdx = `
        SELECT {[Measures].[Doanh Thu],[Measures].[So Luong Ban]} ON COLUMNS,
               NON EMPTY [Dim Thoi Gian].[Thoi Gian].[Thang].MEMBERS ON ROWS
        FROM [DW Ban Hang]
        WHERE ([Dim Thoi Gian].[Nam].&[${nam}],[Dim Thoi Gian].[Quy].&[${quy}])`;
    }

    const raw = await runMDX(mdx);
    // Đổi tên cột MDX → tên frontend expect
    const { columns, rows } = renameResult(raw, {
      'Doanh Thu':    'DoanhThu',
      'So Luong Ban': 'SoLuong',
    });
    res.json({ level, columns, rows, nam, quy });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ─── API: ROLL UP — Tồn kho CuaHang → ThanhPho → Bang (MDX → SSAS) ──────────
// ?muc=cuahang   → mức chi tiết nhất (từng cửa hàng)
// ?muc=thanhpho  → roll up theo thành phố
// ?muc=bang      → roll up cao nhất (theo bang/tỉnh)
app.get('/api/rollup', async (req, res) => {
  try {
    const muc = req.query.muc || 'cuahang';
    const measures = `{[Measures].[So Luong Ton Kho],[Measures].[Gia Tri Ton Kho]}`;
    let mdx;

    if (muc === 'cuahang') {
      mdx = `
        SELECT ${measures} ON COLUMNS,
               NON EMPTY [Dim Cua Hang].[Ma Cua Hang].MEMBERS ON ROWS
        FROM [DW Ban Hang]`;
    } else if (muc === 'thanhpho') {
      mdx = `
        SELECT ${measures} ON COLUMNS,
               NON EMPTY [Dim VPDD].[Dia Ly].[Ten Thanh Pho].MEMBERS ON ROWS
        FROM [DW Ban Hang]`;
    } else {
      // bang — mức roll up cao nhất
      mdx = `
        SELECT ${measures} ON COLUMNS,
               NON EMPTY [Dim VPDD].[Dia Ly].[Bang].MEMBERS ON ROWS
        FROM [DW Ban Hang]`;
    }

    const raw = await runMDX(mdx);
    const { columns, rows } = renameResult(raw, {
      'So Luong Ton Kho': 'TonKho',
      'Gia Tri Ton Kho':  'GiaTriTonKho',
      'Ma Cua Hang':      'MaCuaHang',
      'Ten Thanh Pho':    'TenThanhPho',
    });
    res.json({ muc, columns, rows });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ─── API: SLICE — Cắt 1 chiều (MDX → SSAS) ──────────────────────────────────
// ?loai=Du lịch        → slice theo loại khách hàng
// ?nam=2023            → slice theo năm
// ?loai=...&nam=...    → cả hai
app.get('/api/slice', async (req, res) => {
  try {
    const loai = req.query.loai || null;
    const nam  = req.query.nam  ? parseInt(req.query.nam) : null;
    const measures = `{[Measures].[Doanh Thu],[Measures].[So Luong Ban]}`;
    let mdx;

    if (loai && nam) {
      mdx = `
        SELECT ${measures} ON COLUMNS,
               NON EMPTY [Dim Thoi Gian].[Thoi Gian].[Quy].MEMBERS ON ROWS
        FROM [DW Ban Hang]
        WHERE ([Dim Khach Hang].[Loai Khach Hang].&[${loai}],
               [Dim Thoi Gian].[Nam].&[${nam}])`;
    } else if (loai) {
      mdx = `
        SELECT ${measures} ON COLUMNS,
               NON EMPTY [Dim Thoi Gian].[Thoi Gian].[Nam].MEMBERS ON ROWS
        FROM [DW Ban Hang]
        WHERE [Dim Khach Hang].[Loai Khach Hang].&[${loai}]`;
    } else if (nam) {
      mdx = `
        SELECT ${measures} ON COLUMNS,
               NON EMPTY [Dim Khach Hang].[Phan Loai KH].[Loai Khach Hang].MEMBERS ON ROWS
        FROM [DW Ban Hang]
        WHERE [Dim Thoi Gian].[Nam].&[${nam}]`;
    } else {
      mdx = `
        SELECT ${measures} ON COLUMNS,
               NON EMPTY [Dim Thoi Gian].[Thoi Gian].[Nam].MEMBERS ON ROWS
        FROM [DW Ban Hang]`;
    }

    const { columns, rows } = await runMDX(mdx);
    res.json({ columns, rows, filters: { loai, nam } });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ─── API: DICE — Cắt nhiều chiều (MDX → SSAS) ───────────────────────────────
// ?mamh=MH0001              → filter theo mặt hàng
// ?matp=HN                  → filter theo mã thành phố (Dim_VPDD)
// ?nam_f=2023&nam_t=2024    → filter theo dải năm
app.get('/api/dice', async (req, res) => {
  try {
    const mamh  = req.query.mamh  || null;
    const matp  = req.query.matp  || null;
    const nam_f = req.query.nam_f ? parseInt(req.query.nam_f) : null;
    const nam_t = req.query.nam_t ? parseInt(req.query.nam_t) : null;

    // Xây WHERE tuple cho matHang + thanhPho
    const whereParts = [];
    if (mamh) whereParts.push(`[Dim Mat Hang].[Ma Mat Hang].&[${mamh}]`);
    if (matp) whereParts.push(`[Dim VPDD].[Ten Thanh Pho].&[${matp}]`);
    const whereClause = whereParts.length > 0
      ? `WHERE (${whereParts.join(',')})`
      : '';

    // Filter năm qua MDX FILTER function (hỗ trợ dải năm)
    let rowSet = `NON EMPTY [Dim Thoi Gian].[Thoi Gian].[Nam].MEMBERS`;
    if (nam_f || nam_t) {
      const conds = [];
      if (nam_f) conds.push(`[Dim Thoi Gian].[Nam].CurrentMember.MemberValue >= ${nam_f}`);
      if (nam_t) conds.push(`[Dim Thoi Gian].[Nam].CurrentMember.MemberValue <= ${nam_t}`);
      rowSet = `NON EMPTY FILTER([Dim Thoi Gian].[Thoi Gian].[Nam].MEMBERS, ${conds.join(' AND ')})`;
    }

    const mdx = `
      SELECT {[Measures].[So Luong Ton Kho],[Measures].[Gia Tri Ton Kho]} ON COLUMNS,
             ${rowSet} ON ROWS
      FROM [DW Ban Hang]
      ${whereClause}`;

    const { columns, rows } = await runMDX(mdx);
    res.json({ columns, rows, filters: { mamh, matp, nam_f, nam_t } });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ─── API: PIVOT — Doanh thu LoaiKhachHang × Năm (SQL pivot → đúng format frontend) ──
app.get('/api/pivot', async (req, res) => {
  try {
    // Dùng SQL CASE WHEN để tạo bảng pivot đúng format frontend cần
    const sqlText = `
      SELECT tg.Nam,
        ISNULL(SUM(CASE WHEN kh.LoaiKhachHang = N'Du lịch'  THEN f.DoanhThu END), 0) AS DuLich,
        ISNULL(SUM(CASE WHEN kh.LoaiKhachHang = N'Bưu điện' THEN f.DoanhThu END), 0) AS BuuDien,
        ISNULL(SUM(CASE WHEN kh.LoaiKhachHang = N'Cả hai'   THEN f.DoanhThu END), 0) AS DL_BD,
        SUM(f.DoanhThu) AS TongCong
      FROM Fact_BanHang f
      JOIN Dim_KhachHang kh ON f.MaKhachHang = kh.MaKhachHang
      JOIN Dim_ThoiGian  tg ON f.MaThoiGian  = tg.MaThoiGian
      GROUP BY tg.Nam
      ORDER BY tg.Nam`;

    const { columns, rows } = await runQuery(sqlText);
    res.json({ columns, rows });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ─── API: 9 Câu Truy Vấn Nghiệp Vụ (SQL → SQLEXPRESS) ───────────────────────
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
          FROM Fact_Kho fk
          JOIN Dim_CuaHang ch ON fk.MaCuaHang = ch.MaCuaHang
          JOIN Dim_VPDD    vp ON ch.MaThanhPho = vp.MaThanhPho
          JOIN Dim_MatHang mh ON fk.MaMatHang  = mh.MaMatHang
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
                 SUM(fk.SoLuongTonKho) AS TonKho
          FROM Fact_Kho fk
          JOIN Dim_CuaHang ch ON fk.MaCuaHang = ch.MaCuaHang
          JOIN Dim_VPDD    vp ON ch.MaThanhPho = vp.MaThanhPho
          WHERE fk.MaMatHang = @mamh
          GROUP BY vp.TenThanhPho, vp.Bang, vp.DiaChi, ch.MaCuaHang
          HAVING SUM(fk.SoLuongTonKho) > @nguong
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
          SELECT ch.MaCuaHang, vp.TenThanhPho, SUM(fk.SoLuongTonKho) AS TonKho
          FROM Fact_Kho fk
          JOIN Dim_CuaHang ch ON fk.MaCuaHang = ch.MaCuaHang
          JOIN Dim_VPDD    vp ON ch.MaThanhPho = vp.MaThanhPho
          WHERE fk.MaMatHang = @mamh AND vp.MaThanhPho = @matp
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
        label: 'Phân loại khách hàng: Du lịch, Bưu điện, Cả hai',
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

// ─── API: Filter options (query từ Dim tables — không phụ thuộc Cube_ tables) ─
app.get('/api/filters', async (req, res) => {
  try {
    const [loaiRes, namRes, kichcoRes, tpRes, mhRes] = await Promise.all([
      runQuery(`SELECT DISTINCT LoaiKhachHang AS val
                FROM Dim_KhachHang WHERE LoaiKhachHang IS NOT NULL ORDER BY val`),
      runQuery(`SELECT DISTINCT Nam AS val FROM Dim_ThoiGian ORDER BY val`),
      runQuery(`SELECT DISTINCT KichCo AS val FROM Dim_MatHang WHERE KichCo IS NOT NULL ORDER BY val`),
      runQuery(`SELECT DISTINCT MaThanhPho AS ma, TenThanhPho AS ten FROM Dim_VPDD ORDER BY ten`),
      runQuery(`SELECT DISTINCT MaMatHang AS ma, MoTa AS ten FROM Dim_MatHang ORDER BY ma`),
    ]);
    res.json({
      loaiKH:   loaiRes.rows.map(r => r.val),
      namDT:    namRes.rows.map(r => r.val),
      kichCo:   kichcoRes.rows.map(r => r.val),
      namTK:    namRes.rows.map(r => r.val),
      thanhPho: tpRes.rows,
      matHang:  mhRes.rows,
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ─── SPA Fallback ────────────────────────────────────────────────────────────
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// ─── Start Server ─────────────────────────────────────────────────────────────
app.listen(PORT, async () => {
  console.log(`\n🚀 DW OLAP App đang chạy tại http://localhost:${PORT}`);
  console.log(`📊 SQL Server : ${DB_CONFIG.server}${DB_CONFIG.options.instanceName ? '\\' + DB_CONFIG.options.instanceName : ''} → ${DB_CONFIG.database}`);
  console.log(`🔷 SSAS (MDX) : ${SSAS_SERVER} → ${SSAS_CATALOG}\n`);
  try { await getPool(); } catch (e) {
    console.error('⚠️  Lỗi kết nối DB:', e.message);
  }
});
