import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync, existsSync } from 'node:fs';
import { dirname, extname, join, resolve } from 'node:path';
import ts from 'typescript';
const src=resolve('src');
function walk(dir){return readdirSync(dir,{withFileTypes:true}).flatMap(entry=>entry.isDirectory()?walk(join(dir,entry.name)):[join(dir,entry.name)]);}
const sources=walk(src).filter(file=>/\.tsx?$/.test(file));
test('all TypeScript and TSX source files parse without syntax errors',()=>{
  assert.ok(sources.length>=15);
  for(const file of sources){const source=ts.createSourceFile(file,readFileSync(file,'utf8'),ts.ScriptTarget.Latest,true,file.endsWith('.tsx')?ts.ScriptKind.TSX:ts.ScriptKind.TS);assert.equal(source.parseDiagnostics.length,0,`${file}: ${source.parseDiagnostics.map(d=>ts.flattenDiagnosticMessageText(d.messageText,' ')).join('; ')}`);}
});
test('all local imports resolve to source or asset files',()=>{
  for(const file of sources){const ast=ts.createSourceFile(file,readFileSync(file,'utf8'),ts.ScriptTarget.Latest,true);for(const stmt of ast.statements){if(!ts.isImportDeclaration(stmt)||!ts.isStringLiteral(stmt.moduleSpecifier))continue;const name=stmt.moduleSpecifier.text;if(!name.startsWith('.'))continue;const path=resolve(dirname(file),name);const found=[path,path+'.ts',path+'.tsx',path+'.css',path+'.webp',join(path,'index.ts'),join(path,'index.tsx')].some(existsSync);assert.ok(found,`${file} imports missing ${name}`);}}
});
test('the application contains required storefront routes',()=>{
  const code=readFileSync(join(src,'App.tsx'),'utf8');for(const route of ['/catalog','/product/','/login','/register','/verify-email','/forgot-password','/cart','/checkout','/orders','/payment-result','/wishlist','/compare','/pc-builder','/account'])assert.ok(code.includes(route),`Missing route ${route}`);
});
