import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import ts from 'typescript';

function moduleUrl(source) {
  const javascript = ts.transpileModule(source, {
    compilerOptions: {
      module: ts.ModuleKind.ESNext,
      target: ts.ScriptTarget.ES2022,
    },
  }).outputText;
  return `data:text/javascript;base64,${Buffer.from(javascript).toString('base64')}`;
}
const apiUrl = moduleUrl(readFileSync('src/admin/api.ts', 'utf8'));
const source = readFileSync('src/admin/export.ts', 'utf8').replace(
  /["']\.\/api["']/,
  JSON.stringify(apiUrl),
);
const { csvCell, recordsCsv } = await import(moduleUrl(source));

test('CSV preserves commas, quotes, line breaks, booleans and empty values', () => {
  assert.equal(csvCell('Monitor, 27"'), '"Monitor, 27"""');
  assert.equal(csvCell('first\nsecond'), '"first\nsecond"');
  assert.equal(csvCell(null), '""');
  assert.equal(csvCell(false), '"false"');
});

test('CSV neutralizes formula prefixes including whitespace and control characters', () => {
  for (const value of [
    '=1+1',
    '+cmd',
    '-2+3',
    '@SUM(A1)',
    '  =1',
    '\tformula',
    '\rformula',
    '\nformula',
  ]) {
    assert.ok(csvCell(value).startsWith('"\''), value);
  }
  assert.equal(csvCell('Safe product'), '"Safe product"');
});

test('record export includes only the requested columns and safe labels', () => {
  const csv = recordsCsv(
    [
      {
        id: 7,
        email: 'staff@example.test',
        password: 'excluded',
        is_active: true,
      },
    ],
    ['email', 'is_active'],
  );
  assert.equal(csv, '"ID","Email","Active"\r\n"7","staff@example.test","true"');
  assert.ok(!csv.includes('excluded'));
});
