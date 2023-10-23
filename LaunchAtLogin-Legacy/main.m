//
//  main.m
//  LaunchAtLogin-Legacy
//
//  Created by Eric Maciel on 23/10/23.
//

#import <Cocoa/Cocoa.h>
#import <ServiceManagement/ServiceManagement.h>

@interface LaunchAtLogin : NSObject <NSMenuDelegate>
@end

@implementation LaunchAtLogin

// MARK: - Launch at login methods

static NSString *launcherBundleId = @"com.demos.LaunchAtLogin-Legacy-Launcher";

- (void)toggleLaunchAtLogin:(NSMenuItem *)sender {
    BOOL isEnabled = ![self isLaunchAtLoginEnabled];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    SMLoginItemSetEnabled((__bridge CFStringRef)launcherBundleId, isEnabled);
#pragma clang diagnostic pop
}

- (BOOL)isLaunchAtLoginEnabled {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    // Apple deprecated this function in version 10.10 and didn't provide an alternative,
    // so the only option is to use it anyway and silence the deprecation warning.
    NSArray *jobsDict = (__bridge NSArray *)(SMCopyAllJobDictionaries(kSMDomainUserLaunchd));
#pragma clang diagnostic pop
    for (NSDictionary *job in jobsDict) {
        if ([job[@"Label"] isEqualToString:launcherBundleId]) {
            return ((NSNumber *)job[@"OnDemand"]).boolValue;
        }
    }
    return NO;
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
        statusItem.button.title = @"🚀";
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
