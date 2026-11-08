#include "AppProfileDialog.h"
#include "stdafx.h"
#include "AppDelegate.h"
#include "AppProfile.h"
#include <commdlg.h>

#define MODE_ENGLISH_TEXT _T("Tiếng Anh")
#define MODE_VIET_TEXT _T("Tiếng Việt")

AppProfileDialog::AppProfileDialog(const HINSTANCE& hInstance, const int& resourceId)
	: BaseDialog(hInstance, resourceId) {
}

AppProfileDialog::~AppProfileDialog() {
}

INT_PTR AppProfileDialog::eventProc(HWND hDlg, UINT uMsg, WPARAM wParam, LPARAM lParam) {
	switch (uMsg) {
	case WM_INITDIALOG:
		this->hDlg = hDlg;
		initDialog();
		return TRUE;
	case WM_COMMAND: {
		int wmId = LOWORD(wParam);
		switch (wmId) {
		case IDOK:
		case IDBUTTON_OK:
			AppDelegate::getInstance()->closeDialog(this);
			break;
		case IDC_BUTTON_BROWSE_EXE:
			onBrowseExe();
			break;
		case IDC_BUTTON_SAVE_PROFILE:
			onSaveRule();
			break;
		case IDC_BUTTON_DELETE_PROFILE:
			onDeleteRule();
			break;
		case IDC_COMBO_APP_EXE:
			if (HIWORD(wParam) == CBN_DROPDOWN) {
				fillProcessList(); //refresh the running processes each time it opens
			}
			break;
		}
		break;
	}
	case WM_NOTIFY: {
		if (((LPNMHDR)lParam)->code == LVN_ITEMCHANGED && ((LPNMHDR)lParam)->hwndFrom == hList) {
			NMLISTVIEW* pData = (NMLISTVIEW*)lParam;
			if ((pData->uNewState & LVIS_SELECTED) != 0)
				onSelectItem(pData->iItem);
		}
		break;
	}
	}
	return FALSE;
}

void AppProfileDialog::initDialog() {
	SET_DIALOG_ICON(IDI_APP_ICON);

	hList = GetDlgItem(hDlg, IDC_LIST_APP_PROFILE);
	hComboExe = GetDlgItem(hDlg, IDC_COMBO_APP_EXE);
	hComboMode = GetDlgItem(hDlg, IDC_COMBO_APP_MODE);

	SendMessage(hList, LVM_SETEXTENDEDLISTVIEWSTYLE, LVS_EX_FULLROWSELECT, LVS_EX_FULLROWSELECT);
	LVCOLUMN col;
	memset(&col, 0, sizeof(col));
	col.mask = LVCF_FMT | LVCF_TEXT | LVCF_WIDTH | LVCF_SUBITEM;
	col.pszText = (LPWSTR)L"Ứng dụng";
	col.cx = 230;
	SendMessage(hList, LVM_INSERTCOLUMN, 0, (LPARAM)&col);
	col.pszText = (LPWSTR)L"Chế độ mặc định";
	col.cx = 140;
	SendMessage(hList, LVM_INSERTCOLUMN, 1, (LPARAM)&col);

	SendMessage(hComboMode, CB_ADDSTRING, 0, (LPARAM)MODE_ENGLISH_TEXT);
	SendMessage(hComboMode, CB_ADDSTRING, 0, (LPARAM)MODE_VIET_TEXT);
	SendMessage(hComboMode, CB_SETCURSEL, 0, 0);

	fillProcessList();
	fillData();
}

void AppProfileDialog::fillProcessList() {
	//keep what the user typed/selected
	wstring current = getComboExeText();
	SendMessage(hComboExe, CB_RESETCONTENT, 0, 0);
	for (const wstring& name : AppProfile::enumRunningProcesses()) {
		SendMessage(hComboExe, CB_ADDSTRING, 0, (LPARAM)name.c_str());
	}
	SetWindowText(hComboExe, current.c_str());
}

void AppProfileDialog::fillData() {
	SendMessage(hList, LVM_DELETEALLITEMS, 0, 0);
	const auto& rules = AppProfile::rules();
	for (size_t i = 0; i < rules.size(); i++) {
		LV_ITEM item;
		memset(&item, 0, sizeof(item));
		item.mask = LVIF_TEXT;
		item.iItem = (int)i;
		item.iSubItem = 0;
		item.pszText = (LPWSTR)rules[i].exe.c_str();
		SendMessage(hList, LVM_INSERTITEM, 0, (LPARAM)&item);
		item.iSubItem = 1;
		item.pszText = (LPWSTR)(rules[i].mode ? MODE_VIET_TEXT : MODE_ENGLISH_TEXT);
		SendMessage(hList, LVM_SETITEM, 0, (LPARAM)&item);
	}
}

wstring AppProfileDialog::getComboExeText() {
	TCHAR buffer[MAX_PATH];
	GetWindowText(hComboExe, buffer, MAX_PATH);
	wstring s = buffer;
	//trim spaces and quotes
	size_t b = s.find_first_not_of(L" \t\"");
	if (b == wstring::npos) return L"";
	size_t e = s.find_last_not_of(L" \t\"");
	s = s.substr(b, e - b + 1);
	//accept a full path too: keep the file name only
	size_t slash = s.find_last_of(L"\\/");
	if (slash != wstring::npos)
		s = s.substr(slash + 1);
	return s;
}

void AppProfileDialog::onSelectItem(const int& index) {
	const auto& rules = AppProfile::rules();
	if (index < 0 || index >= (int)rules.size())
		return;
	SetWindowText(hComboExe, rules[index].exe.c_str());
	SendMessage(hComboMode, CB_SETCURSEL, rules[index].mode ? 1 : 0, 0);
}

void AppProfileDialog::onBrowseExe() {
	OPENFILENAME ofn;
	TCHAR szFile[MAX_PATH] = { 0 };
	ZeroMemory(&ofn, sizeof(ofn));
	ofn.lStructSize = sizeof(ofn);
	ofn.hwndOwner = hDlg;
	ofn.lpstrFile = szFile;
	ofn.nMaxFile = MAX_PATH;
	ofn.lpstrFilter = _T("Ứng dụng (*.exe)\0*.exe\0All (*.*)\0*.*\0");
	ofn.nFilterIndex = 1;
	ofn.Flags = OFN_PATHMUSTEXIST | OFN_FILEMUSTEXIST | OFN_DONTADDTORECENT;
	if (GetOpenFileName(&ofn) == TRUE) {
		SetWindowText(hComboExe, szFile); //getComboExeText keeps the file name
		SetWindowText(hComboExe, getComboExeText().c_str());
	}
}

void AppProfileDialog::onSaveRule() {
	wstring exe = getComboExeText();
	if (exe.empty()) {
		MessageBox(hDlg, _T("Bạn hãy chọn ứng dụng!"), _T("OpenKey"), MB_OK);
		return;
	}
	int mode = (int)SendMessage(hComboMode, CB_GETCURSEL, 0, 0) == 1 ? 1 : 0;
	AppProfile::setRule(exe, mode);
	fillData();
}

void AppProfileDialog::onDeleteRule() {
	wstring exe = getComboExeText();
	if (exe.empty() || !AppProfile::removeRule(exe)) {
		MessageBox(hDlg, _T("Bạn hãy chọn quy tắc cần xoá!"), _T("OpenKey"), MB_OK);
		return;
	}
	SetWindowText(hComboExe, _T(""));
	fillData();
}
