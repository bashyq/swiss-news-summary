/**
 * Photos — Google Places photo proxy with R2 cache.
 * GET /photo/:activityId → venue photo (JPEG)
 */

export const VERSION = '1.1.0';

import { getActivityById } from './activities.js';
import { getSunshineDestById } from './sunshine.js';
import { getSnowResortById } from './snow.js';

const PHOTO_MAX_WIDTH = 600;

async function findPlacePhoto(name, lat, lon, apiKey) {
  // Step 1: Find place
  const searchUrl = `https://maps.googleapis.com/maps/api/place/findplacefromtext/json?input=${encodeURIComponent(name)}&inputtype=textquery&locationbias=point:${lat},${lon}&fields=place_id,photos&key=${apiKey}`;
  const searchRes = await fetch(searchUrl);
  if (!searchRes.ok) return { error: `Places search failed: ${searchRes.status}` };

  const searchData = await searchRes.json();
  if (searchData.status && searchData.status !== 'OK') return { error: `Places API: ${searchData.status} - ${searchData.error_message || ''}` };
  const candidate = searchData.candidates?.[0];
  if (!candidate?.photos?.length) return { error: `No photos found for "${name}"` };

  const photoRef = candidate.photos[0].photo_reference;

  // Step 2: Fetch photo bytes
  const photoUrl = `https://maps.googleapis.com/maps/api/place/photo?maxwidth=${PHOTO_MAX_WIDTH}&photo_reference=${photoRef}&key=${apiKey}`;
  const photoRes = await fetch(photoUrl, { redirect: 'follow' });
  if (!photoRes.ok) return { error: `Photo fetch failed: ${photoRes.status}` };

  return {
    bytes: await photoRes.arrayBuffer(),
    contentType: photoRes.headers.get('Content-Type') || 'image/jpeg'
  };
}

export async function handlePhoto(url, env) {
  const activityId = url.pathname.replace('/photo/', '');
  if (!activityId) {
    return new Response(JSON.stringify({ error: 'Missing activity ID' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': env.ALLOWED_ORIGIN || '*' }
    });
  }

  const corsHeader = { 'Access-Control-Allow-Origin': env.ALLOWED_ORIGIN || '*' };

  // Check R2 cache first
  const r2Key = `photos/${activityId}`;
  if (env.PHOTOS_BUCKET) {
    const cached = await env.PHOTOS_BUCKET.get(r2Key);
    if (cached) {
      return new Response(cached.body, {
        headers: {
          'Content-Type': cached.httpMetadata?.contentType || 'image/jpeg',
          'Cache-Control': 'public, max-age=2592000',
          ...corsHeader
        }
      });
    }
  }

  // Look up place from activities, sunshine destinations, snow resorts, or query params (for dynamic spots like lunch)
  let activity = getActivityById(activityId) || getSunshineDestById(activityId) || getSnowResortById(activityId);
  if (!activity) {
    const name = url.searchParams.get('name');
    const lat = parseFloat(url.searchParams.get('lat'));
    const lon = parseFloat(url.searchParams.get('lon'));
    if (name && !isNaN(lat) && !isNaN(lon)) {
      activity = { name, lat, lon };
    }
  }
  if (!activity || !activity.lat || !activity.lon) {
    return new Response(JSON.stringify({ error: 'Place not found' }), {
      status: 404, headers: { 'Content-Type': 'application/json', ...corsHeader }
    });
  }

  const apiKey = env.GOOGLE_PLACES_KEY;
  if (!apiKey) {
    return new Response(JSON.stringify({ error: 'Google Places API key not configured' }), {
      status: 503, headers: { 'Content-Type': 'application/json', ...corsHeader }
    });
  }

  // Fetch from Google Places
  const photo = await findPlacePhoto(activity.name, activity.lat, activity.lon, apiKey);
  if (!photo || photo.error) {
    return new Response(JSON.stringify({ error: photo?.error || 'Unknown error', activity: activity.name }), {
      status: 404,
      headers: { 'Content-Type': 'application/json', ...corsHeader }
    });
  }

  // Store in R2
  if (env.PHOTOS_BUCKET) {
    await env.PHOTOS_BUCKET.put(r2Key, photo.bytes, {
      httpMetadata: { contentType: photo.contentType }
    });
  }

  return new Response(photo.bytes, {
    headers: {
      'Content-Type': photo.contentType,
      'Cache-Control': 'public, max-age=2592000',
      ...corsHeader
    }
  });
}
