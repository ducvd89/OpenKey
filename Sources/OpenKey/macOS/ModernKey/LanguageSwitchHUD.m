#import "LanguageSwitchHUD.h"
#import <QuartzCore/QuartzCore.h>

@implementation LanguageSwitchHUD {
    NSPanel *_panel;
    NSArray<NSVisualEffectView *> *_options;
    NSArray<NSTextField *> *_labels;
    NSTextField *_previewLabel;
    NSTimer *_hideTimer;
}

- (instancetype)init {
    self = [super init];
    if (!self) {
        return nil;
    }

    NSRect frame = NSMakeRect(0, 0, 288, 62);
    _panel = [[NSPanel alloc] initWithContentRect:frame
                                        styleMask:NSWindowStyleMaskBorderless | NSWindowStyleMaskNonactivatingPanel
                                          backing:NSBackingStoreBuffered defer:YES];
    _panel.opaque = NO;
    _panel.backgroundColor = NSColor.clearColor;
    _panel.hasShadow = YES;
    _panel.ignoresMouseEvents = YES;
    _panel.hidesOnDeactivate = NO;
    _panel.level = CGWindowLevelForKey(kCGOverlayWindowLevelKey);
    _panel.animationBehavior = NSWindowAnimationBehaviorNone;
    _panel.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces |
                                NSWindowCollectionBehaviorFullScreenAuxiliary |
                                NSWindowCollectionBehaviorIgnoresCycle;

    NSVisualEffectView *background = [[NSVisualEffectView alloc] initWithFrame:frame];
    background.material = NSVisualEffectMaterialHUDWindow;
    background.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    background.state = NSVisualEffectStateActive;
    background.wantsLayer = YES;
    background.layer.cornerRadius = 15;
    background.layer.masksToBounds = YES;
    _panel.contentView = background;

    NSMutableArray *options = [NSMutableArray array];
    NSMutableArray *labels = [NSMutableArray array];
    for (NSString *title in @[@"Tiếng Anh", @"Tiếng Việt"]) {
        NSRect optionFrame = NSMakeRect(8 + options.count * 138, 8, 134, 46);
        NSVisualEffectView *option = [[NSVisualEffectView alloc] initWithFrame:optionFrame];
        option.material = NSVisualEffectMaterialSelection;
        option.blendingMode = NSVisualEffectBlendingModeWithinWindow;
        option.state = NSVisualEffectStateActive;
        option.wantsLayer = YES;
        option.layer.cornerRadius = 10;
        option.layer.masksToBounds = YES;
        [background addSubview:option];
        [options addObject:option];

        NSTextField *label = [NSTextField labelWithString:title];
        label.font = [NSFont systemFontOfSize:16 weight:NSFontWeightMedium];
        label.alignment = NSTextAlignmentCenter;
        [label sizeToFit];
        label.frame = NSMakeRect(NSMinX(optionFrame), NSMidY(optionFrame) - NSHeight(label.frame) / 2,
                                 NSWidth(optionFrame), NSHeight(label.frame));
        [background addSubview:label];
        [labels addObject:label];
    }
    _options = [options copy];
    _labels = [labels copy];

    _previewLabel = [NSTextField labelWithString:@""];
    _previewLabel.font = [NSFont systemFontOfSize:16 weight:NSFontWeightMedium];
    _previewLabel.alignment = NSTextAlignmentCenter;
    _previewLabel.textColor = NSColor.labelColor;
    [background addSubview:_previewLabel];
    return self;
}

- (void)showVietnamese:(BOOL)vietnamese whileHeld:(BOOL)whileHeld {
    [_panel setContentSize:whileHeld ? NSMakeSize(150, 46) : NSMakeSize(288, 62)];
    NSUInteger selectedIndex = vietnamese ? 1 : 0;
    for (NSUInteger index = 0; index < _options.count; index++) {
        BOOL selected = index == selectedIndex;
        _options[index].hidden = whileHeld || !selected;
        _labels[index].hidden = whileHeld;
        _labels[index].textColor = selected ? NSColor.alternateSelectedControlTextColor : NSColor.labelColor;
    }
    _previewLabel.hidden = !whileHeld;
    if (whileHeld) {
        _previewLabel.stringValue = _labels[selectedIndex].stringValue;
        [_previewLabel sizeToFit];
        NSRect bounds = _panel.contentView.bounds;
        CGFloat labelHeight = NSHeight(_previewLabel.frame);
        _previewLabel.frame = NSMakeRect(0, NSMidY(bounds) - labelHeight / 2, NSWidth(bounds), labelHeight);
    }

    NSScreen *screen = NSScreen.mainScreen;
    NSPoint pointer = NSEvent.mouseLocation;
    for (NSScreen *candidate in NSScreen.screens) {
        if (NSPointInRect(pointer, candidate.frame)) {
            screen = candidate;
            break;
        }
    }
    if (!screen) {
        return;
    }
    NSRect visible = screen.visibleFrame;
    NSRect frame = _panel.frame;
    [_panel setFrameOrigin:NSMakePoint(NSMidX(visible) - NSWidth(frame) / 2,
                                       NSMinY(visible) + NSHeight(visible) * 0.25)];
    [_panel orderFrontRegardless];

    [_hideTimer invalidate];
    _hideTimer = nil;
    if (!whileHeld) {
        _hideTimer = [NSTimer timerWithTimeInterval:0.95 target:self selector:@selector(hidePanel:) userInfo:nil repeats:NO];
        [NSRunLoop.mainRunLoop addTimer:_hideTimer forMode:NSRunLoopCommonModes];
    }
}

- (void)hidePanel:(NSTimer *)timer {
    [self dismiss];
}

- (void)dismiss {
    [_hideTimer invalidate];
    _hideTimer = nil;
    [_panel orderOut:nil];
}

@end
