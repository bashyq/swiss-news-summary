// ═══════════════════════════════════════════════════
// Znüni — PWA Frontend
// ═══════════════════════════════════════════════════

// ═══ CONFIG ═══
const APP_VERSION = '4.0.3';
const API = 'https://swiss-news-worker.swissnews.workers.dev';
const CITIES = { zurich:'Zürich', basel:'Basel', bern:'Bern', geneva:'Geneva', lausanne:'Lausanne', luzern:'Luzern', winterthur:'Winterthur' };
const WEATHER_ICONS = { 0:'☀️',1:'🌤️',2:'⛅',3:'☁️',45:'🌫️',48:'🌫️',51:'🌦️',53:'🌦️',55:'🌧️',56:'🌧️',57:'🌧️',61:'🌧️',63:'🌧️',65:'🌧️',66:'🌧️',67:'🌧️',71:'🌨️',73:'🌨️',75:'🌨️',77:'🌨️',80:'🌦️',81:'🌦️',82:'🌦️',85:'🌨️',86:'🌨️',95:'⛈️',96:'⛈️',99:'⛈️' };
const ACTIVITY_EMOJIS = { animals:'🦁', museum:'🏛️', playground:'🛝', outdoor:'🌳', nature:'🌿', 'indoor-play':'🎪', event:'📅', seasonal:'🎄', stayhome:'🏠', cafe:'☕', other:'📍' };
const RAINY_CODES = [51,53,55,56,57,61,63,65,66,67,80,81,82,95,96,99];
const MAP_COLORS = { green:'#22c55e', purple:'#a855f7', amber:'#f59e0b', blue:'#3b82f6', sky:'#60a5fa', navy:'#1e40af', gray:'#6b7280', slate:'#94a3b8', white:'#fff', muted:'#666' };

// ═══ STATE ═══
let lang = localStorage.getItem('lang') || 'en';
let city = localStorage.getItem('city') || 'zurich';
let theme = localStorage.getItem('theme') || 'light';
let view = localStorage.getItem('view') || 'news';
if (view === 'whatson') view = 'events'; // merged into events
let newsData = null;
let activitiesData = [];
let cityEventsData = [];
let lunchData = [];
let weekendData = null;
let eventsCalendarData = [];
let currentTab = 'topStories';
let activityFilter = 'all';
let eventFilter = 'all';
let lunchFilters = { nearMe: false, open: false, terrace: false, saved: false };
let lunchCuisine = 'all';
let savedActivities = JSON.parse(localStorage.getItem('savedActivities') || '[]');
let customActivities = JSON.parse(localStorage.getItem('customActivities') || '[]');
let savedLunch = JSON.parse(localStorage.getItem('savedLunch') || '[]');
let customLunch = JSON.parse(localStorage.getItem('customLunch') || '[]');
let sunshineData = null;
// whatsOnData removed — merged into Events view
let sunshineSort = 'sunshine';
let sunshineFilter = 'all';
let sunshineExpanded = false;
let snowData = null;
let snowSort = 'snowfall';
let snowFilter = 'all';
let snowExpanded = false;
let dealsFilter = 'all';
let activityReminders = JSON.parse(localStorage.getItem('activityReminders') || '[]');
let exploreFilter = 'all';
let exploreMap = null;
let exploreMarkers = {};
let snowMap = null;
let snowMarkers = {};
let userLat = null, userLon = null;
let activityMap = null, lunchMap = null, sunshineMap = null;
let lunchMapExpanded = false;
let calendarMonth = new Date().getMonth();
let calendarYear = new Date().getFullYear();
let selectedCalendarDay = null;
let canDonate = false;
const STRIPE_PK = 'pk_live_YOUR_STRIPE_PUBLISHABLE_KEY';

// ═══ I18N ═══
const T = {
  news: { en:'News', de:'Nachrichten' },
  activities: { en:'What to do?', de:'Was tun?' },
  events: { en:'Events', de:'Events' },
  weekend: { en:'Weekend', de:'Wochenende' },
  lunch: { en:'Lunch', de:'Mittagessen' },
  topStories: { en:'Top Stories', de:'Top Meldungen' },
  politics: { en:'Politics', de:'Politik' },
  eventsTab: { en:'Events', de:'Events' },
  culture: { en:'Culture', de:'Kultur' },
  local: { en:'Local', de:'Lokal' },
  all: { en:'All', de:'Alle' },
  nearMe: { en:'Near me', de:'In der Nähe' },
  indoor: { en:'Indoor', de:'Indoor' },
  outdoor: { en:'Outdoor', de:'Draussen' },
  saved: { en:'Saved', de:'Gespeichert' },
  seasonal: { en:'Seasonal', de:'Saisonales' },
  stayHome: { en:'Stay home', de:'Zuhause' },
  surpriseMe: { en:'Surprise me!', de:'Überrasch mich!' },
  settings: { en:'Settings', de:'Einstellungen' },
  language: { en:'Language', de:'Sprache' },
  darkMode: { en:'Dark mode', de:'Dunkelmodus' },
  lightMode: { en:'Light mode', de:'Hellmodus' },
  brandTheme: { en:'Theme', de:'Design' },
  brandClassic: { en:'Classic', de:'Klassisch' },
  brandAlpine: { en:'Alpine', de:'Alpin' },
  holidays: { en:'Upcoming Holidays', de:'Feiertage' },
  share: { en:'Share', de:'Teilen' },
  refresh: { en:'Refresh', de:'Aktualisieren' },
  morning: { en:'Morning', de:'Vormittag' },
  afternoon: { en:'Afternoon', de:'Nachmittag' },
  saturday: { en:'Saturday', de:'Samstag' },
  sunday: { en:'Sunday', de:'Sonntag' },
  today: { en:'Today', de:'Heute' },
  tomorrow: { en:'Tomorrow', de:'Morgen' },
  daysUntil: { en:'days', de:'Tage' },
  addActivity: { en:'Add your own', de:'Eigene hinzufügen' },
  addLunch: { en:'Add restaurant', de:'Restaurant hinzufügen' },
  materials: { en:'Materials', de:'Material' },
  familyActivities: { en: 'Family-friendly activities for ages 2-5', de: 'Familienfreundliche Aktivitäten für 2-5 Jahre' },
  noResults: { en:'No results found', de:'Keine Ergebnisse gefunden' },
  loading: { en:'Loading...', de:'Laden...' },
  shuffle: { en:'Shuffle', de:'Neu mischen' },
  save: { en:'Save', de:'Speichern' },
  another: { en:'Another!', de:'Nochmal!' },
  close: { en:'Close', de:'Schliessen' },
  directions: { en:'Directions', de:'Wegbeschreibung' },
  website: { en:'Website', de:'Webseite' },
  cancel: { en:'Cancel', de:'Abbrechen' },
  name: { en:'Name', de:'Name' },
  description: { en:'Description', de:'Beschreibung' },
  todayInSwitzerland: { en:'Znüni', de:'Znüni' },
  switzerland: { en:'Was lauft hüt?', de:'Was lauft hüt?' },
  whatToDo: { en:'What to do', de:'Was tun' },
  todayQ: { en:'today?', de:'heute?' },
  whereToEat: { en:'Where to', de:'Wo essen' },
  eat: { en:'eat?', de:'gehen?' },
  eventsCalendar: { en:'Calendar', de:'Kalender' },
  weekendPlanner: { en:'Planner', de:'Planer' },
  holidaysFilter: { en:'Holidays', de:'Feiertage' },
  festivalsFilter: { en:'Festivals', de:'Festivals' },
  recurringFilter: { en:'Recurring', de:'Wiederkehrend' },
  sunshine: { en:'Sunshine', de:'Sonnenschein' },
  whereSun: { en:'Where is', de:'Wo ist die' },
  sunTitle: { en:'sun?', de:'Sonne?' },
  sunSubtitle: { en:'Weekend sunshine forecast — best destinations from Zürich', de:'Wochenend-Sonnenprognose — beste Ziele ab Zürich' },
  sunshineHours: { en:'h sun', de:'h Sonne' },
  driveFrom: { en:'from Zürich', de:'ab Zürich' },
  friday: { en:'Fri', de:'Fr' },
  noSunshineData: { en:'No sunshine data available', de:'Keine Sonnendaten verfügbar' },
  sunnyLabel: { en:'Sunny', de:'Sonnig' },
  partlyLabel: { en:'Partly sunny', de:'Teilweise sonnig' },
  cloudyLabel: { en:'Cloudy', de:'Bewölkt' },
  sortBySun: { en:'By sunshine', de:'Nach Sonne' },
  sortByDist: { en:'By distance', de:'Nach Distanz' },
  yourCity: { en:'Your city', de:'Deine Stadt' },
  nearestEscape: { en:'Nearest with more sun', de:'Nächstes Ziel mit mehr Sonne' },
  rain: { en:'rain', de:'Regen' },
  donate: { en:'Support us', de:'Unterstützen' },
  donateTitle: { en:'Buy us a coffee', de:'Kauf uns einen Kaffee' },
  donateDesc: { en:'Help keep this app running', de:'Hilf, diese App am Laufen zu halten' },
  donateThankYou: { en:'Thank you for your support!', de:'Vielen Dank für deine Unterstützung!' },
  donateError: { en:'Payment failed. Please try again.', de:'Zahlung fehlgeschlagen. Bitte erneut versuchen.' },
  donateProcessing: { en:'Processing...', de:'Wird verarbeitet...' },
  about: { en:'About', de:'Info' },
  version: { en:'Version', de:'Version' },
  frontend: { en:'Frontend', de:'Frontend' },
  worker: { en:'Worker', de:'Worker' },
  module: { en:'Module', de:'Modul' },
  checkingVersion: { en:'Checking...', de:'Prüfe...' },
  versionError: { en:'Could not reach API', de:'API nicht erreichbar' },
  toastSaved: { en:'Saved', de:'Gespeichert' },
  toastRemoved: { en:'Removed', de:'Entfernt' },
  toastNetworkError: { en:'Network error — check your connection', de:'Netzwerkfehler — Verbindung prüfen' },
  toastActivitySaved: { en:'Activity added', de:'Aktivität hinzugefügt' },
  toastActivityDeleted: { en:'Activity deleted', de:'Aktivität gelöscht' },
  toastLunchSaved: { en:'Restaurant added', de:'Restaurant hinzugefügt' },
  toastLunchDeleted: { en:'Restaurant deleted', de:'Restaurant gelöscht' },
  toastShared: { en:'Shared!', de:'Geteilt!' },
  emptySavedActivities: { en:'No saved activities yet', de:'Noch keine gespeicherten Aktivitäten' },
  emptySavedHint: { en:'Tap the heart on any activity to save it', de:'Tippe auf das Herz, um eine Aktivität zu speichern' },
  emptyFilterActivities: { en:'No activities match this filter', de:'Keine Aktivitäten für diesen Filter' },
  emptyFilterHint: { en:'Try a different filter or add your own', de:'Probiere einen anderen Filter oder füge eigene hinzu' },
  emptySavedLunch: { en:'No saved restaurants yet', de:'Noch keine gespeicherten Restaurants' },
  emptySavedLunchHint: { en:'Tap the heart on any restaurant to save it', de:'Tippe auf das Herz, um ein Restaurant zu speichern' },
  emptyFilterLunch: { en:'No restaurants match this filter', de:'Keine Restaurants für diesen Filter' },
  emptyEvents: { en:'No events for this date', de:'Keine Events an diesem Datum' },
  emptyEventsHint: { en:'Try selecting a different day or filter', de:'Wähle einen anderen Tag oder Filter' },
  emptySunshine: { en:'No destinations match this filter', de:'Keine Ziele für diesen Filter' },
  emptySunshineHint: { en:'Try "All" to see every destination', de:'Wähle "Alle" um alle Ziele zu sehen' },
  happeningToday: { en:'Happening Today', de:'Heute los' },
  happeningOn: { en:'Happening on', de:'Los am' },
  availableToday: { en:'Available Today', de:'Heute verfügbar' },
  activitiesAvailable: { en:'Activities Available', de:'Verfügbare Aktivitäten' },
  indoorPicksToday: { en:'Indoor picks for today', de:'Indoor-Tipps für heute' },
  outdoorPicksToday: { en:'Outdoor picks for today', de:'Outdoor-Tipps für heute' },
  indoorPicks: { en:'Indoor picks', de:'Indoor-Tipps' },
  outdoorPicks: { en:'Outdoor picks', de:'Outdoor-Tipps' },
  holidayToday: { en:'Holiday today', de:'Feiertag heute' },
  stayIndoorRec: { en:'Stay cosy indoors', de:'Gemütlich drinnen bleiben' },
  goOutdoorRec: { en:'Great day to be outside', de:'Perfekter Tag für draussen' },
  trendingToday: { en:'Trending Today', de:'Trending heute' },
  weatherPicks: { en:'Weather Picks', de:'Wetter-Tipps' },
  thingsToDo: { en:'Things to do', de:'Was unternehmen' },
  findPlaygrounds: { en:'Find playgrounds', de:'Spielplätze finden' },
  findRestaurants: { en:'Find restaurants', de:'Restaurants finden' },
  seeAllActivities: { en:'See all activities', de:'Alle Aktivitäten anzeigen' },
  snow: { en:'Snow', de:'Schnee' },
  whereSnow: { en:'Where is', de:'Wo liegt' },
  snowTitle: { en:'snow?', de:'Schnee?' },
  snowSubtitle: { en:'Weekly snowfall — best ski resorts from Zürich', de:'Wöchentlicher Schneefall — beste Skigebiete ab Zürich' },
  snowfallCm: { en:'cm snow', de:'cm Schnee' },
  snowDepth: { en:'snow depth', de:'Schneehöhe' },
  altitudeM: { en:'m altitude', de:'m Höhe' },
  heavySnow: { en:'Heavy snow', de:'Viel Schnee' },
  moderateSnow: { en:'Moderate', de:'Mässig' },
  lightSnow: { en:'Light', de:'Wenig' },
  sortBySnow: { en:'By snowfall', de:'Nach Schneefall' },
  noSnowData: { en:'No snow data available', de:'Keine Schneedaten verfügbar' },
  emptySnow: { en:'No resorts match this filter', de:'Keine Gebiete für diesen Filter' },
  emptySnowHint: { en:'Try "All" to see every resort', de:'Wähle "Alle" um alle Gebiete zu sehen' },
  weekOf: { en:'Week of', de:'Woche vom' },
  freshPowder: { en:'Fresh powder alert', de:'Neuschnee-Alarm' },
  schoolHolidaysFilter: { en:'School Holidays', de:'Schulferien' },
  schoolHoliday: { en:'School Holiday', de:'Schulferien' },
  schoolHolidayBanner: { en:'School holidays', de:'Schulferien' },
  freeFilter: { en:'Free', de:'Gratis' },
  deals: { en:'Deals', de:'Deals' },
  bestDeals: { en:'Best', de:'Beste' },
  dealsTitle: { en:'deals?', de:'Deals?' },
  dealsSubtitle: { en:'Free entry, family passes & money-saving tips', de:'Gratis Eintritt, Familienpässe & Spartipps' },
  freeEntry: { en:'Free entry', de:'Gratis Eintritt' },
  deal: { en:'Deal', de:'Deal' },
  tip: { en:'Tip', de:'Tipp' },
  museumFree: { en:'Museums', de:'Museen' },
  outdoorFree: { en:'Outdoor', de:'Draussen' },
  transportDeal: { en:'Transport', de:'Transport' },
  familyPass: { en:'Family Passes', de:'Familienpässe' },
  seasonalDeal: { en:'Seasonal', de:'Saisonales' },
  alwaysFree: { en:'Always free', de:'Immer gratis' },
  savingsLabel: { en:'Savings', de:'Ersparnis' },
  emptyDeals: { en:'No deals match this filter', de:'Keine Deals für diesen Filter' },
  emptyDealsHint: { en:'Try "All" to see every deal', de:'Wähle "Alle" um alle Deals zu sehen' },
  todaysPick: { en:"Today's Pick", de:'Tipp des Tages' },
  seeActivity: { en:'See activity', de:'Aktivität ansehen' },
  thisWeekend: { en:'This Weekend', de:'Dieses Wochenende' },
  noWeekendEvents: { en:'No special events', de:'Keine besonderen Events' },
  setReminder: { en:'Set reminder', de:'Erinnerung setzen' },
  reminderSet: { en:'Reminder set!', de:'Erinnerung gesetzt!' },
  reminderDue: { en:'Reminder: Time to visit', de:'Erinnerung: Zeit für' },
  reminderDate: { en:'When?', de:'Wann?' },
  reminderRemove: { en:'Remove reminder', de:'Erinnerung entfernen' },
  newBadge: { en:'NEW', de:'NEU' },
  explore: { en:'Explore', de:'Entdecken' },
  exploreTitle: { en:'near you', de:'in der Nähe' },
  exploreSubtitle: { en:'Activities, events & deals on the map', de:'Aktivitäten, Events & Deals auf der Karte' },
  exploreAll: { en:'All', de:'Alle' },
  exploreActivities: { en:'Activities', de:'Aktivitäten' },
  exploreEvents: { en:'Events', de:'Events' },
  exploreDeals: { en:'Deals', de:'Deals' },
};
const t = k => T[k]?.[lang] || k;

// Deals fetched from worker API — cached locally
let dealsData = [];

const DEAL_CATEGORY_EMOJIS = { museum: '🏛️', outdoor: '🌳', transport: '🚂', family: '👨‍👩‍👧', seasonal: '🎄' };

// ═══ UTILS ═══
const $ = id => document.getElementById(id);
const esc = s => s?.replace(/[&<>"']/g, c => ({ '&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', "'":'&#39;' })[c]) || '';
const safeUrl = u => u && /^https?:\/\//i.test(u) ? u : '';
const CITY_COORDS = { zurich: [47.3769, 8.5417], basel: [47.5596, 7.5886], bern: [46.948, 7.4474], geneva: [46.2044, 6.1432], lausanne: [46.5197, 6.6323], luzern: [47.0502, 8.3093], winterthur: [47.4984, 8.7235] };
const afterRender = fn => requestAnimationFrame(() => requestAnimationFrame(fn));

const cache = {
  get(key, maxAge = 7200000) {
    try {
      const raw = localStorage.getItem(key);
      if (!raw) return null;
      const d = JSON.parse(raw);
      return (Date.now() - (d._cachedAt || 0)) < maxAge ? d : null;
    } catch { return null; }
  },
  set(key, data) {
    try { localStorage.setItem(key, JSON.stringify({ ...data, _cachedAt: Date.now() })); } catch {}
  }
};

// ═══ LOADING BAR ═══
function showLoading() {
  const bar = $('loading-bar');
  if (!bar) return;
  bar.classList.remove('done');
  // Reset animation by removing and re-adding
  const inner = bar.querySelector('.loading-bar-inner');
  inner.style.animation = 'none';
  inner.offsetHeight; // force reflow
  inner.style.animation = '';
  bar.classList.add('active');
}
function hideLoading() {
  const bar = $('loading-bar');
  if (!bar) return;
  bar.classList.add('done');
  setTimeout(() => { bar.classList.remove('active', 'done'); }, 700);
}

function timeAgo(iso) {
  if (!iso) return '';
  const diff = (Date.now() - new Date(iso).getTime()) / 60000;
  if (diff < 1) return lang === 'de' ? 'gerade eben' : 'just now';
  if (diff < 60) return `${Math.floor(diff)}m`;
  if (diff < 1440) return `${Math.floor(diff / 60)}h`;
  return `${Math.floor(diff / 1440)}d`;
}

function haversine(lat1, lon1, lat2, lon2) {
  const R = 6371, toR = Math.PI / 180;
  const dLat = (lat2 - lat1) * toR, dLon = (lon2 - lon1) * toR;
  const a = Math.sin(dLat / 2) ** 2 + Math.cos(lat1 * toR) * Math.cos(lat2 * toR) * Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function formatDist(km) {
  return km < 1 ? `${Math.round(km * 1000)}m` : `${km.toFixed(1)}km`;
}

function retryPhoto(img) {
  const attempt = parseInt(img.dataset.retry || '0');
  if (attempt >= 2) { img.style.display = 'none'; return; }
  img.dataset.retry = attempt + 1;
  setTimeout(() => { img.src = img.src; }, 3000 * (attempt + 1));
}

function mapsUrl(lat, lon, name) {
  const iOS = /iPad|iPhone|iPod/.test(navigator.userAgent);
  return iOS ? `maps://maps.apple.com/?q=${encodeURIComponent(name)}&ll=${lat},${lon}` : `https://www.google.com/maps/search/?api=1&query=${lat},${lon}`;
}

function getGreeting() {
  const h = new Date().getHours();
  if (h < 12) return lang === 'de' ? 'Guten Morgen' : 'Good morning';
  if (h < 17) return lang === 'de' ? 'Guten Tag' : 'Good afternoon';
  return lang === 'de' ? 'Guten Abend' : 'Good evening';
}

function showToast(msgKey, type = 'info') {
  const container = $('toast-container');
  if (!container) return;
  const el = document.createElement('div');
  el.className = `toast toast-${type}`;
  el.textContent = t(msgKey);
  container.appendChild(el);
  requestAnimationFrame(() => el.classList.add('show'));
  setTimeout(() => { el.classList.remove('show'); setTimeout(() => el.remove(), 300); }, 2500);
}

function renderSkeleton(count = 3) {
  return Array.from({ length: count }, () =>
    `<div class="skeleton-card"><div class="skeleton skeleton-title"></div><div class="skeleton skeleton-line"></div><div class="skeleton skeleton-line"></div><div class="skeleton skeleton-line"></div></div>`
  ).join('');
}

function renderEmptyState(icon, msgKey, hintKey) {
  return `<div class="empty-state"><div class="empty-state-icon">${icon}</div><div class="empty-state-msg">${t(msgKey)}</div><div class="empty-state-hint">${t(hintKey)}</div></div>`;
}

let activityMarkers = {};
let lunchMarkers = {};
let sunshineMarkers = {};

function highlightCard(elementId) {
  const el = document.getElementById(elementId);
  if (!el) return;
  el.scrollIntoView({ behavior: 'smooth', block: 'center' });
  el.classList.remove('card-highlight');
  void el.offsetWidth;
  el.classList.add('card-highlight');
}

function panToMarker(markersMap, id, map, zoom = 14) {
  const marker = markersMap[id];
  if (!marker || !map) return;
  map.setView(marker.getLatLng(), zoom);
  marker.openPopup();
}

// ═══ LAYOUT RENDERING ═══

function renderHeader() {
  const now = new Date();
  const dateStr = now.toLocaleDateString(lang === 'de' ? 'de-CH' : 'en-CH', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' });

  const heroViews = { news: true, activities: true, lunch: true, explore: true, events: true, weekend: true, sunshine: true, snow: true, deals: true };
  if (heroViews[view]) {
    const eyebrow = dateStr.toUpperCase();
    const cityName = CITIES[city] || 'Zürich';

    let titleText, heroBottom = '';
    if (view === 'news') {
      titleText = lang === 'de' ? `Heute in <em>${cityName}</em>` : `Today in <em>${cityName}</em>`;
      heroBottom = `<div class="weather-row" id="weather-compact"></div>`;
    } else if (view === 'activities') {
      titleText = lang === 'de' ? `Was <em>tun?</em>` : `What to <em>do?</em>`;
      const filters = [
        ['all', t('all')], ['near', t('nearMe')], ['indoor', t('indoor')], ['outdoor', t('outdoor')],
        ['stayhome', t('stayHome')], ['free', t('freeFilter')], ['seasonal', t('seasonal')], ['saved', t('saved')]
      ];
      const totalCount = activitiesData.length || '...';
      heroBottom = `</div><div class="pill-row-hero">${filters.map(([k, v]) => {
        const active = activityFilter === k;
        return `<button class="pill ${active ? 'on' : 'off'}" onclick="filterActivities('${k}')">${v}${k === 'all' ? `<span class="pill-cnt">${totalCount}</span>` : ''}</button>`;
      }).join('')}</div>`;
    } else if (view === 'lunch') {
      titleText = 'Lunch';
      const lunchPills = [
        ['nearMe', t('nearMe')], ['open', lang === 'de' ? 'Offen' : 'Open'],
        ['terrace', 'Terrasse'], ['saved', t('saved')]
      ];
      const cuisines = [['all', lang === 'de' ? 'Alle' : 'All'], ['italian','🍕'], ['asian','🥢'], ['kebab','🥙'], ['cafe','☕'], ['fastfood','🍔'], ['international','🌍']];
      heroBottom = `</div><div class="pill-row-hero">${lunchPills.map(([k, v]) => {
        const active = lunchFilters[k];
        return `<button class="pill ${active ? 'on' : 'off'}" onclick="toggleLunchFilter('${k}')">${v}</button>`;
      }).join('')}${cuisines.map(([k, v]) => {
        const active = lunchCuisine === k;
        return `<button class="pill ${active ? 'on' : 'off'}" onclick="setLunchCuisine('${k}')">${v}</button>`;
      }).join('')}</div>`;
    } else if (view === 'explore') {
      titleText = lang === 'de' ? `Entdecke <em>${cityName}</em>` : `Explore <em>${cityName}</em>`;
      const explorePills = [
        ['all', t('exploreAll')], ['activities', t('exploreActivities')],
        ['events', t('exploreEvents')], ['deals', t('exploreDeals')]
      ];
      heroBottom = `</div><div class="pill-row-hero">${explorePills.map(([k, v]) => {
        const active = exploreFilter === k;
        return `<button class="pill ${active ? 'on' : 'off'}" onclick="setExploreFilter('${k}')">${v}</button>`;
      }).join('')}</div>`;
    } else if (view === 'events') {
      titleText = lang === 'de' ? `Was <em>läuft?</em>` : `What's <em>On?</em>`;
      const eventPills = [['all', t('all')], ['holidays', t('holidaysFilter')], ['schoolHoliday', '🎒'], ['events', t('eventsTab')], ['recurring', '🔄'], ['seasonal', '🌸'], ['festivals', '🎪']];
      heroBottom = `</div><div class="pill-row-hero">${eventPills.map(([k, v]) => {
        const active = eventFilter === k;
        return `<button class="pill ${active ? 'on' : 'off'}" onclick="filterEvents('${k}')">${v}</button>`;
      }).join('')}</div>`;
    } else if (view === 'weekend') {
      titleText = lang === 'de' ? `Wochen<em>ende</em>` : `Week<em>end</em>`;
    } else if (view === 'sunshine') {
      titleText = lang === 'de' ? `Wo ist <em>Sonne?</em>` : `Where is <em>Sun?</em>`;
      const sunPills = [['all', t('all')], ['sunny', '☀️'], ['partly', '⛅'], ['cloudy', '☁️']];
      const sortPills = [['sunshine', '☀️ ' + t('sortBySun')], ['distance', '📍 ' + t('sortByDist')]];
      heroBottom = `</div><div class="pill-row-hero">${sunPills.map(([k, v]) => {
        const active = sunshineFilter === k;
        return `<button class="pill ${active ? 'on' : 'off'}" onclick="setSunshineFilter('${k}')">${v}</button>`;
      }).join('')}<span class="pill-sep"></span>${sortPills.map(([k, v]) => {
        const active = sunshineSort === k;
        return `<button class="pill ${active ? 'on' : 'off'}" onclick="setSunshineSort('${k}')">${v}</button>`;
      }).join('')}</div>`;
    } else if (view === 'snow') {
      titleText = lang === 'de' ? `Wo ist <em>Schnee?</em>` : `Where is <em>Snow?</em>`;
      const snowPills = [['all', t('all')], ['heavy', '🏔️'], ['moderate', '❄️'], ['light', '🌨️']];
      const sortPills = [['snowfall', '❄️ ' + t('sortBySnow')], ['distance', '📍 ' + t('sortByDist')]];
      heroBottom = `</div><div class="pill-row-hero">${snowPills.map(([k, v]) => {
        const active = snowFilter === k;
        return `<button class="pill ${active ? 'on' : 'off'}" onclick="setSnowFilter('${k}')">${v}</button>`;
      }).join('')}<span class="pill-sep"></span>${sortPills.map(([k, v]) => {
        const active = snowSort === k;
        return `<button class="pill ${active ? 'on' : 'off'}" onclick="setSnowSort('${k}')">${v}</button>`;
      }).join('')}</div>`;
    } else if (view === 'deals') {
      titleText = lang === 'de' ? `Beste <em>Deals?</em>` : `Best <em>Deals?</em>`;
      const dealPills = [['all', t('all')], ['free', '🆓 ' + t('freeEntry')], ['deal', '🏷️ ' + t('deal')], ['tip', '💡 ' + t('tip')]];
      heroBottom = `</div><div class="pill-row-hero">${dealPills.map(([k, v]) => {
        const active = dealsFilter === k;
        return `<button class="pill ${active ? 'on' : 'off'}" onclick="filterDeals('${k}')">${v}</button>`;
      }).join('')}</div>`;
    }

    $('header').innerHTML = `
      <div class="hero">
        <div class="hero-glow"></div>
        <div class="hero-top">
          <div class="hero-controls">
            <div class="city-selector">
              <button class="hero-btn" onclick="toggleCityDropdown()">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/></svg>
                ${cityName}
              </button>
              <div class="city-dropdown" id="city-dropdown">
                ${Object.entries(CITIES).map(([id, name]) => `<button class="city-option${id === city ? ' active' : ''}" onclick="setCity('${id}')">${name}</button>`).join('')}
              </div>
            </div>
          </div>
          <div class="hero-controls">
            <div class="hero-lang">
              <button class="hero-lang-btn${lang === 'en' ? ' active' : ''}" onclick="setLanguage('en')">EN</button>
              <button class="hero-lang-btn${lang === 'de' ? ' active' : ''}" onclick="setLanguage('de')">DE</button>
            </div>
            <button class="hero-btn" onclick="openMenu()" aria-label="Menu">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14"><path d="M3 12h18M3 6h18M3 18h18"/></svg>
            </button>
          </div>
        </div>
        <div class="hero-body">
          <div class="hero-eyebrow">${eyebrow}</div>
          <h1 class="hero-title" style="${view === 'explore' ? 'font-size:26px' : view !== 'news' ? 'font-size:24px' : ''}">${titleText}</h1>
          ${heroBottom}
        </div>
      </div>
      ${view === 'news' ? `<div id="weather-dropdown" class="weather-dropdown"></div>
      <div class="history-strip" id="history-inline"></div>
      <div id="trending-inline" class="trending-banner" style="display:none"></div>
      <div class="alert-banner" id="transport-widget"></div>` : ''}
    `;
  } else {
    // Legacy header for non-news views
    $('header').innerHTML = `
      <div class="header-top">
        <div class="date-display">${dateStr}</div>
        <div class="header-controls">
          <div class="header-lang-toggle">
            <button class="header-lang-btn${lang === 'en' ? ' active' : ''}" onclick="setLanguage('en')">EN</button>
            <button class="header-lang-btn${lang === 'de' ? ' active' : ''}" onclick="setLanguage('de')">DE</button>
          </div>
          <div class="city-selector">
            <button class="icon-btn" onclick="toggleCityDropdown()">
              ${CITIES[city]} <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M6 9l6 6 6-6"/></svg>
            </button>
            <div class="city-dropdown" id="city-dropdown">
              ${Object.entries(CITIES).map(([id, name]) => `<button class="city-option${id === city ? ' active' : ''}" onclick="setCity('${id}')">${name}</button>`).join('')}
            </div>
          </div>
          <button class="icon-btn" onclick="openMenu()">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 12h18M3 6h18M3 18h18"/></svg>
          </button>
        </div>
      </div>
      <div class="title-row">
        <h1 class="page-title" id="page-title">${getPageTitle()}</h1>
        <div id="weather-compact" class="weather-compact"></div>
      </div>
      <div id="weather-dropdown" class="weather-dropdown"></div>
      <div id="history-inline" class="history-inline"></div>
      <div id="trending-inline" class="trending-banner" style="display:none"></div>
      <div id="transport-widget"></div>
    `;
  }
}

function getPageTitle() {
  if (view === 'news') return `${t('todayInSwitzerland')}<br><span class="accent">${t('switzerland')}</span>`;
  if (view === 'activities') return `${t('whatToDo')}<br><span class="accent">${t('todayQ')}</span>`;
  if (view === 'lunch') return `${t('whereToEat')}<br><span class="accent">${t('eat')}</span>`;
  if (view === 'events') return `${lang === 'de' ? 'Was läuft' : "What's on"}<br><span class="accent">${lang === 'de' ? 'heute?' : 'today?'}</span>`;
  if (view === 'weekend') return `${t('weekend')}<br><span class="accent">${t('weekendPlanner')}</span>`;
  if (view === 'sunshine') return `${t('whereSun')}<br><span class="accent">${t('sunTitle')}</span>`;
  if (view === 'snow') return `${t('whereSnow')}<br><span class="accent">${t('snowTitle')}</span>`;
  if (view === 'deals') return `${t('bestDeals')}<br><span class="accent">${t('dealsTitle')}</span>`;
  if (view === 'explore') return `${t('explore')}<br><span class="accent">${t('exploreTitle')}</span>`;
  return '';
}

function renderNav() {
  if (view !== 'news') { $('nav').innerHTML = ''; return; }
  const cats = ['topStories', 'politics', 'eventsTab', 'culture', 'local'];
  const keys = ['topStories', 'politics', 'events', 'culture', 'local'];
  const totalCount = keys.reduce((s, k) => s + (newsData?.categories?.[k]?.length || 0), 0);
  $('nav').innerHTML = `
    <div class="section-row">
      <div class="section-heading">${lang === 'de' ? 'Nachrichten' : 'Headlines'}</div>
      <div class="section-count">${totalCount} ${lang === 'de' ? 'Artikel' : 'articles'}</div>
    </div>
    <div class="pill-row">${cats.map((c, i) => {
      const count = newsData?.categories?.[keys[i]]?.length || 0;
      const active = currentTab === keys[i];
      return `<button class="pill ${active ? 'on' : 'off'}" onclick="setTab('${keys[i]}')">${t(c)}<span class="pill-cnt">${count}</span></button>`;
    }).join('')}</div>`;
}

const VIEW_RENDERERS = { news: renderNewsView, activities: renderActivitiesView, lunch: renderLunchView, events: renderEventsView, weekend: renderWeekendView, sunshine: renderSunshineView, snow: renderSnowView, deals: renderDealsView, explore: renderExploreView };

function renderMain() {
  const views = ['news', 'activities', 'lunch', 'events', 'weekend', 'sunshine', 'snow', 'deals', 'explore'];
  $('main').innerHTML = views.map(v => `<div class="app-view${view === v ? ' active' : ''}" id="view-${v}"></div>`).join('');
  renderCurrentView();
}

function renderCurrentView() {
  const el = $(`view-${view}`);
  if (!el) return;
  if (VIEW_RENDERERS[view]) el.innerHTML = VIEW_RENDERERS[view]();
}

function renderMenu() {
  const navItems = [
    ['news', '📰', t('news')], ['activities', '🎈', t('activities')], ['explore', '🗺️', t('explore')],
    ['sunshine', '☀️', t('sunshine')], ['snow', '❄️', t('snow')], ['lunch', '🍽️', t('lunch')],
    ['weekend', '🌤️', t('weekend')], ['events', '📅', t('events')], ['deals', '🎁', t('deals')]
  ];
  $('menu').innerHTML = `
    <div class="menu-head">
      <div class="menu-title">Znüni</div>
      <button class="menu-close" onclick="closeMenu()"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><path d="M18 6L6 18M6 6l12 12"/></svg></button>
    </div>
    <nav class="menu-nav">
      ${navItems.map(([v, ico, label]) => `<div class="menu-item${view === v ? ' active' : ''}" onclick="switchView('${v}')"><span class="menu-item-icon">${ico}</span>${label}</div>`).join('')}
      ${canDonate ? `<div class="menu-item" onclick="openDonateModal()"><span class="menu-item-icon">☕</span>${t('donate')}</div>` : ''}
    </nav>
    <div class="menu-divider"></div>
    <div class="menu-actions">
      <div class="menu-item" onclick="closeMenu();shareSummary()"><span class="menu-item-icon">📤</span>${t('share')}</div>
      <div class="menu-item" onclick="closeMenu();refreshCurrentView()"><span class="menu-item-icon">🔄</span>${t('refresh')}</div>
      <div class="menu-item" onclick="toggleTheme()"><span class="menu-item-icon">${theme === 'dark' ? '☀️' : '🌙'}</span>${theme === 'dark' ? t('lightMode') : t('darkMode')}</div>
    </div>
    <div class="menu-divider"></div>
    <div class="menu-section" id="menu-holidays">
      <div class="menu-section-title">${t('holidays')}</div>
      <div id="menu-holidays-list"></div>
    </div>
    <div class="menu-footer">
      <div class="menu-section-title" onclick="toggleAbout()" style="cursor:pointer">${t('about')} ▾</div>
      <div id="about-panel" style="display:none"></div>
    </div>
  `;
}

function renderAll() {
  renderHeader();
  renderNav();
  renderMain();
  renderMenu();
}

// ═══ NEWS VIEW ═══

function renderNewsView() {
  if (!newsData) return `<div class="loading-msg">${t('loading')}</div><div class="loading-skeleton">${'<div class="skeleton skeleton-line"></div>'.repeat(6)}</div>`;

  let html = '';

  // Briefing + Daily Pick
  const briefDismissed = localStorage.getItem('briefingDismissed') === new Date().toDateString();
  if (newsData.briefing && !briefDismissed) {
    const b = newsData.briefing;
    html += `<div class="briefing-card" id="briefing-card">
      <button class="briefing-dismiss" onclick="dismissBriefing()">&times;</button>
      <div class="briefing-greeting">${getGreeting()}</div>`;
    if (b.topStory) {
      html += `<div class="briefing-story">
        <div class="briefing-story-headline" onclick="openBriefingStory()">${esc(b.topStory.headline)}</div>
        <div class="briefing-story-summary">${esc(b.topStory.summary)}</div>
      </div>`;
    }
    if (b.dailyPick) {
      const dp = b.dailyPick;
      const reason = lang === 'de' ? dp.reasonDE : dp.reason;
      html += `<div class="briefing-pick" onclick="switchView('activities')">
        <div class="briefing-pick-label">${dp.emoji} ${t('todaysPick')}</div>
        <div class="briefing-pick-text">${esc(reason)}</div>
        <div class="briefing-pick-cta">${t('seeActivity')} &rarr;</div>
      </div>`;
    }
    html += '</div>';
  }

  // Weekend brief
  if (newsData.weekendBrief) {
    html += renderWeekendBriefCard(newsData.weekendBrief);
  }

  // Category sections with ncard layout
  const cats = ['topStories', 'politics', 'events', 'culture', 'local'];
  for (const cat of cats) {
    const items = newsData.categories?.[cat] || [];
    html += `<div class="section${currentTab === cat ? ' active' : ''}" id="section-${cat}">
      <div class="news-list">`;
    for (let ci = 0; ci < items.length; ci++) {
      const item = items[ci];
      const sentiment = item.sentiment || 'neutral';
      const sentClass = sentiment === 'positive' ? 'positive' : sentiment === 'negative' ? 'negative' : 'neutral';
      const sentLabel = sentiment === 'positive' ? (lang === 'de' ? 'Positiv' : 'Positive') : sentiment === 'negative' ? (lang === 'de' ? 'Negativ' : 'Negative') : (lang === 'de' ? 'Neutral' : 'Neutral');
      const sentPill = sentiment === 'positive' ? 'pos' : sentiment === 'negative' ? 'neg' : 'neu';
      const timeStr = item.publishedAt ? timeAgo(item.publishedAt) : '';
      html += `<div class="ncard ${sentClass}" onclick="toggleNews(this, event)">
        <div class="ncard-core">
          <div class="ncard-top">
            <div class="ncard-source-row">
              <span class="ncard-source">${esc(item.source)}</span>
              ${timeStr ? `<span class="ncard-dot"></span><span class="ncard-time">${timeStr}</span>` : ''}
            </div>
          </div>
          <div class="ncard-headline"><a href="${esc(item.url)}" target="_blank" onclick="event.stopPropagation()">${esc(item.headline)}</a></div>
          <div class="ncard-summary">${esc(item.summary)}</div>
          <div class="ncard-footer">
            <span class="sentiment ${sentPill}">${sentLabel}</span>
            <span class="ncard-cta">${lang === 'de' ? 'Mehr' : 'More'} <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M6 9l6 6 6-6"/></svg></span>
          </div>
        </div>
        <div class="ncard-detail">
          <div class="ncard-detail-inner">
            ${item.detail ? `<div class="detail-meta"><div class="detail-meta-item"><div class="detail-meta-label">${lang === 'de' ? 'Details' : 'Details'}</div><div class="detail-meta-value">${esc(item.detail)}</div></div></div>` : ''}
            <div class="detail-actions">
              <a class="btn-read" href="${esc(item.url)}" target="_blank" onclick="event.stopPropagation()">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/><polyline points="15 3 21 3 21 9"/><line x1="10" y1="14" x2="21" y2="3"/></svg>
                ${lang === 'de' ? 'Artikel lesen' : 'Read full article'}
              </a>
              <button class="btn-share" onclick="event.stopPropagation();shareArticle('${esc(item.headline)}','${esc(item.url)}')" aria-label="Share">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="18" cy="5" r="3"/><circle cx="6" cy="12" r="3"/><circle cx="18" cy="19" r="3"/><line x1="8.59" y1="13.51" x2="15.42" y2="17.49"/><line x1="15.41" y1="6.51" x2="8.59" y2="10.49"/></svg>
              </button>
            </div>
          </div>
        </div>
      </div>`;
    }
    if (items.length === 0) html += `<div class="loading-msg">${t('noResults')}</div>`;
    html += '</div></div>';
  }

  return html;
}

function renderWeekendBriefCard(wb) {
  const WI = WEATHER_ICONS;
  let dayHtml = '';
  if (wb.saturday) {
    dayHtml += `<div class="weekend-brief-day"><div class="weekend-brief-day-name">${t('saturday')}</div><div>${WI[wb.saturday.weatherCode] || '🌤️'} ${wb.saturday.tempMax}° / ${wb.saturday.tempMin}°</div></div>`;
  }
  if (wb.sunday) {
    dayHtml += `<div class="weekend-brief-day"><div class="weekend-brief-day-name">${t('sunday')}</div><div>${WI[wb.sunday.weatherCode] || '🌤️'} ${wb.sunday.tempMax}° / ${wb.sunday.tempMin}°</div></div>`;
  }
  let eventsHtml = '';
  if (wb.events?.length) {
    eventsHtml = wb.events.map(e => {
      const name = lang === 'de' ? (e.nameDE || e.name) : e.name;
      return `<div class="weekend-brief-event">${e.toddlerFriendly ? '👶 ' : ''}${esc(name)}${e.free ? ' <span class="badge badge-free">Free</span>' : ''}</div>`;
    }).join('');
  } else {
    eventsHtml = `<div class="weekend-brief-event" style="color:var(--muted)">${t('noWeekendEvents')}</div>`;
  }
  return `<div class="weekend-brief" onclick="switchView('events')">
    <div class="weekend-brief-title">${t('thisWeekend')}</div>
    <div class="weekend-brief-weather">${dayHtml}</div>
    <div class="weekend-brief-events">${eventsHtml}</div>
  </div>`;
}

// ═══ ACTIVITIES VIEW ═══

function renderActivitiesView() {
  const filtered = getFilteredActivities();
  let html = '';

  // Map
  html += '<div class="map-container" id="activity-map"></div>';

  // Results count
  html += `<div class="act-results">
    <div class="act-results-count">${filtered.length} ${lang === 'de' ? 'Ergebnisse' : 'results'}</div>
  </div>`;

  // Activities list
  html += '<div class="act-list" id="activities-list">';
  if (filtered.length === 0) {
    if (activitiesData.length === 0) {
      html += renderSkeleton(3);
    } else if (activityFilter === 'saved') {
      html += renderEmptyState('💛', 'emptySavedActivities', 'emptySavedHint');
    } else {
      html += renderEmptyState('🔍', 'emptyFilterActivities', 'emptyFilterHint');
    }
  } else {
    for (const a of filtered) html += renderActivityCard(a);
  }
  html += '</div>';

  // Surprise me button
  html += `<div style="padding:4px 0 20px">
    <button class="btn-surprise" onclick="surpriseMe()" id="surprise-btn">
      <svg width="15" height="15" viewBox="0 0 16 16" fill="none"><path d="M11 1L13 5H15L11.5 8L12.5 12L10 10.5L7.5 12L8.5 8L5 5H7L9 1H11Z" fill="white" opacity=".85"/><path d="M4 6L5 8H6L4.5 9.5L5 11.5L3.5 10.5L2 11.5L2.5 9.5L1 8H2L3 6H4Z" fill="white" opacity=".5"/></svg>
      ${t('surpriseMe')}
    </button>
  </div>`;

  // Add custom
  html += `<button class="btn-add" onclick="showAddForm('activity')">${t('addActivity')}</button>`;
  html += `<div class="add-form" id="add-activity-form">
    <input id="new-activity-name" placeholder="${t('name')}">
    <textarea id="new-activity-desc" placeholder="${t('description')}"></textarea>
    <div class="form-row">
      <select id="new-activity-indoor"><option value="false">${t('outdoor')}</option><option value="true">${t('indoor')}</option></select>
      <input id="new-activity-price" placeholder="Price">
    </div>
    <div class="form-row" style="margin-top:8px;">
      <button class="btn-primary" onclick="saveCustomActivity()">${t('save')}</button>
      <button class="btn-secondary" onclick="hideAddForm('activity')">${t('cancel')}</button>
    </div>
  </div>`;

  return html;
}

function renderActivityCard(a) {
  const name = lang === 'de' ? (a.nameDE || a.name) : a.name;
  const desc = lang === 'de' ? (a.descriptionDE || a.description) : a.description;
  const isSaved = savedActivities.includes(a.id);
  const dist = (userLat && a.lat) ? haversine(userLat, userLon, a.lat, a.lon) : null;
  const hasPhoto = a.category !== 'stayhome' && a.id && !a.custom;
  const catLabel = a.category ? (a.category.charAt(0).toUpperCase() + a.category.slice(1).replace('-', ' ')) : '';

  // Face tags
  let tags = '';
  tags += `<span class="act-tag ${a.indoor ? 'indoor' : 'outdoor'}">${a.indoor ? 'Indoor' : 'Outdoor'}</span>`;
  if (a.duration) tags += `<span class="act-tag time">${a.duration}</span>`;
  if (a.free || (a.price && /^free|^gratis/i.test(a.price))) tags += `<span class="act-tag free">${lang === 'de' ? 'Gratis' : 'Free'}</span>`;
  else if (a.price) tags += `<span class="act-tag price">${a.price}</span>`;
  if (dist !== null) tags += `<span class="act-tag dist">↗ ${formatDist(dist)}</span>`;

  // Status info
  let statusHtml = '';
  if (a.permanentlyClosed) {
    statusHtml = `<div class="act-status-strip"><div class="act-status-dot closed"></div><span class="act-status-text closed">${lang === 'de' ? 'Dauerhaft geschlossen' : 'Permanently closed'}</span></div>`;
  } else if (a.openNow !== undefined && a.openNow !== null) {
    const weekdays = a.weekdayText ? ` · ${a.weekdayText[0]?.split(':')[0] || ''}` : '';
    statusHtml = `<div class="act-status-strip">
      <div class="act-status-dot ${a.openNow ? 'open' : 'closed'}"></div>
      <span class="act-status-text ${a.openNow ? 'open' : 'closed'}">${a.openNow ? (lang === 'de' ? 'Geöffnet' : 'Open now') : (lang === 'de' ? 'Geschlossen' : 'Closed')}</span>
      <span class="act-status-hours">${weekdays}</span>
    </div>`;
  }

  // Detail grid cells
  const distVal = dist !== null ? formatDist(dist) + (lang === 'de' ? ' entfernt' : ' away') : (lang === 'de' ? 'Standort unbekannt' : 'Location unknown');
  const durationVal = a.duration || '—';
  const priceVal = a.price || (lang === 'de' ? 'Gratis' : 'Free');
  const agesVal = a.ageRange || (a.minAge && a.maxAge ? `${a.minAge}–${a.maxAge} ${lang === 'de' ? 'Jahre' : 'years'}` : (lang === 'de' ? 'Alle Alter' : 'All ages'));

  return `<div class="act-card" id="activity-${a.id}" data-lat="${a.lat || ''}" data-lon="${a.lon || ''}" onclick="toggleActCard(this, event)">
    <div class="act-face">
      ${hasPhoto ? `<div class="act-photo-wrap"><img src="${API}/photo/${a.id}" alt="" loading="lazy" onerror="this.parentNode.classList.add('no-img')"><div class="act-photo-badge">${catLabel}</div></div>` : ''}
      <div class="act-face-body">
        <div class="act-face-name">${esc(name)}</div>
        <div class="act-face-desc">${esc(desc)}</div>
        <div class="act-face-tags">${tags}</div>
      </div>
      <button class="act-close-btn" onclick="closeActCard(this.closest('.act-card'), event)">
        <svg width="9" height="9" viewBox="0 0 10 10" fill="none"><path d="M1 1L9 9M9 1L1 9" stroke="var(--muted)" stroke-width="1.8" stroke-linecap="round"/></svg>
      </button>
    </div>
    <div class="act-detail">
      ${hasPhoto ? `<div class="act-detail-photo"><img src="${API}/photo/${a.id}" alt="" loading="lazy"><div class="act-detail-photo-fade"></div><div class="act-detail-photo-badges"><span class="act-detail-photo-badge">${catLabel}${a.indoor ? ' · Indoor' : ''}</span></div></div>` : ''}
      <div class="act-detail-body">
        <div class="act-detail-title">${esc(name)}</div>
        <div class="act-detail-desc">${esc(desc)}</div>
        <div class="act-detail-grid">
          <div class="act-detail-cell"><div class="act-detail-label">${lang === 'de' ? 'Entfernung' : 'Distance'}</div><div class="act-detail-value">${distVal}</div></div>
          <div class="act-detail-cell"><div class="act-detail-label">${lang === 'de' ? 'Dauer' : 'Duration'}</div><div class="act-detail-value">${durationVal}</div></div>
          <div class="act-detail-cell"><div class="act-detail-label">${lang === 'de' ? 'Preis' : 'Price'}</div><div class="act-detail-value">${priceVal}</div></div>
          <div class="act-detail-cell"><div class="act-detail-label">${lang === 'de' ? 'Alter' : 'Ages'}</div><div class="act-detail-value">${agesVal}</div></div>
        </div>
        ${statusHtml}
        <div class="act-detail-actions">
          ${a.url ? `<a class="btn-website" href="${esc(a.url)}" target="_blank" onclick="event.stopPropagation()"><svg width="12" height="12" viewBox="0 0 14 14" fill="none"><path d="M7 1V8M4 5L7 1L10 5" stroke="white" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round"/><path d="M2 10V12C2 12.5 2.5 13 3 13H11C11.5 13 12 12.5 12 12V10" stroke="white" stroke-width="1.4" stroke-linecap="round"/></svg>${t('website')}</a>` : ''}
          <button class="btn-save${isSaved ? ' saved' : ''}" onclick="event.stopPropagation();toggleSave('${a.id}');renderCurrentView();afterRender(initActivityMap)">
            ${isSaved ? '❤️' : '🤍'}
          </button>
        </div>
      </div>
    </div>
  </div>`;
}

function getFilteredActivities() {
  let items = [...activitiesData, ...customActivities];

  // Category filter
  if (activityFilter === 'all') { items = items.filter(a => a.category !== 'stayhome'); for (let i = items.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [items[i], items[j]] = [items[j], items[i]]; } }
  else if (activityFilter === 'near') { items = items.filter(a => a.category !== 'stayhome' && a.lat && (!userLat || haversine(userLat, userLon, a.lat, a.lon) < 2)); if (userLat) items.sort((a, b) => haversine(userLat, userLon, a.lat, a.lon) - haversine(userLat, userLon, b.lat, b.lon)); }
  else if (activityFilter === 'indoor') items = items.filter(a => a.indoor && a.category !== 'stayhome');
  else if (activityFilter === 'outdoor') items = items.filter(a => !a.indoor && a.category !== 'stayhome');
  else if (activityFilter === 'free') items = items.filter(a => a.free === true);
  else if (activityFilter === 'saved') items = items.filter(a => savedActivities.includes(a.id));
  else if (activityFilter === 'seasonal') items = items.filter(a => a.category === 'seasonal');
  else if (activityFilter === 'stayhome') items = items.filter(a => a.category === 'stayhome');

  return items;
}

// ═══ EVENTS VIEW ═══

function renderEventsView() {
  let html = '';

  // Auto-select today if nothing selected
  if (!selectedCalendarDay) {
    selectedCalendarDay = new Date().toISOString().split('T')[0];
  }

  // Calendar
  html += renderCalendarGrid();

  // Day detail panel (always shown for selected day)
  html += '<div id="day-detail" class="day-detail-panel">';
  html += renderDayDetail(selectedCalendarDay);
  html += '</div>';

  // Events list header
  html += `<div class="section-heading" style="margin-top:20px;margin-bottom:8px">${lang === 'de' ? 'Alle Events' : 'All Events'}</div>`;

  // Events list
  html += '<div id="events-list">';
  html += renderEventsList();
  html += '</div>';

  return html;
}

function renderCalendarGrid() {
  const months = lang === 'de'
    ? ['Januar','Februar','März','April','Mai','Juni','Juli','August','September','Oktober','November','Dezember']
    : ['January','February','March','April','May','June','July','August','September','October','November','December'];
  const dayHeaders = lang === 'de' ? ['Mo','Di','Mi','Do','Fr','Sa','So'] : ['Mo','Tu','We','Th','Fr','Sa','Su'];

  const first = new Date(calendarYear, calendarMonth, 1);
  const daysInMonth = new Date(calendarYear, calendarMonth + 1, 0).getDate();
  let startDay = first.getDay() - 1; if (startDay < 0) startDay = 6;
  const today = new Date(); today.setHours(0, 0, 0, 0);

  let html = `<div class="calendar-header">
    <button class="calendar-nav" onclick="calendarPrev()">&lt;</button>
    <span class="calendar-month">${months[calendarMonth]} ${calendarYear}</span>
    <button class="calendar-nav" onclick="calendarNext()">&gt;</button>
  </div>`;
  html += '<div class="calendar-grid">';
  for (const d of dayHeaders) html += `<div class="calendar-day-header">${d}</div>`;

  // Build event map for this month
  const eventMap = {};
  for (const ev of eventsCalendarData) {
    const start = new Date(ev.startDate || ev.date);
    const end = ev.endDate ? new Date(ev.endDate) : start;
    for (let d = new Date(start); d <= end; d.setDate(d.getDate() + 1)) {
      if (d.getMonth() === calendarMonth && d.getFullYear() === calendarYear) {
        const key = d.getDate();
        if (!eventMap[key]) eventMap[key] = new Set();
        eventMap[key].add(ev.type || 'event');
      }
    }
  }

  // Empty cells before month starts
  for (let i = 0; i < startDay; i++) html += '<div class="calendar-day other-month"></div>';

  for (let d = 1; d <= daysInMonth; d++) {
    const dateObj = new Date(calendarYear, calendarMonth, d);
    const isToday = dateObj.getTime() === today.getTime();
    const dateStr = `${calendarYear}-${String(calendarMonth + 1).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
    const isSelected = selectedCalendarDay === dateStr;
    const types = eventMap[d];

    let dots = '';
    if (types) {
      dots = '<div class="calendar-dots">';
      if (types.has('holiday')) dots += '<div class="calendar-dot dot-holiday"></div>';
      if (types.has('festival')) dots += '<div class="calendar-dot dot-festival"></div>';
      if (types.has('schoolHoliday')) dots += '<div class="calendar-dot dot-school-holiday"></div>';
      if (types.has('recurring')) dots += '<div class="calendar-dot dot-recurring"></div>';
      if (types.has('seasonal')) dots += '<div class="calendar-dot dot-seasonal"></div>';
      dots += '</div>';
    }

    html += `<div class="calendar-day${isToday ? ' today' : ''}${isSelected ? ' selected' : ''}" onclick="selectCalendarDay('${dateStr}')">${d}${dots}</div>`;
  }

  html += '</div>';
  return html;
}

function renderEventsList() {
  let items = eventsCalendarData;

  // Filter by type
  if (eventFilter !== 'all') {
    items = items.filter(e => e.type === eventFilter || (eventFilter === 'events' && e.type === 'event'));
  }

  // Filter by selected day
  if (selectedCalendarDay) {
    const sel = new Date(selectedCalendarDay);
    items = items.filter(e => {
      const start = new Date(e.startDate || e.date);
      const end = e.endDate ? new Date(e.endDate) : start;
      return sel >= start && sel <= end;
    });
  }

  // Sort by date
  items.sort((a, b) => new Date(a.startDate || a.date) - new Date(b.startDate || b.date));

  if (items.length === 0) return renderEmptyState('📅', 'emptyEvents', 'emptyEventsHint');

  return items.map(e => {
    const name = lang === 'de' ? (e.nameDE || e.name) : e.name;
    const desc = lang === 'de' ? (e.descriptionDE || e.description) : e.description;
    let dateLabel = e.startDate || e.date || '';
    if (e.endDate && e.endDate !== e.startDate) dateLabel += ` — ${e.endDate}`;

    let badges = '';
    if (e.type === 'schoolHoliday') badges += '<span class="badge badge-school-holiday">🎒 ' + t('schoolHoliday') + '</span>';
    if (e.toddlerFriendly) badges += '<span class="badge badge-toddler">👶 Toddler-friendly</span>';
    if (e.free) badges += '<span class="badge badge-free">🆓 Free</span>';

    const clickAttr = safeUrl(e.url) ? ` style="cursor:pointer" onclick="window.open('${esc(e.url)}','_blank')"` : '';
    return `<div class="event-card"${clickAttr}>
      <div class="event-date">${dateLabel}</div>
      <div class="event-name">${esc(name)}</div>
      <div class="event-desc">${esc(desc)}</div>
      <div class="event-badges">${badges}</div>
    </div>`;
  }).join('');
}

// ═══ WEEKEND VIEW ═══

function renderWeekendView() {
  if (!weekendData) return renderSkeleton(2);

  let html = '';
  for (const day of ['saturday', 'sunday']) {
    const d = weekendData[day];
    if (!d) continue;
    const dayName = t(day);
    const dateLabel = new Date(d.date).toLocaleDateString(lang === 'de' ? 'de-CH' : 'en-CH', { weekday: 'long', day: 'numeric', month: 'long' });

    html += `<div class="weekend-day">
      <div class="weekend-day-header">
        <div class="weekend-day-name">${dayName}</div>
        <div class="weekend-weather">${d.weather ? `${WEATHER_ICONS[d.weather.weatherCode] || '🌡️'} ${d.weather.tempMax}°/${d.weather.tempMin}°` : ''}</div>
      </div>
      <div style="font-size:.75rem;color:var(--muted);margin-bottom:8px;">${dateLabel}</div>`;

    for (const slot of ['morning', 'afternoon']) {
      const a = d.plan?.[slot];
      if (!a) continue;
      const name = lang === 'de' ? (a.nameDE || a.name) : a.name;
      const desc = lang === 'de' ? (a.descriptionDE || a.description) : a.description;
      html += `<div class="weekend-slot">
        <div class="weekend-slot-label">${t(slot)}</div>
        <div class="weekend-activity-name">${ACTIVITY_EMOJIS[a.category] || '📍'} ${esc(name)}</div>
        <div class="weekend-activity-desc">${esc(desc)}</div>
        <div class="activity-badges" style="margin-top:6px;">
          <span class="badge ${a.indoor ? 'badge-indoor' : 'badge-outdoor'}">${a.indoor ? 'Indoor' : 'Outdoor'}</span>
          ${a.duration ? `<span class="badge badge-duration">${a.duration}</span>` : ''}
          ${a.price ? `<span class="badge badge-price">${a.price}</span>` : ''}
        </div>
      </div>`;
    }
    html += '</div>';
  }

  html += `<div class="weekend-actions">
    <button class="btn-secondary" onclick="loadWeekendPlanner(true)">${t('shuffle')}</button>
  </div>`;

  return html;
}

// ═══ LUNCH VIEW ═══

function renderLunchView() {
  let html = '';

  // Map
  html += `<div class="map-container${lunchMapExpanded ? ' expanded' : ' compact'}" id="lunch-map" onclick="toggleLunchMap()"></div>`;

  // Results bar
  const spots = getFilteredLunchSpots();
  const totalCount = lunchData.length + customLunch.length;
  html += `<div class="act-results"><span>${spots.length} of ${totalCount} ${lang === 'de' ? 'Ergebnisse' : 'results'}</span></div>`;

  // List
  html += '<div class="vcard-list" id="lunch-list">';
  if (spots.length === 0) {
    if (lunchData.length === 0) {
      html += renderSkeleton(3);
    } else if (lunchFilters.saved) {
      html += renderEmptyState('💛', 'emptySavedLunch', 'emptySavedLunchHint');
    } else {
      html += renderEmptyState('🔍', 'emptyFilterLunch', 'emptyFilterHint');
    }
  } else {
    for (const s of spots.slice(0, 50)) html += renderLunchCard(s);
  }
  html += '</div>';

  // Surprise me button
  html += `<button class="btn-surprise" onclick="surpriseLunch()">🎲 ${t('surpriseMe')}</button>`;

  return html;
}

function renderLunchCard(s) {
  const isSaved = savedLunch.includes(s.id);
  const dist = (userLat && s.lat) ? haversine(userLat, userLon, s.lat, s.lon) : null;
  const photoUrl = s.lat ? `${API}/photo/${s.id}?name=${encodeURIComponent(s.name)}&lat=${s.lat}&lon=${s.lon}` : '';

  // Face tags
  let tags = '';
  if (s.outdoorSeating) tags += '<span class="vcard-tag terrace">☀️ Terrace</span>';
  if (s.takeaway) tags += '<span class="vcard-tag">📦 Takeaway</span>';
  if (s.wheelchair === 'yes') tags += '<span class="vcard-tag">♿</span>';
  const cuisineLabel = s.cuisine || s.cuisineCategory || s.amenity || '';
  if (cuisineLabel) tags += `<span class="vcard-tag cuisine">${esc(cuisineLabel)}</span>`;

  // Rating
  const starsHtml = s.rating ? `<span class="vcard-stars">★ ${s.rating}</span><span class="vcard-reviews">(${s.ratingCount || 0})</span>` : '';
  const priceHtml = s.priceLevel != null ? `<span class="vcard-price">${'$'.repeat(s.priceLevel || 1)}</span>` : '';

  // Status
  let statusHtml = '';
  if (s.permanentlyClosed) statusHtml = '<span class="status-dot closed"></span><span class="status-txt closed">Permanently closed</span>';
  else if (s.openForLunch === true) statusHtml = `<span class="status-dot open"></span><span class="status-txt open">${lang === 'de' ? 'Offen zum Mittagessen' : 'Open for lunch'}</span>`;
  else if (s.openForLunch === false) statusHtml = `<span class="status-dot closed"></span><span class="status-txt closed">${lang === 'de' ? 'Geschlossen' : 'Closed'}</span>`;

  // Detail grid
  const distText = dist !== null ? formatDist(dist) : '—';
  const priceText = s.priceLevel != null ? '$'.repeat(s.priceLevel) : '—';

  return `<div class="vcard${s.permanentlyClosed ? ' closed' : ''}" id="lc-${s.id}" onclick="toggleLunchCard(this, event)">
    <div class="vcard-face">
      <div class="vcard-photo">${photoUrl ? `<img src="${photoUrl}" alt="" loading="lazy" onerror="retryPhoto(this)">` : `<div class="vcard-photo-empty">🍽️</div>`}</div>
      <div class="vcard-body">
        <div class="vcard-name">${esc(s.name)}</div>
        <div class="vcard-meta">${starsHtml}${priceHtml}${dist !== null ? `<span class="vcard-dist">↗ ${distText}</span>` : ''}</div>
        <div class="vcard-tags">${tags}</div>
      </div>
      <div class="vcard-right"><svg class="vcard-chevron" width="8" height="14" viewBox="0 0 8 14" fill="none"><path d="M1 1l6 6-6 6" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/></svg></div>
    </div>
    <button class="act-close-btn" onclick="closeLunchCard(this.closest('.vcard'),event)">✕</button>
    <div class="vcard-expand">
      ${photoUrl ? `<div class="act-detail-photo"><img src="${photoUrl}" alt="" loading="lazy"><div class="act-detail-photo-fade"></div></div>` : ''}
      <div class="vcard-expand-body">
        <div class="vcard-expand-name">${esc(s.name)}</div>
        ${statusHtml ? `<div class="vcard-status">${statusHtml}</div>` : ''}
        <div class="act-detail-grid">
          <div class="act-detail-cell"><div class="act-detail-label">${lang === 'de' ? 'Entfernung' : 'Distance'}</div><div class="act-detail-val">${distText}</div></div>
          <div class="act-detail-cell"><div class="act-detail-label">${lang === 'de' ? 'Küche' : 'Cuisine'}</div><div class="act-detail-val">${esc(cuisineLabel) || '—'}</div></div>
          <div class="act-detail-cell"><div class="act-detail-label">${lang === 'de' ? 'Preis' : 'Price'}</div><div class="act-detail-val">${priceText}</div></div>
          <div class="act-detail-cell"><div class="act-detail-label">Rating</div><div class="act-detail-val">${s.rating || '—'}</div></div>
        </div>
        <div class="vcard-actions">
          ${s.lat ? `<button class="vcard-act-btn primary" onclick="event.stopPropagation();window.open('${mapsUrl(s.lat, s.lon, s.name)}','_blank')"><svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/></svg> ${lang === 'de' ? 'Route' : 'Directions'}</button>` : ''}
          ${s.website ? `<button class="vcard-act-btn secondary" onclick="event.stopPropagation();window.open('${esc(s.website)}','_blank')">🌐 Website</button>` : ''}
          <button class="vcard-act-btn icon-only" onclick="event.stopPropagation();toggleSaveLunch('${s.id}')">${isSaved ? '❤️' : '🤍'}</button>
          ${s.custom ? `<button class="vcard-act-btn icon-only" onclick="event.stopPropagation();deleteCustomLunch('${s.id}')">🗑️</button>` : ''}
        </div>
      </div>
    </div>
  </div>`;
}

function getFilteredLunchSpots() {
  let items = [...lunchData, ...customLunch];
  if (lunchFilters.saved) items = items.filter(s => savedLunch.includes(s.id));
  if (lunchFilters.open) items = items.filter(s => s.openForLunch === true);
  if (lunchFilters.terrace) items = items.filter(s => s.outdoorSeating);
  if (lunchFilters.nearMe && userLat) items = items.filter(s => s.lat && haversine(userLat, userLon, s.lat, s.lon) < 2);
  if (lunchCuisine !== 'all') items = items.filter(s => s.cuisineCategory === lunchCuisine);

  if (userLat) items.sort((a, b) => {
    if (!a.lat) return 1; if (!b.lat) return -1;
    return haversine(userLat, userLon, a.lat, a.lon) - haversine(userLat, userLon, b.lat, b.lon);
  });

  return items;
}

// ═══ DATA FETCHING ═══

async function fetchNews(force = false) {
  const cacheKey = `newsCache-${city}-${lang}`;
  const hadData = !!newsData;
  if (!force) {
    const cached = cache.get(cacheKey);
    if (cached) { newsData = cached; renderAll(); }
  }

  showLoading();
  try {
    // Use prefetched data if available (started in <head> before JS loaded)
    let data;
    if (!force && window.__prefetch) {
      data = await window.__prefetch;
      window.__prefetch = null;
    }
    if (!data) {
      const res = await fetch(`${API}/?lang=${lang}&city=${city}${force ? '&refresh=true' : ''}`);
      data = await res.json();
    }
    newsData = data;
    cache.set(cacheKey, data);
    if (hadData) {
      if (view === 'news') renderCurrentView();
      renderNav();
    } else {
      renderAll();
    }
    if (data.holidays) renderHolidays(data.holidays);
    if (data.weather) renderWeather(data.weather);
    if (data.history) renderHistory(data.history);
    renderTrending(data.trending);
    if (data.transport) renderTransport(data.transport);
  } catch (e) {
    console.error('Fetch news error:', e);
    showToast('toastNetworkError', 'error');
    const newsEl = $('view-news');
    if (!newsData && newsEl) newsEl.innerHTML = '<div class="loading-msg">Failed to load. Check your connection.</div>';
  } finally {
    hideLoading();
  }
}

async function loadActivities(force = false) {
  const cacheKey = `activitiesCache-${city}`;
  if (!force) {
    const cached = cache.get(cacheKey);
    if (cached) {
      activitiesData = cached.activities || [];
      cityEventsData = cached.cityEvents || [];
      renderCurrentView();
      afterRender(initActivityMap);
    }
  }

  showLoading();
  try {
    const res = await fetch(`${API}/activities?city=${city}&lang=${lang}${force ? '&refresh=true' : ''}`);
    const data = await res.json();
    activitiesData = data.activities || [];
    cityEventsData = data.cityEvents || [];
    cache.set(cacheKey, data);
    renderCurrentView();
    afterRender(initActivityMap);
  } catch (e) {
    console.error('Activities error:', e);
    if (!activitiesData.length) showToast('toastNetworkError', 'error');
  } finally {
    hideLoading();
  }
}

async function loadEventsCalendar() {
  // Build calendar data from multiple sources
  eventsCalendarData = [];

  // Fetch news (for weather, trending, holidays) if not loaded
  if (!newsData) {
    try {
      const cacheKey = `newsCache-${city}-${lang}`;
      const cached = cache.get(cacheKey);
      if (cached) newsData = cached;
      else {
        const res = await fetch(`${API}/?city=${city}&lang=${lang}`);
        if (res.ok) { newsData = await res.json(); cache.set(cacheKey, newsData); }
      }
    } catch {}
  }

  // Holidays from news data
  if (newsData?.holidays) {
    for (const h of newsData.holidays) {
      eventsCalendarData.push({ ...h, startDate: h.date, type: 'holiday' });
    }
  }

  // City events + activities
  if (cityEventsData.length === 0) {
    try {
      const res = await fetch(`${API}/activities?city=${city}&lang=${lang}`);
      if (res.ok) {
        const data = await res.json();
        cityEventsData = data.cityEvents || [];
        if (!activitiesData.length) activitiesData = data.activities || [];
      }
    } catch {}
  }

  for (const e of cityEventsData) eventsCalendarData.push({ ...e, type: 'festival' });

  // School holidays from news data
  if (newsData?.schoolHolidays) {
    for (const sh of newsData.schoolHolidays) {
      eventsCalendarData.push({ ...sh, type: 'schoolHoliday' });
    }
  }

  // Recurring & seasonal from activities
  for (const a of activitiesData) {
    if (a.recurring) eventsCalendarData.push({ name: a.name, nameDE: a.nameDE, description: `${a.recurring}`, descriptionDE: `${a.recurring}`, startDate: new Date().toISOString().split('T')[0], type: 'recurring' });
    if (a.category === 'seasonal') eventsCalendarData.push({ name: a.name, nameDE: a.nameDE, description: a.description, descriptionDE: a.descriptionDE, startDate: new Date().toISOString().split('T')[0], type: 'seasonal' });
  }

  renderCurrentView();
}

async function loadWeekendPlanner(force = false) {
  showLoading();
  try {
    const res = await fetch(`${API}/weekend?city=${city}&lang=${lang}${force ? '&refresh=true' : ''}`);
    weekendData = await res.json();
    renderCurrentView();
  } catch (e) { console.error('Weekend error:', e); showToast('toastNetworkError', 'error'); }
  finally { hideLoading(); }
}

async function loadLunchSpots(force = false) {
  showLoading();
  try {
    const res = await fetch(`${API}/lunch?city=${city}${force ? '&refresh=true' : ''}`);
    const data = await res.json();
    lunchData = data.spots || [];
    renderCurrentView();
    afterRender(initLunchMap);
  } catch (e) { console.error('Lunch error:', e); showToast('toastNetworkError', 'error'); }
  finally { hideLoading(); }
}

// ═══ RENDERING HELPERS ═══

function renderWeather(w) {
  if (!w) return;
  const el = $('weather-compact');
  if (!el) return;

  if (view === 'news') {
    // Hero weather row (inside navy hero)
    const icon = WEATHER_ICONS[w.weatherCode] || '🌡️';
    const desc = w.description || '';
    const hi = w.hourly ? Math.max(...w.hourly.map(h => h.temperature)) : w.temperature;
    const lo = w.hourly ? Math.min(...w.hourly.map(h => h.temperature)) : w.temperature;
    el.innerHTML = `
      <span class="weather-temp-lg">${w.temperature}°</span>
      <span class="weather-meta">
        <span class="weather-desc">${desc}</span>
        <span class="weather-range">H:${hi}° L:${lo}°</span>
      </span>
      <span class="weather-icon-hero">${icon}</span>`;
    el.onclick = toggleWeatherDropdown;
    el.style.cursor = 'pointer';
  } else {
    // Legacy compact weather
    el.innerHTML = `<span class="weather-icon">${WEATHER_ICONS[w.weatherCode] || '🌡️'}</span>
      <span class="weather-temp">${w.temperature}°</span>
      <span class="weather-wind">${w.windSpeed} km/h</span>`;
    el.onclick = toggleWeatherDropdown;
    el.style.cursor = 'pointer';
  }

  // Hourly dropdown
  const dd = $('weather-dropdown');
  if (dd && w.hourly?.length) {
    dd.innerHTML = `<div style="font-size:.8rem;font-weight:600;margin-bottom:8px;">${w.description}</div>
    <div class="hourly-forecast">${w.hourly.map(h => `<div class="hourly-item"><div>${h.time}</div><div>${WEATHER_ICONS[h.weatherCode] || '🌡️'}</div><div class="temp">${h.temperature}°</div></div>`).join('')}</div>`;
  }
}

function toggleWeatherDropdown() {
  $('weather-dropdown')?.classList.toggle('active');
}

function renderHistory(h) {
  const el = $('history-inline');
  if (!el || !h) return;
  const text = lang === 'de' ? h.eventDE : h.event;
  const label = lang === 'de' ? 'Heute in der Geschichte' : 'This Day in History';

  if (view === 'news') {
    // History strip card
    el.innerHTML = `
      <svg class="history-strip-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
      <div>
        <div class="history-label">${label}</div>
        <div class="history-text"><span class="history-year">${h.year}</span> — ${esc(text)}</div>
      </div>`;
    el.classList.add('active');
  } else {
    // Legacy
    el.innerHTML = `<div class="history-title">${label}</div><span class="history-year">${h.year}</span> — ${esc(text)}`;
    el.classList.add('active');
  }
}

function renderTrending(tr) {
  const el = $('trending-inline');
  if (!el) return;
  if (!tr) { el.style.display = 'none'; return; }
  const topic = lang === 'de' ? (tr.topicDE || tr.topic) : tr.topic;
  if (view !== 'news') { el.style.display = 'none'; return; }
  el.setAttribute('onclick', safeUrl(tr.url) ? `window.open('${esc(tr.url)}','_blank')` : '');
  el.innerHTML = `
    <div class="alert-left">
      <span>🔥</span>
      <div><div class="trending-label">Trending</div><div class="trending-topic">${esc(topic)}</div></div>
    </div>`;
  el.classList.add('active');
}

function renderTransport(tr) {
  const el = $('transport-widget');
  if (!el) return;
  if (!tr?.summary || tr.summary.status === 'normal') { el.classList.remove('active'); return; }

  if (view === 'news') {
    // Alert banner style
    const status = tr.summary.status;
    const statusText = status === 'major' ? (lang === 'de' ? 'Grosse Störungen' : 'Major delays') : (lang === 'de' ? 'Leichte Verspätungen' : 'Minor delays');
    el.innerHTML = `
      <div class="alert-left" onclick="$('transport-details')?.classList.toggle('active')">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--terra)" stroke-width="2"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>
        <span class="alert-text">🚆 ${statusText} (${tr.summary.totalDelayed})</span>
      </div>
      <svg class="alert-arrow" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M6 9l6 6 6-6"/></svg>`;
    el.classList.add('active');
    // Insert details div after alert banner
    let detailEl = $('transport-details');
    if (!detailEl) {
      detailEl = document.createElement('div');
      detailEl.className = 'transport-details';
      detailEl.id = 'transport-details';
      el.after(detailEl);
    }
    detailEl.innerHTML = tr.delays.map(d => `<div class="delay-item"><span>${esc(d.line)} → ${esc(d.destination)}</span><span class="delay-badge">+${d.delay}min</span></div>`).join('');
  } else {
    // Legacy transport widget
    el.style.display = 'block';
    const status = tr.summary.status;
    const statusText = status === 'major' ? (lang === 'de' ? 'Grosse Störungen' : 'Major delays') : (lang === 'de' ? 'Leichte Verspätungen' : 'Minor delays');
    el.innerHTML = `<div class="transport-header" onclick="$('transport-details')?.classList.toggle('active')">
      <div class="transport-status ${status}"></div>
      <span>🚆 ${statusText} (${tr.summary.totalDelayed})</span>
    </div>
    <div class="transport-details" id="transport-details">
      ${tr.delays.map(d => `<div class="delay-item"><span>${esc(d.line)} → ${esc(d.destination)}</span><span class="delay-badge">+${d.delay}min</span></div>`).join('')}
    </div>`;
  }
}

function renderHolidays(holidays) {
  const el = $('menu-holidays-list');
  if (!el) return;
  if (!holidays?.length) { el.innerHTML = `<div style="font-size:.8rem;color:var(--muted);">${lang === 'de' ? 'Keine in den nächsten 60 Tagen' : 'None in the next 60 days'}</div>`; return; }
  el.innerHTML = holidays.map(h => {
    const name = lang === 'de' ? (h.nameDE || h.name) : h.name;
    const days = h.isToday ? t('today') : h.daysUntil === 1 ? t('tomorrow') : `${h.daysUntil} ${t('daysUntil')}`;
    return `<div class="menu-holiday"><span>${esc(name)}</span><span class="menu-holiday-days">${days}</span></div>`;
  }).join('');
}

// ═══ ACTIONS ═══

function switchView(v) {
  view = v;
  localStorage.setItem('view', v);
  document.querySelectorAll('.app-view').forEach(el => el.classList.toggle('active', el.id === `view-${v}`));
  renderCurrentView();
  renderHeader();
  renderNav();
  renderMenu();
  closeMenu();
  if (newsData) {
    if (newsData.history) renderHistory(newsData.history);
    renderTrending(newsData.trending);
    if (newsData.weather) renderWeather(newsData.weather);
    if (newsData.transport) renderTransport(newsData.transport);
  }
  if (v === 'activities') loadActivities();
  else if (v === 'lunch') loadLunchSpots();
  else if (v === 'events') loadEventsCalendar();
  else if (v === 'weekend') loadWeekendPlanner();
  else if (v === 'sunshine') loadSunshine();
  else if (v === 'snow') loadSnow();
  else if (v === 'explore') loadExplore();
  else if (v === 'deals') loadDeals();
}

function setTab(tab) {
  currentTab = tab;
  renderNav();
  // Toggle sections
  document.querySelectorAll('.section').forEach(s => s.classList.toggle('active', s.id === `section-${tab}`));
}

function setCity(id) {
  city = id; localStorage.setItem('city', id);
  newsData = null; activitiesData = []; lunchData = []; weekendData = null; cityEventsData = [];
  renderAll();
  toggleCityDropdown();
  if (view === 'news') fetchNews();
  else if (view === 'activities') loadActivities();
  else if (view === 'lunch') loadLunchSpots();
  else if (view === 'events') loadEventsCalendar();
  else if (view === 'weekend') loadWeekendPlanner();
  else if (view === 'sunshine') loadSunshine();
  else if (view === 'snow') loadSnow();
  else if (view === 'explore') loadExplore();
}

function setLanguage(l) {
  lang = l; localStorage.setItem('lang', l);
  renderAll();
  if (view === 'news') fetchNews();
}

function toggleTheme() {
  theme = theme === 'dark' ? 'light' : 'dark';
  localStorage.setItem('theme', theme);
  document.documentElement.setAttribute('data-theme', theme);
  updateThemeColor();
  renderMenu();
}

function updateThemeColor() {
  const meta = document.getElementById('meta-theme-color');
  if (!meta) return;
  meta.content = theme === 'dark' ? '#1A3050' : '#1A3A5C';
}

function toggleCityDropdown() {
  $('city-dropdown')?.classList.toggle('active');
}

function openMenu() { $('menu').classList.add('active'); $('menu-overlay').classList.add('active'); }
function closeMenu() { $('menu').classList.remove('active'); $('menu-overlay').classList.remove('active'); }

let aboutLoaded = false;
function toggleAbout() {
  const panel = $('about-panel');
  if (!panel) return;
  const visible = panel.style.display !== 'none';
  panel.style.display = visible ? 'none' : 'block';
  if (!visible && !aboutLoaded) {
    aboutLoaded = true;
    panel.innerHTML = `<div class="about-grid">
      <div class="about-row"><span class="about-label">${t('frontend')}</span><span class="about-val">${APP_VERSION}</span></div>
      <div class="about-row"><span class="about-label">${t('worker')}</span><span class="about-val" id="about-worker">${t('checkingVersion')}</span></div>
      <div id="about-modules"></div>
    </div>`;
    fetch(`${API}/version`).then(r => r.json()).then(d => {
      $('about-worker').textContent = d.worker || '?';
      const mods = d.modules || {};
      $('about-modules').innerHTML = Object.entries(mods)
        .map(([name, ver]) => `<div class="about-row about-module"><span class="about-label">${name}.js</span><span class="about-val">${ver}</span></div>`)
        .join('');
    }).catch(() => {
      $('about-worker').textContent = t('versionError');
    });
  }
}

function toggleDetail(id) { $(id)?.classList.toggle('active'); }

function toggleActCard(card, e) {
  if (e && (e.target.closest('a') || e.target.closest('.btn-save') || e.target.closest('.act-close-btn'))) return;
  const wasExpanded = card.classList.contains('act-expanded');
  document.querySelectorAll('.act-card.act-expanded').forEach(c => c.classList.remove('act-expanded'));
  if (!wasExpanded) {
    card.classList.add('act-expanded');
    card.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
  }
}

function closeActCard(card, e) {
  if (e) e.stopPropagation();
  card.classList.remove('act-expanded');
}

function toggleNews(card, e) {
  if (e && (e.target.closest('a') || e.target.closest('.btn-share'))) return;
  const wasExpanded = card.classList.contains('expanded');
  // Close all other expanded cards
  document.querySelectorAll('.ncard.expanded').forEach(c => c.classList.remove('expanded'));
  if (!wasExpanded) card.classList.add('expanded');
}

function toggleLunchCard(card, e) {
  if (e && (e.target.closest('a') || e.target.closest('.vcard-act-btn') || e.target.closest('.act-close-btn'))) return;
  const wasOpen = card.classList.contains('vcard-open');
  document.querySelectorAll('.vcard.vcard-open').forEach(c => c.classList.remove('vcard-open'));
  if (!wasOpen) {
    card.classList.add('vcard-open');
    setTimeout(() => card.scrollIntoView({ behavior: 'smooth', block: 'nearest' }), 80);
  }
}

function closeLunchCard(card, e) {
  if (e) e.stopPropagation();
  card.classList.remove('vcard-open');
}

function shareArticle(headline, url) {
  if (navigator.share) {
    navigator.share({ title: headline, url: url }).catch(() => {});
  } else {
    navigator.clipboard?.writeText(url).then(() => showToast('toastShared'));
  }
}

function filterActivities(f) {
  activityFilter = f;
  if (f === 'near' && !userLat) { requestLocation(); return; }
  renderHeader();
  renderCurrentView();
  afterRender(initActivityMap);
}

function filterEvents(f) { eventFilter = f; renderHeader(); renderCurrentView(); }
function toggleLunchFilter(f) {
  lunchFilters[f] = !lunchFilters[f];
  if (f === 'nearMe' && lunchFilters.nearMe && !userLat) { requestLocation().then(() => { renderHeader(); renderCurrentView(); afterRender(initLunchMap); }); return; }
  renderHeader();
  renderCurrentView();
  afterRender(initLunchMap);
}
function setLunchCuisine(c) {
  lunchCuisine = c;
  renderHeader();
  renderCurrentView();
  afterRender(initLunchMap);
}

function toggleSave(id) {
  const idx = savedActivities.indexOf(id);
  const removing = idx >= 0;
  if (removing) savedActivities.splice(idx, 1); else savedActivities.push(id);
  localStorage.setItem('savedActivities', JSON.stringify(savedActivities));
  showToast(removing ? 'toastRemoved' : 'toastSaved', removing ? 'info' : 'success');
  renderCurrentView();
  afterRender(initActivityMap);
}

// ═══ REMINDERS ═══

function showReminderModal(activityId) {
  const allActs = [...activitiesData, ...customActivities];
  const act = allActs.find(a => a.id === activityId);
  if (!act) return;
  const name = lang === 'de' ? (act.nameDE || act.name) : act.name;
  const existing = activityReminders.find(r => r.activityId === activityId);
  const tomorrow = new Date();
  tomorrow.setDate(tomorrow.getDate() + 1);
  const minDate = tomorrow.toISOString().split('T')[0];

  const modal = $('modal');
  modal.innerHTML = `<div class="modal-content">
    <button class="modal-close" onclick="closeModal()">&times;</button>
    <div class="modal-emoji">🔔</div>
    <div class="modal-title">${t('setReminder')}</div>
    <div class="modal-desc">${esc(name)}</div>
    ${existing ? `<div style="margin:8px 0;font-size:.8rem;color:var(--accent)">${t('reminderDate')}: ${existing.date}</div>` : ''}
    <input type="date" id="reminder-date-input" min="${minDate}" value="${existing?.date || minDate}" style="width:100%;padding:10px;border:1px solid var(--border);border-radius:8px;margin:12px 0;font-size:1rem;background:var(--bg);color:var(--text)">
    <div class="modal-actions">
      <button class="btn-primary" onclick="confirmReminder('${activityId}')">${t('save')}</button>
      ${existing ? `<button class="btn-secondary" onclick="removeReminder('${activityId}');closeModal()">${t('reminderRemove')}</button>` : ''}
      <button class="btn-secondary" onclick="closeModal()">${t('cancel')}</button>
    </div>
  </div>`;
  modal.classList.add('active');
}

function confirmReminder(activityId) {
  const dateStr = $('reminder-date-input')?.value;
  if (!dateStr) return;
  const allActs = [...activitiesData, ...customActivities];
  const act = allActs.find(a => a.id === activityId);
  const name = act ? (lang === 'de' ? (act.nameDE || act.name) : act.name) : activityId;

  // Remove existing reminder for this activity
  activityReminders = activityReminders.filter(r => r.activityId !== activityId);
  activityReminders.push({ activityId, name, date: dateStr, createdAt: new Date().toISOString() });
  localStorage.setItem('activityReminders', JSON.stringify(activityReminders));

  // Request notification permission
  if ('Notification' in window && Notification.permission === 'default') {
    Notification.requestPermission();
  }

  closeModal();
  showToast('reminderSet', 'success');
  renderCurrentView();
  afterRender(initActivityMap);
}

function removeReminder(activityId) {
  activityReminders = activityReminders.filter(r => r.activityId !== activityId);
  localStorage.setItem('activityReminders', JSON.stringify(activityReminders));
  showToast('toastRemoved', 'info');
  renderCurrentView();
  afterRender(initActivityMap);
}

function checkReminders() {
  const today = new Date().toISOString().split('T')[0];
  const due = activityReminders.filter(r => r.date <= today);
  if (!due.length) return;

  for (const r of due) {
    const msg = `${t('reminderDue')} ${r.name}`;
    if ('Notification' in window && Notification.permission === 'granted') {
      try { new Notification('Znüni', { body: msg, icon: '/icon.svg' }); } catch {}
    }
    showToast('reminderDue', 'info');
  }

  // Remove due reminders
  activityReminders = activityReminders.filter(r => r.date > today);
  localStorage.setItem('activityReminders', JSON.stringify(activityReminders));
}

function toggleSaveLunch(id) {
  const idx = savedLunch.indexOf(id);
  const removing = idx >= 0;
  if (removing) savedLunch.splice(idx, 1); else savedLunch.push(id);
  localStorage.setItem('savedLunch', JSON.stringify(savedLunch));
  showToast(removing ? 'toastRemoved' : 'toastSaved', removing ? 'info' : 'success');
  renderCurrentView();
  afterRender(initLunchMap);
}


function showAddForm(type) { $(`add-${type}-form`)?.classList.add('active'); }
function hideAddForm(type) { $(`add-${type}-form`)?.classList.remove('active'); }

function saveCustomActivity() {
  const name = $('new-activity-name')?.value?.trim();
  const desc = $('new-activity-desc')?.value?.trim();
  if (!name) return;
  customActivities.push({
    id: 'custom-' + Date.now(), name, nameDE: name, description: desc || '', descriptionDE: desc || '',
    indoor: $('new-activity-indoor')?.value === 'true', ageRange: '2-5 years', duration: '1-2 hours',
    price: $('new-activity-price')?.value || '', category: 'other', custom: true
  });
  localStorage.setItem('customActivities', JSON.stringify(customActivities));
  hideAddForm('activity');
  showToast('toastActivitySaved', 'success');
  renderCurrentView();
  afterRender(initActivityMap);
}

function deleteCustomActivity(id) {
  customActivities = customActivities.filter(a => a.id !== id);
  localStorage.setItem('customActivities', JSON.stringify(customActivities));
  showToast('toastActivityDeleted', 'info');
  renderCurrentView();
  afterRender(initActivityMap);
}

function saveCustomLunch() {
  const name = $('new-lunch-name')?.value?.trim();
  if (!name) return;
  customLunch.push({
    id: 'custom-lunch-' + Date.now(), name, cuisine: $('new-lunch-cuisine')?.value || '',
    cuisineCategory: 'other', custom: true
  });
  localStorage.setItem('customLunch', JSON.stringify(customLunch));
  hideAddForm('lunch');
  showToast('toastLunchSaved', 'success');
  renderCurrentView();
  afterRender(initLunchMap);
}

function deleteCustomLunch(id) {
  customLunch = customLunch.filter(s => s.id !== id);
  localStorage.setItem('customLunch', JSON.stringify(customLunch));
  showToast('toastLunchDeleted', 'info');
  renderCurrentView();
  afterRender(initLunchMap);
}

function requestLocation() {
  if (!navigator.geolocation) return;
  navigator.geolocation.getCurrentPosition(pos => {
    userLat = pos.coords.latitude;
    userLon = pos.coords.longitude;
    renderCurrentView();
    afterRender(initActivityMap);
  }, () => {}, { enableHighAccuracy: true });
}

function dismissBriefing() {
  localStorage.setItem('briefingDismissed', new Date().toDateString());
  $('briefing-card')?.remove();
}

function openBriefingStory() {
  if (newsData?.briefing?.topStory?.url) window.open(newsData.briefing.topStory.url, '_blank');
}

function calendarPrev() { calendarMonth--; if (calendarMonth < 0) { calendarMonth = 11; calendarYear--; } renderCurrentView(); }
function calendarNext() { calendarMonth++; if (calendarMonth > 11) { calendarMonth = 0; calendarYear++; } renderCurrentView(); }
function selectCalendarDay(dateStr) { selectedCalendarDay = selectedCalendarDay === dateStr ? null : dateStr; renderCurrentView(); }

function refreshCurrentView() {
  if (view === 'news') fetchNews(true);
  else if (view === 'activities') loadActivities(true);
  else if (view === 'lunch') loadLunchSpots(true);
  else if (view === 'events') loadEventsCalendar();
  else if (view === 'weekend') loadWeekendPlanner(true);
  else if (view === 'sunshine') loadSunshine(true);
  else if (view === 'snow') loadSnow(true);
  else if (view === 'explore') loadExplore(true);
}

async function shareSummary() {
  if (!navigator.share) return;
  try {
    await navigator.share({ title: 'Znüni', text: `Znüni — ${CITIES[city]}`, url: window.location.href });
    showToast('toastShared', 'success');
  } catch {}
}

function toggleLunchMap() {
  lunchMapExpanded = !lunchMapExpanded;
  const el = $('lunch-map');
  if (!el) return;
  el.classList.toggle('compact', !lunchMapExpanded);
  el.classList.toggle('expanded', lunchMapExpanded);
  el.style.pointerEvents = lunchMapExpanded ? 'auto' : 'none';
  if (lunchMap) afterRender(() => lunchMap.invalidateSize());
}

// ═══ SURPRISE ME ═══

function surpriseMe() {
  let candidates = activitiesData.filter(a => a.category !== 'stayhome');
  if (activityFilter === 'stayhome') candidates = activitiesData.filter(a => a.category === 'stayhome');
  if (candidates.length === 0) return;
  const pick = candidates[Math.floor(Math.random() * candidates.length)];
  showSurpriseModal(pick, 'activity');
}

function openPlaygroundsMap() {
  const [lat, lon] = userLat ? [userLat, userLon] : (CITY_COORDS[city] || CITY_COORDS.zurich);
  window.open(`https://www.google.com/maps/search/playground/@${lat},${lon},14z`, '_blank');
}

function surpriseLunch() {
  const spots = getFilteredLunchSpots();
  if (spots.length === 0) return;
  const pick = spots[Math.floor(Math.random() * spots.length)];
  showSurpriseModal(pick, 'lunch');
}

function showSurpriseModal(item, type) {
  const name = lang === 'de' ? (item.nameDE || item.name) : item.name;
  const desc = lang === 'de' ? (item.descriptionDE || item.description) : item.description;
  const emoji = type === 'lunch' ? '🍽️' : (ACTIVITY_EMOJIS[item.category] || '🎉');
  const isSaved = savedActivities.includes(item.id);

  if (type === 'activity') {
    // Bottom sheet for activities
    const hasPhoto = item.id && item.category !== 'stayhome';
    let tags = `<span class="act-tag ${item.indoor ? 'indoor' : 'outdoor'}">${item.indoor ? 'Indoor' : 'Outdoor'}</span>`;
    if (item.duration) tags += `<span class="act-tag time">${item.duration}</span>`;
    if (item.free || (item.price && /^free|^gratis/i.test(item.price))) tags += `<span class="act-tag free">${lang === 'de' ? 'Gratis' : 'Free'}</span>`;
    if (item.ageRange) tags += `<span class="act-tag ages">${item.ageRange}</span>`;

    // Create sheet elements if not exists
    let scrim = document.querySelector('.surprise-sheet-scrim');
    let sheet = document.querySelector('.surprise-sheet');
    if (!scrim) {
      scrim = document.createElement('div');
      scrim.className = 'surprise-sheet-scrim';
      scrim.onclick = closeSurpriseSheet;
      document.body.appendChild(scrim);
    }
    if (!sheet) {
      sheet = document.createElement('div');
      sheet.className = 'surprise-sheet';
      document.body.appendChild(sheet);
    }
    sheet.innerHTML = `
      <div class="surprise-sheet-handle"><div class="surprise-sheet-bar"></div></div>
      <button class="surprise-sheet-close" onclick="closeSurpriseSheet()">
        <svg width="9" height="9" viewBox="0 0 10 10" fill="none"><path d="M1 1L9 9M9 1L1 9" stroke="var(--muted)" stroke-width="1.8" stroke-linecap="round"/></svg>
      </button>
      <div class="surprise-sheet-body">
        ${hasPhoto ? `<div class="surprise-sheet-photo"><img src="${API}/photo/${item.id}" alt="" onerror="this.parentNode.innerHTML='<div style=\\'font-size:3rem;padding:30px\\'>${emoji}</div>'"></div>` : `<div style="font-size:3rem;margin-bottom:16px">${emoji}</div>`}
        <div class="surprise-sheet-name">${esc(name)}</div>
        <div class="surprise-sheet-desc">${esc(desc || '')}</div>
        <div class="surprise-sheet-tags">${tags}</div>
        <div class="surprise-sheet-links">
          ${item.url ? `<button class="surprise-sheet-link" onclick="window.open('${esc(item.url)}','_blank')"><svg width="14" height="14" viewBox="0 0 16 16" fill="none"><circle cx="8" cy="8" r="6" stroke="var(--navy)" stroke-width="1.4"/><path d="M8 2C8 2 6 5 6 8C6 11 8 14 8 14M8 2C8 2 10 5 10 8C10 11 8 14 8 14M2 8H14" stroke="var(--navy)" stroke-width="1.4" stroke-linecap="round"/></svg>${t('website')}</button>` : ''}
          <button class="surprise-sheet-link" onclick="event.stopPropagation();toggleSave('${item.id}');this.innerHTML=savedActivities.includes('${item.id}')?'❤️ Saved':'🤍 Save'">
            ${isSaved ? '❤️ Saved' : '🤍 Save'}
          </button>
        </div>
        <button class="btn-surprise" onclick="surpriseMe()" style="margin-top:0">
          <svg width="15" height="15" viewBox="0 0 16 16" fill="none"><path d="M2 8C2 4.7 4.7 2 8 2C10 2 11.8 3 13 4.5M14 8C14 11.3 11.3 14 8 14C6 14 4.2 13 3 11.5" stroke="white" stroke-width="1.5" stroke-linecap="round"/><path d="M13 1.5V5H9.5" stroke="white" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/><path d="M3 14.5V11H6.5" stroke="white" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/></svg>
          ${t('another')}
        </button>
      </div>`;
    scrim.classList.add('active');
    requestAnimationFrame(() => sheet.classList.add('active'));
    return;
  }

  // Fallback modal for lunch
  let badges = '';
  if (item.cuisine) badges += `<span class="badge badge-price">${esc(item.cuisine)}</span>`;
  if (item.openForLunch === true) badges += '<span class="badge badge-open">Open</span>';
  const modal = $('modal');
  modal.innerHTML = `<div class="modal-content">
    <button class="modal-close" onclick="closeModal()">&times;</button>
    <div class="modal-emoji">${emoji}</div>
    <div class="modal-title">${esc(name)}</div>
    <div class="modal-desc">${esc(desc || '')}</div>
    <div class="modal-badges">${badges}</div>
    <div class="modal-actions">
      <button class="btn-primary" onclick="surpriseLunch()">${t('another')}</button>
      ${item.lat ? `<button class="btn-secondary" onclick="window.open('${mapsUrl(item.lat, item.lon, name)}','_blank')">${t('directions')}</button>` : ''}
      ${item.url || item.website ? `<button class="btn-secondary" onclick="window.open('${esc(item.url || item.website)}','_blank')">${t('website')}</button>` : ''}
      <button class="btn-secondary" onclick="closeModal()">${t('close')}</button>
    </div>
  </div>`;
  modal.classList.add('active');
}

function closeSurpriseSheet() {
  document.querySelector('.surprise-sheet')?.classList.remove('active');
  document.querySelector('.surprise-sheet-scrim')?.classList.remove('active');
}

function closeModal() { $('modal').classList.remove('active'); }

// ═══ DONATE (Apple Pay) ═══

let stripeInstance = null;

function loadStripe() {
  return new Promise((resolve) => {
    if (window.Stripe) { resolve(); return; }
    const js = document.createElement('script');
    js.src = 'https://js.stripe.com/v3/';
    js.onload = resolve;
    js.onerror = () => resolve();
    document.head.appendChild(js);
  });
}

async function getStripe() {
  await loadStripe();
  if (!stripeInstance) stripeInstance = Stripe(STRIPE_PK);
  return stripeInstance;
}

async function checkDonateAvailability() {
  try {
    const stripe = await getStripe();
    const pr = stripe.paymentRequest({
      country: 'CH', currency: 'chf',
      total: { label: 'Donation', amount: 200 },
      requestPayerName: false, requestPayerEmail: false,
    });
    const result = await pr.canMakePayment();
    canDonate = !!(result && result.applePay);
    if (canDonate) renderMenu();
  } catch { canDonate = false; }
}

function openDonateModal() {
  closeMenu();
  let selectedAmount = 200;
  const modal = $('modal');
  modal.innerHTML = `<div class="modal-content">
    <button class="modal-close" onclick="closeModal()">&times;</button>
    <div class="modal-emoji">☕</div>
    <div class="modal-title">${t('donateTitle')}</div>
    <div class="modal-desc">${t('donateDesc')}</div>
    <div class="donate-amounts">
      <button class="donate-amount-btn" data-amount="100" onclick="selectDonateAmount(100)">CHF 1</button>
      <button class="donate-amount-btn active" data-amount="200" onclick="selectDonateAmount(200)">CHF 2</button>
      <button class="donate-amount-btn" data-amount="300" onclick="selectDonateAmount(300)">CHF 3</button>
      <button class="donate-amount-btn" data-amount="500" onclick="selectDonateAmount(500)">CHF 5</button>
    </div>
    <div class="donate-apple-pay-container" id="donate-apple-pay"></div>
    <div class="donate-status" id="donate-status"></div>
  </div>`;
  modal.classList.add('active');
  mountApplePayButton(selectedAmount);
}

function selectDonateAmount(amount) {
  document.querySelectorAll('.donate-amount-btn').forEach(b => {
    b.classList.toggle('active', Number(b.dataset.amount) === amount);
  });
  mountApplePayButton(amount);
}

async function mountApplePayButton(amount) {
  const container = $('donate-apple-pay');
  if (!container) return;
  container.innerHTML = '';
  $('donate-status').textContent = '';

  const stripe = await getStripe();
  const pr = stripe.paymentRequest({
    country: 'CH', currency: 'chf',
    total: { label: 'Znüni', amount },
    requestPayerName: false, requestPayerEmail: false,
  });

  pr.on('paymentmethod', async (ev) => {
    $('donate-status').textContent = t('donateProcessing');
    try {
      const res = await fetch(`${API}/donate`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ amount }),
      });
      const { clientSecret, error: apiErr } = await res.json();
      if (apiErr || !clientSecret) { ev.complete('fail'); $('donate-status').textContent = t('donateError'); return; }

      const { error } = await stripe.confirmCardPayment(clientSecret, { payment_method: ev.paymentMethod.id }, { handleActions: false });
      if (error) { ev.complete('fail'); $('donate-status').textContent = t('donateError'); }
      else {
        ev.complete('success');
        $('modal').innerHTML = `<div class="modal-content">
          <button class="modal-close" onclick="closeModal()">&times;</button>
          <div class="modal-emoji">❤️</div>
          <div class="modal-title">${t('donateThankYou')}</div>
          <div class="modal-actions"><button class="btn-primary" onclick="closeModal()">${t('close')}</button></div>
        </div>`;
      }
    } catch { ev.complete('fail'); $('donate-status').textContent = t('donateError'); }
  });

  const result = await pr.canMakePayment();
  if (result && result.applePay) {
    const elements = stripe.elements();
    const prButton = elements.create('paymentRequestButton', {
      paymentRequest: pr,
      style: { paymentRequestButton: { type: 'donate', theme: 'dark', height: '48px' } },
    });
    prButton.mount(container);
  }
}

// ═══ MAPS ═══

function loadLeaflet() {
  return new Promise((resolve) => {
    if (window.L) { resolve(); return; }
    const css = document.createElement('link');
    css.rel = 'stylesheet'; css.href = 'https://unpkg.com/leaflet@1.9.4/dist/leaflet.css';
    document.head.appendChild(css);
    const js = document.createElement('script');
    js.src = 'https://unpkg.com/leaflet@1.9.4/dist/leaflet.js';
    js.onload = resolve;
    js.onerror = () => resolve();
    document.head.appendChild(js);
  });
}

async function initActivityMap() {
  const el = $('activity-map');
  if (!el || !el.offsetParent) return;
  await loadLeaflet();
  if (!window.L) return;

  const center = CITY_COORDS[city] || CITY_COORDS.zurich;

  if (activityMap) activityMap.remove();
  activityMap = L.map(el).setView(center, 12);
  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', { attribution: '© OSM' }).addTo(activityMap);

  activityMarkers = {};
  const filtered = getFilteredActivities().filter(a => a.lat);
  for (const a of filtered) {
    const name = lang === 'de' ? (a.nameDE || a.name) : a.name;
    const marker = L.marker([a.lat, a.lon]).addTo(activityMap).bindPopup(`<b>${esc(name)}</b><br>${a.indoor ? 'Indoor' : 'Outdoor'} · ${a.duration || ''}`);
    marker.on('click', () => highlightCard(`activity-${a.id}`));
    activityMarkers[a.id] = marker;
  }
  if (userLat) L.marker([userLat, userLon], { icon: L.divIcon({ html: '📍', className: '', iconSize: [20, 20] }) }).addTo(activityMap);
}

async function initLunchMap() {
  const el = $('lunch-map');
  if (!el || !el.offsetParent) return;
  await loadLeaflet();
  if (!window.L) return;

  const center = CITY_COORDS[city] || CITY_COORDS.zurich;

  if (lunchMap) lunchMap.remove();
  lunchMap = L.map(el, { zoomControl: lunchMapExpanded, dragging: lunchMapExpanded, scrollWheelZoom: lunchMapExpanded }).setView(center, 14);
  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', { attribution: '© OSM' }).addTo(lunchMap);

  lunchMarkers = {};
  const spots = getFilteredLunchSpots().filter(s => s.lat);
  for (const s of spots.slice(0, 100)) {
    const marker = L.circleMarker([s.lat, s.lon], { radius: 5, fillColor: s.openForLunch ? MAP_COLORS.green : MAP_COLORS.muted, fillOpacity: .8, weight: 1, color: MAP_COLORS.white }).addTo(lunchMap).bindPopup(`<b>${esc(s.name)}</b><br>${s.cuisine || ''}`);
    marker.on('click', () => highlightCard(`lunch-${s.id}`));
    lunchMarkers[s.id] = marker;
  }
}

// ═══ SUNSHINE VIEW ═══

function getSunshineClass(totalHours) {
  if (totalHours > 6) return 'sunny';
  if (totalHours >= 3) return 'partly';
  return 'cloudy';
}

function getSunshineEmoji(totalHours) {
  if (totalHours > 6) return '☀️';
  if (totalHours >= 3) return '⛅';
  return '☁️';
}

function getBaselineDest() {
  return (sunshineData?.destinations || []).find(d => d.isBaseline) || null;
}

function getFilteredSunshineDests() {
  let dests = (sunshineData?.destinations || []).filter(d => !d.isBaseline);

  // Filter
  if (sunshineFilter === 'sunny') dests = dests.filter(d => d.sunshineHoursTotal > 6);
  else if (sunshineFilter === 'partly') dests = dests.filter(d => d.sunshineHoursTotal >= 3 && d.sunshineHoursTotal <= 6);
  else if (sunshineFilter === 'cloudy') dests = dests.filter(d => d.sunshineHoursTotal < 3);

  // Sort
  if (sunshineSort === 'distance' && userLat) {
    dests.sort((a, b) => haversine(userLat, userLon, a.lat, a.lon) - haversine(userLat, userLon, b.lat, b.lon));
  }
  // 'sunshine' sort is already the API default order

  return dests;
}

function renderSunshineView() {
  if (!sunshineData) return `<div class="loading-msg">${t('loading')}</div><div class="loading-skeleton">${'<div class="skeleton skeleton-line"></div>'.repeat(6)}</div>`;

  const allDests = sunshineData.destinations || [];
  if (allDests.length === 0) return `<div class="loading-msg">${t('noSunshineData')}</div>`;

  const wd = sunshineData.weekendDates || {};
  let html = '';

  // Map
  html += '<div class="map-container" id="sunshine-map" style="height:350px;"></div>';

  // Weekend date label
  const fmtDate = d => new Date(d + 'T12:00:00').toLocaleDateString(lang === 'de' ? 'de-CH' : 'en-CH', { weekday: 'short', day: 'numeric', month: 'short' });
  html += `<div class="sunshine-dates">${fmtDate(wd.friday)} — ${fmtDate(wd.sunday)}</div>`;

  // Legend
  html += `<div class="sunshine-legend">
    <div class="legend-item"><span class="legend-dot dot-baseline"></span>${t('yourCity')}</div>
    <div class="legend-item"><span class="legend-dot dot-sunny"></span>&gt;6h</div>
    <div class="legend-item"><span class="legend-dot dot-partly"></span>3-6h</div>
    <div class="legend-item"><span class="legend-dot dot-cloudy"></span>&lt;3h</div>
    <div class="legend-item"><span class="legend-bar-sample"></span>${lang === 'de' ? 'Sonnenstunden' : 'Sunny hours'}</div>
  </div>`;

  // Baseline card (Zürich) — always shown first
  const baseline = getBaselineDest();
  html += '<div class="sunshine-list">';
  if (baseline) html += renderSunshineCard(baseline, null);

  // "Nearest sunny escape" nudge — only when Zürich has < 6h sunshine
  if (baseline && baseline.sunshineHoursTotal < 6) {
    const allNonBaseline = (sunshineData?.destinations || []).filter(d => !d.isBaseline && d.sunshineHoursTotal > baseline.sunshineHoursTotal);
    allNonBaseline.sort((a, b) => a.driveMinutes - b.driveMinutes);
    const escape = allNonBaseline[0];
    if (escape) {
      const eName = lang === 'de' ? (escape.nameDE || escape.name) : escape.name;
      const eDrive = escape.driveMinutes >= 60
        ? `${Math.floor(escape.driveMinutes / 60)}h${escape.driveMinutes % 60 ? (escape.driveMinutes % 60 + 'min') : ''}`
        : `${escape.driveMinutes}min`;
      html += `<div class="sunshine-escape" onclick="sunshineCardClick('${escape.id}')">
        <span class="sunshine-escape-label">🚀 ${t('nearestEscape')}</span>
        <span class="sunshine-escape-dest"><b>${esc(eName)}</b> — ${escape.sunshineHoursTotal}${t('sunshineHours')} · 🚗 ${eDrive}</span>
      </div>`;
    }
  }

  // Ranked cards — show top 10 unless expanded
  const dests = getFilteredSunshineDests();
  const showCount = sunshineExpanded ? dests.length : Math.min(10, dests.length);
  if (dests.length === 0 && !baseline) {
    html += renderEmptyState('☀️', 'emptySunshine', 'emptySunshineHint');
  } else {
    for (let i = 0; i < showCount; i++) html += renderSunshineCard(dests[i], i + 1);
    if (!sunshineExpanded && dests.length > 10) {
      html += `<button class="sunshine-expand-btn" onclick="expandSunshineList()">
        ${lang === 'de' ? `Alle ${dests.length} Ziele anzeigen` : `Show all ${dests.length} destinations`} ▾
      </button>`;
    }
  }
  html += '</div>';

  return html;
}

function renderSunshineTimeline(sunnyHours) {
  // Show hours 6-20 as small segments
  let html = '<div class="sunshine-timeline">';
  for (let h = 6; h <= 20; h++) {
    const isSunny = sunnyHours && sunnyHours.includes(h);
    html += `<div class="timeline-slot${isSunny ? ' slot-sunny' : ''}" title="${h}:00"></div>`;
  }
  html += '</div>';
  return html;
}

function renderSunshineCard(d, rank) {
  const isBaseline = d.isBaseline;
  const name = lang === 'de' ? (d.nameDE || d.name) : d.name;
  const region = lang === 'de' ? (d.regionDE || d.region) : d.region;
  const cls = isBaseline ? 'baseline' : getSunshineClass(d.sunshineHoursTotal);
  const emoji = getSunshineEmoji(d.sunshineHoursTotal);
  const driveLabel = d.driveMinutes >= 60
    ? `${Math.floor(d.driveMinutes / 60)}h${d.driveMinutes % 60 ? (d.driveMinutes % 60 + 'min') : ''}`
    : `${d.driveMinutes}min`;
  const dist = userLat ? haversine(userLat, userLon, d.lat, d.lon) : null;

  const dayNames = [t('friday'), t('saturday').substring(0, 2), t('sunday').substring(0, 2)];

  let forecastHtml = '';
  if (d.forecast) {
    forecastHtml = '<div class="sunshine-days">';
    d.forecast.forEach((f, i) => {
      const rainBadge = f.precipMm > 0 ? `<div class="sunshine-day-rain">💧${f.precipMm}</div>` : '';
      forecastHtml += `<div class="sunshine-day">
        <div class="sunshine-day-label">${dayNames[i] || ''}</div>
        <div class="sunshine-day-icon">${WEATHER_ICONS[f.weatherCode] || '🌡️'}</div>
        <div class="sunshine-day-temp">${f.tempMax}°/${f.tempMin}°</div>
        <div class="sunshine-day-sun">☀️ ${f.sunshineHours}h</div>
        ${rainBadge}
        ${renderSunshineTimeline(f.sunnyHours)}
        <div class="timeline-labels"><span>6</span><span>13</span><span>20</span></div>
      </div>`;
    });
    forecastHtml += '</div>';
  }

  let badges;
  if (isBaseline) {
    badges = `<span class="sunshine-baseline-badge">📍 ${t('yourCity')}</span>`;
  } else {
    badges = `<span class="sunshine-drive-badge">🚗 ${driveLabel} ${t('driveFrom')}</span>`;
  }
  if (dist !== null && !isBaseline) badges += `<span class="sunshine-dist-badge">📍 ${formatDist(dist)}</span>`;

  const rankHtml = isBaseline ? '<div class="sunshine-rank sunshine-rank-baseline">📍</div>' : `<div class="sunshine-rank">${rank}</div>`;

  const summaryBadges = isBaseline
    ? `<span class="sunshine-badge-inline">📍 ${t('yourCity')}</span>`
    : `<span class="sunshine-badge-inline">🚗 ${driveLabel}</span>`;
  const distBadge = dist !== null && !isBaseline ? `<span class="sunshine-badge-inline">📍 ${formatDist(dist)}</span>` : '';

  return `<div class="sunshine-card sunshine-${cls}" id="sunshine-${d.id}" onclick="sunshineCardClick('${d.id}')" data-id="${d.id}">
    <div class="sunshine-card-header">
      ${rankHtml}
      <div class="sunshine-card-info">
        <div class="sunshine-card-name">${emoji} ${esc(name)}</div>
        <div class="sunshine-card-region">${esc(region)} ${summaryBadges}${distBadge}</div>
      </div>
      <div class="sunshine-card-total">
        <div class="sunshine-total-num">${d.sunshineHoursTotal}</div>
        <div class="sunshine-total-label">${t('sunshineHours')}</div>
      </div>
    </div>
    <div class="sunshine-card-body">
      <div class="dest-photo"><img src="${API}/photo/${d.id}" alt="${esc(name)}" loading="lazy" onerror="this.parentNode.style.display='none'"></div>
      <div class="sunshine-badges">${badges}</div>
      ${forecastHtml}
    </div>
    ${renderSunshineHighlights(d)}
  </div>`;
}

const SUNSHINE_DESTS = [
  { id:'zurich',name:'Zürich',nameDE:'Zürich',lat:47.3769,lon:8.5417,region:'Zürich',regionDE:'Zürich',driveMinutes:0,isBaseline:true },
  { id:'lugano',name:'Lugano',nameDE:'Lugano',lat:46.0037,lon:8.9511,region:'Ticino',regionDE:'Tessin',driveMinutes:150 },
  { id:'locarno',name:'Locarno',nameDE:'Locarno',lat:46.1711,lon:8.7953,region:'Ticino',regionDE:'Tessin',driveMinutes:160 },
  { id:'bellinzona',name:'Bellinzona',nameDE:'Bellinzona',lat:46.1955,lon:9.0234,region:'Ticino',regionDE:'Tessin',driveMinutes:140 },
  { id:'ascona',name:'Ascona',nameDE:'Ascona',lat:46.157,lon:8.7726,region:'Ticino',regionDE:'Tessin',driveMinutes:165 },
  { id:'chur',name:'Chur',nameDE:'Chur',lat:46.8499,lon:9.5329,region:'Graubünden',regionDE:'Graubünden',driveMinutes:80 },
  { id:'davos',name:'Davos',nameDE:'Davos',lat:46.8027,lon:9.836,region:'Graubünden',regionDE:'Graubünden',driveMinutes:115 },
  { id:'stmoritz',name:'St. Moritz',nameDE:'St. Moritz',lat:46.4908,lon:9.8355,region:'Graubünden',regionDE:'Graubünden',driveMinutes:150 },
  { id:'flims',name:'Flims',nameDE:'Flims',lat:46.8354,lon:9.2836,region:'Graubünden',regionDE:'Graubünden',driveMinutes:95 },
  { id:'sion',name:'Sion',nameDE:'Sitten',lat:46.233,lon:7.3597,region:'Valais',regionDE:'Wallis',driveMinutes:165 },
  { id:'brig',name:'Brig',nameDE:'Brig',lat:46.3138,lon:7.9877,region:'Valais',regionDE:'Wallis',driveMinutes:140 },
  { id:'zermatt',name:'Zermatt',nameDE:'Zermatt',lat:46.0207,lon:7.7491,region:'Valais',regionDE:'Wallis',driveMinutes:195 },
  { id:'luzern',name:'Lucerne',nameDE:'Luzern',lat:47.0502,lon:8.3093,region:'Central Switzerland',regionDE:'Zentralschweiz',driveMinutes:45 },
  { id:'interlaken',name:'Interlaken',nameDE:'Interlaken',lat:46.6863,lon:7.8632,region:'Bernese Oberland',regionDE:'Berner Oberland',driveMinutes:110 },
  { id:'engelberg',name:'Engelberg',nameDE:'Engelberg',lat:46.821,lon:8.4013,region:'Central Switzerland',regionDE:'Zentralschweiz',driveMinutes:65 },
  { id:'schwyz',name:'Schwyz',nameDE:'Schwyz',lat:47.0207,lon:8.6571,region:'Central Switzerland',regionDE:'Zentralschweiz',driveMinutes:40 },
  { id:'altdorf',name:'Altdorf',nameDE:'Altdorf',lat:46.8802,lon:8.6441,region:'Central Switzerland',regionDE:'Zentralschweiz',driveMinutes:50 },
  { id:'lausanne',name:'Lausanne',nameDE:'Lausanne',lat:46.5197,lon:6.6323,region:'Lake Geneva',regionDE:'Genfersee',driveMinutes:140 },
  { id:'montreux',name:'Montreux',nameDE:'Montreux',lat:46.4312,lon:6.9107,region:'Lake Geneva',regionDE:'Genfersee',driveMinutes:150 },
  { id:'vevey',name:'Vevey',nameDE:'Vevey',lat:46.4603,lon:6.8412,region:'Lake Geneva',regionDE:'Genfersee',driveMinutes:145 },
  { id:'basel',name:'Basel',nameDE:'Basel',lat:47.5596,lon:7.5886,region:'Northwestern Switzerland',regionDE:'Nordwestschweiz',driveMinutes:55 },
  { id:'solothurn',name:'Solothurn',nameDE:'Solothurn',lat:47.2088,lon:7.5378,region:'Northwestern Switzerland',regionDE:'Nordwestschweiz',driveMinutes:65 },
  { id:'delemont',name:'Delémont',nameDE:'Delémont',lat:47.3647,lon:7.3462,region:'Jura',regionDE:'Jura',driveMinutes:90 },
  { id:'konstanz',name:'Konstanz',nameDE:'Konstanz',lat:47.6633,lon:9.1753,region:'Lake Constance',regionDE:'Bodensee',driveMinutes:50 },
  { id:'lindau',name:'Lindau',nameDE:'Lindau',lat:47.546,lon:9.6829,region:'Lake Constance',regionDE:'Bodensee',driveMinutes:70 },
  { id:'como',name:'Como',nameDE:'Como',lat:45.8081,lon:9.0852,region:'Lake Como',regionDE:'Comer See',driveMinutes:155 },
  { id:'schaffhausen',name:'Schaffhausen',nameDE:'Schaffhausen',lat:47.696,lon:8.6342,region:'Eastern Switzerland',regionDE:'Ostschweiz',driveMinutes:35 },
  { id:'frauenfeld',name:'Frauenfeld',nameDE:'Frauenfeld',lat:47.5535,lon:8.8987,region:'Eastern Switzerland',regionDE:'Ostschweiz',driveMinutes:30 },
  { id:'rapperswil',name:'Rapperswil',nameDE:'Rapperswil',lat:47.2267,lon:8.8184,region:'Lake Zurich',regionDE:'Zürichsee',driveMinutes:25 },
];

// Highlights now come from sunshine API response (d.highlights array per destination)

// Mirrors getWeekendDates() in worker/src/sunshine.js — keep in sync
function getSunshineWeekendDates() {
  const now = new Date();
  const day = now.getDay();
  let friday;
  if (day === 5) friday = new Date(now);
  else if (day === 6) { friday = new Date(now); friday.setDate(friday.getDate() - 1); }
  else if (day === 0) { friday = new Date(now); friday.setDate(friday.getDate() - 2); }
  else { friday = new Date(now); friday.setDate(friday.getDate() + (5 - day)); }
  const sat = new Date(friday); sat.setDate(sat.getDate() + 1);
  const sun = new Date(friday); sun.setDate(sun.getDate() + 2);
  const fmt = d => d.toISOString().split('T')[0];
  return { friday: fmt(friday), saturday: fmt(sat), sunday: fmt(sun) };
}

async function fetchSunshineClientSide() {
  const wd = getSunshineWeekendDates();
  const dates = [wd.friday, wd.saturday, wd.sunday];
  const lats = SUNSHINE_DESTS.map(d => d.lat).join(',');
  const lons = SUNSHINE_DESTS.map(d => d.lon).join(',');
  const url = `https://api.open-meteo.com/v1/forecast?latitude=${lats}&longitude=${lons}&daily=weather_code,temperature_2m_max,temperature_2m_min,sunshine_duration,precipitation_sum&hourly=sunshine_duration&start_date=${wd.friday}&end_date=${wd.sunday}&timezone=Europe/Zurich`;

  const res = await fetch(url);
  if (!res.ok) return null;
  const raw = await res.json();
  const locations = Array.isArray(raw) ? raw : [raw];

  const WD = {0:'Clear sky',1:'Mainly clear',2:'Partly cloudy',3:'Overcast',45:'Foggy',48:'Foggy',51:'Light drizzle',53:'Drizzle',55:'Heavy drizzle',61:'Light rain',63:'Rain',65:'Heavy rain',71:'Light snow',73:'Snow',75:'Heavy snow',80:'Rain showers',81:'Rain showers',82:'Heavy showers',85:'Snow showers',86:'Heavy snow showers',95:'Thunderstorm',96:'Thunderstorm with hail',99:'Thunderstorm with hail'};

  const results = [];
  for (let i = 0; i < SUNSHINE_DESTS.length && i < locations.length; i++) {
    const loc = locations[i];
    if (!loc.daily?.time) continue;
    const hourlyMap = {};
    if (loc.hourly?.time) {
      loc.hourly.time.forEach((t, j) => {
        const date = t.substring(0, 10);
        const hour = parseInt(t.substring(11, 13), 10);
        if (hour >= 6 && hour <= 20 && (loc.hourly.sunshine_duration[j] || 0) > 0) {
          if (!hourlyMap[date]) hourlyMap[date] = [];
          hourlyMap[date].push(hour);
        }
      });
    }
    const forecast = loc.daily.time.filter(d => dates.includes(d)).map((date, di) => {
      const idx = loc.daily.time.indexOf(date);
      return {
        date,
        weatherCode: loc.daily.weather_code[idx],
        tempMax: loc.daily.temperature_2m_max[idx] != null ? Math.round(loc.daily.temperature_2m_max[idx]) : 0,
        tempMin: loc.daily.temperature_2m_min[idx] != null ? Math.round(loc.daily.temperature_2m_min[idx]) : 0,
        sunshineHours: Math.round((loc.daily.sunshine_duration[idx] || 0) / 360) / 10,
        precipMm: Math.round((loc.daily.precipitation_sum[idx] || 0) * 10) / 10,
        sunnyHours: hourlyMap[date] || [],
        description: WD[loc.daily.weather_code[idx]] || 'Unknown',
      };
    });
    const sunshineHoursTotal = Math.round(forecast.reduce((s, d) => s + d.sunshineHours, 0) * 10) / 10;
    results.push({ ...SUNSHINE_DESTS[i], forecast, sunshineHoursTotal });
  }
  results.sort((a, b) => {
    if (a.isBaseline) return -1;
    if (b.isBaseline) return 1;
    return b.sunshineHoursTotal - a.sunshineHoursTotal;
  });
  return { destinations: results, weekendDates: wd, timestamp: new Date().toISOString() };
}

async function loadSunshine(force = false) {
  const cacheKey = 'sunshineCache-v2';
  if (!force) {
    const cached = cache.get(cacheKey, 1800000);
    if (cached && cached.destinations?.length > 0) { sunshineData = cached; renderCurrentView(); afterRender(initSunshineMap); return; }
  }

  showLoading();
  try {
    // Try worker first
    const res = await fetch(`${API}/sunshine?lang=${lang}${force ? '&refresh=true' : ''}`);
    if (!res.ok) throw new Error(`Worker returned ${res.status}`);
    const data = await res.json();
    if (data.destinations?.length > 0) {
      sunshineData = data;
      cache.set(cacheKey, data);
      renderCurrentView();
      afterRender(initSunshineMap);
      hideLoading();
      return;
    }
  } catch (e) { console.error('Worker sunshine error:', e); }

  // Fallback: fetch directly from Open-Meteo (client-side)
  try {
    const data = await fetchSunshineClientSide();
    if (data) {
      sunshineData = data;
      cache.set(cacheKey, data);
      renderCurrentView();
      afterRender(initSunshineMap);
      hideLoading();
      return;
    }
  } catch (e) { console.error('Client sunshine error:', e); showToast('toastNetworkError', 'error'); }

  hideLoading();
  if (!sunshineData) {
    const vEl = $('view-sunshine');
    if (vEl) vEl.innerHTML = '<div class="loading-msg">Failed to load sunshine data.</div>';
  }
}

async function initSunshineMap() {
  const el = $('sunshine-map');
  if (!el || !el.offsetParent) return;
  await loadLeaflet();
  if (!window.L) return;

  if (sunshineMap) sunshineMap.remove();
  sunshineMap = L.map(el).setView([46.8, 8.2], 7);
  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', { attribution: '© OSM' }).addTo(sunshineMap);

  if (!sunshineData?.destinations) return;

  sunshineMarkers = {};
  for (const d of sunshineData.destinations) {
    const name = lang === 'de' ? (d.nameDE || d.name) : d.name;
    let marker;

    if (d.isBaseline) {
      marker = L.circleMarker([d.lat, d.lon], {
        radius: 12,
        fillColor: MAP_COLORS.purple,
        fillOpacity: 0.9,
        weight: 3,
        color: MAP_COLORS.white,
      }).addTo(sunshineMap).bindPopup(`<b>${esc(name)}</b> (${t('yourCity')})<br>${d.sunshineHoursTotal}${t('sunshineHours')}<br>${getSunshineEmoji(d.sunshineHoursTotal)}`);
    } else {
      const cls = getSunshineClass(d.sunshineHoursTotal);
      const color = cls === 'sunny' ? MAP_COLORS.amber : cls === 'partly' ? MAP_COLORS.sky : MAP_COLORS.gray;
      const radius = Math.max(8, Math.min(18, 8 + d.sunshineHoursTotal));

      marker = L.circleMarker([d.lat, d.lon], {
        radius,
        fillColor: color,
        fillOpacity: 0.85,
        weight: 2,
        color: MAP_COLORS.white,
      }).addTo(sunshineMap).bindPopup(`<b>${esc(name)}</b><br>${d.sunshineHoursTotal}${t('sunshineHours')}<br>${getSunshineEmoji(d.sunshineHoursTotal)}`);
    }
    marker.on('click', () => highlightCard(`sunshine-${d.id}`));
    sunshineMarkers[d.id] = marker;
  }
}

function renderSunshineHighlights(d) {
  if (d.isBaseline) return '';
  const highlights = d.highlights || [];
  const isActivityCity = ['basel', 'lausanne', 'luzern'].includes(d.id);
  if (!highlights.length && !isActivityCity) return '';
  const name = lang === 'de' ? (d.nameDE || d.name) : d.name;
  let html = `<div class="sunshine-highlights">
    <div class="sunshine-highlights-title">${t('thingsToDo')}</div>
    ${highlights.map(h => renderHighlightItem(h)).join('')}`;
  if (isActivityCity) {
    html += `<div class="sunshine-link" onclick="event.stopPropagation();setCity('${d.id}');switchView('activities')">${t('seeAllActivities')} →</div>`;
  }
  html += `<div class="sunshine-links">
    <a href="https://www.google.com/maps/search/playground/@${d.lat},${d.lon},14z" target="_blank" onclick="event.stopPropagation()">🛝 ${t('findPlaygrounds')} ↗</a>
    <a href="https://www.google.com/maps/search/restaurant/@${d.lat},${d.lon},14z" target="_blank" onclick="event.stopPropagation()">🍽️ ${t('findRestaurants')} ↗</a>
  </div></div>`;
  return html;
}

function renderHighlightItem(h) {
  const name = lang === 'de' ? (h.nameDE || h.name) : h.name;
  const desc = lang === 'de' ? (h.descDE || h.desc) : h.desc;
  const emoji = ACTIVITY_EMOJIS[h.cat] || '📍';
  const badge = h.indoor ? t('indoor') : t('outdoor');
  return `<div class="sunshine-highlight">
    <div class="sunshine-highlight-name">${emoji} ${esc(name)}</div>
    <div class="sunshine-highlight-desc">${esc(desc)}</div>
    <div class="sunshine-highlight-actions">
      <span class="badge badge-${h.indoor ? 'indoor' : 'outdoor'}">${badge}</span>
      <a href="${mapsUrl(h.lat, h.lon, name)}" target="_blank" onclick="event.stopPropagation()">${t('directions')} ↗</a>
    </div>
  </div>`;
}

function sunshineCardClick(id) {
  // Accordion: collapse other expanded cards
  document.querySelectorAll('.sunshine-card.expanded').forEach(c => {
    if (c.dataset.id !== id) c.classList.remove('expanded');
  });
  const card = document.getElementById(`sunshine-${id}`);
  if (card) card.classList.toggle('expanded');
  if (sunshineMap) panToMarker(sunshineMarkers, id, sunshineMap, 10);
}

function setSunshineFilter(f) {
  sunshineFilter = f;
  sunshineExpanded = false;
  renderHeader();
  renderCurrentView();
  afterRender(initSunshineMap);
}

function setSunshineSort(s) {
  if (s === 'distance' && !userLat) {
    navigator.geolocation?.getCurrentPosition(pos => {
      userLat = pos.coords.latitude;
      userLon = pos.coords.longitude;
      sunshineSort = 'distance';
      renderHeader();
      renderCurrentView();
      afterRender(initSunshineMap);
    }, () => {}, { enableHighAccuracy: true });
    return;
  }
  sunshineSort = s;
  renderHeader();
  renderCurrentView();
  afterRender(initSunshineMap);
}

function expandSunshineList() {
  sunshineExpanded = true;
  renderCurrentView();
  afterRender(initSunshineMap);
}

// ═══ SNOW VIEW ═══

const SNOW_DESTS = [
  { id:'zermatt',name:'Zermatt',nameDE:'Zermatt',lat:46.0207,lon:7.7491,region:'Valais',regionDE:'Wallis',driveMinutes:195,altitude:1620 },
  { id:'verbier',name:'Verbier',nameDE:'Verbier',lat:46.0967,lon:7.2286,region:'Valais',regionDE:'Wallis',driveMinutes:170,altitude:1500 },
  { id:'saas-fee',name:'Saas-Fee',nameDE:'Saas-Fee',lat:46.1048,lon:7.9329,region:'Valais',regionDE:'Wallis',driveMinutes:185,altitude:1800 },
  { id:'crans-montana',name:'Crans-Montana',nameDE:'Crans-Montana',lat:46.3072,lon:7.4816,region:'Valais',regionDE:'Wallis',driveMinutes:175,altitude:1500 },
  { id:'nendaz',name:'Nendaz',nameDE:'Nendaz',lat:46.1871,lon:7.3041,region:'Valais',regionDE:'Wallis',driveMinutes:165,altitude:1400 },
  { id:'davos',name:'Davos',nameDE:'Davos',lat:46.8027,lon:9.836,region:'Graubunden',regionDE:'Graubünden',driveMinutes:115,altitude:1560 },
  { id:'stmoritz',name:'St. Moritz',nameDE:'St. Moritz',lat:46.4908,lon:9.8355,region:'Graubunden',regionDE:'Graubünden',driveMinutes:150,altitude:1822 },
  { id:'laax',name:'Laax',nameDE:'Laax',lat:46.8097,lon:9.2579,region:'Graubunden',regionDE:'Graubünden',driveMinutes:100,altitude:1100 },
  { id:'arosa',name:'Arosa',nameDE:'Arosa',lat:46.7832,lon:9.678,region:'Graubunden',regionDE:'Graubünden',driveMinutes:110,altitude:1775 },
  { id:'lenzerheide',name:'Lenzerheide',nameDE:'Lenzerheide',lat:46.7394,lon:9.5584,region:'Graubunden',regionDE:'Graubünden',driveMinutes:95,altitude:1473 },
  { id:'klosters',name:'Klosters',nameDE:'Klosters',lat:46.8683,lon:9.8756,region:'Graubunden',regionDE:'Graubünden',driveMinutes:110,altitude:1191 },
  { id:'grindelwald',name:'Grindelwald',nameDE:'Grindelwald',lat:46.6244,lon:8.0413,region:'Bernese Oberland',regionDE:'Berner Oberland',driveMinutes:130,altitude:1034 },
  { id:'wengen',name:'Wengen',nameDE:'Wengen',lat:46.6082,lon:7.9222,region:'Bernese Oberland',regionDE:'Berner Oberland',driveMinutes:140,altitude:1274 },
  { id:'adelboden',name:'Adelboden',nameDE:'Adelboden',lat:46.4917,lon:7.5611,region:'Bernese Oberland',regionDE:'Berner Oberland',driveMinutes:125,altitude:1353 },
  { id:'gstaad',name:'Gstaad',nameDE:'Gstaad',lat:46.475,lon:7.2861,region:'Bernese Oberland',regionDE:'Berner Oberland',driveMinutes:145,altitude:1050 },
  { id:'engelberg',name:'Engelberg',nameDE:'Engelberg',lat:46.821,lon:8.4013,region:'Central Switzerland',regionDE:'Zentralschweiz',driveMinutes:65,altitude:1000 },
  { id:'andermatt',name:'Andermatt',nameDE:'Andermatt',lat:46.6343,lon:8.5936,region:'Central Switzerland',regionDE:'Zentralschweiz',driveMinutes:85,altitude:1444 },
  { id:'stoos',name:'Stoos',nameDE:'Stoos',lat:46.9767,lon:8.6625,region:'Central Switzerland',regionDE:'Zentralschweiz',driveMinutes:55,altitude:1300 },
  { id:'flumserberg',name:'Flumserberg',nameDE:'Flumserberg',lat:47.0912,lon:9.2739,region:'Eastern Switzerland',regionDE:'Ostschweiz',driveMinutes:60,altitude:1220 },
  { id:'hoch-ybrig',name:'Hoch-Ybrig',nameDE:'Hoch-Ybrig',lat:47.031,lon:8.789,region:'Central Switzerland',regionDE:'Zentralschweiz',driveMinutes:50,altitude:1100 },
  { id:'braunwald',name:'Braunwald',nameDE:'Braunwald',lat:46.9412,lon:8.9998,region:'Eastern Switzerland',regionDE:'Ostschweiz',driveMinutes:70,altitude:1256 },
  { id:'sattel-hochstuckli',name:'Sattel-Hochstuckli',nameDE:'Sattel-Hochstuckli',lat:47.08,lon:8.63,region:'Central Switzerland',regionDE:'Zentralschweiz',driveMinutes:40,altitude:1170 },
];

function getSnowClass(totalCm) {
  if (totalCm > 30) return 'heavy';
  if (totalCm >= 10) return 'moderate';
  return 'light';
}

function getSnowEmoji(totalCm) {
  if (totalCm > 30) return '🏔️';
  if (totalCm >= 10) return '❄️';
  return '🌨️';
}

function getFilteredSnowDests() {
  let dests = (snowData?.destinations || []).slice();
  if (snowFilter === 'heavy') dests = dests.filter(d => d.snowfallWeekTotal > 30);
  else if (snowFilter === 'moderate') dests = dests.filter(d => d.snowfallWeekTotal >= 10 && d.snowfallWeekTotal <= 30);
  else if (snowFilter === 'light') dests = dests.filter(d => d.snowfallWeekTotal < 10);

  if (snowSort === 'distance' && userLat) {
    dests.sort((a, b) => haversine(userLat, userLon, a.lat, a.lon) - haversine(userLat, userLon, b.lat, b.lon));
  }
  // 'snowfall' sort is the API default order
  return dests;
}

function renderSnowView() {
  if (!snowData) return `<div class="loading-msg">${t('loading')}</div><div class="loading-skeleton">${'<div class="skeleton skeleton-line"></div>'.repeat(6)}</div>`;

  const allDests = snowData.destinations || [];
  if (allDests.length === 0) return `<div class="loading-msg">${t('noSnowData')}</div>`;

  const wd = snowData.weekDates || {};
  let html = '';

  // Map
  html += '<div class="map-container" id="snow-map" style="height:350px;"></div>';

  // Week date label
  const fmtDate = d => new Date(d + 'T12:00:00').toLocaleDateString(lang === 'de' ? 'de-CH' : 'en-CH', { weekday: 'short', day: 'numeric', month: 'short' });
  html += `<div class="snow-dates">${t('weekOf')} ${fmtDate(wd.monday)} — ${fmtDate(wd.sunday)}</div>`;

  // Legend
  html += `<div class="snow-legend">
    <div class="legend-item"><span class="legend-dot snow-dot-heavy"></span>&gt;30cm</div>
    <div class="legend-item"><span class="legend-dot snow-dot-moderate"></span>10-30cm</div>
    <div class="legend-item"><span class="legend-dot snow-dot-light"></span>&lt;10cm</div>
  </div>`;

  // Fresh powder nudge — if top resort has >40cm
  const topDest = allDests[0];
  if (topDest && topDest.snowfallWeekTotal > 40) {
    const tName = lang === 'de' ? (topDest.nameDE || topDest.name) : topDest.name;
    const tDrive = topDest.driveMinutes >= 60
      ? `${Math.floor(topDest.driveMinutes / 60)}h${topDest.driveMinutes % 60 ? (topDest.driveMinutes % 60 + 'min') : ''}`
      : `${topDest.driveMinutes}min`;
    html += `<div class="snow-powder-alert" onclick="snowCardClick('${topDest.id}')">
      <span class="snow-powder-label">🏔️ ${t('freshPowder')}</span>
      <span class="snow-powder-dest"><b>${esc(tName)}</b> — ${topDest.snowfallWeekTotal}${t('snowfallCm')} · 🚗 ${tDrive}</span>
    </div>`;
  }

  // Ranked cards
  html += '<div class="snow-list">';
  const dests = getFilteredSnowDests();
  const showCount = snowExpanded ? dests.length : Math.min(10, dests.length);
  if (dests.length === 0) {
    html += renderEmptyState('❄️', 'emptySnow', 'emptySnowHint');
  } else {
    for (let i = 0; i < showCount; i++) html += renderSnowCard(dests[i], i + 1);
    if (!snowExpanded && dests.length > 10) {
      html += `<button class="snow-expand-btn" onclick="expandSnowList()">
        ${lang === 'de' ? `Alle ${dests.length} Gebiete anzeigen` : `Show all ${dests.length} resorts`} ▾
      </button>`;
    }
  }
  html += '</div>';

  return html;
}

function renderSnowCard(d, rank) {
  const name = lang === 'de' ? (d.nameDE || d.name) : d.name;
  const region = lang === 'de' ? (d.regionDE || d.region) : d.region;
  const cls = getSnowClass(d.snowfallWeekTotal);
  const emoji = getSnowEmoji(d.snowfallWeekTotal);
  const driveLabel = d.driveMinutes >= 60
    ? `${Math.floor(d.driveMinutes / 60)}h${d.driveMinutes % 60 ? (d.driveMinutes % 60 + 'min') : ''}`
    : `${d.driveMinutes}min`;
  const dist = userLat ? haversine(userLat, userLon, d.lat, d.lon) : null;

  const dayNames = [
    lang === 'de' ? 'Mo' : 'Mon',
    lang === 'de' ? 'Di' : 'Tue',
    lang === 'de' ? 'Mi' : 'Wed',
    lang === 'de' ? 'Do' : 'Thu',
    lang === 'de' ? 'Fr' : 'Fri',
    lang === 'de' ? 'Sa' : 'Sat',
    lang === 'de' ? 'So' : 'Sun',
  ];

  // Find max daily snowfall for bar scaling
  const maxDaily = d.forecast ? Math.max(...d.forecast.map(f => f.snowfallCm), 1) : 1;

  let forecastHtml = '';
  if (d.forecast) {
    forecastHtml = '<div class="snow-days">';
    d.forecast.forEach((f, i) => {
      const barHeight = Math.round((f.snowfallCm / maxDaily) * 32);
      forecastHtml += `<div class="snow-day">
        <div class="snow-day-label">${dayNames[i] || ''}</div>
        <div class="snow-day-icon">${WEATHER_ICONS[f.weatherCode] || '🌡️'}</div>
        <div class="snow-day-temp">${f.tempMax}°/${f.tempMin}°</div>
        <div class="snow-day-bar-wrap"><div class="snow-day-bar" style="height:${barHeight}px">${f.snowfallCm > 0 ? f.snowfallCm : ''}</div></div>
      </div>`;
    });
    forecastHtml += '</div>';
  }

  let badges = `<span class="snow-drive-badge">🚗 ${driveLabel} ${t('driveFrom')}</span>`;
  badges += `<span class="snow-altitude-badge">⛰️ ${d.altitude}${t('altitudeM')}</span>`;
  if (d.snowDepthCm > 0) badges += `<span class="snow-depth-badge">📏 ${d.snowDepthCm}cm ${t('snowDepth')}</span>`;
  if (dist !== null) badges += `<span class="snow-dist-badge">📍 ${formatDist(dist)}</span>`;

  const summarySnowBadges = `<span class="sunshine-badge-inline">🚗 ${driveLabel}</span><span class="sunshine-badge-inline">⛰️ ${d.altitude}m</span>`;
  const distSnowBadge = dist !== null ? `<span class="sunshine-badge-inline">📍 ${formatDist(dist)}</span>` : '';

  return `<div class="snow-card snow-${cls}" id="snow-${d.id}" onclick="snowCardClick('${d.id}')" data-id="${d.id}">
    <div class="snow-card-header">
      <div class="snow-rank">${rank}</div>
      <div class="snow-card-info">
        <div class="snow-card-name">${emoji} ${esc(name)}</div>
        <div class="snow-card-region">${esc(region)} ${summarySnowBadges}${distSnowBadge}</div>
      </div>
      <div class="snow-card-total">
        <div class="snow-total-num">${d.snowfallWeekTotal}</div>
        <div class="snow-total-label">${t('snowfallCm')}</div>
      </div>
    </div>
    <div class="snow-card-body">
      <div class="dest-photo"><img src="${API}/photo/${d.id}" alt="${esc(name)}" loading="lazy" onerror="this.parentNode.style.display='none'"></div>
      <div class="snow-badges">${badges}</div>
      ${forecastHtml}
    </div>
  </div>`;
}

function snowCardClick(id) {
  document.querySelectorAll('.snow-card.expanded').forEach(c => {
    if (c.dataset.id !== id) c.classList.remove('expanded');
  });
  const card = document.getElementById(`snow-${id}`);
  if (card) card.classList.toggle('expanded');
  if (snowMap) panToMarker(snowMarkers, id, snowMap, 10);
}

function setSnowFilter(f) {
  snowFilter = f;
  snowExpanded = false;
  renderHeader();
  renderCurrentView();
  afterRender(initSnowMap);
}

function setSnowSort(s) {
  if (s === 'distance' && !userLat) {
    navigator.geolocation?.getCurrentPosition(pos => {
      userLat = pos.coords.latitude;
      userLon = pos.coords.longitude;
      snowSort = 'distance';
      renderHeader();
      renderCurrentView();
      afterRender(initSnowMap);
    }, () => {}, { enableHighAccuracy: true });
    return;
  }
  snowSort = s;
  renderHeader();
  renderCurrentView();
  afterRender(initSnowMap);
}

function expandSnowList() {
  snowExpanded = true;
  renderCurrentView();
  afterRender(initSnowMap);
}

function getSnowWeekDates() {
  const now = new Date();
  const day = now.getDay();
  const monday = new Date(now);
  monday.setDate(now.getDate() - ((day + 6) % 7));
  const sunday = new Date(monday);
  sunday.setDate(monday.getDate() + 6);
  const fmt = d => d.toISOString().split('T')[0];
  return { monday: fmt(monday), sunday: fmt(sunday) };
}

async function fetchSnowClientSide() {
  const wd = getSnowWeekDates();
  const lats = SNOW_DESTS.map(d => d.lat).join(',');
  const lons = SNOW_DESTS.map(d => d.lon).join(',');
  const url = `https://api.open-meteo.com/v1/forecast?latitude=${lats}&longitude=${lons}&daily=snowfall_sum,weather_code,temperature_2m_max,temperature_2m_min&hourly=snow_depth&start_date=${wd.monday}&end_date=${wd.sunday}&timezone=Europe/Zurich`;

  const res = await fetch(url);
  if (!res.ok) return null;
  const raw = await res.json();
  const locations = Array.isArray(raw) ? raw : [raw];

  const WD = {0:'Clear sky',1:'Mainly clear',2:'Partly cloudy',3:'Overcast',45:'Foggy',48:'Foggy',51:'Light drizzle',53:'Drizzle',55:'Heavy drizzle',61:'Light rain',63:'Rain',65:'Heavy rain',71:'Light snow',73:'Snow',75:'Heavy snow',80:'Rain showers',81:'Rain showers',82:'Heavy showers',85:'Snow showers',86:'Heavy snow showers',95:'Thunderstorm',96:'Thunderstorm with hail',99:'Thunderstorm with hail'};

  const results = [];
  for (let i = 0; i < SNOW_DESTS.length && i < locations.length; i++) {
    const loc = locations[i];
    if (!loc.daily?.time) continue;
    const forecast = loc.daily.time.map((date, di) => ({
      date,
      snowfallCm: Math.round((loc.daily.snowfall_sum[di] || 0) * 10) / 10,
      weatherCode: loc.daily.weather_code[di],
      tempMax: loc.daily.temperature_2m_max[di] != null ? Math.round(loc.daily.temperature_2m_max[di]) : 0,
      tempMin: loc.daily.temperature_2m_min[di] != null ? Math.round(loc.daily.temperature_2m_min[di]) : 0,
      description: WD[loc.daily.weather_code[di]] || 'Unknown',
    }));
    const snowfallWeekTotal = Math.round(forecast.reduce((s, d) => s + d.snowfallCm, 0) * 10) / 10;
    let snowDepthCm = 0;
    if (loc.hourly?.snow_depth) {
      const maxD = Math.max(...loc.hourly.snow_depth.filter(v => v != null));
      if (isFinite(maxD)) snowDepthCm = Math.round(maxD * 100);
    }
    results.push({ ...SNOW_DESTS[i], forecast, snowfallWeekTotal, snowDepthCm });
  }
  results.sort((a, b) => b.snowfallWeekTotal - a.snowfallWeekTotal);
  return { destinations: results, weekDates: wd, timestamp: new Date().toISOString() };
}

async function loadSnow(force = false) {
  const cacheKey = 'snowCache-v1';
  if (!force) {
    const cached = cache.get(cacheKey, 1800000);
    if (cached && cached.destinations?.length > 0) { snowData = cached; renderCurrentView(); afterRender(initSnowMap); return; }
  }

  showLoading();
  try {
    const res = await fetch(`${API}/snow?lang=${lang}${force ? '&refresh=true' : ''}`);
    if (!res.ok) throw new Error(`Worker returned ${res.status}`);
    const data = await res.json();
    if (data.destinations?.length > 0) {
      snowData = data;
      cache.set(cacheKey, data);
      renderCurrentView();
      afterRender(initSnowMap);
      hideLoading();
      return;
    }
  } catch (e) { console.error('Worker snow error:', e); }

  try {
    const data = await fetchSnowClientSide();
    if (data) {
      snowData = data;
      cache.set(cacheKey, data);
      renderCurrentView();
      afterRender(initSnowMap);
      hideLoading();
      return;
    }
  } catch (e) { console.error('Client snow error:', e); showToast('toastNetworkError', 'error'); }

  hideLoading();
  if (!snowData) {
    const vEl = $('view-snow');
    if (vEl) vEl.innerHTML = '<div class="loading-msg">Failed to load snow data.</div>';
  }
}

async function initSnowMap() {
  const el = $('snow-map');
  if (!el || !el.offsetParent) return;
  await loadLeaflet();
  if (!window.L) return;

  if (snowMap) snowMap.remove();
  snowMap = L.map(el).setView([46.8, 8.2], 7);
  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', { attribution: '© OSM' }).addTo(snowMap);

  if (!snowData?.destinations) return;

  snowMarkers = {};
  for (const d of snowData.destinations) {
    const name = lang === 'de' ? (d.nameDE || d.name) : d.name;
    const cls = getSnowClass(d.snowfallWeekTotal);
    const color = cls === 'heavy' ? MAP_COLORS.navy : cls === 'moderate' ? MAP_COLORS.sky : MAP_COLORS.slate;
    const radius = Math.max(8, Math.min(25, 8 + d.snowfallWeekTotal / 2));

    const marker = L.circleMarker([d.lat, d.lon], {
      radius,
      fillColor: color,
      fillOpacity: 0.8,
      weight: 2,
      color: MAP_COLORS.white,
    }).addTo(snowMap).bindPopup(`<b>${esc(name)}</b><br>${d.snowfallWeekTotal}${t('snowfallCm')}<br>${getSnowEmoji(d.snowfallWeekTotal)}`);
    marker.on('click', () => highlightCard(`snow-${d.id}`));
    snowMarkers[d.id] = marker;
  }
}

// ═══ DEALS VIEW ═══

async function loadDeals() {
  if (dealsData.length > 0) return;
  try {
    const cached = localStorage.getItem('dealsCache');
    if (cached) {
      const parsed = JSON.parse(cached);
      if (parsed.deals?.length) { dealsData = parsed.deals; renderCurrentView(); }
    }
    const res = await fetch(`${API}/deals`);
    if (res.ok) {
      const data = await res.json();
      if (data.deals?.length) {
        dealsData = data.deals;
        localStorage.setItem('dealsCache', JSON.stringify(data));
        renderCurrentView();
      }
    }
  } catch {}
}

function renderDealsView() {
  const currentMonth = new Date().getMonth() + 1;
  let html = '';

  // Filter deals
  let items = dealsData.filter(d => {
    // Filter by valid months
    if (d.validMonths && !d.validMonths.includes(currentMonth)) return false;
    // Filter by city
    if (d.city !== 'all' && d.city !== city) return false;
    return true;
  });

  if (dealsFilter !== 'all') {
    items = items.filter(d => d.type === dealsFilter);
  }

  if (items.length === 0) {
    html += renderEmptyState('🎁', 'emptyDeals', 'emptyDealsHint');
  } else {
    html += '<div class="deals-list">';
    for (const d of items) html += renderDealCard(d);
    html += '</div>';
  }

  return html;
}

function renderDealCard(d) {
  const name = lang === 'de' ? (d.nameDE || d.name) : d.name;
  const desc = lang === 'de' ? (d.descriptionDE || d.description) : d.description;
  const emoji = DEAL_CATEGORY_EMOJIS[d.category] || '🎁';
  const typeLabel = d.type === 'free' ? t('freeEntry') : d.type === 'deal' ? t('deal') : t('tip');
  const typeCls = d.type === 'free' ? 'deal-type-free' : d.type === 'deal' ? 'deal-type-deal' : 'deal-type-tip';

  let badges = `<span class="deal-type-badge ${typeCls}">${typeLabel}</span>`;
  if (d.savings && d.savings !== 'Free') badges += `<span class="deal-savings-badge">💰 ${esc(d.savings)}</span>`;
  if (d.recurring) badges += `<span class="deal-recurring-badge">🔄 ${esc(d.recurring)}</span>`;

  return `<div class="deal-card" onclick="${safeUrl(d.url) ? `window.open('${esc(d.url)}','_blank')` : ''}">
    <div class="deal-card-header">
      <span class="deal-emoji">${emoji}</span>
      <div class="deal-card-title">${esc(name)}</div>
    </div>
    <div class="deal-card-desc">${esc(desc)}</div>
    <div class="deal-card-badges">${badges}</div>
  </div>`;
}

function filterDeals(f) { dealsFilter = f; renderHeader(); renderCurrentView(); }

// ═══ DAY DETAIL (integrated into Events view) ═══

function renderDayDetailSection(titleKey, icon, content) {
  return `<div class="day-detail-section">
    <div class="day-detail-section-header">
      <span class="day-detail-section-icon">${icon}</span>
      <span class="day-detail-section-title">${t(titleKey)}</span>
    </div>
    ${content}
  </div>`;
}

function renderDayFestivalCard(f) {
  const name = lang === 'de' ? (f.nameDE || f.name) : f.name;
  const desc = lang === 'de' ? (f.descriptionDE || f.description || '') : (f.description || '');
  const dateRange = f.startDate === f.endDate || !f.endDate
    ? f.startDate
    : `${f.startDate} — ${f.endDate}`;
  let badges = '';
  if (f.toddlerFriendly) badges += '<span class="badge badge-indoor">👶 Toddler-friendly</span>';
  if (f.free) badges += '<span class="badge badge-outdoor">🆓 Free</span>';
  return `<div class="day-detail-festival" onclick="${safeUrl(f.url) ? `window.open('${esc(f.url)}','_blank')` : ''}">
    <div class="day-detail-festival-name">${esc(name)}</div>
    <div class="day-detail-festival-desc">${esc(desc)}</div>
    <div class="day-detail-festival-meta">
      <span class="day-detail-festival-date">📅 ${dateRange}</span>
      ${badges}
    </div>
  </div>`;
}

function renderDayActivityCard(a) {
  const name = lang === 'de' ? (a.nameDE || a.name) : a.name;
  const emoji = ACTIVITY_EMOJIS[a.category] || '📍';
  let badges = '';
  if (a.indoor) badges += `<span class="badge badge-indoor">${t('indoor')}</span>`;
  else badges += `<span class="badge badge-outdoor">${t('outdoor')}</span>`;
  if (a.recurring) badges += `<span class="badge-recurring">${esc(a.recurring)}</span>`;
  if (a.duration) badges += `<span class="badge badge-duration">${esc(a.duration)}</span>`;
  return `<div class="day-detail-activity" onclick="switchView('activities')">
    <div class="day-detail-activity-name"><span class="activity-emoji">${emoji}</span> ${esc(name)}</div>
    <div class="day-detail-activity-badges">${badges}</div>
  </div>`;
}

function renderDayDetail(dateStr) {
  const selDate = new Date(dateStr + 'T00:00:00');
  const todayStr = new Date().toISOString().split('T')[0];
  const isToday = dateStr === todayStr;
  const dow = selDate.getDay();

  // Date label
  const dateLabel = selDate.toLocaleDateString(lang === 'de' ? 'de-CH' : 'en-CH', { weekday: 'long', day: 'numeric', month: 'long' });
  let html = `<div class="day-detail-date">${dateLabel}</div>`;

  // Weather (today only)
  if (isToday && newsData?.weather) {
    const w = newsData.weather;
    const isBad = RAINY_CODES.includes(w.weatherCode) || w.temperature < 5;
    const rec = isBad ? t('stayIndoorRec') : t('goOutdoorRec');
    html += `<div class="day-detail-weather" onclick="switchView('news')">
      <div class="day-detail-weather-main">
        <span class="day-detail-weather-icon">${WEATHER_ICONS[w.weatherCode] || '🌡️'}</span>
        <span class="day-detail-weather-temp">${w.temperature}°</span>
        <span class="day-detail-weather-desc">${esc(w.description || '')}</span>
      </div>
      <span class="day-detail-weather-rec">${rec}</span>
    </div>`;
  }

  let sections = '';

  // Holidays on this date
  if (newsData?.holidays) {
    const dayHolidays = newsData.holidays.filter(h => h.date === dateStr);
    if (dayHolidays.length) {
      const holidayHtml = dayHolidays.map(h => {
        const name = lang === 'de' ? (h.nameDE || h.name) : h.name;
        return `<div class="day-detail-holiday">🎉 ${esc(name)}</div>`;
      }).join('');
      sections += renderDayDetailSection('holidayToday', '🏳️', holidayHtml);
    }
  }

  // School holidays overlapping this date
  if (newsData?.schoolHolidays) {
    const daySchoolHols = newsData.schoolHolidays.filter(sh => {
      const start = new Date(sh.startDate);
      const end = new Date(sh.endDate);
      return selDate >= start && selDate <= end;
    });
    if (daySchoolHols.length) {
      const shHtml = daySchoolHols.map(sh => {
        const name = lang === 'de' ? (sh.nameDE || sh.name) : sh.name;
        return `<div class="day-detail-school-holiday">🎒 ${esc(name)} <span class="day-detail-school-holiday-dates">${sh.startDate} — ${sh.endDate}</span></div>`;
      }).join('');
      sections += renderDayDetailSection('schoolHolidayBanner', '🎒', shHtml);
    }
  }

  // Festivals overlapping this date
  const festivals = cityEventsData.filter(f => {
    const start = new Date(f.startDate);
    const end = f.endDate ? new Date(f.endDate) : start;
    return selDate >= start && selDate <= end;
  });
  if (festivals.length) {
    sections += renderDayDetailSection(
      isToday ? 'happeningToday' : 'happeningOn',
      '🎪',
      festivals.map(f => renderDayFestivalCard(f)).join('')
    );
  }

  // Recurring activities available on this day-of-week
  const recurring = activitiesData.filter(a => {
    if (!a.recurring) return false;
    const r = a.recurring.toLowerCase();
    if (r === 'weekends' || r.includes('weekend')) return dow === 0 || dow === 6;
    if (r.includes('various')) return true;
    const days = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'];
    if (r.includes(days[dow])) return true;
    if (days.some(d => r.includes(d))) return false;
    return false;
  });
  if (recurring.length) {
    sections += renderDayDetailSection(
      isToday ? 'availableToday' : 'activitiesAvailable',
      '📋',
      recurring.map(a => renderDayActivityCard(a)).join('')
    );
  }

  // Weather-based picks (today only)
  if (isToday && activitiesData.length) {
    const w = newsData?.weather;
    const isBad = w && (RAINY_CODES.includes(w.weatherCode) || w.temperature < 5);
    const picks = activitiesData.filter(a => a.category !== 'stayhome' && !a.recurring && (isBad ? a.indoor : !a.indoor));
    if (picks.length) {
      const shuffled = [...picks].sort(() => Math.random() - 0.5).slice(0, 4);
      sections += renderDayDetailSection(
        isBad ? 'indoorPicksToday' : 'outdoorPicksToday',
        isBad ? '🏠' : '☀️',
        shuffled.map(a => renderDayActivityCard(a)).join('')
      );
    }
  }

  // Trending news (today only)
  if (isToday && newsData?.trending?.length) {
    const trendingHtml = newsData.trending.slice(0, 3).map(t => {
      return `<div class="day-detail-trending" onclick="${safeUrl(t.url) ? `window.open('${esc(t.url)}','_blank')` : ''}">
        <div class="day-detail-trending-headline">${esc(lang === 'de' ? (t.headlineDE || t.headline) : t.headline)}</div>
        <div class="day-detail-trending-source">${esc(t.source || '')}</div>
      </div>`;
    }).join('');
    sections += renderDayDetailSection('trendingToday', '📈', trendingHtml);
  }

  if (!sections) {
    sections = `<div style="text-align:center;color:var(--muted);padding:24px 0;font-size:.85rem">${lang === 'de' ? 'Keine besonderen Events an diesem Tag' : 'No special events on this day'}</div>`;
  }

  html += sections;
  return html;
}

// ═══ EXPLORE VIEW ═══

function renderExploreView() {
  let html = '';

  // Mini map
  html += `<div class="explore-map-wrap"><div class="explore-map-container" id="explore-map"></div><div class="explore-map-hint" onclick="expandExploreMap()">🗺️ ${lang === 'de' ? 'Karte vergrössern' : 'Expand map'}</div></div>`;

  // Near You horizontal scroll
  const items = getExploreItems();
  const nearItems = items.slice(0, 10);
  if (nearItems.length) {
    html += `<div class="near-section"><div class="near-section-row"><span class="section-heading">${lang === 'de' ? 'In der Nähe' : 'Near You'}</span><span class="section-count">${items.length} ${lang === 'de' ? 'Orte' : 'places'}</span></div>`;
    html += '<div class="near-scroll">';
    for (const item of nearItems) {
      const dist = userLat ? formatDist(haversine(userLat, userLon, item.lat, item.lon)) : '';
      html += `<div class="near-chip" onclick="exploreCardClick('${esc(item.id)}')">
        <div class="near-chip-icon" style="background:${item.color}15"><span>${item.emoji}</span></div>
        <div class="near-chip-info"><div class="near-chip-name">${esc(item.name)}</div>${dist ? `<div class="near-chip-dist">↗ ${dist}</div>` : `<div class="near-chip-dist">${item.type}</div>`}</div>
      </div>`;
    }
    html += '</div></div>';
  }

  // Browse by Type — category grid
  const categories = [
    { key: 'museum', emoji: '🏛️', label: lang === 'de' ? 'Museen' : 'Museums', color: '#a855f7' },
    { key: 'playground', emoji: '🛝', label: lang === 'de' ? 'Spielplätze' : 'Playgrounds', color: '#22c55e' },
    { key: 'outdoor', emoji: '🌳', label: lang === 'de' ? 'Draussen' : 'Outdoors', color: '#059669' },
    { key: 'animals', emoji: '🦁', label: lang === 'de' ? 'Tiere' : 'Animals', color: '#f59e0b' },
    { key: 'indoor-play', emoji: '🎪', label: 'Indoor', color: '#ec4899' },
    { key: 'cafe', emoji: '☕', label: 'Cafés', color: '#C4623A' }
  ];
  const actCounts = {};
  for (const a of activitiesData) { actCounts[a.category] = (actCounts[a.category] || 0) + 1; }

  html += `<div class="explore-section"><div class="section-heading" style="margin-bottom:12px">${lang === 'de' ? 'Nach Typ entdecken' : 'Browse by Type'}</div>`;
  html += '<div class="explore-grid">';
  for (const cat of categories) {
    const count = actCounts[cat.key] || 0;
    html += `<div class="explore-cat-card" style="--cat-color:${cat.color}" onclick="filterActivities('all');switchView('activities')">
      <div class="explore-cat-icon">${cat.emoji}</div>
      <div class="explore-cat-label">${cat.label}</div>
      <div class="explore-cat-count">${count} ${lang === 'de' ? 'Orte' : 'places'}</div>
    </div>`;
  }
  html += '</div></div>';

  // Full list
  html += '<div id="explore-list" class="explore-list"></div>';

  return html;
}

function setExploreFilter(f) {
  exploreFilter = f;
  renderHeader();
  renderCurrentView();
  afterRender(() => initExploreMap());
}

function expandExploreMap() {
  const el = $('explore-map');
  if (!el) return;
  el.closest('.explore-map-wrap')?.classList.toggle('expanded');
  if (exploreMap) setTimeout(() => exploreMap.invalidateSize(), 300);
}

function getExploreItems() {
  const items = [];
  const today = new Date().toISOString().split('T')[0];
  const currentMonth = new Date().getMonth() + 1;

  // Activities (with coordinates)
  if (exploreFilter === 'all' || exploreFilter === 'activities') {
    const acts = [...activitiesData, ...customActivities].filter(a => a.lat && a.category !== 'stayhome');
    for (const a of acts) {
      items.push({
        type: 'activity', id: a.id, name: lang === 'de' ? (a.nameDE || a.name) : a.name,
        desc: lang === 'de' ? (a.descriptionDE || a.description) : a.description,
        lat: a.lat, lon: a.lon, indoor: a.indoor, category: a.category,
        emoji: ACTIVITY_EMOJIS[a.category] || '📍', color: MAP_COLORS.green,
        price: a.price
      });
    }
  }

  // City events (with dates overlapping today or upcoming 7 days)
  if (exploreFilter === 'all' || exploreFilter === 'events') {
    const weekFromNow = new Date();
    weekFromNow.setDate(weekFromNow.getDate() + 7);
    const weekStr = weekFromNow.toISOString().split('T')[0];
    for (const e of cityEventsData) {
      if (!e.startDate) continue;
      const end = e.endDate || e.startDate;
      if (end < today || e.startDate > weekStr) continue;
      // Events don't have coordinates in the data — use city center
      const coords = CITY_COORDS[e.city || city] || CITY_COORDS[city];
      if (!coords) continue;
      items.push({
        type: 'event', id: e.id, name: lang === 'de' ? (e.nameDE || e.name) : e.name,
        desc: lang === 'de' ? (e.descriptionDE || e.description) : e.description,
        lat: coords[0] + (Math.random() - 0.5) * 0.01, lon: coords[1] + (Math.random() - 0.5) * 0.01,
        emoji: '📅', color: MAP_COLORS.purple,
        toddlerFriendly: e.toddlerFriendly, free: e.free,
        startDate: e.startDate, endDate: e.endDate
      });
    }
  }

  // Deals (city-relevant, no coordinates — use city center with offset)
  if (exploreFilter === 'all' || exploreFilter === 'deals') {
    const coords = CITY_COORDS[city] || CITY_COORDS.zurich;
    const relevant = dealsData.filter(d => {
      if (d.city !== 'all' && d.city !== city) return false;
      if (d.validMonths && !d.validMonths.includes(currentMonth)) return false;
      return true;
    });
    for (let i = 0; i < relevant.length; i++) {
      const d = relevant[i];
      // Spread deals in a circle around city center
      const angle = (i / relevant.length) * Math.PI * 2;
      const r = 0.005 + Math.random() * 0.008;
      items.push({
        type: 'deal', id: d.id, name: lang === 'de' ? (d.nameDE || d.name) : d.name,
        desc: lang === 'de' ? (d.descriptionDE || d.description) : d.description,
        lat: coords[0] + Math.sin(angle) * r, lon: coords[1] + Math.cos(angle) * r,
        emoji: DEAL_CATEGORY_EMOJIS[d.category] || '🎁',
        color: d.type === 'free' ? MAP_COLORS.green : d.type === 'deal' ? MAP_COLORS.blue : MAP_COLORS.amber,
        dealType: d.type, savings: d.savings, url: d.url
      });
    }
  }

  // Sort by distance if location available
  if (userLat) {
    items.sort((a, b) => haversine(userLat, userLon, a.lat, a.lon) - haversine(userLat, userLon, b.lat, b.lon));
  }

  return items;
}

async function initExploreMap() {
  const el = $('explore-map');
  if (!el || !el.offsetParent) return;
  await loadLeaflet();
  if (!window.L) return;

  const center = userLat ? [userLat, userLon] : (CITY_COORDS[city] || CITY_COORDS.zurich);

  if (exploreMap) exploreMap.remove();
  exploreMarkers = {};
  exploreMap = L.map(el).setView(center, 13);
  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', { attribution: '© OSM' }).addTo(exploreMap);

  const items = getExploreItems();
  const listEl = $('explore-list');
  let listHtml = '';

  for (const item of items) {
    // Map marker
    const marker = L.circleMarker([item.lat, item.lon], {
      radius: 7,
      fillColor: item.color,
      fillOpacity: .85,
      weight: 1,
      color: '#fff'
    }).addTo(exploreMap);

    const popupContent = `<b>${item.emoji} ${esc(item.name)}</b><br><span style="font-size:.85em;color:#666">${esc(item.desc?.substring(0, 80) || '')}${item.desc?.length > 80 ? '...' : ''}</span>`;
    marker.bindPopup(popupContent);
    marker.on('click', () => highlightCard(`explore-${item.id}`));
    exploreMarkers[item.id] = marker;

    // List card
    const dist = userLat ? haversine(userLat, userLon, item.lat, item.lon) : null;
    let tags = `<span class="vcard-tag" style="background:${item.color}15;color:${item.color}">${item.type === 'activity' ? (item.indoor ? 'Indoor' : 'Outdoor') : item.type === 'event' ? 'Event' : item.dealType || 'Deal'}</span>`;
    if (item.free) tags += '<span class="vcard-tag" style="background:rgba(58,125,92,.1);color:var(--clr-green)">Free</span>';
    if (item.savings) tags += `<span class="vcard-tag">${item.savings}</span>`;

    listHtml += `<div class="explore-item" id="explore-${item.id}" onclick="exploreCardClick('${esc(item.id)}')">
      <div class="explore-item-icon" style="background:${item.color}15"><span>${item.emoji}</span></div>
      <div class="explore-item-body">
        <div class="vcard-name">${esc(item.name)}</div>
        <div class="vcard-desc">${esc(item.desc?.substring(0, 80) || '')}${item.desc?.length > 80 ? '...' : ''}</div>
        <div class="vcard-tags">${tags}</div>
      </div>
      ${dist !== null ? `<div class="vcard-dist">↗ ${formatDist(dist)}</div>` : ''}
    </div>`;
  }

  if (!items.length) {
    listHtml = renderEmptyState('🗺️', 'noResults', 'emptyFilterHint');
  }
  if (listEl) listEl.innerHTML = listHtml;

  // User location marker
  if (userLat) {
    L.marker([userLat, userLon], { icon: L.divIcon({ html: '📍', className: '', iconSize: [20, 20] }) }).addTo(exploreMap);
  }
}

function exploreCardClick(id) {
  if (exploreMap && exploreMarkers[id]) {
    const marker = exploreMarkers[id];
    exploreMap.setView(marker.getLatLng(), 15, { animate: true });
    marker.openPopup();
    $('explore-map')?.scrollIntoView({ behavior: 'smooth', block: 'start' });
  }
  highlightCard(`explore-${id}`);
}

async function loadExplore(force = false) {
  // Need activities data for the map
  if (!activitiesData.length || force) {
    const cacheKey = `activitiesCache-${city}`;
    if (!force) {
      const cached = cache.get(cacheKey);
      if (cached) {
        activitiesData = cached.activities || [];
        cityEventsData = cached.cityEvents || [];
      }
    }
    if (!activitiesData.length) {
      showLoading();
      try {
        const res = await fetch(`${API}/activities?city=${city}&lang=${lang}`);
        const data = await res.json();
        activitiesData = data.activities || [];
        cityEventsData = data.cityEvents || [];
        cache.set(cacheKey, data);
      } catch (e) {
        console.error('Explore load error:', e);
      } finally {
        hideLoading();
      }
    }
  }

  // Ensure deals are loaded for explore map
  if (!dealsData.length) loadDeals();

  // Request location for distance sorting
  if (!userLat && navigator.geolocation) {
    navigator.geolocation.getCurrentPosition(pos => {
      userLat = pos.coords.latitude;
      userLon = pos.coords.longitude;
      if (view === 'explore') afterRender(() => initExploreMap());
    }, () => {}, { enableHighAccuracy: true });
  }

  renderCurrentView();
  afterRender(() => initExploreMap());
}

// ═══ SWIPE NAVIGATION ═══

function setupSwipe() {
  let startX = 0;
  const main = $('main');
  if (!main) return;

  main.addEventListener('touchstart', e => { startX = e.touches[0].clientX; }, { passive: true });
  main.addEventListener('touchend', e => {
    if (view !== 'news') return;
    const diff = e.changedTouches[0].clientX - startX;
    if (Math.abs(diff) < 80) return;
    const cats = ['topStories', 'politics', 'events', 'culture', 'local'];
    const idx = cats.indexOf(currentTab);
    if (diff < 0 && idx < cats.length - 1) setTab(cats[idx + 1]);
    else if (diff > 0 && idx > 0) setTab(cats[idx - 1]);
  }, { passive: true });
}

// ═══ PULL TO REFRESH ═══

function setupPullRefresh() {
  let startY = 0, pulling = false;
  document.addEventListener('touchstart', e => { if (window.scrollY === 0) { startY = e.touches[0].clientY; pulling = true; } }, { passive: true });
  document.addEventListener('touchmove', e => {
    if (!pulling) return;
    const diff = e.touches[0].clientY - startY;
    if (diff > 60) $('pull-indicator')?.classList.add('active');
  }, { passive: true });
  document.addEventListener('touchend', () => {
    if ($('pull-indicator')?.classList.contains('active')) {
      $('pull-indicator').classList.remove('active');
      refreshCurrentView();
    }
    pulling = false;
  }, { passive: true });
}

// ═══ FRESHNESS TIMER ═══

function updateFreshnessTimes() {
  // Re-render time-ago badges
  document.querySelectorAll('.freshness').forEach(el => {
    if (el.dataset.iso) el.textContent = timeAgo(el.dataset.iso);
  });
}

// ═══ INIT ═══

document.addEventListener('DOMContentLoaded', () => {
  // Theme
  document.documentElement.setAttribute('data-theme', theme);
  updateThemeColor();

  // Render
  renderAll();

  // Close dropdowns on outside click
  document.addEventListener('click', e => {
    if (!e.target.closest('.city-selector')) $('city-dropdown')?.classList.remove('active');
    if (e.target.id === 'menu-overlay') closeMenu();
    if (e.target.id === 'modal') closeModal();
  });

  // Swipe & pull
  setupSwipe();
  setupPullRefresh();

  // Freshness timer
  setInterval(updateFreshnessTimes, 60000);

  // Check URL params (override persisted view if present)
  const params = new URLSearchParams(window.location.search);
  const viewParam = params.get('view');
  if (viewParam && ['activities', 'lunch', 'events', 'weekend', 'sunshine', 'snow', 'deals', 'explore'].includes(viewParam)) {
    switchView(viewParam);
  } else if (view === 'news') {
    fetchNews();
  } else {
    // Restore persisted view and load its data
    switchView(view);
  }

  // Service worker
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.register('/sw.js').catch(() => {});
  }

  // Check reminders
  checkReminders();

  // Check Apple Pay donate availability
  checkDonateAvailability();
});
