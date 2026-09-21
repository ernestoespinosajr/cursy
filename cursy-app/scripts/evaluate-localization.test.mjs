import test from 'node:test';
import assert from 'node:assert/strict';
import { MODELS, COMPUTER_MEMBERS, optionsFrom, validateFixture, imageDimensions, buildRequest,
  decodePoint, pointHits, evaluate } from './evaluate-localization.mjs';

const fixture = { caseID: 'case-01', image: '/private/tmp/synthetic.png', width: 100, height: 80,
  label: 'Synthetic control', acceptanceRect: { x: 0.2, y: 0.3, width: 0.2, height: 0.2 },
  imageData: { mime: 'image/png', base64: 'AAAA' } };
const options = { ...optionsFrom(['--fixtures', '/private/tmp/cases.json']), models: ['gpt-4.1'] };
const chatResult = point => ({ choices: [{ finish_reason: 'stop', message: { content: JSON.stringify({ point }) } }],
  usage: { prompt_tokens: 10, completion_tokens: 5 } });

test('offline default and arguments fail closed', () => {
  assert.equal(options.run, false);
  for (const argv of [[], ['--fixtures', 'x', '--max-calls', '21'], ['--fixtures', 'x', '--models', 'unknown'],
    ['--fixtures', 'x', '--models', 'gpt-4.1,gpt-4.1'], ['--fixtures', 'x', '--repeat', '0'], ['--wat']]) {
    assert.throws(() => optionsFrom(argv));
  }
});

test('fixtures reject private IDs, dimensions and bad acceptance regions', () => {
  assert.equal(validateFixture({ cases: [fixture] }).length, 1);
  for (const change of [{ caseID: 'private-name' }, { width: 0 }, { acceptanceRect: undefined },
    { acceptanceRect: { x: 0.9, y: 0, width: 0.5, height: 0.5 } }]) {
    assert.throws(() => validateFixture({ cases: [{ ...fixture, ...change }] }));
  }
  assert.throws(() => validateFixture({ cases: [fixture, fixture] }));
});

test('raster dimensions are read from bytes rather than trusted labels', () => {
  const png = Buffer.alloc(24);
  Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]).copy(png); png.write('IHDR', 12);
  png.writeUInt32BE(100, 16); png.writeUInt32BE(80, 20);
  assert.deepEqual(imageDimensions(png), { width: 100, height: 80, mime: 'image/png' });
  const jpeg = Buffer.from([255, 216, 255, 192, 0, 11, 8, 0, 80, 0, 100, 1, 1, 17, 0, 255, 217]);
  assert.deepEqual(imageDimensions(jpeg), { width: 100, height: 80, mime: 'image/jpeg' });
  assert.throws(() => imageDimensions(Buffer.from('not an image')));
});

test('Claude exposes exactly one non-click action; no dimensions or beta legacy fields', () => {
  const request = buildRequest('claude-sonnet-5', fixture);
  const tool = request.tools[0];
  assert.equal(COMPUTER_MEMBERS.length, 17);
  assert.equal(Object.keys(tool.configs).length, 17);
  assert.deepEqual(Object.entries(tool.configs).filter(([, config]) => config.enabled).map(([name]) => name), ['mouse_move']);
  assert.equal(tool.type, 'computer_toolset_20260801');
  assert.equal(tool.display_width_px, undefined);
  assert.equal(request.messages[0].content[0].type, 'text');
});

test('provider-specific requests preserve original or baseline image detail', () => {
  const modern = buildRequest('gpt-5.6-sol', fixture);
  assert.equal(modern.store, false);
  assert.equal(modern.input[0].content[1].detail, 'original');
  assert.equal(modern.tools[0].strict, true);
  assert.equal(modern.tools[0].name, 'record_localization');
  assert.equal(buildRequest('gpt-4.1', fixture).messages[1].content[1].image_url.detail, 'high');
  assert.equal(buildRequest('deepseek-flash', fixture).messages[1].content[1].image_url.detail, 'original');
  for (const model of Object.keys(MODELS)) {
    assert.ok(!JSON.stringify(buildRequest(model, fixture)).includes('acceptanceRect'));
  }
});

test('normalizes only validated model points and never executes tool output', () => {
  const point = { x: 30, y: 32 };
  assert.deepEqual(decodePoint('gpt-4.1', chatResult(point), fixture), point);
  assert.equal(pointHits(point, fixture), true);
  assert.equal(pointHits({ x: 90, y: 70 }, fixture), false);
  assert.equal(pointHits(null, { ...fixture, acceptanceRect: null }), true);
  assert.throws(() => decodePoint('gpt-4.1', chatResult({ x: 100, y: 32 }), fixture), /out_of_bounds/);
  const claude = { stop_reason: 'tool_use', content: [{ type: 'tool_use', toolset_name: 'computer', name: 'mouse_move', input: { coordinate: [30, 32] } }] };
  assert.deepEqual(decodePoint('claude-sonnet-5', claude, fixture), point);
  assert.throws(() => decodePoint('claude-sonnet-5', { ...claude, content: [{ ...claude.content[0], name: 'left_click' }] }, fixture), /unexpected_tool/);
  assert.throws(() => decodePoint('claude-sonnet-5', { ...claude, content: [...claude.content, ...claude.content] }, fixture), /unexpected_tool/);
  const modern = { status: 'completed', output: [{ type: 'function_call', name: 'record_localization', arguments: JSON.stringify({ point }) }] };
  assert.deepEqual(decodePoint('gpt-5.6-sol', modern, fixture), point);
  assert.throws(() => decodePoint('gpt-5.6-sol', { ...modern, status: 'incomplete' }, fixture), /incomplete_response/);
});

test('dry run never loads credentials or calls network', async () => {
  const rows = [];
  await evaluate(options, [fixture], { loadEnv: () => assert.fail('credential access'),
    fetchImpl: () => assert.fail('network access'), emit: row => rows.push(row) });
  assert.equal(rows[0].status, 'dry_run');
  assert.ok(!JSON.stringify(rows).includes(fixture.label));
  assert.ok(!JSON.stringify(rows).includes(fixture.image));
});

test('budget checked before secrets and paid calls', async () => {
  await assert.rejects(() => evaluate({ ...options, run: true, maxCalls: 1, repeat: 2 }, [fixture], {
    loadEnv: () => assert.fail('credential access'), fetchImpl: () => assert.fail('network access'),
  }), /call_budget_exceeded/);
});

test('live boundary uses only explicit env, no retries, logs only safe result metrics', async () => {
  const rows = []; let calls = 0;
  await evaluate({ ...options, run: true }, [fixture], {
    loadEnv: async () => ({ OPENAI_API_KEY: 'test-key' }),
    fetchImpl: async (url, request) => {
      calls++; assert.equal(url, MODELS['gpt-4.1'].url); assert.equal(request.redirect, 'error');
      assert.equal(request.headers.authorization, 'Bearer test-key');
      return new Response(JSON.stringify(chatResult({ x: 30, y: 32 })), { status: 200 });
    }, emit: row => rows.push(row),
  });
  assert.equal(calls, 1); assert.equal(rows[0].hit, true); assert.equal(rows[0].inputTokens, 10);
  assert.ok(!JSON.stringify(rows).includes('test-key'));
  assert.ok(!JSON.stringify(rows).includes('Synthetic'));
});

test('missing keys, server errors and thrown private errors remain redacted', async () => {
  for (const [credentials, response, expected] of [
    [{}, () => assert.fail('network without key'), 'missing_key'],
    [{ OPENAI_API_KEY: 'secret' }, () => new Response('secret echoed provider payload', { status: 403 }), 'http_error'],
    [{ OPENAI_API_KEY: 'secret' }, () => { throw new Error('secret and private label'); }, 'network_error'],
  ]) {
    const rows = [];
    await evaluate({ ...options, run: true }, [fixture], { loadEnv: async () => credentials,
      fetchImpl: response, emit: row => rows.push(row) });
    assert.equal(rows[0].status, expected);
    assert.ok(!JSON.stringify(rows).includes('secret'));
  }
});

test('Claude prepaid billing failures are distinguished without exposing raw errors', async () => {
  const rows = [];
  await evaluate({ ...options, run: true, models: ['claude-sonnet-5'] }, [fixture], {
    loadEnv: async () => ({ ANTHROPIC_API_KEY: 'test-secret' }),
    fetchImpl: async () => new Response(JSON.stringify({ error: { type: 'invalid_request_error',
      message: 'Your credit balance is too low to access the Anthropic API. Private provider context.' } }), { status: 400 }),
    emit: row => rows.push(row),
  });
  assert.equal(rows[0].status, 'billing_unavailable');
  assert.equal(rows[0].httpStatus, 400);
  assert.ok(!JSON.stringify(rows).includes('Private'));
  assert.ok(!JSON.stringify(rows).includes('test-secret'));
  assert.equal(rows[0].point, null);
});
