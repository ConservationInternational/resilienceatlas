import type { NextApiRequest, NextApiResponse } from 'next';

type DebugResponse = {
  rollbarTokenSet: boolean;
  rollbarTokenLength: number;
  rollbarTokenPrefix: string;
  nodeEnv: string;
  timestamp: string;
};

export default function handler(req: NextApiRequest, res: NextApiResponse<DebugResponse>) {
  const token = process.env.NEXT_PUBLIC_ROLLBAR_CLIENT_TOKEN || '';
  
  res.status(200).json({
    rollbarTokenSet: token.length > 0,
    rollbarTokenLength: token.length,
    // Show first 4 chars only for debugging (safe to expose prefix)
    rollbarTokenPrefix: token.length > 4 ? token.substring(0, 4) + '...' : '',
    nodeEnv: process.env.NODE_ENV || 'unknown',
    timestamp: new Date().toISOString(),
  });
}
