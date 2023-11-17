//
//  main.m
//  LaunchAtLogin-Modern
//
//  Created by Eric Maciel on 23/10/23.
//

#import <Cocoa/Cocoa.h>
#import <ServiceManagement/SMAppService.h>

@interface LaunchAtLogin : NSObject <NSMenuDelegate>
@end

@implementation LaunchAtLogin

// MARK: - Launch at login methods

- (void)toggleLaunchAtLogin:(NSMenuItem *)sender {
    if (SMAppService.mainAppService.status == SMAppServiceStatusEnabled) {
        [SMAppService.mainAppService unregisterAndReturnError:nil];
    } else {
        [SMAppService.mainAppService registerAndReturnError:nil];
    }
}

- (BOOL)isLaunchAtLoginEnabled {
    return SMAppService.mainAppService.status == SMAppServiceStatusEnabled;
}

// MARK: - Menu delegate

- (void)menuNeedsUpdate:(NSMenu *)menu {
    NSMenuItem *item = menu.itemArray.firstObject;
    [item setState:[self isLaunchAtLoginEnabled] ? NSControlStateValueOn : NSControlStateValueOff];
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSApplication *app = NSApplication.sharedApplication;
        app.activationPolicy = NSApplicationActivationPolicyAccessory;
        
        LaunchAtLogin *launchAtLogin = [LaunchAtLogin new];
        
        NSStatusItem *statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
        statusItem.button.title = @"Modern";
        statusItem.menu = [NSMenu new];
        statusItem.menu.delegate = launchAtLogin;
        
        [statusItem.menu addItemWithTitle:@"Launch at Login"
                                   action:@selector(toggleLaunchAtLogin:)
                            keyEquivalent:@""].target = launchAtLogin;
        [statusItem.menu addItemWithTitle:@"Quit"
                                   action:@selector(terminate:)
                            keyEquivalent:@"q"].target = app;
        
        [app run];
    }
    return EXIT_SUCCESS;
}
