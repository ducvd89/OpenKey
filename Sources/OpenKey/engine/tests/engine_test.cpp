//
//  engine_test.cpp
//  OpenKey engine tests
//
//  Drives the engine the same way the macOS event tap does (OpenKey.mm) and keeps a simulated
//  text field, so every expectation is about what the user would see on screen.
//
//  Build and run: ./run.sh
//

#include "../Engine.h"
#include "../EnglishWords.h"
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <iostream>
#include <sstream>
#include <clocale>
#include <cwctype>

using namespace std;

// Settings the host application normally owns.
int vLanguage = 1;
int vInputType = 0;
int vFreeMark = 0;
int vCodeTable = 0;
int vSwitchKeyStatus = 0;
int vCheckSpelling = 1;
int vUseModernOrthography = 0;
int vQuickTelex = 0;
int vRestoreIfWrongSpelling = 0;
int vFixRecommendBrowser = 0;
int vUseMacro = 0;
int vUseMacroInEnglishMode = 0;
int vAutoCapsMacro = 0;
int vUseSmartSwitchKey = 0;
int vUpperCaseFirstChar = 0;
int vTempOffSpelling = 0;
int vAllowConsonantZFWJ = 0;
int vQuickStartConsonant = 0;
int vQuickEndConsonant = 0;
int vRememberCode = 0;
int vOtherLanguage = 0;
int vTempOffOpenKey = 0;

static int failures = 0;
static int checks = 0;

// How many of the words in english_words.txt may come out altered. Ceilings only ever go down;
// raise one only for a deliberate behaviour change.
static const int ENGLISH_CEILING_PLAIN = 2984;
static const int ENGLISH_CEILING_RESTORE = 372;
static const int ENGLISH_CEILING_CONTEXT = 221;

static string narrow(const wstring& text) {
    return wideStringToUtf8(text);
}

#pragma mark - Simulated text field

// Special keys in key strings.
static const wchar_t kBackspace = L'⌫';
static const wchar_t kEnter = L'↵';
static const wchar_t kTab = L'⇥';
static const wchar_t kEscape = L'⎋';
static const wchar_t kLeft = L'←';
static const wchar_t kClick = L'¤'; // mouse click: the caret moved somewhere else

struct Sim {
    vKeyHookState* state;
    wstring screen;
    string problem; // first broken invariant, empty when none

    Sim() {
        state = (vKeyHookState*)vKeyInit();
        reset();
    }

    void reset() {
        vKeyInit();
        startNewSession();
        click();
        screen.clear();
        problem.clear();
    }

    void click() {
        vKeyHandleEvent(vKeyEvent::Mouse, vKeyEventState::MouseDown, 0);
    }

    static wchar_t toChar(Uint32 data) {
        if (data & (PURE_CHARACTER_MASK | CHAR_CODE_MASK))
            return (wchar_t)(data & CHAR_MASK);
        wchar_t c = (wchar_t)keyCodeToCharacter(data);
        return c ? c : L'�';
    }

    void erase(int count) {
        if (count > (int)screen.size()) {
            if (problem.empty())
                problem = "engine deleted more characters than it ever typed";
            count = (int)screen.size();
        }
        screen.erase(screen.size() - count);
    }

    // rawChar is what the key types when the engine leaves it alone, 0 for keys that type nothing.
    void key(Uint16 keyCode, bool shift, wchar_t rawChar) {
        vKeyHandleEvent(vKeyEvent::Keyboard, vKeyEventState::KeyDown, keyCode, shift ? 1 : 0, false);
        switch (state->code) {
            case vDoNothing:
                if (keyCode == KEY_DELETE) {
                    if (!screen.empty())
                        screen.erase(screen.size() - 1);
                } else if (rawChar) {
                    screen += rawChar;
                }
                break;
            case vWillProcess:
            case vRestore:
            case vRestoreAndStartNewSession:
                if (state->newCharCount > MAX_BUFF && problem.empty())
                    problem = "newCharCount is larger than the buffer";
                if (state->backspaceCount > 0 && state->backspaceCount < MAX_BUFF)
                    erase(state->backspaceCount);
                for (int i = state->newCharCount - 1; i >= 0 && i < MAX_BUFF; i--)
                    screen += toChar(state->charData[i]);
                if (state->code != vWillProcess && rawChar)
                    screen += rawChar;
                if (state->code == vRestoreAndStartNewSession)
                    startNewSession();
                break;
            case vReplaceMaro:
                erase(state->backspaceCount);
                for (size_t i = 0; i < state->macroData.size(); i++)
                    screen += toChar(state->macroData[i]);
                if (rawChar)
                    screen += rawChar;
                break;
        }
    }

    void type(const wstring& keys) {
        for (size_t i = 0; i < keys.size(); i++) {
            wchar_t c = keys[i];
            if (c == kBackspace) {
                key(KEY_DELETE, false, 0);
            } else if (c == kEnter) {
                key(KEY_RETURN, false, kEnter); // shown as the symbol so a case stays on one line
            } else if (c == kTab) {
                key(KEY_TAB, false, kTab);
            } else if (c == kEscape) {
                key(KEY_ESC, false, 0);
            } else if (c == kLeft) {
                key(KEY_LEFT, false, 0);
            } else if (c == kClick) {
                click();
            } else if (_characterMap.find(c) != _characterMap.end()) {
                Uint32 code = _characterMap[c];
                key((Uint16)code, (code & CAPS_MASK) != 0, c);
            } else {
                screen += c; // not on the keyboard, the engine never sees it
            }
        }
    }
};

#pragma mark - Options

static void setDefaults() {
    vInputType = vTelex;
    vCodeTable = 0;
    vFreeMark = 0;
    vCheckSpelling = 1;
    vUseModernOrthography = 0;
    vQuickTelex = 0;
    vRestoreIfWrongSpelling = 0;
    vEnglishContext = 0;
    vUseMacro = 0;
    vAutoCapsMacro = 0;
    vUpperCaseFirstChar = 0;
    vAllowConsonantZFWJ = 0;
    vQuickStartConsonant = 0;
    vQuickEndConsonant = 0;
    vSetCheckSpelling();
}

static void defineMacros() {
    initMacroMap((const Byte*)"\0\0", 2);
    addMacro("btw", "by the way");
    addMacro("vn", "Việt Nam");
}

static bool applyOption(const string& name) {
    if (name == "-" || name.empty()) return true;
    if (name == "vni") vInputType = vVNI;
    else if (name == "simple1") vInputType = vSimpleTelex1;
    else if (name == "simple2") vInputType = vSimpleTelex2;
    else if (name == "restore") vRestoreIfWrongSpelling = 1;
    else if (name == "context") { vRestoreIfWrongSpelling = 1; vEnglishContext = 1; }
    else if (name == "nospell") vCheckSpelling = 0;
    else if (name == "modern") vUseModernOrthography = 1;
    else if (name == "quick") vQuickTelex = 1;
    else if (name == "free") vFreeMark = 1;
    else if (name == "zfwj") vAllowConsonantZFWJ = 1;
    else if (name == "quickstart") vQuickStartConsonant = 1;
    else if (name == "quickend") vQuickEndConsonant = 1;
    else if (name == "macro") { vUseMacro = 1; defineMacros(); }
    else if (name == "autocaps") { vUseMacro = 1; vAutoCapsMacro = 1; defineMacros(); }
    else if (name == "upper") vUpperCaseFirstChar = 1;
    else return false;
    return true;
}

static bool applyOptions(const string& options) {
    setDefaults();
    stringstream stream(options);
    string name;
    while (getline(stream, name, ',')) {
        if (!applyOption(name)) {
            fprintf(stderr, "unknown option '%s'\n", name.c_str());
            return false;
        }
    }
    vSetCheckSpelling();
    return true;
}

static string dataPath(const string& dir, const string& name) {
    return dir + "/" + name;
}

#pragma mark - Golden cases

// cases.tsv: options <TAB> keys <TAB> expected screen text
static void runCases(const string& path) {
    ifstream file(path.c_str());
    if (!file.is_open()) {
        fprintf(stderr, "cannot open %s\n", path.c_str());
        failures++;
        return;
    }
    Sim sim;
    string line;
    int lineNumber = 0;
    int count = 0;
    while (getline(file, line)) {
        lineNumber++;
        if (line.empty() || line[0] == '#') continue;
        size_t first = line.find('\t');
        size_t second = first == string::npos ? string::npos : line.find('\t', first + 1);
        if (second == string::npos) {
            fprintf(stderr, "%s:%d: expected 3 tab-separated fields\n", path.c_str(), lineNumber);
            failures++;
            continue;
        }
        string options = line.substr(0, first);
        string keys = line.substr(first + 1, second - first - 1);
        string expected = line.substr(second + 1);
        if (!applyOptions(options)) {
            failures++;
            continue;
        }
        sim.reset();
        sim.type(utf8ToWideString(keys));
        string actual = narrow(sim.screen);
        checks++;
        count++;
        if (actual != expected || !sim.problem.empty()) {
            failures++;
            fprintf(stderr, "FAIL cases.tsv:%d [%s] \"%s\"\n     expected \"%s\"\n     actual   \"%s\"%s%s\n",
                    lineNumber, options.c_str(), keys.c_str(), expected.c_str(), actual.c_str(),
                    sim.problem.empty() ? "" : "\n     ", sim.problem.c_str());
        }
    }
    printf("cases: %d\n", count);
}

#pragma mark - Vietnamese round trip

static const wchar_t* kToneRows[] = {
    L"aàáảãạ", L"ăằắẳẵặ", L"âầấẩẫậ", L"eèéẻẽẹ", L"êềếểễệ", L"iìíỉĩị",
    L"oòóỏõọ", L"ôồốổỗộ", L"ơờớởỡợ", L"uùúủũụ", L"ưừứửữự", L"yỳýỷỹỵ"
};
static const wchar_t* kTelexBase[] = {L"a", L"aw", L"aa", L"e", L"ee", L"i", L"o", L"oo", L"ow", L"u", L"uw", L"y"};
static const wchar_t* kVniBase[] = {L"a", L"a8", L"a6", L"e", L"e6", L"i", L"o", L"o6", L"o7", L"u", L"u7", L"y"};
static const wchar_t kTelexTone[] = {0, L'f', L's', L'r', L'x', L'j'};
static const wchar_t kVniTone[] = {0, L'2', L'1', L'3', L'4', L'5'};

// Keys a typist presses for a word. toneAtEnd=false puts the tone right after its vowel.
static wstring keysFor(const wstring& word, bool vni, bool toneAtEnd) {
    wstring keys;
    wchar_t tone = 0;
    for (size_t i = 0; i < word.size(); i++) {
        wchar_t c = word[i];
        bool upper = false;
        wchar_t lower = towlower(c);
        if (lower != c) upper = true;
        // towlower may not know Vietnamese letters in the C locale, fall back to table search below
        bool found = false;
        if (lower == L'đ' || c == L'Đ') {
            keys += (c == L'Đ' || upper) ? (vni ? L"D9" : L"DD") : (vni ? L"d9" : L"dd");
            continue;
        }
        for (int row = 0; row < 12 && !found; row++) {
            for (int t = 0; t < 6 && !found; t++) {
                wchar_t candidate = kToneRows[row][t];
                wchar_t candidateUpper = towupper(candidate);
                if (candidate == c || (candidateUpper != candidate && candidateUpper == c)) {
                    wstring base = vni ? kVniBase[row] : kTelexBase[row];
                    if (candidate != c) {
                        for (size_t k = 0; k < base.size(); k++) base[k] = towupper(base[k]);
                    }
                    keys += base;
                    if (t > 0) {
                        wchar_t toneKey = vni ? kVniTone[t] : kTelexTone[t];
                        if (toneAtEnd) tone = toneKey; else keys += toneKey;
                    }
                    found = true;
                }
            }
        }
        if (!found) keys += c;
    }
    if (tone) keys += tone;
    return keys;
}

static vector<wstring> readWords(const string& path) {
    vector<wstring> words;
    ifstream file(path.c_str());
    if (!file.is_open()) {
        fprintf(stderr, "cannot open %s\n", path.c_str());
        failures++;
        return words;
    }
    string line;
    while (getline(file, line)) {
        if (line.empty() || line[0] == '#') continue;
        stringstream stream(line);
        string word;
        while (stream >> word) words.push_back(utf8ToWideString(word));
    }
    return words;
}

// Every word must come back exactly as written, whatever the typing style or restore setting.
static void runRoundTrip(const string& path) {
    vector<wstring> words = readWords(path);
    struct Mode { const char* options; bool vni; bool toneAtEnd; };
    const Mode modes[] = {
        {"-", false, true}, {"-", false, false},
        {"restore", false, true}, {"restore", false, false},
        {"context", false, true}, {"context", false, false},
        {"vni", true, true}, {"vni,restore", true, true},
    };
    Sim sim;
    int count = 0;
    for (size_t m = 0; m < sizeof(modes) / sizeof(modes[0]); m++) {
        applyOptions(modes[m].options);
        for (size_t i = 0; i < words.size(); i++) {
            wstring keys = keysFor(words[i], modes[m].vni, modes[m].toneAtEnd) + L" ";
            sim.reset();
            sim.type(keys);
            checks++;
            count++;
            if (sim.screen != words[i] + L" " || !sim.problem.empty()) {
                failures++;
                fprintf(stderr, "FAIL round trip [%s] \"%s\" typed as \"%s\" gave \"%s\" %s\n", modes[m].options,
                        narrow(words[i]).c_str(), narrow(keys).c_str(), narrow(sim.screen).c_str(), sim.problem.c_str());
            }
        }
    }
    printf("round trip: %d (%d words)\n", count, (int)words.size());
}

#pragma mark - English ratchet

// Counts common English words that do not survive being typed in Vietnamese mode.
static int countAltered(const vector<wstring>& words, const char* options, const wstring& prefix, vector<string>* samples) {
    applyOptions(options);
    Sim sim;
    int altered = 0;
    for (size_t i = 0; i < words.size(); i++) {
        sim.reset();
        sim.type(prefix + words[i] + L" ");
        if (sim.screen != prefix + words[i] + L" ") {
            altered++;
            if (samples && samples->size() < 12)
                samples->push_back(narrow(words[i]) + ">" + narrow(sim.screen.substr(prefix.size())));
        }
    }
    return altered;
}

static void runEnglishRatchet(const string& path) {
    vector<wstring> words = readWords(path);
    if (words.empty()) return;
    struct Level { const char* name; const char* options; const wchar_t* prefix; int ceiling; };
    const Level levels[] = {
        {"restore off", "-", L"", ENGLISH_CEILING_PLAIN},
        {"restore on", "restore", L"", ENGLISH_CEILING_RESTORE},
        {"restore on, after \"the \"", "context", L"the ", ENGLISH_CEILING_CONTEXT},
    };
    for (size_t l = 0; l < sizeof(levels) / sizeof(levels[0]); l++) {
        vector<string> samples;
        int altered = countAltered(words, levels[l].options, levels[l].prefix, &samples);
        checks++;
        printf("english, %s: %d of %d altered (ceiling %d)\n", levels[l].name, altered, (int)words.size(), levels[l].ceiling);
        if (altered > levels[l].ceiling) {
            failures++;
            fprintf(stderr, "FAIL english ratchet \"%s\": %d altered, ceiling is %d. First ones:", levels[l].name, altered, levels[l].ceiling);
            for (size_t s = 0; s < samples.size(); s++) fprintf(stderr, " %s", samples[s].c_str());
            fprintf(stderr, "\n");
        }
    }
}

#pragma mark - Word lists

static void checkSorted(const char* name, const char* const* words, int count) {
    checks++;
    for (int i = 0; i < count; i++) {
        for (const char* c = words[i]; *c; c++) {
            if (*c < 'a' || *c > 'z') {
                failures++;
                fprintf(stderr, "FAIL %s: \"%s\" must be lowercase a-z only\n", name, words[i]);
                return;
            }
        }
        if (i > 0 && strcmp(words[i - 1], words[i]) >= 0) {
            failures++;
            fprintf(stderr, "FAIL %s: \"%s\" then \"%s\" breaks the sort order the binary search needs\n", name, words[i - 1], words[i]);
            return;
        }
    }
}

static void runWordListChecks() {
    checkSorted("kEnglishAlways", kEnglishAlways, kEnglishAlwaysCount);
    checkSorted("kEnglishInContext", kEnglishInContext, kEnglishInContextCount);
    checkSorted("kEnglishAnchors", kEnglishAnchors, kEnglishAnchorsCount);
    checkSorted("kVietnameseAsciiWords", kVietnameseAsciiWords, kVietnameseAsciiWordsCount);
    printf("word lists: %d always, %d in context, %d anchors\n", kEnglishAlwaysCount, kEnglishInContextCount, kEnglishAnchorsCount);
}

#pragma mark - Fuzz

struct Random {
    unsigned long long state;
    explicit Random(unsigned long long seed) : state(seed) {}
    unsigned long long next() { // SplitMix64
        unsigned long long z = (state += 0x9E3779B97F4A7C15ULL);
        z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9ULL;
        z = (z ^ (z >> 27)) * 0x94D049BB133111EBULL;
        return z ^ (z >> 31);
    }
    int below(int limit) { return (int)(next() % (unsigned long long)limit); }
};

static wstring randomKeys(Random& random, int length) {
    // Weighted towards the keys that drive Telex and VNI, plus edits and punctuation.
    static const wstring letters = L"aaaeeeooouuiiywwddsfrxjzbcghklmnpqtv";
    static const wstring others = L"1234567890.,;:'\"-_=+/\\!?()[]{}@#$~`";
    // Whole words now and then, so the restore paths get exercised between the random edits.
    static const wchar_t* words[] = {L"pass", L"posts", L"issue", L"career", L"data", L"the", L"this", L"list", L"does",
                                     L"user", L"www", L"toans", L"truowngf", L"thees", L"dduowcj", L"nguoiwf"};
    wstring keys;
    for (int i = 0; i < length; i++) {
        int roll = random.below(100);
        if (roll < 8) {
            keys += words[random.below(sizeof(words) / sizeof(words[0]))];
        } else if (roll < 66) {
            wchar_t c = letters[random.below((int)letters.size())];
            keys += random.below(12) == 0 ? (wchar_t)towupper(c) : c;
        } else if (roll < 78) {
            keys += L' ';
        } else if (roll < 88) {
            keys += kBackspace;
        } else if (roll < 96) {
            keys += others[random.below((int)others.size())];
        } else {
            static const wchar_t controls[] = {kEnter, kTab, kEscape, kLeft, kClick};
            keys += controls[random.below(5)];
        }
    }
    return keys;
}

// The word the engine believes is under the caret must be what is on screen.
static string checkEngineMatchesScreen(const Sim& sim) {
    vector<Uint32> word;
    if (!vDebugTypingWord(word) || word.empty()) return "";
    if (word.size() > sim.screen.size()) return "engine word is longer than the text on screen";
    for (size_t i = 0; i < word.size(); i++) {
        Uint32 code = getCharacterCode(word[i]);
        wchar_t expected = (code & CHAR_CODE_MASK) ? (wchar_t)(code & CHAR_MASK) : (wchar_t)keyCodeToCharacter(code & (CHAR_MASK | CAPS_MASK));
        wchar_t actual = sim.screen[sim.screen.size() - word.size() + i];
        if (expected != actual)
            return "engine word differs from the text on screen";
    }
    return "";
}

static string runSequence(const wstring& keys, const char* options) {
    applyOptions(options);
    Sim sim;
    for (size_t i = 0; i < keys.size(); i++) {
        sim.type(keys.substr(i, 1));
        if (!sim.problem.empty()) return sim.problem;
        string mismatch = checkEngineMatchesScreen(sim);
        if (!mismatch.empty()) return mismatch;
    }
    return "";
}

static void runFuzz(unsigned long long firstSeed, int seeds, int steps) {
    const char* optionSets[] = {"-", "restore", "context", "modern,quick,restore", "vni,restore", "free", "zfwj,quickstart,quickend,context", "upper,context"};
    const int optionCount = sizeof(optionSets) / sizeof(optionSets[0]);
    int failed = 0;
    for (int s = 0; s < seeds && failed < 5; s++) {
        unsigned long long seed = firstSeed + s;
        Random random(seed);
        const char* options = optionSets[seed % optionCount];
        wstring keys = randomKeys(random, steps);
        string problem = runSequence(keys, options);
        checks++;
        if (problem.empty()) continue;
        failed++;
        failures++;
        // Shrink: drop chunks while the same problem still shows.
        for (size_t chunk = keys.size() / 2; chunk >= 1; chunk /= 2) {
            for (size_t start = 0; start + chunk <= keys.size();) {
                wstring candidate = keys.substr(0, start) + keys.substr(start + chunk);
                if (runSequence(candidate, options) == problem) keys = candidate; else start += chunk;
            }
            if (chunk == 1) break;
        }
        fprintf(stderr, "FAIL fuzz seed %llu [%s]: %s\n     keys \"%s\"\n", seed, options, problem.c_str(), narrow(keys).c_str());
    }
    printf("fuzz: %d seeds x %d keys from seed %llu\n", seeds, steps, firstSeed);
}

#pragma mark - Main

int main(int argc, char** argv) {
    setlocale(LC_ALL, "en_US.UTF-8"); // towupper on Vietnamese letters
    string dir = ".";
    unsigned long long seed = 1;
    int seeds = 400;
    int steps = 300;
    bool echo = false;
    vector<string> echoArgs;
    for (int i = 1; i < argc; i++) {
        string arg = argv[i];
        if (arg == "--dir" && i + 1 < argc) dir = argv[++i];
        else if (arg == "--seed" && i + 1 < argc) { seed = strtoull(argv[++i], NULL, 10); seeds = 1; }
        else if (arg == "--seeds" && i + 1 < argc) seeds = atoi(argv[++i]);
        else if (arg == "--steps" && i + 1 < argc) steps = atoi(argv[++i]);
        else if (arg == "--type") echo = true; // --type <options> <keys>...: print what the screen shows
        else echoArgs.push_back(arg);
    }

    if (echo) {
        if (echoArgs.empty() || !applyOptions(echoArgs[0])) return 2;
        Sim sim;
        for (size_t i = 1; i < echoArgs.size(); i++) {
            sim.reset();
            sim.type(utf8ToWideString(echoArgs[i]));
            vector<Uint32> word;
            wstring engineWord;
            if (vDebugTypingWord(word)) {
                for (size_t k = 0; k < word.size(); k++) {
                    Uint32 code = getCharacterCode(word[k]);
                    engineWord += (code & CHAR_CODE_MASK) ? (wchar_t)(code & CHAR_MASK) : (wchar_t)keyCodeToCharacter(code & (CHAR_MASK | CAPS_MASK));
                }
            }
            printf("%s\t[%s]\tengine word [%s]\n", echoArgs[i].c_str(), narrow(sim.screen).c_str(), narrow(engineWord).c_str());
        }
        return 0;
    }

    runWordListChecks();
    runCases(dataPath(dir, "cases.tsv"));
    runRoundTrip(dataPath(dir, "vietnamese_words.txt"));
    runEnglishRatchet(dataPath(dir, "english_words.txt"));
    runFuzz(seed, seeds, steps);

    if (failures) {
        fprintf(stderr, "\n%d of %d checks failed\n", failures, checks);
        return 1;
    }
    printf("\nall %d checks passed\n", checks);
    return 0;
}
