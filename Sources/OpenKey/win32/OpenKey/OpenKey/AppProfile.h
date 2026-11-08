/*----------------------------------------------------------
Per-application language profile (Win32).
A rule forces Vietnamese/English mode while an application has focus;
the previous mode is restored when focus leaves the application.
-----------------------------------------------------------*/
#pragma once
#include "stdafx.h"

struct AppProfileRule {
	wstring exe;   //executable file name, e.g. "notepad.exe"
	int mode;      //0 = English, 1 = Vietnamese
};

namespace AppProfile {
	void load();
	void save();

	const vector<AppProfileRule>& rules();
	//add a rule or update the mode if the exe already has one
	void setRule(const wstring& exe, int mode);
	bool removeRule(const wstring& exe);

	//called from the foreground-window hook. Returns true when a rule
	//forced the language for the app that just got focus.
	bool onForegroundChanged(const string& exeUtf8);
	//restore the language saved before a profile applied (used on exit)
	void restoreIfActive();

	//executable names of the running processes (sorted, unique)
	vector<wstring> enumRunningProcesses();
}
