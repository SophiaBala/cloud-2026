import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Counter } from 'k6/metrics';
import { textSummary } from 'https://jslib.k6.io/k6-summary/0.1.0/index.js';

const BASE_URL = (__ENV.BASE_URL || 'http://localhost:8000').replace(/\/$/, '');
const VUS = parseInt(__ENV.VUS || '30', 10);
const THINK = parseFloat(__ENV.THINK || '0.3');
const RAMP_UP = __ENV.RAMP_UP || '3m';
const STEADY = __ENV.STEADY || '5m';
const RAMP_DOWN = __ENV.RAMP_DOWN || '2m';
const LABEL = __ENV.LABEL || 'run';

const cacheHit = new Rate('cache_hit');
const writes = new Counter('writes');

export const options = {
  scenarios: {
    users: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: RAMP_UP, target: VUS },
        { duration: STEADY, target: VUS },
        { duration: RAMP_DOWN, target: 0 },
      ],
      gracefulRampDown: '10s',
    },
  },
  summaryTrendStats: ['avg', 'min', 'med', 'p(95)', 'p(99)', 'max'],
  thresholds: {
    http_req_failed: ['rate<0.01'],
  },
};

const JSON_HEADERS = { headers: { 'Content-Type': 'application/json' } };

function pick(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

function getStats() {
  const r = http.get(`${BASE_URL}/stats`, { tags: { name: 'stats' } });
  return r.status === 200 ? r.json() : null;
}

export function setup() {
  return { start: getStats(), startedAt: Date.now() };
}

export default function () {
  const unique = `${__VU}-${__ITER}-${Math.floor(Math.random() * 1e6)}`;
  const created = http.post(
    `${BASE_URL}/shop`,
    JSON.stringify({ address: `Load st. ${__VU}`, phone: `+${unique}`, city: 'Lviv' }),
    { ...JSON_HEADERS, tags: { name: 'POST /shop' } },
  );
  check(created, { 'create 201': (r) => r.status === 201 });
  writes.add(1);
  const newId = created.status === 201 ? created.json('idshop') : null;
  sleep(THINK);

  let ids = [];
  for (let i = 0; i < 4; i++) {
    const list = http.get(`${BASE_URL}/shop`, { tags: { name: 'GET /shop' } });
    check(list, { 'list 200': (r) => r.status === 200 });
    cacheHit.add(list.headers['X-Cache'] === 'HIT');
    if (list.status === 200 && ids.length === 0) ids = list.json().map((s) => s.id);
    sleep(THINK);
  }

  if (newId) {
    const own = http.get(`${BASE_URL}/shop/${newId}`, { tags: { name: 'GET /shop/{id}' } });
    check(own, { 'own shop 200': (r) => r.status === 200 });
    sleep(THINK);
  }

  for (let i = 0; i < 2; i++) {
    const id = ids.length ? pick(ids) : newId;
    const r = http.get(`${BASE_URL}/shop/${id}`, { tags: { name: 'GET /shop/{id}' } });
    check(r, { 'shop 200': (x) => x.status === 200 });
    sleep(THINK);
  }

  for (let i = 0; i < 2; i++) {
    const id = newId || pick(ids);
    const r = http.get(`${BASE_URL}/shop/${id}/staff`, { tags: { name: 'GET /shop/{id}/staff' } });
    check(r, { 'staff 200': (x) => x.status === 200 });
    sleep(THINK);
  }
}

export function teardown(data) {
  const end = getStats();
  const seconds = (Date.now() - data.startedAt) / 1000;
  if (!data.start || !end) return;
  const d = (k) => end.db[k] - data.start.db[k];
  console.log(JSON.stringify({
    duration_s: Math.round(seconds),
    db_queries: d('Questions'),
    db_queries_per_s: +(d('Questions') / seconds).toFixed(1),
    db_selects: d('Com_select'),
    db_inserts: d('Com_insert'),
    cache_enabled: end.cache.enabled,
    cache_hits: end.cache.hits - (data.start.cache.hits || 0),
    cache_misses: end.cache.misses - (data.start.cache.misses || 0),
  }));
}

export function handleSummary(data) {
  const m = data.metrics;
  const dur = m.http_reqs ? data.state.testRunDurationMs / 1000 : 0;
  const short = {
    label: LABEL,
    base_url: BASE_URL,
    vus: VUS,
    requests: m.http_reqs.values.count,
    rps: +(m.http_reqs.values.count / dur).toFixed(1),
    error_rate: m.http_req_failed.values.rate,
    p50_ms: +m.http_req_duration.values.med.toFixed(1),
    p95_ms: +m.http_req_duration.values['p(95)'].toFixed(1),
    p99_ms: +m.http_req_duration.values['p(99)'].toFixed(1),
    cache_hit_rate: m.cache_hit ? m.cache_hit.values.rate : null,
  };
  return {
    stdout: textSummary(data, { indent: ' ', enableColors: true }) + '\n\nSUMMARY ' + JSON.stringify(short) + '\n',
    [`results/${LABEL}.json`]: JSON.stringify({ summary: short, k6: data }, null, 2),
  };
}
