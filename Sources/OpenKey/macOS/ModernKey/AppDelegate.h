//
//  AppDelegate.h
//  ModernKey
//
//  Created by Tuyen on 1/18/19.
//  Copyright © 2019 Tuyen Mai. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ViewController.h"

#define OPENKEY_BUNDLE @"app.cid.openkey"

extern NSString * const OpenKeyAppProfilesKey;

@interface AppDelegate : NSObject <NSApplicationDelegate>

-(void)setInputLanguage:(int)language remember:(BOOL)remember;
-(void)onInputMethodSelected;
-(void)showLanguageSwitchHUD;
-(void)beginLanguageSwitchPreviewAfter:(NSTimeInterval)delay;
-(void)endLanguageSwitchPreview;
-(void)finishLanguageSwitchPreview;
-(void)onAppProfilesSelected;
-(void)refreshActiveApp;

-(BOOL)refreshInputPermission;
-(void)requestInputPermission;

-(void)onInputTypeSelectedIndex:(int)index;
-(void)onCodeTableChanged:(int)index;

-(void)setRunOnStartup:(BOOL)val;
-(void)loadDefaultConfig;

-(void)setGrayIcon:(BOOL)val;

-(void)onMacroSelected;
-(void)onConvertTool;
-(void)onAboutSelected;
-(void)onControlPanelSelected;
-(void)onQuickConvert;
-(void)setQuickConvertString;

-(void)showIconOnDock:(BOOL)val;
@end

