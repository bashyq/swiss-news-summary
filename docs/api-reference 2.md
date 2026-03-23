# API Reference

Worker API base: `https://swiss-news-worker.swissnews.workers.dev`

## Main News Endpoint
`GET /?lang={en|de}&city={cityId}&refresh={true}`

```json
{
  "weather": { "temperature": 1, "description": "Foggy", "weatherCode": 45, "windSpeed": 3, "hourly": [...] },
  "transport": {
    "delays": [{ "line": "IC 8", "destination": "Bern", "delay": 5, "scheduledTime": "23:02" }],
    "summary": { "totalDelayed": 3, "maxDelay": 10, "status": "minor" }
  },
  "holidays": [{ "name": "Easter", "nameDE": "Ostern", "daysUntil": 45 }],
  "schoolHolidays": [{ "name": "Summer", "nameDE": "Sommerferien", "startDate": "2026-07-13", "endDate": "2026-08-14", "type": "schoolHoliday" }],
  "history": { "year": 1958, "event": "...", "eventDE": "..." },
  "categories": {
    "disruptions": [{ "headline": "...", "summary": "...", "source": "NZZ", "url": "..." }],
    "events": [...], "politics": [...], "culture": [...], "local": [...]
  },
  "briefing": {
    "topStory": { "headline": "...", "summary": "...", "source": "NZZ", "url": "..." },
    "suggestedActivity": { "id": "zoo-zurich", "name": "Zoo Zürich", "indoor": false, ... }
  },
  "trending": { "topic": "...", "topicDE": "...", "articleCount": 5 },
  "city": { "id": "zurich", "name": "Zürich" },
  "timestamp": "2026-..."
}
```

## Activities Endpoint
`GET /activities?lang={en|de}&city={cityId}`

```json
{
  "activities": [
    {
      "id": "zoo-zurich", "name": "Zoo Zürich", "nameDE": "Zoo Zürich",
      "description": "...", "indoor": false, "ageRange": "2-5 years",
      "duration": "2-4 hours", "price": "CHF 29 adults, kids under 6 free",
      "url": "https://www.zoo.ch", "lat": 47.3849, "lon": 8.5743,
      "category": "animals", "minAge": 2, "maxAge": 5, "season": "winter"
    }
  ],
  "cityEvents": [
    {
      "id": "zh-sechselaeuten", "name": "Sechseläuten", "city": "zurich",
      "startDate": "2026-04-20", "endDate": "2026-04-20",
      "description": "...", "toddlerFriendly": true, "free": true
    }
  ],
  "weather": { ... },
  "city": { "id": "zurich", "name": "Zürich" }
}
```

## Sunshine Endpoint
`GET /sunshine?lang={en|de}&refresh={true}`

```json
{
  "destinations": [
    {
      "id": "lugano", "name": "Lugano", "lat": 46.0037, "lon": 8.9511,
      "region": "Ticino", "driveMinutes": 150,
      "forecast": [
        { "date": "2026-02-20", "weatherCode": 1, "tempMax": 12, "tempMin": 3,
          "sunshineHours": 7.2, "precipMm": 0, "sunnyHours": [8,9,10,11,12,13,14,15,16] }
      ],
      "sunshineHoursTotal": 18.5
    }
  ],
  "weekendDates": { "friday": "2026-02-20", "saturday": "2026-02-21", "sunday": "2026-02-22" }
}
```

## Snow Endpoint
`GET /snow?lang={en|de}&refresh={true}`

```json
{
  "destinations": [
    {
      "id": "zermatt", "name": "Zermatt", "lat": 46.0207, "lon": 7.7491,
      "region": "Valais", "driveMinutes": 195, "altitude": 1620,
      "forecast": [
        { "date": "2026-02-16", "snowfallCm": 5.2, "weatherCode": 73, "tempMax": -2, "tempMin": -8 }
      ],
      "snowfallWeekTotal": 28.5, "snowDepthCm": 145
    }
  ],
  "weekDates": { "monday": "2026-02-16", "sunday": "2026-02-22" }
}
```

## Weekend Endpoint
`GET /weekend?lang={en|de}&city={cityId}`

## Lunch Endpoint
`GET /lunch?lang={en|de}&city={cityId}&lat={lat}&lon={lon}`
