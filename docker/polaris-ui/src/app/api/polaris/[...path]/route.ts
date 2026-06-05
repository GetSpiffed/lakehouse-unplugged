import { NextRequest, NextResponse } from 'next/server';

const polarisBaseUrl = process.env.POLARIS_BASE_URL;
const polarisClientId = process.env.POLARIS_CLIENT_ID;
const polarisClientSecret = process.env.POLARIS_CLIENT_SECRET;

type CachedToken = {
  accessToken: string;
  expiresAtMs: number;
};

let cachedToken: CachedToken | null = null;

function isTokenValid(token: CachedToken | null): token is CachedToken {
  return !!token && token.expiresAtMs > Date.now();
}

async function getAccessToken(): Promise<string | null> {
  if (isTokenValid(cachedToken)) {
    return cachedToken.accessToken;
  }

  if (!polarisBaseUrl || !polarisClientId || !polarisClientSecret) {
    return null;
  }

  const oauthUrl = `${polarisBaseUrl.replace(/\/$/, '')}/api/catalog/v1/oauth/tokens`;
  const body = new URLSearchParams({
    grant_type: 'client_credentials',
    client_id: polarisClientId,
    client_secret: polarisClientSecret,
    scope: 'PRINCIPAL_ROLE:ALL'
  });

  const response = await fetch(oauthUrl, {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body,
    cache: 'no-store'
  });

  if (!response.ok) {
    return null;
  }

  const tokenResponse = (await response.json()) as { access_token?: string; expires_in?: number };
  if (!tokenResponse.access_token) {
    return null;
  }

  const expiresInMs = Math.max(0, (tokenResponse.expires_in ?? 60) - 10) * 1000;
  cachedToken = {
    accessToken: tokenResponse.access_token,
    expiresAtMs: Date.now() + expiresInMs
  };

  return tokenResponse.access_token;
}

export async function GET(req: NextRequest, { params }: { params: Promise<{ path: string[] }> }) {
  if (!polarisBaseUrl || !polarisClientId || !polarisClientSecret) {
    return NextResponse.json({ error: 'POLARIS_BASE_URL is not configured on server.' }, { status: 500 });
  }

  const { path } = await params;
  const endpointPath = path.join('/');
  const upstream = new URL(`${polarisBaseUrl.replace(/\/$/, '')}/${endpointPath}`);
  upstream.search = req.nextUrl.search;

  try {
    const accessToken = await getAccessToken();
    if (!accessToken) {
      return NextResponse.json({ error: 'polaris_auth_failed' }, { status: 401 });
    }

    const response = await fetch(upstream, {
      method: 'GET',
      headers: {
        Accept: 'application/json',
        Authorization: `Bearer ${accessToken}`
      },
      cache: 'no-store'
    });

    const body = await response.text();

    return new NextResponse(body, {
      status: response.status,
      headers: {
        'content-type': response.headers.get('content-type') ?? 'application/json'
      }
    });
  } catch {
    return NextResponse.json(
      { error: 'polaris_proxy_failed' },
      { status: 502 }
    );
  }
}
