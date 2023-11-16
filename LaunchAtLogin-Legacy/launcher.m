//
//  main.m
//  Launcher
//
//  Created by Eric Maciel on 23/10/23.
//

#import <Cocoa/Cocoa.h>

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSApplication *app = NSApplication.sharedApplication;
        NSString *mainAppBundleID = @"com.demos.LaunchAtLogin-Legacy";
        BOOL isRunning = NO;
        for (NSRunningApplication *app in NSWorkspace.sharedWorkspace.runningApplications) {
            if ([app.bundleIdentifier isEqualToString:mainAppBundleID]) {
                isRunning = YES;
                break;
            }
        }
        if (!isRunning) {
            NSURL *url = NSBundle.mainBundle.bundleURL;
            url = [url URLByDeletingLastPathComponent];
            url = [url URLByDeletingLastPathComponent];
            url = [url URLByDeletingLastPathComponent];
            url = [url URLByDeletingLastPathComponent];
            [NSWorkspace.sharedWorkspace openApplicationAtURL:url
                                                configuration:[NSWorkspaceOpenConfiguration configuration]
                                            completionHandler:^(NSRunningApplication * _Nullable app, NSError * _Nullable error) {
                [NSApp terminate:app];
            }];
        }
        [app run];
    }
    return EXIT_SUCCESS;
}
