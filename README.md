# Swiss News Summary

A single-page web app that fetches headlines from Swiss news sources and summarizes them using Claude AI.

## Architecture

```
Your Domain
    ↓
Cloudflare Pages (frontend/index.html)
    ↓ API call
Cloudflare Worker (worker/worker.js)
    ↓
Claude API → Summary returned
```

## Prerequisites

- Cloudflare account (free tier works)
- Domain connected to Cloudflare DNS
- Claude API key from console.anthropic.com

---

## Deployment Instructions

### Step 1: Deploy the Cloudflare Worker (Backend)

#### Option A: Using Wrangler CLI (Recommended)

1. **Install Node.js** (if not installed): https://nodejs.org

2. **Install Wrangler CLI**:
   ```bash
   npm install -g wrangler
   ```

3. **Login to Cloudflare**:
   ```bash
   wrangler login
   ```

4. **Navigate to worker folder**:
   ```bash
   cd C:\Users\bashy\Documents\swiss-news-summary\worker
   ```

5. **Add your Claude API key as a secret**:
   ```bash
   wrangler secret put CLAUDE_API_KEY
   ```
   (Paste your API key when prompted)

6. **Deploy the worker**:
   ```bash
   wrangler deploy
   ```

7. **Note the worker URL** (e.g., `https://swiss-news-worker.your-subdomain.workers.dev`)

#### Option B: Using Cloudflare Dashboard

1. Go to https://dash.cloudflare.com
2. Select your account → **Workers & Pages** → **Create application** → **Create Worker**
3. Name it `swiss-news-worker`
4. Click **Edit code** and paste the contents of `worker/worker.js`
5. Click **Save and deploy**
6. Go to **Settings** → **Variables** → **Add variable**:
   - Add `CLAUDE_API_KEY` as an **encrypted** variable with your API key
   - Add `ALLOWED_ORIGIN` with your frontend domain (e.g., `https://news.yourdomain.com`)

---

### Step 2: Deploy the Frontend (Cloudflare Pages)

1. **Update the Worker URL in index.html**:
   Open `frontend/index.html` and find this line:
   ```javascript
   const WORKER_URL = 'https://swiss-news-worker.YOUR_SUBDOMAIN.workers.dev';
   ```
   Replace with your actual worker URL from Step 1.

2. **Deploy to Cloudflare Pages**:

   #### Via Dashboard:
   - Go to https://dash.cloudflare.com
   - **Workers & Pages** → **Create application** → **Pages** → **Upload assets**
   - Name: `swiss-news` (or whatever you prefer)
   - Upload the `frontend` folder (or just drag `index.html`)
   - Click **Deploy site**

3. **Connect your custom domain** (optional):
   - In Pages project → **Custom domains** → **Set up a custom domain**
   - Add `news.yourdomain.com` (or any subdomain)
   - Cloudflare will auto-configure DNS

---

### Step 3: Update CORS Settings

1. Go to your Worker in the dashboard
2. **Settings** → **Variables**
3. Update `ALLOWED_ORIGIN` to match your Pages URL:
   - Example: `https://swiss-news.pages.dev` or `https://news.yourdomain.com`

---

## Testing

1. Open your deployed Pages URL in a browser
2. Click **"Get Today's Summary"**
3. Wait 5-10 seconds for the summary to appear

---

## Costs

| Service | Cost |
|---------|------|
| Cloudflare Pages | Free |
| Cloudflare Workers | Free (100k requests/day) |
| Claude API (Haiku) | ~$0.01-0.02 per summary |

For personal use (a few requests per day), expect less than $1/month in API costs.

---

## Troubleshooting

### "Failed to fetch summary"
- Check browser console for errors (F12)
- Verify CORS: `ALLOWED_ORIGIN` must match your frontend domain exactly
- Verify API key is set correctly in Worker secrets

### No headlines appearing
- RSS feeds may have changed format
- Check Worker logs: Dashboard → Workers → your worker → **Logs**

### Rate limiting
- Claude API has rate limits; if exceeded, wait a few minutes

---

## Customization

### Add more news sources
Edit `NEWS_SOURCES` array in `worker.js`:
```javascript
{
  name: 'Blick',
  url: 'https://www.blick.ch/rss',
  language: 'de'
}
```

### Change summary language
Edit the prompt in `getSummaryFromClaude()` function to request German output instead of English.

### Add auto-refresh
Add this to `index.html` to auto-refresh every hour:
```javascript
setInterval(fetchSummary, 60 * 60 * 1000);
```

---

## File Structure

```
swiss-news-summary/
├── frontend/
│   └── index.html      # Single-page frontend
├── worker/
│   ├── worker.js       # Cloudflare Worker (backend)
│   └── wrangler.toml   # Worker configuration
└── README.md           # This file
```
