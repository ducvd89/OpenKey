#pragma once
#include "BaseDialog.h"

class AppProfileDialog : public BaseDialog {
private:
	HWND hList, hComboExe, hComboMode;
public:
	AppProfileDialog(const HINSTANCE& hInstance, const int& resourceId);
	~AppProfileDialog();
	virtual void fillData() override;
protected:
	INT_PTR eventProc(HWND hDlg, UINT uMsg, WPARAM wParam, LPARAM lParam);
	void initDialog();
private:
	void fillProcessList();
	void onSelectItem(const int& index);
	void onBrowseExe();
	void onSaveRule();
	void onDeleteRule();
	wstring getComboExeText();
};
