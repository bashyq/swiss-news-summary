# Donate Feature — Setup Steps

## 1. Stripe Account Setup
- Go to https://dashboard.stripe.com
- Enable Apple Pay under Settings → Payment methods → Apple Pay
- Register domain: `swiss-news.pages.dev`

## 2. Replace Stripe Publishable Key
- Copy your publishable key from Stripe Dashboard → Developers → API keys
- In `frontend/app.js`, replace `pk_live_YOUR_STRIPE_PUBLISHABLE_KEY` with the actual key
- Use `pk_test_...` for testing first, switch to `pk_live_...` when ready

## 3. Set Stripe Secret Key on Worker
```bash
cd C:\Users\bashy\Documents\swiss-news-summary\worker
wrangler secret put STRIPE_SECRET_KEY
# Paste your sk_test_... or sk_live_... key when prompted
```

## 4. Apple Pay Domain Verification
- In Stripe Dashboard → Apple Pay settings, download the verification file
- Replace the placeholder content in `frontend/.well-known/apple-developer-merchantid-domain-association` with the downloaded file content

## 5. Deploy
```bash
cd C:\Users\bashy\Documents\swiss-news-summary\worker && npx wrangler deploy
cd C:\Users\bashy\Documents\swiss-news-summary && npx wrangler pages deploy frontend --project-name=swiss-news
```

## 6. Verify
- Worker endpoint: `curl -X POST https://swiss-news-worker.swissnews.workers.dev/donate -H "Content-Type: application/json" -d '{"amount":200}'` → should return `{ clientSecret: "pi_..." }`
- Domain verification: `curl https://swiss-news.pages.dev/.well-known/apple-developer-merchantid-domain-association` → should return file contents
- iOS Safari: Open app → hamburger menu → "Support us" → amount buttons + Apple Pay sheet
- Non-Apple devices: Menu should NOT show the donate item
