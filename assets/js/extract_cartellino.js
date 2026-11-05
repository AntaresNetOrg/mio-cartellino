// Injected into the desktop presenze.unisa.it cartellino page after login. Reads
// the DataTables table #1011 and posts the rows to the Flutter side through the
// `CartellinoChannel` JavaScript channel.
//
// #1011 exists before DataTables fills it, so wait for the DataTables instance.
// The table is client-side (all rows in memory): instead of the desktop app's
// paging loop, draw every row at once with `page.len(-1)` and read the DOM. Only
// visible columns are read, which include those listed in `update_screen.dart`.
//
// Messages (JSON strings):
//   {type: 'page',  page: 1, headers: [...], rows: [{<header>: [parts...]}]}
//   {type: 'done',  pages: 1}
//   {type: 'error', message: '...'}
//
// Each cell is returned as an array of strings: multiple "Voci Base" in one
// cell are separated by <br><span> in the portal's HTML (the desktop app
// replaces that sequence with a separator before pd.read_html).
(function () {
  'use strict';
  if (window.__cartellino) { return; }

  var TABLE_ID = '1011';
  var VOCE_SPLIT = /<br\s*\/?>\s*(?=<span)/i;

  function post(msg) { CartellinoChannel.postMessage(JSON.stringify(msg)); }
  function sleep(ms) { return new Promise(function (r) { setTimeout(r, ms); }); }

  async function waitFor(fn, timeoutMs) {
    var t0 = Date.now();
    while (Date.now() - t0 < timeoutMs) {
      var v = fn();
      if (v) { return v; }
      await sleep(250);
    }
    return null;
  }

  function text(html) {
    var d = document.createElement('div');
    d.innerHTML = html;
    return (d.textContent || '').replace(/\s+/g, ' ').trim();
  }

  function table() { return document.getElementById(TABLE_ID); }

  /// The DataTables API once the table is initialized and populated, else null.
  function readyDataTable() {
    var $ = window.jQuery;
    if (!$ || !$.fn.dataTable || !table() || !$.fn.dataTable.isDataTable(table())) {
      return null;
    }
    var dt = $(table()).DataTable();
    return dt.rows().count() > 0 ? dt : null;
  }

  function readRows() {
    var t = table();
    var headers = Array.prototype.map.call(
      t.querySelectorAll('thead th'), function (th) { return text(th.innerHTML); });
    var rows = [];
    Array.prototype.forEach.call(t.querySelectorAll('tbody tr'), function (tr) {
      var cells = tr.querySelectorAll('td');
      if (cells.length !== headers.length) { return; } // "no data" placeholder row
      var row = {};
      headers.forEach(function (h, i) {
        row[h] = cells[i].innerHTML.split(VOCE_SPLIT).map(text)
          .filter(function (s) { return s.length > 0; });
      });
      rows.push(row);
    });
    return { headers: headers, rows: rows };
  }

  async function run() {
    try {
      var dt = await waitFor(readyDataTable, 20000);
      if (!dt) {
        throw new Error('Tabella del cartellino (#' + TABLE_ID + ') non trovata');
      }
      var cookie = document.getElementById('cookieChoiceDismiss');
      if (cookie) { cookie.click(); }

      dt.page.len(-1).draw();
      var expected = dt.rows().count();
      var data = readRows();
      if (data.rows.length !== expected) {
        throw new Error('Lette ' + data.rows.length + ' righe su ' + expected);
      }
      post({ type: 'page', page: 1, headers: data.headers, rows: data.rows });
      post({ type: 'done', pages: 1 });
    } catch (e) {
      post({ type: 'error', message: String((e && e.message) || e) });
    }
  }

  window.__cartellino = { run: run };
})();
