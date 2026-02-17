/**
 * Cities, holidays, history — static data shared across modules.
 */

export const VERSION = '2.0.0';

export const CITIES = {
  zurich: {
    name: 'Zürich', lat: 47.3769, lon: 8.5417, station: 'Zürich HB',
    sources: [
      { name: 'NZZ Zürich', url: 'https://www.nzz.ch/zuerich.rss' },
      { name: 'Google Zürich', url: 'https://news.google.com/rss/search?q=zurich+OR+zürich&hl=en&gl=CH&ceid=CH:en' }
    ]
  },
  basel: {
    name: 'Basel', lat: 47.5596, lon: 7.5886, station: 'Basel SBB',
    sources: [
      { name: 'Google Basel', url: 'https://news.google.com/rss/search?q=basel+switzerland&hl=en&gl=CH&ceid=CH:en' }
    ]
  },
  geneva: {
    name: 'Geneva', lat: 46.2044, lon: 6.1432, station: 'Genève',
    sources: [
      { name: 'Tribune de Genève', url: 'https://www.tdg.ch/geneve/rss.xml' },
      { name: 'Google Geneva', url: 'https://news.google.com/rss/search?q=geneva+switzerland&hl=en&gl=CH&ceid=CH:en' }
    ]
  },
  bern: {
    name: 'Bern', lat: 46.9480, lon: 7.4474, station: 'Bern',
    sources: [
      { name: 'Google Bern', url: 'https://news.google.com/rss/search?q=bern+switzerland&hl=en&gl=CH&ceid=CH:en' }
    ]
  },
  lausanne: {
    name: 'Lausanne', lat: 46.5197, lon: 6.6323, station: 'Lausanne',
    sources: [
      { name: '24 heures', url: 'https://www.24heures.ch/vaud/rss.xml' },
      { name: 'Google Lausanne', url: 'https://news.google.com/rss/search?q=lausanne+switzerland&hl=en&gl=CH&ceid=CH:en' }
    ]
  },
  luzern: {
    name: 'Luzern', lat: 47.0502, lon: 8.3093, station: 'Luzern',
    sources: [
      { name: 'Luzerner Zeitung', url: 'https://www.luzernerzeitung.ch/zentralschweiz/luzern.rss' },
      { name: 'Luzerner Zeitung Zentralschweiz', url: 'https://www.luzernerzeitung.ch/zentralschweiz.rss' },
      { name: 'Google Luzern', url: 'https://news.google.com/rss/search?q=luzern+OR+lucerne+switzerland&hl=en&gl=CH&ceid=CH:en' }
    ]
  },
  winterthur: {
    name: 'Winterthur', lat: 47.4984, lon: 8.7235, station: 'Winterthur',
    sources: [
      { name: 'Tagesanzeiger Winterthur', url: 'https://www.tagesanzeiger.ch/winterthur/rss.xml' },
      { name: 'Google Winterthur', url: 'https://news.google.com/rss/search?q=winterthur+switzerland&hl=en&gl=CH&ceid=CH:en' }
    ]
  }
};

export const NATIONAL_SOURCES = [
  { name: 'NZZ Schweiz', url: 'https://www.nzz.ch/schweiz.rss' },
  { name: 'SRF News', url: 'https://www.srf.ch/news/bnf/rss/1890' },
  { name: '20 Minuten', url: 'https://partner-feeds.20min.ch/rss/20minuten' },
  { name: 'Inside Paradeplatz', url: 'https://insideparadeplatz.ch/feed/' },
  { name: 'Google News CH', url: 'https://news.google.com/rss/search?q=switzerland+news&hl=en&gl=CH&ceid=CH:en' }
];

export function getCity(id) {
  return CITIES[id] || CITIES.zurich;
}

/* ── Easter & holidays ── */

function calculateEaster(year) {
  const a = year % 19, b = Math.floor(year / 100), c = year % 100;
  const d = Math.floor(b / 4), e = b % 4, f = Math.floor((b + 8) / 25);
  const g = Math.floor((b - f + 1) / 3);
  const h = (19 * a + b - d - g + 15) % 30;
  const i = Math.floor(c / 4), k = c % 4;
  const l = (32 + 2 * e + 2 * i - h - k) % 7;
  const m = Math.floor((a + 11 * h + 22 * l) / 451);
  const month = Math.floor((h + l - 7 * m + 114) / 31);
  const day = ((h + l - 7 * m + 114) % 31) + 1;
  return new Date(year, month - 1, day);
}

export function getUpcomingHolidays(cityId) {
  const year = new Date().getFullYear();
  const today = new Date(); today.setHours(0, 0, 0, 0);

  const holidays = [
    { date: `${year}-01-01`, name: "New Year's Day", nameDE: 'Neujahr', national: true },
    { date: `${year}-01-02`, name: "Berchtold's Day", nameDE: 'Berchtoldstag', cantons: ['zurich', 'bern', 'basel', 'lausanne'] },
    { date: `${year}-08-01`, name: 'Swiss National Day', nameDE: 'Bundesfeier', national: true },
    { date: `${year}-12-25`, name: 'Christmas Day', nameDE: 'Weihnachten', national: true },
    { date: `${year}-12-26`, name: "St. Stephen's Day", nameDE: 'Stephanstag', cantons: ['zurich', 'bern', 'basel'] },
  ];

  const easter = calculateEaster(year);
  const easterBased = [
    { offset: -2, name: 'Good Friday', nameDE: 'Karfreitag', cantons: ['zurich', 'bern', 'basel', 'geneva', 'lausanne'] },
    { offset: 0, name: 'Easter Sunday', nameDE: 'Ostersonntag', national: true },
    { offset: 1, name: 'Easter Monday', nameDE: 'Ostermontag', cantons: ['zurich', 'bern', 'basel', 'lausanne'] },
    { offset: 39, name: 'Ascension Day', nameDE: 'Auffahrt', national: true },
    { offset: 49, name: 'Whit Sunday', nameDE: 'Pfingstsonntag', national: true },
    { offset: 50, name: 'Whit Monday', nameDE: 'Pfingstmontag', cantons: ['zurich', 'bern', 'basel', 'lausanne'] },
  ];
  for (const h of easterBased) {
    const d = new Date(easter); d.setDate(d.getDate() + h.offset);
    holidays.push({ date: d.toISOString().split('T')[0], name: h.name, nameDE: h.nameDE, national: h.national, cantons: h.cantons });
  }

  const cantonal = {
    zurich: [
      { date: `${year}-04-19`, name: 'Sechseläuten', nameDE: 'Sechseläuten' },
      { date: `${year}-09-11`, name: 'Knabenschiessen', nameDE: 'Knabenschiessen' },
    ],
    geneva: [
      { date: `${year}-12-12`, name: 'Escalade', nameDE: 'Escalade' },
      { date: `${year}-09-04`, name: 'Geneva Fast', nameDE: 'Jeûne genevois' },
    ],
    basel: [
      { date: `${year}-02-19`, name: 'Carnival', nameDE: 'Fasnacht' },
    ],
  };
  if (cantonal[cityId]) {
    for (const h of cantonal[cityId]) holidays.push({ ...h, cantonal: true });
  }

  const sixtyDays = new Date(today); sixtyDays.setDate(sixtyDays.getDate() + 60);

  return holidays
    .filter(h => {
      const d = new Date(h.date);
      const relevant = h.national || h.cantonal || (h.cantons && h.cantons.includes(cityId));
      return relevant && d >= today && d <= sixtyDays;
    })
    .map(h => {
      const d = new Date(h.date);
      const daysUntil = Math.ceil((d - today) / 86400000);
      return { ...h, daysUntil, isToday: daysUntil === 0 };
    })
    .sort((a, b) => a.daysUntil - b.daysUntil)
    .slice(0, 3);
}

/* ── This Day in History ── */

const HISTORY = {
  '1-1': { year: 1291, event: 'Traditional date of Swiss Confederation founding (Federal Charter)', eventDE: 'Traditionelles Datum der Gründung der Eidgenossenschaft' },
  '1-2': { year: 1946, event: 'First Swiss television broadcast from Zurich', eventDE: 'Erste Schweizer Fernsehübertragung aus Zürich' },
  '1-6': { year: 1912, event: 'Alfred Wegener presents continental drift theory in Frankfurt', eventDE: 'Alfred Wegener präsentiert die Kontinentaldrift-Theorie' },
  '1-12': { year: 1528, event: 'Bern adopts Protestant Reformation', eventDE: 'Bern führt die protestantische Reformation ein' },
  '2-5': { year: 1958, event: "Swiss voters reject women's suffrage (finally granted 1971)", eventDE: 'Schweizer Stimmbürger lehnen Frauenstimmrecht ab (1971 eingeführt)' },
  '2-7': { year: 1971, event: 'Swiss women gain the right to vote at federal level', eventDE: 'Schweizer Frauen erhalten das Stimmrecht auf Bundesebene' },
  '2-14': { year: 1349, event: 'Basel massacre: 600 Jews killed during Black Death persecution', eventDE: 'Basler Judenverfolgung während der Pest' },
  '2-19': { year: 1803, event: "Napoleon's Act of Mediation creates Swiss Confederation of 19 cantons", eventDE: 'Napoleons Mediationsakte schafft die Schweizerische Eidgenossenschaft mit 19 Kantonen' },
  '3-1': { year: 1848, event: 'Swiss Federal Constitution adopted, creating modern Switzerland', eventDE: 'Annahme der Bundesverfassung, Gründung der modernen Schweiz' },
  '3-16': { year: 1798, event: 'French invasion ends the Old Swiss Confederacy', eventDE: 'Französische Invasion beendet die Alte Eidgenossenschaft' },
  '4-19': { year: 1529, event: 'First Kappel War between Protestant and Catholic cantons', eventDE: 'Erster Kappelerkrieg zwischen protestantischen und katholischen Kantonen' },
  '5-1': { year: 1890, event: 'First May Day celebration in Switzerland', eventDE: 'Erste 1. Mai-Feier in der Schweiz' },
  '5-20': { year: 1802, event: 'First ascent of the Finsteraarhorn, highest Bernese Alps peak', eventDE: 'Erstbesteigung des Finsteraarhorns' },
  '6-22': { year: 1476, event: 'Battle of Morat: Swiss defeat Burgundian army', eventDE: 'Schlacht bei Murten: Schweizer besiegen burgundisches Heer' },
  '7-1': { year: 1990, event: 'Appenzell Innerrhoden forced to grant women vote (last canton)', eventDE: 'Appenzell Innerrhoden muss Frauenstimmrecht einführen (letzter Kanton)' },
  '7-24': { year: 1938, event: 'First ascent of the Eiger North Face', eventDE: 'Erstbesteigung der Eiger-Nordwand' },
  '8-1': { year: 1291, event: 'Swiss National Day: Rütli oath (legendary founding)', eventDE: 'Schweizer Nationalfeiertag: Rütlischwur' },
  '8-17': { year: 1798, event: 'Nidwalden uprising against French occupation', eventDE: 'Nidwaldner Aufstand gegen französische Besatzung' },
  '9-12': { year: 1848, event: 'New Federal Constitution comes into force', eventDE: 'Neue Bundesverfassung tritt in Kraft' },
  '9-22': { year: 1499, event: 'Treaty of Basel: Swiss independence from Holy Roman Empire', eventDE: 'Friede von Basel: Unabhängigkeit vom Heiligen Römischen Reich' },
  '10-10': { year: 1531, event: 'Battle of Kappel: Reformer Zwingli killed', eventDE: 'Schlacht bei Kappel: Reformator Zwingli stirbt' },
  '10-16': { year: 1949, event: 'CERN founded in Geneva', eventDE: 'CERN in Genf gegründet' },
  '11-7': { year: 1315, event: 'Battle of Morgarten: Swiss defeat Habsburg army', eventDE: 'Schlacht am Morgarten: Schweizer besiegen habsburgisches Heer' },
  '11-24': { year: 1815, event: 'Switzerland declares permanent neutrality', eventDE: 'Die Schweiz erklärt dauernde Neutralität' },
  '12-6': { year: 1992, event: 'Swiss voters reject joining European Economic Area (EEA)', eventDE: 'Schweizer Stimmbürger lehnen EWR-Beitritt ab' },
  '12-12': { year: 1602, event: 'Escalade: Geneva repels Savoyard attack', eventDE: 'Escalade: Genf wehrt savoyischen Angriff ab' },
  '12-25': { year: 1941, event: "General Guisan's famous Rütli Report during WWII", eventDE: 'General Guisans berühmter Rütlirapport während des 2. Weltkriegs' }
};

const FALLBACKS = [
  { year: 1291, event: 'The Swiss Confederation was founded, beginning 700+ years of independence', eventDE: 'Die Schweizerische Eidgenossenschaft wurde gegründet' },
  { year: 1815, event: 'Congress of Vienna recognized Swiss neutrality', eventDE: 'Wiener Kongress anerkennt Schweizer Neutralität' },
  { year: 1848, event: 'Switzerland became a federal state with a new constitution', eventDE: 'Die Schweiz wurde ein Bundesstaat mit neuer Verfassung' },
  { year: 1971, event: 'Swiss women finally gained the right to vote', eventDE: 'Schweizer Frauen erhielten endlich das Stimmrecht' }
];

export function getThisDayInHistory() {
  const today = new Date();
  const key = `${today.getMonth() + 1}-${today.getDate()}`;
  return HISTORY[key] || FALLBACKS[today.getDate() % FALLBACKS.length];
}
