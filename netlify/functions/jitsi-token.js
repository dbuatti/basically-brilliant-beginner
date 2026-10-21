/**
 * jitsi-token — issues a Jitsi JWT for a meeting room.
 *
 * Enables the full iFrame API on the Council Console: prejoin skip, moderator
 * rights, and programmatic recording via `api.executeCommand('startRecording')`.
 *
 * The public Jitsi server (meet.jit.si) has `disableIframeAPI: true` and cuts
 * embedded calls off after 5 minutes, so none of that works there. Jitsi as a
 * Service (8x8.vc) does all of it.
 *
 * ── Setup (once) ───────────────────────────────────────────────────────
 * 1. Free account: https://jaas.8x8.vc  (JaaS Dev — 25 MAU, free)
 * 2. Copy the AppID from the console. It looks like
 *      vpaas-magic-cookie-1fc542a3e4414a44b2611668195e2bfe
 * 3. Generate an RSA key pair:
 *      ssh-keygen -t rsa -b 4096 -m PEM -f jaasauth.key
 *      openssl rsa -in jaasauth.key -pubout -outform PEM -out jaasauth.key.pub
 * 4. Upload jaasauth.key.pub in the JaaS console (API keys) — it issues a
 *    Key Id (kid), which looks like
 *      vpaas-magic-cookie-1fc542a3e4414a44b2611668195e2bfe/4f4910
 * 5. Set the environment variables in Netlify:
 *      JAAAS_APP_ID       = vpaas-magic-cookie-...
 *      JAAAS_API_KEY_ID   = vpaas-magic-cookie-.../4f4910
 *      JAAAS_PRIVATE_KEY  = the contents of jaasauth.key
 *
 * Until those are set, this returns 501 and the console falls back to the
 * public server, which still works for a full-window session.
 */

const crypto = require('crypto');

const b64url = (buf) =>
  Buffer.from(buf).toString('base64')
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');

exports.handler = async (event) => {
  const headers = {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
  };

  const appId    = process.env.JAAAS_APP_ID;
  const keyId    = process.env.JAAAS_API_KEY_ID;
  const privKey  = process.env.JAAAS_PRIVATE_KEY;

  if (!appId || !keyId || !privKey) {
    return {
      statusCode: 501,
      headers,
      body: JSON.stringify({
        configured: false,
        error: 'JaaS is not configured. Set JAAAS_APP_ID, JAAAS_API_KEY_ID and JAAAS_PRIVATE_KEY.',
      }),
    };
  }

  // Query params
  const params = event.queryStringParameters || {};
  const room = String(params.room || 'council-of-the-root').replace(/[^a-zA-Z0-9-_]/g, '');
  const name = String(params.name || 'Council').slice(0, 60);
  const moderator = params.moderator !== 'false';

  // The private key may arrive with literal \n or as a base64 blob
  let pem = privKey;
  if (!pem.includes('-----BEGIN')) {
    try { pem = Buffer.from(privKey, 'base64').toString('utf8'); } catch (e) { /* use as-is */ }
  }
  pem = pem.replace(/\\n/g, '\n');

  const now = Math.floor(Date.now() / 1000);
  const exp = now + 60 * 60 * 12;   // 12 hours

  const header = {
    alg: 'RS256',
    kid: keyId,
    typ: 'JWT',
  };

  const payload = {
    aud: 'jitsi',
    iss: 'chat',
    sub: appId,
    room: '*',
    nbf: now - 30,
    exp: exp,
    context: {
      user: {
        id: 'council-console',
        name: name,
        moderator: moderator ? 'true' : 'false',
        'hidden-from-recorder': false,
      },
      features: {
        livestreaming: 'false',
        recording: 'true',
        transcription: 'true',
      },
      room: { regex: false },
    },
  };

  let signature;
  try {
    const signer = crypto.createSign('RSA-SHA256');
    signer.update(`${b64url(JSON.stringify(header))}.${b64url(JSON.stringify(payload))}`);
    signature = signer.sign(pem, 'base64')
      .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  } catch (err) {
    return {
      statusCode: 500,
      headers,
      body: JSON.stringify({ configured: true, error: `Signing failed: ${err.message}` }),
    };
  }

  const jwt = `${b64url(JSON.stringify(header))}.${b64url(JSON.stringify(payload))}.${signature}`;

  return {
    statusCode: 200,
    headers,
    body: JSON.stringify({
      configured: true,
      jwt,
      domain: '8x8.vc',
      roomName: `${appId}/${room}`,
      roomUrl: `https://8x8.vc/${appId}/${room}`,
    }),
  };
};
