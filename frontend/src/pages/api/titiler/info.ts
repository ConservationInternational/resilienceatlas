import type { NextApiRequest, NextApiResponse } from 'next';

/**
 * API route to proxy TiTiler /info requests.
 * This avoids CORS issues when fetching COG metadata from the frontend.
 *
 * Usage: /api/titiler/info?titilerUrl=<base>&cogUrl=<cog_url>
 */
export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { titilerUrl, cogUrl } = req.query;

  if (!titilerUrl || !cogUrl) {
    return res.status(400).json({ error: 'Missing required parameters: titilerUrl and cogUrl' });
  }

  const titilerBase = Array.isArray(titilerUrl) ? titilerUrl[0] : titilerUrl;
  const cogSource = Array.isArray(cogUrl) ? cogUrl[0] : cogUrl;

  try {
    const infoUrl = `${titilerBase}/info?url=${encodeURIComponent(cogSource)}`;
    const response = await fetch(infoUrl);

    if (!response.ok) {
      return res.status(response.status).json({
        error: `TiTiler request failed: ${response.statusText}`,
      });
    }

    const data = await response.json();
    return res.status(200).json(data);
  } catch (error) {
    console.error('[API/titiler/info] Error proxying request:', error);
    return res.status(500).json({ error: 'Failed to fetch COG info from TiTiler' });
  }
}
