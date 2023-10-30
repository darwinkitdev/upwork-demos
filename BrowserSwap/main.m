//
//  main.m
//  BrowserSwap
//
//  Created by Eric Maciel on 26/10/23.
//

#import <Cocoa/Cocoa.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface Browser : NSObject
@property (strong) NSString *name;
@property (strong) NSURL *url;
@property (strong) NSImage *icon;
@end

@implementation Browser

+ (instancetype)browserWithURL:(NSURL * _Nonnull)browserURL {
    NSBundle *bundle = [NSBundle bundleWithURL:browserURL];
    NSString *displayName = [bundle objectForInfoDictionaryKey:@"CFBundleDisplayName"];
    if (!displayName) {
        displayName = [bundle objectForInfoDictionaryKey:(NSString *)kCFBundleNameKey];
    }
    if (!displayName) {
        return nil;
    }
    NSImage *icon = [NSWorkspace.sharedWorkspace iconForFile:browserURL.path];
    icon.size = NSMakeSize(24, 24);
    Browser *browser = [[Browser alloc] init];
    browser.name = displayName;
    browser.url = browserURL;
    browser.icon = icon;
    return browser;
}

@end

@interface BrowserSwap : NSObject <NSMenuDelegate>
@end

@implementation BrowserSwap

- (NSURL *)defaultBrowserURL {
    return [NSWorkspace.sharedWorkspace URLForApplicationToOpenURL:[NSURL URLWithString:@"https:"]];
}

- (NSArray *)allBrowsersURLs {
    NSURL *schemeURL = [NSURL URLWithString:@"https:"];
    NSArray *compatibleHTMLAppsURLs;
    NSArray *compatibleHTTPSAppsURLs;
    if (@available(macOS 12.0, *)) {
        compatibleHTMLAppsURLs = [NSWorkspace.sharedWorkspace URLsForApplicationsToOpenContentType:UTTypeHTML];
        compatibleHTTPSAppsURLs = [NSWorkspace.sharedWorkspace URLsForApplicationsToOpenURL:schemeURL];
    } else {
        NSArray *compatibleHTMLAppsIds = CFBridgingRelease(LSCopyAllRoleHandlersForContentType(kUTTypeHTML, kLSRolesViewer));
        NSMutableArray *_compatibleHTMLAppsURLs = [NSMutableArray array];
        for (NSString *bundleId in compatibleHTMLAppsIds) {
            NSURL *appURL = [NSWorkspace.sharedWorkspace URLForApplicationWithBundleIdentifier:bundleId];
            [_compatibleHTMLAppsURLs addObject:appURL];
        }
        compatibleHTMLAppsURLs = _compatibleHTMLAppsURLs;
        compatibleHTTPSAppsURLs = CFBridgingRelease(LSCopyApplicationURLsForURL((__bridge CFURLRef)schemeURL, kLSRolesViewer));
    }
    NSMutableSet *browsersURLs = [NSMutableSet setWithArray:compatibleHTTPSAppsURLs];
    [browsersURLs intersectSet:[NSSet setWithArray:compatibleHTMLAppsURLs]];
    return [browsersURLs allObjects];
}

- (NSArray *)allBrowsers {
    NSMutableArray *browsers = [NSMutableArray array];
    for (NSURL *browserURL in [self allBrowsersURLs]) {
        Browser *browser = [Browser browserWithURL:browserURL];
        if (browser) {
            [browsers addObject:browser];
        }
    }
    [browsers sortUsingComparator:^NSComparisonResult(Browser *obj1, Browser *obj2) {
        return [obj1.name compare:obj2.name];
    }];
    return browsers;
}

- (void)openDefaultBrowser:(NSMenuItem *)sender {
    NSWorkspaceOpenConfiguration *config = [NSWorkspaceOpenConfiguration configuration];
    [NSWorkspace.sharedWorkspace openApplicationAtURL:[self defaultBrowserURL]
                                        configuration:config
                                    completionHandler:nil];
}

- (void)setDefaultBrowser:(NSMenuItem *)sender {
    NSURL *browserURL = sender.representedObject;
    if (@available(macOS 12.0, *)) {
        [NSWorkspace.sharedWorkspace setDefaultApplicationAtURL:browserURL
                                           toOpenURLsWithScheme:@"http"
                                              completionHandler:nil];
    } else {
        NSString *bundleId = [NSBundle bundleWithURL:browserURL].bundleIdentifier;
        LSSetDefaultHandlerForURLScheme(CFSTR("http"), (__bridge CFStringRef)bundleId);
    }
}

- (void)menuNeedsUpdate:(NSMenu *)menu {
    // Preserve the first item (section header), the separator and the last two items,
    // and remove the other items, related to the browsers.
    NSArray *menuItems = [menu.itemArray subarrayWithRange:NSMakeRange(1, menu.numberOfItems - 4)];
    for (NSMenuItem *item in menuItems) {
        [menu removeItem:item];
    }
    
    NSURL *defaultBrowserURL = [self defaultBrowserURL];
    for (Browser *browser in [self allBrowsers]) {
        NSMenuItem *item = [menu insertItemWithTitle:browser.name
                                              action:@selector(setDefaultBrowser:)
                                       keyEquivalent:@""
                                             atIndex:menu.numberOfItems - 3];
        item.representedObject = browser.url;
        item.image = browser.icon;
        item.target = self;
        [item setState:[browser.url isEqualTo:defaultBrowserURL] ? NSControlStateValueOn : NSControlStateValueOff];
    }
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSApplication *app = NSApplication.sharedApplication;
        app.activationPolicy = NSApplicationActivationPolicyAccessory;
        
        BrowserSwap *browserSwap = [BrowserSwap new];
        
        NSStatusItem *statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSSquareStatusItemLength];
        statusItem.button.image = [NSImage imageWithSystemSymbolName:@"globe"
                                            accessibilityDescription:nil];
        statusItem.menu = [NSMenu new];
        statusItem.menu.delegate = browserSwap;
        
        [statusItem.menu addItemWithTitle:@"Set default browser"
                                   action:nil
                            keyEquivalent:@""];
        [statusItem.menu addItem:[NSMenuItem separatorItem]];
        [statusItem.menu addItemWithTitle:@"Open Default Browser"
                                   action:@selector(openDefaultBrowser:)
                            keyEquivalent:@""].target = browserSwap;
        [statusItem.menu addItemWithTitle:@"Quit"
                                   action:@selector(terminate:)
                            keyEquivalent:@"q"].target = app;
        
        [app run];
    }
    return EXIT_SUCCESS;
}
