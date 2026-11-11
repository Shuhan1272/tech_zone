import { label, type Row } from './api';

/** Quote CSV fields and neutralize spreadsheet formula injection. */
export function csvCell(value: unknown): string {
  let text = value == null ? '' : String(value);
  if (/^[\s]*[=+@-]/.test(text) || /^[\t\r\n]/.test(text)) {
    text = "'" + text;
  }
  return '"' + text.replaceAll('"', '""') + '"';
}

export function recordsCsv(rows: Row[], columns: string[]): string {
  const fields = ['id', ...columns];
  return [
    fields.map((field) => csvCell(field === 'id' ? 'ID' : label(field))).join(','),
    ...rows.map((row) => fields.map((field) => csvCell(row[field])).join(',')),
  ].join('\r\n');
}

export function downloadRecords(rows: Row[], columns: string[], resource: string) {
  const blob = new Blob(['\uFEFF', recordsCsv(rows, columns)], {
    type: 'text/csv;charset=utf-8;',
  });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = `techzone-${resource}-${new Date().toISOString().slice(0, 10)}.csv`;
  link.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
