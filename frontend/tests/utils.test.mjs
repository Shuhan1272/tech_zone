import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import ts from 'typescript';
const source=readFileSync(new URL('../src/lib/utils.ts',import.meta.url),'utf8');
const js=ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.ESNext,target:ts.ScriptTarget.ES2022}}).outputText;
const util=await import(`data:text/javascript;base64,${Buffer.from(js).toString('base64')}`);
test('formats prices in BDT',()=>{assert.match(util.money(2990),/^৳/);assert.match(util.money(2990),/2,990/);});
test('accepts only SSLCommerz HTTPS gateway URLs',()=>{
  assert.equal(util.validateGatewayUrl('https://securepay.sslcommerz.com/gwprocess/v4/gw.php'),true);
  assert.equal(util.validateGatewayUrl('https://sandbox.sslcommerz.com/path'),true);
  assert.equal(util.validateGatewayUrl('http://securepay.sslcommerz.com/path'),false);
  assert.equal(util.validateGatewayUrl('https://sslcommerz.com.evil.example/path'),false);
  assert.equal(util.validateGatewayUrl('javascript:alert(1)'),false);
});
test('handles DRF paginated and plain array responses',()=>{
  assert.deepEqual(util.asList({count:1,results:[{id:2}]}),[{id:2}]);
  assert.deepEqual(util.asList([{id:3}]),[{id:3}]);
  assert.deepEqual(util.asList(null),[]);
});
test('selects active default variant and server-computed price',()=>{
  const p={variants:[{id:1,is_default:false,is_active:true,discounted_price:'250.00'},{id:2,is_default:true,is_active:true,discounted_price:'200.00'}]};
  assert.equal(util.variantOf(p).id,2);assert.equal(util.priceOf(p),200);
});
test('blocks unsafe post-login destinations',()=>{
  assert.equal(util.safeNext('//evil.example'),'/');
  assert.equal(util.safeNext('/orders'),'/orders');
  assert.equal(util.safeNext('/login?next=abc'),'/');
});

const filterSource=readFileSync(new URL('../src/lib/catalogFilters.ts',import.meta.url),'utf8');
const filterJs=ts.transpileModule(filterSource,{compilerOptions:{module:ts.ModuleKind.ESNext,target:ts.ScriptTarget.ES2022}}).outputText;
const filters=await import(`data:text/javascript;base64,${Buffer.from(filterJs).toString('base64')}`);
test('serializes multi-brand, price and spec filters to Django query parameters',()=>{
  const params=filters.catalogApiParams('?category=laptop&brand=asus,msi&RAM=8GB&RAM=16GB&max_price=120000&in_stock=true&featured=true');
  assert.equal(params.get('brand'),'asus,msi');assert.deepEqual(params.getAll('RAM'),['8GB','16GB']);
  assert.equal(params.get('max_price'),'120000');assert.equal(params.get('is_featured'),'true');
  assert.equal(params.get('in_stock'),'true');
});
test('toggles one brand without losing the other filters',()=>{
  const p=filters.toggledCsv('?category=laptop&brand=asus,msi&RAM=16GB&page=2','brand','msi');
  assert.equal(p.get('brand'),'asus');assert.equal(p.get('RAM'),'16GB');assert.equal(p.get('page'),null);
});
test('repeated spec selection preserves multiple values',()=>{
  const p=filters.toggledSpec('?category=laptop&RAM=8GB','RAM','16GB');
  assert.deepEqual(p.getAll('RAM'),['8GB','16GB']);
});
