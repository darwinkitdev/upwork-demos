//
//  main.m
//  Launcher
//
//  Created by Eric Maciel on 10/10/23.
//

#import <Cocoa/Cocoa.h>

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSString *mainAppBundleID = @"com.demos.AudioSnap";
        BOOL isRunning = NO;
        for (NSRunningApplication *app in NSWorkspace.sharedWorkspace.runningApplications) {
            if ([app.bundleIdentifier isEqualToString:mainAppBundleID]) {
                isRunning = YES;
                break;
            }
        }
        if (!isRunning) {
            NSString *path = NSBundle.mainBundle.bundlePath;
            path = [path stringByDeletingLastPathComponent];
            path = [path stringByDeletingLastPathComponent];
            path = [path stringByDeletingLastPathComponent];
            path = [path stringByDeletingLastPathComponent];
            NSURL *appURL = [NSURL URLWithString:path];
            [NSWorkspace.sharedWorkspace openApplicationAtURL:appURL
                                                configuration:[NSWorkspaceOpenConfiguration new]
                                            completionHandler:nil];
        }
    }
    return EXIT_SUCCESS;
}
