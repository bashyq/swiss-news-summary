// ═══════════════════════════════════════════════════
// Today in Switzerland — PWA Frontend
// ═══════════════════════════════════════════════════

// ═══ CONFIG ═══
const APP_VERSION = '2.0.0';
const API = 'https://swiss-news-worker.swissnews.workers.dev';
const CITIES = { zurich:'Zürich', basel:'Basel', bern:'Bern', geneva:'Geneva', lausanne:'Lausanne', luzern:'Luzern', winterthur:'Winterthur' };
const WEATHER_ICONS = { 0:'☀️',1:'🌤️',2:'⛅',3:'☁️',45:'🌫️',48:'🌫️',51:'🌦️',53:'🌦️',55:'🌧️',56:'🌧️',57:'🌧️',61:'🌧️',63:'🌧️',65:'🌧️',66:'🌧️',67:'🌧️',71:'🌨️',73:'🌨️',75:'🌨️',77:'🌨️',80:'🌦️',81:'🌦️',82:'🌦️',85:'🌨️',86:'🌨️',95:'⛈️',96:'⛈️',99:'⛈️' };
const ACTIVITY_EMOJIS = { animals:'🦁', museum:'🏛️', playground:'🛝', outdoor:'🌳', nature:'🌿', 'indoor-play':'🎪', event:'📅', seasonal:'🎄', stayhome:'🏠', cafe:'☕', other:'📍' };

// ═══ STATE ═══
let lang = localStorage.getItem('lang') || 'en';
let city = localStorage.getItem('city') || 'zurich';
let theme = localStorage.getItem('theme') || 'dark';
let view = 'news';
let newsData = null;
let activitiesData = [];
let cityEventsData = [];
let lunchData = [];
let weekendData = null;
let eventsCalendarData = [];
let currentTab = 'topStories';
let activityFilter = 'all';
let ageFilter = 'all';
let eventFilter = 'all';
let lunchFilter = 'all';
let savedActivities = JSON.parse(localStorage.getItem('savedActivities') || '[]');
let customActivities = JSON.parse(localStorage.getItem('customActivities') || '[]');
let savedLunch = JSON.parse(localStorage.getItem('savedLunch') || '[]');
let customLunch = JSON.parse(localStorage.getItem('customLunch') || '[]');
let lunchRatings = JSON.parse(localStorage.getItem('lunchRatings') || '{}');
let sunshineData = null;
let sunshineSort = 'sunshine';
let sunshineFilter = 'all';
let sunshineExpanded = false;
let userLat = null, userLon = null;
let activityMap = null, lunchMap = null, sunshineMap = null;
let lunchMapExpanded = false;
let calendarMonth = new Date().getMonth();
let calendarYear = new Date().getFullYear();
let selectedCalendarDay = null;

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
  allAges: { en:'All ages', de:'Alle Alter' },
  age23: { en:'2-3 years', de:'2-3 Jahre' },
  age45: { en:'4-5 years', de:'4-5 Jahre' },
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
  todayInSwitzerland: { en:'Today in', de:'Heute in der' },
  switzerland: { en:'Switzerland', de:'Schweiz' },
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
  about: { en:'About', de:'Info' },
  version: { en:'Version', de:'Version' },
  frontend: { en:'Frontend', de:'Frontend' },
  worker: { en:'Worker', de:'Worker' },
  module: { en:'Module', de:'Modul' },
  checkingVersion: { en:'Checking...', de:'Prüfe...' },
  versionError: { en:'Could not reach API', de:'API nicht erreichbar' },
};
const t = k => T[k]?.[lang] || k;

function getSubcategoryLabel(sub) {
  const labels = { sensory: { en:'Sensory', de:'Sensorik' }, art: { en:'Art & Crafts', de:'Basteln' }, active: { en:'Active Play', de:'Bewegung' }, pretend: { en:'Pretend Play', de:'Rollenspiel' }, kitchen: { en:'Kitchen Fun', de:'Küchenspass' } };
  return labels[sub]?.[lang] || sub;
}

// ═══ UTILS ═══
const $ = id => document.getElementById(id);
const esc = s => s?.replace(/[&<>"']/g, c => ({ '&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', "'":'&#39;' })[c]) || '';

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

// ═══ LAYOUT RENDERING ═══

function renderHeader() {
  const now = new Date();
  const dateStr = now.toLocaleDateString(lang === 'de' ? 'de-CH' : 'en-CH', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' });

  $('header').innerHTML = `
    <div class="header-top">
      <div class="date-display">${dateStr}</div>
      <div class="header-controls">
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
      <div id="weather-compact"></div>
    </div>
    <div id="weather-dropdown" class="weather-dropdown"></div>
    <div id="history-inline" class="history-inline"></div>
    <div id="transport-widget"></div>
  `;
}

function getPageTitle() {
  if (view === 'news') return `${t('todayInSwitzerland')}<br><span class="accent">${t('switzerland')}</span>`;
  if (view === 'activities') return `${t('whatToDo')}<br><span class="accent">${t('todayQ')}</span>`;
  if (view === 'lunch') return `${t('whereToEat')}<br><span class="accent">${t('eat')}</span>`;
  if (view === 'events') return `${t('events')}<br><span class="accent">${t('eventsCalendar')}</span>`;
  if (view === 'weekend') return `${t('weekend')}<br><span class="accent">${t('weekendPlanner')}</span>`;
  if (view === 'sunshine') return `${t('whereSun')}<br><span class="accent">${t('sunTitle')}</span>`;
  return '';
}

function renderNav() {
  if (view !== 'news') { $('nav').innerHTML = ''; return; }
  const cats = ['topStories', 'politics', 'eventsTab', 'culture', 'local'];
  const keys = ['topStories', 'politics', 'events', 'culture', 'local'];
  $('nav').innerHTML = `<div class="tabs">${cats.map((c, i) => {
    const count = newsData?.categories?.[keys[i]]?.length || 0;
    return `<button class="tab-btn${currentTab === keys[i] ? ' active' : ''}" onclick="setTab('${keys[i]}')">${t(c)} <span class="tab-count">${count}</span></button>`;
  }).join('')}</div>`;
}

function renderMain() {
  let html = '';
  html += `<div class="app-view${view === 'news' ? ' active' : ''}" id="view-news">${renderNewsView()}</div>`;
  html += `<div class="app-view${view === 'activities' ? ' active' : ''}" id="view-activities">${renderActivitiesView()}</div>`;
  html += `<div class="app-view${view === 'lunch' ? ' active' : ''}" id="view-lunch">${renderLunchView()}</div>`;
  html += `<div class="app-view${view === 'events' ? ' active' : ''}" id="view-events">${renderEventsView()}</div>`;
  html += `<div class="app-view${view === 'weekend' ? ' active' : ''}" id="view-weekend">${renderWeekendView()}</div>`;
  html += `<div class="app-view${view === 'sunshine' ? ' active' : ''}" id="view-sunshine">${renderSunshineView()}</div>`;
  $('main').innerHTML = html;
}

function renderMenu() {
  $('menu').innerHTML = `
    <button class="menu-close" onclick="closeMenu()">&times;</button>
    <div class="menu-title">${t('settings')}</div>
    <div class="menu-item${view === 'news' ? ' active' : ''}" onclick="switchView('news')"><span class="menu-item-icon">📰</span>${t('news')}</div>
    <div class="menu-item${view === 'activities' ? ' active' : ''}" onclick="switchView('activities')"><span class="menu-item-icon">🎈</span>${t('activities')}</div>
    <div class="menu-item${view === 'lunch' ? ' active' : ''}" onclick="switchView('lunch')"><span class="menu-item-icon">🍽️</span>${t('lunch')}</div>
    <div class="menu-item${view === 'events' ? ' active' : ''}" onclick="switchView('events')"><span class="menu-item-icon">📅</span>${t('events')}</div>
    <div class="menu-item${view === 'weekend' ? ' active' : ''}" onclick="switchView('weekend')"><span class="menu-item-icon">🌤️</span>${t('weekend')}</div>
    <div class="menu-item${view === 'sunshine' ? ' active' : ''}" onclick="switchView('sunshine')"><span class="menu-item-icon">☀️</span>${t('sunshine')}</div>
    <div class="menu-section">
      <div class="menu-section-title">${t('language')}</div>
      <div class="lang-toggle">
        <button class="lang-btn${lang === 'en' ? ' active' : ''}" onclick="setLanguage('en')">EN</button>
        <button class="lang-btn${lang === 'de' ? ' active' : ''}" onclick="setLanguage('de')">DE</button>
      </div>
      <button class="theme-toggle" onclick="toggleTheme()">${theme === 'dark' ? '☀️ ' + t('lightMode') : '🌙 ' + t('darkMode')}</button>
    </div>
    <div class="menu-section" id="menu-holidays">
      <div class="menu-section-title">${t('holidays')}</div>
      <div id="menu-holidays-list"></div>
    </div>
    <div class="menu-section" style="margin-top:20px;">
      <div class="menu-item" onclick="shareSummary()"><span class="menu-item-icon">📤</span>${t('share')}</div>
      <div class="menu-item" onclick="refreshCurrentView()"><span class="menu-item-icon">🔄</span>${t('refresh')}</div>
    </div>
    <div class="menu-section">
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

  // Briefing
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
    if (b.suggestedActivity) {
      const a = b.suggestedActivity;
      html += `<div class="briefing-activity">${lang === 'de' ? '💡 Vorschlag: ' : '💡 Suggestion: '}${esc(lang === 'de' ? (a.nameDE || a.name) : a.name)}</div>`;
    }
    html += '</div>';
  }

  // Trending
  if (newsData.trending) {
    const tr = newsData.trending;
    const topic = lang === 'de' ? (tr.topicDE || tr.topic) : tr.topic;
    html += `<div class="trending-banner" onclick="${tr.url ? `window.open('${esc(tr.url)}','_blank')` : ''}">
      <div class="trending-label">🔥 ${lang === 'de' ? 'Trending' : 'Trending'}</div>
      <div class="trending-topic">${esc(topic)}</div>
    </div>`;
  }

  // Category sections
  const cats = ['topStories', 'politics', 'events', 'culture', 'local'];
  for (const cat of cats) {
    const items = newsData.categories?.[cat] || [];
    html += `<div class="section${currentTab === cat ? ' active' : ''}" id="section-${cat}">`;
    for (const item of items) {
      const cardId = `card-${cat}-${Math.random().toString(36).substr(2, 6)}`;
      html += `<div class="card" onclick="toggleDetail('${cardId}')">
        <div class="card-headline"><a href="${esc(item.url)}" target="_blank" onclick="event.stopPropagation()">${esc(item.headline)}</a></div>
        <div class="card-summary">${esc(item.summary)}</div>
        <div class="card-detail" id="${cardId}">${esc(item.detail || '')}</div>
        <div class="card-meta">
          <span class="card-source">${esc(item.source)}</span>
          <span class="sentiment-badge sentiment-${item.sentiment || 'neutral'}">${item.sentiment || 'neutral'}</span>
          ${item.publishedAt ? `<span class="freshness">${timeAgo(item.publishedAt)}</span>` : ''}
        </div>
      </div>`;
    }
    if (items.length === 0) html += `<div class="loading-msg">${t('noResults')}</div>`;
    html += '</div>';
  }

  return html;
}

// ═══ ACTIVITIES VIEW ═══

function renderActivitiesView() {
  const cityName = CITIES[city] || 'Switzerland';
  let html = `<div class="subtitle" id="activities-subtitle">${t('familyActivities')} ${lang === 'de' ? 'in' : 'in'} ${cityName}</div>`;

  // Filters
  const filters = [
    ['all', t('all')], ['near', t('nearMe')], ['indoor', t('indoor')], ['outdoor', t('outdoor')],
    ['saved', t('saved')], ['seasonal', t('seasonal')], ['stayhome', t('stayHome')]
  ];
  html += `<div class="filter-bar">${filters.map(([k, v]) => `<button class="filter-btn${activityFilter === k ? ' active' : ''}" onclick="filterActivities('${k}')">${v}</button>`).join('')}</div>`;

  // Age filter
  html += `<div class="age-filter">
    <button class="age-btn${ageFilter === 'all' ? ' active' : ''}" onclick="setAgeFilter('all')">${t('allAges')}</button>
    <button class="age-btn${ageFilter === '2-3' ? ' active' : ''}" onclick="setAgeFilter('2-3')">${t('age23')}</button>
    <button class="age-btn${ageFilter === '4-5' ? ' active' : ''}" onclick="setAgeFilter('4-5')">${t('age45')}</button>
  </div>`;

  // Surprise button
  html += `<button class="surprise-btn" onclick="surpriseMe()" id="surprise-btn">${t('surpriseMe')}</button>`;

  // Map
  html += '<div class="map-container" id="activity-map"></div>';

  // Activities list
  html += '<div id="activities-list">';
  const filtered = getFilteredActivities();
  if (filtered.length === 0) {
    html += `<div class="loading-msg">${activitiesData.length === 0 ? t('loading') : t('noResults')}</div>`;
  } else {
    for (const a of filtered) html += renderActivityCard(a);
  }
  html += '</div>';

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

  let badges = '';
  badges += `<span class="badge ${a.indoor ? 'badge-indoor' : 'badge-outdoor'}">${a.indoor ? 'Indoor' : 'Outdoor'}</span>`;
  if (a.duration) badges += `<span class="badge badge-duration">${a.duration}</span>`;
  if (a.price) badges += `<span class="badge badge-price">${a.price}</span>`;
  if (dist !== null) badges += `<span class="badge badge-distance">${formatDist(dist)}</span>`;
  if (a.season) badges += `<span class="badge-seasonal badge-${a.season}">${a.season}</span>`;
  if (a.recurring) badges += `<span class="badge-recurring">${a.recurring}</span>`;
  if (a.subcategory) badges += `<span class="badge-subcategory">${getSubcategoryLabel(a.subcategory)}</span>`;

  let extra = '';
  if (a.materials) {
    const mat = lang === 'de' ? (a.materialsDE || a.materials) : a.materials;
    extra = `<div class="materials-info">📦 ${t('materials')}: ${esc(mat)}</div>`;
  }

  return `<div class="activity-card" id="activity-${a.id}" data-lat="${a.lat || ''}" data-lon="${a.lon || ''}">
    <div class="activity-name">${ACTIVITY_EMOJIS[a.category] || '📍'} ${esc(name)}</div>
    <div class="activity-desc">${esc(desc)}</div>
    <div class="activity-badges">${badges}</div>
    ${extra}
    <div class="activity-actions">
      <button class="${isSaved ? 'saved' : ''}" onclick="toggleSave('${a.id}')">${isSaved ? '❤️' : '🤍'} ${t('save')}</button>
      ${a.url ? `<button onclick="window.open('${esc(a.url)}','_blank')">${t('website')}</button>` : ''}
      ${a.lat ? `<button onclick="window.open('${mapsUrl(a.lat, a.lon, name)}','_blank')">${t('directions')}</button>` : ''}
      ${a.custom ? `<button onclick="deleteCustomActivity('${a.id}')">🗑️</button>` : ''}
    </div>
  </div>`;
}

function getFilteredActivities() {
  let items = [...activitiesData, ...customActivities];

  // Age filter
  if (ageFilter === '2-3') items = items.filter(a => !a.minAge || a.minAge <= 3);
  else if (ageFilter === '4-5') items = items.filter(a => !a.maxAge || a.maxAge >= 4);

  // Category filter
  if (activityFilter === 'all') items = items.filter(a => a.category !== 'stayhome');
  else if (activityFilter === 'near') { items = items.filter(a => a.category !== 'stayhome' && a.lat); if (userLat) items.sort((a, b) => haversine(userLat, userLon, a.lat, a.lon) - haversine(userLat, userLon, b.lat, b.lon)); }
  else if (activityFilter === 'indoor') items = items.filter(a => a.indoor && a.category !== 'stayhome');
  else if (activityFilter === 'outdoor') items = items.filter(a => !a.indoor && a.category !== 'stayhome');
  else if (activityFilter === 'saved') items = items.filter(a => savedActivities.includes(a.id));
  else if (activityFilter === 'seasonal') items = items.filter(a => a.category === 'seasonal');
  else if (activityFilter === 'stayhome') items = items.filter(a => a.category === 'stayhome');

  return items;
}

// ═══ EVENTS VIEW ═══

function renderEventsView() {
  let html = '';
  // Filter bar
  const filters = [['all', t('all')], ['holidays', t('holidaysFilter')], ['events', t('eventsTab')], ['recurring', t('recurringFilter')], ['seasonal', t('seasonal')], ['festivals', t('festivalsFilter')]];
  html += `<div class="filter-bar">${filters.map(([k, v]) => `<button class="filter-btn${eventFilter === k ? ' active' : ''}" onclick="filterEvents('${k}')">${v}</button>`).join('')}</div>`;

  // Calendar
  html += renderCalendarGrid();

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

  if (items.length === 0) return `<div class="loading-msg">${t('noResults')}</div>`;

  return items.map(e => {
    const name = lang === 'de' ? (e.nameDE || e.name) : e.name;
    const desc = lang === 'de' ? (e.descriptionDE || e.description) : e.description;
    let dateLabel = e.startDate || e.date || '';
    if (e.endDate && e.endDate !== e.startDate) dateLabel += ` — ${e.endDate}`;

    let badges = '';
    if (e.toddlerFriendly) badges += '<span class="badge badge-toddler">👶 Toddler-friendly</span>';
    if (e.free) badges += '<span class="badge badge-free">🆓 Free</span>';

    return `<div class="event-card${e.url ? ' style="cursor:pointer" onclick="window.open(\'' + esc(e.url) + '\',\'_blank\')"' : ''}">
      <div class="event-date">${dateLabel}</div>
      <div class="event-name">${esc(name)}</div>
      <div class="event-desc">${esc(desc)}</div>
      <div class="event-badges">${badges}</div>
    </div>`;
  }).join('');
}

// ═══ WEEKEND VIEW ═══

function renderWeekendView() {
  if (!weekendData) return `<div class="loading-msg">${t('loading')}</div>`;

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
  let html = `<div class="subtitle">${lang === 'de' ? 'Restaurants in der Nähe von' : 'Restaurants near'} ${CITIES[city]}</div>`;

  // Filters
  const filters = [['all', t('all')], ['saved', t('saved')], ['open', lang === 'de' ? 'Offen' : 'Open'], ['outdoor', 'Terrasse'], ['veg', 'Vegi']];
  html += `<div class="filter-bar">${filters.map(([k, v]) => `<button class="filter-btn${lunchFilter === k ? ' active' : ''}" onclick="filterLunch('${k}')">${v}</button>`).join('')}</div>`;

  // Surprise
  html += `<button class="surprise-btn" onclick="surpriseLunch()" id="surprise-lunch-btn">${t('surpriseMe')}</button>`;

  // Map
  html += `<div class="map-container${lunchMapExpanded ? ' expanded' : ' compact'}" id="lunch-map" onclick="toggleLunchMap()"></div>`;

  // List
  html += '<div id="lunch-list">';
  const spots = getFilteredLunchSpots();
  if (spots.length === 0) {
    html += `<div class="loading-msg">${lunchData.length === 0 ? t('loading') : t('noResults')}</div>`;
  } else {
    for (const s of spots.slice(0, 50)) html += renderLunchCard(s);
  }
  html += '</div>';

  // Add custom
  html += `<button class="btn-add" onclick="showAddForm('lunch')">${t('addLunch')}</button>`;
  html += `<div class="add-form" id="add-lunch-form">
    <input id="new-lunch-name" placeholder="${t('name')}">
    <input id="new-lunch-cuisine" placeholder="Cuisine">
    <div class="form-row" style="margin-top:8px;">
      <button class="btn-primary" onclick="saveCustomLunch()">${t('save')}</button>
      <button class="btn-secondary" onclick="hideAddForm('lunch')">${t('cancel')}</button>
    </div>
  </div>`;

  return html;
}

function renderLunchCard(s) {
  const isSaved = savedLunch.includes(s.id);
  const rating = lunchRatings[s.id] || 0;
  const dist = (userLat && s.lat) ? haversine(userLat, userLon, s.lat, s.lon) : null;

  let badges = '';
  if (s.openForLunch === true) badges += '<span class="badge badge-open">Open</span>';
  else if (s.openForLunch === false) badges += '<span class="badge badge-closed">Closed</span>';
  if (s.outdoorSeating) badges += '<span class="badge badge-outdoor-seat">🪑 Terrace</span>';
  if (s.wheelchair === 'yes') badges += '<span class="badge badge-wheelchair">♿</span>';
  if (s.takeaway) badges += '<span class="badge badge-takeaway">📦</span>';
  if (dist !== null) badges += `<span class="badge badge-distance">${formatDist(dist)}</span>`;

  const stars = [1, 2, 3, 4, 5].map(n => `<span class="star${n <= rating ? ' filled' : ''}" onclick="rateLunch('${s.id}',${n})">★</span>`).join('');

  return `<div class="lunch-spot">
    <div>
      <div class="lunch-name">${esc(s.name)}</div>
      <div class="lunch-cuisine">${esc(s.cuisine || s.cuisineCategory || s.amenity || '')}</div>
      <div class="lunch-badges">${badges}</div>
      <div class="star-rating" style="margin-top:4px;">${stars}</div>
    </div>
    <div class="lunch-actions">
      <button class="${isSaved ? 'saved' : ''}" onclick="toggleSaveLunch('${s.id}')" style="${isSaved ? 'color:var(--accent);border-color:var(--accent)' : ''}">${isSaved ? '❤️' : '🤍'}</button>
      ${s.lat ? `<button onclick="window.open('${mapsUrl(s.lat, s.lon, s.name)}','_blank')">📍</button>` : ''}
      ${s.website ? `<button onclick="window.open('${esc(s.website)}','_blank')">🌐</button>` : ''}
      ${s.custom ? `<button onclick="deleteCustomLunch('${s.id}')">🗑️</button>` : ''}
    </div>
  </div>`;
}

function getFilteredLunchSpots() {
  let items = [...lunchData, ...customLunch];
  if (lunchFilter === 'saved') items = items.filter(s => savedLunch.includes(s.id));
  else if (lunchFilter === 'open') items = items.filter(s => s.openForLunch === true);
  else if (lunchFilter === 'outdoor') items = items.filter(s => s.outdoorSeating);
  else if (lunchFilter === 'veg') items = items.filter(s => s.vegetarian || s.vegan || s.cuisineCategory === 'vegetarian');

  if (userLat) items.sort((a, b) => {
    if (!a.lat) return 1; if (!b.lat) return -1;
    return haversine(userLat, userLon, a.lat, a.lon) - haversine(userLat, userLon, b.lat, b.lon);
  });

  return items;
}

// ═══ DATA FETCHING ═══

async function fetchNews(force = false) {
  const cacheKey = `newsCache-${city}-${lang}`;
  if (!force) {
    const cached = cache.get(cacheKey);
    if (cached) { newsData = cached; renderAll(); }
  }

  try {
    const res = await fetch(`${API}/?lang=${lang}&city=${city}${force ? '&refresh=true' : ''}`);
    const data = await res.json();
    newsData = data;
    cache.set(cacheKey, data);
    renderAll();
    if (data.holidays) renderHolidays(data.holidays);
    if (data.weather) renderWeather(data.weather);
    if (data.history) renderHistory(data.history);
    if (data.transport) renderTransport(data.transport);
  } catch (e) {
    console.error('Fetch news error:', e);
    if (!newsData) $('main').querySelector('#view-news').innerHTML = '<div class="loading-msg">Failed to load. Check your connection.</div>';
  }
}

async function loadActivities(force = false) {
  try {
    const res = await fetch(`${API}/activities?city=${city}&lang=${lang}${force ? '&refresh=true' : ''}`);
    const data = await res.json();
    activitiesData = data.activities || [];
    cityEventsData = data.cityEvents || [];
    renderMain();
    setTimeout(() => initActivityMap(), 100);
  } catch (e) { console.error('Activities error:', e); }
}

async function loadEventsCalendar() {
  // Build calendar data from multiple sources
  eventsCalendarData = [];

  // Holidays from news data
  if (newsData?.holidays) {
    for (const h of newsData.holidays) {
      eventsCalendarData.push({ ...h, startDate: h.date, type: 'holiday' });
    }
  }

  // City events
  if (cityEventsData.length === 0) {
    try {
      const res = await fetch(`${API}/activities?city=${city}&lang=${lang}`);
      const data = await res.json();
      cityEventsData = data.cityEvents || [];
      if (!activitiesData.length) activitiesData = data.activities || [];
    } catch {}
  }

  for (const e of cityEventsData) eventsCalendarData.push({ ...e, type: 'festival' });

  // Recurring & seasonal from activities
  for (const a of activitiesData) {
    if (a.recurring) eventsCalendarData.push({ name: a.name, nameDE: a.nameDE, description: `${a.recurring}`, descriptionDE: `${a.recurring}`, startDate: new Date().toISOString().split('T')[0], type: 'recurring' });
    if (a.category === 'seasonal') eventsCalendarData.push({ name: a.name, nameDE: a.nameDE, description: a.description, descriptionDE: a.descriptionDE, startDate: new Date().toISOString().split('T')[0], type: 'seasonal' });
  }

  renderMain();
}

async function loadWeekendPlanner(force = false) {
  try {
    const res = await fetch(`${API}/weekend?city=${city}&lang=${lang}${force ? '&refresh=true' : ''}`);
    weekendData = await res.json();
    renderMain();
  } catch (e) { console.error('Weekend error:', e); }
}

async function loadLunchSpots(force = false) {
  try {
    const res = await fetch(`${API}/lunch?city=${city}${force ? '&refresh=true' : ''}`);
    const data = await res.json();
    lunchData = data.spots || [];
    renderMain();
    setTimeout(() => initLunchMap(), 100);
  } catch (e) { console.error('Lunch error:', e); }
}

// ═══ RENDERING HELPERS ═══

function renderWeather(w) {
  if (!w) return;
  const el = $('weather-compact');
  if (!el) return;
  el.innerHTML = `<span class="weather-icon">${WEATHER_ICONS[w.weatherCode] || '🌡️'}</span>
    <span class="weather-temp">${w.temperature}°</span>
    <span class="weather-wind">${w.windSpeed} km/h</span>`;
  el.onclick = toggleWeatherDropdown;
  el.style.cursor = 'pointer';

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
  const title = lang === 'de' ? 'Heute in der Geschichte' : 'This Day in History';
  el.innerHTML = `<div class="history-title">${title}</div><span class="history-year">${h.year}</span> — ${esc(text)}`;
  if (view === 'news') el.classList.add('active');
}

function renderTransport(tr) {
  const el = $('transport-widget');
  if (!el) return;
  if (!tr?.summary) { el.style.display = 'none'; return; }
  el.style.display = 'block';
  const status = tr.summary.status;
  const statusText = status === 'major' ? (lang === 'de' ? 'Grosse Störungen' : 'Major delays') : (lang === 'de' ? 'Leichte Verspätungen' : 'Minor delays');
  el.innerHTML = `<div class="transport-header" onclick="$('transport-details').classList.toggle('active')">
    <div class="transport-status ${status}"></div>
    <span>🚆 ${statusText} (${tr.summary.totalDelayed})</span>
  </div>
  <div class="transport-details" id="transport-details">
    ${tr.delays.map(d => `<div class="delay-item"><span>${esc(d.line)} → ${esc(d.destination)}</span><span class="delay-badge">+${d.delay}min</span></div>`).join('')}
  </div>`;
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
  renderAll();
  closeMenu();
  if (v === 'activities') loadActivities();
  else if (v === 'lunch') loadLunchSpots();
  else if (v === 'events') loadEventsCalendar();
  else if (v === 'weekend') loadWeekendPlanner();
  else if (v === 'sunshine') loadSunshine();
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
  renderMenu();
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

function filterActivities(f) {
  activityFilter = f;
  if (f === 'near' && !userLat) { requestLocation(); return; }
  renderMain();
  setTimeout(() => initActivityMap(), 100);
}

function setAgeFilter(f) { ageFilter = f; renderMain(); setTimeout(() => initActivityMap(), 100); }
function filterEvents(f) { eventFilter = f; renderMain(); }
function filterLunch(f) {
  lunchFilter = f;
  renderMain();
  setTimeout(() => initLunchMap(), 100);
}

function toggleSave(id) {
  const idx = savedActivities.indexOf(id);
  if (idx >= 0) savedActivities.splice(idx, 1); else savedActivities.push(id);
  localStorage.setItem('savedActivities', JSON.stringify(savedActivities));
  renderMain();
  setTimeout(() => initActivityMap(), 100);
}

function toggleSaveLunch(id) {
  const idx = savedLunch.indexOf(id);
  if (idx >= 0) savedLunch.splice(idx, 1); else savedLunch.push(id);
  localStorage.setItem('savedLunch', JSON.stringify(savedLunch));
  renderMain();
  setTimeout(() => initLunchMap(), 100);
}

function rateLunch(id, stars) {
  lunchRatings[id] = stars;
  localStorage.setItem('lunchRatings', JSON.stringify(lunchRatings));
  renderMain();
  setTimeout(() => initLunchMap(), 100);
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
  renderMain();
  setTimeout(() => initActivityMap(), 100);
}

function deleteCustomActivity(id) {
  customActivities = customActivities.filter(a => a.id !== id);
  localStorage.setItem('customActivities', JSON.stringify(customActivities));
  renderMain();
  setTimeout(() => initActivityMap(), 100);
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
  renderMain();
  setTimeout(() => initLunchMap(), 100);
}

function deleteCustomLunch(id) {
  customLunch = customLunch.filter(s => s.id !== id);
  localStorage.setItem('customLunch', JSON.stringify(customLunch));
  renderMain();
  setTimeout(() => initLunchMap(), 100);
}

function requestLocation() {
  if (!navigator.geolocation) return;
  navigator.geolocation.getCurrentPosition(pos => {
    userLat = pos.coords.latitude;
    userLon = pos.coords.longitude;
    renderMain();
    setTimeout(() => initActivityMap(), 100);
  }, () => {}, { enableHighAccuracy: true });
}

function dismissBriefing() {
  localStorage.setItem('briefingDismissed', new Date().toDateString());
  $('briefing-card')?.remove();
}

function openBriefingStory() {
  if (newsData?.briefing?.topStory?.url) window.open(newsData.briefing.topStory.url, '_blank');
}

function calendarPrev() { calendarMonth--; if (calendarMonth < 0) { calendarMonth = 11; calendarYear--; } renderMain(); }
function calendarNext() { calendarMonth++; if (calendarMonth > 11) { calendarMonth = 0; calendarYear++; } renderMain(); }
function selectCalendarDay(dateStr) { selectedCalendarDay = selectedCalendarDay === dateStr ? null : dateStr; renderMain(); }

function refreshCurrentView() {
  if (view === 'news') fetchNews(true);
  else if (view === 'activities') loadActivities(true);
  else if (view === 'lunch') loadLunchSpots(true);
  else if (view === 'events') loadEventsCalendar();
  else if (view === 'weekend') loadWeekendPlanner(true);
  else if (view === 'sunshine') loadSunshine(true);
}

async function shareSummary() {
  if (!navigator.share) return;
  try {
    await navigator.share({ title: 'Today in Switzerland', text: `Today in ${CITIES[city]}`, url: window.location.href });
  } catch {}
}

function toggleLunchMap() {
  lunchMapExpanded = !lunchMapExpanded;
  const el = $('lunch-map');
  if (!el) return;
  el.classList.toggle('compact', !lunchMapExpanded);
  el.classList.toggle('expanded', lunchMapExpanded);
  el.style.pointerEvents = lunchMapExpanded ? 'auto' : 'none';
  if (lunchMap) setTimeout(() => lunchMap.invalidateSize(), 100);
}

// ═══ SURPRISE ME ═══

function surpriseMe() {
  let candidates = activitiesData.filter(a => a.category !== 'stayhome');
  if (activityFilter === 'stayhome') candidates = activitiesData.filter(a => a.category === 'stayhome');
  if (candidates.length === 0) return;
  const pick = candidates[Math.floor(Math.random() * candidates.length)];
  showSurpriseModal(pick, 'activity');
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

  let badges = '';
  if (type === 'activity') {
    badges += `<span class="badge ${item.indoor ? 'badge-indoor' : 'badge-outdoor'}">${item.indoor ? 'Indoor' : 'Outdoor'}</span>`;
    if (item.duration) badges += `<span class="badge badge-duration">${item.duration}</span>`;
    if (item.price) badges += `<span class="badge badge-price">${item.price}</span>`;
  } else {
    if (item.cuisine) badges += `<span class="badge badge-price">${esc(item.cuisine)}</span>`;
    if (item.openForLunch === true) badges += '<span class="badge badge-open">Open</span>';
  }

  const modal = $('modal');
  modal.innerHTML = `<div class="modal-content">
    <button class="modal-close" onclick="closeModal()">&times;</button>
    <div class="modal-emoji">${emoji}</div>
    <div class="modal-title">${esc(name)}</div>
    <div class="modal-desc">${esc(desc || '')}</div>
    <div class="modal-badges">${badges}</div>
    <div class="modal-actions">
      <button class="btn-primary" onclick="${type === 'activity' ? 'surpriseMe()' : 'surpriseLunch()'}">${t('another')}</button>
      ${item.lat ? `<button class="btn-secondary" onclick="window.open('${mapsUrl(item.lat, item.lon, name)}','_blank')">${t('directions')}</button>` : ''}
      ${item.url || item.website ? `<button class="btn-secondary" onclick="window.open('${esc(item.url || item.website)}','_blank')">${t('website')}</button>` : ''}
      <button class="btn-secondary" onclick="closeModal()">${t('close')}</button>
    </div>
  </div>`;
  modal.classList.add('active');
}

function closeModal() { $('modal').classList.remove('active'); }

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
    document.head.appendChild(js);
  });
}

async function initActivityMap() {
  const el = $('activity-map');
  if (!el || !el.offsetParent) return;
  await loadLeaflet();

  const cityData = { zurich: [47.3769, 8.5417], basel: [47.5596, 7.5886], bern: [46.948, 7.4474], geneva: [46.2044, 6.1432], lausanne: [46.5197, 6.6323], luzern: [47.0502, 8.3093], winterthur: [47.4984, 8.7235] };
  const center = cityData[city] || [47.3769, 8.5417];

  if (activityMap) activityMap.remove();
  activityMap = L.map(el).setView(center, 12);
  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', { attribution: '© OSM' }).addTo(activityMap);

  const filtered = getFilteredActivities().filter(a => a.lat);
  for (const a of filtered) {
    const name = lang === 'de' ? (a.nameDE || a.name) : a.name;
    L.marker([a.lat, a.lon]).addTo(activityMap).bindPopup(`<b>${esc(name)}</b><br>${a.indoor ? 'Indoor' : 'Outdoor'} · ${a.duration || ''}`);
  }
  if (userLat) L.marker([userLat, userLon], { icon: L.divIcon({ html: '📍', className: '', iconSize: [20, 20] }) }).addTo(activityMap);
}

async function initLunchMap() {
  const el = $('lunch-map');
  if (!el || !el.offsetParent) return;
  await loadLeaflet();

  const cityData = { zurich: [47.3769, 8.5417], basel: [47.5596, 7.5886], bern: [46.948, 7.4474], geneva: [46.2044, 6.1432], lausanne: [46.5197, 6.6323], luzern: [47.0502, 8.3093], winterthur: [47.4984, 8.7235] };
  const center = cityData[city] || [47.3769, 8.5417];

  if (lunchMap) lunchMap.remove();
  lunchMap = L.map(el, { zoomControl: lunchMapExpanded, dragging: lunchMapExpanded, scrollWheelZoom: lunchMapExpanded }).setView(center, 14);
  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', { attribution: '© OSM' }).addTo(lunchMap);

  const spots = getFilteredLunchSpots().filter(s => s.lat);
  for (const s of spots.slice(0, 100)) {
    L.circleMarker([s.lat, s.lon], { radius: 5, fillColor: s.openForLunch ? '#22c55e' : '#666', fillOpacity: .8, weight: 1, color: '#fff' }).addTo(lunchMap).bindPopup(`<b>${esc(s.name)}</b><br>${s.cuisine || ''}`);
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
  let html = `<div class="subtitle">${t('sunSubtitle')}</div>`;

  // Filter bar
  const filters = [
    ['all', t('all')],
    ['sunny', '☀️ ' + t('sunnyLabel')],
    ['partly', '⛅ ' + t('partlyLabel')],
    ['cloudy', '☁️ ' + t('cloudyLabel')],
  ];
  html += `<div class="filter-bar">${filters.map(([k, v]) => `<button class="filter-btn${sunshineFilter === k ? ' active' : ''}" onclick="setSunshineFilter('${k}')">${v}</button>`).join('')}</div>`;

  // Sort toggle
  html += `<div class="sunshine-sort">
    <button class="sort-btn${sunshineSort === 'sunshine' ? ' active' : ''}" onclick="setSunshineSort('sunshine')">☀️ ${t('sortBySun')}</button>
    <button class="sort-btn${sunshineSort === 'distance' ? ' active' : ''}" onclick="setSunshineSort('distance')">📍 ${t('sortByDist')}</button>
  </div>`;

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
    html += `<div class="loading-msg">${t('noResults')}</div>`;
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

  return `<div class="sunshine-card sunshine-${cls}" onclick="sunshineCardClick('${d.id}')" data-id="${d.id}">
    <div class="sunshine-card-header">
      ${rankHtml}
      <div class="sunshine-card-info">
        <div class="sunshine-card-name">${emoji} ${esc(name)}</div>
        <div class="sunshine-card-region">${esc(region)}</div>
      </div>
      <div class="sunshine-card-total">
        <div class="sunshine-total-num">${d.sunshineHoursTotal}</div>
        <div class="sunshine-total-label">${t('sunshineHours')}</div>
      </div>
    </div>
    <div class="sunshine-card-body">
      <div class="sunshine-badges">${badges}</div>
      ${forecastHtml}
    </div>
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
  const cacheKey = 'sunshineCache';
  if (!force) {
    const cached = cache.get(cacheKey, 1800000);
    if (cached && cached.destinations?.length > 0) { sunshineData = cached; renderMain(); setTimeout(() => initSunshineMap(), 150); return; }
  }

  try {
    // Try worker first
    const res = await fetch(`${API}/sunshine?lang=${lang}${force ? '&refresh=true' : ''}`);
    const data = await res.json();
    if (data.destinations?.length > 0) {
      sunshineData = data;
      cache.set(cacheKey, data);
      renderMain();
      setTimeout(() => initSunshineMap(), 150);
      return;
    }
  } catch (e) { console.error('Worker sunshine error:', e); }

  // Fallback: fetch directly from Open-Meteo (client-side)
  try {
    const data = await fetchSunshineClientSide();
    if (data) {
      sunshineData = data;
      cache.set(cacheKey, data);
      renderMain();
      setTimeout(() => initSunshineMap(), 150);
      return;
    }
  } catch (e) { console.error('Client sunshine error:', e); }

  if (!sunshineData) {
    const vEl = $('view-sunshine');
    if (vEl) vEl.innerHTML = '<div class="loading-msg">Failed to load sunshine data.</div>';
  }
}

async function initSunshineMap() {
  const el = $('sunshine-map');
  if (!el || !el.offsetParent) return;
  await loadLeaflet();

  if (sunshineMap) sunshineMap.remove();
  sunshineMap = L.map(el).setView([46.8, 8.2], 7);
  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', { attribution: '© OSM' }).addTo(sunshineMap);

  if (!sunshineData?.destinations) return;

  for (const d of sunshineData.destinations) {
    const name = lang === 'de' ? (d.nameDE || d.name) : d.name;

    if (d.isBaseline) {
      L.circleMarker([d.lat, d.lon], {
        radius: 12,
        fillColor: '#a855f7',
        fillOpacity: 0.9,
        weight: 3,
        color: '#fff',
      }).addTo(sunshineMap).bindPopup(`<b>${esc(name)}</b> (${t('yourCity')})<br>${d.sunshineHoursTotal}${t('sunshineHours')}<br>${getSunshineEmoji(d.sunshineHoursTotal)}`);
    } else {
      const cls = getSunshineClass(d.sunshineHoursTotal);
      const color = cls === 'sunny' ? '#f59e0b' : cls === 'partly' ? '#60a5fa' : '#6b7280';
      const radius = Math.max(8, Math.min(18, 8 + d.sunshineHoursTotal));

      L.circleMarker([d.lat, d.lon], {
        radius,
        fillColor: color,
        fillOpacity: 0.85,
        weight: 2,
        color: '#fff',
      }).addTo(sunshineMap).bindPopup(`<b>${esc(name)}</b><br>${d.sunshineHoursTotal}${t('sunshineHours')}<br>${getSunshineEmoji(d.sunshineHoursTotal)}`);
    }
  }
}

function sunshineCardClick(id) {
  if (!sunshineMap || !sunshineData?.destinations) return;
  const d = sunshineData.destinations.find(x => x.id === id);
  if (!d) return;
  sunshineMap.setView([d.lat, d.lon], 10);
  // Open the popup for this marker
  sunshineMap.eachLayer(layer => {
    if (layer.getLatLng && Math.abs(layer.getLatLng().lat - d.lat) < 0.001 && Math.abs(layer.getLatLng().lng - d.lon) < 0.001) {
      layer.openPopup();
    }
  });
  // Scroll map into view
  $('sunshine-map')?.scrollIntoView({ behavior: 'smooth', block: 'center' });
}

function setSunshineFilter(f) {
  sunshineFilter = f;
  sunshineExpanded = false;
  renderMain();
  setTimeout(() => initSunshineMap(), 150);
}

function setSunshineSort(s) {
  if (s === 'distance' && !userLat) {
    navigator.geolocation?.getCurrentPosition(pos => {
      userLat = pos.coords.latitude;
      userLon = pos.coords.longitude;
      sunshineSort = 'distance';
      renderMain();
      setTimeout(() => initSunshineMap(), 150);
    }, () => {}, { enableHighAccuracy: true });
    return;
  }
  sunshineSort = s;
  renderMain();
  setTimeout(() => initSunshineMap(), 150);
}

function expandSunshineList() {
  sunshineExpanded = true;
  renderMain();
  setTimeout(() => initSunshineMap(), 150);
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

  // Check URL params
  const params = new URLSearchParams(window.location.search);
  const viewParam = params.get('view');
  if (viewParam && ['activities', 'lunch', 'events', 'weekend', 'sunshine'].includes(viewParam)) {
    switchView(viewParam);
  } else {
    fetchNews();
  }

  // Service worker
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.register('/sw.js').catch(() => {});
  }
});
