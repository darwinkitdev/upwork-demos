//
//  main.m
//  FolderScout
//
//  Created by Eric Maciel on 31/10/23.
//

#import <Cocoa/Cocoa.h>

@implementation NSString (Truncate)

- (NSString *)stringByTruncatingMaxLength:(NSUInteger)maxLength leader:(NSString *)leader {
    if (!leader) {
        leader = @"…";
    }
    maxLength -= leader.length;
    return self.length > maxLength ? [[self substringToIndex:maxLength] stringByAppendingString:leader] : self;
}

@end

@interface FolderScout : NSObject <NSMenuDelegate>
@property (strong) NSOpenPanel *panel;
@property (strong) NSURL *selectedFolderURL;
@property (strong) NSString *selectedFolderTitle;
@end

@implementation FolderScout

- (void)setFolderURL:(NSURL *)folderURL {
    NSString *folder = folderURL.lastPathComponent;
    NSURL *url = [folderURL URLByDeletingLastPathComponent];
    
    while (folder.length < 30 && ![url.path isEqualToString:@"/"]) {
        folder = [NSString stringWithFormat:@"%@/%@", url.lastPathComponent, folder];
        url = [url URLByDeletingLastPathComponent];
    }
    
    self.selectedFolderURL = folderURL;
    self.selectedFolderTitle = folder;
}

- (void)chooseFolder:(NSMenuItem *)sender {
    if (!self.panel) {
        self.panel = [NSOpenPanel openPanel];
        self.panel.allowsMultipleSelection = NO;
        self.panel.canChooseFiles = NO;
        self.panel.canChooseDirectories = YES;
        self.panel.canCreateDirectories = YES;
        [self.panel beginWithCompletionHandler:^(NSModalResponse result) {
            if (result == NSModalResponseOK) {
                [self setFolderURL:self.panel.URL];
            }
            self.panel = nil;
        }];
    }
    [self.panel makeKeyAndOrderFront:sender];
    [NSApplication.sharedApplication activateIgnoringOtherApps:YES];
}

- (void)openURL:(NSMenuItem *)sender {
    [NSWorkspace.sharedWorkspace openURL:sender.representedObject];
}

- (void)addFolderContentsAt:(NSURL *)folderURL to:(NSMenu *)menu {
    NSArray *contents = [NSFileManager.defaultManager contentsOfDirectoryAtURL:folderURL
                                                    includingPropertiesForKeys:nil
                                                                       options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                         error:nil];
    contents = [contents sortedArrayUsingComparator:^NSComparisonResult(NSURL *url1, NSURL *url2) {
        return [url1.lastPathComponent localizedStandardCompare:url2.lastPathComponent];
    }];
    contents = [contents sortedArrayUsingComparator:^NSComparisonResult(NSURL *url1, NSURL *url2) {
        if (url1.hasDirectoryPath == url2.hasDirectoryPath) {
            return NSOrderedSame;
        }
        if (url1.hasDirectoryPath) {
            return NSOrderedAscending;
        }
        return NSOrderedDescending;
    }];
    
    for (NSURL *url in contents) {
        NSString *extension = [NSString stringWithFormat:@"….%@", url.pathExtension];
        NSMenuItem *item = [menu addItemWithTitle:[url.lastPathComponent stringByTruncatingMaxLength:30 leader:extension]
                                           action:@selector(openURL:)
                                    keyEquivalent:@""];
        item.representedObject = url;
        item.image = [NSWorkspace.sharedWorkspace iconForFile:url.path];
        item.image.size = NSMakeSize(16, 16);
        item.target = self;
        
        if (url.hasDirectoryPath) {
            item.submenu = [NSMenu new];
            item.submenu.delegate = self;
        }
    }
}

- (void)menuNeedsUpdate:(NSMenu *)menu {
    
    // List subfolder contents
    if (menu.supermenu) {
        NSURL *subfolderURL = menu.supermenu.highlightedItem.representedObject;
        [self addFolderContentsAt:subfolderURL to:menu];
        return;
    }
    
    // Preserve the "Choose folder..." and "Quit" items and remove the rest.
    NSArray *menuItems = [menu.itemArray subarrayWithRange:NSMakeRange(2, menu.numberOfItems - 2)];
    for (NSMenuItem *item in menuItems) {
        [menu removeItem:item];
    }
    
    // List selected/main folder contents
    if (self.selectedFolderURL) {
        [menu addItem:[NSMenuItem separatorItem]];
        [menu addItemWithTitle:self.selectedFolderTitle
                        action:nil
                 keyEquivalent:@""];
        [self addFolderContentsAt:self.selectedFolderURL to:menu];
    }
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSApplication *app = NSApplication.sharedApplication;
        app.activationPolicy = NSApplicationActivationPolicyAccessory;
        
        FolderScout *folderScout = [FolderScout new];
        
        NSStatusItem *statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSSquareStatusItemLength];
        statusItem.button.image = [NSImage imageWithSystemSymbolName:@"folder"
                                            accessibilityDescription:nil];
        statusItem.menu = [NSMenu new];
        statusItem.menu.delegate = folderScout;
        
        [statusItem.menu addItemWithTitle:@"Choose folder..."
                                   action:@selector(chooseFolder:)
                            keyEquivalent:@""].target = folderScout;
        [statusItem.menu addItemWithTitle:@"Quit"
                                   action:@selector(terminate:)
                            keyEquivalent:@"q"];
        
        [app run];
    }
    return EXIT_SUCCESS;
}
