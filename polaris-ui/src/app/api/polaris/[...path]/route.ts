import { NextRequest, NextResponse } from 'next/server';

const polarisBaseUrl = process.env.POLARIS_BASE_URL;
const basicUser = process.env.POLARIS_API_USER;
const basicPassword = process.env.POLARIS_API_PASSWORD;
const bearerToken = process.env.POLARIS_API_BEARER_TOKEN;

function authHeaders(): HeadersInit {
  if (bearerToken) {
    return { Authorization: `Bearer ${bearerToken}` };
  }

  if (basicUser && basicPassword) {
    const encoded = Buffer.from(`${basicUser}:${basicPassword}`).toString('base64');
    return { Authorization: `Basic ${encoded}` };
  }

  return {};
}

export async function GET(req: NextRequest, { params }: { params: Promise<{ path: string[] }> }) {
  if (!polarisBaseUrl) {
    return NextResponse.json({ error: 'POLARIS_BASE_URL is not configured on server.' }, { status: 500 });
  }

  const { path } = await params;
  const endpointPath = path.join('/');
  const upstream = new URL(`${polarisBaseUrl.replace(/\/$/, '')}/${endpointPath}`);
  upstream.search = req.nextUrl.search;

  try {
    const response = await fetch(upstream, {
      method: 'GET',
      headers: {
        Accept: 'application/json',
        ...authHeaders()
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
  } catch (error) {
    return NextResponse.json(
      {
        error: 'Polaris is unreachable from polaris-ui service.',
        details: error instanceof Error ? error.message : 'Unknown error'
      },
      { status: 502 }
    );
  }
}
