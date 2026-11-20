#import <Cocoa/Cocoa.h>

@interface LanguageSwitchHUD : NSObject
- (void)showVietnamese:(BOOL)vietnamese whileHeld:(BOOL)whileHeld;
- (void)dismiss;
@end
