'use client';

import { useMemo, useState } from 'react';
import { endpointMap, readonlyNotice, type EndpointKey } from '@/lib/polaris';

type EndpointState = {
  loading: boolean;
  status?: number;
  payload?: unknown;
  error?: string;
};

type State = Record<string, EndpointState>;

type Primitive = string | number | boolean | null | undefined;

type AnyRecord = Record<string, unknown>;

const endpoints = Object.entries(endpointMap) as [EndpointKey, string[]][];

function asRecord(input: unknown): AnyRecord | null {
  return input && typeof input === 'object' && !Array.isArray(input) ? (input as AnyRecord) : null;
}

function asArray(input: unknown): unknown[] {
  if (Array.isArray(input)) return input;
  const root = asRecord(input);
  if (!root) return [];
  const candidates = ['catalogs', 'principals', 'principalRoles', 'catalogRoles', 'items', 'results', 'data'];
  for (const key of candidates) {
    if (Array.isArray(root[key])) return root[key] as unknown[];
  }
  return [];
}

function pickString(source: AnyRecord, keys: string[]): string {
  for (const key of keys) {
    const value = source[key] as Primitive;
    if (typeof value === 'string' && value.trim().length > 0) return value;
  }
  return '—';
}

function pickNumber(source: AnyRecord, keys: string[]): number | null {
  for (const key of keys) {
    const value = source[key] as Primitive;
    if (typeof value === 'number' && Number.isFinite(value)) return value;
    if (typeof value === 'string' && /^\d+$/.test(value)) return Number(value);
  }
  return null;
}

function pickBoolean(source: AnyRecord, keys: string[]): boolean | null {
  for (const key of keys) {
    const value = source[key] as Primitive;
    if (typeof value === 'boolean') return value;
  }
  return null;
}

function formatEpochMs(value: number | null): string {
  if (!value || !Number.isFinite(value)) return '—';
  try {
    return new Date(value).toLocaleString();
  } catch {
    return String(value);
  }
}

function valueToString(value: unknown): string {
  if (value === null || value === undefined) return '—';
  if (typeof value === 'string') return value;
  if (typeof value === 'number' || typeof value === 'boolean') return String(value);
  if (Array.isArray(value)) return value.map(valueToString).join(', ');
  return JSON.stringify(value);
}

function RawJsonSection({ payload, stateKey }: { payload: unknown; stateKey: string }) {
  return (
    <details>
      <summary>Raw JSON</summary>
      <pre id={`raw-json-${stateKey}`}>{JSON.stringify(payload, null, 2)}</pre>
    </details>
  );
}

function CatalogsRenderer({ payload }: { payload: unknown }) {
  const catalogs = asArray(payload).map((item) => asRecord(item)).filter(Boolean) as AnyRecord[];

  return (
    <>
      <p className="summary">Catalogs loaded: <strong>{catalogs.length}</strong></p>
      <div className="nested-grid">
        {catalogs.map((catalog, idx) => {
          const properties = asRecord(catalog.properties) ?? {};
          return (
            <div className="subcard" key={`${pickString(catalog, ['name'])}-${idx}`}>
              <h4>{pickString(catalog, ['name'])}</h4>
              <dl className="kv-grid">
                <dt>Type</dt><dd>{pickString(catalog, ['type'])}</dd>
                <dt>Default base location</dt><dd className="wrap">{pickString(catalog, ['defaultBaseLocation'])}</dd>
                <dt>Storage endpoint</dt><dd className="wrap">{valueToString(properties['storage.endpoint'])}</dd>
                <dt>Storage type</dt><dd>{valueToString(properties['storage.type'])}</dd>
                <dt>Region</dt><dd>{valueToString(properties['storage.region'])}</dd>
                <dt>Allowed locations</dt><dd className="wrap">{valueToString(properties['allowed.locations'])}</dd>
                <dt>Created</dt><dd>{formatEpochMs(pickNumber(catalog, ['createTimestamp', 'createdAt']))}</dd>
                <dt>Last updated</dt><dd>{formatEpochMs(pickNumber(catalog, ['lastUpdateTimestamp', 'updatedAt']))}</dd>
              </dl>
            </div>
          );
        })}
      </div>
    </>
  );
}

function TableRenderer({ payload, columns }: { payload: unknown; columns: { key: string; label: string; type?: 'timestamp' | 'boolean' }[] }) {
  const rows = asArray(payload).map((item) => asRecord(item)).filter(Boolean) as AnyRecord[];
  return (
    <>
      <p className="summary">Records loaded: <strong>{rows.length}</strong></p>
      <div className="table-wrap">
        <table>
          <thead><tr>{columns.map((c) => <th key={c.key}>{c.label}</th>)}</tr></thead>
          <tbody>
            {rows.map((row, idx) => (
              <tr key={`${pickString(row, ['name'])}-${idx}`}>
                {columns.map((col) => {
                  let content = valueToString(row[col.key]);
                  if (col.type === 'timestamp') content = formatEpochMs(pickNumber(row, [col.key]));
                  if (col.type === 'boolean') {
                    const boolValue = pickBoolean(row, [col.key]);
                    content = boolValue === null ? '—' : boolValue ? 'Yes' : 'No';
                  }
                  return <td className="wrap" key={col.key}>{content}</td>;
                })}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  );
}

function FallbackRenderer({ payload, status }: { payload: unknown; status?: number }) {
  const items = asArray(payload);
  return (
    <div>
      <p className="summary">Status: <strong>{status ?? '—'}</strong></p>
      <p className="summary">Count: <strong>{items.length || '—'}</strong></p>
    </div>
  );
}

function renderSummary(key: EndpointKey, endpointState?: EndpointState) {
  if (!endpointState || endpointState.payload === undefined) return null;
  if (key === 'catalogs') return <CatalogsRenderer payload={endpointState.payload} />;
  if (key === 'principals') return <TableRenderer payload={endpointState.payload} columns={[
    { key: 'name', label: 'Name' },
    { key: 'clientId', label: 'Client ID' },
    { key: 'createTimestamp', label: 'Created', type: 'timestamp' },
    { key: 'lastUpdateTimestamp', label: 'Last Updated', type: 'timestamp' },
    { key: 'entityVersion', label: 'Entity Version' },
  ]} />;
  if (key === 'principalRoles') return <TableRenderer payload={endpointState.payload} columns={[
    { key: 'name', label: 'Name' },
    { key: 'federated', label: 'Federated', type: 'boolean' },
    { key: 'createTimestamp', label: 'Created', type: 'timestamp' },
    { key: 'lastUpdateTimestamp', label: 'Last Updated', type: 'timestamp' },
    { key: 'entityVersion', label: 'Entity Version' },
  ]} />;
  if (key === 'catalogRoles') return <TableRenderer payload={endpointState.payload} columns={[
    { key: 'name', label: 'Name' },
    { key: 'catalog', label: 'Catalog' },
    { key: 'createTimestamp', label: 'Created', type: 'timestamp' },
    { key: 'lastUpdateTimestamp', label: 'Last Updated', type: 'timestamp' },
    { key: 'entityVersion', label: 'Entity Version' },
  ]} />;
  return <FallbackRenderer payload={endpointState.payload} status={endpointState.status} />;
}

export default function PolarisDashboard() {
  const [query, setQuery] = useState('');
  const [state, setState] = useState<State>({});

  async function fetchEndpoint(key: EndpointKey, endpoint: string) {
    setState((s) => ({ ...s, [key]: { loading: true } }));
    try {
      const res = await fetch(`/api/polaris${endpoint}`);
      const text = await res.text();
      let payload: unknown = text;
      try { payload = JSON.parse(text); } catch {}
      setState((s) => ({ ...s, [key]: { loading: false, status: res.status, payload, error: res.ok ? undefined : 'Request failed. See raw JSON.' } }));
    } catch (error) {
      setState((s) => ({ ...s, [key]: { loading: false, error: error instanceof Error ? error.message : 'Unexpected error' } }));
    }
  }

  async function copyJson(key: EndpointKey) {
    const payload = state[key]?.payload;
    if (payload === undefined) return;
    await navigator.clipboard.writeText(JSON.stringify(payload, null, 2));
  }

  const filtered = useMemo(() => endpoints.filter(([key]) => key.toLowerCase().includes(query.toLowerCase())), [query]);

  return (
    <div className="container">
      <h1>Apache Polaris Read-Only UI</h1>
      <p className="badge">{readonlyNotice}</p>
      <div className="card">
        <label>Zoek endpoint of resource</label>
        <input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="catalogs, grants, namespaces..." />
      </div>
      <div className="grid">
        {filtered.map(([key, paths]) => (
          <div className="card" key={key}>
            <h3>{key}</h3>
            <small className="wrap">{paths.join(', ')}</small>
            <p className="actions">
              <button onClick={() => fetchEndpoint(key, paths[0])}>Load</button>
              <button onClick={() => copyJson(key)} disabled={state[key]?.payload === undefined}>Copy JSON</button>
            </p>
            {state[key]?.loading && <p>Loading…</p>}
            {state[key]?.status && <small>HTTP {state[key].status}</small>}
            {state[key]?.error && <p className="error">{state[key].error}</p>}
            {renderSummary(key, state[key])}
            {state[key]?.payload !== undefined && <RawJsonSection payload={state[key].payload} stateKey={key} />}
          </div>
        ))}
      </div>
    </div>
  );
}
