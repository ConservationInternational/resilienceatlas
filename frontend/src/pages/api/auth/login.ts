import axios from 'axios';
import type { NextApiRequest, NextApiResponse } from 'next';

const BACKEND_URL = process.env.INTERNAL_API_HOST || process.env.NEXT_PUBLIC_API_HOST || 'http://localhost:3001';
const COOKIE_MAX_AGE = 7 * 24 * 60 * 60; // 7 days

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { email, password } = req.body ?? {};
  if (!email || !password) {
    return res.status(400).json({ error: 'email and password are required' });
  }

  try {
    const { data } = await axios.post(`${BACKEND_URL}/api/users/authenticate`, {
      email,
      password,
    });

    if (data.error || !data.auth_token) {
      return res.status(401).json({ error: data.error || 'Authentication failed' });
    }

    const secure = process.env.NODE_ENV === 'production' ? '; Secure' : '';
    res.setHeader(
      'Set-Cookie',
      `resilience_token=${data.auth_token}; HttpOnly${secure}; SameSite=Strict; Path=/; Max-Age=${COOKIE_MAX_AGE}`,
    );
    return res.status(200).json({ success: true });
  } catch (err: unknown) {
    const status = (err as { response?: { status?: number } })?.response?.status ?? 500;
    const message = (err as { response?: { data?: { error?: string } } })?.response?.data?.error ?? 'Authentication failed';
    return res.status(status).json({ error: message });
  }
}
