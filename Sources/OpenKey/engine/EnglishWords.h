//
//  EnglishWords.h
//  OpenKey
//
//  Word lists for "restore keys of a wrong word" (vRestoreIfWrongSpelling) and its English context
//  option (vEnglishContext). Included by Engine.cpp only.
//
//  Every array is lowercase a-z and sorted, because the engine looks words up with a binary search.
//  tests/engine_test.cpp fails when an entry breaks that.
//
//  The two English lists were built by typing common English words into this engine and sorting them
//  by what came out. The source words come from the VieLotus-IM project (MIT License, Copyright (c)
//  2026 Tran Phat Dat): its English regression corpus and its lexicon files 04, 05 and 11.
//

#ifndef EnglishWords_h
#define EnglishWords_h

/**
 * English words Telex turns into something that is not Vietnamese: letters go missing ("pass" -> "pas",
 * "issue" -> "isue") or the result is not a syllable anyone writes ("data" -> "dât", "more" -> "mỏe").
 * Restoring them costs a Vietnamese typist nothing.
 * Not here on purpose: doubled letters whose single form is the more common word. "off" stays the way
 * to type "of".
 */
static const char* const kEnglishAlways[] = {
    "affair", "affairs", "affect", "affected", "affectedly", "affecteds", "affecter", "affecting", "affectingly",
    "affectings", "affects", "affiliate", "affiliated", "affiliates", "affiliation", "affiliations", "affirm",
    "affirmer", "affirms", "afford", "affordable", "affordables", "affords", "arizona", "arrange", "arranged",
    "arrangement", "arrangements", "arranges", "array", "arrayer", "arrays", "arrest", "arrested", "arrester",
    "arresting", "arrests", "arrival", "arrivals", "arrive", "arrived", "arrives", "arrow", "arrowed", "arrows",
    "assault", "assaulter", "assaults", "assemble", "assembled", "assembles", "assembly", "assemblys", "assert",
    "asserter", "assertion", "assertions", "asserts", "asses", "assess", "assessed", "assesseds", "assesses",
    "assessing", "assessment", "assessments", "asset", "assets", "assetses", "assign", "assigned", "assigneds",
    "assigner", "assignment", "assignments", "assigns", "assist", "assistance", "assistances", "assistant",
    "assistanted", "assistants", "assisted", "assister", "assists", "associate", "associated", "associateds",
    "associates", "association", "associations", "assume", "assumed", "assumedly", "assumeds", "assumes",
    "assuming", "assumingly", "assumings", "assumption", "assumptions", "assurance", "assurances", "assure",
    "assured", "assuredly", "assureds", "assures", "assuring", "aus", "aux", "awareness", "away", "barrel",
    "barreled", "barreler", "barrels", "barren", "barrenly", "barrens", "barrier", "barriers", "barry", "barrys",
    "bass", "berries", "berry", "berrys", "bias", "boar", "boars", "boast", "boats", "booms", "boot", "bore",
    "bores", "borrow", "borrowed", "borrower", "borrowing", "borrows", "boss", "bossed", "bosser", "bosses",
    "bossing", "boxes", "buffalo", "buffalos", "buffed", "buffer", "buffered", "buffers", "buffs", "burr", "busy",
    "buys", "carried", "carrieds", "carrier", "carriers", "carries", "carroll", "carry", "carrying", "carryings",
    "carrys", "casa", "cassette", "caw", "charms", "chassis", "chassises", "cheer", "cherry", "cherrypick",
    "cherrys", "chess", "chesser", "chesses", "chics", "chore", "chosen", "cir", "cirrus", "coast", "coco",
    "coffee", "coffees", "coffer", "cofferer", "coffering", "coffers", "coop", "cora", "coras", "core", "cores",
    "correct", "corrected", "correcteds", "correcting", "correction", "correctioner", "corrections", "correctly",
    "correctlys", "corrects", "correlation", "correlations", "correspond", "correspondence", "correspondences",
    "corresponder", "corresponding", "correspondingly", "correspondings", "corresponds", "corrupt", "corrupted",
    "corrupter", "corrupting", "corruption", "corruptions", "corruptly", "corrupts", "cox", "cuff", "cuffer",
    "cuffs", "curr", "currencies", "currency", "currencys", "current", "currently", "currentlys", "currents",
    "curriculum", "curriculums", "curry", "currys", "cursor", "daddy", "darn", "darr", "data", "daw", "dawns",
    "deem", "deems", "deep", "deeps", "deferred", "deferreds", "dens", "dense", "desserts", "diff", "differ",
    "difference", "differences", "different", "differentia", "differential", "differentially", "differentials",
    "differentias", "differently", "differentlys", "differents", "differs", "difficult", "difficulties",
    "difficultly", "difficults", "difficulty", "difficultys", "diffs", "disc", "does", "donor", "donors", "doom",
    "dooms", "door", "doors", "dose", "earrings", "effect", "effecter", "effective", "effectively", "effectivelys",
    "effectiveness", "effectivenesses", "effectives", "effects", "effectses", "efficiency", "efficiencys",
    "efficient", "efficiently", "efficientlys", "efficients", "effort", "efforts", "ericsson", "error", "errors",
    "essay", "essayer", "essays", "essence", "essences", "essential", "essentially", "essentiallys", "essentials",
    "essex", "gangs", "gee", "gene", "genes", "genre", "genres", "germ", "germs", "gets", "ghost", "goes", "gore",
    "gores", "gossip", "gossiper", "gossiping", "gossips", "guar", "guars", "guess", "guns", "guys", "harassment",
    "harassments", "harris", "harrison", "harry", "harrys", "haw", "heres", "hisser", "hisses", "hissing", "hoes",
    "honors", "horns", "horrible", "horribles", "horror", "horrors", "horse", "hose", "howto", "hurrah", "hurrahs",
    "hurricane", "hurricanes", "hurry", "hurrys", "ieee", "ips", "irrigation", "irrigations", "isa", "isp", "issn",
    "issue", "issued", "issues", "issuing", "karma", "karmas", "keens", "keep", "kern", "kerry", "kerrys", "kiss",
    "kissed", "kisser", "kisses", "kissing", "kissingly", "kissings", "kore", "kores", "larry", "larrys", "lauras",
    "law", "lawns", "laws", "leers", "lees", "less", "lesser", "lessers", "lesses", "lesson", "lessons", "loop",
    "loss", "losses", "major", "maps", "marriage", "marriages", "married", "marrieds", "marriott", "marryer",
    "marrying", "marrys", "mass", "massachusetts", "massage", "massages", "masser", "masses", "massive",
    "massively", "massives", "meet", "merry", "merrys", "mess", "message", "messages", "messaging", "messenger",
    "messengers", "messer", "messes", "messing", "mete", "mins", "mirror", "mirrored", "mirrors", "misc", "miss",
    "missed", "misses", "missile", "missiles", "missing", "missingly", "missings", "mission", "missioner",
    "missions", "mississippi", "missouri", "momos", "monos", "moons", "mora", "moras", "more", "mores", "morn",
    "morris", "morrises", "morrison", "moss", "mossed", "mosser", "murray", "narrative", "narratively",
    "narratives", "narrow", "narrower", "narrowly", "narrows", "nasa", "necessarily", "necessarilys", "necessary",
    "necessarys", "necessity", "necessitys", "nginx", "nissan", "noons", "norms", "nose", "offense", "offenses",
    "offensive", "offensively", "offensives", "offer", "offered", "offerer", "offering", "offerings", "offers",
    "office", "officer", "officers", "offices", "official", "officially", "officiallys", "officials", "offline",
    "offset", "offsetof", "offsets", "offshore", "offshores", "ons", "orang", "orangs", "pair", "pairs", "para",
    "paras", "pari", "paris", "pas", "paso", "pass", "passage", "passages", "passed", "passenger", "passengers",
    "passer", "passes", "passing", "passingly", "passings", "passion", "passioned", "passions", "passive",
    "passively", "passives", "passport", "passports", "passwd", "password", "passwords", "pasta", "pax", "pays",
    "peer", "peers", "pens", "perm", "perms", "pero", "perry", "perrys", "pers", "pete", "petes", "phons", "photo",
    "phys", "piece", "pieces", "pierces", "pierre", "pins", "piss", "pisses", "pissing", "pix", "poems", "poets",
    "poor", "poors", "por", "porn", "porno", "pos", "pose", "posses", "possess", "possessed", "possesses",
    "possessing", "possession", "possessioned", "possessioner", "possessions", "possibilities", "possibility",
    "possibilitys", "possible", "possibles", "possibly", "possiblys", "post", "puff", "puffed", "puffer", "puffing",
    "puffs", "purr", "pus", "puss", "pusses", "pussy", "pussys", "puts", "raw", "referral", "referrals", "referred",
    "referring", "refuse", "riff", "riffle", "riffles", "riffs", "roast", "roofs", "rooms", "root", "rose", "ross",
    "rosser", "ruff", "ruffed", "ruffer", "ruffly", "ruffs", "russel", "russell", "russels", "russia", "russian",
    "russias", "sara", "sasses", "saw", "saws", "says", "seem", "seems", "seers", "sees", "sess", "sesses",
    "session", "sessions", "sessionses", "sexo", "sierra", "sims", "sofas", "soon", "soons", "sorrow", "sorrower",
    "sorrowing", "sorrows", "sorry", "sorrys", "sox", "suffer", "suffered", "sufferer", "suffering", "sufferingly",
    "sufferings", "suffers", "sufficient", "sufficiently", "sufficientlys", "sufficients", "suffix", "surrey",
    "surreys", "surround", "surrounded", "surroundedly", "surroundeds", "surrounder", "surrounding", "surroundings",
    "surrounds", "susan", "sussex", "sweep", "sweet", "swiss", "swisses", "swissing", "sworn", "sys", "tariff",
    "tariffs", "teens", "terrace", "terraces", "terracing", "terraform", "terrain", "terrains", "terrible",
    "terribles", "territories", "territory", "territorys", "terror", "terrorism", "terrorisms", "terrorist",
    "terrorists", "terrors", "terry", "terrys", "themer", "themes", "thems", "thens", "therm", "therms", "thongs",
    "thons", "thorn", "those", "tiffany", "tiffanys", "tirr", "tissue", "tissues", "toffing", "tomorrow",
    "tomorrower", "tomorrowing", "tomorrows", "tons", "toot", "torn", "traffic", "traffics", "trees", "trips",
    "troop", "troops", "turns", "tweet", "verizon", "vessel", "vesseled", "vessels", "war", "warrant", "warranties",
    "warranty", "warren", "warrior", "warriors", "wax", "wc", "wi", "wm", "wn", "worm", "worn", "worried", "worry",
    "wow", "wp", "wrong", "wt", "www", "wx", "xanax"
};
static const int kEnglishAlwaysCount = 786;

/**
 * English words that are also a real Vietnamese syllable typed the normal way ("this" / "thí",
 * "list" / "lít", "tax" / "tã"). Restored only right after English words, and only when the user
 * turned vEnglishContext on.
 */
static const char* const kEnglishInContext[] = {
    "air", "arm", "arms", "as", "asp", "axis", "bar", "bars", "been", "beer", "best", "bits", "boost", "boots",
    "born", "box", "burn", "bus", "caps", "car", "cars", "cast", "cats", "chair", "chairs", "char", "charm",
    "chest", "chips", "corn", "cost", "cuts", "dawn", "days", "def", "der", "des", "dir", "dos", "down", "dust",
    "est", "gary", "gas", "hair", "has", "hats", "her", "here", "hero", "his", "hist", "hits", "honor", "host",
    "how", "if", "ins", "is", "its", "keeps", "kits", "last", "laura", "lawn", "lee", "lens", "les", "lets", "lisa",
    "list", "loans", "los", "lose", "lost", "lots", "low", "mar", "mars", "mary", "max", "meets", "mens", "mix",
    "moon", "most", "must", "nor", "now", "of", "or", "own", "par", "past", "pee", "per", "pets", "photos", "pics",
    "queen", "quest", "ref", "refer", "refers", "res", "rest", "roof", "room", "roots", "row", "runs", "see",
    "seen", "sense", "sets", "sir", "six", "songs", "sons", "sur", "surf", "tax", "tee", "teen", "term", "terms",
    "test", "there", "these", "this", "thus", "tips", "tits", "too", "tops", "town", "towns", "trans", "tree",
    "trust", "turn", "ups", "urw", "us", "usa", "usc", "usr", "var", "vary", "vast", "virus", "visa", "wa", "wars",
    "was", "were", "won", "worst"
};
static const int kEnglishInContextCount = 158;

/**
 * English function words. One of these, left as typed, starts an English stretch. Words that are
 * everyday Vietnamese without marks ("to", "do", "so", "no", "an", "in", "can") are left out.
 */
static const char* const kEnglishAnchors[] = {
    "about", "all", "also", "and", "any", "are", "as", "at", "been", "but", "by", "could", "did", "does", "for",
    "from", "had", "has", "have", "he", "here", "him", "how", "if", "into", "is", "it", "its", "just", "more",
    "most", "my", "not", "of", "on", "only", "or", "other", "our", "over", "she", "should", "some", "such", "than",
    "that", "the", "their", "them", "there", "these", "they", "this", "those", "very", "was", "we", "were", "what",
    "when", "where", "which", "who", "why", "will", "with", "would", "you", "your"
};
static const int kEnglishAnchorsCount = 69;

/**
 * Vietnamese words that need no mark. Like any word with a mark, they end an English stretch.
 */
static const char* const kVietnameseAsciiWords[] = {
    "ai", "anh", "ba", "bac", "bao", "cao", "cau", "cha", "chi", "cho", "chu", "chung", "co", "con", "cung", "di",
    "em", "giay", "gio", "hai", "hay", "khi", "kia", "kinh", "linh", "lo", "mai", "me", "nam", "nay", "nhanh",
    "nhau", "nhung", "ong", "phut", "quan", "ra", "sang", "sao", "sau", "sinh", "ta", "tay", "thang", "thanh",
    "theo", "tin", "trong", "trung", "tuan", "tui", "vui", "xa", "xe", "xem", "xin"
};
static const int kVietnameseAsciiWordsCount = 56;

#endif /* EnglishWords_h */
