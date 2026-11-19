#import "AppProfilesWindowController.h"
#import "AppDelegate.h"

static NSString * const AppColumn = @"app";
static NSString * const LanguageColumn = @"language";

@interface AppProfilesWindowController () <NSTableViewDataSource, NSTableViewDelegate, NSMenuDelegate>
@end

@implementation AppProfilesWindowController {
    NSMutableDictionary<NSString *, NSDictionary *> *_profiles;
    NSArray<NSString *> *_identifiers;
    NSTableView *_table;
    NSButton *_removeButton;
    NSTextField *_emptyLabel;
    NSTextField *_statusLabel;
}

- (instancetype)init {
    NSRect frame = NSMakeRect(0, 0, 600, 360);
    NSUInteger style = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                       NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable;
    NSWindow *window = [[NSWindow alloc] initWithContentRect:frame styleMask:style
                                                   backing:NSBackingStoreBuffered defer:NO];
    self = [super initWithWindow:window];
    if (self) {
        [self configureWindow];
    }
    return self;
}

- (void)configureWindow {
    NSWindow *window = self.window;
    window.title = @"Chế độ gõ theo ứng dụng";
    window.contentMinSize = NSMakeSize(480, 240);
    window.level = NSFloatingWindowLevel;

    NSView *content = window.contentView;
    NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:content.bounds];
    scroll.borderType = NSBezelBorder;
    scroll.hasVerticalScroller = YES;
    scroll.autohidesScrollers = YES;

    _table = [[NSTableView alloc] initWithFrame:scroll.contentView.bounds];
    _table.rowHeight = 30;
    _table.usesAlternatingRowBackgroundColors = YES;
    _table.columnAutoresizingStyle = NSTableViewFirstColumnOnlyAutoresizingStyle;
    _table.dataSource = self;
    _table.delegate = self;

    NSTableColumn *appColumn = [[NSTableColumn alloc] initWithIdentifier:AppColumn];
    appColumn.title = @"Ứng dụng";
    appColumn.minWidth = 230;
    appColumn.width = 400;
    [_table addTableColumn:appColumn];

    NSTableColumn *languageColumn = [[NSTableColumn alloc] initWithIdentifier:LanguageColumn];
    languageColumn.title = @"Chế độ gõ";
    languageColumn.width = 150;
    languageColumn.resizingMask = NSTableColumnNoResizing;
    [_table addTableColumn:languageColumn];
    scroll.documentView = _table;

    NSPopUpButton *addButton = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:YES];
    [addButton addItemWithTitle:@"Thêm ứng dụng…"];
    addButton.menu.delegate = self;
    [addButton setAccessibilityLabel:@"Thêm ứng dụng"];
    _removeButton = [NSButton buttonWithTitle:@"Xóa quy tắc" target:self action:@selector(removeProfile:)];

    _emptyLabel = [NSTextField labelWithString:@"Chưa có quy tắc. Chọn Thêm ứng dụng để tạo quy tắc đầu tiên."];
    _emptyLabel.textColor = NSColor.secondaryLabelColor;
    _statusLabel = [NSTextField labelWithString:@""];
    _statusLabel.textColor = NSColor.secondaryLabelColor;
    [_statusLabel setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow
                                           forOrientation:NSLayoutConstraintOrientationHorizontal];

    for (NSView *view in @[scroll, _emptyLabel, addButton, _removeButton, _statusLabel]) {
        view.translatesAutoresizingMaskIntoConstraints = NO;
        [content addSubview:view];
    }
    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor constraintEqualToAnchor:content.topAnchor constant:16],
        [scroll.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:16],
        [scroll.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-16],
        [scroll.bottomAnchor constraintEqualToAnchor:addButton.topAnchor constant:-12],
        [_emptyLabel.centerXAnchor constraintEqualToAnchor:scroll.centerXAnchor],
        [_emptyLabel.centerYAnchor constraintEqualToAnchor:scroll.centerYAnchor],
        [addButton.leadingAnchor constraintEqualToAnchor:scroll.leadingAnchor],
        [addButton.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-16],
        [_removeButton.leadingAnchor constraintEqualToAnchor:addButton.trailingAnchor constant:8],
        [_removeButton.centerYAnchor constraintEqualToAnchor:addButton.centerYAnchor],
        [_statusLabel.leadingAnchor constraintEqualToAnchor:_removeButton.trailingAnchor constant:12],
        [_statusLabel.trailingAnchor constraintLessThanOrEqualToAnchor:scroll.trailingAnchor],
        [_statusLabel.centerYAnchor constraintEqualToAnchor:addButton.centerYAnchor]
    ]];

    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    _profiles = [[prefs dictionaryForKey:OpenKeyAppProfilesKey] mutableCopy] ?: [NSMutableDictionary dictionary];
    [self reloadTableSelecting:nil];
    window.initialFirstResponder = _table;
    [window center];
}

- (void)showWindow:(id)sender {
    [super showWindow:sender];
    if (@available(macOS 14.0, *)) {
        [NSApp activate];
    } else {
        [NSApp activateIgnoringOtherApps:YES];
    }
    [self.window makeKeyAndOrderFront:sender];
}

- (void)reloadTableSelecting:(NSString *)identifier {
    _identifiers = [_profiles.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *left, NSString *right) {
        NSString *leftName = self->_profiles[left][@"name"] ?: left;
        NSString *rightName = self->_profiles[right][@"name"] ?: right;
        NSComparisonResult order = [leftName localizedStandardCompare:rightName];
        return order == NSOrderedSame ? [left compare:right] : order;
    }];
    [_table reloadData];
    [_table deselectAll:self];
    NSUInteger row = identifier ? [_identifiers indexOfObject:identifier] : NSNotFound;
    if (row != NSNotFound) {
        [_table selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
        [_table scrollRowToVisible:row];
    }
    _emptyLabel.hidden = _identifiers.count > 0;
    _removeButton.enabled = _table.selectedRow >= 0;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return _identifiers.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)column row:(NSInteger)row {
    NSString *identifier = _identifiers[row];
    NSDictionary *profile = _profiles[identifier];
    NSString *name = profile[@"name"] ?: identifier;
    NSView *cell = [[NSView alloc] initWithFrame:NSZeroRect];
    NSView *control;
    if ([column.identifier isEqualToString:AppColumn]) {
        NSTextField *label = [NSTextField labelWithString:name];
        label.lineBreakMode = NSLineBreakByTruncatingTail;
        label.toolTip = identifier;
        control = label;
    } else {
        NSPopUpButton *language = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
        [language addItemsWithTitles:@[@"Tiếng Anh", @"Tiếng Việt"]];
        [language selectItemAtIndex:[profile[@"language"] boolValue]];
        language.target = self;
        language.action = @selector(changeLanguage:);
        [language setAccessibilityLabel:[NSString stringWithFormat:@"Chế độ gõ của %@", name]];
        control = language;
    }
    control.translatesAutoresizingMaskIntoConstraints = NO;
    [cell addSubview:control];
    [NSLayoutConstraint activateConstraints:@[
        [control.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor constant:6],
        [control.trailingAnchor constraintEqualToAnchor:cell.trailingAnchor constant:-6],
        [control.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor]
    ]];
    return cell;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    _removeButton.enabled = _table.selectedRow >= 0;
}

- (void)menuNeedsUpdate:(NSMenu *)menu {
    while (menu.numberOfItems > 1) {
        [menu removeItemAtIndex:1];
    }
    NSMenuItem *browse = [menu addItemWithTitle:@"Duyệt ứng dụng…" action:@selector(browseForApp:) keyEquivalent:@""];
    browse.target = self;

    NSMutableDictionary<NSString *, NSString *> *names = [NSMutableDictionary dictionary];
    for (NSRunningApplication *app in [NSWorkspace sharedWorkspace].runningApplications) {
        NSString *identifier = app.bundleIdentifier;
        if (app.activationPolicy == NSApplicationActivationPolicyRegular && identifier.length &&
            ![identifier isEqualToString:OPENKEY_BUNDLE] && !_profiles[identifier]) {
            names[identifier] = app.localizedName ?: identifier;
        }
    }
    if (names.count > 0) {
        [menu addItem:[NSMenuItem separatorItem]];
        NSMenuItem *heading = [menu addItemWithTitle:@"Ứng dụng đang chạy" action:nil keyEquivalent:@""];
        heading.enabled = NO;
    }
    for (NSString *identifier in [names keysSortedByValueUsingSelector:@selector(localizedStandardCompare:)]) {
        NSMenuItem *item = [menu addItemWithTitle:names[identifier] action:@selector(addRunningApp:) keyEquivalent:@""];
        item.target = self;
        item.representedObject = identifier;
        item.toolTip = identifier;
    }
}

- (void)addRunningApp:(NSMenuItem *)item {
    [self addAppWithIdentifier:item.representedObject name:item.title];
}

- (void)browseForApp:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.directoryURL = [NSURL fileURLWithPath:@"/Applications" isDirectory:YES];
    panel.allowedFileTypes = @[@"app"];
    panel.prompt = @"Thêm";
    [panel beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse response) {
        if (response != NSModalResponseOK) {
            return;
        }
        NSBundle *bundle = [NSBundle bundleWithURL:panel.URL];
        NSString *name = [bundle objectForInfoDictionaryKey:@"CFBundleDisplayName"] ?:
                         [bundle objectForInfoDictionaryKey:@"CFBundleName"] ?:
                         panel.URL.lastPathComponent.stringByDeletingPathExtension;
        [self addAppWithIdentifier:bundle.bundleIdentifier name:name];
    }];
}

- (void)addAppWithIdentifier:(NSString *)identifier name:(NSString *)name {
    if (!identifier.length || [identifier isEqualToString:OPENKEY_BUNDLE]) {
        _statusLabel.stringValue = @"Hãy chọn một ứng dụng macOS khác.";
        return;
    }
    _statusLabel.stringValue = @"";
    if (!_profiles[identifier]) {
        BOOL language = [[NSUserDefaults standardUserDefaults] boolForKey:@"InputMethod"];
        _profiles[identifier] = @{@"name": name ?: identifier, @"language": @(language)};
        [self saveProfiles];
    }
    [self reloadTableSelecting:identifier];
}

- (void)changeLanguage:(NSPopUpButton *)sender {
    NSInteger row = [_table rowForView:sender];
    if (row < 0 || row >= (NSInteger)_identifiers.count) {
        return;
    }
    NSString *identifier = _identifiers[row];
    NSMutableDictionary *profile = [_profiles[identifier] mutableCopy];
    profile[@"language"] = @(sender.indexOfSelectedItem == 1);
    _profiles[identifier] = profile;
    _statusLabel.stringValue = @"";
    [self saveProfiles];
}

- (void)removeProfile:(id)sender {
    NSInteger row = _table.selectedRow;
    if (row < 0) {
        return;
    }
    [_profiles removeObjectForKey:_identifiers[row]];
    NSUInteger nextRow = row + 1 < (NSInteger)_identifiers.count ? row + 1 : MAX(0, row - 1);
    NSString *next = _identifiers.count > 1 ? _identifiers[nextRow] : nil;
    _statusLabel.stringValue = @"";
    [self saveProfiles];
    [self reloadTableSelecting:next];
}

- (void)saveProfiles {
    [[NSUserDefaults standardUserDefaults] setObject:_profiles forKey:OpenKeyAppProfilesKey];
    [(AppDelegate *)NSApp.delegate refreshActiveApp];
}

@end
