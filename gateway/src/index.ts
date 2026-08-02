export interface Env {
  INVITE_SALT: string;
  PROVIDER_API_KEY?: string;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const requestId = crypto.randomUUID();
    const url = new URL(request.url);

    if (url.pathname === '/health') {
      return json({ ok: true, request_id: requestId });
    }

    if (url.pathname === '/generate' && request.method === 'POST') {
      const invite = request.headers.get('x-invite-code') ?? '';
      if (!invite || invite.length > 64) {
        return json({ error: 'invalid_invite', request_id: requestId }, 403);
      }

      return json({ error: 'gateway_not_configured', request_id: requestId }, 501);
    }

    return json({ error: 'not_found', request_id: requestId }, 404);
  },
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'content-type': 'application/json; charset=utf-8',
      'cache-control': 'no-store',
    },
  });
}
