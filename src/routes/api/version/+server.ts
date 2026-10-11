import { json, type RequestHandler } from '@sveltejs/kit';
import { APP_BUILD_ID } from '$lib/deployment';

export const GET: RequestHandler = async () => {
  return json(
    {
      version: APP_BUILD_ID
    },
    {
      headers: {
        'Cache-Control': 'no-store, no-cache, must-revalidate, proxy-revalidate',
        Pragma: 'no-cache',
        Expires: '0'
      }
    }
  );
};
