/**
 * Cities, holidays, history — static data shared across modules.
 */

export const VERSION = '2.1.0';

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

/* ── School Holidays (Zürich 2026) ── */

const SCHOOL_HOLIDAYS_2026 = [
  { name: 'Sport/Ski Week', nameDE: 'Sportferien', startDate: '2026-02-09', endDate: '2026-02-20' },
  { name: 'Easter', nameDE: 'Osterferien', startDate: '2026-04-02', endDate: '2026-04-06' },
  { name: 'Spring', nameDE: 'Frühlingsferien', startDate: '2026-04-20', endDate: '2026-05-01' },
  { name: 'Ascension', nameDE: 'Auffahrtsferien', startDate: '2026-05-14', endDate: '2026-05-15' },
  { name: 'Summer', nameDE: 'Sommerferien', startDate: '2026-07-13', endDate: '2026-08-14' },
  { name: 'Autumn', nameDE: 'Herbstferien', startDate: '2026-10-05', endDate: '2026-10-16' },
  { name: 'Christmas', nameDE: 'Weihnachtsferien', startDate: '2026-12-21', endDate: '2027-01-01' },
];

export function getSchoolHolidays() {
  return SCHOOL_HOLIDAYS_2026.map(h => ({ ...h, type: 'schoolHoliday' }));
}

/* ── This Day in History ── */

const HISTORY = {
  '1-1': { year: 1291, event: 'Traditional date of Swiss Confederation founding (Federal Charter)', eventDE: 'Traditionelles Datum der Gründung der Eidgenossenschaft' },
  '1-2': { year: 1946, event: 'First Swiss television broadcast from Zurich', eventDE: 'Erste Schweizer Fernsehübertragung aus Zürich' },
  '1-3': { year: 1833, event: 'Basel splits into Basel-Stadt and Basel-Landschaft', eventDE: 'Basel teilt sich in Basel-Stadt und Basel-Landschaft' },
  '1-4': { year: 1798, event: 'Vaud declares independence from Bern', eventDE: 'Waadt erklärt Unabhängigkeit von Bern' },
  '1-5': { year: 1477, event: 'Nancy: Swiss mercenaries defeat Charles the Bold', eventDE: 'Nancy: Schweizer Söldner besiegen Karl den Kühnen' },
  '1-6': { year: 1912, event: 'Alfred Wegener presents continental drift theory in Frankfurt', eventDE: 'Alfred Wegener präsentiert die Kontinentaldrift-Theorie' },
  '1-7': { year: 1610, event: 'Galileo observes Jupiter moons with Swiss-made lenses', eventDE: 'Galileo beobachtet Jupitermonde mit Schweizer Linsen' },
  '1-8': { year: 1800, event: 'Founding of the Helvetic Republic Parliament in Bern', eventDE: 'Gründung des Helvetischen Parlaments in Bern' },
  '1-9': { year: 1488, event: 'Swabian League formed, threatening Swiss independence', eventDE: 'Schwäbischer Bund gegründet, bedroht Schweizer Unabhängigkeit' },
  '1-10': { year: 1920, event: 'Switzerland joins the League of Nations', eventDE: 'Die Schweiz tritt dem Völkerbund bei' },
  '1-11': { year: 1693, event: 'Birth of naturalist Johann Jakob Scheuchzer in Zürich', eventDE: 'Geburt des Naturforschers Johann Jakob Scheuchzer in Zürich' },
  '1-12': { year: 1528, event: 'Bern adopts Protestant Reformation', eventDE: 'Bern führt die protestantische Reformation ein' },
  '1-13': { year: 1874, event: 'Swiss telegraph network reaches all cantons', eventDE: 'Schweizer Telegrafennetz erreicht alle Kantone' },
  '1-14': { year: 1814, event: 'Treaty of Kiel affects Swiss diplomacy across Europe', eventDE: 'Kieler Vertrag beeinflusst Schweizer Diplomatie' },
  '1-15': { year: 1831, event: 'Canton Thurgau adopts liberal constitution', eventDE: 'Kanton Thurgau nimmt liberale Verfassung an' },
  '1-16': { year: 1891, event: 'Birth of artist Alberto Giacometti in Borgonovo', eventDE: 'Geburt des Künstlers Alberto Giacometti in Borgonovo' },
  '1-17': { year: 1706, event: 'Birth of Benjamin Franklin — later US envoy to Swiss allies', eventDE: 'Geburt von Benjamin Franklin — später US-Gesandter bei Schweizer Verbündeten' },
  '1-18': { year: 1871, event: 'Bourbaki Army crosses into Switzerland seeking refuge', eventDE: 'Bourbaki-Armee überquert Grenze in die Schweiz' },
  '1-19': { year: 1795, event: 'Helvetic Republic: Revolutionary committees form across cantons', eventDE: 'Helvetische Republik: Revolutionskomitees in den Kantonen' },
  '1-20': { year: 1942, event: 'Wannsee Conference; Switzerland tightens refugee borders', eventDE: 'Wannseekonferenz; Schweiz verschärft Flüchtlingspolitik' },
  '1-21': { year: 1525, event: 'Zürich Council holds first disputation on Anabaptism', eventDE: 'Zürcher Rat hält erste Disputation über Täufertum' },
  '1-22': { year: 1506, event: 'Swiss Guard arrives in Vatican to protect the Pope', eventDE: 'Schweizergarde trifft im Vatikan ein zum Schutz des Papstes' },
  '1-23': { year: 1719, event: 'Principality of Liechtenstein created (Swiss neighbor)', eventDE: 'Fürstentum Liechtenstein gegründet (Schweizer Nachbar)' },
  '1-24': { year: 1848, event: 'Gold discovered in California — Swiss emigrant Johann Sutter\'s land', eventDE: 'Gold in Kalifornien entdeckt — auf Land des Schweizers Johann Sutter' },
  '1-25': { year: 1554, event: 'Founding of São Paulo by Swiss Jesuit José de Anchieta', eventDE: 'Gründung von São Paulo unter Beteiligung Schweizer Jesuiten' },
  '1-26': { year: 1788, event: 'First European settlers arrive in Australia, incl. Swiss', eventDE: 'Erste europäische Siedler in Australien, darunter Schweizer' },
  '1-27': { year: 1945, event: 'Auschwitz liberated; Swiss Red Cross aided survivors', eventDE: 'Auschwitz befreit; Schweizer Rotes Kreuz unterstützt Überlebende' },
  '1-28': { year: 1613, event: 'Galileo letters reach Swiss scholars spreading heliocentrism', eventDE: 'Galileos Briefe erreichen Schweizer Gelehrte' },
  '1-29': { year: 1863, event: 'Birth of painter Ferdinand Hodler\'s artistic career begins', eventDE: 'Beginn der Karriere des Malers Ferdinand Hodler' },
  '1-30': { year: 1661, event: 'Zürich mint produces new Taler coins', eventDE: 'Zürcher Münze prägt neue Taler-Münzen' },
  '1-31': { year: 1798, event: 'Lemanic Republic proclaimed in western Switzerland', eventDE: 'Lemanische Republik in der Westschweiz ausgerufen' },
  '2-1': { year: 2003, event: 'Swiss astronaut Claude Nicollier completes final space mission', eventDE: 'Schweizer Astronaut Claude Nicollier beendet letzte Weltraummission' },
  '2-2': { year: 1536, event: 'Bern conquers Vaud from Savoy', eventDE: 'Bern erobert die Waadt von Savoyen' },
  '2-3': { year: 1958, event: 'Benelux Treaty signed; Swiss trade talks follow', eventDE: 'Benelux-Vertrag unterzeichnet; Schweizer Handelsgespräche folgen' },
  '2-4': { year: 1927, event: 'First Swiss Alpine ski championships held in St. Moritz', eventDE: 'Erste Schweizer Alpin-Skimeisterschaften in St. Moritz' },
  '2-5': { year: 1958, event: 'Swiss voters reject women\'s suffrage (finally granted 1971)', eventDE: 'Schweizer Stimmbürger lehnen Frauenstimmrecht ab (1971 eingeführt)' },
  '2-6': { year: 1918, event: 'Proportional representation introduced for Swiss elections', eventDE: 'Proporzwahlrecht für Schweizer Wahlen eingeführt' },
  '2-7': { year: 1971, event: 'Swiss women gain the right to vote at federal level', eventDE: 'Schweizer Frauen erhalten das Stimmrecht auf Bundesebene' },
  '2-8': { year: 1863, event: 'Henry Dunant publishes "A Memory of Solferino" in Geneva', eventDE: 'Henry Dunant veröffentlicht «Eine Erinnerung an Solferino» in Genf' },
  '2-9': { year: 1996, event: 'Swiss banks agree to search for dormant Holocaust-era accounts', eventDE: 'Schweizer Banken suchen nach nachrichtenlosen Holocaust-Konten' },
  '2-10': { year: 1798, event: 'Canton of Léman established under French influence', eventDE: 'Kanton Léman unter französischem Einfluss gegründet' },
  '2-11': { year: 1531, event: 'Zwingli organizes Christian Civic Union in Zürich', eventDE: 'Zwingli gründet Christliches Burgrecht in Zürich' },
  '2-12': { year: 1809, event: 'Birth of Charles Darwin; Swiss naturalists advance his theories', eventDE: 'Geburt von Charles Darwin; Schweizer Naturforscher fördern seine Theorien' },
  '2-13': { year: 1856, event: 'Start of Neuenburg crisis: Prussia claims Neuchâtel', eventDE: 'Beginn der Neuenburger Krise: Preussen beansprucht Neuenburg' },
  '2-14': { year: 1349, event: 'Basel massacre: 600 Jews killed during Black Death persecution', eventDE: 'Basler Judenverfolgung während der Pest' },
  '2-15': { year: 1798, event: 'French troops occupy Bern ending the Old Regime', eventDE: 'Französische Truppen besetzen Bern und beenden das Ancien Régime' },
  '2-16': { year: 1874, event: 'Swiss Federal Council proposes total revision of constitution', eventDE: 'Bundesrat schlägt Totalrevision der Verfassung vor' },
  '2-17': { year: 1934, event: 'Death of King Albert I; Swiss mountaineering community mourns', eventDE: 'Tod von König Albert I; Schweizer Bergsteiger trauern' },
  '2-18': { year: 1861, event: 'First Swiss federal census conducted', eventDE: 'Erste eidgenössische Volkszählung durchgeführt' },
  '2-19': { year: 1803, event: 'Napoleon\'s Act of Mediation creates Swiss Confederation of 19 cantons', eventDE: 'Napoleons Mediationsakte schafft die Schweizerische Eidgenossenschaft mit 19 Kantonen' },
  '2-20': { year: 1947, event: 'Swiss National Bank introduces new banknote series', eventDE: 'Schweizerische Nationalbank führt neue Banknotenserie ein' },
  '2-21': { year: 1513, event: 'Pope Julius II dies; Swiss Guard had protected him in battle', eventDE: 'Papst Julius II. stirbt; Schweizergarde hatte ihn in der Schlacht beschützt' },
  '2-22': { year: 1857, event: 'Birth of Robert Baden-Powell; Swiss scouting follows', eventDE: 'Geburt von Robert Baden-Powell; Schweizer Pfadfinderbewegung folgt' },
  '2-23': { year: 1798, event: 'Helvetic Republic constitution drafted under French pressure', eventDE: 'Verfassung der Helvetischen Republik unter französischem Druck entworfen' },
  '2-24': { year: 1848, event: 'February Revolution in Paris; Swiss radicals take inspiration', eventDE: 'Februarrevolution in Paris; Schweizer Radikale lassen sich inspirieren' },
  '2-25': { year: 1803, event: 'Imperial Recess: Swiss territories reorganized', eventDE: 'Reichsdeputationshauptschluss: Schweizer Gebiete neu geordnet' },
  '2-26': { year: 1815, event: 'Napoleon escapes Elba; Swiss neutrality tested again', eventDE: 'Napoleon flieht von Elba; Schweizer Neutralität erneut geprüft' },
  '2-27': { year: 1881, event: 'Bourbaki Panorama painting unveiled in Lucerne', eventDE: 'Bourbaki-Panorama in Luzern enthüllt' },
  '2-28': { year: 1446, event: 'Old Zürich War ends with peace agreement', eventDE: 'Alter Zürichkrieg endet mit Friedensabkommen' },
  '2-29': { year: 1956, event: 'Switzerland introduces leap year postal stamp series', eventDE: 'Schweiz führt Schaltjahr-Briefmarkenserie ein' },
  '3-1': { year: 1848, event: 'Swiss Federal Constitution adopted, creating modern Switzerland', eventDE: 'Annahme der Bundesverfassung, Gründung der modernen Schweiz' },
  '3-2': { year: 1476, event: 'Grandson: Swiss defeat Charles the Bold of Burgundy', eventDE: 'Grandson: Schweizer besiegen Karl den Kühnen von Burgund' },
  '3-3': { year: 1847, event: 'Birth of Alexander Graham Bell; Swiss telephone network follows', eventDE: 'Geburt von Alexander Graham Bell; Schweizer Telefonnetz folgt' },
  '3-4': { year: 1798, event: 'Battle of Fraubrunnen: Bernese resist French invasion', eventDE: 'Schlacht bei Fraubrunnen: Berner leisten Widerstand gegen Franzosen' },
  '3-5': { year: 1798, event: 'French forces enter Bern; city treasury looted', eventDE: 'Französische Truppen besetzen Bern; Staatsschatz geplündert' },
  '3-6': { year: 1353, event: 'Bern joins the Swiss Confederation as eighth canton', eventDE: 'Bern tritt als achter Kanton der Eidgenossenschaft bei' },
  '3-7': { year: 1875, event: 'Birth of Maurice Ravel; inspired by Swiss landscapes', eventDE: 'Geburt von Maurice Ravel; inspiriert von Schweizer Landschaften' },
  '3-8': { year: 1969, event: 'First Women\'s Day march in Bern for suffrage', eventDE: 'Erster Frauenstreik-Marsch in Bern für das Stimmrecht' },
  '3-9': { year: 1798, event: 'Helvetic Republic formally proclaimed', eventDE: 'Helvetische Republik offiziell ausgerufen' },
  '3-10': { year: 1922, event: 'Swiss aviation pioneer Walter Mittelholzer flies over Alps', eventDE: 'Schweizer Flugpionier Walter Mittelholzer überfliegt die Alpen' },
  '3-11': { year: 1882, event: 'Gotthard rail tunnel construction continues after breakthroughs', eventDE: 'Bau des Gotthard-Eisenbahntunnels nach Durchbrüchen fortgesetzt' },
  '3-12': { year: 1999, event: 'Czech Republic, Hungary, Poland join NATO; Swiss neutrality debated', eventDE: 'Tschechien, Ungarn, Polen treten NATO bei; Schweizer Neutralität debattiert' },
  '3-13': { year: 1522, event: 'Zwingli\'s sausage-eating protest starts Zürich Reformation', eventDE: 'Zwinglis Wurstessen leitet Zürcher Reformation ein' },
  '3-14': { year: 1879, event: 'Birth of Albert Einstein in Ulm; later studies in Zürich', eventDE: 'Geburt von Albert Einstein in Ulm; studiert später in Zürich' },
  '3-15': { year: 1939, event: 'Germany occupies Czechoslovakia; Switzerland mobilizes border troops', eventDE: 'Deutschland besetzt Tschechoslowakei; Schweiz mobilisiert Grenztruppen' },
  '3-16': { year: 1798, event: 'French invasion ends the Old Swiss Confederacy', eventDE: 'Französische Invasion beendet die Alte Eidgenossenschaft' },
  '3-17': { year: 1969, event: 'Golda Meir becomes Israeli PM; Swiss-Israeli relations evolve', eventDE: 'Golda Meir wird israelische PM; Schweizer-israelische Beziehungen entwickeln sich' },
  '3-18': { year: 1871, event: 'Paris Commune; Swiss citizens in France seek consular help', eventDE: 'Pariser Kommune; Schweizer Bürger in Frankreich suchen konsularische Hilfe' },
  '3-19': { year: 1563, event: 'Council of Trent ends; Swiss Catholic cantons implement reforms', eventDE: 'Konzil von Trient endet; Schweizer katholische Kantone setzen Reformen um' },
  '3-20': { year: 1815, event: 'Congress of Vienna: Switzerland\'s borders redrawn', eventDE: 'Wiener Kongress: Schweizer Grenzen neu gezogen' },
  '3-21': { year: 1804, event: 'Napoleonic Code introduced; influences Swiss civil law', eventDE: 'Code Napoléon eingeführt; beeinflusst Schweizer Zivilrecht' },
  '3-22': { year: 1312, event: 'Abolition of Knights Templar; Swiss lands redistributed', eventDE: 'Auflösung der Tempelritter; Schweizer Ländereien umverteilt' },
  '3-23': { year: 1839, event: 'Züriputsch: conservative uprising overthrows Zürich liberals', eventDE: 'Züriputsch: konservativer Aufstand stürzt Zürcher Liberale' },
  '3-24': { year: 1882, event: 'Robert Koch announces discovery of tuberculosis bacillus; Swiss sanatoriums affected', eventDE: 'Robert Koch entdeckt Tuberkulose-Bazillus; Schweizer Sanatorien betroffen' },
  '3-25': { year: 1957, event: 'Treaty of Rome signed; Switzerland chooses EFTA over EEC', eventDE: 'Römische Verträge unterzeichnet; Schweiz wählt EFTA statt EWG' },
  '3-26': { year: 1484, event: 'Birth of Reformer Huldrych Zwingli in Wildhaus', eventDE: 'Geburt des Reformators Huldrych Zwingli in Wildhaus' },
  '3-27': { year: 1528, event: 'Bern forces Reformation on subject territories', eventDE: 'Bern erzwingt Reformation in Untertanengebieten' },
  '3-28': { year: 1460, event: 'University of Basel founded, oldest in Switzerland', eventDE: 'Universität Basel gegründet, älteste der Schweiz' },
  '3-29': { year: 1798, event: 'Canton Schwyz resists Helvetic Republic', eventDE: 'Kanton Schwyz leistet Widerstand gegen Helvetische Republik' },
  '3-30': { year: 1885, event: 'Swiss Patent Office opens; Einstein later works there', eventDE: 'Schweizer Patentamt eröffnet; Einstein arbeitet dort später' },
  '3-31': { year: 1946, event: 'First regular Swiss air service Zürich-London by Swissair', eventDE: 'Erster regulärer Swissair-Flug Zürich-London' },
  '4-1': { year: 1934, event: 'Swiss Banking Act enacted, codifying bank secrecy', eventDE: 'Schweizer Bankengesetz verabschiedet, Bankgeheimnis kodifiziert' },
  '4-2': { year: 1917, event: 'Lenin departs Switzerland through Germany to Russia', eventDE: 'Lenin verlässt die Schweiz durch Deutschland nach Russland' },
  '4-3': { year: 1959, event: 'First stretch of Swiss national motorway opens near Lucerne', eventDE: 'Erster Schweizer Autobahnabschnitt bei Luzern eröffnet' },
  '4-4': { year: 1949, event: 'NATO founded; Switzerland reaffirms neutrality', eventDE: 'NATO gegründet; Schweiz bekräftigt Neutralität' },
  '4-5': { year: 1815, event: 'Tambora eruption leads to "Year Without a Summer" in Switzerland', eventDE: 'Tambora-Ausbruch führt zum «Jahr ohne Sommer» in der Schweiz' },
  '4-6': { year: 1654, event: 'Peasant War: Swiss farmers revolt in Canton Bern', eventDE: 'Bauernkrieg: Schweizer Bauern revoltieren im Kanton Bern' },
  '4-7': { year: 1827, event: 'John Walker invents the match; Swiss later dominate production', eventDE: 'John Walker erfindet das Streichholz; Schweiz dominiert später die Produktion' },
  '4-8': { year: 1904, event: 'Swiss-French agreement on border disputes settled', eventDE: 'Schweizer-französisches Grenzabkommen geschlossen' },
  '4-9': { year: 1388, event: 'Battle of Näfels: Glarus defeats Habsburg forces', eventDE: 'Schlacht bei Näfels: Glarus besiegt Habsburger' },
  '4-10': { year: 1912, event: 'RMS Titanic departs; Swiss passengers aboard', eventDE: 'RMS Titanic legt ab; Schweizer Passagiere an Bord' },
  '4-11': { year: 1798, event: 'Canton Nidwalden resists French-imposed Helvetic Republic', eventDE: 'Kanton Nidwalden leistet Widerstand gegen Helvetische Republik' },
  '4-12': { year: 1798, event: 'Helvetic Republic establishes cantonal governments', eventDE: 'Helvetische Republik richtet Kantonalregierungen ein' },
  '4-13': { year: 1501, event: 'Basel and Schaffhausen join the Swiss Confederation', eventDE: 'Basel und Schaffhausen treten der Eidgenossenschaft bei' },
  '4-14': { year: 1865, event: 'Abraham Lincoln shot; Swiss communities in America mourn', eventDE: 'Abraham Lincoln erschossen; Schweizer Gemeinden in Amerika trauern' },
  '4-15': { year: 1874, event: 'First Impressionist exhibition; Swiss artists participate', eventDE: 'Erste Impressionismus-Ausstellung; Schweizer Künstler nehmen teil' },
  '4-16': { year: 1943, event: 'Albert Hofmann discovers LSD effects in Basel', eventDE: 'Albert Hofmann entdeckt LSD-Wirkung in Basel' },
  '4-17': { year: 1961, event: 'Bay of Pigs invasion; Swiss embassy represents US interests in Cuba', eventDE: 'Invasion in der Schweinebucht; Schweizer Botschaft vertritt US-Interessen in Kuba' },
  '4-18': { year: 1506, event: 'Foundation stone of new St. Peter\'s Basilica; Swiss Guard present', eventDE: 'Grundsteinlegung des neuen Petersdoms; Schweizergarde anwesend' },
  '4-19': { year: 1529, event: 'First Kappel War between Protestant and Catholic cantons', eventDE: 'Erster Kappelerkrieg zwischen protestantischen und katholischen Kantonen' },
  '4-20': { year: 1964, event: 'First Swiss National Exhibition in Lausanne (Expo 64) preparations', eventDE: 'Vorbereitungen für die Schweizer Landesausstellung in Lausanne (Expo 64)' },
  '4-21': { year: 1526, event: 'Zurich bans Anabaptist movement, first in Europe', eventDE: 'Zürich verbietet Täuferbewegung, erstmals in Europa' },
  '4-22': { year: 1834, event: 'Seven Articles of Sarnen: Catholic cantons resist liberal reforms', eventDE: 'Sieben Artikel von Sarnen: Katholische Kantone gegen liberale Reformen' },
  '4-23': { year: 1516, event: 'Bavarian Reinheitsgebot; Swiss brewers develop own traditions', eventDE: 'Bayerisches Reinheitsgebot; Schweizer Brauer entwickeln eigene Traditionen' },
  '4-24': { year: 1800, event: 'US Library of Congress founded; later hosts Swiss collections', eventDE: 'US Library of Congress gegründet; beherbergt später Schweizer Sammlungen' },
  '4-25': { year: 1792, event: 'First use of the guillotine; Swiss revolutionaries influenced', eventDE: 'Erste Nutzung der Guillotine; Schweizer Revolutionäre beeinflusst' },
  '4-26': { year: 1986, event: 'Chernobyl disaster; Swiss authorities monitor radiation levels', eventDE: 'Tschernobyl-Katastrophe; Schweizer Behörden überwachen Strahlung' },
  '4-27': { year: 1848, event: 'Slavery abolished in French colonies; Swiss traders affected', eventDE: 'Sklaverei in französischen Kolonien abgeschafft; Schweizer Händler betroffen' },
  '4-28': { year: 1503, event: 'Battle of Cerignola: Swiss mercenaries fight for France', eventDE: 'Schlacht bei Cerignola: Schweizer Söldner kämpfen für Frankreich' },
  '4-29': { year: 1429, event: 'Swiss delegation arrives at Council of Basel', eventDE: 'Schweizer Delegation trifft beim Konzil von Basel ein' },
  '4-30': { year: 1798, event: 'Swiss Confederation officially dissolved by French', eventDE: 'Eidgenossenschaft offiziell von Frankreich aufgelöst' },
  '5-1': { year: 1890, event: 'First May Day celebration in Switzerland', eventDE: 'Erste 1. Mai-Feier in der Schweiz' },
  '5-2': { year: 1889, event: 'Eiffel Tower opens; Swiss engineer contributed to design', eventDE: 'Eiffelturm eröffnet; Schweizer Ingenieur am Bau beteiligt' },
  '5-3': { year: 1815, event: 'Congress of Vienna guarantees Swiss neutrality', eventDE: 'Wiener Kongress garantiert Schweizer Neutralität' },
  '5-4': { year: 1471, event: 'Birth of Albrecht Dürer; later influenced by Swiss artists', eventDE: 'Geburt von Albrecht Dürer; später von Schweizer Künstlern beeinflusst' },
  '5-5': { year: 1798, event: 'Swiss resistance at Stans against Helvetic Republic', eventDE: 'Schweizer Widerstand in Stans gegen Helvetische Republik' },
  '5-6': { year: 1527, event: 'Sack of Rome: Swiss Guard makes heroic last stand', eventDE: 'Sacco di Roma: Schweizergarde leistet heldenhaften letzten Widerstand' },
  '5-7': { year: 1824, event: 'Beethoven\'s 9th premieres; Swiss musicians in attendance', eventDE: 'Beethovens 9. Sinfonie uraufgeführt; Schweizer Musiker anwesend' },
  '5-8': { year: 1945, event: 'VE Day: WWII ends in Europe; Swiss celebrate peace', eventDE: 'Tag der Befreiung: 2. Weltkrieg in Europa endet; Schweiz feiert Frieden' },
  '5-9': { year: 1950, event: 'Schuman Declaration for European Coal and Steel; Swiss EFTA path begins', eventDE: 'Schuman-Erklärung für Kohle und Stahl; Schweizer EFTA-Weg beginnt' },
  '5-10': { year: 1940, event: 'Germany invades Low Countries; Switzerland on full alert', eventDE: 'Deutschland greift Benelux an; Schweiz in voller Alarmbereitschaft' },
  '5-11': { year: 1798, event: 'Canton Uri rebels against Helvetic Republic', eventDE: 'Kanton Uri rebelliert gegen Helvetische Republik' },
  '5-12': { year: 1832, event: 'Siebnerkonkordat: seven liberal cantons form alliance', eventDE: 'Siebnerkonkordat: sieben liberale Kantone bilden Allianz' },
  '5-13': { year: 1888, event: 'Brazil abolishes slavery; Swiss colonists in Brazil affected', eventDE: 'Brasilien schafft Sklaverei ab; Schweizer Kolonisten in Brasilien betroffen' },
  '5-14': { year: 1509, event: 'Battle of Agnadello: Swiss mercenaries fight in Italy', eventDE: 'Schlacht bei Agnadello: Schweizer Söldner kämpfen in Italien' },
  '5-15': { year: 1940, event: 'Swiss Army mobilizes fully as Germany conquers France', eventDE: 'Schweizer Armee voll mobilisiert bei deutscher Eroberung Frankreichs' },
  '5-16': { year: 1920, event: 'Joan of Arc canonized; Swiss pilgrims attend', eventDE: 'Jeanne d\'Arc heiliggesprochen; Schweizer Pilger anwesend' },
  '5-17': { year: 1954, event: 'Brown v. Board ruling in US; Swiss human rights discourse follows', eventDE: 'Brown-v.-Board-Urteil in USA; Schweizer Menschenrechtsdebatte folgt' },
  '5-18': { year: 1804, event: 'Napoleon crowned Emperor; Swiss Act of Mediation continues', eventDE: 'Napoleon zum Kaiser gekrönt; Schweizer Mediationsakte fortgesetzt' },
  '5-19': { year: 1874, event: 'Revised Swiss Federal Constitution approved by referendum', eventDE: 'Revidierte Bundesverfassung per Volksabstimmung angenommen' },
  '5-20': { year: 1802, event: 'First ascent of the Finsteraarhorn, highest Bernese Alps peak', eventDE: 'Erstbesteigung des Finsteraarhorns' },
  '5-21': { year: 1863, event: 'Red Cross precursor meeting in Geneva led by Dunant', eventDE: 'Vorläufertreffen des Roten Kreuzes in Genf unter Dunant' },
  '5-22': { year: 1939, event: 'Pact of Steel signed; Swiss fear encirclement', eventDE: 'Stahlpakt unterzeichnet; Schweiz fürchtet Umzingelung' },
  '5-23': { year: 1618, event: 'Defenestration of Prague starts 30 Years War; Swiss cantons drawn in', eventDE: 'Prager Fenstersturz beginnt 30-jährigen Krieg; Schweizer Kantone verwickelt' },
  '5-24': { year: 1844, event: 'First telegraph message sent; Swiss postal system modernizes', eventDE: 'Erste Telegraphennachricht gesendet; Schweizer Post modernisiert' },
  '5-25': { year: 1935, event: 'Jesse Owens breaks records; Swiss athletes compete alongside', eventDE: 'Jesse Owens bricht Rekorde; Schweizer Athleten treten daneben an' },
  '5-26': { year: 1923, event: 'First 24 Hours of Le Mans; Swiss drivers participate', eventDE: 'Erste 24 Stunden von Le Mans; Schweizer Fahrer nehmen teil' },
  '5-27': { year: 1679, event: 'Habeas Corpus Act in England; Swiss legal scholars study it', eventDE: 'Habeas-Corpus-Akte in England; Schweizer Juristen studieren sie' },
  '5-28': { year: 1858, event: 'Treaty of Aigun; Swiss missionaries in Far East affected', eventDE: 'Vertrag von Aigun; Schweizer Missionare im Fernen Osten betroffen' },
  '5-29': { year: 1453, event: 'Fall of Constantinople; Swiss trade routes shift', eventDE: 'Fall von Konstantinopel; Schweizer Handelsrouten verlagern sich' },
  '5-30': { year: 1431, event: 'Joan of Arc burned; Swiss mercenaries present at Rouen', eventDE: 'Jeanne d\'Arc verbrannt; Schweizer Söldner in Rouen anwesend' },
  '5-31': { year: 1902, event: 'Treaty of Vereeniging ends Boer War; Swiss mediated negotiations', eventDE: 'Vertrag von Vereeniging beendet Burenkrieg; Schweiz vermittelt' },
  '6-1': { year: 2002, event: 'Switzerland joins the United Nations', eventDE: 'Die Schweiz tritt den Vereinten Nationen bei' },
  '6-2': { year: 1559, event: 'John Calvin founds Geneva Academy (later University)', eventDE: 'Johannes Calvin gründet Genfer Akademie (spätere Universität)' },
  '6-3': { year: 1906, event: 'Simplon rail tunnel opens — world\'s longest at the time', eventDE: 'Simplontunnel eröffnet — damals längster der Welt' },
  '6-4': { year: 1989, event: 'Tiananmen Square crackdown; Swiss government condemns violence', eventDE: 'Tiananmen-Massaker; Schweizer Regierung verurteilt Gewalt' },
  '6-5': { year: 1898, event: 'Zurich Tonhalle opens with Richard Strauss conducting', eventDE: 'Tonhalle Zürich eröffnet mit Richard Strauss als Dirigent' },
  '6-6': { year: 1944, event: 'D-Day: Swiss intelligence had tracked German preparations', eventDE: 'D-Day: Schweizer Geheimdienst hatte deutsche Vorbereitungen verfolgt' },
  '6-7': { year: 1494, event: 'Treaty of Tordesillas; Swiss cartographers map new world', eventDE: 'Vertrag von Tordesillas; Schweizer Kartografen kartieren neue Welt' },
  '6-8': { year: 1815, event: 'Act of German Confederation; Swiss borders confirmed', eventDE: 'Deutsche Bundesakte; Schweizer Grenzen bestätigt' },
  '6-9': { year: 1815, event: 'Final Act of Congress of Vienna signed; Swiss neutrality guaranteed', eventDE: 'Schlussakte des Wiener Kongresses unterzeichnet; Schweizer Neutralität garantiert' },
  '6-10': { year: 1692, event: 'Birth of naturalist Albrecht von Haller in Bern', eventDE: 'Geburt des Naturforschers Albrecht von Haller in Bern' },
  '6-11': { year: 1940, event: 'Switzerland surrounded: Italy enters WWII alongside Germany', eventDE: 'Schweiz umzingelt: Italien tritt an Deutschlands Seite in den Krieg' },
  '6-12': { year: 1799, event: 'Battle of Zürich (first): French defend against Allies', eventDE: 'Erste Schlacht bei Zürich: Franzosen verteidigen gegen Alliierte' },
  '6-13': { year: 1917, event: 'Grimm-Hoffmann affair: Swiss diplomat scandal during WWI', eventDE: 'Grimm-Hoffmann-Affäre: Schweizer Diplomatenskandal im 1. Weltkrieg' },
  '6-14': { year: 1536, event: 'Calvin arrives in Geneva and begins his reform mission', eventDE: 'Calvin kommt in Genf an und beginnt seine Reformmission' },
  '6-15': { year: 1389, event: 'Sempach Letter: Swiss cantons agree on rules of warfare', eventDE: 'Sempacherbrief: Schweizer Kantone einigen sich auf Kriegsregeln' },
  '6-16': { year: 1881, event: 'Swiss education law makes primary school free and compulsory', eventDE: 'Schweizer Bildungsgesetz macht Grundschule kostenlos und obligatorisch' },
  '6-17': { year: 1882, event: 'Birth of Igor Stravinsky; later composes in Switzerland', eventDE: 'Geburt von Igor Strawinsky; komponiert später in der Schweiz' },
  '6-18': { year: 1815, event: 'Battle of Waterloo: Swiss regiments fight on both sides', eventDE: 'Schlacht bei Waterloo: Schweizer Regimenter kämpfen auf beiden Seiten' },
  '6-19': { year: 1867, event: 'Emperor Maximilian of Mexico executed; Swiss volunteers affected', eventDE: 'Kaiser Maximilian von Mexiko hingerichtet; Schweizer Freiwillige betroffen' },
  '6-20': { year: 1792, event: 'Tuileries invasion; Swiss Guards prepare to defend French king', eventDE: 'Invasion der Tuilerien; Schweizergardisten bereiten Verteidigung des Königs vor' },
  '6-21': { year: 1908, event: 'Swiss women organize first major suffrage demonstration in Bern', eventDE: 'Schweizer Frauen organisieren erste grosse Wahlrechtsdemo in Bern' },
  '6-22': { year: 1476, event: 'Battle of Morat: Swiss defeat Burgundian army', eventDE: 'Schlacht bei Murten: Schweizer besiegen burgundisches Heer' },
  '6-23': { year: 1865, event: 'Matterhorn summit attempt preparations begin in Zermatt', eventDE: 'Vorbereitungen zur Matterhorn-Besteigung beginnen in Zermatt' },
  '6-24': { year: 1340, event: 'Battle of Sluys; Swiss mercenaries in European conflicts', eventDE: 'Schlacht bei Sluis; Schweizer Söldner in europäischen Konflikten' },
  '6-25': { year: 1950, event: 'Korean War begins; Swiss serve as neutral mediators', eventDE: 'Koreakrieg beginnt; Schweiz dient als neutrale Vermittlerin' },
  '6-26': { year: 1945, event: 'United Nations Charter signed; Swiss observer delegation present', eventDE: 'UNO-Charta unterzeichnet; Schweizer Beobachterdelegation anwesend' },
  '6-27': { year: 1519, event: 'Zwingli begins preaching reform in Zürich\'s Grossmünster', eventDE: 'Zwingli beginnt Reformpredigten im Zürcher Grossmünster' },
  '6-28': { year: 1914, event: 'Assassination of Archduke Franz Ferdinand; Swiss mobilize', eventDE: 'Ermordung von Erzherzog Franz Ferdinand; Schweiz mobilisiert' },
  '6-29': { year: 1888, event: 'First recorded audio in Switzerland — phonograph demonstration', eventDE: 'Erste Tonaufnahme in der Schweiz — Phonograph-Vorführung' },
  '6-30': { year: 1934, event: 'Night of the Long Knives in Germany; Swiss borders tighten', eventDE: 'Nacht der langen Messer in Deutschland; Schweizer Grenzen verschärft' },
  '7-1': { year: 1990, event: 'Appenzell Innerrhoden forced to grant women vote (last canton)', eventDE: 'Appenzell Innerrhoden muss Frauenstimmrecht einführen (letzter Kanton)' },
  '7-2': { year: 1850, event: 'Swiss Federal Post officially established', eventDE: 'Schweizerische Bundespost offiziell gegründet' },
  '7-3': { year: 1866, event: 'Battle of Königgrätz; Swiss remain neutral in Austro-Prussian War', eventDE: 'Schlacht bei Königgrätz; Schweiz bleibt neutral im Deutschen Krieg' },
  '7-4': { year: 1776, event: 'US Independence; Swiss-Americans like Albert Gallatin contribute', eventDE: 'US-Unabhängigkeit; Schweiz-Amerikaner wie Albert Gallatin tragen bei' },
  '7-5': { year: 1950, event: 'Israeli Law of Return; Swiss Jewish communities respond', eventDE: 'Israelisches Rückkehrgesetz; Schweizer jüdische Gemeinden reagieren' },
  '7-6': { year: 1809, event: 'Napoleon abolishes Papal States; Swiss Guard disbanded temporarily', eventDE: 'Napoleon löst Kirchenstaat auf; Schweizergarde vorübergehend aufgelöst' },
  '7-7': { year: 1798, event: 'Swiss Confederation under Helvetic Republic holds elections', eventDE: 'Eidgenossenschaft unter Helvetischer Republik hält Wahlen ab' },
  '7-8': { year: 1497, event: 'Vasco da Gama reaches India; Swiss traders benefit from new routes', eventDE: 'Vasco da Gama erreicht Indien; Schweizer Händler profitieren' },
  '7-9': { year: 1386, event: 'Battle of Sempach: Swiss defeat Habsburg Duke Leopold III', eventDE: 'Schlacht bei Sempach: Schweizer besiegen Habsburg-Herzog Leopold III.' },
  '7-10': { year: 1509, event: 'John Calvin born in France; later transforms Geneva', eventDE: 'Johannes Calvin in Frankreich geboren; verwandelt später Genf' },
  '7-11': { year: 1907, event: 'Hague Convention on laws of war; Swiss delegation participates', eventDE: 'Haager Konvention zum Kriegsrecht; Schweizer Delegation nimmt teil' },
  '7-12': { year: 1906, event: 'Alfred Dreyfus rehabilitated; Swiss press covered the affair', eventDE: 'Alfred Dreyfus rehabilitiert; Schweizer Presse berichtete' },
  '7-13': { year: 1870, event: 'Ems Dispatch: Franco-Prussian War begins; Swiss mobilize border', eventDE: 'Emser Depesche: Deutsch-Französischer Krieg beginnt; Schweiz mobilisiert' },
  '7-14': { year: 1865, event: 'Edward Whymper first to summit the Matterhorn', eventDE: 'Edward Whymper besteigt als Erster das Matterhorn' },
  '7-15': { year: 1865, event: 'Matterhorn tragedy: four climbers die on descent', eventDE: 'Matterhorn-Tragödie: vier Bergsteiger sterben beim Abstieg' },
  '7-16': { year: 1465, event: 'Swiss cantons form alliance against Burgundy', eventDE: 'Schweizer Kantone bilden Allianz gegen Burgund' },
  '7-17': { year: 1955, event: 'Disneyland opens; Swiss Family Robinson attraction later added', eventDE: 'Disneyland eröffnet; Swiss Family Robinson-Attraktion später hinzugefügt' },
  '7-18': { year: 1870, event: 'First Vatican Council defines papal infallibility; Swiss Old Catholics split', eventDE: 'Erstes Vatikanisches Konzil definiert Unfehlbarkeit; Schweizer Altkatholiken spalten sich' },
  '7-19': { year: 1553, event: 'Lady Jane Grey deposed; Swiss reformers monitor English Reformation', eventDE: 'Lady Jane Grey abgesetzt; Schweizer Reformatoren beobachten englische Reformation' },
  '7-20': { year: 1969, event: 'Moon landing: Swiss solar wind experiment deployed on lunar surface', eventDE: 'Mondlandung: Schweizer Sonnenwind-Experiment auf dem Mond aufgestellt' },
  '7-21': { year: 1831, event: 'Leopold I becomes King of Belgium; Swiss model of neutrality studied', eventDE: 'Leopold I. wird König von Belgien; Schweizer Neutralitätsmodell studiert' },
  '7-22': { year: 1934, event: 'FBI kills Dillinger; Swiss banking secrecy law passes same year', eventDE: 'FBI tötet Dillinger; Schweizer Bankgeheimnisgesetz im selben Jahr verabschiedet' },
  '7-23': { year: 1847, event: 'Mormon pioneers reach Salt Lake; Swiss emigrants among later settlers', eventDE: 'Mormonenpioniere erreichen Salt Lake; Schweizer Auswanderer unter späteren Siedlern' },
  '7-24': { year: 1938, event: 'First ascent of the Eiger North Face', eventDE: 'Erstbesteigung der Eiger-Nordwand' },
  '7-25': { year: 1940, event: 'General Guisan calls army to Rütli meadow for resistance speech', eventDE: 'General Guisan ruft Armee zur Rütliwiese für Widerstandsrede' },
  '7-26': { year: 1847, event: 'Liberia independent; Switzerland among first to recognize', eventDE: 'Liberia unabhängig; Schweiz unter den ersten Anerkennenden' },
  '7-27': { year: 1794, event: 'Thermidorian Reaction ends Terror; Swiss exiles can return', eventDE: 'Thermidor-Reaktion beendet Terror; Schweizer Exilanten können zurückkehren' },
  '7-28': { year: 1914, event: 'WWI begins: Austria declares war on Serbia; Swiss mobilize 250,000', eventDE: '1. Weltkrieg: Österreich erklärt Serbien Krieg; Schweiz mobilisiert 250\'000' },
  '7-29': { year: 1907, event: 'Baden-Powell founds Scouts; Swiss scouting follows in 1913', eventDE: 'Baden-Powell gründet Pfadfinder; Schweizer Pfadfinder folgen 1913' },
  '7-30': { year: 1419, event: 'First Defenestration of Prague; Hussite Wars impact Swiss cantons', eventDE: 'Erster Prager Fenstersturz; Hussitenkriege beeinflussen Schweizer Kantone' },
  '7-31': { year: 1891, event: 'Swiss Patent Office clerk Albert Einstein begins work in Bern (later)', eventDE: 'Patentamtsangestellter Albert Einstein beginnt Arbeit in Bern (später)' },
  '8-1': { year: 1291, event: 'Swiss National Day: Rütli oath (legendary founding)', eventDE: 'Schweizer Nationalfeiertag: Rütlischwur' },
  '8-2': { year: 1798, event: 'French impose new constitution on Helvetic Republic', eventDE: 'Frankreich erzwingt neue Verfassung für Helvetische Republik' },
  '8-3': { year: 1914, event: 'Germany invades Belgium; Swiss Army on full war footing', eventDE: 'Deutschland marschiert in Belgien ein; Schweizer Armee in voller Kriegsbereitschaft' },
  '8-4': { year: 1578, event: 'Battle of Alcácer Quibir: Swiss mercenaries among combatants', eventDE: 'Schlacht von Alcácer-Quibir: Schweizer Söldner unter Kämpfern' },
  '8-5': { year: 1912, event: 'Birth of Abbé Pierre; later works with Swiss charities', eventDE: 'Geburt von Abbé Pierre; arbeitet später mit Schweizer Hilfswerken' },
  '8-6': { year: 1945, event: 'Hiroshima bombed; Swiss Red Cross assists survivors', eventDE: 'Hiroshima bombardiert; Schweizer Rotes Kreuz unterstützt Überlebende' },
  '8-7': { year: 1990, event: 'Gulf War begins; Swiss provide humanitarian aid', eventDE: 'Golfkrieg beginnt; Schweiz leistet humanitäre Hilfe' },
  '8-8': { year: 1847, event: 'Ten-Hour Act in Britain; Swiss labor reforms follow', eventDE: 'Zehn-Stunden-Gesetz in Grossbritannien; Schweizer Arbeitsreformen folgen' },
  '8-9': { year: 1945, event: 'Nagasaki bombed; Swiss diplomats aid in peace negotiations', eventDE: 'Nagasaki bombardiert; Schweizer Diplomaten helfen bei Friedensverhandlungen' },
  '8-10': { year: 1792, event: 'Swiss Guards massacred defending Tuileries Palace in Paris', eventDE: 'Schweizergardisten beim Schutz der Tuilerien in Paris massakriert' },
  '8-11': { year: 1891, event: 'First August 1st celebration as official Swiss National Day', eventDE: 'Erste offizielle Feier des 1. August als Nationalfeiertag' },
  '8-12': { year: 1898, event: 'Peace protocol ends Spanish-American War; Swiss observers present', eventDE: 'Friedensprotokoll beendet Spanisch-Amerikanischen Krieg; Schweizer Beobachter' },
  '8-13': { year: 1889, event: 'Birth of filmmaker Alfred Hitchcock; later films Swiss landscapes', eventDE: 'Geburt des Filmemachers Alfred Hitchcock; dreht später in Schweizer Landschaften' },
  '8-14': { year: 1385, event: 'Canton Lucerne signs pact with Swiss Confederation', eventDE: 'Kanton Luzern unterzeichnet Pakt mit der Eidgenossenschaft' },
  '8-15': { year: 1516, event: 'Treaty of Fribourg: "Eternal Peace" between France and Switzerland', eventDE: 'Ewiger Friede von Freiburg zwischen Frankreich und der Schweiz' },
  '8-16': { year: 1812, event: 'Battle of Smolensk: Swiss regiments serve in Napoleon\'s army', eventDE: 'Schlacht bei Smolensk: Schweizer Regimenter in Napoleons Armee' },
  '8-17': { year: 1798, event: 'Nidwalden uprising against French occupation', eventDE: 'Nidwaldner Aufstand gegen französische Besatzung' },
  '8-18': { year: 1891, event: 'First Swiss 1 August celebration held nationwide', eventDE: 'Erste schweizweite 1.-August-Feier durchgeführt' },
  '8-19': { year: 1493, event: 'Maximilian I and Swiss Confederation sign peace after Swabian War', eventDE: 'Maximilian I. und Eidgenossenschaft schliessen Frieden nach Schwabenkrieg' },
  '8-20': { year: 1866, event: 'End of Austro-Prussian War; Swiss neutrality preserved', eventDE: 'Ende des Deutschen Krieges; Schweizer Neutralität bewahrt' },
  '8-21': { year: 1911, event: 'Mona Lisa stolen from Louvre; Swiss border alerts issued', eventDE: 'Mona Lisa aus Louvre gestohlen; Schweizer Grenzalarme ausgelöst' },
  '8-22': { year: 1864, event: 'First Geneva Convention signed — birth of modern humanitarian law', eventDE: 'Erste Genfer Konvention unterzeichnet — Geburt des humanitären Völkerrechts' },
  '8-23': { year: 1839, event: 'Britain takes Hong Kong; Swiss trading houses open branches', eventDE: 'Grossbritannien nimmt Hongkong; Schweizer Handelshäuser eröffnen Filialen' },
  '8-24': { year: 1572, event: 'St. Bartholomew\'s Massacre: Huguenots flee to Swiss cantons', eventDE: 'Bartholomäusnacht: Hugenotten fliehen in Schweizer Kantone' },
  '8-25': { year: 1609, event: 'Galileo demonstrates telescope; Swiss astronomers adopt it', eventDE: 'Galileo demonstriert Teleskop; Schweizer Astronomen übernehmen es' },
  '8-26': { year: 1789, event: 'Declaration of Rights of Man; Swiss revolutionaries inspired', eventDE: 'Erklärung der Menschenrechte; Schweizer Revolutionäre inspiriert' },
  '8-27': { year: 1896, event: 'Anglo-Zanzibar War (38 minutes); Swiss press reports', eventDE: 'Britisch-sansibarischer Krieg (38 Minuten); Schweizer Presse berichtet' },
  '8-28': { year: 1963, event: 'Martin Luther King "I Have a Dream" speech; Swiss civil rights response', eventDE: 'Martin Luther Kings Rede «I Have a Dream»; Schweizer Reaktion' },
  '8-29': { year: 1897, event: 'First Zionist Congress in Basel led by Theodor Herzl', eventDE: 'Erster Zionistenkongress in Basel unter Theodor Herzl' },
  '8-30': { year: 1898, event: 'Empress Elisabeth of Austria assassinated in Geneva', eventDE: 'Kaiserin Elisabeth von Österreich in Genf ermordet' },
  '8-31': { year: 1907, event: 'Anglo-Russian Convention; Swiss neutral role in Great Game diplomacy', eventDE: 'Britisch-russische Konvention; Schweizer Neutralität in Grossmachtdiplomatie' },
  '9-1': { year: 1939, event: 'WWII begins: Germany invades Poland; Swiss general mobilization', eventDE: '2. Weltkrieg: Deutschland überfällt Polen; Schweizer Generalmobilmachung' },
  '9-2': { year: 1798, event: 'Swiss resistance at Stans against French troops', eventDE: 'Schweizer Widerstand in Stans gegen französische Truppen' },
  '9-3': { year: 1939, event: 'Britain and France declare war on Germany; Swiss reinforce borders', eventDE: 'Grossbritannien und Frankreich erklären Deutschland Krieg; Schweiz verstärkt Grenzen' },
  '9-4': { year: 1798, event: 'Helvetic Republic faces internal revolts in central Switzerland', eventDE: 'Helvetische Republik erlebt Aufstände in der Zentralschweiz' },
  '9-5': { year: 1798, event: 'Canton Glarus resists Helvetic Republic reforms', eventDE: 'Kanton Glarus wehrt sich gegen Reformen der Helvetischen Republik' },
  '9-6': { year: 1522, event: 'Magellan\'s ship returns; Swiss merchants invest in trade routes', eventDE: 'Magellans Schiff kehrt zurück; Schweizer Kaufleute investieren in Handelsrouten' },
  '9-7': { year: 1860, event: 'Giuseppe Garibaldi unites Italy; Swiss-Italian border changes', eventDE: 'Giuseppe Garibaldi eint Italien; Schweizer-italienische Grenze ändert sich' },
  '9-8': { year: 1855, event: 'Sevastopol falls in Crimean War; Swiss humanitarian aid sent', eventDE: 'Sewastopol fällt im Krimkrieg; Schweiz sendet humanitäre Hilfe' },
  '9-9': { year: 1776, event: 'Continental Congress names "United States"; Swiss envoys take note', eventDE: 'Kontinentalkongress benennt «United States»; Schweizer Gesandte nehmen Kenntnis' },
  '9-10': { year: 1515, event: 'Battle of Marignano: Swiss defeated by French, ending expansion', eventDE: 'Schlacht bei Marignano: Schweizer von Franzosen besiegt, Ende der Expansion' },
  '9-11': { year: 1709, event: 'Battle of Malplaquet: Swiss mercenaries on both sides', eventDE: 'Schlacht bei Malplaquet: Schweizer Söldner auf beiden Seiten' },
  '9-12': { year: 1848, event: 'New Federal Constitution comes into force', eventDE: 'Neue Bundesverfassung tritt in Kraft' },
  '9-13': { year: 1515, event: 'Second day of Marignano: Swiss withdrawal from Italy begins', eventDE: 'Zweiter Tag von Marignano: Schweizer Rückzug aus Italien beginnt' },
  '9-14': { year: 1321, event: 'Death of Dante Alighieri; Swiss scholars preserve his works', eventDE: 'Tod von Dante Alighieri; Schweizer Gelehrte bewahren seine Werke' },
  '9-15': { year: 1830, event: 'Liverpool-Manchester railway opens; Swiss rail plans follow', eventDE: 'Eisenbahn Liverpool-Manchester eröffnet; Schweizer Bahnpläne folgen' },
  '9-16': { year: 1620, event: 'Mayflower departs; Swiss emigrants follow to New World', eventDE: 'Mayflower sticht in See; Schweizer Auswanderer folgen in die Neue Welt' },
  '9-17': { year: 1978, event: 'Camp David Accords; Swiss diplomatic model cited', eventDE: 'Camp-David-Abkommen; Schweizer Diplomatie-Modell als Vorbild' },
  '9-18': { year: 1947, event: 'CIA established; Swiss intelligence maintains cooperation', eventDE: 'CIA gegründet; Schweizer Nachrichtendienst pflegt Zusammenarbeit' },
  '9-19': { year: 1946, event: 'Winston Churchill\'s "Europe" speech; Swiss integration debated', eventDE: 'Winston Churchills Europa-Rede; Schweizer Integration debattiert' },
  '9-20': { year: 1519, event: 'Magellan departs Spain; Swiss cartographers advance world maps', eventDE: 'Magellan verlässt Spanien; Schweizer Kartografen erweitern Weltkarten' },
  '9-21': { year: 1937, event: 'Tolkien publishes The Hobbit; Swiss landscapes inspired his work', eventDE: 'Tolkien veröffentlicht «Der Hobbit»; Schweizer Landschaften inspirierten ihn' },
  '9-22': { year: 1499, event: 'Treaty of Basel: Swiss independence from Holy Roman Empire', eventDE: 'Friede von Basel: Unabhängigkeit vom Heiligen Römischen Reich' },
  '9-23': { year: 1846, event: 'Neptune discovered; Swiss observatories confirm sighting', eventDE: 'Neptun entdeckt; Schweizer Sternwarten bestätigen Sichtung' },
  '9-24': { year: 1799, event: 'Battle of Zürich (second): Masséna defeats Russians and Austrians', eventDE: 'Zweite Schlacht bei Zürich: Masséna besiegt Russen und Österreicher' },
  '9-25': { year: 1799, event: 'Suvorov\'s Swiss campaign: Russian army crosses the Alps', eventDE: 'Suworows Schweizer Feldzug: Russische Armee überquert die Alpen' },
  '9-26': { year: 1815, event: 'Holy Alliance formed; Swiss neutrality internationally recognized', eventDE: 'Heilige Allianz gegründet; Schweizer Neutralität international anerkannt' },
  '9-27': { year: 1529, event: 'First Kappeler Milchsuppe: Protestant and Catholic cantons share meal', eventDE: 'Erste Kappeler Milchsuppe: Protestantische und katholische Kantone teilen Mahlzeit' },
  '9-28': { year: 1864, event: 'First International founded; Swiss workers form unions', eventDE: 'Erste Internationale gegründet; Schweizer Arbeiter bilden Gewerkschaften' },
  '9-29': { year: 1833, event: 'Canton Schwyz split resolved; confederation mediates', eventDE: 'Spaltung des Kantons Schwyz gelöst; Eidgenossenschaft vermittelt' },
  '9-30': { year: 1452, event: 'Gutenberg Bible printed; Swiss monasteries acquire copies', eventDE: 'Gutenberg-Bibel gedruckt; Schweizer Klöster erwerben Exemplare' },
  '10-1': { year: 1847, event: 'Sonderbund crisis: Federal Diet votes to dissolve Catholic alliance', eventDE: 'Sonderbundskrise: Tagsatzung beschliesst Auflösung des katholischen Bündnisses' },
  '10-2': { year: 1869, event: 'Birth of Mahatma Gandhi; Swiss pacifist movement inspired', eventDE: 'Geburt von Mahatma Gandhi; Schweizer Friedensbewegung inspiriert' },
  '10-3': { year: 1990, event: 'German reunification; Swiss banking adapts to new Europe', eventDE: 'Deutsche Wiedervereinigung; Schweizer Bankwesen passt sich an' },
  '10-4': { year: 1957, event: 'Sputnik launched; Swiss scientists contribute to space research', eventDE: 'Sputnik gestartet; Schweizer Wissenschaftler forschen im Weltraum' },
  '10-5': { year: 1798, event: 'Nidwalden final resistance crushed by French troops', eventDE: 'Nidwaldner letzter Widerstand von französischen Truppen gebrochen' },
  '10-6': { year: 1926, event: 'League of Nations Council meets in Geneva', eventDE: 'Völkerbundrat tagt in Genf' },
  '10-7': { year: 1571, event: 'Battle of Lepanto: Swiss mercenaries serve on both fleets', eventDE: 'Schlacht von Lepanto: Schweizer Söldner dienen auf beiden Flotten' },
  '10-8': { year: 1891, event: 'Swiss Confederation celebrates 600th anniversary', eventDE: 'Eidgenossenschaft feiert 600-Jahr-Jubiläum' },
  '10-9': { year: 1874, event: 'Universal Postal Union founded in Bern', eventDE: 'Weltpostverein in Bern gegründet' },
  '10-10': { year: 1531, event: 'Battle of Kappel: Reformer Zwingli killed', eventDE: 'Schlacht bei Kappel: Reformator Zwingli stirbt' },
  '10-11': { year: 1531, event: 'Second Peace of Kappel restores Catholic-Protestant balance', eventDE: 'Zweiter Landfrieden von Kappel stellt konfessionelle Balance wieder her' },
  '10-12': { year: 1492, event: 'Columbus reaches Americas; Swiss mapmakers redraw the world', eventDE: 'Kolumbus erreicht Amerika; Schweizer Kartografen zeichnen Welt neu' },
  '10-13': { year: 1307, event: 'Legendary date of William Tell\'s apple shot', eventDE: 'Legendäres Datum von Wilhelm Tells Apfelschuss' },
  '10-14': { year: 1066, event: 'Battle of Hastings; Swiss mercenary tradition growing in Europe', eventDE: 'Schlacht bei Hastings; Schweizer Söldnertradition wächst in Europa' },
  '10-15': { year: 1917, event: 'Mata Hari executed; Swiss neutrality tested by spy networks', eventDE: 'Mata Hari hingerichtet; Schweizer Neutralität durch Spionagenetzwerke geprüft' },
  '10-16': { year: 1949, event: 'CERN founded in Geneva', eventDE: 'CERN in Genf gegründet' },
  '10-17': { year: 1534, event: 'Affair of the Placards in France; Protestant refugees flee to Geneva', eventDE: 'Plakataffäre in Frankreich; protestantische Flüchtlinge fliehen nach Genf' },
  '10-18': { year: 1685, event: 'Edict of Nantes revoked; Huguenot refugees stream into Switzerland', eventDE: 'Edikt von Nantes widerrufen; hugenottische Flüchtlinge strömen in die Schweiz' },
  '10-19': { year: 1813, event: 'Battle of Leipzig ends; Swiss neutrality holds through Napoleonic Wars', eventDE: 'Völkerschlacht bei Leipzig endet; Schweizer Neutralität hält' },
  '10-20': { year: 2019, event: 'Swiss federal elections: Green parties make historic gains', eventDE: 'Schweizer Bundesratswahlen: Grüne Parteien mit historischen Gewinnen' },
  '10-21': { year: 1879, event: 'Thomas Edison invents practical lightbulb; Swiss cities electrify', eventDE: 'Thomas Edison erfindet Glühbirne; Schweizer Städte elektrifizieren' },
  '10-22': { year: 1797, event: 'First parachute jump by Garnerin; Swiss aviation later pioneers', eventDE: 'Erster Fallschirmsprung von Garnerin; Schweizer Luftfahrt folgt' },
  '10-23': { year: 1648, event: 'Peace of Westphalia: Swiss independence formally recognized', eventDE: 'Westfälischer Friede: Schweizer Unabhängigkeit formell anerkannt' },
  '10-24': { year: 1945, event: 'United Nations founded; Geneva becomes key UN hub', eventDE: 'Vereinte Nationen gegründet; Genf wird wichtiger UNO-Standort' },
  '10-25': { year: 1415, event: 'Battle of Agincourt; Swiss mercenaries increasingly sought in Europe', eventDE: 'Schlacht bei Azincourt; Schweizer Söldner zunehmend in Europa gefragt' },
  '10-26': { year: 1860, event: 'Garibaldi meets Victor Emmanuel; Swiss-Italian border fixed', eventDE: 'Garibaldi trifft Viktor Emanuel; Schweizer-italienische Grenze festgelegt' },
  '10-27': { year: 1553, event: 'Michael Servetus burned in Geneva under Calvin\'s influence', eventDE: 'Michael Servet in Genf unter Calvins Einfluss verbrannt' },
  '10-28': { year: 1886, event: 'Statue of Liberty dedicated; Swiss immigrants in New York celebrate', eventDE: 'Freiheitsstatue eingeweiht; Schweizer Einwanderer in New York feiern' },
  '10-29': { year: 1923, event: 'Turkish Republic proclaimed; Swiss recognize new state', eventDE: 'Türkische Republik ausgerufen; Schweiz anerkennt neuen Staat' },
  '10-30': { year: 1847, event: 'Sonderbund War begins: last civil war in Switzerland', eventDE: 'Sonderbundskrieg beginnt: letzter Bürgerkrieg in der Schweiz' },
  '10-31': { year: 1517, event: 'Luther\'s 95 Theses; Swiss Reformation follows within years', eventDE: 'Luthers 95 Thesen; Schweizer Reformation folgt innerhalb weniger Jahre' },
  '11-1': { year: 1478, event: 'Pazzi conspiracy aftermath; Swiss Guard strengthens Vatican protection', eventDE: 'Folgen der Pazzi-Verschwörung; Schweizergarde verstärkt Vatikanschutz' },
  '11-2': { year: 1847, event: 'Sonderbund War: Federal troops march on Fribourg', eventDE: 'Sonderbundskrieg: Bundestruppen marschieren auf Freiburg' },
  '11-3': { year: 1957, event: 'Laika in space; Swiss satellite research programs follow', eventDE: 'Laika im Weltraum; Schweizer Satellitenforschung folgt' },
  '11-4': { year: 1847, event: 'Sonderbund War: Fribourg surrenders to federal army', eventDE: 'Sonderbundskrieg: Freiburg kapituliert vor der Bundesarmee' },
  '11-5': { year: 1555, event: 'Peace of Augsburg; Swiss confessional borders crystallize', eventDE: 'Augsburger Religionsfrieden; Schweizer Konfessionsgrenzen festigen sich' },
  '11-6': { year: 1632, event: 'Battle of Lützen: Swiss mercenaries fight in Thirty Years War', eventDE: 'Schlacht bei Lützen: Schweizer Söldner im Dreissigjährigen Krieg' },
  '11-7': { year: 1315, event: 'Battle of Morgarten: Swiss defeat Habsburg army', eventDE: 'Schlacht am Morgarten: Schweizer besiegen habsburgisches Heer' },
  '11-8': { year: 1895, event: 'Wilhelm Röntgen discovers X-rays; Swiss hospitals adopt them rapidly', eventDE: 'Wilhelm Röntgen entdeckt Röntgenstrahlen; Schweizer Spitäler übernehmen sie' },
  '11-9': { year: 1989, event: 'Berlin Wall falls; Swiss banking faces new European order', eventDE: 'Berliner Mauer fällt; Schweizer Bankwesen vor neuer europäischer Ordnung' },
  '11-10': { year: 1619, event: 'René Descartes has "stove-heated room" vision; Swiss scholars debate', eventDE: 'René Descartes hat Vision im «ofenbeheizten Zimmer»; Schweizer Gelehrte debattieren' },
  '11-11': { year: 1918, event: 'WWI Armistice: Swiss general strike (Landesstreik) same week', eventDE: 'Waffenstillstand 1. Weltkrieg: Schweizer Generalstreik (Landesstreik) in derselben Woche' },
  '11-12': { year: 1918, event: 'Swiss general strike (Landesstreik) begins: 250,000 workers stop', eventDE: 'Schweizer Landesstreik beginnt: 250\'000 Arbeiter legen Arbeit nieder' },
  '11-13': { year: 1002, event: 'Henry II is King of Germany; grants rights to Swiss monasteries', eventDE: 'Heinrich II. König von Deutschland; gewährt Schweizer Klöstern Rechte' },
  '11-14': { year: 1847, event: 'Sonderbund War: Federal forces enter Lucerne', eventDE: 'Sonderbundskrieg: Bundestruppen betreten Luzern' },
  '11-15': { year: 1315, event: 'Aftermath of Morgarten: Swiss cantons renew their pact', eventDE: 'Nach Morgarten: Schweizer Kantone erneuern ihren Bund' },
  '11-16': { year: 1632, event: 'King Gustavus Adolphus dies; Swiss mercenaries in his army return', eventDE: 'König Gustav Adolf stirbt; Schweizer Söldner in seiner Armee kehren zurück' },
  '11-17': { year: 1869, event: 'Suez Canal opens; Swiss trading firms gain faster routes to Asia', eventDE: 'Suezkanal eröffnet; Schweizer Handelsfirmen gewinnen schnellere Routen nach Asien' },
  '11-18': { year: 1738, event: 'Birth of astronomer Johann Heinrich Lambert in Mulhouse (then Swiss)', eventDE: 'Geburt des Astronomen Johann Heinrich Lambert in Mülhausen (damals Schweiz)' },
  '11-19': { year: 1863, event: 'Gettysburg Address; Swiss-Americans in the Union Army', eventDE: 'Gettysburg-Rede; Schweizer-Amerikaner in der Unionsarmee' },
  '11-20': { year: 1815, event: 'Second Treaty of Paris: Swiss neutrality reconfirmed', eventDE: 'Zweiter Pariser Vertrag: Schweizer Neutralität erneut bestätigt' },
  '11-21': { year: 1847, event: 'Sonderbund War ends: Catholic cantons surrender after 25 days', eventDE: 'Sonderbundskrieg endet: Katholische Kantone kapitulieren nach 25 Tagen' },
  '11-22': { year: 1963, event: 'JFK assassinated; Swiss embassy in Washington responds', eventDE: 'JFK ermordet; Schweizer Botschaft in Washington reagiert' },
  '11-23': { year: 1847, event: 'Sonderbund aftermath: Swiss cantons begin constitutional reform', eventDE: 'Nach dem Sonderbund: Schweizer Kantone beginnen Verfassungsreform' },
  '11-24': { year: 1815, event: 'Switzerland declares permanent neutrality', eventDE: 'Die Schweiz erklärt dauernde Neutralität' },
  '11-25': { year: 1952, event: 'Agatha Christie play "The Mousetrap" premieres; Swiss theater follows', eventDE: 'Agatha Christies «Die Mausefalle» uraufgeführt; Schweizer Theater folgt' },
  '11-26': { year: 1847, event: 'Federal Diet announces amnesty after Sonderbund War', eventDE: 'Tagsatzung verkündet Amnestie nach Sonderbundskrieg' },
  '11-27': { year: 1895, event: 'Alfred Nobel establishes Nobel Prize; Swiss scientists win many', eventDE: 'Alfred Nobel stiftet Nobelpreis; Schweizer Wissenschaftler gewinnen viele' },
  '11-28': { year: 1443, event: 'Old Zürich War escalates; Austrian and Swiss forces clash', eventDE: 'Alter Zürichkrieg eskaliert; österreichische und Schweizer Truppen kämpfen' },
  '11-29': { year: 1516, event: 'Peace of Fribourg confirmed: Swiss stop foreign military service', eventDE: 'Friede von Freiburg bestätigt: Schweiz beendet ausländischen Militärdienst' },
  '11-30': { year: 1939, event: 'Soviet-Finnish Winter War begins; Swiss solidarity with Finland', eventDE: 'Sowjetisch-finnischer Winterkrieg beginnt; Schweizer Solidarität mit Finnland' },
  '12-1': { year: 1959, event: 'Antarctic Treaty signed; Swiss scientists participate in research', eventDE: 'Antarktisvertrag unterzeichnet; Schweizer Wissenschaftler forschen mit' },
  '12-2': { year: 1805, event: 'Battle of Austerlitz; Swiss territories under Napoleonic influence', eventDE: 'Schlacht bei Austerlitz; Schweizer Gebiete unter napoleonischem Einfluss' },
  '12-3': { year: 1966, event: 'Zurich Globus riots prefigure 1968 youth protests', eventDE: 'Zürcher Globuskrawalle nehmen Jugendproteste von 1968 vorweg' },
  '12-4': { year: 1674, event: 'Father Marquette founds mission at Chicago; Swiss missionaries in Americas', eventDE: 'Pater Marquette gründet Mission in Chicago; Schweizer Missionare in Amerika' },
  '12-5': { year: 1766, event: 'Christie\'s auction house founded; Swiss art market thrives', eventDE: 'Auktionshaus Christie\'s gegründet; Schweizer Kunstmarkt floriert' },
  '12-6': { year: 1992, event: 'Swiss voters reject joining European Economic Area (EEA)', eventDE: 'Schweizer Stimmbürger lehnen EWR-Beitritt ab' },
  '12-7': { year: 1941, event: 'Pearl Harbor attack; Switzerland strengthens neutrality stance', eventDE: 'Angriff auf Pearl Harbor; Schweiz stärkt Neutralitätshaltung' },
  '12-8': { year: 1854, event: 'Pope Pius IX declares Immaculate Conception; Swiss Catholic cantons celebrate', eventDE: 'Papst Pius IX. verkündet Unbefleckte Empfängnis; Schweizer Kantone feiern' },
  '12-9': { year: 1531, event: 'Our Lady of Guadalupe; Swiss missionaries spread devotion in Latin America', eventDE: 'Unsere Liebe Frau von Guadalupe; Schweizer Missionare verbreiten Verehrung' },
  '12-10': { year: 1901, event: 'First Nobel Prizes awarded; Henry Dunant (Swiss) wins Peace Prize', eventDE: 'Erste Nobelpreise verliehen; Henry Dunant (Schweizer) erhält Friedenspreis' },
  '12-11': { year: 1868, event: 'Birth of Swiss painter Cuno Amiet in Solothurn', eventDE: 'Geburt des Schweizer Malers Cuno Amiet in Solothurn' },
  '12-12': { year: 1602, event: 'Escalade: Geneva repels Savoyard attack', eventDE: 'Escalade: Genf wehrt savoyischen Angriff ab' },
  '12-13': { year: 1545, event: 'Council of Trent begins; Swiss Catholic reform follows', eventDE: 'Konzil von Trient beginnt; katholische Reform in der Schweiz folgt' },
  '12-14': { year: 1911, event: 'Roald Amundsen reaches South Pole; Swiss flag later planted at base', eventDE: 'Roald Amundsen erreicht Südpol; Schweizer Flagge später an Basis gehisst' },
  '12-15': { year: 1939, event: '"Gone with the Wind" premieres; Swiss cinemas screen it in 1940', eventDE: '«Vom Winde verweht» Premiere; Schweizer Kinos zeigen ihn 1940' },
  '12-16': { year: 1773, event: 'Boston Tea Party; Swiss Enlightenment thinkers approve rebellion', eventDE: 'Boston Tea Party; Schweizer Aufklärungsdenker billigen Rebellion' },
  '12-17': { year: 1903, event: 'Wright Brothers fly; Swiss aviation pioneer Oskar Bider follows in 1913', eventDE: 'Gebrüder Wright fliegen; Schweizer Flugpionier Oskar Bider folgt 1913' },
  '12-18': { year: 1878, event: 'Birth of Joseph Stalin; Swiss exile community later shelters dissidents', eventDE: 'Geburt von Josef Stalin; Schweizer Exilgemeinschaft beherbergt später Dissidenten' },
  '12-19': { year: 1562, event: 'Battle of Dreux: Swiss mercenaries serve in French Wars of Religion', eventDE: 'Schlacht bei Dreux: Schweizer Söldner in französischen Religionskriegen' },
  '12-20': { year: 1803, event: 'Louisiana Purchase; Swiss emigrants head west', eventDE: 'Louisiana-Kauf; Schweizer Auswanderer ziehen nach Westen' },
  '12-21': { year: 1620, event: 'Pilgrims land at Plymouth Rock; Swiss Mennonites later settle Pennsylvania', eventDE: 'Pilger landen in Plymouth; Schweizer Mennoniten besiedeln später Pennsylvania' },
  '12-22': { year: 1216, event: 'Pope Honorius III approves Dominican Order; Swiss monasteries follow', eventDE: 'Papst Honorius III. genehmigt Dominikanerorden; Schweizer Klöster folgen' },
  '12-23': { year: 1847, event: 'Federal Constitution commission begins drafting modern Swiss charter', eventDE: 'Verfassungskommission beginnt Entwurf der modernen Schweizer Verfassung' },
  '12-24': { year: 1524, event: 'Vasco da Gama dies; Swiss trade routes to Asia established', eventDE: 'Vasco da Gama stirbt; Schweizer Handelsrouten nach Asien etabliert' },
  '12-25': { year: 1941, event: 'General Guisan\'s famous Rütli Report during WWII', eventDE: 'General Guisans berühmter Rütlirapport während des 2. Weltkriegs' },
  '12-26': { year: 1898, event: 'Marie Curie announces radium discovery; Swiss physics advances', eventDE: 'Marie Curie kündigt Radium-Entdeckung an; Schweizer Physik profitiert' },
  '12-27': { year: 1831, event: 'Darwin departs on HMS Beagle; Swiss naturalists later expand his work', eventDE: 'Darwin bricht auf der HMS Beagle auf; Schweizer Naturforscher erweitern seine Arbeit' },
  '12-28': { year: 1836, event: 'Spain recognizes Mexican independence; Swiss emigrants in Mexico', eventDE: 'Spanien anerkennt mexikanische Unabhängigkeit; Schweizer Auswanderer in Mexiko' },
  '12-29': { year: 1170, event: 'Thomas Becket murdered; Swiss pilgrimage to Canterbury begins', eventDE: 'Thomas Becket ermordet; Schweizer Pilgerfahrten nach Canterbury beginnen' },
  '12-30': { year: 1916, event: 'Rasputin killed; Swiss intelligence monitors Russian Revolution', eventDE: 'Rasputin getötet; Schweizer Nachrichtendienst beobachtet russische Revolution' },
  '12-31': { year: 1907, event: 'First New Year\'s Eve ball drop; Swiss tradition of midnight church bells', eventDE: 'Erster Silvester-Countdown; Schweizer Tradition des Mitternachtsläutens' },
};

export function getThisDayInHistory() {
  const today = new Date();
  const key = `${today.getMonth() + 1}-${today.getDate()}`;
  return HISTORY[key] || { year: 1291, event: 'The Swiss Confederation was founded', eventDE: 'Die Schweizerische Eidgenossenschaft wurde gegründet' };
}
