import axios from 'axios';
import type { NextApiRequest, NextApiResponse } from 'next';

const BACKEND_URL = process.env.INTERNAL_API_HOST || process.env.NEXT_PUBLIC_API_HOST || 'http://localhost:3001';

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const token = req.cookies['resilience_token'];
  if (!token) {
    return res.status(200).json({ authenticated: false });
  }

  try {
    const { data } = await axios.get(`${BACKEND_URL}/api/users/me`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    // Return the token so Redux can hold it in memory for client-side API calls.
    // It is never written to localStorage.
    return res.status(200).json({ authenticated: true, token, user: data });
  } catch {
    // Token is invalid or expired — clear the cookie
    const secure = process.env.NODE_ENV === 'production' ? '; Secure' : '';
    res.setHeader(
      'Set-Cookie',
      `resilience_token=; HttpOnly${secure}; SameSite=Strict; Path=/; Max-Age=0`,
    );
    return res.status(200).json({ authenticated: false });
  }
}
