from flask import Flask, render_template, request, jsonify
import pyodbc

app = Flask(__name__)

# ── Cấu hình kết nối SQL Server ──────────────────────────────
# Chỉnh SERVER cho phù hợp với môi trường của bạn
CONN_STR = (
    "DRIVER={ODBC Driver 17 for SQL Server};"
    "SERVER=localhost;"
    "DATABASE=DW_BanHang;"
    "Trusted_Connection=yes;"
)

def get_conn():
    return pyodbc.connect(CONN_STR)

def query(sql, params=None):
    conn = get_conn()
    cur  = conn.cursor()
    cur.execute(sql, params or [])
    cols = [c[0] for c in cur.description]
    rows = [dict(zip(cols, r)) for r in cur.fetchall()]
    conn.close()
    return cols, rows

# ── Trang chủ ────────────────────────────────────────────────
@app.route('/')
def index():
    return render_template('index.html')

# ── DRILL DOWN: Năm → Quý → Tháng ───────────────────────────
@app.route('/drilldown')
def drilldown():
    nam = request.args.get('nam', type=int)
    quy = request.args.get('quy', type=int)

    if nam is None:
        sql = """
            SELECT Nam, SUM(TongDoanhThu) AS DoanhThu, SUM(TongSoLuongBan) AS SoLuong
            FROM Cube_DoanhThu GROUP BY Nam ORDER BY Nam
        """
        cols, rows = query(sql)
        level = 'nam'
    elif quy is None:
        sql = """
            SELECT Nam, Quy, SUM(TongDoanhThu) AS DoanhThu, SUM(TongSoLuongBan) AS SoLuong
            FROM Cube_DoanhThu WHERE Nam=? GROUP BY Nam,Quy ORDER BY Quy
        """
        cols, rows = query(sql, [nam])
        level = 'quy'
    else:
        sql = """
            SELECT Nam, Quy, Thang, SUM(TongDoanhThu) AS DoanhThu, SUM(TongSoLuongBan) AS SoLuong
            FROM Cube_DoanhThu WHERE Nam=? AND Quy=? GROUP BY Nam,Quy,Thang ORDER BY Thang
        """
        cols, rows = query(sql, [nam, quy])
        level = 'thang'

    return render_template('drilldown.html', cols=cols, rows=rows,
                           level=level, nam=nam, quy=quy)

# ── ROLL UP: Cửa hàng → Thành phố → Bang ────────────────────
@app.route('/rollup')
def rollup():
    muc = request.args.get('muc', 'cuahang')
    nam = request.args.get('nam', type=int)

    nam_filter = nam or 2024

    if muc == 'cuahang':
        sql = """
            SELECT MaCuaHang, TenThanhPho, Bang, SUM(TongTonKho) AS TonKho
            FROM Cube_TonKho WHERE Nam=?
            GROUP BY MaCuaHang,TenThanhPho,Bang ORDER BY TonKho DESC
        """
    elif muc == 'thanhpho':
        sql = """
            SELECT TenThanhPho, Bang, SUM(TongTonKho) AS TonKho
            FROM Cube_TonKho WHERE Nam=?
            GROUP BY TenThanhPho,Bang ORDER BY TonKho DESC
        """
    else:
        sql = """
            SELECT Bang, SUM(TongTonKho) AS TonKho
            FROM Cube_TonKho WHERE Nam=?
            GROUP BY Bang ORDER BY TonKho DESC
        """

    cols, rows = query(sql, [nam_filter])
    return render_template('rollup.html', cols=cols, rows=rows,
                           muc=muc, nam=nam_filter)

# ── SLICE: Cắt 1 chiều cố định ───────────────────────────────
@app.route('/slice')
def slice_view():
    loai  = request.args.get('loai', '')
    nam   = request.args.get('nam',  type=int)
    kichco = request.args.get('kichco', '')

    sql = """
        SELECT LoaiKhachHang, Nam, Quy, KichCo,
               SUM(TongSoLuongBan) AS SoLuong,
               SUM(TongDoanhThu)   AS DoanhThu
        FROM Cube_DoanhThu
        WHERE (? = '' OR LoaiKhachHang = ?)
          AND (? IS NULL OR Nam = ?)
          AND (? = '' OR KichCo = ?)
        GROUP BY LoaiKhachHang, Nam, Quy, KichCo
        ORDER BY Nam, Quy
    """
    cols, rows = query(sql, [loai, loai, nam, nam, kichco, kichco])

    # Lấy danh sách filter
    _, loai_list  = query("SELECT DISTINCT LoaiKhachHang FROM Cube_DoanhThu ORDER BY 1")
    _, nam_list   = query("SELECT DISTINCT Nam FROM Cube_DoanhThu ORDER BY 1")
    _, kichco_list = query("SELECT DISTINCT KichCo FROM Cube_DoanhThu ORDER BY 1")

    return render_template('slice.html', cols=cols, rows=rows,
                           loai_list=loai_list, nam_list=nam_list,
                           kichco_list=kichco_list,
                           sel_loai=loai, sel_nam=nam, sel_kichco=kichco)

# ── DICE: Cắt nhiều chiều ────────────────────────────────────
@app.route('/dice')
def dice_view():
    matp  = request.args.get('matp',  '')
    mamh  = request.args.get('mamh',  '')
    nam_f = request.args.get('nam_f', type=int)
    nam_t = request.args.get('nam_t', type=int)

    sql = """
        SELECT MaMatHang, MoTaMatHang, KichCo,
               TenThanhPho, Bang,
               Nam, Quy, Thang, SUM(TongTonKho) AS TonKho
        FROM Cube_TonKho
        WHERE (? = '' OR MaThanhPhoCH = ?)
          AND (? = '' OR MaMatHang    = ?)
          AND (? IS NULL OR Nam >= ?)
          AND (? IS NULL OR Nam <= ?)
        GROUP BY MaMatHang, MoTaMatHang, KichCo, TenThanhPho, Bang, Nam, Quy, Thang
        ORDER BY Nam, Thang
    """
    cols, rows = query(sql, [matp, matp, mamh, mamh, nam_f, nam_f, nam_t, nam_t])

    _, tp_list  = query("SELECT DISTINCT MaThanhPhoCH, TenThanhPho FROM Cube_TonKho ORDER BY 2")
    _, mh_list  = query("SELECT DISTINCT MaMatHang, MoTaMatHang FROM Cube_TonKho ORDER BY 1")
    _, nam_list = query("SELECT DISTINCT Nam FROM Cube_TonKho ORDER BY 1")

    return render_template('dice.html', cols=cols, rows=rows,
                           tp_list=tp_list, mh_list=mh_list, nam_list=nam_list,
                           sel_matp=matp, sel_mamh=mamh,
                           sel_namf=nam_f, sel_namt=nam_t)

# ── PIVOT: Doanh thu Loại KH × Năm ──────────────────────────
@app.route('/pivot')
def pivot_view():
    sql = """
        SELECT Nam,
            ISNULL(SUM(CASE WHEN LoaiKhachHang=N'Du lịch'            THEN TongDoanhThu END),0) AS [Du lich],
            ISNULL(SUM(CASE WHEN LoaiKhachHang=N'Bưu điện'           THEN TongDoanhThu END),0) AS [Buu dien],
            ISNULL(SUM(CASE WHEN LoaiKhachHang=N'Du lịch & Bưu điện' THEN TongDoanhThu END),0) AS [DL and BD],
            ISNULL(SUM(CASE WHEN LoaiKhachHang=N'Thường'             THEN TongDoanhThu END),0) AS [Thuong],
            SUM(TongDoanhThu) AS TongCong
        FROM Cube_DoanhThu
        GROUP BY Nam ORDER BY Nam
    """
    cols, rows = query(sql)
    return render_template('pivot.html', cols=cols, rows=rows)

# ── API: 9 câu nghiệp vụ ─────────────────────────────────────
@app.route('/query/<int:qid>')
def run_query(qid):
    makh   = request.args.get('makh',  'KH001')
    mamh   = request.args.get('mamh',  'MH001')
    matp   = request.args.get('matp',  'HCM')
    nguong = request.args.get('nguong', 100, type=int)

    queries = {
        1: ("""
            SELECT DISTINCT ch.MaCuaHang, vp.TenThanhPho, ch.Bang, ch.SDT,
                mh.MaMH, mh.MoTa, mh.KichCo, mh.TrongLuong, mh.DonGia
            FROM Cube_TonKho tk
            JOIN Dim_CuaHang ch ON tk.MaCuaHang=ch.MaCuaHang
            JOIN Dim_VPDD    vp ON ch.MaThanhPho=vp.MaThanhPho
            JOIN Dim_MatHang mh ON tk.MaMatHang=mh.MaMH
            ORDER BY ch.MaCuaHang, mh.MaMH
            """, []),
        2: ("""
            SELECT kh.MaKH,kh.TenKhachHang,tg.Nam,tg.Thang,
                SUM(f.SoLuongBan) AS TongSL, SUM(f.DoanhThu) AS DoanhThu
            FROM Fact_BanHang f
            JOIN Dim_KhachHang kh ON f.MaKhachHang=kh.MaKH
            JOIN Dim_ThoiGian  tg ON f.TimeKey=tg.TimeKey
            WHERE kh.MaKH=?
            GROUP BY kh.MaKH,kh.TenKhachHang,tg.Nam,tg.Thang ORDER BY tg.Nam,tg.Thang
            """, [makh]),
        3: ("""
            SELECT DISTINCT ch.MaCuaHang,vp.TenThanhPho,ch.SDT,mh.MaMH,mh.MoTa
            FROM Fact_BanHang fb
            JOIN Dim_KhachHang kh ON fb.MaKhachHang=kh.MaKH
            JOIN Fact_Kho      fk ON fb.MaMatHang=fk.MaMatHang
            JOIN Dim_CuaHang   ch ON fk.MaCuaHang=ch.MaCuaHang
            JOIN Dim_VPDD      vp ON ch.MaThanhPho=vp.MaThanhPho
            JOIN Dim_MatHang   mh ON fb.MaMatHang=mh.MaMH
            WHERE kh.MaKH=?
            """, [makh]),
        4: ("""
            SELECT vp.TenThanhPho,vp.Bang,vp.DiaChi,ch.MaCuaHang,SUM(tk.TongTonKho) AS TonKho
            FROM Cube_TonKho tk
            JOIN Dim_CuaHang ch ON tk.MaCuaHang=ch.MaCuaHang
            JOIN Dim_VPDD    vp ON ch.MaThanhPho=vp.MaThanhPho
            WHERE tk.MaMatHang=?
            GROUP BY vp.TenThanhPho,vp.Bang,vp.DiaChi,ch.MaCuaHang
            HAVING SUM(tk.TongTonKho)>? ORDER BY TonKho DESC
            """, [mamh, nguong]),
        5: ("""
            SELECT DISTINCT kh.TenKhachHang,mh.MaMH,mh.MoTa,ch.MaCuaHang,vp.TenThanhPho
            FROM Fact_BanHang fb
            JOIN Dim_KhachHang kh ON fb.MaKhachHang=kh.MaKH
            JOIN Dim_MatHang   mh ON fb.MaMatHang=mh.MaMH
            JOIN Fact_Kho      fk ON fb.MaMatHang=fk.MaMatHang
            JOIN Dim_CuaHang   ch ON fk.MaCuaHang=ch.MaCuaHang
            JOIN Dim_VPDD      vp ON ch.MaThanhPho=vp.MaThanhPho
            WHERE kh.MaKH=?
            """, [makh]),
        6: ("""
            SELECT kh.MaKH,kh.TenKhachHang,vp.TenThanhPho,vp.Bang
            FROM Dim_KhachHang kh JOIN Dim_VPDD vp ON kh.MaThanhPho=vp.MaThanhPho
            WHERE kh.MaKH=?
            """, [makh]),
        7: ("""
            SELECT ch.MaCuaHang,vp.TenThanhPho,SUM(tk.TongTonKho) AS TonKho
            FROM Cube_TonKho tk
            JOIN Dim_CuaHang ch ON tk.MaCuaHang=ch.MaCuaHang
            JOIN Dim_VPDD    vp ON ch.MaThanhPho=vp.MaThanhPho
            WHERE tk.MaMatHang=? AND tk.MaThanhPhoCH=?
            GROUP BY ch.MaCuaHang,vp.TenThanhPho ORDER BY TonKho DESC
            """, [mamh, matp]),
        8: ("""
            SELECT kh.TenKhachHang,mh.MaMH,mh.MoTa,
                SUM(fb.SoLuongBan) AS SoLuong,SUM(fb.DoanhThu) AS DoanhThu,
                ch.MaCuaHang,vp.TenThanhPho
            FROM Fact_BanHang fb
            JOIN Dim_KhachHang kh ON fb.MaKhachHang=kh.MaKH
            JOIN Dim_MatHang   mh ON fb.MaMatHang=mh.MaMH
            JOIN Fact_Kho      fk ON fb.MaMatHang=fk.MaMatHang
            JOIN Dim_CuaHang   ch ON fk.MaCuaHang=ch.MaCuaHang
            JOIN Dim_VPDD      vp ON ch.MaThanhPho=vp.MaThanhPho
            WHERE kh.MaKH=?
            GROUP BY kh.TenKhachHang,mh.MaMH,mh.MoTa,ch.MaCuaHang,vp.TenThanhPho
            """, [makh]),
        9: ("""
            SELECT LoaiKhachHang, COUNT(*) AS SoLuong
            FROM Dim_KhachHang
            WHERE LoaiKhachHang IN (N'Du lịch',N'Bưu điện',N'Du lịch & Bưu điện')
            GROUP BY LoaiKhachHang
            """, []),
    }

    if qid not in queries:
        return jsonify({'error': 'Query không tồn tại'}), 404

    sql, params = queries[qid]
    cols, rows  = query(sql, params)
    return render_template('query_result.html', qid=qid, cols=cols, rows=rows,
                           makh=makh, mamh=mamh, matp=matp, nguong=nguong)

if __name__ == '__main__':
    app.run(debug=True, port=5000)
