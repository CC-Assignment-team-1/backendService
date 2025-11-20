async function fetchItems() {
  const limit = document.getElementById('limit').value;
  const key = document.getElementById('key').value;
  const value = document.getElementById('value').value;

  const params = new URLSearchParams();
  if (limit) params.append('limit', limit);
  if (key && value) {
    params.append('key', key);
    params.append('value', value);
  }

  const status = document.getElementById('status');
  status.innerText = 'Loading...';

  try {
    const res = await fetch('/api/items?' + params.toString());
    if (!res.ok) {
      const txt = await res.text();
      status.innerText = 'Error: ' + txt;
      return;
    }

    const data = await res.json();
    const items = data.items || [];

    renderTable(items);
    status.innerText = `Loaded ${items.length} items`;
  } catch (e) {
    status.innerText = 'Fetch failed: ' + e.message;
  }
}

function renderTable(items) {
  const thead = document.getElementById('thead');
  const tbody = document.getElementById('tbody');
  thead.innerHTML = '';
  tbody.innerHTML = '';

  if (!items.length) {
    thead.innerHTML = '<tr><th>No data</th></tr>';
    return;
  }

  // Build union of keys
  const keys = new Set();
  items.forEach(item => Object.keys(item).forEach(k => keys.add(k)));

  const headerRow = document.createElement('tr');
  keys.forEach(k => {
    const th = document.createElement('th');
    th.innerText = k;
    headerRow.appendChild(th);
  });
  thead.appendChild(headerRow);

  // Fill rows
  items.forEach(item => {
    const tr = document.createElement('tr');
    keys.forEach(k => {
      const td = document.createElement('td');
      const val = item[k];
      td.innerText = val === undefined ? '' : JSON.stringify(val);
      tr.appendChild(td);
    });
    tbody.appendChild(tr);
  });
}

document.getElementById('load').addEventListener('click', fetchItems);
// load immediately
fetchItems();
