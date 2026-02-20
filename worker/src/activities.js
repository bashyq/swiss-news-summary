/**
 * Activities — curated family activities, seasonal, stay-home, handler.
 */

export const VERSION = '2.1.0';

import { getCity } from './data.js';
import { fetchWeather, RAINY_CODES } from './weather.js';
import { getCityEvents } from './events.js';

/* ── Default activities per city ── */

const ZURICH = [
  { id: 'zoo-zurich', name: 'Zoo Zürich', nameDE: 'Zoo Zürich', description: 'See elephants, penguins, and the amazing Masoala Rainforest hall. Perfect for little animal lovers!', descriptionDE: 'Elefanten, Pinguine und die beeindruckende Masoala-Regenwaldhalle. Perfekt für kleine Tierliebhaber!', indoor: false, ageRange: '2-5 years', duration: '2-4 hours', price: 'CHF 29 adults, kids under 6 free', url: 'https://www.zoo.ch', category: 'animals', lat: 47.3849, lon: 8.5743 },
  { id: 'landesmuseum', name: 'Swiss National Museum', nameDE: 'Landesmuseum Zürich', description: 'Family-friendly exhibitions with interactive elements. The castle-like building is exciting for kids!', descriptionDE: 'Familienfreundliche Ausstellungen mit interaktiven Elementen. Das schlossartige Gebäude begeistert Kinder!', indoor: true, ageRange: '3-5 years', duration: '1-2 hours', price: 'CHF 10 adults, kids under 16 free', url: 'https://www.landesmuseum.ch', category: 'museum', lat: 47.3792, lon: 8.5396 },
  { id: 'kindercity', name: 'Kindercity Volketswil', nameDE: 'Kindercity Volketswil', description: 'Indoor play paradise with science experiments, role-play areas, and soft play zones. Perfect for rainy days!', descriptionDE: 'Indoor-Spielparadies mit Wissenschaftsexperimenten, Rollenspielbereichen und Softplay-Zonen. Perfekt für Regentage!', indoor: true, ageRange: '2-5 years', duration: '2-4 hours', price: 'CHF 18-24', url: 'https://www.kindercity.ch', category: 'indoor-play', lat: 47.3867, lon: 8.6839 },
  { id: 'playground-irchelpark', name: 'Irchelpark Playground', nameDE: 'Spielplatz Irchelpark', description: 'Large natural playground with climbing structures, sand pit, and water play in summer.', descriptionDE: 'Grosser Naturspielplatz mit Klettergerüsten, Sandkasten und Wasserspiel im Sommer.', indoor: false, ageRange: '2-5 years', duration: '1-3 hours', price: 'Free', category: 'playground', lat: 47.3970, lon: 8.5480 },
  { id: 'trammuseum', name: 'Tram Museum Zürich', nameDE: 'Tram-Museum Zürich', description: 'Historic trams kids can climb into! Special family days with rides on vintage trams.', descriptionDE: 'Historische Trams, in die Kinder klettern können! Spezielle Familientage mit Fahrten in alten Trams.', indoor: true, ageRange: '2-5 years', duration: '1-2 hours', price: 'CHF 8 adults, CHF 4 kids', url: 'https://www.tram-museum.ch', category: 'museum', lat: 47.3556, lon: 8.5268 },
  { id: 'chinagarten', name: 'Chinese Garden', nameDE: 'Chinagarten', description: 'Beautiful garden by the lake with koi fish, bridges, and pagodas.', descriptionDE: 'Wunderschöner Garten am See mit Koi-Fischen, Brücken und Pagoden.', indoor: false, ageRange: '2-5 years', duration: '1 hour', price: 'CHF 4', category: 'nature', lat: 47.3545, lon: 8.5520 },
  { id: 'playground-josefwiese', name: 'Josefwiese Playground', nameDE: 'Spielplatz Josefwiese', description: 'Popular urban playground in Kreis 5 with water features, swings, and climbing frames.', descriptionDE: 'Beliebter Stadtspielplatz im Kreis 5 mit Wasserspielen, Schaukeln und Klettergerüsten.', indoor: false, ageRange: '2-5 years', duration: '1-2 hours', price: 'Free', category: 'playground', lat: 47.3876, lon: 8.5280 },
  { id: 'wildnispark', name: 'Wildnispark Zürich Langenberg', nameDE: 'Wildnispark Zürich Langenberg', description: 'See native Swiss animals like deer, wild boar, and lynx in natural enclosures.', descriptionDE: 'Einheimische Schweizer Tiere wie Hirsche, Wildschweine und Luchse in natürlichen Gehegen.', indoor: false, ageRange: '2-5 years', duration: '2-4 hours', price: 'Free', url: 'https://www.wildnispark.ch', category: 'animals', lat: 47.2856, lon: 8.5194 },
  { id: 'zuerich-spielzeugmuseum', name: 'Toy Museum', nameDE: 'Spielzeugmuseum', description: 'Collection of historic toys with hands-on play areas for children.', descriptionDE: 'Sammlung historischer Spielzeuge mit praktischen Spielbereichen für Kinder.', indoor: true, ageRange: '2-5 years', duration: '1-2 hours', price: 'CHF 7', url: 'https://www.spielzeugmuseum.ch', category: 'museum', lat: 47.3695, lon: 8.5436 },
  { id: 'lake-boats', name: 'Lake Zürich Boat Trip', nameDE: 'Schifffahrt auf dem Zürichsee', description: 'Short boat rides on the lake. Kids love watching the water!', descriptionDE: 'Kurze Bootsfahrten auf dem See. Kinder lieben es!', indoor: false, ageRange: '2-5 years', duration: '1-2 hours', price: 'From CHF 8', url: 'https://www.zsg.ch', category: 'outdoor', lat: 47.3667, lon: 8.5410 },
  { id: 'botanischer-garten', name: 'Botanical Garden', nameDE: 'Botanischer Garten', description: 'Free garden with tropical greenhouses, pond with turtles, and space to run.', descriptionDE: 'Kostenloser Garten mit tropischen Gewächshäusern, Teich mit Schildkröten.', indoor: false, ageRange: '2-5 years', duration: '1-2 hours', price: 'Free', url: 'https://www.bg.uzh.ch', category: 'nature', lat: 47.3584, lon: 8.5601 },
  { id: 'indoorspielplatz-kiddy-dome', name: 'Kiddy Dome Indoor Playground', nameDE: 'Kiddy Dome Indoorspielplatz', description: 'Soft play area, ball pit, trampolines, and toddler zone.', descriptionDE: 'Softplay-Bereich, Bällebad, Trampoline und Kleinkindzone.', indoor: true, ageRange: '2-5 years', duration: '2-3 hours', price: 'CHF 12-15', category: 'indoor-play', lat: 47.4115, lon: 8.5448 },
  // Recurring
  { id: 'buerkliplatz-market', name: 'Bürkliplatz Farmers Market', nameDE: 'Bauernmarkt Bürkliplatz', description: 'Tuesday & Friday mornings: Fresh produce, flowers, and snacks.', descriptionDE: 'Dienstag & Freitag morgens: Frische Produkte, Blumen und Snacks.', indoor: false, ageRange: '2-5 years', duration: '1 hour', price: 'Free', category: 'event', recurring: 'Tue & Fri 6:00-11:00', lat: 47.3667, lon: 8.5410 },
  { id: 'spielnachmittag-gz', name: 'GZ Play Afternoons', nameDE: 'GZ Spielnachmittage', description: 'Free drop-in play sessions at community centers.', descriptionDE: 'Kostenlose Spielnachmittage in den Gemeinschaftszentren.', indoor: true, ageRange: '2-5 years', duration: '2-3 hours', price: 'Free', url: 'https://gz-zh.ch', category: 'event', recurring: 'Various days', lat: 47.3769, lon: 8.5417 },
  { id: 'story-time-pestalozzi', name: 'Story Time at Pestalozzi Library', nameDE: 'Geschichtenzeit Pestalozzi-Bibliothek', description: 'Free story readings for toddlers. Wednesday afternoons.', descriptionDE: 'Kostenlose Geschichten für Kleinkinder. Mittwochnachmittags.', indoor: true, ageRange: '2-5 years', duration: '45 min', price: 'Free', url: 'https://www.pbz.ch', category: 'event', recurring: 'Wed afternoon', lat: 47.3775, lon: 8.5358 },
  { id: 'kindermuseum-workshops', name: "Children's Museum Workshops", nameDE: 'Kindermuseum Workshops', description: 'Weekend craft workshops at Museum Rietberg.', descriptionDE: 'Wochenend-Bastelworkshops im Museum Rietberg.', indoor: true, ageRange: '3-5 years', duration: '1-2 hours', price: 'CHF 5-10', url: 'https://rietberg.ch', category: 'event', recurring: 'Weekends', lat: 47.3594, lon: 8.5312 },
];

const BASEL = [
  { id: 'basel-zoo', name: 'Zoo Basel', nameDE: 'Zoo Basel', description: "One of Switzerland's oldest zoos with great children's area and petting zoo.", descriptionDE: 'Einer der ältesten Zoos der Schweiz mit tollem Kinderbereich und Streichelzoo.', indoor: false, ageRange: '2-5 years', duration: '2-4 hours', price: 'CHF 21 adults, kids under 6 free', url: 'https://www.zoobasel.ch', category: 'animals', lat: 47.5475, lon: 7.5789 },
  { id: 'basel-spielzeugmuseum', name: 'Toy Worlds Museum Basel', nameDE: 'Spielzeug Welten Museum Basel', description: 'Amazing collection of teddy bears, dolls, and miniatures.', descriptionDE: 'Tolle Sammlung von Teddybären, Puppen und Miniaturen.', indoor: true, ageRange: '2-5 years', duration: '1-2 hours', price: 'CHF 7 adults, kids under 16 free', url: 'https://www.spielzeug-welten-museum-basel.ch', category: 'museum', lat: 47.5563, lon: 7.5898 },
  { id: 'basel-rhein-ferry', name: 'Rhine Ferry Ride', nameDE: 'Rheinfähre', description: 'Short ferry rides across the Rhine - powered only by the current!', descriptionDE: 'Kurze Fährfahrten über den Rhein - nur von der Strömung angetrieben!', indoor: false, ageRange: '2-5 years', duration: '15 min', price: 'CHF 2', category: 'outdoor', lat: 47.5607, lon: 7.5909 },
  { id: 'basel-tinguely', name: 'Tinguely Museum Garden', nameDE: 'Tinguely Museum Garten', description: 'Moving sculptures that fascinate children. The park outside is free.', descriptionDE: 'Bewegliche Skulpturen die Kinder faszinieren. Der Park draussen ist gratis.', indoor: false, ageRange: '3-5 years', duration: '1-2 hours', price: 'Park free, museum CHF 18', url: 'https://www.tinguely.ch', category: 'museum', lat: 47.5591, lon: 7.6135 },
  { id: 'basel-lange-erlen', name: 'Lange Erlen Animal Park', nameDE: 'Tierpark Lange Erlen', description: 'Free animal park with deer, wild boar, and birds. Great playground!', descriptionDE: 'Gratis Tierpark mit Hirschen, Wildschweinen und Vögeln. Toller Spielplatz!', indoor: false, ageRange: '2-5 years', duration: '2-3 hours', price: 'Free', category: 'animals', lat: 47.5776, lon: 7.6255 },
];

const BERN = [
  { id: 'bern-barenpark', name: 'BärenPark Bern', nameDE: 'BärenPark Bern', description: "See Bern's famous bears in their modern park by the river. Free!", descriptionDE: 'Berns berühmte Bären in ihrem modernen Park am Fluss. Gratis!', indoor: false, ageRange: '2-5 years', duration: '1 hour', price: 'Free', url: 'https://www.baerenpark-bern.ch', category: 'animals', lat: 46.9480, lon: 7.4600 },
  { id: 'bern-tierpark-dahlholzli', name: 'Tierpark Dählhölzli', nameDE: 'Tierpark Dählhölzli', description: 'Great zoo with Nordic animals, playground, and restaurant.', descriptionDE: 'Toller Zoo mit nordischen Tieren, Spielplatz und Restaurant.', indoor: false, ageRange: '2-5 years', duration: '2-3 hours', price: 'CHF 10 adults, CHF 4 kids', url: 'https://www.tierpark-bern.ch', category: 'animals', lat: 46.9367, lon: 7.4507 },
  { id: 'bern-kindermuseum-creaviva', name: "Creaviva Children's Museum", nameDE: 'Kindermuseum Creaviva', description: 'Interactive art workshops for kids at the Paul Klee Centre.', descriptionDE: 'Interaktive Kunstworkshops für Kinder im Zentrum Paul Klee.', indoor: true, ageRange: '3-5 years', duration: '1-2 hours', price: 'CHF 12', url: 'https://www.creaviva.org', category: 'museum', lat: 46.9490, lon: 7.4744 },
  { id: 'bern-gurten', name: 'Gurten Funicular & Playground', nameDE: 'Gurtenbahn & Spielplatz', description: "Take the funicular up Bern's local mountain. Huge playground!", descriptionDE: 'Mit der Standseilbahn auf Berns Hausberg. Riesiger Spielplatz!', indoor: false, ageRange: '2-5 years', duration: '2-4 hours', price: 'CHF 12 return', url: 'https://www.gurtenpark.ch', category: 'outdoor', lat: 46.9215, lon: 7.4347 },
  { id: 'bern-naturhistorisches', name: 'Natural History Museum', nameDE: 'Naturhistorisches Museum', description: 'Dinosaurs, animals, and Barry the famous rescue dog!', descriptionDE: 'Dinosaurier, Tiere und Barry der berühmte Rettungshund!', indoor: true, ageRange: '3-5 years', duration: '1-2 hours', price: 'CHF 10 adults, kids under 16 free', url: 'https://www.nmbe.ch', category: 'museum', lat: 46.9514, lon: 7.4410 },
];

const GENEVA = [
  { id: 'geneva-jardin-botanique', name: 'Botanical Garden', nameDE: 'Botanischer Garten', description: 'Beautiful free gardens with a small zoo, playground, and turtles.', descriptionDE: 'Wunderschöne kostenlose Gärten mit kleinem Zoo, Spielplatz und Schildkröten.', indoor: false, ageRange: '2-5 years', duration: '1-2 hours', price: 'Free', url: 'https://www.ville-ge.ch/cjb', category: 'nature', lat: 46.2268, lon: 6.1479 },
  { id: 'geneva-jet-deau', name: "Jet d'Eau & Lake Shore", nameDE: "Jet d'Eau & Seeufer", description: 'Watch the famous fountain and play along the lakeside.', descriptionDE: 'Den berühmten Springbrunnen beobachten und am See spielen.', indoor: false, ageRange: '2-5 years', duration: '1-2 hours', price: 'Free', category: 'outdoor', lat: 46.2073, lon: 6.1554 },
  { id: 'geneva-museum-histoire-naturelle', name: 'Natural History Museum', nameDE: 'Naturhistorisches Museum', description: 'Huge collection of animals and dinosaurs. Free and kid-friendly!', descriptionDE: 'Riesige Sammlung von Tieren und Dinosauriern. Gratis und kinderfreundlich!', indoor: true, ageRange: '2-5 years', duration: '1-2 hours', price: 'Free', url: 'https://www.museum-geneve.ch', category: 'museum', lat: 46.1973, lon: 6.1578 },
  { id: 'geneva-baby-plage', name: 'Baby Plage', nameDE: 'Baby Plage', description: 'Shallow water beach area perfect for toddlers.', descriptionDE: 'Flacher Strandbereich perfekt für Kleinkinder.', indoor: false, ageRange: '2-5 years', duration: '2-3 hours', price: 'Free', category: 'outdoor', lat: 46.2055, lon: 6.1611 },
  { id: 'geneva-parc-bastions', name: 'Parc des Bastions', nameDE: 'Parc des Bastions', description: 'Central park with huge chess boards, playground, and space to run.', descriptionDE: 'Zentraler Park mit riesigen Schachbrettern, Spielplatz und Platz zum Herumrennen.', indoor: false, ageRange: '2-5 years', duration: '1-2 hours', price: 'Free', category: 'playground', lat: 46.2000, lon: 6.1461 },
];

const LAUSANNE = [
  { id: 'lausanne-olympic-museum', name: 'Olympic Museum', nameDE: 'Olympisches Museum', description: 'Interactive sports exhibits kids love. Beautiful park with lake views.', descriptionDE: 'Interaktive Sportausstellungen die Kinder lieben. Schöner Park mit Seeblick.', indoor: true, ageRange: '3-5 years', duration: '2-3 hours', price: 'CHF 20 adults, kids under 16 free', url: 'https://www.olympic.org/museum', category: 'museum', lat: 46.5082, lon: 6.6340 },
  { id: 'lausanne-sauvabelin', name: 'Sauvabelin Park & Tower', nameDE: 'Sauvabelin Park & Turm', description: 'Forest park with animals, playground, and wooden tower.', descriptionDE: 'Waldpark mit Tieren, Spielplatz und Holzturm.', indoor: false, ageRange: '2-5 years', duration: '2-3 hours', price: 'Free', category: 'nature', lat: 46.5366, lon: 6.6421 },
  { id: 'lausanne-aquatis', name: 'Aquatis Aquarium', nameDE: 'Aquatis Aquarium', description: "Europe's largest freshwater aquarium. Kids love the fish and crocodiles!", descriptionDE: 'Europas grösstes Süsswasseraquarium. Kinder lieben Fische und Krokodile!', indoor: true, ageRange: '2-5 years', duration: '2-3 hours', price: 'CHF 29 adults, CHF 19 kids', url: 'https://www.aquatis.ch', category: 'animals', lat: 46.5359, lon: 6.6178 },
  { id: 'lausanne-ouchy', name: 'Ouchy Waterfront', nameDE: 'Ouchy Seepromenade', description: 'Lakeside promenade with playground, carousel, and boat rides.', descriptionDE: 'Seepromenade mit Spielplatz, Karussell und Bootsfahrten.', indoor: false, ageRange: '2-5 years', duration: '2-3 hours', price: 'Free', category: 'outdoor', lat: 46.5070, lon: 6.6290 },
  { id: 'lausanne-espace-enfants', name: 'Espace des Inventions', nameDE: 'Espace des Inventions', description: 'Science museum for kids with hands-on experiments.', descriptionDE: 'Wissenschaftsmuseum für Kinder mit Experimenten zum Anfassen.', indoor: true, ageRange: '3-5 years', duration: '1-2 hours', price: 'CHF 10', url: 'https://www.espace-des-inventions.ch', category: 'museum', lat: 46.5192, lon: 6.5727 },
];

const LUZERN = [
  { id: 'luzern-verkehrshaus', name: 'Swiss Museum of Transport', nameDE: 'Verkehrshaus der Schweiz', description: "Switzerland's most popular museum! Trains, planes, cars, and space exhibits.", descriptionDE: 'Beliebtestes Museum der Schweiz! Züge, Flugzeuge, Autos und Weltraumausstellungen.', indoor: true, ageRange: '2-5 years', duration: '3-4 hours', price: 'CHF 36 adults, kids under 6 free', url: 'https://www.verkehrshaus.ch', category: 'museum', minAge: 2, maxAge: 5, lat: 47.0528, lon: 8.3356 },
  { id: 'luzern-gletschergarten', name: 'Glacier Garden & Mirror Maze', nameDE: 'Gletschergarten & Spiegellabyrinth', description: 'Explore prehistoric glacier potholes and get lost in the mirror maze!', descriptionDE: 'Prähistorische Gletschertöpfe erkunden und sich im Spiegellabyrinth verlieren!', indoor: true, ageRange: '3-5 years', duration: '1-2 hours', price: 'CHF 22 adults, CHF 8 kids', url: 'https://www.gletschergarten.ch', category: 'museum', minAge: 3, maxAge: 5, lat: 47.0585, lon: 8.3107 },
  { id: 'luzern-ufschoetti', name: 'Ufschötti Park & Beach', nameDE: 'Ufschötti Park & Strand', description: 'Popular lakeside park with playground and swimming access.', descriptionDE: 'Beliebter Park am See mit Spielplatz und Bademöglichkeit.', indoor: false, ageRange: '2-5 years', duration: '2-3 hours', price: 'Free', category: 'playground', minAge: 2, maxAge: 5, lat: 47.0485, lon: 8.3173 },
  { id: 'luzern-city-train', name: 'City Train Luzern', nameDE: 'City-Train Luzern', description: 'Fun little train ride through the old town and along the lake.', descriptionDE: 'Lustige kleine Zugfahrt durch die Altstadt und am See entlang.', indoor: false, ageRange: '2-5 years', duration: '45 min', price: 'CHF 10 adults, CHF 5 kids', category: 'outdoor', minAge: 2, maxAge: 5, lat: 47.0505, lon: 8.3064 },
  { id: 'luzern-natur-museum', name: 'Nature Museum Lucerne', nameDE: 'Natur-Museum Luzern', description: 'Local animals, dinosaurs, and hands-on exhibits for kids.', descriptionDE: 'Einheimische Tiere, Dinosaurier und interaktive Ausstellungen.', indoor: true, ageRange: '2-5 years', duration: '1-2 hours', price: 'CHF 10 adults, kids under 16 free', url: 'https://www.naturmuseum.ch', category: 'museum', minAge: 2, maxAge: 5, lat: 47.0503, lon: 8.3054 },
  { id: 'luzern-playground-wettsteinpark', name: 'Wettsteinpark Playground', nameDE: 'Spielplatz Wettsteinpark', description: 'Central city playground with swings, slides, and sandbox.', descriptionDE: 'Zentraler Stadtspielplatz mit Schaukeln, Rutschen und Sandkasten.', indoor: false, ageRange: '2-5 years', duration: '1-2 hours', price: 'Free', category: 'playground', minAge: 2, maxAge: 5, lat: 47.0491, lon: 8.3098 },
  { id: 'luzern-pilatus', name: 'Pilatus Krienseregg Playground', nameDE: 'Pilatus Krienseregg Spielplatz', description: 'Mountain adventure playground at the first cable car stop.', descriptionDE: 'Berg-Abenteuerspielplatz bei der ersten Seilbahnstation.', indoor: false, ageRange: '3-5 years', duration: '2-3 hours', price: 'Cable car CHF 36 return', url: 'https://www.pilatus.ch', category: 'outdoor', minAge: 3, maxAge: 5, lat: 46.9852, lon: 8.2647 },
  { id: 'luzern-lido', name: 'Lido Luzern', nameDE: 'Lido Luzern', description: 'Lakeside park with sandy beach, playground, and swimming.', descriptionDE: 'Park am See mit Sandstrand, Spielplatz und Bademöglichkeit.', indoor: false, ageRange: '2-5 years', duration: '2-4 hours', price: 'CHF 7 adults, kids under 6 free', category: 'outdoor', minAge: 2, maxAge: 5, lat: 47.0539, lon: 8.3389 },
];

const WINTERTHUR = [
  { id: 'winterthur-technorama', name: 'Swiss Science Center Technorama', nameDE: 'Technorama Wissenschaftszentrum', description: "Europe's biggest science center! 500+ interactive exhibits!", descriptionDE: 'Europas grösstes Wissenschaftszentrum! 500+ interaktive Exponate!', indoor: true, ageRange: '3-5 years', duration: '3-5 hours', price: 'CHF 29 adults, CHF 18 kids', url: 'https://www.technorama.ch', category: 'museum', minAge: 3, maxAge: 5, lat: 47.5069, lon: 8.7167 },
  { id: 'winterthur-wildpark-bruderhaus', name: 'Wildpark Bruderhaus', nameDE: 'Wildpark Bruderhaus', description: 'Free forest animal park with deer, wild boar, and wolves!', descriptionDE: 'Gratis Waldtierpark mit Hirschen, Wildschweinen und Wölfen!', indoor: false, ageRange: '2-5 years', duration: '2-3 hours', price: 'Free', url: 'https://www.wildpark.ch', category: 'animals', minAge: 2, maxAge: 5, lat: 47.4756, lon: 8.7891 },
  { id: 'winterthur-stadtgarten', name: 'Stadtgarten Playground', nameDE: 'Spielplatz Stadtgarten', description: "The city's most popular playground in a beautiful park.", descriptionDE: 'Der beliebteste Spielplatz der Stadt in einem schönen Park.', indoor: false, ageRange: '2-5 years', duration: '1-2 hours', price: 'Free', category: 'playground', minAge: 2, maxAge: 5, lat: 47.4989, lon: 8.7264 },
  { id: 'winterthur-piratolino', name: 'Piratolino Indoor Playground', nameDE: 'Piratolino Indoorspielplatz', description: 'Indoor play paradise with slides, ball pit, trampolines!', descriptionDE: 'Indoor-Spielparadies mit Rutschen, Bällebad, Trampolinen!', indoor: true, ageRange: '2-5 years', duration: '2-3 hours', price: 'CHF 15-18', url: 'https://www.piratolino.ch', category: 'indoor-play', minAge: 2, maxAge: 5, lat: 47.4847, lon: 8.7339 },
  { id: 'winterthur-naturmuseum', name: 'Natural History Museum', nameDE: 'Naturmuseum Winterthur', description: 'Local wildlife exhibits with hands-on discovery room for children.', descriptionDE: 'Einheimische Tierwelt-Ausstellungen mit Entdeckerraum für Kinder.', indoor: true, ageRange: '2-5 years', duration: '1-2 hours', price: 'CHF 8 adults, kids under 16 free', url: 'https://www.naturmuseum.ch', category: 'museum', minAge: 2, maxAge: 5, lat: 47.4986, lon: 8.7279 },
  { id: 'winterthur-skills-park', name: 'Skills Park', nameDE: 'Skills Park', description: 'Trampolines, climbing, and freestyle sports. Mini area for younger kids!', descriptionDE: 'Trampoline, Klettern und Freestyle-Sport. Mini-Bereich für kleinere Kinder!', indoor: true, ageRange: '4-5 years', duration: '2-3 hours', price: 'CHF 25', url: 'https://www.skillspark.ch', category: 'indoor-play', minAge: 4, maxAge: 5, lat: 47.5003, lon: 8.6956 },
  { id: 'winterthur-fotomuseum', name: 'Fotomuseum Winterthur', nameDE: 'Fotomuseum Winterthur', description: 'Photography museum with family workshops.', descriptionDE: 'Fotomuseum mit Familienworkshops.', indoor: true, ageRange: '4-5 years', duration: '1-2 hours', price: 'CHF 12 adults, kids under 16 free', url: 'https://www.fotomuseum.ch', category: 'museum', minAge: 4, maxAge: 5, lat: 47.4969, lon: 8.7234 },
  { id: 'winterthur-rosengarten', name: 'Rosengarten Park', nameDE: 'Rosengarten', description: 'Beautiful rose garden with playground and small animal enclosure.', descriptionDE: 'Schöner Rosengarten mit Spielplatz und kleinem Tiergehege.', indoor: false, ageRange: '2-5 years', duration: '1-2 hours', price: 'Free', category: 'nature', minAge: 2, maxAge: 5, lat: 47.4942, lon: 8.7337 },
];

const CITY_ACTIVITIES = { zurich: ZURICH, basel: BASEL, bern: BERN, geneva: GENEVA, lausanne: LAUSANNE, luzern: LUZERN, winterthur: WINTERTHUR };

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

export async function handleActivities(url, env) {
  const cityId = url.searchParams.get('city') || 'zurich';
  const city = getCity(cityId);

  const [weather, activities] = await Promise.all([
    fetchWeather(city.lat, city.lon),
    getCuratedActivities(env, cityId)
  ]);

  let sorted = activities;
  if (weather) {
    const bad = RAINY_CODES.includes(weather.weatherCode) || weather.temperature < 5;
    if (bad) sorted = [...activities].sort((a, b) => (a.indoor ? -1 : 1) - (b.indoor ? -1 : 1));
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
