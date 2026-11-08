#include "AppProfile.h"
#include "AppDelegate.h"
#include <algorithm>

#define REG_KEY_APP_PROFILES _T("appProfiles")

static vector<AppProfileRule> _rules;
static bool _active = false;     //a profile is currently applied
static wstring _activeExe;       //exe of the app the profile applied to
static int _previousLanguage = 0; //language before the profile applied

static wstring lower(const wstring& s) {
	wstring r = s;
	transform(r.begin(), r.end(), r.begin(), ::towlower);
	return r;
}

static vector<AppProfileRule>::iterator findRule(const wstring& exe) {
	wstring key = lower(exe);
	return find_if(_rules.begin(), _rules.end(), [&](const AppProfileRule& r) { return lower(r.exe) == key; });
}

//storage format (UTF-8): one rule per line, "<exe>\t<mode>\n"
void AppProfile::load() {
	_rules.clear();
	DWORD size = 0;
	BYTE* data = OpenKeyHelper::getRegBinary(REG_KEY_APP_PROFILES, size);
	if (data == NULL || size == 0)
		return;
	string text((char*)data, size); //data is owned by OpenKeyHelper, don't free it

	size_t pos = 0;
	while (pos < text.size()) {
		size_t end = text.find('\n', pos);
		if (end == string::npos) end = text.size();
		string line = text.substr(pos, end - pos);
		pos = end + 1;
		size_t tab = line.rfind('\t');
		if (tab == string::npos || tab == 0)
			continue;
		wstring exe = utf8ToWideString(line.substr(0, tab));
		int mode = atoi(line.c_str() + tab + 1) ? 1 : 0;
		if (findRule(exe) == _rules.end())
			_rules.push_back({ exe, mode });
	}
}

void AppProfile::save() {
	string text;
	for (const auto& r : _rules) {
		text += wideStringToUtf8(r.exe);
		text += '\t';
		text += (r.mode ? '1' : '0');
		text += '\n';
	}
	OpenKeyHelper::setRegBinary(REG_KEY_APP_PROFILES, (const BYTE*)text.data(), (int)text.size());
}

const vector<AppProfileRule>& AppProfile::rules() {
	return _rules;
}

void AppProfile::setRule(const wstring& exe, int mode) {
	auto it = findRule(exe);
	if (it != _rules.end()) {
		it->mode = mode ? 1 : 0;
	} else {
		_rules.push_back({ exe, mode ? 1 : 0 });
	}
	save();
}

bool AppProfile::removeRule(const wstring& exe) {
	auto it = findRule(exe);
	if (it == _rules.end())
		return false;
	_rules.erase(it);
	save();
	return true;
}

static void applyLanguage(int language) {
	if (vLanguage == language)
		return;
	vLanguage = language;
	AppDelegate::getInstance()->onInputMethodChangedFromHotKey();
	vTempOffEngine(false);
	startNewSession();
}

bool AppProfile::onForegroundChanged(const string& exeUtf8) {
	wstring exe = utf8ToWideString(exeUtf8);

	//focus left the profiled app: go back to the state before it
	if (_active && lower(exe) != lower(_activeExe)) {
		_active = false;
		applyLanguage(_previousLanguage);
	}

	auto it = findRule(exe);
	if (it == _rules.end())
		return false;

	if (!_active) {
		_active = true;
		_activeExe = exe;
		_previousLanguage = vLanguage;
	}
	applyLanguage(it->mode);
	return true;
}

void AppProfile::restoreIfActive() {
	if (_active) {
		_active = false;
		applyLanguage(_previousLanguage);
	}
}

vector<wstring> AppProfile::enumRunningProcesses() {
	vector<wstring> names;
	DWORD pids[4096], bytes = 0;
	if (!EnumProcesses(pids, sizeof(pids), &bytes))
		return names;
	DWORD count = bytes / sizeof(DWORD);
	for (DWORD i = 0; i < count; i++) {
		if (pids[i] == 0)
			continue;
		HANDLE h = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pids[i]);
		if (!h)
			continue;
		wchar_t path[MAX_PATH];
		DWORD len = MAX_PATH;
		if (QueryFullProcessImageNameW(h, 0, path, &len)) {
			wchar_t* slash = wcsrchr(path, L'\\');
			names.push_back(slash ? slash + 1 : path);
		}
		CloseHandle(h);
	}
	sort(names.begin(), names.end(), [](const wstring& a, const wstring& b) { return lower(a) < lower(b); });
	names.erase(unique(names.begin(), names.end(), [](const wstring& a, const wstring& b) { return lower(a) == lower(b); }), names.end());
	return names;
}
