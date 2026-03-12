/**
 * Activities — curated family activities, seasonal, stay-home, handler.
 */

export const VERSION = '2.5.0';

import { getCity } from './data.js';
import { fetchWeather, RAINY_CODES } from './weather.js';
import { getCityEvents } from './events.js';

/* ── Default activities per city ── */

const ZURICH = [
  { id: 'zoo-zurich', name: 'Zoo Zürich', nameDE: 'Zoo Zürich', description: 'See elephants, penguins, and the amazing Masoala Rainforest hall. Perfect for little animal lovers!', descriptionDE: 'Elefanten, Pinguine und die beeindruckende Masoala-Regenwaldhalle. Perfekt für kleine Tierliebhaber!', indoor: false, ageRange: '2-5 years', duration: '2-4 hours', price: 'CHF 29 adults, kids under 6 free', url: 'https://www.zoo.ch', category: 'animals', lat: 47.3849, lon: 8.5743 , openingHours: 'Daily 9:00–18:00', openingHoursDE: 'Täglich 9:00–18:00'},
  { id: 'landesmuseum', name: 'Swiss National Museum', nameDE: 'Landesmuseum Zürich', description: 'Family-friendly exhibitions with interactive elements. The castle-like building is exciting for kids!', descriptionDE: 'Familienfreundliche Ausstellungen mit interaktiven Elementen. Das schlossartige Gebäude begeistert Kinder!', indoor: true, ageRange: '3-5 years', duration: '1-2 hours', price: 'CHF 10 adults, kids under 16 free', url: 'https://www.landesmuseum.ch', category: 'museum', lat: 47.3792, lon: 8.5396 , openingHours: 'Tue–Sun 10:00–17:00', openingHoursDE: 'Di–So 10:00–17:00'},
  { id: 'kindercity', name: 'Kindercity Volketswil', nameDE: 'Kindercity Volketswil', description: 'Indoor play paradise with science experiments, role-play areas, and soft play zones. Perfect for rainy days!', descriptionDE: 'Indoor-Spielparadies mit Wissenschaftsexperimenten, Rollenspielbereichen und Softplay-Zonen. Perfekt für Regentage!', indoor: true, ageRange: '2-5 years', duration: '2-4 hours', price: 'CHF 18-24', url: 'https://www.kindercity.ch', category: 'indoor-play', lat: 47.3867, lon: 8.6839 , openingHours: 'Daily 10:00–19:00', openingHoursDE: 'Täglich 10:00–19:00'},
  { id: 'playground-irchelpark', name: 'Irchelpark Playground', nameDE: 'Spielplatz Irchelpark', description: 'Large natural playground with climbing structures, sand pit, and water play in summer.', descriptionDE: 'Grosser Naturspielplatz mit Klettergerüsten, Sandkasten und Wasserspiel im Sommer.', indoor: false, ageRange: '2-5 years', duration: '1-3 hours', price: 'Free', category: 'playground', lat: 47.3970, lon: 8.5480 , openingHours: 'Open daily', openingHoursDE: 'Täglich geöffnet'},
  { id: 'trammuseum', name: 'Tram Museum Zürich', nameDE: 'Tram-Museum Zürich', description: 'Historic trams kids can climb into! Special family days with rides on vintage trams.', descriptionDE: 'Historische Trams, in die Kinder klettern können! Spezielle Familientage mit Fahrten in alten Trams.', indoor: true, ageRange: '2-5 years', duration: '1-2 hours', price: 'CHF 8 adults, CHF 4 kids', url: 'https://www.tram-museum.ch', category: 'museum', lat: 47.3556, lon: 8.5268 , openingHours: 'Sat 13:00–18:00', openingHoursDE: 'Sa 13:00–18:00'},
  { id: 'chinagarten', name: 'Chinese Garden', nameDE: 'Chinagarten', description: 'Beautiful garden by the lake with koi fish, bridges, and pagodas.', descriptionDE: 'Wunderschöner Garten am See mit Koi-Fischen, Brücken und Pagoden.', indoor: false, ageRange: '2-5 years', duration: '1 hour', price: 'CHF 4', category: 'nature', lat: 47.3545, lon: 8.5520 , openingHours: 'Daily 11:00–19:00', openingHoursDE: 'Täglich 11:00–19:00'},
  { id: 'playground-josefwiese', name: 'Josefwiese Playground', nameDE: 'Spielplatz Josefwiese', description: 'Popular urban playground in Kreis 5 with water features, swings, and climbing frames.', descriptionDE: 'Beliebter Stadtspielplatz im Kreis 5 mit Wasserspielen, Schaukeln und Klettergerüsten.', indoor: false, ageRange: '2-5 years', duration: '1-2 hours', price: 'Free', category: 'playground', lat: 47.3876, lon: 8.5280 , openingHours: 'Open daily', openingHoursDE: 'Täglich geöffnet'},
  { id: 'wildnispark', name: 'Wildnispark Zürich Langenberg', nameDE: 'Wildnispark Zürich Langenberg', description: 'See native Swiss animals like deer, wild boar, and lynx in natural enclosures.', descriptionDE: 'Einheimische Schweizer Tiere wie Hirsche, Wildschweine und Luchse in natürlichen Gehegen.', indoor: false, ageRange: '2-5 years', duration: '2-4 hours', price: 'Free', url: 'https://www.wildnispark.ch', category: 'animals', lat: 47.2856, lon: 8.5194 , openingHours: 'Open daily', openingHoursDE: 'Täglich geöffnet'},
  { id: 'zuerich-spielzeugmuseum', name: 'Toy Museum', nameDE: 'Spielzeugmuseum', description: 'Collection of historic toys with hands-on play areas for children.', descriptionDE: 'Sammlung historischer Spielzeuge mit praktischen Spielbereichen für Kinder.', indoor: true, ageRange: '2-5 years', duration: '1-2 hours', price: 'CHF 7', url: 'https://www.spielzeugmuseum.ch', category: 'museum', lat: 47.3695, lon: 8.5436 , openingHours: 'Mon–Fri 14:00–17:00, Sat 13:00–16:00', openingHoursDE: 'Mo–Fr 14:00–17:00, Sa 13:00–16:00'},
  { id: 'lake-boats', name: 'Lake Zürich Boat Trip', nameDE: 'Schifffahrt auf dem Zürichsee', description: 'Short boat rides on the lake. Kids love watching the water!', descriptionDE: 'Kurze Bootsfahrten auf dem See. Kinder lieben es!', indoor: false, ageRange: '2-5 years', duration: '1-2 hours', price: 'From CHF 8', url: 'https://www.zsg.ch', category: 'outdoor', lat: 47.3667, lon: 8.5410 , openingHours: 'Seasonal, see schedule', openingHoursDE: 'Saisonabhängig, siehe Fahrplan'},
  { id: 'botanischer-garten', name: 'Botanical Garden', nameDE: 'Botanischer Garten', description: 'Free garden with tropical greenhouses, pond with turtles, and space to run.', descriptionDE: 'Kostenloser Garten mit tropischen Gewächshäusern, Teich mit Schildkröten.', indoor: false, ageRange: '2-5 years', duration: '1-2 hours', price: 'Free', url: 'https://www.bg.uzh.ch', category: 'nature', lat: 47.3584, lon: 8.5601 , openingHours: 'Daily 7:00–19:00', openingHoursDE: 'Täglich 7:00–19:00'},
  { id: 'indoorspielplatz-kiddy-dome', name: 'Kiddy Dome Indoor Playground', nameDE: 'Kiddy Dome Indoorspielplatz', description: 'Soft play area, ball pit, trampolines, and toddler zone.', descriptionDE: 'Softplay-Bereich, Bällebad, Trampoline und Kleinkindzone.', indoor: true, ageRange: '2-5 years', duration: '2-3 hours', price: 'CHF 12-15', category: 'indoor-play', lat: 47.4115, lon: 8.5448 , openingHours: 'Daily 10:00–19:00', openingHoursDE: 'Täglich 10:00–19:00'},
  // Recurring
  { id: 'buerkliplatz-market', name: 'Bürkliplatz Farmers Market', nameDE: 'Bauernmarkt Bürkliplatz', description: 'Tuesday & Friday mornings: Fresh produce, flowers, and snacks.', descriptionDE: 'Dienstag & Freitag morgens: Frische Produkte, Blumen und Snacks.', indoor: false, ageRange: '2-5 years', duration: '1 hour', price: 'Free', category: 'event', recurring: 'Tue & Fri 6:00-11:00', lat: 47.3667, lon: 8.5410 },
  { id: 'spielnachmittag-gz', name: 'GZ Play Afternoons', nameDE: 'GZ Spielnachmittage', description: 'Free drop-in play sessions at community centers.', descriptionDE: 'Kostenlose Spielnachmittage in den Gemeinschaftszentren.', indoor: true, ageRange: '2-5 years', duration: '2-3 hours', price: 'Free', url: 'https://gz-zh.ch', category: 'event', recurring: 'Various days', lat: 47.3769, lon: 8.5417 },
  { id: 'story-time-pestalozzi', name: 'Story Time at Pestalozzi Library', nameDE: 'Geschichtenzeit Pestalozzi-Bibliothek', description: 'Free story readings for toddlers. Wednesday afternoons.', descriptionDE: 'Kostenlose Geschichten für Kleinkinder. Mittwochnachmittags.', indoor: true, ageRange: '2-5 years', duration: '45 min', price: 'Free', url: 'https://www.pbz.ch', category: 'event', recurring: 'Wed afternoon', lat: 47.3775, lon: 8.5358 },
  { id: 'kindermuseum-workshops', name: "Children's Museum Workshops", nameDE: 'Kindermuseum Workshops', description: 'Weekend craft workshops at Museum Rietberg.', descriptionDE: 'Wochenend-Bastelworkshops im Museum Rietberg.', indoor: true, ageRange: '3-5 years', duration: '1-2 hours', price: 'CHF 5-10', url: 'https://rietberg.ch', category: 'event', recurring: 'Weekends', lat: 47.3594, lon: 8.5312 },
  // Within 20km
  { id: 'zurich-uetliberg', name: 'Uetliberg Mountain', nameDE: 'Uetliberg', description: 'Zürich\'s local mountain with playground, Planetenweg trail, and panoramic views. Easy S-Bahn ride!', descriptionDE: 'Zürichs Hausberg mit Spielplatz, Planetenweg und Panoramablick. Einfach mit der S-Bahn erreichbar!', indoor: false, ageRange: '2-5 years', duration: '2-3 hours', price: 'Free (transport extra)', category: 'outdoor', lat: 47.3496, lon: 8.4919 , openingHours: 'Open daily', openingHoursDE: 'Täglich geöffnet'},
  { id: 'zurich-lindt-chocolate', name: 'Lindt Home of Chocolate', nameDE: 'Lindt Home of Chocolate', description: 'Chocolate museum in Kilchberg with 9m chocolate fountain and kids\' workshop area.', descriptionDE: 'Schokoladenmuseum in Kilchberg mit 9m Schokobrunnen und Kinder-Workshopbereich.', indoor: true, ageRange: '3-5 years', duration: '1-2 hours', price: 'CHF 15 adults, kids under 8 free', url: 'https://www.lindt-home-of-chocolate.com', category: 'museum', lat: 47.3227, lon: 8.5485 , openingHours: 'Daily 10:00–18:00', openingHoursDE: 'Täglich 10:00–18:00'},
  { id: 'zurich-flughafen-deck', name: 'Airport Observation Deck', nameDE: 'Flughafen Zuschauerterrasse', description: 'Watch planes take off and land! Playground on the terrace.', descriptionDE: 'Flugzeugen beim Starten und Landen zuschauen! Spielplatz auf der Terrasse.', indoor: false, ageRange: '2-5 years', duration: '1-2 hours', price: 'CHF 5', url: 'https://www.flughafen-zuerich.ch', category: 'outdoor', lat: 47.4582, lon: 8.5555 , openingHours: 'Daily 8:00–21:00', openingHoursDE: 'Täglich 8:00–21:00'},
  { id: 'zurich-greifensee', name: 'Greifensee Lakeside Walk', nameDE: 'Greifensee Uferweg', description: 'Flat stroller-friendly path around the lake with bird-watching and playground.', descriptionDE: 'Flacher, kinderwagentauglicher Weg um den See mit Vogelbeobachtung und Spielplatz.', indoor: false, ageRange: '2-5 years', duration: '1-3 hours', price: 'Free', category: 'nature', lat: 47.3669, lon: 8.6815 , openingHours: 'Open daily', openingHoursDE: 'Täglich geöffnet'},
  { id: 'zurich-wow-museum', name: 'WOW Museum', nameDE: 'WOW Museum', description: 'Interactive illusion museum with 3D rooms and optical tricks. Great for photos!', descriptionDE: 'Interaktives Illusionsmuseum mit 3D-Räumen und optischen Tricks. Toll für Fotos!', indoor: true, ageRange: '3-5 years', duration: '1-2 hours', price: 'CHF 25 adults, CHF 15 kids', url: 'https://www.wowmuseum.ch', category: 'museum', lat: 47.3722, lon: 8.5412 , openingHours: 'Daily 10:00–20:00', openingHoursDE: 'Täglich 10:00–20:00'},
  { id: 'zurich-playground-blatterwiese', name: 'Blatterwiese Playground', nameDE: 'Spielplatz Blatterwiese', description: 'Lakeside playground near Chinese Garden with swings, slides, and huge lawn.', descriptionDE: 'Seeseitiger Spielplatz beim Chinagarten mit Schaukeln, Rutschen und grosser Wiese.', indoor: false, ageRange: '2-5 years', duration: '1-2 hours', price: 'Free', category: 'playground', lat: 47.3540, lon: 8.5505 , openingHours: 'Open daily', openingHoursDE: 'Täglich geöffnet'},
];

const BASEL = [
  { id: 'basel-zoo', name: 'Zoo Basel', nameDE: 'Zoo Basel', description: "One of Switzerland's oldest zoos with great children's area and petting zoo.", descriptionDE: 'Einer der ältesten Zoos der Schweiz mit tollem Kinderbereich und Streichelzoo.', indoor: false, ageRange: '2-5 years', duration: '2-4 hours', price: 'CHF 21 adults, kids under 6 free', url: 'https://www.zoobasel.ch', category: 'animals', lat: 47.5475, lon: 7.5789 , openingHours: 'Daily 8:00–18:00', openingHoursDE: 'Täglich 8:00–18:00'},
  { id: 'basel-spielzeugmuseum', name: 'Toy Worlds Museum Basel', nameDE: 'Spielzeug Welten Museum Basel', description: 'Amazing collection of teddy bears, dolls, and miniatures.', descriptionDE: 'Tolle Sammlung von Teddybären, Puppen und Miniaturen.', indoor: true, ageRange: '2-5 years', duration: '1-2 hours', price: 'CHF 7 adults, kids under 16 free', url: 'https://www.spielzeug-welten-museum-basel.ch', category: 'museum', lat: 47.5563, lon: 7.5898 , openingHours: 'Daily 10:00–18:00', openingHoursDE: 'Täglich 10:00–18:00'},
  { id: 'basel-rhein-ferry', name: 'Rhine Ferry Ride', nameDE: 'Rheinfähre', description: 'Short ferry rides across the Rhine - powered only by the current!', descriptionDE: 'Kurze Fährfahrten über den Rhein - nur von der Strömung angetrieben!', indoor: false, ageRange: '2-5 years', duration: '15 min', price: 'CHF 2', category: 'outdoor', lat: 47.5607, lon: 7.5909 , openingHours: 'Daily 9:00–19:00', openingHoursDE: 'Täglich 9:00–19:00'},
  { id: 'basel-tinguely', name: 'Tinguely Museum Garden', nameDE: 'Tinguely Museum Garten', description: 'Moving sculptures that fascinate children. The park outside is free.', descriptionDE: 'Bewegliche Skulpturen die Kinder faszinieren. Der Park draussen ist gratis.', indoor: false, ageRange: '3-5 years', duration: '1-2 hours', price: 'Park free, museum CHF 18', url: 'https://www.tinguely.ch', category: 'museum', lat: 47.5591, lon: 7.6135 , openingHours: 'Tue–Sun 11:00–18:00', openingHoursDE: 'Di–So 11:00–18:00'},
  { id: 'basel-lange-erlen', name: 'Lange Erlen Animal Park', nameDE: 'Tierpark Lange Erlen', description: 'Free animal park with deer, wild boar, and birds. Great playground!', descriptionDE: 'Gratis Tierpark mit Hirschen, Wildschweinen und Vögeln. Toller Spielplatz!', indoor: false, ageRange: '2-5 years', duration: '2-3 hours', price: 'Free', category: 'animals', lat: 47.5776, lon: 7.6255 , openingHours: 'Open daily', openingHoursDE: 'Täglich geöffnet'},
  // Within 20km
  { id: 'basel-augusta-raurica', name: 'Augusta Raurica Roman Ruins', nameDE: 'Augusta Raurica Römerstadt', description: 'Open-air Roman ruins with a hands-on museum where kids can try on togas and bake Roman bread.', descriptionDE: 'Freiluft-Römerruinen mit Museum zum Anfassen — Toga anprobieren und Römerbrot backen.', indoor: false, ageRange: '3-5 years', duration: '2-3 hours', price: 'Free (museum CHF 8)', url: 'https://www.augustaraurica.ch', category: 'museum', lat: 47.5345, lon: 7.7186 , openingHours: 'Daily 10:00–17:00', openingHoursDE: 'Täglich 10:00–17:00'},
  { id: 'basel-naturhistorisches', name: 'Natural History Museum', nameDE: 'Naturhistorisches Museum Basel', description: 'Dinosaur skeletons, minerals, and hands-on activities. Free for kids!', descriptionDE: 'Dinosaurierskelette, Mineralien und Aktivitäten zum Anfassen. Gratis für Kinder!', indoor: true, ageRange: '2-5 years', duration: '1-2 hours', price: 'CHF 7 adults, kids under 13 free', url: 'https://www.nmbs.ch', category: 'museum', lat: 47.5580, lon: 7.5881 , openingHours: 'Tue–Sun 10:00–17:00', openingHoursDE: 'Di–So 10:00–17:00'},
  { id: 'basel-papiermuehle', name: 'Paper Mill Museum', nameDE: 'Basler Papiermühle', description: 'Make your own paper and learn about printing. Very interactive!', descriptionDE: 'Eigenes Papier herstellen und Drucken lernen. Sehr interaktiv!', indoor: true, ageRange: '3-5 years', duration: '1-2 hours', price: 'CHF 15 adults, CHF 9 kids', url: 'https://www.papiermuseum.ch', category: 'museum', lat: 47.5585, lon: 7.5986 , openingHours: 'Tue–Sun 11:00–17:00', openingHoursDE: 'Di–So 11:00–17:00'},
  { id: 'basel-schuetzenmattpark', name: 'Schützenmattpark Playground', nameDE: 'Spielplatz Schützenmattpark', description: 'Large central playground with sand pit, water fountain, and pavilion for drinks.', descriptionDE: 'Grosser zentraler Spielplatz mit Sandkasten, Wasserfontäne und Pavillon.', indoor: false, ageRange: '2-5 years', duration: '1-2 hours', price: 'Free', category: 'playground', lat: 47.5530, lon: 7.5830 , openingHours: 'Open daily', openingHoursDE: 'Täglich geöffnet'},
  { id: 'basel-solitude-park', name: 'Solitude Park Playground', nameDE: 'Spielplatz Solitude Park', description: 'Playground near the Rhine with sandbox, lawn, and gardens. Next to Tinguely Museum.', descriptionDE: 'Spielplatz am Rhein mit Sandkasten, Wiese und Gärten. Neben dem Tinguely Museum.', indoor: false, ageRange: '2-5 years', duration: '1-2 hours', price: 'Free', category: 'playground', lat: 47.5694, lon: 7.5982 , openingHours: 'Open daily', openingHoursDE: 'Täglich geöffnet'},
  { id: 'basel-fondation-beyeler', name: 'Fondation Beyeler Park', nameDE: 'Fondation Beyeler Park', description: 'Beautiful sculpture garden in Riehen. Kids love the outdoor art and water features.', descriptionDE: 'Wunderschöner Skulpturengarten in Riehen. Kinder lieben die Kunst und Wasserspiele.', indoor: false, ageRange: '2-5 years', duration: '1-2 hours', price: 'Park free, museum CHF 25', url: 'https://www.fondationbeyeler.ch', category: 'nature', lat: 47.5905, lon: 7.6589 , openingHours: 'Daily 10:00–18:00, Wed 10:00–20:00', openingHoursDE: 'Täglich 10:00–18:00, Mi 10:00–20:00'},
  { id: 'basel-aquabasilea', name: 'Aquabasilea Water Park', nameDE: 'Aquabasilea Erlebnisbad', description: 'Indoor water park in Pratteln with toddler pool and gentle slides.', descriptionDE: 'Erlebnisbad in Pratteln mit Kleinkinderbecken und sanften Rutschen.', indoor: true, ageRange: '2-5 years', duration: '2-3 hours', price: 'CHF 39 adults, CHF 29 kids', url: 'https://www.aquabasilea.ch', category: 'indoor-play', lat: 47.5232, lon: 7.6863 , openingHours: 'Daily 9:00–22:00', openingHoursDE: 'Täglich 9:00–22:00'},
];

const BERN = [
  { id: 'bern-barenpark', name: 'BärenPark Bern', nameDE: 'BärenPark Bern', description: "See Bern's famous bears in their modern park by the river. Free!", descriptionDE: 'Berns berühmte Bären in ihrem modernen Park am Fluss. Gratis!', indoor: false, ageRange: '2-5 years', duration: '1 hour', price: 'Free', url: 'https://www.baerenpark-bern.ch', category: 'animals', lat: 46.9480, lon: 7.4600 , openingHours: 'Daily 8:00–17:00', openingHoursDE: 'Täglich 8:00–17:00'},
  { id: 'bern-tierpark-dahlholzli', name: 'Tierpark Dählhölzli', nameDE: 'Tierpark Dählhölzli', description: 'Great zoo with Nordic animals, playground, and restaurant.', descriptionDE: 'Toller Zoo mit nordischen Tieren, Spielplatz und Restaurant.', indoor: false, ageRange: '2-5 years', duration: '2-3 hours', price: 'CHF 10 adults, CHF 4 kids', url: 'https://www.tierpark-bern.ch', category: 'animals', lat: 46.9367, lon: 7.4507 , openingHours: 'Daily 9:00–17:00', openingHoursDE: 'Täglich 9:00–17:00'},
  { id: 'bern-kindermuseum-creaviva', name: "Creaviva Children's Museum", nameDE: 'Kindermuseum Creaviva', description: 'Interactive art workshops for kids at the Paul Klee Centre.', descriptionDE: 'Interaktive Kunstworkshops für Kinder im Zentrum Paul Klee.', indoor: true, ageRange: '3-5 years', duration: '1-2 hours', price: 'CHF 12', url: 'https://www.creaviva.org', category: 'museum', lat: 46.9490, lon: 7.4744 , openingHours: 'Tue–Sun 10:00–17:00', openingHoursDE: 'Di–So 10:00–17:00'},
  { id: 'bern-gurten', name: 'Gurten Funicular & Playground', nameDE: 'Gurtenbahn & Spielplatz', description: "Take the funicular up Bern's local mountain. Huge playground!", descriptionDE: 'Mit der Standseilbahn auf Berns Hausberg. Riesiger Spielplatz!', indoor: false, ageRange: '2-5 years', duration: '2-4 hours', price: 'CHF 12 return', url: 'https://www.gurtenpark.ch', category: 'outdoor', lat: 46.9215, lon: 7.4347 , openingHours: 'Funicular 7:00–23:00', openingHoursDE: 'Gurtenbahn 7:00–23:00'},
  { id: 'bern-naturhistorisches', name: 'Natural History Museum', nameDE: 'Naturhistorisches Museum', description: 'Dinosaurs, animals, and Barry the famous rescue dog!', descriptionDE: 'Dinosaurier, Tiere und Barry der berühmte Rettungshund!', indoor: true, ageRange: '3-5 years', duration: '1-2 hours', price: 'CHF 10 adults, kids under 16 free', url: 'https://www.nmbe.ch', category: 'museum', lat: 46.9514, lon: 7.4410 , openingHours: 'Tue–Sun 10:00–17:00', openingHoursDE: 'Di–So 10:00–17:00'},
  // Within 20km
  { id: 'bern-kommunikation', name: 'Museum of Communication', nameDE: 'Museum für Kommunikation', description: 'Interactive exhibits about communication. Kids love the hands-on stations and robot!', descriptionDE: 'Interaktive Ausstellungen über Kommunikation. Kinder lieben die Mitmach-Stationen und den Roboter!', indoor: true, ageRange: '3-5 years', duration: '1-2 hours', price: 'CHF 15 adults, kids under 7 free', url: 'https://www.mfk.ch', category: 'museum', lat: 46.9432, lon: 7.4500 , openingHours: 'Tue–Sun 10:00–17:00', openingHoursDE: 'Di–So 10:00–17:00'},
  { id: 'bern-rosengarten', name: 'Rose Garden & Playground', nameDE: 'Rosengarten & Spielplatz', description: 'Beautiful garden above the old town with playground and panoramic views of the Alps.', descriptionDE: 'Wunderschöner Garten über der Altstadt mit Spielplatz und Alpenpanorama.', indoor: false, ageRange: '2-5 years', duration: '1-2 hours', price: 'Free', category: 'playground', lat: 46.9522, lon: 7.4558 , openingHours: 'Open daily', openingHoursDE: 'Täglich geöffnet'},
  { id: 'bern-marzili', name: 'Marzili River Park', nameDE: 'Marzilibad & Park', description: 'Popular park by the Aare river with wading areas, playground, and picnic spots.', descriptionDE: 'Beliebter Park an der Aare mit Planschbereichen, Spielplatz und Picknickplätzen.', indoor: false, ageRange: '2-5 years', duration: '2-3 hours', price: 'Free', category: 'playground', lat: 46.9400, lon: 7.4480 , openingHours: 'Open daily', openingHoursDE: 'Täglich geöffnet'},
  { id: 'bern-bimano', name: 'Bimano Indoor Playground', nameDE: 'Bimano Indoorspielplatz', description: 'Indoor play paradise with dedicated toddler zone, slides, and creative areas.', descriptionDE: 'Indoor-Spielparadies mit Kleinkindzone, Rutschen und Kreativbereichen.', indoor: true, ageRange: '2-5 years', duration: '2-3 hours', price: 'CHF 15-20', url: 'https://www.bimano.ch', category: 'indoor-play', lat: 46.9530, lon: 7.3890 , openingHours: 'Mon–Fri 9:00–18:00, Sat 10:00–17:00', openingHoursDE: 'Mo–Fr 9:00–18:00, Sa 10:00–17:00'},
  { id: 'bern-alpines-museum', name: 'Alpine Museum', nameDE: 'Alpines Museum der Schweiz', description: 'Learn about mountain life through interactive exhibits. Kids\' trail through the museum.', descriptionDE: 'Interaktive Ausstellungen über das Bergleben. Kinderpfad durchs Museum.', indoor: true, ageRange: '3-5 years', duration: '1-2 hours', price: 'CHF 16 adults, kids under 16 free', url: 'https://www.alpinesmuseum.ch', category: 'museum', lat: 46.9460, lon: 7.4512 , openingHours: 'Tue–Sun 10:00–17:00', openingHoursDE: 'Di–So 10:00–17:00'},
  { id: 'bern-papiliorama', name: 'Papiliorama Kerzers', nameDE: 'Papiliorama Kerzers', description: 'Tropical butterfly house and jungle dome. Hundreds of butterflies land on you!', descriptionDE: 'Tropisches Schmetterlingshaus und Dschungelkuppel. Hunderte Schmetterlinge landen auf dir!', indoor: true, ageRange: '2-5 years', duration: '2-3 hours', price: 'CHF 19 adults, CHF 9 kids', url: 'https://www.papiliorama.ch', category: 'animals', lat: 46.9783, lon: 7.1917 , openingHours: 'Daily 10:00–18:00', openingHoursDE: 'Täglich 10:00–18:00'},
  { id: 'bern-playground-eichholz', name: 'Eichholz Playground & BBQ', nameDE: 'Spielplatz Eichholz', description: 'Huge playground area by the Aare with BBQ spots and wading pools.', descriptionDE: 'Riesiger Spielplatzbereich an der Aare mit Grillstellen und Planschbecken.', indoor: false, ageRange: '2-5 years', duration: '2-4 hours', price: 'Free', category: 'playground', lat: 46.9318, lon: 7.4582 , openingHours: 'Open daily', openingHoursDE: 'Täglich geöffnet'},
];

const GENEVA = [
  { id: 'geneva-jardin-botanique', name: 'Botanical Garden', nameDE: 'Botanischer Garten', description: 'Beautiful free gardens with a small zoo, playground, and turtles.', descriptionDE: 'Wunderschöne kostenlose Gärten mit kleinem Zoo, Spielplatz und Schildkröten.', indoor: false, ageRange: '2-5 years', duration: '1-2 hours', price: 'Free', url: 'https://www.ville-ge.ch/cjb', category: 'nature', lat: 46.2268, lon: 6.1479 , openingHours: 'Daily 8:00–19:30', openingHoursDE: 'Täglich 8:00–19:30'},
  { id: 'geneva-jet-deau', name: "Jet d'Eau & Lake Shore", nameDE: "Jet d'Eau & Seeufer", description: 'Watch the famous fountain and play along the lakeside.', descriptionDE: 'Den berühmten Springbrunnen beobachten und am See spielen.', indoor: false, ageRange: '2-5 years', duration: '1-2 hours', price: 'Free', category: 'outdoor', lat: 46.2073, lon: 6.1554 , openingHours: 'Open daily', openingHoursDE: 'Täglich geöffnet'},
  { id: 'geneva-museum-histoire-naturelle', name: 'Natural History Museum', nameDE: 'Naturhistorisches Museum', description: 'Huge collection of animals and dinosaurs. Free and kid-friendly!', descriptionDE: 'Riesige Sammlung von Tieren und Dinosauriern. Gratis und kinderfreundlich!', indoor: true, ageRange: '2-5 years', duration: '1-2 hours', price: 'Free', url: 'https://www.museum-geneve.ch', category: 'museum', lat: 46.1973, lon: 6.1578 , openingHours: 'Tue–Sun 10:00–17:00', openingHoursDE: 'Di–So 10:00–17:00'},
  { id: 'geneva-baby-plage', name: 'Baby Plage', nameDE: 'Baby Plage', description: 'Shallow water beach area perfect for toddlers.', descriptionDE: 'Flacher Strandbereich perfekt für Kleinkinder.', indoor: false, ageRange: '2-5 years', duration: '2-3 hours', price: 'Free', category: 'outdoor', lat: 46.2055, lon: 6.1611 , openingHours: 'Open daily', openingHoursDE: 'Täglich geöffnet'},
  { id: 'geneva-parc-bastions', name: 'Parc des Bastions', nameDE: 'Parc des Bastions', description: 'Central park with huge chess boards, playground, and space to run.', descriptionDE: 'Zentraler Park mit riesigen Schachbrettern, Spielplatz und Platz zum Herumrennen.', indoor: false, ageRange: '2-5 years', duration: '1-2 hours', price: 'Free', category: 'playground', lat: 46.2000, lon: 6.1461 , openingHours: 'Open daily', openingHoursDE: 'Täglich geöffnet'},
  // Within 20km
  { id: 'geneva-bois-batie', name: 'Bois de la Bâtie Zoo & Playground', nameDE: 'Bois de la Bâtie Zoo & Spielplatz', description: 'Free mini-zoo with local animals, large playground, and paddling pool in summer.', descriptionDE: 'Gratis Mini-Zoo mit einheimischen Tieren, grosser Spielplatz und Planschbecken im Sommer.', indoor: false, ageRange: '2-5 years', duration: '2-3 hours', price: 'Free', category: 'animals', lat: 46.1963, lon: 6.1275 , openingHours: 'Open daily', openingHoursDE: 'Täglich geöffnet'},
  { id: 'geneva-maison-creativite', name: 'Maison de la Créativité', nameDE: 'Maison de la Créativité', description: 'Creative play spaces designed for under-6s. Art, building, and imaginative play.', descriptionDE: 'Kreative Spielräume für Kinder unter 6. Kunst, Bauen und Fantasiespiel.', indoor: true, ageRange: '2-5 years', duration: '1-2 hours', price: 'CHF 3 per child', category: 'indoor-play', lat: 46.2065, lon: 6.1580 , openingHours: 'Wed–Sun 10:00–18:00', openingHoursDE: 'Mi–So 10:00–18:00'},
  { id: 'geneva-eaux-vives', name: 'Parc des Eaux-Vives', nameDE: 'Parc des Eaux-Vives', description: 'Beautiful lakefront park with playground, huge lawn, and views of the Alps.', descriptionDE: 'Wunderschöner Park am See mit Spielplatz, riesiger Wiese und Alpenblick.', indoor: false, ageRange: '2-5 years', duration: '1-2 hours', price: 'Free', category: 'playground', lat: 46.2010, lon: 6.1635 , openingHours: 'Open daily', openingHoursDE: 'Täglich geöffnet'},
  { id: 'geneva-bains-paquis', name: 'Bains des Pâquis', nameDE: 'Bains des Pâquis', description: 'Iconic lakeside baths with shallow pools, playground, and fondue in winter.', descriptionDE: 'Legendäres Seebad mit Planschbecken, Spielplatz und Fondue im Winter.', indoor: false, ageRange: '2-5 years', duration: '2-3 hours', price: 'CHF 2', url: 'https://www.bfrp.ch', category: 'outdoor', lat: 46.2098, lon: 6.1496 , openingHours: 'Daily 8:00–20:00', openingHoursDE: 'Täglich 8:00–20:00'},
  { id: 'geneva-perle-du-lac', name: 'Parc La Perle du Lac', nameDE: 'Parc La Perle du Lac', description: 'Peaceful lakefront park with playgrounds, grass to run, and swan watching.', descriptionDE: 'Ruhiger Park am See mit Spielplätzen, Wiese und Schwäne beobachten.', indoor: false, ageRange: '2-5 years', duration: '1-2 hours', price: 'Free', category: 'playground', lat: 46.2140, lon: 6.1480 , openingHours: 'Open daily', openingHoursDE: 'Täglich geöffnet'},
  { id: 'geneva-parc-evaux', name: 'Parc des Evaux', nameDE: 'Parc des Evaux', description: 'Huge park with playgrounds, pedal go-karts, mini train, and adventure area.', descriptionDE: 'Riesiger Park mit Spielplätzen, Pedalfahrzeugen, Minizug und Abenteuerbereich.', indoor: false, ageRange: '2-5 years', duration: '2-4 hours', price: 'Free', category: 'playground', lat: 46.1839, lon: 6.1027 , openingHours: 'Open daily', openingHoursDE: 'Täglich geöffnet'},
  { id: 'geneva-mouettes', name: 'Mouettes Lake Shuttles', nameDE: 'Mouettes Seefähren', description: 'Mini lake boat rides crossing the harbour. Kids love the short adventure!', descriptionDE: 'Mini-Bootsfahrten über den Hafen. Kinder lieben das kurze Abenteuer!', indoor: false, ageRange: '2-5 years', duration: '30 min', price: 'CHF 3.50', category: 'outdoor', lat: 46.2072, lon: 6.1510 , openingHours: 'Mon–Sat 7:30–19:00', openingHoursDE: 'Mo–Sa 7:30–19:00'},
];

const LAUSANNE = [
  { id: 'lausanne-olympic-museum', name: 'Olympic Museum', nameDE: 'Olympisches Museum', description: 'Interactive sports exhibits kids love. Beautiful park with lake views.', descriptionDE: 'Interaktive Sportausstellungen die Kinder lieben. Schöner Park mit Seeblick.', indoor: true, ageRange: '3-5 years', duration: '2-3 hours', price: 'CHF 20 adults, kids under 16 free', url: 'https://www.olympic.org/museum', category: 'museum', lat: 46.5082, lon: 6.6340 , openingHours: 'Tue–Sun 10:00–18:00', openingHoursDE: 'Di–So 10:00–18:00'},
  { id: 'lausanne-sauvabelin', name: 'Sauvabelin Park & Tower', nameDE: 'Sauvabelin Park & Turm', description: 'Forest park with animals, playground, and wooden tower.', descriptionDE: 'Waldpark mit Tieren, Spielplatz und Holzturm.', indoor: false, ageRange: '2-5 years', duration: '2-3 hours', price: 'Free', category: 'nature', lat: 46.5366, lon: 6.6421 , openingHours: 'Open daily', openingHoursDE: 'Täglich geöffnet'},
  { id: 'lausanne-aquatis', name: 'Aquatis Aquarium', nameDE: 'Aquatis Aquarium', description: "Europe's largest freshwater aquarium. Kids love the fish and crocodiles!", descriptionDE: 'Europas grösstes Süsswasseraquarium. Kinder lieben Fische und Krokodile!', indoor: true, ageRange: '2-5 years', duration: '2-3 hours', price: 'CHF 29 adults, CHF 19 kids', url: 'https://www.aquatis.ch', category: 'animals', lat: 46.5359, lon: 6.6178 , openingHours: 'Daily 10:00–18:00', openingHoursDE: 'Täglich 10:00–18:00'},
  { id: 'lausanne-ouchy', name: 'Ouchy Waterfront', nameDE: 'Ouchy Seepromenade', description: 'Lakeside promenade with playground, carousel, and boat rides.', descriptionDE: 'Seepromenade mit Spielplatz, Karussell und Bootsfahrten.', indoor: false, ageRange: '2-5 years', duration: '2-3 hours', price: 'Free', category: 'outdoor', lat: 46.5070, lon: 6.6290 , openingHours: 'Open daily', openingHoursDE: 'Täglich geöffnet'},
  { id: 'lausanne-espace-enfants', name: 'Espace des Inventions', nameDE: 'Espace des Inventions', description: 'Science museum for kids with hands-on experiments.', descriptionDE: 'Wissenschaftsmuseum für Kinder mit Experimenten zum Anfassen.', indoor: true, ageRange: '3-5 years', duration: '1-2 hours', price: 'CHF 10', url: 'https://www.espace-des-inventions.ch', category: 'museum', lat: 46.5192, lon: 6.5727 , openingHours: 'Tue–Sun 10:00–18:00', openingHoursDE: 'Di–So 10:00–18:00'},
  // Within 20km
  { id: 'lausanne-mon-repos', name: 'Parc de Mon-Repos', nameDE: 'Parc de Mon-Repos', description: 'Central park with playground, exotic birds, and shady picnic spots.', descriptionDE: 'Zentraler Park mit Spielplatz, exotischen Vögeln und schattigen Picknickplätzen.', indoor: false, ageRange: '2-5 years', duration: '1-2 hours', price: 'Free', category: 'playground', lat: 46.5255, lon: 6.6380 , openingHours: 'Open daily', openingHoursDE: 'Täglich geöffnet'},
  { id: 'lausanne-milan', name: 'Parc de Milan Playground', nameDE: 'Spielplatz Parc de Milan', description: 'Green oasis below the train station with swings, slides, and a sandpit.', descriptionDE: 'Grüne Oase unterhalb des Bahnhofs mit Schaukeln, Rutschen und Sandkasten.', indoor: false, ageRange: '2-5 years', duration: '1-2 hours', price: 'Free', category: 'playground', lat: 46.5174, lon: 6.6280 , openingHours: 'Tue–Sun 11:00–18:00', openingHoursDE: 'Di–So 11:00–18:00'},
  { id: 'lausanne-vidy-romain', name: 'Roman Museum Vidy', nameDE: 'Römisches Museum Vidy', description: 'Small free museum with Roman artifacts. Lakeside park with playground next door.', descriptionDE: 'Kleines Gratismuseum mit Römer-Fundstücken. Seepark mit Spielplatz nebenan.', indoor: true, ageRange: '3-5 years', duration: '1 hour', price: 'Free', category: 'museum', lat: 46.5155, lon: 6.5993 , openingHours: 'Open daily', openingHoursDE: 'Täglich geöffnet'},
  { id: 'lausanne-signal-bougy', name: 'Signal de Bougy Adventure Park', nameDE: 'Signal de Bougy Erlebnispark', description: 'Huge park with playgrounds, mini farm, mini golf, and lake views. Full day out!', descriptionDE: 'Riesiger Park mit Spielplätzen, Mini-Bauernhof, Minigolf und Seeblick. Ganzer Tag!', indoor: false, ageRange: '2-5 years', duration: '3-5 hours', price: 'CHF 9 per person', url: 'https://www.signaldebougy.ch', category: 'outdoor', lat: 46.4572, lon: 6.3861 , openingHours: 'Daily 10:00–18:00', openingHoursDE: 'Täglich 10:00–18:00'},
  { id: 'lausanne-morges', name: 'Morges Castle & Lakeside', nameDE: 'Schloss Morges & Seepromenade', description: 'Medieval castle with military museum, lakeside playground, and the famous tulip festival in spring.', descriptionDE: 'Mittelalterliches Schloss mit Museum, Seepromenade mit Spielplatz und berühmtem Tulpenfest im Frühling.', indoor: false, ageRange: '2-5 years', duration: '1-2 hours', price: 'Free (castle CHF 10)', category: 'outdoor', lat: 46.5112, lon: 6.4981 , openingHours: 'Open daily', openingHoursDE: 'Täglich geöffnet'},
  { id: 'lausanne-lutry', name: 'Lutry Lakeside & Lavaux Trail', nameDE: 'Lutry Seeweg & Lavaux', description: 'Charming lakeside village with playground, beach, and gentle vineyard walks.', descriptionDE: 'Charmantes Seedorf mit Spielplatz, Strand und sanften Weinbergspaziergängen.', indoor: false, ageRange: '2-5 years', duration: '1-3 hours', price: 'Free', category: 'nature', lat: 46.5058, lon: 6.6862 , openingHours: 'Open daily', openingHoursDE: 'Täglich geöffnet'},
  { id: 'lausanne-bellerive', name: 'Bellerive-Plage', nameDE: 'Bellerive-Plage', description: 'Lakeside swimming pool complex with toddler pool, slides, and huge lawn.', descriptionDE: 'Freibad am See mit Planschbecken, Rutschen und grosser Wiese.', indoor: false, ageRange: '2-5 years', duration: '2-4 hours', price: 'CHF 7 adults, kids under 6 free', category: 'outdoor', lat: 46.5092, lon: 6.6360 , openingHours: 'Daily 9:00–20:00', openingHoursDE: 'Täglich 9:00–20:00'},
];

const LUZERN = [
  { id: 'luzern-verkehrshaus', name: 'Swiss Museum of Transport', nameDE: 'Verkehrshaus der Schweiz', description: "Switzerland's most popular museum! Trains, planes, cars, and space exhibits.", descriptionDE: 'Beliebtestes Museum der Schweiz! Züge, Flugzeuge, Autos und Weltraumausstellungen.', indoor: true, ageRange: '2-5 years', duration: '3-4 hours', price: 'CHF 36 adults, kids under 6 free', url: 'https://www.verkehrshaus.ch', category: 'museum', minAge: 2, maxAge: 5, lat: 47.0528, lon: 8.3356 , openingHours: 'Daily 10:00–17:00', openingHoursDE: 'Täglich 10:00–17:00'},
  { id: 'luzern-gletschergarten', name: 'Glacier Garden & Mirror Maze', nameDE: 'Gletschergarten & Spiegellabyrinth', description: 'Explore prehistoric glacier potholes and get lost in the mirror maze!', descriptionDE: 'Prähistorische Gletschertöpfe erkunden und sich im Spiegellabyrinth verlieren!', indoor: true, ageRange: '3-5 years', duration: '1-2 hours', price: 'CHF 22 adults, CHF 8 kids', url: 'https://www.gletschergarten.ch', category: 'museum', minAge: 3, maxAge: 5, lat: 47.0585, lon: 8.3107 , openingHours: 'Daily 10:00–17:00', openingHoursDE: 'Täglich 10:00–17:00'},
  { id: 'luzern-ufschoetti', name: 'Ufschötti Park & Beach', nameDE: 'Ufschötti Park & Strand', description: 'Popular lakeside park with playground and swimming access.', descriptionDE: 'Beliebter Park am See mit Spielplatz und Bademöglichkeit.', indoor: false, ageRange: '2-5 years', duration: '2-3 hours', price: 'Free', category: 'playground', minAge: 2, maxAge: 5, lat: 47.0485, lon: 8.3173 , openingHours: 'Open daily', openingHoursDE: 'Täglich geöffnet'},
  { id: 'luzern-city-train', name: 'City Train Luzern', nameDE: 'City-Train Luzern', description: 'Fun little train ride through the old town and along the lake.', descriptionDE: 'Lustige kleine Zugfahrt durch die Altstadt und am See entlang.', indoor: false, ageRange: '2-5 years', duration: '45 min', price: 'CHF 10 adults, CHF 5 kids', category: 'outdoor', minAge: 2, maxAge: 5, lat: 47.0505, lon: 8.3064 , openingHours: 'Seasonal, see schedule', openingHoursDE: 'Saisonabhängig, siehe Fahrplan'},
  { id: 'luzern-natur-museum', name: 'Nature Museum Lucerne', nameDE: 'Natur-Museum Luzern', description: 'Local animals, dinosaurs, and hands-on exhibits for kids.', descriptionDE: 'Einheimische Tiere, Dinosaurier und interaktive Ausstellungen.', indoor: true, ageRange: '2-5 years', duration: '1-2 hours', price: 'CHF 10 adults, kids under 16 free', url: 'https://www.naturmuseum.ch', category: 'museum', minAge: 2, maxAge: 5, lat: 47.0503, lon: 8.3054 , openingHours: 'Tue–Sun 10:00–17:00', openingHoursDE: 'Di–So 10:00–17:00'},
  { id: 'luzern-playground-wettsteinpark', name: 'Wettsteinpark Playground', nameDE: 'Spielplatz Wettsteinpark', description: 'Central city playground with swings, slides, and sandbox.', descriptionDE: 'Zentraler Stadtspielplatz mit Schaukeln, Rutschen und Sandkasten.', indoor: false, ageRange: '2-5 years', duration: '1-2 hours', price: 'Free', category: 'playground', minAge: 2, maxAge: 5, lat: 47.0491, lon: 8.3098 , openingHours: 'Open daily', openingHoursDE: 'Täglich geöffnet'},
  { id: 'luzern-pilatus', name: 'Pilatus Krienseregg Playground', nameDE: 'Pilatus Krienseregg Spielplatz', description: 'Mountain adventure playground at the first cable car stop.', descriptionDE: 'Berg-Abenteuerspielplatz bei der ersten Seilbahnstation.', indoor: false, ageRange: '3-5 years', duration: '2-3 hours', price: 'Cable car CHF 36 return', url: 'https://www.pilatus.ch', category: 'outdoor', minAge: 3, maxAge: 5, lat: 46.9852, lon: 8.2647 , openingHours: 'Daily 8:30–17:00', openingHoursDE: 'Täglich 8:30–17:00'},
  { id: 'luzern-lido', name: 'Lido Luzern', nameDE: 'Lido Luzern', description: 'Lakeside park with sandy beach, playground, and swimming.', descriptionDE: 'Park am See mit Sandstrand, Spielplatz und Bademöglichkeit.', indoor: false, ageRange: '2-5 years', duration: '2-4 hours', price: 'CHF 7 adults, kids under 6 free', category: 'outdoor', minAge: 2, maxAge: 5, lat: 47.0539, lon: 8.3389 , openingHours: 'Daily 9:00–20:00', openingHoursDE: 'Täglich 9:00–20:00'},
  // Within 20km
  { id: 'luzern-tierpark-goldau', name: 'Tierpark Goldau', nameDE: 'Natur- und Tierpark Goldau', description: 'Walk among free-roaming deer and feed them! Bears, wolves, and 10 playgrounds.', descriptionDE: 'Zwischen freilaufenden Hirschen spazieren und füttern! Bären, Wölfe und 10 Spielplätze.', indoor: false, ageRange: '2-5 years', duration: '3-4 hours', price: 'CHF 22 adults, kids under 6 free', url: 'https://www.tierpark.ch', category: 'animals', minAge: 2, maxAge: 5, lat: 47.0482, lon: 8.5467 , openingHours: 'Daily 9:00–17:00', openingHoursDE: 'Täglich 9:00–17:00'},
  { id: 'luzern-historisches', name: 'Historical Museum Lucerne', nameDE: 'Historisches Museum Luzern', description: 'Costumes, armour, and interactive exhibits in a riverside building. Kids love the old weapons!', descriptionDE: 'Kostüme, Rüstungen und interaktive Ausstellungen am Fluss. Kinder lieben die alten Waffen!', indoor: true, ageRange: '3-5 years', duration: '1-2 hours', price: 'CHF 10 adults, kids under 16 free', url: 'https://www.historischesmuseum.lu.ch', category: 'museum', minAge: 3, maxAge: 5, lat: 47.0480, lon: 8.3060 , openingHours: 'Tue–Sun 10:00–17:00', openingHoursDE: 'Di–So 10:00–17:00'},
  { id: 'luzern-playground-voegelipark', name: 'Vögelipark Playground', nameDE: 'Spielplatz Vögelipark', description: 'City playground with water play features, climbing frames, and shaded areas.', descriptionDE: 'Stadtspielplatz mit Wasserspielen, Klettergerüsten und schattigem Bereich.', indoor: false, ageRange: '2-5 years', duration: '1-2 hours', price: 'Free', category: 'playground', minAge: 2, maxAge: 5, lat: 47.0530, lon: 8.3005 , openingHours: 'Open daily', openingHoursDE: 'Täglich geöffnet'},
  { id: 'luzern-rotsee', name: 'Rotsee Lake Walk', nameDE: 'Rotsee Rundweg', description: 'Flat, stroller-friendly walk around the small lake with bird-watching and picnic areas.', descriptionDE: 'Flacher, kinderwagentauglicher Rundweg um den kleinen See mit Vogelbeobachtung und Picknickplätzen.', indoor: false, ageRange: '2-5 years', duration: '1-2 hours', price: 'Free', category: 'nature', minAge: 2, maxAge: 5, lat: 47.0650, lon: 8.3210 , openingHours: 'Open daily', openingHoursDE: 'Täglich geöffnet'},
];

const WINTERTHUR = [
  { id: 'winterthur-technorama', name: 'Swiss Science Center Technorama', nameDE: 'Technorama Wissenschaftszentrum', description: "Europe's biggest science center! 500+ interactive exhibits!", descriptionDE: 'Europas grösstes Wissenschaftszentrum! 500+ interaktive Exponate!', indoor: true, ageRange: '3-5 years', duration: '3-5 hours', price: 'CHF 29 adults, CHF 18 kids', url: 'https://www.technorama.ch', category: 'museum', minAge: 3, maxAge: 5, lat: 47.5069, lon: 8.7167 , openingHours: 'Tue–Sun 10:00–17:00', openingHoursDE: 'Di–So 10:00–17:00'},
  { id: 'winterthur-wildpark-bruderhaus', name: 'Wildpark Bruderhaus', nameDE: 'Wildpark Bruderhaus', description: 'Free forest animal park with deer, wild boar, and wolves!', descriptionDE: 'Gratis Waldtierpark mit Hirschen, Wildschweinen und Wölfen!', indoor: false, ageRange: '2-5 years', duration: '2-3 hours', price: 'Free', url: 'https://www.wildpark.ch', category: 'animals', minAge: 2, maxAge: 5, lat: 47.4756, lon: 8.7891 , openingHours: 'Open daily', openingHoursDE: 'Täglich geöffnet'},
  { id: 'winterthur-stadtgarten', name: 'Stadtgarten Playground', nameDE: 'Spielplatz Stadtgarten', description: "The city's most popular playground in a beautiful park.", descriptionDE: 'Der beliebteste Spielplatz der Stadt in einem schönen Park.', indoor: false, ageRange: '2-5 years', duration: '1-2 hours', price: 'Free', category: 'playground', minAge: 2, maxAge: 5, lat: 47.4989, lon: 8.7264 , openingHours: 'Open daily', openingHoursDE: 'Täglich geöffnet'},
  { id: 'winterthur-piratolino', name: 'Piratolino Indoor Playground', nameDE: 'Piratolino Indoorspielplatz', description: 'Indoor play paradise with slides, ball pit, trampolines!', descriptionDE: 'Indoor-Spielparadies mit Rutschen, Bällebad, Trampolinen!', indoor: true, ageRange: '2-5 years', duration: '2-3 hours', price: 'CHF 15-18', url: 'https://www.piratolino.ch', category: 'indoor-play', minAge: 2, maxAge: 5, lat: 47.4847, lon: 8.7339 , openingHours: 'Daily 10:00–19:00', openingHoursDE: 'Täglich 10:00–19:00'},
  { id: 'winterthur-naturmuseum', name: 'Natural History Museum', nameDE: 'Naturmuseum Winterthur', description: 'Local wildlife exhibits with hands-on discovery room for children.', descriptionDE: 'Einheimische Tierwelt-Ausstellungen mit Entdeckerraum für Kinder.', indoor: true, ageRange: '2-5 years', duration: '1-2 hours', price: 'CHF 8 adults, kids under 16 free', url: 'https://www.naturmuseum.ch', category: 'museum', minAge: 2, maxAge: 5, lat: 47.4986, lon: 8.7279 , openingHours: 'Tue–Sun 10:00–17:00', openingHoursDE: 'Di–So 10:00–17:00'},
  { id: 'winterthur-skills-park', name: 'Skills Park', nameDE: 'Skills Park', description: 'Trampolines, climbing, and freestyle sports. Mini area for younger kids!', descriptionDE: 'Trampoline, Klettern und Freestyle-Sport. Mini-Bereich für kleinere Kinder!', indoor: true, ageRange: '4-5 years', duration: '2-3 hours', price: 'CHF 25', url: 'https://www.skillspark.ch', category: 'indoor-play', minAge: 4, maxAge: 5, lat: 47.5003, lon: 8.6956 , openingHours: 'Mon–Fri 14:00–22:00, Sat–Sun 10:00–20:00', openingHoursDE: 'Mo–Fr 14:00–22:00, Sa–So 10:00–20:00'},
  { id: 'winterthur-fotomuseum', name: 'Fotomuseum Winterthur', nameDE: 'Fotomuseum Winterthur', description: 'Photography museum with family workshops.', descriptionDE: 'Fotomuseum mit Familienworkshops.', indoor: true, ageRange: '4-5 years', duration: '1-2 hours', price: 'CHF 12 adults, kids under 16 free', url: 'https://www.fotomuseum.ch', category: 'museum', minAge: 4, maxAge: 5, lat: 47.4969, lon: 8.7234 , openingHours: 'Tue–Sun 11:00–18:00, Wed 11:00–20:00', openingHoursDE: 'Di–So 11:00–18:00, Mi 11:00–20:00'},
  { id: 'winterthur-rosengarten', name: 'Rosengarten Park', nameDE: 'Rosengarten', description: 'Beautiful rose garden with playground and small animal enclosure.', descriptionDE: 'Schöner Rosengarten mit Spielplatz und kleinem Tiergehege.', indoor: false, ageRange: '2-5 years', duration: '1-2 hours', price: 'Free', category: 'nature', minAge: 2, maxAge: 5, lat: 47.4942, lon: 8.7337 , openingHours: 'Open daily', openingHoursDE: 'Täglich geöffnet'},
  // Within 20km
  { id: 'winterthur-kyburg', name: 'Kyburg Castle', nameDE: 'Schloss Kyburg', description: 'Medieval castle with dragon hunt for kids, try on armour, and playground in the garden.', descriptionDE: 'Mittelalterliche Burg mit Drachenjagd für Kinder, Rüstung anprobieren und Spielplatz im Garten.', indoor: false, ageRange: '3-5 years', duration: '1-2 hours', price: 'CHF 10 adults, CHF 5 kids', url: 'https://www.schlosskyburg.ch', category: 'museum', minAge: 3, maxAge: 5, lat: 47.4578, lon: 8.7445 , openingHours: 'Tue–Sun 10:00–17:00', openingHoursDE: 'Di–So 10:00–17:00'},
  { id: 'winterthur-schloss-hegi', name: 'Schloss Hegi', nameDE: 'Schloss Hegi', description: 'Small castle with garden and museum. Quiet spot for a family walk.', descriptionDE: 'Kleines Schloss mit Garten und Museum. Ruhiger Ort für einen Familienspaziergang.', indoor: false, ageRange: '2-5 years', duration: '1 hour', price: 'Free grounds, museum CHF 5', category: 'outdoor', minAge: 2, maxAge: 5, lat: 47.4930, lon: 8.7580 , openingHours: 'Open daily (grounds)', openingHoursDE: 'Täglich geöffnet (Gelände)'},
  { id: 'winterthur-eulachpark', name: 'Eulachpark Playground', nameDE: 'Spielplatz Eulachpark', description: 'Modern playground along the Eulach river with water play and natural elements.', descriptionDE: 'Moderner Spielplatz am Eulachfluss mit Wasserspiel und Naturelementen.', indoor: false, ageRange: '2-5 years', duration: '1-2 hours', price: 'Free', category: 'playground', minAge: 2, maxAge: 5, lat: 47.4960, lon: 8.7200 , openingHours: 'Open daily', openingHoursDE: 'Täglich geöffnet'},
  { id: 'winterthur-pfaffikersee', name: 'Pfäffikersee Nature Reserve', nameDE: 'Naturschutzgebiet Pfäffikersee', description: 'Flat lakeside walk through wetlands with bird-watching towers and playground in Pfäffikon.', descriptionDE: 'Flacher Seerundweg durch Feuchtgebiete mit Vogelbeobachtungstürmen und Spielplatz in Pfäffikon.', indoor: false, ageRange: '2-5 years', duration: '1-3 hours', price: 'Free', category: 'nature', minAge: 2, maxAge: 5, lat: 47.3653, lon: 8.7819 , openingHours: 'Open daily', openingHoursDE: 'Täglich geöffnet'},
];

const CITY_ACTIVITIES = { zurich: ZURICH, basel: BASEL, bern: BERN, geneva: GENEVA, lausanne: LAUSANNE, luzern: LUZERN, winterthur: WINTERTHUR };

const ALL_ACTIVITIES = Object.values(CITY_ACTIVITIES).flat();

export function getActivityById(id) {
  return ALL_ACTIVITIES.find(a => a.id === id) || null;
}

/* ── Seasonal activities ── */

function getCurrentSeason() {
  const m = new Date().getMonth() + 1;
  if (m >= 3 && m <= 5) return 'spring';
  if (m >= 6 && m <= 8) return 'summer';
  if (m >= 9 && m <= 11) return 'autumn';
  return 'winter';
}

function getSeasonalActivities(cityId) {
  const season = getCurrentSeason();
  const acts = [];
  const a = (obj) => acts.push(obj);

  if (cityId === 'zurich') {
    if (season === 'winter') {
      a({ id: 'zurich-christkindlimarkt', name: 'Christmas Market at Main Station', nameDE: 'Christkindlimarkt Hauptbahnhof', description: 'Magical indoor Christmas market with Swarovski tree.', descriptionDE: 'Magischer Indoor-Weihnachtsmarkt mit Swarovski-Baum.', indoor: true, ageRange: '2-5 years', duration: '1-2 hours', price: 'Free entry', category: 'seasonal', season: 'winter', availableMonths: [11, 12], minAge: 2, maxAge: 5, lat: 47.3779, lon: 8.5403 });
      a({ id: 'zurich-ice-skating-dolder', name: 'Ice Skating at Dolder', nameDE: 'Eislaufen Dolder', description: 'Beautiful outdoor ice rink with mountain views. Penguin aids for kids!', descriptionDE: 'Schöne Outdoor-Eisbahn mit Bergblick. Pinguin-Laufhilfen für Kinder!', indoor: false, ageRange: '3-5 years', duration: '1-2 hours', price: 'CHF 9 adults, CHF 6 kids', url: 'https://www.doldereisbahn.ch', category: 'seasonal', season: 'winter', availableMonths: [11, 12, 1, 2], minAge: 3, maxAge: 5, lat: 47.3722, lon: 8.5756 });
      a({ id: 'zurich-singing-christmas-tree', name: 'Singing Christmas Tree', nameDE: 'Singender Weihnachtsbaum', description: 'Live choir performances on Werdmühleplatz.', descriptionDE: 'Live-Choraufführungen auf dem Werdmühleplatz.', indoor: false, ageRange: '2-5 years', duration: '30 min', price: 'Free', category: 'seasonal', season: 'winter', availableMonths: [12], minAge: 2, maxAge: 5, lat: 47.3728, lon: 8.5369 });
    }
    if (season === 'summer') {
      a({ id: 'zurich-freibad-mythenquai', name: 'Freibad Mythenquai', nameDE: 'Freibad Mythenquai', description: 'Lake swimming with dedicated toddler pool and playground.', descriptionDE: 'Seebad mit Kleinkind-Becken und Spielplatz.', indoor: false, ageRange: '2-5 years', duration: '2-4 hours', price: 'CHF 8 adults, kids under 6 free', category: 'seasonal', season: 'summer', minAge: 2, maxAge: 5, lat: 47.3559, lon: 8.5357 });
      a({ id: 'zurich-letten', name: 'Oberer Letten River Pool', nameDE: 'Flussbad Oberer Letten', description: 'River swimming in the Limmat. Shallow areas for paddling.', descriptionDE: 'Flussschwimmen in der Limmat. Flache Bereiche zum Planschen.', indoor: false, ageRange: '3-5 years', duration: '2-3 hours', price: 'Free', category: 'seasonal', season: 'summer', minAge: 3, maxAge: 5, lat: 47.3890, lon: 8.5318 });
      a({ id: 'zurich-wasserspielplatz', name: 'Water Playground Blatterwiese', nameDE: 'Wasserspielplatz Blatterwiese', description: 'Free water playground by the lake.', descriptionDE: 'Gratis Wasserspielplatz am See.', indoor: false, ageRange: '2-5 years', duration: '1-3 hours', price: 'Free', category: 'seasonal', season: 'summer', minAge: 2, maxAge: 5, lat: 47.3545, lon: 8.5480 });
    }
    if (season === 'autumn') {
      a({ id: 'zurich-knies-kinderzoo', name: 'Knies Kinderzoo Rapperswil', nameDE: 'Knies Kinderzoo Rapperswil', description: 'Petting zoo and circus animals. Elephant rides!', descriptionDE: 'Streichelzoo und Zirkustiere. Elefantenreiten!', indoor: false, ageRange: '2-5 years', duration: '3-4 hours', price: 'CHF 15', url: 'https://www.kfrz.ch', category: 'seasonal', season: 'autumn', minAge: 2, maxAge: 5, lat: 47.2267, lon: 8.8185 });
      a({ id: 'zurich-pumpkin-juckerhof', name: 'Pumpkin Exhibition Juckerhof', nameDE: 'Kürbisausstellung Juckerhof', description: 'Giant pumpkin sculptures, corn maze, and farm animals.', descriptionDE: 'Riesige Kürbisskulpturen, Maislabyrinth und Bauernhoftiere.', indoor: false, ageRange: '2-5 years', duration: '2-3 hours', price: 'CHF 10', url: 'https://www.juckerfarm.ch', category: 'seasonal', season: 'autumn', minAge: 2, maxAge: 5, lat: 47.3411, lon: 8.7459 });
    }
    if (season === 'spring') {
      a({ id: 'zurich-tulips-arboretum', name: 'Tulip Garden at Arboretum', nameDE: 'Tulpengarten im Arboretum', description: 'Beautiful tulip displays by the lake.', descriptionDE: 'Wunderschöne Tulpen am See.', indoor: false, ageRange: '2-5 years', duration: '1 hour', price: 'Free', category: 'seasonal', season: 'spring', minAge: 2, maxAge: 5, lat: 47.3592, lon: 8.5365 });
      a({ id: 'zurich-sechselauten', name: 'Sechseläuten Parade', nameDE: 'Sechseläuten Umzug', description: 'Spring festival with parade and the Böögg burning!', descriptionDE: 'Frühlingsfest mit Umzug und Böögg-Verbrennung!', indoor: false, ageRange: '4-5 years', duration: '2-3 hours', price: 'Free', category: 'seasonal', season: 'spring', availableMonths: [4], minAge: 4, maxAge: 5, lat: 47.3666, lon: 8.5449 });
    }
  }

  if (cityId === 'basel' && season === 'winter')
    a({ id: 'basel-weihnachtsmarkt', name: 'Basel Christmas Market', nameDE: 'Basler Weihnachtsmarkt', description: "One of Switzerland's most beautiful Christmas markets.", descriptionDE: 'Einer der schönsten Weihnachtsmärkte der Schweiz.', indoor: false, ageRange: '2-5 years', duration: '1-2 hours', price: 'Free entry', category: 'seasonal', season: 'winter', availableMonths: [11, 12], minAge: 2, maxAge: 5, lat: 47.5546, lon: 7.5892 });

  if (cityId === 'bern' && season === 'winter')
    a({ id: 'bern-zibelemaerit', name: 'Onion Market (November)', nameDE: 'Zibelemärit', description: 'Traditional onion market with confetti battles.', descriptionDE: 'Traditioneller Zwiebelmarkt mit Konfettischlachten.', indoor: false, ageRange: '3-5 years', duration: '2-3 hours', price: 'Free', category: 'seasonal', season: 'winter', availableMonths: [11], minAge: 3, maxAge: 5, lat: 47.9480, lon: 7.4474 });

  if (cityId === 'luzern') {
    if (season === 'winter') {
      a({ id: 'luzern-weihnachtsmarkt', name: 'Lucerne Christmas Market', nameDE: 'Luzerner Weihnachtsmarkt', description: 'Charming Christmas market in the old town.', descriptionDE: 'Charmanter Weihnachtsmarkt in der Altstadt.', indoor: false, ageRange: '2-5 years', duration: '1-2 hours', price: 'Free entry', category: 'seasonal', season: 'winter', availableMonths: [11, 12], minAge: 2, maxAge: 5, lat: 47.0508, lon: 8.3074 });
      a({ id: 'luzern-fasnacht', name: 'Luzerner Fasnacht (Carnival)', nameDE: 'Luzerner Fasnacht', description: 'Famous Swiss carnival with parades and costumes!', descriptionDE: 'Berühmte Schweizer Fasnacht mit Umzügen und Kostümen!', indoor: false, ageRange: '3-5 years', duration: '2-3 hours', price: 'Free', category: 'seasonal', season: 'winter', availableMonths: [2, 3], minAge: 3, maxAge: 5, lat: 47.0505, lon: 8.3064 });
    }
    if (season === 'summer')
      a({ id: 'luzern-lake-swimming', name: 'Lake Lucerne Swimming', nameDE: 'Vierwaldstättersee Baden', description: 'Crystal clear lake water for swimming.', descriptionDE: 'Kristallklares Seewasser zum Schwimmen.', indoor: false, ageRange: '2-5 years', duration: '2-4 hours', price: 'Free at public beaches', category: 'seasonal', season: 'summer', minAge: 2, maxAge: 5, lat: 47.0485, lon: 8.3173 });
  }

  if (cityId === 'winterthur') {
    if (season === 'winter') {
      a({ id: 'winterthur-weihnachtsmarkt', name: 'Winterthur Christmas Market', nameDE: 'Winterthurer Weihnachtsmarkt', description: 'Cozy Christmas market in the old town.', descriptionDE: 'Gemütlicher Weihnachtsmarkt in der Altstadt.', indoor: false, ageRange: '2-5 years', duration: '1-2 hours', price: 'Free entry', category: 'seasonal', season: 'winter', availableMonths: [11, 12], minAge: 2, maxAge: 5, lat: 47.4989, lon: 8.7245 });
      a({ id: 'winterthur-eisfeld', name: 'Ice Skating Neuwiesen', nameDE: 'Eisbahn Neuwiesen', description: 'Outdoor ice skating rink. Penguin aids for kids!', descriptionDE: 'Outdoor-Eisbahn. Pinguin-Laufhilfen für Kinder!', indoor: false, ageRange: '3-5 years', duration: '1-2 hours', price: 'CHF 8', category: 'seasonal', season: 'winter', availableMonths: [11, 12, 1, 2], minAge: 3, maxAge: 5, lat: 47.4956, lon: 8.7178 });
    }
    if (season === 'summer') {
      a({ id: 'winterthur-technorama-outdoor', name: 'Technorama Outdoor Park', nameDE: 'Technorama Draussen', description: 'Water experiments and outdoor science fun!', descriptionDE: 'Wasserexperimente und Outdoor-Wissenschaftsspass!', indoor: false, ageRange: '3-5 years', duration: '2-3 hours', price: 'Included with Technorama ticket', url: 'https://www.technorama.ch', category: 'seasonal', season: 'summer', minAge: 3, maxAge: 5, lat: 47.5069, lon: 8.7167 });
      a({ id: 'winterthur-freibad-geiselweid', name: 'Geiselweid Outdoor Pool', nameDE: 'Freibad Geiselweid', description: 'Large outdoor pool with toddler area and slides.', descriptionDE: 'Grosses Freibad mit Kleinkindbereich und Rutschen.', indoor: false, ageRange: '2-5 years', duration: '2-4 hours', price: 'CHF 8 adults, kids under 6 free', category: 'seasonal', season: 'summer', minAge: 2, maxAge: 5, lat: 47.4981, lon: 8.7092 });
    }
  }

  // Filter by available months
  const cm = new Date().getMonth() + 1;
  return acts.filter(x => !x.availableMonths || x.availableMonths.includes(cm));
}

/* ── Stay-home activities ── */

function getStayHomeActivities() {
  const s = (id, name, nameDE, desc, descDE, sub, age, dur, mat, matDE) =>
    ({ id: `stayhome-${id}`, name, nameDE, description: desc, descriptionDE: descDE, category: 'stayhome', subcategory: sub, indoor: true, ageRange: `${age[0]}-${age[1]} years`, minAge: age[0], maxAge: age[1], duration: dur, materials: mat, materialsDE: matDE });

  return [
    // Sensory (8)
    s('rainbow-rice', 'Rainbow Rice Sensory Bin', 'Regenbogen-Reis Sensorikbox', 'Fill a bin with colored rice and hide small toys to discover.', 'Box mit gefärbtem Reis füllen und kleine Spielzeuge verstecken.', 'sensory', [2,5], '30-45 min', 'Rice, food coloring, vinegar, bin, small toys', 'Reis, Lebensmittelfarbe, Essig, Box, kleine Spielzeuge'),
    s('water-pouring', 'Water Pouring Station', 'Wasser-Giessstation', 'Set up cups, funnels, and containers for pouring and measuring.', 'Becher, Trichter und Behälter zum Giessen und Messen.', 'sensory', [2,5], '20-30 min', 'Cups, funnels, containers, towel, water', 'Becher, Trichter, Behälter, Handtuch, Wasser'),
    s('playdough', 'Homemade Playdough', 'Selbstgemachte Knete', 'Make colorful playdough together, then sculpt animals.', 'Gemeinsam bunte Knete herstellen und Tiere formen.', 'sensory', [2,5], '45-60 min', 'Flour, salt, water, oil, food coloring', 'Mehl, Salz, Wasser, Öl, Lebensmittelfarbe'),
    s('cloud-dough', 'Cloud Dough', 'Wolkenteig', 'Mix flour and oil to make silky moldable cloud dough.', 'Mehl und Öl mischen für seidig formbaren Wolkenteig.', 'sensory', [2,5], '30 min', 'Flour, baby oil or vegetable oil, bin', 'Mehl, Babyöl oder Pflanzenöl, Box'),
    s('frozen-treasure', 'Frozen Treasure Excavation', 'Eisschatz-Ausgrabung', 'Freeze small toys in ice and let your child chip them free.', 'Kleine Spielzeuge in Eis einfrieren und befreien lassen.', 'sensory', [2,5], '30-45 min', 'Container, small toys, water, freezer, warm water', 'Behälter, kleine Spielzeuge, Wasser, Gefrierfach, warmes Wasser'),
    s('shaving-cream', 'Shaving Cream Painting', 'Rasierschaum-Malerei', 'Spread shaving cream on a tray and draw, swirl, mix colors.', 'Rasierschaum auf Tablett verteilen und malen, wirbeln, mischen.', 'sensory', [2,5], '20-30 min', 'Shaving cream, tray, food coloring', 'Rasierschaum, Tablett, Lebensmittelfarbe'),
    s('pasta-threading', 'Pasta Threading', 'Nudeln auffädeln', 'Thread penne onto string or pipe cleaners to make necklaces.', 'Penne auf Schnüre oder Pfeifenputzer auffädeln.', 'sensory', [2,5], '20-30 min', 'Dry pasta (penne), string or pipe cleaners', 'Trockene Nudeln, Schnur oder Pfeifenputzer'),
    s('bubble-wrap', 'Bubble Wrap Stomp', 'Luftpolsterfolie stampfen', 'Tape bubble wrap to the floor and stomp, jump, and pop!', 'Luftpolsterfolie auf den Boden kleben und stampfen!', 'sensory', [2,5], '15-20 min', 'Bubble wrap, tape', 'Luftpolsterfolie, Klebeband'),
    // Art (8)
    s('finger-painting', 'Finger Painting', 'Fingermalerei', 'Get messy with washable finger paints on big sheets of paper.', 'Kreativ werden mit abwaschbaren Fingerfarben.', 'art', [2,5], '30-45 min', 'Washable finger paints, large paper, smock', 'Abwaschbare Fingerfarben, grosses Papier, Kittel'),
    s('magazine-collage', 'Magazine Collage', 'Zeitschriften-Collage', 'Cut or tear pictures from old magazines and glue into a collage.', 'Bilder aus alten Zeitschriften schneiden und zu Collage kleben.', 'art', [3,5], '30-45 min', 'Old magazines, child scissors, glue stick, paper', 'Alte Zeitschriften, Kinderschere, Klebestift, Papier'),
    s('veggie-stamps', 'Veggie Stamp Printing', 'Gemüsestempel-Druck', 'Cut vegetables in half and use as stamps with washable paint.', 'Gemüse halbieren und als Stempel verwenden.', 'art', [2,5], '30 min', 'Celery, peppers, potatoes, washable paint, paper', 'Sellerie, Peperoni, Kartoffeln, abwaschbare Farbe, Papier'),
    s('paper-plate-animals', 'Paper Plate Animals', 'Pappteller-Tiere', 'Turn paper plates into animal faces with paint and googly eyes.', 'Pappteller mit Farbe und Wackelaugen in Tiergesichter verwandeln.', 'art', [2,5], '30-45 min', 'Paper plates, paint, googly eyes, glue, pipe cleaners', 'Pappteller, Farbe, Wackelaugen, Kleber, Pfeifenputzer'),
    s('handprint-art', 'Handprint Art', 'Handabdruck-Kunst', 'Create animals, flowers, and trees using painted handprints.', 'Tiere, Blumen und Bäume aus bemalten Handabdrücken.', 'art', [2,5], '30 min', 'Washable paint, paper, wet wipes', 'Abwaschbare Farbe, Papier, Feuchttücher'),
    s('cardboard-house', 'Cardboard Box House', 'Kartonhaus', 'Transform a large cardboard box into a playhouse or castle.', 'Grossen Karton in Spielhaus oder Schloss verwandeln.', 'art', [2,5], '45-60 min', 'Large cardboard box, markers, tape, scissors', 'Grosser Karton, Stifte, Klebeband, Schere'),
    s('cotton-clouds', 'Cotton Ball Clouds', 'Wattewolken', 'Glue cotton balls onto blue paper to create fluffy cloud scenes.', 'Wattebäusche auf blaues Papier kleben für Wolkenbilder.', 'art', [2,5], '20-30 min', 'Cotton balls, blue paper, glue, crayons', 'Wattebäusche, blaues Papier, Kleber, Buntstifte'),
    s('salt-painting', 'Salt Painting', 'Salzmalerei', 'Draw with glue, sprinkle salt, then drop watercolors to watch them spread.', 'Mit Kleber malen, Salz streuen, dann Wasserfarben tropfen.', 'art', [3,5], '30-45 min', 'White glue, salt, watercolors, cardstock, dropper', 'Bastelkleber, Salz, Wasserfarben, Karton, Pipette'),
    // Active (8)
    s('obstacle-course', 'Indoor Obstacle Course', 'Indoor-Hindernisparcours', 'Build a course with cushions to climb, tunnels to crawl.', 'Parcours mit Kissen zum Klettern und Tunneln zum Krabbeln.', 'active', [2,5], '30-45 min', 'Cushions, blankets, chairs, tape', 'Kissen, Decken, Stühle, Klebeband'),
    s('dance-party', 'Dance Party', 'Tanzparty', 'Put on favorite music and dance together — try freeze dance!', 'Lieblingsmusik anmachen und zusammen tanzen — Stopptanz!', 'active', [2,5], '20-30 min', 'Music player, space to dance', 'Musikgerät, Platz zum Tanzen'),
    s('balloon-tennis', 'Balloon Tennis', 'Ballon-Tennis', 'Tape paper plates to sticks for paddles and bat a balloon.', 'Pappteller an Stöcke kleben und einen Ballon schlagen.', 'active', [3,5], '20-30 min', 'Balloon, paper plates, wooden spoons or sticks', 'Ballon, Pappteller, Holzlöffel oder Stöcke'),
    s('animal-yoga', 'Animal Yoga', 'Tier-Yoga', 'Do yoga poses named after animals — cat, dog, frog, butterfly!', 'Yoga-Posen nach Tieren — Katze, Hund, Frosch, Schmetterling!', 'active', [2,5], '15-20 min', 'Yoga mat or soft surface', 'Yogamatte oder weiche Unterlage'),
    s('sock-basketball', 'Sock Basketball', 'Socken-Basketball', 'Roll up socks into balls and toss them into a laundry basket.', 'Socken zu Bällen rollen und in Wäschekorb werfen.', 'active', [2,5], '15-20 min', 'Socks, laundry basket', 'Socken, Wäschekorb'),
    s('musical-statues', 'Musical Statues', 'Musikstatuen', 'Dance when the music plays, freeze when it stops!', 'Tanzen wenn Musik spielt, einfrieren wenn sie stoppt!', 'active', [2,5], '20-30 min', 'Music player', 'Musikgerät'),
    s('pillow-fort', 'Pillow Fort', 'Kissenfort', 'Build an epic fort with pillows and blankets — then read stories inside!', 'Episches Fort aus Kissen und Decken bauen!', 'active', [2,5], '30-60 min', 'Pillows, blankets, cushions, chairs', 'Kissen, Decken, Polster, Stühle'),
    s('treasure-hunt', 'Indoor Treasure Hunt', 'Indoor-Schatzsuche', 'Hide small toys around the house with simple picture clues.', 'Kleine Spielzeuge verstecken mit Bild-Hinweisen.', 'active', [3,5], '30-45 min', 'Small toys or treats, paper for clues', 'Kleine Spielzeuge, Papier für Hinweise'),
    // Pretend (8)
    s('restaurant', 'Play Restaurant', 'Restaurant spielen', 'Set up a pretend restaurant — take orders, cook, and serve.', 'Restaurant einrichten — bestellen, kochen, servieren.', 'pretend', [3,5], '30-45 min', 'Play food, paper for menus, apron', 'Spielessen, Papier für Menükarten, Schürze'),
    s('doctor', "Doctor's Office", 'Arztpraxis spielen', 'Play doctor with stuffed animals as patients.', 'Arzt spielen mit Kuscheltieren als Patienten.', 'pretend', [2,5], '30 min', 'Stuffed animals, bandages, toy stethoscope', 'Kuscheltiere, Pflaster, Spielzeug-Stethoskop'),
    s('grocery-shop', 'Grocery Shop', 'Lebensmittelladen spielen', 'Set up a pretend shop with food, price tags, and cash register.', 'Spielladen mit Lebensmitteln, Preisschildern und Kasse.', 'pretend', [3,5], '30-45 min', 'Play food or pantry items, paper for price tags, bags', 'Spielessen, Papier für Preisschilder, Tüten'),
    s('post-office', 'Post Office', 'Post spielen', 'Write letters, decorate envelopes, and deliver mail around the house.', 'Briefe schreiben, Umschläge dekorieren und Post verteilen.', 'pretend', [3,5], '30-45 min', 'Paper, envelopes, stickers, crayons', 'Papier, Umschläge, Sticker, Buntstifte'),
    s('puppet-show', 'Sock Puppet Show', 'Sockenpuppen-Theater', 'Make puppets from old socks and put on a show.', 'Puppen aus alten Socken basteln und vorführen.', 'pretend', [2,5], '30-45 min', 'Old socks, buttons, markers, chair', 'Alte Socken, Knöpfe, Stifte, Stuhl'),
    s('camping', 'Indoor Camping', 'Indoor-Camping', 'Set up a tent or blanket fort, use flashlights.', 'Zelt oder Deckenzelt aufbauen, Taschenlampen benutzen.', 'pretend', [2,5], '45-60 min', 'Blankets, flashlights, stuffed animals, snacks', 'Decken, Taschenlampen, Kuscheltiere, Snacks'),
    s('animal-hospital', 'Animal Hospital', 'Tierspital spielen', 'Set up a vet clinic for stuffed animals.', 'Tierklinik für Kuscheltiere einrichten.', 'pretend', [2,5], '30 min', 'Stuffed animals, bandages, blankets, toy medical kit', 'Kuscheltiere, Pflaster, Decken, Spielzeug-Arztkoffer'),
    s('hair-salon', 'Hair Salon', 'Friseursalon spielen', "Style dolls' hair with clips, brushes, and pretend blow-dryers.", 'Puppen-Haare mit Clips, Bürsten und Spiel-Föhns stylen.', 'pretend', [2,5], '20-30 min', 'Dolls or stuffed animals, hair clips, brush, spray bottle', 'Puppen, Haarklammern, Bürste, Sprühflasche'),
    // Kitchen (8)
    s('cookie-decorating', 'Cookie Decorating', 'Kekse dekorieren', 'Bake simple cookies and let your toddler decorate them.', 'Einfache Kekse backen und dekorieren lassen.', 'kitchen', [2,5], '45-60 min', 'Cookie dough or mix, icing, sprinkles', 'Keksteig oder Backmischung, Glasur, Streusel'),
    s('fruit-salad', 'Fruit Salad Making', 'Fruchtsalat machen', 'Wash, peel, and chop soft fruits together.', 'Weiches Obst zusammen waschen, schälen und schneiden.', 'kitchen', [2,5], '20-30 min', 'Assorted fruits, child-safe knife, bowl', 'Verschiedene Früchte, Kindermesser, Schüssel'),
    s('smoothie', 'Smoothie Mixing', 'Smoothie mixen', 'Pick fruits, add yogurt, and blend a yummy smoothie.', 'Früchte auswählen, Joghurt dazu und mixen.', 'kitchen', [2,5], '15-20 min', 'Fruits, yogurt, blender, cups', 'Früchte, Joghurt, Mixer, Becher'),
    s('pizza-faces', 'Pizza Faces', 'Pizza-Gesichter', 'Use pre-made dough and make funny faces with toppings.', 'Fertigen Teig verwenden und lustige Gesichter mit Belag machen.', 'kitchen', [2,5], '30-45 min', 'Pizza dough, sauce, cheese, vegetable toppings', 'Pizzateig, Sauce, Käse, Gemüsebelag'),
    s('cookie-sandwiches', 'Cookie Cutter Sandwiches', 'Ausstecher-Sandwiches', 'Use cookie cutters to make fun-shaped sandwiches.', 'Ausstechformen für lustig geformte Sandwiches verwenden.', 'kitchen', [2,5], '15-20 min', 'Bread, fillings, cookie cutters', 'Brot, Belag, Ausstechformen'),
    s('trail-mix', 'Trail Mix Sorting', 'Studentenfutter sortieren', 'Sort and mix cereals, raisins, and crackers into snack bags.', 'Müsli, Rosinen und Cracker sortieren und mischen.', 'kitchen', [2,5], '15-20 min', 'Cereals, raisins, crackers, small bags or cups', 'Müsli, Rosinen, Cracker, kleine Tüten oder Becher'),
    s('banana-icecream', 'Banana Ice Cream', 'Bananen-Eiscreme', 'Blend frozen bananas for instant healthy ice cream.', 'Gefrorene Bananen für sofortige gesunde Eiscreme mixen.', 'kitchen', [2,5], '15-20 min', 'Frozen bananas, blender, toppings (berries, cocoa)', 'Gefrorene Bananen, Mixer, Toppings (Beeren, Kakao)'),
    s('veggie-washing', 'Vegetable Washing Station', 'Gemüse-Waschstation', 'Set up a washing station and let your toddler scrub vegetables.', 'Waschstation einrichten und Ihr Kind Gemüse schrubben lassen.', 'kitchen', [2,5], '15-20 min', 'Vegetables, basin, scrub brush, towel', 'Gemüse, Schüssel, Schrubbürste, Handtuch'),
  ];
}

/* ── Public API ── */

export async function getCuratedActivities(env, cityId) {
  if (env.ACTIVITIES_KV) {
    try {
      const custom = await env.ACTIVITIES_KV.get(`activities-${cityId}`, 'json');
      if (custom?.length > 0) return custom;
    } catch {}
  }
  const all = [...(CITY_ACTIVITIES[cityId] || CITY_ACTIVITIES.zurich), ...getSeasonalActivities(cityId), ...getStayHomeActivities()];
  // Auto-tag free activities
  for (const a of all) {
    if (a.price && /^free|^gratis/i.test(a.price.trim())) a.free = true;
  }
  return all;
}

async function fetchGoogleHours(name, lat, lon, apiKey) {
  try {
    const searchUrl = `https://maps.googleapis.com/maps/api/place/findplacefromtext/json?input=${encodeURIComponent(name)}&inputtype=textquery&locationbias=point:${lat},${lon}&fields=opening_hours,business_status&key=${apiKey}`;
    const res = await fetch(searchUrl);
    if (!res.ok) return null;
    const data = await res.json();
    if (data.status !== 'OK' || !data.candidates?.length) return null;
    const c = data.candidates[0];
    return {
      openNow: c.opening_hours?.open_now ?? null,
      weekdayText: c.opening_hours?.weekday_text || null,
      closed: c.business_status === 'CLOSED_PERMANENTLY',
      cachedAt: Date.now()
    };
  } catch { return null; }
}

async function enrichWithHours(activities, cityId, env) {
  if (!env.GOOGLE_PLACES_KEY || !env.PHOTOS_BUCKET) return activities;

  const r2Key = `hours/city-${cityId}.json`;
  let cache = {};
  try {
    const obj = await env.PHOTOS_BUCKET.get(r2Key);
    if (obj) cache = JSON.parse(await obj.text());
  } catch {}

  const now = Date.now();
  // Only enrich non-stayhome activities with coordinates
  const enrichable = activities.filter(a => a.category !== 'stayhome' && a.lat && a.lon);
  // Only fetch if not yet cached (no expiry — hours/status rarely change)
  const uncached = enrichable.filter(a => !cache[a.id]);

  const MAX_GOOGLE = 10;
  const toFetch = uncached.slice(0, MAX_GOOGLE);
  if (toFetch.length > 0) {
    const fetches = toFetch.map(async (a) => {
      const hours = await fetchGoogleHours(a.name, a.lat, a.lon, env.GOOGLE_PLACES_KEY);
      cache[a.id] = hours || { openNow: null, weekdayText: null, closed: false, cachedAt: now };
    });
    await Promise.allSettled(fetches);

    await env.PHOTOS_BUCKET.put(r2Key, JSON.stringify(cache), {
      httpMetadata: { contentType: 'application/json' }
    });
  }

  return activities.map(a => {
    const h = cache[a.id];
    if (!h) return a;
    const enriched = { ...a };
    if (h.openNow !== null) enriched.openNow = h.openNow;
    if (h.weekdayText) enriched.weekdayText = h.weekdayText;
    if (h.closed) enriched.permanentlyClosed = true;
    return enriched;
  });
}

export async function handleActivities(url, env) {
  const cityId = url.searchParams.get('city') || 'zurich';
  const city = getCity(cityId);

  const [weather, activities] = await Promise.all([
    fetchWeather(city.lat, city.lon),
    getCuratedActivities(env, cityId)
  ]);

  let enriched = await enrichWithHours(activities, cityId, env);
  let sorted = enriched;
  if (weather) {
    const bad = RAINY_CODES.includes(weather.weatherCode) || weather.temperature < 5;
    if (bad) sorted = [...enriched].sort((a, b) => (a.indoor ? -1 : 1) - (b.indoor ? -1 : 1));
  }

  return new Response(JSON.stringify({
    activities: sorted,
    cityEvents: getCityEvents(cityId),
    weather,
    city: { id: cityId, name: city.name },
    timestamp: new Date().toISOString()
  }), {
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': env.ALLOWED_ORIGIN || '*',
      'Cache-Control': 'public, max-age=1800'
    }
  });
}
