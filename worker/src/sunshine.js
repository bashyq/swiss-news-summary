/**
 * Sunshine — Weekend sunshine forecast for destinations near Zurich.
 * Uses Open-Meteo multi-location API (single request for all destinations).
 */

export const VERSION = '1.2.0';

import { getWeatherDescription } from './weather.js';

const DEST_HIGHLIGHTS = {
  lugano: [
    { name:'Parco Ciani', nameDE:'Parco Ciani', desc:'Lakeside park with large playground and duck pond', descDE:'Park am See mit grossem Spielplatz und Ententeich', indoor:false, cat:'playground', lat:46.0053, lon:8.9580 },
    { name:'Swissminiatur', nameDE:'Swissminiatur', desc:'Miniature Switzerland park with 120+ scale models', descDE:'Miniatur-Schweiz-Park mit über 120 Modellen', indoor:false, cat:'outdoor', lat:45.9553, lon:8.9468 },
    { name:'Lido di Lugano', nameDE:'Lido di Lugano', desc:'Sandy beach with kids pool and playground', descDE:'Sandstrand mit Kinderplanschbecken und Spielplatz', indoor:false, cat:'outdoor', lat:46.0005, lon:8.9625 },
  ],
  locarno: [
    { name:'Lido Locarno', nameDE:'Lido Locarno', desc:'Family pool complex with slides and sandy beach', descDE:'Familien-Schwimmbad mit Rutschen und Sandstrand', indoor:false, cat:'outdoor', lat:46.1660, lon:8.7935 },
    { name:'Cardada Playground', nameDE:'Spielplatz Cardada', desc:'Mountain playground at 1340m with cable car ride', descDE:'Bergspielplatz auf 1340m mit Seilbahnfahrt', indoor:false, cat:'playground', lat:46.1835, lon:8.7640 },
  ],
  bellinzona: [
    { name:'Castelgrande', nameDE:'Castelgrande', desc:'UNESCO castle with grassy courtyards, lift access', descDE:'UNESCO-Burg mit Grünflächen und Liftanschluss', indoor:false, cat:'outdoor', lat:46.1944, lon:9.0168 },
    { name:'Castello Montebello', nameDE:'Castello Montebello', desc:'Medieval castle with playground and picnic area', descDE:'Mittelalterliche Burg mit Spielplatz und Picknick', indoor:false, cat:'playground', lat:46.1943, lon:9.0244 },
  ],
  ascona: [
    { name:'Lakefront Playground', nameDE:'Spielplatz Seepromenade', desc:'Lakefront playground with trampolines and swings', descDE:'Spielplatz am See mit Trampolinen und Schaukeln', indoor:false, cat:'playground', lat:46.1570, lon:8.7730 },
    { name:'Brissago Islands', nameDE:'Brissago-Inseln', desc:'Botanical island with treasure hunt, boat ride over', descDE:'Botanische Insel mit Schatzsuche, per Boot erreichbar', indoor:false, cat:'nature', lat:46.1317, lon:8.7344 },
  ],
  chur: [
    { name:'Brambrüesch Playground', nameDE:'Spielplatz Brambrüesch', desc:'Mountain playground with cable car and theme trail', descDE:'Bergspielplatz mit Seilbahn und Themenweg', indoor:false, cat:'playground', lat:46.8670, lon:9.5025 },
    { name:'Bündner Naturmuseum', nameDE:'Bündner Naturmuseum', desc:'Interactive alpine animal exhibits for kids', descDE:'Interaktive Ausstellung alpiner Tiere für Kinder', indoor:true, cat:'museum', lat:46.8494, lon:9.5362 },
  ],
  davos: [
    { name:'Schatzalp Alpine Garden', nameDE:'Alpengarten Schatzalp', desc:'Alpine garden at 1864m with funicular ride up', descDE:'Alpengarten auf 1864m mit Standseilbahn', indoor:false, cat:'nature', lat:46.7927, lon:9.8204 },
    { name:'Rinerhorn Petting Zoo', nameDE:'Rinerhorn Streichelzoo', desc:'Free alpine petting zoo with goats and alpacas', descDE:'Gratis Streichelzoo mit Ziegen und Alpakas', indoor:false, cat:'animals', lat:46.7560, lon:9.8630 },
  ],
  stmoritz: [
    { name:'Muottas Muragl Playground', nameDE:'Spielplatz Muottas Muragl', desc:'Mountain playground at 2456m with epic Engadin view', descDE:'Bergspielplatz auf 2456m mit Engadin-Panorama', indoor:false, cat:'playground', lat:46.5237, lon:9.9092 },
    { name:'Lake St. Moritz Promenade', nameDE:'St. Moritzer See Promenade', desc:'Flat lakeside walk with playground and duck feeding', descDE:'Flacher Seeweg mit Spielplatz und Enten füttern', indoor:false, cat:'outdoor', lat:46.4935, lon:9.8410 },
  ],
  flims: [
    { name:'Caumasee', nameDE:'Caumasee', desc:'Turquoise alpine lake with playground and paddleboats', descDE:'Türkiser Bergsee mit Spielplatz und Tretbooten', indoor:false, cat:'outdoor', lat:46.8188, lon:9.2908 },
    { name:'Spielplatz Prau la Selva', nameDE:'Spielplatz Prau la Selva', desc:'Large forest playground with water play features', descDE:'Grosser Waldspielplatz mit Wasserspiel', indoor:false, cat:'playground', lat:46.8340, lon:9.2810 },
  ],
  sion: [
    { name:'Domaine des Îles', nameDE:'Domaine des Îles', desc:'Huge park with playground, mini-golf and mini train', descDE:'Grosser Park mit Spielplatz, Minigolf und Bähnli', indoor:false, cat:'playground', lat:46.2131, lon:7.3332 },
    { name:'Musée de la Nature', nameDE:'Naturmuseum Wallis', desc:'Interactive alpine exhibits, free first Sunday', descDE:'Interaktive Alpen-Ausstellung, 1. Sonntag gratis', indoor:true, cat:'museum', lat:46.2330, lon:7.3601 },
  ],
  brig: [
    { name:'Stockalperschloss Garden', nameDE:'Stockalperschloss Garten', desc:'Castle garden with playground, free courtyard access', descDE:'Schlossgarten mit Spielplatz, Hof frei zugänglich', indoor:false, cat:'playground', lat:46.3150, lon:7.9873 },
    { name:'Brigerbad Thermal Baths', nameDE:'Thermalbad Brigerbad', desc:'Thermal pools with toddler area and water slides', descDE:'Therme mit Kleinkinderbereich und Wasserrutschen', indoor:false, cat:'indoor-play', lat:46.3025, lon:7.9240 },
  ],
  zermatt: [
    { name:'Wolli Park Sunnegga', nameDE:'Wolli Park Sunnegga', desc:'Mountain playground with lake beach, by funicular', descDE:'Bergspielplatz mit Seestrand, per Standseilbahn', indoor:false, cat:'playground', lat:46.0300, lon:7.7701 },
    { name:'Obere Matten Playground', nameDE:'Spielplatz Obere Matten', desc:'Village playground near shops and restaurants', descDE:'Spielplatz im Dorf nahe Läden und Restaurants', indoor:false, cat:'playground', lat:46.0207, lon:7.7480 },
  ],
  luzern: [
    { name:'Verkehrshaus', nameDE:'Verkehrshaus der Schweiz', desc:'Transport museum with hands-on exhibits and playground', descDE:'Verkehrsmuseum mit Mitmach-Stationen und Spielplatz', indoor:true, cat:'museum', lat:47.0531, lon:8.3356 },
    { name:'Vögeligärtli Park', nameDE:'Vögeligärtli', desc:'Central playground near train station with sandbox', descDE:'Zentraler Spielplatz beim Bahnhof mit Sandkasten', indoor:false, cat:'playground', lat:47.0485, lon:8.3068 },
  ],
  interlaken: [
    { name:'Harder Kulm Playground', nameDE:'Spielplatz Harder Kulm', desc:'Alpine playground at 1322m with Jungfrau panorama', descDE:'Bergspielplatz auf 1322m mit Jungfrau-Panorama', indoor:false, cat:'playground', lat:46.6974, lon:7.8519 },
    { name:'Höhematte Park', nameDE:'Spielplatz Höhematte', desc:'Free central park playground with mountain views', descDE:'Gratis Spielplatz im Zentrum mit Bergpanorama', indoor:false, cat:'playground', lat:46.6859, lon:7.8598 },
  ],
  engelberg: [
    { name:'Globi Playground Ristis', nameDE:'Globi Spielplatz Ristis', desc:'Alpine playground with rope park and bouncy castle', descDE:'Bergspielplatz mit Seilpark und Hüpfburg', indoor:false, cat:'playground', lat:46.8130, lon:8.3820 },
    { name:'Trübsee Playground', nameDE:'Spielplatz Trübsee', desc:'Smuggler-themed playground by mountain lake', descDE:'Schmuggler-Spielplatz am Bergsee', indoor:false, cat:'playground', lat:46.7890, lon:8.3920 },
  ],
  schwyz: [
    { name:'Swiss Knife Valley Center', nameDE:'Swiss Knife Valley Besucherzentrum', desc:'Victorinox museum where kids can build a knife', descDE:'Victorinox-Museum, Kinder bauen ein Messer', indoor:true, cat:'museum', lat:46.9944, lon:8.6054 },
    { name:'Swiss Holiday Park', nameDE:'Swiss Holiday Park', desc:'Indoor waterpark with slides and toddler pool', descDE:'Erlebnisbad mit Rutschen und Kleinkinderbecken', indoor:true, cat:'indoor-play', lat:46.9830, lon:8.6160 },
  ],
  altdorf: [
    { name:'Tell Monument Square', nameDE:'Telldenkmal', desc:'Iconic William Tell statue with playground nearby', descDE:'Ikonisches Telldenkmal mit Spielplatz in der Nähe', indoor:false, cat:'outdoor', lat:46.8802, lon:8.6393 },
    { name:'Schwimmbad Altdorf', nameDE:'Schwimmbad Altdorf', desc:'Indoor/outdoor pool with slides and paddling pool', descDE:'Hallen-/Freibad mit Rutschen und Planschbecken', indoor:false, cat:'indoor-play', lat:46.8760, lon:8.6500 },
  ],
  lausanne: [
    { name:'Olympic Museum', nameDE:'Olympisches Museum', desc:'Interactive sports museum with lakeside park', descDE:'Interaktives Sportmuseum mit Seeuferpark', indoor:true, cat:'museum', lat:46.5088, lon:6.6340 },
    { name:'Ouchy Playground', nameDE:'Spielplatz Ouchy', desc:'Lakefront playground with paddleboats and ducks', descDE:'Spielplatz am See mit Tretbooten und Enten', indoor:false, cat:'playground', lat:46.5075, lon:6.6282 },
  ],
  montreux: [
    { name:'Château de Chillon', nameDE:'Schloss Chillon', desc:'Fairy-tale lakeside castle with kids activity booklet', descDE:'Märchenschloss am See mit Kinder-Aktivheft', indoor:true, cat:'museum', lat:46.4142, lon:6.9276 },
    { name:'Lakefront Playground', nameDE:'Spielplatz Seepromenade', desc:'Flower-lined lakefront promenade with playground', descDE:'Blumengesäumte Seepromenade mit Spielplatz', indoor:false, cat:'playground', lat:46.4340, lon:6.9120 },
  ],
  vevey: [
    { name:'Alimentarium', nameDE:'Alimentarium', desc:'Interactive food museum with hands-on kids exhibits', descDE:'Interaktives Ernährungsmuseum mit Kinderstationen', indoor:true, cat:'museum', lat:46.4583, lon:6.8464 },
    { name:'Lakefront Playground', nameDE:'Spielplatz am See', desc:'Large jungle gym by lake with swing sets', descDE:'Grosses Klettergerüst am See mit Schaukeln', indoor:false, cat:'playground', lat:46.4610, lon:6.8430 },
  ],
  basel: [
    { name:'Zoo Basel (Zolli)', nameDE:'Zoo Basel (Zolli)', desc:'Historic zoo with petting area and kids playground', descDE:'Historischer Zoo mit Streichelzoo und Spielplatz', indoor:false, cat:'animals', lat:47.5472, lon:7.5789 },
    { name:'Tierpark Lange Erlen', nameDE:'Tierpark Lange Erlen', desc:'Free animal park with deer, ponies and playground', descDE:'Gratis Tierpark mit Hirschen, Ponys und Spielplatz', indoor:false, cat:'animals', lat:47.5760, lon:7.6230 },
  ],
  solothurn: [
    { name:'Naturmuseum Solothurn', nameDE:'Naturmuseum Solothurn', desc:'Regional nature exhibits for families', descDE:'Regionale Naturausstellung für Familien', indoor:true, cat:'museum', lat:47.2078, lon:7.5372 },
    { name:'Verenaschlucht', nameDE:'Verenaschlucht', desc:'Atmospheric gorge walk to hermitage, stroller-friendly', descDE:'Stimmungsvolle Schluchtwanderung, kinderwagentauglich', indoor:false, cat:'nature', lat:47.2200, lon:7.5415 },
  ],
  delemont: [
    { name:'Préhisto-Parc', nameDE:'Préhisto-Parc', desc:'Dinosaur park with 45 life-size models in forest', descDE:'Dinosaurierpark mit 45 lebensgrossen Modellen', indoor:false, cat:'outdoor', lat:47.3013, lon:7.0532 },
    { name:'Parc du Château', nameDE:'Parc du Château', desc:'Castle park with playground and shaded picnic area', descDE:'Schlosspark mit Spielplatz und schattigem Picknick', indoor:false, cat:'playground', lat:47.3650, lon:7.3450 },
  ],
  konstanz: [
    { name:'SEA LIFE Konstanz', nameDE:'SEA LIFE Konstanz', desc:'Aquarium with underwater tunnel and touch pools', descDE:'Aquarium mit Unterwassertunnel und Streichelbecken', indoor:true, cat:'museum', lat:47.6605, lon:9.1770 },
    { name:'Stadtgarten Playground', nameDE:'Spielplatz Stadtgarten', desc:'Large lakeside playground with water play area', descDE:'Grosser Seespielplatz mit Wasserspielbereich', indoor:false, cat:'playground', lat:47.6615, lon:9.1790 },
  ],
  lindau: [
    { name:'Harbour Playground', nameDE:'Spielplatz am Hafen', desc:'Harbour playground with slides and lake views', descDE:'Hafenspielplatz mit Rutschen und Seeblick', indoor:false, cat:'playground', lat:47.5450, lon:9.6840 },
    { name:'Lindenhofpark', nameDE:'Lindenhofpark', desc:'Lakeside park with paddleboats and shaded playground', descDE:'Seepark mit Tretbooten und schattigem Spielplatz', indoor:false, cat:'outdoor', lat:47.5510, lon:9.6920 },
  ],
  como: [
    { name:'Villa Olmo Park', nameDE:'Park Villa Olmo', desc:'Grand lakefront park with playground, free entry', descDE:'Grosser Seeuferpark mit Spielplatz, Eintritt frei', indoor:false, cat:'outdoor', lat:45.8180, lon:9.0598 },
    { name:'Harbour Playground', nameDE:'Spielplatz am Hafen', desc:'Modern playground by boat dock with lake views', descDE:'Moderner Spielplatz beim Anleger mit Seeblick', indoor:false, cat:'playground', lat:45.8110, lon:9.0720 },
  ],
  schaffhausen: [
    { name:'Rhine Falls', nameDE:'Rheinfall', desc:'Europe\'s largest waterfall with playground and boat rides', descDE:'Grösster Wasserfall Europas mit Spielplatz und Boot', indoor:false, cat:'nature', lat:47.6778, lon:8.6152 },
    { name:'Munot Fortress', nameDE:'Munot Festung', desc:'Circular fortress with playground and deer park', descDE:'Runde Festung mit Spielplatz und Hirschgehege', indoor:false, cat:'outdoor', lat:47.6965, lon:8.6390 },
  ],
  frauenfeld: [
    { name:'Plättli Zoo', nameDE:'Plättli Zoo', desc:'Small zoo with petting area and pony rides', descDE:'Kleiner Zoo mit Streichelzoo und Ponyreiten', indoor:false, cat:'animals', lat:47.5605, lon:8.9157 },
    { name:'Schloss Frauenfeld', nameDE:'Schloss Frauenfeld', desc:'Historic castle with nature museum and park', descDE:'Historisches Schloss mit Naturmuseum und Park', indoor:true, cat:'museum', lat:47.5565, lon:8.8980 },
  ],
  rapperswil: [
    { name:'Knies Kinderzoo', nameDE:'Knies Kinderzoo', desc:'Children\'s zoo with camel rides and adventure playground', descDE:'Kinderzoo mit Kamelreiten und Abenteuerspielplatz', indoor:false, cat:'animals', lat:47.2290, lon:8.8210 },
    { name:'Castle Playground', nameDE:'Spielplatz Lindenhof', desc:'Lakefront playground below castle with climbing tower', descDE:'Seespielplatz unter dem Schloss mit Kletterturm', indoor:false, cat:'playground', lat:47.2267, lon:8.8180 },
  ],
};

export function getSunshineDestById(id) {
  return DESTINATIONS.find(d => d.id === id) || null;
}

const DESTINATIONS = [
  // Baseline (Zürich — always pinned first)
  { id: 'zurich', name: 'Zürich', nameDE: 'Zürich', lat: 47.3769, lon: 8.5417, region: 'Zürich', regionDE: 'Zürich', driveMinutes: 0, isBaseline: true },

  // Ticino
  { id: 'lugano', name: 'Lugano', nameDE: 'Lugano', lat: 46.0037, lon: 8.9511, region: 'Ticino', regionDE: 'Tessin', driveMinutes: 150 },
  { id: 'locarno', name: 'Locarno', nameDE: 'Locarno', lat: 46.1711, lon: 8.7953, region: 'Ticino', regionDE: 'Tessin', driveMinutes: 160 },
  { id: 'bellinzona', name: 'Bellinzona', nameDE: 'Bellinzona', lat: 46.1955, lon: 9.0234, region: 'Ticino', regionDE: 'Tessin', driveMinutes: 140 },
  { id: 'ascona', name: 'Ascona', nameDE: 'Ascona', lat: 46.1570, lon: 8.7726, region: 'Ticino', regionDE: 'Tessin', driveMinutes: 165 },

  // Graubunden
  { id: 'chur', name: 'Chur', nameDE: 'Chur', lat: 46.8499, lon: 9.5329, region: 'Graubünden', regionDE: 'Graubünden', driveMinutes: 80 },
  { id: 'davos', name: 'Davos', nameDE: 'Davos', lat: 46.8027, lon: 9.8360, region: 'Graubünden', regionDE: 'Graubünden', driveMinutes: 115 },
  { id: 'stmoritz', name: 'St. Moritz', nameDE: 'St. Moritz', lat: 46.4908, lon: 9.8355, region: 'Graubünden', regionDE: 'Graubünden', driveMinutes: 150 },
  { id: 'flims', name: 'Flims', nameDE: 'Flims', lat: 46.8354, lon: 9.2836, region: 'Graubünden', regionDE: 'Graubünden', driveMinutes: 95 },

  // Valais
  { id: 'sion', name: 'Sion', nameDE: 'Sitten', lat: 46.2330, lon: 7.3597, region: 'Valais', regionDE: 'Wallis', driveMinutes: 165 },
  { id: 'brig', name: 'Brig', nameDE: 'Brig', lat: 46.3138, lon: 7.9877, region: 'Valais', regionDE: 'Wallis', driveMinutes: 140 },
  { id: 'zermatt', name: 'Zermatt', nameDE: 'Zermatt', lat: 46.0207, lon: 7.7491, region: 'Valais', regionDE: 'Wallis', driveMinutes: 195 },

  // Central Switzerland
  { id: 'luzern', name: 'Lucerne', nameDE: 'Luzern', lat: 47.0502, lon: 8.3093, region: 'Central Switzerland', regionDE: 'Zentralschweiz', driveMinutes: 45 },
  { id: 'interlaken', name: 'Interlaken', nameDE: 'Interlaken', lat: 46.6863, lon: 7.8632, region: 'Bernese Oberland', regionDE: 'Berner Oberland', driveMinutes: 110 },
  { id: 'engelberg', name: 'Engelberg', nameDE: 'Engelberg', lat: 46.8210, lon: 8.4013, region: 'Central Switzerland', regionDE: 'Zentralschweiz', driveMinutes: 65 },
  { id: 'schwyz', name: 'Schwyz', nameDE: 'Schwyz', lat: 47.0207, lon: 8.6571, region: 'Central Switzerland', regionDE: 'Zentralschweiz', driveMinutes: 40 },
  { id: 'altdorf', name: 'Altdorf', nameDE: 'Altdorf', lat: 46.8802, lon: 8.6441, region: 'Central Switzerland', regionDE: 'Zentralschweiz', driveMinutes: 50 },

  // Lake Geneva
  { id: 'lausanne', name: 'Lausanne', nameDE: 'Lausanne', lat: 46.5197, lon: 6.6323, region: 'Lake Geneva', regionDE: 'Genfersee', driveMinutes: 140 },
  { id: 'montreux', name: 'Montreux', nameDE: 'Montreux', lat: 46.4312, lon: 6.9107, region: 'Lake Geneva', regionDE: 'Genfersee', driveMinutes: 150 },
  { id: 'vevey', name: 'Vevey', nameDE: 'Vevey', lat: 46.4603, lon: 6.8412, region: 'Lake Geneva', regionDE: 'Genfersee', driveMinutes: 145 },

  // Basel / Jura
  { id: 'basel', name: 'Basel', nameDE: 'Basel', lat: 47.5596, lon: 7.5886, region: 'Northwestern Switzerland', regionDE: 'Nordwestschweiz', driveMinutes: 55 },
  { id: 'solothurn', name: 'Solothurn', nameDE: 'Solothurn', lat: 47.2088, lon: 7.5378, region: 'Northwestern Switzerland', regionDE: 'Nordwestschweiz', driveMinutes: 65 },
  { id: 'delemont', name: 'Delémont', nameDE: 'Delémont', lat: 47.3647, lon: 7.3462, region: 'Jura', regionDE: 'Jura', driveMinutes: 90 },

  // Nearby
  { id: 'konstanz', name: 'Konstanz', nameDE: 'Konstanz', lat: 47.6633, lon: 9.1753, region: 'Lake Constance', regionDE: 'Bodensee', driveMinutes: 50 },
  { id: 'lindau', name: 'Lindau', nameDE: 'Lindau', lat: 47.5460, lon: 9.6829, region: 'Lake Constance', regionDE: 'Bodensee', driveMinutes: 70 },
  { id: 'como', name: 'Como', nameDE: 'Como', lat: 45.8081, lon: 9.0852, region: 'Lake Como', regionDE: 'Comer See', driveMinutes: 155 },
  { id: 'schaffhausen', name: 'Schaffhausen', nameDE: 'Schaffhausen', lat: 47.6960, lon: 8.6342, region: 'Eastern Switzerland', regionDE: 'Ostschweiz', driveMinutes: 35 },
  { id: 'frauenfeld', name: 'Frauenfeld', nameDE: 'Frauenfeld', lat: 47.5535, lon: 8.8987, region: 'Eastern Switzerland', regionDE: 'Ostschweiz', driveMinutes: 30 },
  { id: 'rapperswil', name: 'Rapperswil', nameDE: 'Rapperswil', lat: 47.2267, lon: 8.8184, region: 'Lake Zurich', regionDE: 'Zürichsee', driveMinutes: 25 },
];

function getWeekendDates() {
  const now = new Date();
  const day = now.getDay(); // 0=Sun, 1=Mon, ... 5=Fri, 6=Sat

  let friday;
  if (day === 5) {
    friday = new Date(now);
  } else if (day === 6) {
    friday = new Date(now);
    friday.setDate(friday.getDate() - 1);
  } else if (day === 0) {
    friday = new Date(now);
    friday.setDate(friday.getDate() - 2);
  } else {
    friday = new Date(now);
    friday.setDate(friday.getDate() + (5 - day));
  }

  const sat = new Date(friday);
  sat.setDate(sat.getDate() + 1);
  const sun = new Date(friday);
  sun.setDate(sun.getDate() + 2);

  const fmt = d => d.toISOString().split('T')[0];
  return { friday: fmt(friday), saturday: fmt(sat), sunday: fmt(sun) };
}

function parseLocationData(locData, dates) {
  if (!locData.daily?.time) return null;

  // Build hourly sunshine lookup: date -> array of hours with sunshine
  const hourlyMap = {};
  if (locData.hourly?.time) {
    locData.hourly.time.forEach((t, i) => {
      const date = t.substring(0, 10);
      const hour = parseInt(t.substring(11, 13), 10);
      if (hour >= 6 && hour <= 20 && (locData.hourly.sunshine_duration[i] || 0) > 0) {
        if (!hourlyMap[date]) hourlyMap[date] = [];
        hourlyMap[date].push(hour);
      }
    });
  }

  const allDays = locData.daily.time.map((date, i) => ({
    date,
    weatherCode: locData.daily.weather_code[i],
    tempMax: locData.daily.temperature_2m_max[i] != null ? Math.round(locData.daily.temperature_2m_max[i]) : 0,
    tempMin: locData.daily.temperature_2m_min[i] != null ? Math.round(locData.daily.temperature_2m_min[i]) : 0,
    sunshineHours: Math.round((locData.daily.sunshine_duration[i] || 0) / 360) / 10,
    precipMm: Math.round((locData.daily.precipitation_sum[i] || 0) * 10) / 10,
    sunnyHours: hourlyMap[date] || [],
    description: getWeatherDescription(locData.daily.weather_code[i]),
  }));

  const forecast = allDays.filter(d => dates.includes(d.date));
  const sunshineHoursTotal = Math.round(forecast.reduce((sum, d) => sum + d.sunshineHours, 0) * 10) / 10;

  return { forecast, sunshineHoursTotal };
}

async function fetchAllDestinations(weekendDates) {
  const lats = DESTINATIONS.map(d => d.lat).join(',');
  const lons = DESTINATIONS.map(d => d.lon).join(',');
  const dates = [weekendDates.friday, weekendDates.saturday, weekendDates.sunday];

  const url = `https://api.open-meteo.com/v1/forecast?latitude=${lats}&longitude=${lons}&daily=weather_code,temperature_2m_max,temperature_2m_min,sunshine_duration,precipitation_sum&hourly=sunshine_duration&start_date=${weekendDates.friday}&end_date=${weekendDates.sunday}&timezone=Europe/Zurich`;

  const res = await fetch(url, { headers: { Accept: 'application/json' } });
  if (!res.ok) {
    console.error(`Sunshine fetch failed: ${res.status}`);
    return [];
  }

  const data = await res.json();

  // Multi-location returns an array; single location returns a single object
  const locations = Array.isArray(data) ? data : [data];

  const results = [];
  for (let i = 0; i < DESTINATIONS.length && i < locations.length; i++) {
    const parsed = parseLocationData(locations[i], dates);
    if (!parsed) continue;

    const dest = DESTINATIONS[i];
    results.push({
      ...dest,
      forecast: parsed.forecast,
      sunshineHoursTotal: parsed.sunshineHoursTotal,
      highlights: DEST_HIGHLIGHTS[dest.id] || [],
    });
  }

  results.sort((a, b) => {
    if (a.isBaseline) return -1;
    if (b.isBaseline) return 1;
    return b.sunshineHoursTotal - a.sunshineHoursTotal;
  });
  return results;
}

export async function handleSunshine(url, env) {
  const lang = url.searchParams.get('lang') || 'en';
  const cacheKey = `sunshine-v3-${lang}`;

  // Check CF cache
  const cacheUrl = new URL(url.href);
  cacheUrl.searchParams.set('_ck', cacheKey);
  const cacheReq = new Request(cacheUrl.toString());
  const cfCache = caches.default;
  let cached = await cfCache.match(cacheReq);
  if (cached && url.searchParams.get('refresh') !== 'true') return cached;

  const weekendDates = getWeekendDates();
  const destinations = await fetchAllDestinations(weekendDates);

  const body = JSON.stringify({
    destinations,
    weekendDates,
    timestamp: new Date().toISOString(),
  });

  const headers = {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': env.ALLOWED_ORIGIN || '*',
    'Cache-Control': destinations.length > 0 ? 'public, max-age=1800' : 'no-store',
  };

  const response = new Response(body, { headers });

  // Only cache successful (non-empty) responses
  if (destinations.length > 0) {
    await cfCache.put(cacheReq, new Response(body, { headers }));
  }

  return response;
}
