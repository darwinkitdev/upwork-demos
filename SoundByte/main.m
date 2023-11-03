//
//  main.m
//  SoundByte
//
//  Created by Eric Maciel on 01/11/23.
//

#import <Cocoa/Cocoa.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@implementation NSString (Truncate)

- (NSString *)stringByTruncatingMaxLength:(NSUInteger)maxLength {
    return self.length > maxLength ? [[self substringToIndex:maxLength] stringByAppendingString:@"…"] : self;
}

@end

@interface SoundByte : NSObject <NSMenuDelegate>
@property (strong) NSOpenPanel *panel;
@property (strong) NSURL *selectedFolderURL;
@property (strong) NSString *selectedFolderTitle;
@property (strong) NSString *selectedFolderPath;
@property (strong) NSSound *currentSound;
@end

@implementation SoundByte

- (void)setFolderURL:(NSURL *)folderURL {
    NSURL *homeURL = [NSFileManager.defaultManager homeDirectoryForCurrentUser];
    NSString *relativePath = [folderURL.path stringByDeletingLastPathComponent];
    NSString *folder = folderURL.lastPathComponent;
    
    if ([relativePath hasPrefix:homeURL.path]) {
        relativePath = [relativePath substringFromIndex:homeURL.path.length];
    }
    
    while (folder.length < 30 && relativePath.length > 0 && ![relativePath isEqualToString:@"/"]) {
        folder = [NSString stringWithFormat:@"%@/%@", relativePath.lastPathComponent, folder];
        relativePath = [relativePath stringByDeletingLastPathComponent];
    }
    
    self.selectedFolderURL = folderURL;
    self.selectedFolderTitle = folder;
    
    if ([folderURL isNotEqualTo:homeURL] && [folderURL.path hasPrefix:homeURL.path]) {
        self.selectedFolderPath = [folderURL.path substringFromIndex:homeURL.path.length + 1];
    } else {
        self.selectedFolderPath = folderURL.path;
    }
}

- (void)chooseSourceFolder:(NSMenuItem *)sender {
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

- (void)playSound:(NSMenuItem *)sender {
    if (self.currentSound && self.currentSound.isPlaying) {
        [self.currentSound stop];
    }
    NSURL *audioURL = sender.representedObject;
    self.currentSound = [[NSSound alloc] initWithContentsOfURL:audioURL byReference:NO];
    [self.currentSound play];
}

- (void)addFolderContentsAt:(NSURL *)folderURL to:(NSMenu *)menu {
    NSArray *contents = [NSFileManager.defaultManager contentsOfDirectoryAtURL:folderURL
                                                    includingPropertiesForKeys:@[NSURLContentTypeKey]
                                                                       options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                         error:nil];
    for (NSURL *url in contents) {
        NSDictionary *resources = [url resourceValuesForKeys:@[NSURLContentTypeKey] error:nil];
        UTType *contentType = resources[NSURLContentTypeKey];
        if ([contentType conformsToType:UTTypeAudio]) {
            NSString *filename = [url.lastPathComponent stringByDeletingPathExtension];
            NSMenuItem *item = [menu insertItemWithTitle:[filename stringByTruncatingMaxLength:30]
                                                  action:@selector(playSound:)
                                           keyEquivalent:@""
                                                 atIndex:1];
            item.representedObject = url;
            item.target = self;
        }
    }
}

- (void)menuNeedsUpdate:(NSMenu *)menu {
    // Preserve the "Choose source folder..." and "Quit" items and remove the rest.
    NSArray *menuItems = [menu.itemArray subarrayWithRange:NSMakeRange(0, menu.numberOfItems - 2)];
    for (NSMenuItem *item in menuItems) {
        [menu removeItem:item];
    }
    
    if (self.selectedFolderURL) {
        [menu insertItem:[NSMenuItem separatorItem] atIndex:0];
        NSMenuItem *folderItem = [menu insertItemWithTitle:self.selectedFolderTitle
                                                    action:nil
                                             keyEquivalent:@""
                                                   atIndex:0];
        folderItem.toolTip = self.selectedFolderPath;
        [self addFolderContentsAt:self.selectedFolderURL to:menu];
    }
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSApplication *app = NSApplication.sharedApplication;
        app.activationPolicy = NSApplicationActivationPolicyAccessory;
        
        SoundByte *soundByte = [SoundByte new];
        
        NSStatusItem *statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSSquareStatusItemLength];
        statusItem.button.image = [NSImage imageWithSystemSymbolName:@"music.quarternote.3"
                                            accessibilityDescription:nil];
        statusItem.menu = [NSMenu new];
        statusItem.menu.delegate = soundByte;
        
        [statusItem.menu addItemWithTitle:@"Choose source folder..."
                                   action:@selector(chooseSourceFolder:)
                            keyEquivalent:@""].target = soundByte;
        [statusItem.menu addItemWithTitle:@"Quit"
                                   action:@selector(terminate:)
                            keyEquivalent:@"q"];
        
        [app run];
    }
    return EXIT_SUCCESS;
}
