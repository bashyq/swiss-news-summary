/**
 * Donate — Stripe PaymentIntent creation for Apple Pay donations.
 */

export const VERSION = '1.0.0';

export async function handleDonate(url, env, request) {
  if (request.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': env.ALLOWED_ORIGIN || '*' }
    });
  }

  if (!env.STRIPE_SECRET_KEY) {
    return new Response(JSON.stringify({ error: 'Payment not configured' }), {
      status: 503,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': env.ALLOWED_ORIGIN || '*' }
    });
  }

  let body;
  try { body = await request.json(); } catch {
    return new Response(JSON.stringify({ error: 'Invalid request body' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': env.ALLOWED_ORIGIN || '*' }
    });
  }
  const amount = body.amount;

  if (!Number.isInteger(amount) || amount < 100 || amount > 500) {
    return new Response(JSON.stringify({ error: 'Amount must be 100-500 (CHF 1-5)' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': env.ALLOWED_ORIGIN || '*' }
    });
  }

  const res = await fetch('https://api.stripe.com/v1/payment_intents', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${env.STRIPE_SECRET_KEY}`,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: new URLSearchParams({
      amount: String(amount),
      currency: 'chf',
      'automatic_payment_methods[enabled]': 'true',
    }),
  });

  const pi = await res.json();

  if (!res.ok) {
    console.error('[donate] Stripe error:', pi);
    return new Response(JSON.stringify({ error: pi.error?.message || 'Payment failed' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': env.ALLOWED_ORIGIN || '*' }
    });
  }

  return new Response(JSON.stringify({ clientSecret: pi.client_secret }), {
    headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': env.ALLOWED_ORIGIN || '*' }
  });
}
