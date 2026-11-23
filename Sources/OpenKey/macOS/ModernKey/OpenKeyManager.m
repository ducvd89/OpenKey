//
//  OpenKeyManager.m
//  OpenKey
//
//  Created by Tuyen on 1/27/19.
//  Copyright © 2019 Tuyen Mai. All rights reserved.
//

#import <Carbon/Carbon.h>
#import "OpenKeyManager.h"
#import "AppDelegate.h"
#import "MJAccessibilityUtils.h"
#include <string.h>
#include <sys/sysctl.h>

extern void OpenKeyInit(void);

extern CGEventRef OpenKeyCallback(CGEventTapProxy proxy,
                                  CGEventType type,
                                  CGEventRef event,
                                  void *refcon);

extern NSString* ConvertUtil(NSString* str);
extern void RequestNewSession(void);
extern int vLanguage;

@interface OpenKeyManager ()

@end

@implementation OpenKeyManager {

}
static BOOL _isInited = NO;

static CFMachPortRef      eventTap;
static CGEventMask        eventMask;
static CFRunLoopSourceRef runLoopSource;
static CFMachPortRef      mouseTap;
static CFRunLoopSourceRef mouseRunLoopSource;

// Mouse clicks only need to end the word being typed, so they are observed through a
// listen-only tap. Keeping them out of the active tap means drags elsewhere
// (menu bar managers, window moves) never wait on OpenKey's main thread.
static CGEventRef OpenKeyMouseCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
    if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput) {
        if (mouseTap) {
            CGEventTapEnable(mouseTap, true);
        }
        return event;
    }
    if (vLanguage != 0) {
        RequestNewSession();
    }
    return event;
}

static NSString *windowsExecutableName(pid_t pid) {
    int mib[] = {CTL_KERN, KERN_PROCARGS2, pid};
    size_t size = 0;
    if (sysctl(mib, 3, NULL, &size, NULL, 0) != 0 || size <= sizeof(int)) {
        return nil;
    }
    NSMutableData *args = [NSMutableData dataWithLength:size];
    if (sysctl(mib, 3, args.mutableBytes, &size, NULL, 0) != 0 || size <= sizeof(int)) {
        return nil;
    }

    // The buffer starts with argc, the native executable path, padding, and argv[0].
    const char *bytes = args.bytes;
    int argumentCount;
    memcpy(&argumentCount, bytes, sizeof(argumentCount));
    const char *end = bytes + size;
    const char *pathEnd = memchr(bytes + sizeof(argumentCount), 0, size - sizeof(argumentCount));
    if (argumentCount < 1 || !pathEnd) {
        return nil;
    }
    const char *argument = pathEnd + 1;
    while (argument < end && *argument == 0) {
        argument++;
    }
    const char *argumentEnd = memchr(argument, 0, end - argument);
    if (!argumentEnd) {
        return nil;
    }

    NSString *path = [[NSString alloc] initWithBytes:argument length:argumentEnd - argument encoding:NSUTF8StringEncoding];
    NSString *name = [path stringByReplacingOccurrencesOfString:@"\\" withString:@"/"].lastPathComponent;
    return [name.pathExtension.lowercaseString isEqualToString:@"exe"] ? name : nil;
}

+(NSString *)profileIdentifierForApplication:(NSRunningApplication *)app displayName:(NSString **)displayName {
    NSString *identifier = app.bundleIdentifier;
    NSString *name = app.localizedName;
    NSString *launcher = app.executableURL.lastPathComponent.lowercaseString;
    BOOL wineHost = [launcher isEqualToString:@"wine"] || [launcher isEqualToString:@"wine64"] ||
                    [launcher isEqualToString:@"wine-preloader"] || [launcher isEqualToString:@"wine64-preloader"];
    if (!identifier.length || wineHost) {
        // Wine runs different Windows apps through the same native binary.
        NSString *executable = windowsExecutableName(app.processIdentifier);
        if (executable) {
            name = executable;
            identifier = [@"windows-exe:" stringByAppendingString:executable.lowercaseString];
        }
    }
    if (displayName) {
        *displayName = name ?: identifier;
    }
    return identifier;
}

+(BOOL)isInited {
    return _isInited;
}

+(BOOL)initEventTap {
    if (_isInited)
        return true;
    if (!MJAccessibilityIsEnabled())
        return NO;
    
    // Create an event tap. We are interested in key presses.
    eventMask = ((1 << kCGEventKeyDown) |
                 (1 << kCGEventKeyUp) |
                 (1 << kCGEventFlagsChanged));
    
    eventTap = CGEventTapCreate(kCGSessionEventTap,
                                kCGHeadInsertEventTap,
                                0,
                                eventMask,
                                OpenKeyCallback,
                                NULL);
    
    if (!eventTap) {
        return NO;
    }

    // Create a run loop source.
    runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0);
    if (!runLoopSource) {
        CFMachPortInvalidate(eventTap);
        CFRelease(eventTap);
        eventTap = NULL;
        return NO;
    }

    OpenKeyInit();
    _isInited = YES;
    
    // Add to the current run loop.
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);

    mouseTap = CGEventTapCreate(kCGSessionEventTap, kCGTailAppendEventTap, kCGEventTapOptionListenOnly,
                                CGEventMaskBit(kCGEventLeftMouseDown) | CGEventMaskBit(kCGEventRightMouseDown) |
                                CGEventMaskBit(kCGEventOtherMouseDown),
                                OpenKeyMouseCallback, NULL);
    if (mouseTap) {
        mouseRunLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, mouseTap, 0);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), mouseRunLoopSource, kCFRunLoopCommonModes);
        CGEventTapEnable(mouseTap, true);
    }
    
    // Enable the event tap.
    CGEventTapEnable(eventTap, true);
    [(AppDelegate *)NSApp.delegate refreshActiveApp];
    
    return YES;
}

+(BOOL)stopEventTap {
    if (_isInited) { //release all object
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);
        CFRelease(runLoopSource);
        runLoopSource = nil;
        
        CFMachPortInvalidate(eventTap);
        CFRelease(eventTap);
        eventTap = nil;

        if (mouseRunLoopSource) {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), mouseRunLoopSource, kCFRunLoopCommonModes);
            CFRelease(mouseRunLoopSource);
            mouseRunLoopSource = nil;
        }
        if (mouseTap) {
            CFMachPortInvalidate(mouseTap);
            CFRelease(mouseTap);
            mouseTap = nil;
        }
        
        _isInited = false;
    }
    return YES;
}

+(void)reenableEventTap {
    if (eventTap && !CGEventTapIsEnabled(eventTap)) {
        CGEventTapEnable(eventTap, true);
    }
}

+(NSString *)secureInputHolder {
    if (!IsSecureEventInputEnabled()) {
        return nil;
    }
    NSDictionary *session = CFBridgingRelease(CGSessionCopyCurrentDictionary());
    NSNumber *pid = session[@"kCGSSessionSecureInputPID"];
    if (![pid isKindOfClass:[NSNumber class]]) {
        return @"";
    }
    NSRunningApplication *app = [NSRunningApplication runningApplicationWithProcessIdentifier:pid.intValue];
    return app.localizedName ?: app.bundleIdentifier ?: @"";
}

+(BOOL)isChromiumBrowser:(NSRunningApplication *)app {
    static NSMutableDictionary<NSString *, NSNumber *> *known;
    NSString *identifier = app.bundleIdentifier;
    NSURL *bundleURL = app.bundleURL;
    if (!identifier.length || !bundleURL || [identifier hasPrefix:@"com.apple."]) {
        return NO;
    }
    NSNumber *answer = known[identifier];
    if (answer) {
        return answer.boolValue;
    }
    if (!known) {
        known = [NSMutableDictionary dictionary];
    }

    // Chrome, Edge, Brave, Arc, Vivaldi and the like keep their renderer inside
    // "<Name> Framework.framework/Helpers". Electron and CEF apps keep it elsewhere, and they are
    // not wanted here: their text fields are not address bars.
    BOOL found = NO;
    NSFileManager *files = [NSFileManager defaultManager];
    NSString *frameworks = [bundleURL.path stringByAppendingPathComponent:@"Contents/Frameworks"];
    for (NSString *framework in [files contentsOfDirectoryAtPath:frameworks error:nil]) {
        if (![framework hasSuffix:@" Framework.framework"]) {
            continue;
        }
        NSString *helpers = [[frameworks stringByAppendingPathComponent:framework] stringByAppendingPathComponent:@"Versions/Current/Helpers"];
        for (NSString *helper in [files contentsOfDirectoryAtPath:helpers error:nil]) {
            if ([helper hasSuffix:@"Helper (Renderer).app"]) {
                found = YES;
                break;
            }
        }
        if (found) {
            break;
        }
    }
    known[identifier] = @(found);
    return found;
}

+(BOOL)isRemoteControlApplication:(NSString *)identifier {
    static NSArray<NSString *> *vendors;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        vendors = @[@"com.microsoft.rdc", @"apple.remotedesktop", @"apple.screensharing", @"teamviewer", @"anydesk",
                    @"parsec", @"moonlight", @"nomachine", @"realvnc", @"rustdesk", @"splashtop", @"citrix",
                    @"jump.mac.viewer", @"jumpdesktop", @"sunlogin", @"vmware", @"parallels", @"utmapp",
                    @"virtualbox"];
    });
    NSString *lowercase = identifier.lowercaseString;
    for (NSString *vendor in vendors) {
        if ([lowercase containsString:vendor]) {
            return YES;
        }
    }
    return NO;
}

+(NSArray*)getTableCodes {
    return [[NSArray alloc] initWithObjects:
            @"Unicode",
            @"TCVN3 (ABC)",
            @"VNI Windows",
            @"Unicode tổ hợp",
            @"Vietnamese Locale CP 1258", nil];
}

+(NSString*)getBuildDate {
    return [NSString stringWithUTF8String:__DATE__];
}

#pragma mark -Convert feature
+(BOOL)quickConvert {
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    NSString *htmlString = [pasteboard stringForType:NSPasteboardTypeHTML];
    NSString *rawString = [pasteboard stringForType:NSPasteboardTypeString];
    bool converted = false;
    if (htmlString != nil) {
        htmlString = ConvertUtil(htmlString);
        converted = true;
    }
    if (rawString != nil) {
        rawString = ConvertUtil(rawString);
        converted = true;
    }
    if (converted) {
        [pasteboard clearContents];
        if (htmlString != nil)
            [pasteboard setString:htmlString forType:NSPasteboardTypeHTML];
        if (rawString != nil)
            [pasteboard setString:rawString forType:NSPasteboardTypeString];
        
        return YES;
    }
    return NO;
}

+(void)showMessage:(NSWindow*)window message:(NSString*)msg subMsg:(NSString*)subMsg {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:msg];
    [alert setInformativeText:subMsg];
    [alert addButtonWithTitle:@"OK"];
    if (window) {
        [alert beginSheetModalForWindow:window completionHandler:^(NSModalResponse returnCode) {
        }];
    } else {
        [alert runModal];
    }
}

#pragma mark -AutoUpdate feature

static NSString * const OpenKeyReleasesAPI = @"https://api.github.com/repos/ducvd89/OpenKey/releases?per_page=20";
static NSString * const OpenKeyReleasesPage = @"https://github.com/ducvd89/OpenKey/releases";

// Pulls "2.0.4" out of tags such as "macos-2.0.4-app-profiles" or "v2.0.4".
static NSString *versionInText(NSString *text) {
    if (!text.length) {
        return nil;
    }
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\d+(\\.\\d+)+" options:0 error:nil];
    NSTextCheckingResult *match = [regex firstMatchInString:text options:0 range:NSMakeRange(0, text.length)];
    return match ? [text substringWithRange:match.range] : nil;
}

// Newest published macOS release, falling back to any release when none is tagged for macOS.
static NSDictionary *latestMacRelease(NSArray *releases) {
    NSDictionary *fallback = nil;
    for (NSDictionary *release in releases) {
        if (![release isKindOfClass:[NSDictionary class]] || [release[@"draft"] boolValue] || [release[@"prerelease"] boolValue]) {
            continue;
        }
        NSString *tag = [release[@"tag_name"] isKindOfClass:[NSString class]] ? release[@"tag_name"] : @"";
        NSString *name = [release[@"name"] isKindOfClass:[NSString class]] ? release[@"name"] : @"";
        if (!versionInText(tag) && !versionInText(name)) {
            continue;
        }
        NSString *label = [[tag stringByAppendingString:name] lowercaseString];
        if ([label containsString:@"macos"] || [label containsString:@"mac-"]) {
            return release;
        }
        if (!fallback) {
            fallback = release;
        }
    }
    return fallback;
}

+(void)checkNewVersion:(NSWindow*)parent callbackFunc:(CheckNewVersionCallback) callback {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:OpenKeyReleasesAPI]];
    [request setValue:@"application/vnd.github+json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"OpenKey-macOS" forHTTPHeaderField:@"User-Agent"];
    request.timeoutInterval = 15;

    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSDictionary *release = nil;
        if (!error && ((NSHTTPURLResponse *)response).statusCode == 200 && data) {
            id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if ([object isKindOfClass:[NSArray class]]) {
                release = latestMacRelease(object);
            }
        }
        NSString *latest = versionInText(release[@"tag_name"]) ?: versionInText(release[@"name"]);
        NSString *current = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
        BOOL needUpdating = latest && [latest compare:current options:NSNumericSearch] == NSOrderedDescending;
        NSString *page = [release[@"html_url"] isKindOfClass:[NSString class]] ? release[@"html_url"] : OpenKeyReleasesPage;

        dispatch_async(dispatch_get_main_queue(), ^{
            if (callback != nil) {
                callback();
            }
            if (!latest) {
                // Only bother the user about failures they asked for.
                if (callback != nil) {
                    [self showMessage:parent message:@"Không kiểm tra được bản mới"
                               subMsg:@"Hãy kiểm tra kết nối mạng rồi thử lại."];
                }
                return;
            }
            if (needUpdating || callback != nil) {
                [self showUpdateMessage:parent needUpdating:needUpdating newVersion:latest releasePage:page];
            }
        });
    }] resume];
}

+(void)showUpdateMessage:(NSWindow*)parent needUpdating:(BOOL)needUpdating newVersion:(NSString*)versionString releasePage:(NSString *)page {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:(needUpdating ? [NSString stringWithFormat:@"OpenKey có phiên bản mới (%@)", versionString] : @"Bạn đang dùng phiên bản mới nhất!")];
    [alert setInformativeText:(needUpdating ? @"Mở trang phát hành trên GitHub để tải bản mới?" : @"")];

    if (!needUpdating) {
        [alert addButtonWithTitle:@"OK"];
    } else {
        [alert addButtonWithTitle:@"Tải về"];
        [alert addButtonWithTitle:@"Để sau"];
    }
    void (^handle)(NSModalResponse) = ^(NSModalResponse returnCode) {
        if (returnCode == NSAlertFirstButtonReturn && needUpdating) {
            [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:page]];
        }
    };
    if (parent == nil) {
        [alert.window makeKeyAndOrderFront:nil];
        [alert.window setLevel:NSStatusWindowLevel];
        handle([alert runModal]);
    } else {
        [alert beginSheetModalForWindow:parent completionHandler:handle];
    }
}
@end
