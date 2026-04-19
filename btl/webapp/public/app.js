/**
 * DW OLAP Web App — Frontend JavaScript
 * Quản lý điều hướng, gọi API, render bảng và biểu đồ
 */

// ═══════════════════════════════════════════════════════════
// 1. NAVIGATION
// ═══════════════════════════════════════════════════════════

const PAGE_TITLES = {
  dashboard: 'Tổng Quan',
  drilldown: 'Drill Down — Năm → Quý → Tháng',
  rollup:    'Roll Up — Cửa Hàng → Thành Phố → Bang',
  slice:     'Slice — Cắt Theo 1 Chiều',
  dice:      'Dice — Cắt Theo Nhiều Chiều',
  pivot:     'Pivot — Xoay Chiều Dữ Liệu',
  queries:   '9 Câu Truy Vấn Nghiệp Vụ',
};

function navigateTo(section) {
  // Deactivate all nav + sections
  document.querySelectorAll('.nav-item').forEach(el => el.classList.remove('active'));
  document.querySelectorAll('.section').forEach(el => el.classList.remove('active'));

  const navEl  = document.getElementById(`nav-${section}`);
  const secEl  = document.getElementById(`section-${section}`);
  if (navEl)  navEl.classList.add('active');
  if (secEl)  secEl.classList.add('active');

  document.getElementById('page-title').textContent = PAGE_TITLES[section] || section;

  // Load data on first visit
  if (!state.loaded.has(section)) {
    state.loaded.add(section);
    onSectionLoad(section);
  }

  // Close sidebar on mobile
  if (window.innerWidth <= 900) {
    document.getElementById('sidebar').classList.remove('open');
  }
}

function onSectionLoad(section) {
  switch (section) {
    case 'dashboard': app.dashboard.load(); break;
    case 'drilldown': app.drilldown.reset(); break;
    case 'rollup':    app.rollup.init(); break;
    case 'slice':     app.slice.init(); break;
    case 'dice':      app.dice.init(); break;
    case 'pivot':     app.pivot.load(); break;
    case 'queries':   app.queries.init(); break;
  }
}

// Global state
const state = {
  loaded:        new Set(),
  filters:       null,
  charts:        {},
  rollup:   { muc: 'cuahang', nam: null },
  drilldown: { nam: null, quy: null },
};

// ═══════════════════════════════════════════════════════════
// 2. UTILITIES
// ═══════════════════════════════════════════════════════════

async function apiFetch(url) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`HTTP ${res.status}: ${await res.text()}`);
  return res.json();
}

function showLoading(id) {
  document.getElementById(id)?.classList.remove('hidden');
}
function hideLoading(id) {
  document.getElementById(id)?.classList.add('hidden');
}

function fmt(val, col = '') {
  if (val === null || val === undefined) return '—';
  const colLower = col.toLowerCase();
  if (typeof val === 'number') {
    if (colLower.includes('doanhthu') || colLower.includes('revenue') ||
        colLower.includes('tongcong') || colLower.includes('dl_bd') ||
        colLower.includes('dulich')   || colLower.includes('buudien') ||
        colLower.includes('thuong')) {
      return val.toLocaleString('vi-VN') + ' ₫';
    }
    return val.toLocaleString('vi-VN');
  }
  return String(val);
}

function isNumberCol(col, val) {
  return typeof val === 'number';
}

function renderTable(rows, columns, opts = {}) {
  if (!rows || rows.length === 0) {
    return `<div class="empty-state">
      <div class="empty-state-icon">🔍</div>
      <div>Không có dữ liệu</div>
    </div>`;
  }

  const colDefs = columns.map(c => ({
    key: c,
    isNum: typeof rows[0][c] === 'number',
  }));

  let thead = `<thead><tr>${colDefs.map(c =>
    `<th>${c.key}</th>`
  ).join('')}</tr></thead>`;

  let tbody = `<tbody>${rows.map((row, i) => {
    const cls = opts.clickable ? 'clickable' : '';
    const attr = opts.onRowClick ? `onclick="(${opts.onRowClick})(${JSON.stringify(row)})"` : '';
    return `<tr class="${cls}" ${opts.dataRow ? `data-idx="${i}"` : ''} ${attr}>${
      colDefs.map(c => {
        const v = row[c.key];
        return `<td class="${c.isNum ? 'number' : ''}">${fmt(v, c.key)}</td>`;
      }).join('')
    }</tr>`;
  }).join('')}</tbody>`;

  return `<table>${thead}${tbody}</table>
    <div class="row-count">${rows.length} dòng</div>`;
}

function destroyChart(id) {
  if (state.charts[id]) {
    state.charts[id].destroy();
    delete state.charts[id];
  }
}

function buildChart(id, type, labels, datasets, opts = {}) {
  destroyChart(id);
  const ctx = document.getElementById(id)?.getContext('2d');
  if (!ctx) return;

  state.charts[id] = new Chart(ctx, {
    type,
    data: { labels, datasets },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: {
          labels: { color: '#4a5568', font: { family: 'Inter', size: 11 } },
        },
        tooltip: {
          backgroundColor: '#1e2633',
          titleColor: '#ffffff',
          bodyColor: '#9aa3b2',
          borderColor: 'rgba(0,0,0,0.15)',
          borderWidth: 1,
          padding: 10,
          callbacks: {
            label: ctx => ' ' + (typeof ctx.raw === 'number'
              ? ctx.raw.toLocaleString('vi-VN')
              : ctx.raw)
          },
        },
      },
      scales: type === 'doughnut' || type === 'pie' ? {} : {
        x: { ticks: { color: '#8a94a6', font: { size: 11 } }, grid: { color: 'rgba(0,0,0,0.05)' } },
        y: { ticks: { color: '#8a94a6', font: { size: 11 } }, grid: { color: 'rgba(0,0,0,0.05)' } },
      },
      ...opts,
    },
  });
}

const COLORS = [
  'rgba(26,86,219,0.75)',
  'rgba(4,120,87,0.75)',
  'rgba(180,83,9,0.75)',
  'rgba(109,40,217,0.75)',
  'rgba(190,24,93,0.75)',
  'rgba(2,132,199,0.75)',
];
const COLORS_BORDER = COLORS.map(c => c.replace('0.75','1'));

// ═══════════════════════════════════════════════════════════
// 3. APP MODULES
// ═══════════════════════════════════════════════════════════

const app = {

  // ── 3.1 DASHBOARD ──────────────────────────────────────
  dashboard: {
    async load() {
      try {
        const [pivotData, rollupData, cuahangData, khData] = await Promise.all([
          apiFetch('/api/pivot'),
          apiFetch('/api/rollup?muc=bang'),
          apiFetch('/api/rollup?muc=cuahang'),
          apiFetch('/api/query/9'),
        ]);

        // Stats
        const totalDT    = pivotData.rows.reduce((s, r) => s + (r.TongCong || 0), 0);
        const totalSL    = await apiFetch('/api/drilldown').then(d =>
          d.rows.reduce((s, r) => s + (r.SoLuong || 0), 0));
        const cuahangCnt = cuahangData.rows.length;
        const khachCnt   = await apiFetch('/api/query/9').then(d =>
          d.rows.reduce((s, r) => s + (r.SoLuong || 0), 0));

        document.getElementById('stat-doanhthu').textContent =
          totalDT.toLocaleString('vi-VN') + ' ₫';
        document.getElementById('stat-soluong').textContent =
          totalSL.toLocaleString('vi-VN');
        document.getElementById('stat-cuahang').textContent =
          cuahangCnt.toLocaleString('vi-VN');
        document.getElementById('stat-khachhang').textContent =
          khachCnt.toLocaleString('vi-VN');

        document.querySelectorAll('.stat-card').forEach(c => c.classList.remove('loading'));

        // Chart: KH type donut
        const khRows   = khData.rows;
        buildChart('chart-kh-type', 'doughnut',
          khRows.map(r => r.LoaiKhachHang),
          [{
            data: khRows.map(r => r.SoLuong),
            backgroundColor: COLORS,
            borderColor: '#1c2333',
            borderWidth: 3,
          }]
        );

        // Chart: trend line
        const trendRows = pivotData.rows;
        buildChart('chart-trend', 'line',
          trendRows.map(r => 'Năm ' + r.Nam),
          [{
            label: 'Tổng Doanh Thu',
            data:  trendRows.map(r => r.TongCong),
            borderColor: '#4f8ef7',
            backgroundColor: 'rgba(79,142,247,0.12)',
            tension: 0.4,
            fill: true,
            pointBackgroundColor: '#4f8ef7',
          }]
        );

      } catch (e) {
        console.error('Dashboard error:', e);
      }
    },
  },

  // ── 3.2 DRILL DOWN ──────────────────────────────────────
  drilldown: {
    _nam: null,
    _quy: null,

    async load(nam = null, quy = null) {
      this._nam = nam;
      this._quy = quy;
      
      const params = new URLSearchParams();
      if (nam !== null) params.append('nam', nam);
      if (quy !== null) params.append('quy', quy);

      showLoading('dd-loading');
      document.getElementById('dd-table-wrapper').innerHTML = '';

      try {
        const data = await apiFetch('/api/drilldown?' + params);
        hideLoading('dd-loading');

        // Update level badge
        const levelMap = { nam: 'Năm', quy: 'Quý', thang: 'Tháng' };
        document.getElementById('dd-level-text').textContent = levelMap[data.level];

        // Breadcrumb
        this.updateBreadcrumb(nam, quy);

        // Table (clickable if not at month level)
        const clickable = data.level !== 'thang';
        const wrapper   = document.getElementById('dd-table-wrapper');

        if (!data.rows || data.rows.length === 0) {
          wrapper.innerHTML = '<div class="empty-state"><div class="empty-state-icon">🔍</div><div>Không có dữ liệu</div></div>';
          return;
        }

        wrapper.innerHTML = renderTable(data.rows, data.columns);

        if (clickable) {
          document.querySelectorAll('#dd-table-wrapper tbody tr').forEach((tr, i) => {
            const row = data.rows[i];
            tr.classList.add('clickable');
            tr.addEventListener('click', () => {
              if (data.level === 'nam') this.load(row.Nam, null);
              else if (data.level === 'quy') this.load(nam, row.Quy);
            });
          });
        }

        document.getElementById('dd-hint').textContent =
          clickable ? '💡 Click vào dòng bất kỳ để khoan xuống mức thấp hơn'
                    : '✅ Đã đến mức chi tiết nhất (Tháng)';

        // Chart
        destroyChart('chart-drilldown');
        const labelKey = data.level === 'nam' ? 'Nam'
                       : data.level === 'quy' ? 'Quy' : 'Thang';
        const labels  = data.rows.map(r => {
          if (data.level === 'nam') return 'Năm ' + r.Nam;
          if (data.level === 'quy') return 'Q' + r.Quy + '/' + nam;
          return 'T' + r.Thang + '/' + nam;
        });
        buildChart('chart-drilldown', 'bar', labels, [{
          label: 'Doanh Thu',
          data: data.rows.map(r => r.DoanhThu),
          backgroundColor: COLORS[0],
          borderColor: COLORS_BORDER[0],
          borderWidth: 1,
          borderRadius: 4,
        }, {
          label: 'Số Lượng Bán',
          data: data.rows.map(r => r.SoLuong),
          backgroundColor: COLORS[1],
          borderColor: COLORS_BORDER[1],
          borderWidth: 1,
          borderRadius: 4,
          yAxisID: 'y2',
        }], {
          scales: {
            x: { ticks: { color: '#8b949e' }, grid: { color: 'rgba(255,255,255,0.04)' } },
            y:  { ticks: { color: '#8b949e' }, grid: { color: 'rgba(255,255,255,0.04)' } },
            y2: { position: 'right', ticks: { color: '#8b949e' }, grid: { display: false } },
          }
        });

      } catch (e) {
        hideLoading('dd-loading');
        document.getElementById('dd-table-wrapper').innerHTML =
          `<div class="empty-state"><div>⚠️ Lỗi: ${e.message}</div></div>`;
      }
    },

    reset() { this.load(null, null); },

    updateBreadcrumb(nam, quy) {
      const bc = document.getElementById('dd-breadcrumb');
      let html = `<span class="bc-item ${!nam ? 'active' : ''}" onclick="app.drilldown.reset()">Tất cả năm</span>`;
      if (nam !== null) {
        html += `<span class="bc-sep">›</span>
                 <span class="bc-item ${!quy ? 'active' : ''}" onclick="app.drilldown.load(${nam}, null)">Năm ${nam}</span>`;
      }
      if (quy !== null) {
        html += `<span class="bc-sep">›</span>
                 <span class="bc-item active">Quý ${quy}</span>`;
      }
      bc.innerHTML = html;
    },
  },

  // ── 3.3 ROLL UP ──────────────────────────────────────────
  rollup: {
    _muc: 'cuahang',
    _chart: null,

    async init() {
      const filters = await app.getFilters();
      const sel = document.getElementById('rollup-nam');
      sel.innerHTML = filters.namTK.map(y =>
        `<option value="${y}">Năm ${y}</option>`
      ).join('');
      await this.load();
    },

    setLevel(muc) {
      this._muc = muc;
      document.querySelectorAll('#rollup-level-group .btn-level').forEach(b => {
        b.classList.toggle('active', b.dataset.muc === muc);
      });
      this.load();
    },

    async load() {
      const nam = document.getElementById('rollup-nam')?.value || '';
      const muc = this._muc;
      const url = `/api/rollup?muc=${muc}${nam ? '&nam=' + nam : ''}`;

      showLoading('ru-loading');
      document.getElementById('ru-table-wrapper').innerHTML = '';

      try {
        const data = await apiFetch(url);
        hideLoading('ru-loading');
        document.getElementById('ru-table-wrapper').innerHTML =
          renderTable(data.rows, data.columns);

        // Chart
        const labelKey  = muc === 'cuahang' ? 'MaCuaHang'
                        : muc === 'thanhpho' ? 'TenThanhPho' : 'Bang';
        const maxShow   = 15;
        const chartRows = data.rows.slice(0, maxShow);
        buildChart('chart-rollup', 'bar',
          chartRows.map(r => r[labelKey] || '—'),
          [{
            label: 'Tồn Kho',
            data: chartRows.map(r => r.TonKho),
            backgroundColor: COLORS[1],
            borderColor: COLORS_BORDER[1],
            borderWidth: 1,
            borderRadius: 4,
          }],
          { indexAxis: chartRows.length > 8 ? 'y' : 'x' }
        );

      } catch (e) {
        hideLoading('ru-loading');
        document.getElementById('ru-table-wrapper').innerHTML =
          `<div class="empty-state"><div>⚠️ Lỗi: ${e.message}</div></div>`;
      }
    },
  },

  // ── 3.4 SLICE ────────────────────────────────────────────
  slice: {
    async init() {
      const filters = await app.getFilters();
      const loaiSel  = document.getElementById('slice-loai');
      const namSel   = document.getElementById('slice-nam');
      const kichSel  = document.getElementById('slice-kichco');

      loaiSel.innerHTML = `<option value="">— Tất cả —</option>` +
        filters.loaiKH.map(v => `<option value="${v}">${v}</option>`).join('');
      namSel.innerHTML = `<option value="">— Tất cả —</option>` +
        filters.namDT.map(v => `<option value="${v}">Năm ${v}</option>`).join('');
      kichSel.innerHTML = `<option value="">— Tất cả —</option>` +
        filters.kichCo.map(v => `<option value="${v}">${v}</option>`).join('');

      await this.load();
    },

    async load() {
      const loai   = document.getElementById('slice-loai').value;
      const nam    = document.getElementById('slice-nam').value;
      const kichco = document.getElementById('slice-kichco').value;

      const params = new URLSearchParams();
      if (loai)   params.append('loai',   loai);
      if (nam)    params.append('nam',    nam);
      if (kichco) params.append('kichco', kichco);

      // Show active filters
      const tags = [];
      if (loai)   tags.push(`Loại KH: ${loai}`);
      if (nam)    tags.push(`Năm: ${nam}`);
      if (kichco) tags.push(`Kích cỡ: ${kichco}`);
      document.getElementById('slice-active-filters').innerHTML =
        tags.map(t => `<span class="filter-tag">✂️ ${t}</span>`).join('');

      showLoading('sl-loading');
      document.getElementById('sl-table-wrapper').innerHTML = '';

      try {
        const data = await apiFetch('/api/slice?' + params);
        hideLoading('sl-loading');
        document.getElementById('sl-table-wrapper').innerHTML =
          renderTable(data.rows, data.columns);
      } catch (e) {
        hideLoading('sl-loading');
        document.getElementById('sl-table-wrapper').innerHTML =
          `<div class="empty-state"><div>⚠️ Lỗi: ${e.message}</div></div>`;
      }
    },
  },

  // ── 3.5 DICE ─────────────────────────────────────────────
  dice: {
    async init() {
      const filters = await app.getFilters();

      const tpSel  = document.getElementById('dice-tp');
      const mhSel  = document.getElementById('dice-mh');
      const namFSel = document.getElementById('dice-nam-f');
      const namTSel = document.getElementById('dice-nam-t');

      tpSel.innerHTML = `<option value="">— Tất cả —</option>` +
        filters.thanhPho.map(r => `<option value="${r.ma}">${r.ten}</option>`).join('');
      mhSel.innerHTML = `<option value="">— Tất cả —</option>` +
        filters.matHang.map(r => `<option value="${r.ma}">${r.ma} – ${r.ten?.slice(0,25) || ''}</option>`).join('');
      namFSel.innerHTML = `<option value="">— Tất cả —</option>` +
        filters.namTK.map(v => `<option value="${v}">Năm ${v}</option>`).join('');
      namTSel.innerHTML = `<option value="">— Tất cả —</option>` +
        filters.namTK.map(v => `<option value="${v}">Năm ${v}</option>`).join('');

      await this.load();
    },

    async load() {
      const matp  = document.getElementById('dice-tp').value;
      const mamh  = document.getElementById('dice-mh').value;
      const nam_f = document.getElementById('dice-nam-f').value;
      const nam_t = document.getElementById('dice-nam-t').value;

      const params = new URLSearchParams();
      if (matp)  params.append('matp',  matp);
      if (mamh)  params.append('mamh',  mamh);
      if (nam_f) params.append('nam_f', nam_f);
      if (nam_t) params.append('nam_t', nam_t);

      showLoading('di-loading');
      document.getElementById('di-table-wrapper').innerHTML = '';

      try {
        const data = await apiFetch('/api/dice?' + params);
        hideLoading('di-loading');
        document.getElementById('di-table-wrapper').innerHTML =
          renderTable(data.rows, data.columns);
      } catch (e) {
        hideLoading('di-loading');
        document.getElementById('di-table-wrapper').innerHTML =
          `<div class="empty-state"><div>⚠️ Lỗi: ${e.message}</div></div>`;
      }
    },
  },

  // ── 3.6 PIVOT ────────────────────────────────────────────
  pivot: {
    async load() {
      showLoading('pv-loading');
      document.getElementById('pv-table-wrapper').innerHTML = '';

      try {
        const data = await apiFetch('/api/pivot');
        hideLoading('pv-loading');
        document.getElementById('pv-table-wrapper').innerHTML =
          this.renderPivot(data.rows);
        this.buildPivotChart(data.rows);
      } catch (e) {
        hideLoading('pv-loading');
        document.getElementById('pv-table-wrapper').innerHTML =
          `<div class="empty-state"><div>⚠️ Lỗi: ${e.message}</div></div>`;
      }
    },

    renderPivot(rows) {
      if (!rows || rows.length === 0) return '<div class="empty-state"><div>Không có dữ liệu</div></div>';

      // Find max value for heatmap
      const cols = ['DuLich', 'BuuDien', 'DL_BD', 'Thuong'];
      const colLabels = { DuLich: 'Du Lịch', BuuDien: 'Bưu Điện', DL_BD: 'DL & Bưu Điện', Thuong: 'Thường' };
      const maxVal = Math.max(...rows.flatMap(r => cols.map(c => r[c] || 0)));

      const heatColor = (val) => {
        const ratio = maxVal > 0 ? val / maxVal : 0;
        if (ratio < 0.05) return 'background:#f7f8fa;color:#b0bac8';
        const a = Math.round(ratio * 0.65 * 100) / 100;
        return `background:rgba(26,86,219,${a});color:${ratio > 0.45 ? '#ffffff' : '#1e2633'}`;
      };

      return `<table class="pivot-table">
        <thead><tr>
          <th>Năm</th>
          ${cols.map(c => `<th>${colLabels[c]}</th>`).join('')}
          <th>Tổng Cộng</th>
        </tr></thead>
        <tbody>
          ${rows.map(r => `
            <tr>
              <td>${r.Nam}</td>
              ${cols.map(c => `<td style="${heatColor(r[c] || 0)}">${(r[c] || 0).toLocaleString('vi-VN')} ₫</td>`).join('')}
              <td class="pivot-total">${(r.TongCong || 0).toLocaleString('vi-VN')} ₫</td>
            </tr>
          `).join('')}
        </tbody>
      </table>
      <div class="row-count">${rows.length} năm</div>`;
    },

    buildPivotChart(rows) {
      const cols = ['DuLich', 'BuuDien', 'DL_BD', 'Thuong'];
      const colLabels = ['Du Lịch', 'Bưu Điện', 'DL & Bưu Điện', 'Thường'];
      buildChart('chart-pivot', 'bar',
        rows.map(r => 'Năm ' + r.Nam),
        cols.map((c, i) => ({
          label: colLabels[i],
          data: rows.map(r => r[c] || 0),
          backgroundColor: COLORS[i],
          borderColor: COLORS_BORDER[i],
          borderWidth: 1,
          borderRadius: 3,
        })),
        { plugins: { legend: { position: 'top' } } }
      );
    },
  },

  // ── 3.7 QUERIES ──────────────────────────────────────────
  queries: {
    LABELS: [
      '',
      'Q1 — Tất cả cửa hàng + TP, bang, SĐT và mặt hàng bán ở kho',
      'Q2 — Tất cả đơn hàng + tên KH + thống kê của một khách hàng',
      'Q3 — Cửa hàng + TP + SĐT có bán MH đặt bởi 1 KH cụ thể',
      'Q4 — Địa chỉ VP + TP + bang của CH lưu kho MH > ngưỡng',
      'Q5 — Mặt hàng + mô tả + mã CH + TP bán MH đó (theo đơn KH)',
      'Q6 — Thành phố và bang mà 1 khách hàng sinh sống',
      'Q7 — Tồn kho 1 MH tại tất cả CH ở 1 TP cụ thể',
      'Q8 — MH + SL đặt + KH + CH + TP của 1 đơn đặt hàng cụ thể',
      'Q9 — Khách hàng du lịch, bưu điện và thường',
    ],

    init() {
      const list = document.getElementById('query-list');
      list.innerHTML = this.LABELS.slice(1).map((label, i) => {
        const id = i + 1;
        return `
          <div class="query-item" id="qitem-${id}">
            <div class="query-header" onclick="app.queries.toggle(${id})">
              <div class="query-num">${id}</div>
              <div class="query-label">${label}</div>
              <button class="btn btn-primary query-run"
                onclick="event.stopPropagation(); app.queries.run(${id})">
                ▶ Thực thi
              </button>
            </div>
            <div class="query-result" id="qresult-${id}">
              <div class="query-result-inner" id="qinner-${id}"></div>
            </div>
          </div>`;
      }).join('');
    },

    toggle(id) {
      const result = document.getElementById(`qresult-${id}`);
      result.classList.toggle('open');
      if (result.classList.contains('open')) {
        this.run(id);
      }
    },

    async run(id) {
      const makh   = document.getElementById('q-makh').value   || 'KH1';
      const mamh   = document.getElementById('q-mamh').value   || 'MH1';
      const matp   = document.getElementById('q-matp').value   || 'VP1';
      const nguong = document.getElementById('q-nguong').value || 100;

      const inner  = document.getElementById(`qinner-${id}`);
      const result = document.getElementById(`qresult-${id}`);
      result.classList.add('open');
      inner.innerHTML = `<div class="table-loading"><div class="spinner"></div><span>Đang thực thi Q${id}...</span></div>`;

      try {
        const params = new URLSearchParams({ makh, mamh, matp, nguong });
        const data   = await apiFetch(`/api/query/${id}?${params}`);
        inner.innerHTML = renderTable(data.rows, data.columns);
      } catch (e) {
        inner.innerHTML = `<div class="empty-state"><div>⚠️ Lỗi: ${e.message}</div></div>`;
      }
    },
  },

  // ── Shared: get filter options ──────────────────────────
  async getFilters() {
    if (!state.filters) {
      state.filters = await apiFetch('/api/filters');
    }
    return state.filters;
  },
};

// ═══════════════════════════════════════════════════════════
// 4. INIT
// ═══════════════════════════════════════════════════════════

document.addEventListener('DOMContentLoaded', async () => {
  // Nav click handlers
  document.querySelectorAll('.nav-item[data-section]').forEach(el => {
    el.addEventListener('click', () => navigateTo(el.dataset.section));
  });

  // Mobile menu toggle
  document.getElementById('menu-toggle').addEventListener('click', () => {
    document.getElementById('sidebar').classList.toggle('open');
  });

  // Health check → DB status badge
  try {
    const health = await apiFetch('/api/health');
    const dot  = document.querySelector('.status-dot');
    const text = document.querySelector('.status-text');
    dot.classList.add('connected');
    text.textContent = 'Đã kết nối';
  } catch {
    const dot  = document.querySelector('.status-dot');
    const text = document.querySelector('.status-text');
    dot.classList.add('error');
    text.textContent = 'Mất kết nối';
  }

  // Load dashboard on start
  navigateTo('dashboard');
});
