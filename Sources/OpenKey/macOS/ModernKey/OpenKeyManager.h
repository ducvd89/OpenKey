//
//  OpenKeyManager.h
//  ModernKey
//
//  Created by Tuyen on 1/27/19.
//  Copyright © 2019 Tuyen Mai. All rights reserved.
//

#ifndef OpenKeyManager_h
#define OpenKeyManager_h

#import <Cocoa/Cocoa.h>

typedef void (^CheckNewVersionCallback)(void);

@interface OpenKeyManager : NSObject
+(BOOL)isInited;
+(BOOL)initEventTap;
+(BOOL)stopEventTap;
+(void)reenableEventTap;

/// Name of the app holding Secure Input, an empty string when it is on but the holder is unknown,
/// nil when Secure Input is off. While it is on, no event tap receives keys.
+(NSString *)secureInputHolder;
/// A browser built on Chromium, recognised by its bundle layout.
+(BOOL)isChromiumBrowser:(NSRunningApplication *)app;
/// Remote desktop clients and virtual machines, where the other side usually has its own input method.
+(BOOL)isRemoteControlApplication:(NSString *)identifier;
+(NSString *)profileIdentifierForApplication:(NSRunningApplication *)app displayName:(NSString **)displayName;

+(NSArray*)getTableCodes;

+(NSString*)getBuildDate;
+(void)showMessage:(NSWindow*)window message:(NSString*)msg subMsg:(NSString*)subMsg;

+(BOOL)quickConvert;

+(void)checkNewVersion:(NSWindow*)parent callbackFunc:(CheckNewVersionCallback) callback;
@end

#endif /* OpenKeyManager_h */
