'use client';

import { useMemo, useState } from 'react';
import { endpointMap, readonlyNotice, type EndpointKey } from '@/lib/polaris';

type State = Record<string, { loading: boolean; status?: number; payload?: unknown; error?: string }>;

const endpoints = Object.entries(endpointMap) as [EndpointKey, string[]][];

export default function PolarisDashboard() {
  const [query, setQuery] = useState('');
  const [state, setState] = useState<State>({});

  async function fetchEndpoint(key: EndpointKey, endpoint: string) {
    setState((s) => ({ ...s, [key]: { loading: true } }));
    const res = await fetch(`/api/polaris${endpoint}`);
    const text = await res.text();
    let payload: unknown = text;
    try { payload = JSON.parse(text); } catch {}
    setState((s) => ({ ...s, [key]: { loading: false, status: res.status, payload, error: res.ok ? undefined : JSON.stringify(payload) } }));
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
            <small>{paths.join(', ')}</small>
            <p>
              <button onClick={() => fetchEndpoint(key, paths[0])}>Load</button>
            </p>
            {state[key]?.loading && <p>Loading...</p>}
            {state[key]?.status && <small>HTTP {state[key].status}</small>}
            {state[key]?.error && <p className="error">{state[key].error}</p>}
            {state[key]?.payload !== undefined && (
              <pre>{JSON.stringify(state[key].payload as unknown, null, 2)}</pre>
            )}
          </div>
        ))}
      </div>
      <div className="card">
        <h3>Relaties</h3>
        <p>Gebruik principalRoleBindings en catalogRoleBindings voor:</p>
        <ul>
          <li>principal → principal role</li>
          <li>principal role → catalog role</li>
          <li>catalog role → privileges/resources (via grants)</li>
        </ul>
      </div>
    </div>
  );
}
