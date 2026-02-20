/**
 * Weather — Open Meteo integration.
 */

export const VERSION = '2.0.0';

const DESCRIPTIONS = {
  0: 'Clear sky',
  1: 'Mainly clear', 2: 'Partly cloudy', 3: 'Overcast',
  45: 'Foggy', 48: 'Foggy',
  51: 'Light drizzle', 53: 'Drizzle', 55: 'Heavy drizzle',
  61: 'Light rain', 63: 'Rain', 65: 'Heavy rain',
  71: 'Light snow', 73: 'Snow', 75: 'Heavy snow',
  80: 'Rain showers', 81: 'Rain showers', 82: 'Heavy showers',
  85: 'Snow showers', 86: 'Heavy snow showers',
  95: 'Thunderstorm', 96: 'Thunderstorm with hail', 99: 'Thunderstorm with hail'
};

export function getWeatherDescription(code) {
  return DESCRIPTIONS[code] || 'Unknown';
}

export async function fetchWeather(lat, lon) {
  try {
    const url = `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&current=temperature_2m,weather_code,wind_speed_10m&hourly=temperature_2m,weather_code&forecast_hours=12&timezone=Europe/Zurich`;
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 8000);
    const res = await fetch(url, { headers: { Accept: 'application/json' }, signal: controller.signal });
    clearTimeout(timeout);
    if (!res.ok) return null;

    const data = await res.json();
    const hourly = [];
    if (data.hourly?.time) {
      const now = new Date();
      for (let i = 0; i < Math.min(12, data.hourly.time.length); i++) {
        if (new Date(data.hourly.time[i]) >= now) {
          hourly.push({
            time: new Date(data.hourly.time[i]).toLocaleTimeString('en-CH', { hour: '2-digit', minute: '2-digit', hour12: false }),
            temperature: Math.round(data.hourly.temperature_2m[i]),
            weatherCode: data.hourly.weather_code[i]
          });
        }
        if (hourly.length >= 8) break;
      }
    }

    return {
      temperature: Math.round(data.current.temperature_2m),
      weatherCode: data.current.weather_code,
      windSpeed: Math.round(data.current.wind_speed_10m),
      description: getWeatherDescription(data.current.weather_code),
      hourly
    };
  } catch (e) {
    console.error('Weather error:', e.message);
    return null;
  }
}

export async function fetchWeekendWeather(lat, lon) {
  try {
    const url = `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&daily=weather_code,temperature_2m_max,temperature_2m_min&forecast_days=7&timezone=Europe/Zurich`;
    const res = await fetch(url, { headers: { Accept: 'application/json' } });
    if (!res.ok) return null;

    const data = await res.json();
    if (!data.daily?.time) return null;

    return data.daily.time.map((date, i) => ({
      date,
      weatherCode: data.daily.weather_code[i],
      tempMax: Math.round(data.daily.temperature_2m_max[i]),
      tempMin: Math.round(data.daily.temperature_2m_min[i]),
      description: getWeatherDescription(data.daily.weather_code[i])
    }));
  } catch (e) {
    console.error('Weekend weather error:', e.message);
    return null;
  }
}

export const RAINY_CODES = [51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82, 95, 96, 99];
