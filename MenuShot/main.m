//
//  main.m
//  MenuShot
//
//  Created by Eric Maciel on 04/10/23.
//

#import <AudioToolbox/AudioToolbox.h>
#import <Carbon/Carbon.h>
#import <Cocoa/Cocoa.h>


// Custom NSPanel that accepts keyboard events.
// This is necessary to be able to get ESC events without the alert sound.
@interface Panel : NSPanel
@end

@implementation Panel

- (BOOL)canBecomeKeyWindow {
    return YES;
}

- (void)keyDown:(NSEvent *)event {
    // Overrding to mute sound alert
}

- (void)makeKeyAndOrderFront:(id)sender {
    [super makeKeyAndOrderFront:sender];
    // Solves the custom cursor not appearing issue
    // Waits the window appears and then reset the cursor rects
    usleep(100000);
    [self resetCursorRects];
}

@end


// Custom view that handles custom cursors
@interface CursorView : NSView
@property (strong) NSCursor *cursor;
@end

@implementation CursorView

- (BOOL)canBecomeKeyView {
    return YES;
}

- (void)resetCursorRects {
    [super resetCursorRects];
    [self addCursorRect:self.bounds cursor:self.cursor];
}

@end

// Custom view to select a region of the screen
@interface SelectionView : CursorView
@property (assign) NSPoint origin;
@property (assign) NSRect selection;
@end

@implementation SelectionView

- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    NSTrackingAreaOptions options = (NSTrackingActiveAlways | NSTrackingInVisibleRect | NSTrackingMouseMoved);
    NSTrackingArea *area = [[NSTrackingArea alloc] initWithRect:self.bounds
                                                        options:options
                                                          owner:self
                                                       userInfo:nil];
    [self addTrackingArea:area];
}

- (void)drawRect:(NSRect)dirtyRect {
    // Draw selection
    NSBezierPath *path = [NSBezierPath bezierPathWithRect:self.selection];
    [[NSColor colorWithWhite:1 alpha:0.3] setFill];
    [NSColor.whiteColor setStroke];
    [path fill];
    [path stroke];
    
    // Location label
    CGFloat screenHeight = NSScreen.mainScreen.frame.size.height;
    NSPoint location = NSEvent.mouseLocation;
    NSSize size = CGPointEqualToPoint(self.origin, CGPointZero) ? CGSizeMake(location.x, screenHeight - location.y) : self.selection.size;
    NSString *mouseX = [NSString stringWithFormat:@"%ld", lroundf(size.width)];
    NSString *mouseY = [NSString stringWithFormat:@"%ld", lroundf(size.height)];
    
    // Text position on screen
    location.x += 5;
    location.y -= 30;
    
    // Draw text
    NSShadow* shadow = [NSShadow new];
    shadow.shadowColor = NSColor.whiteColor;
    shadow.shadowOffset = NSMakeSize(1, -1);
    NSDictionary *attributes = @{
        NSForegroundColorAttributeName: NSColor.blackColor,
        NSShadowAttributeName: shadow
    };
    [mouseY drawAtPoint:location withAttributes:attributes];
    location.y += 12;
    [mouseX drawAtPoint:location withAttributes:attributes];
}

- (void)mouseDown:(NSEvent *)event {
    [super mouseDown:event];
    self.origin = event.locationInWindow;
}

-(void)mouseDragged:(NSEvent *)event {
    [super mouseDragged:event];
    self.selection = CGRectMake(fmin(self.origin.x, event.locationInWindow.x),
                                fmin(self.origin.y, event.locationInWindow.y),
                                fabs(event.locationInWindow.x - self.origin.x),
                                fabs(event.locationInWindow.y - self.origin.y));
    self.needsDisplay = YES;
}

- (void)mouseMoved:(NSEvent *)event {
    [super mouseMoved:event];
    self.needsDisplay = YES;
}

@end

@interface CaptureManager: NSObject <NSMenuDelegate>
- (void)handleHotKey:(EventHotKeyID)keyID;
@end

EventHandlerUPP hotKeyFunction;
OSStatus hotKeyHandler(EventHandlerCallRef nextHandler, EventRef event, void *userData) {
    EventHotKeyID keyID;
    GetEventParameter(event, kEventParamDirectObject, typeEventHotKeyID, NULL, sizeof(keyID), NULL, &keyID);
    CaptureManager *captureManager = (__bridge CaptureManager *)(userData);
    [captureManager handleHotKey:keyID];
    return noErr;
}

@implementation CaptureManager {
    NSURL *baseURL;
    NSDateFormatter *formatter;
    id globalEventMonitor;
    id localEventMonitor;
    EventHotKeyRef captureScreenHotKeyRef;
    EventHotKeyRef captureWindowHotKeyRef;
    EventHotKeyRef captureAreaHotKeyRef;
    SystemSoundID captureSoundId;
}

// MARK: - Lifecycle

- (id)init {
    if (self = [super init]) {
        NSString *desktopDir = NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES)[0];
        baseURL = [[NSURL alloc] initFileURLWithPath:desktopDir];
        
        formatter = [NSDateFormatter new];
        formatter.dateFormat = @"yy-MM-dd 'at' HH.mm.ss";
        
        // Load capture sound
        NSURL *captureSoundURL = [NSURL fileURLWithPath:@"/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/system/Screen Capture.aif"];
        AudioServicesCreateSystemSoundID((__bridge CFURLRef _Nonnull)(captureSoundURL), &captureSoundId);
        
        [self registerShortcuts];
    }
    return self;
}

- (void)dealloc {
    [self stopCapturing];
    [self unregisterShortcuts];
}

// MARK: - File methods

- (NSString *)newFileName {
    return [self newFileNameWithSuffix:@""];
}

- (NSString *)newFileNameWithSuffix:(NSString *)suffix {
    NSString *dateTime = [formatter stringFromDate:[NSDate new]];
    return [NSString stringWithFormat:@"Screen Capture %@%@.png", dateTime, suffix];
}

- (void)saveImage:(CGImageRef)cgImage to:(NSURL *)destURL {
    NSBitmapImageRep *bitmapRep = [[NSBitmapImageRep alloc] initWithCGImage:cgImage];
    NSData *pngData = [bitmapRep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    [pngData writeToURL:destURL atomically:YES];
    AudioServicesPlaySystemSound(captureSoundId);
}

// MARK: - Capture methods

- (void)captureScreen:(NSMenuItem *)sender {
    for (NSScreen *screen in NSScreen.screens) {
        NSNumber *screenNumber = [screen.deviceDescription objectForKey:@"NSScreenNumber"];
        CGDirectDisplayID displayId = screenNumber.unsignedIntValue;
        CGImageRef cgImage = CGDisplayCreateImage(displayId);
        if (cgImage) {
            NSURL *destURL = [NSURL fileURLWithPath:[self newFileName] relativeToURL:baseURL];
            [self saveImage:cgImage to:destURL];
        }
    }
}

- (void)stopCapturing {
    if (globalEventMonitor) {
        [NSEvent removeMonitor:globalEventMonitor];
        globalEventMonitor = nil;
    }
    if (localEventMonitor) {
        [NSEvent removeMonitor:localEventMonitor];
        localEventMonitor = nil;
    }
}

- (void)captureWindow:(NSMenuItem *)sender {
    Panel *overlayWindow = [[Panel alloc] initWithContentRect:NSZeroRect
                                                    styleMask:NSWindowStyleMaskNonactivatingPanel
                                                      backing:NSBackingStoreBuffered
                                                        defer:NO];
    overlayWindow.level = NSStatusWindowLevel;
    overlayWindow.hasShadow = NO;
    overlayWindow.alphaValue = 0.3;
    overlayWindow.backgroundColor = NSColor.whiteColor;
    
    NSImage *cursorImage = [NSImage imageNamed:@"screenshotwindow"];
    NSPoint hotspot = NSMakePoint(cursorImage.size.width / 2, cursorImage.size.height / 2);
    NSCursor *cameraCursor = [[NSCursor alloc] initWithImage:cursorImage hotSpot:hotspot];
    
    CursorView *cursorView = [CursorView new];
    cursorView.cursor = cameraCursor;
    overlayWindow.contentView = cursorView;
    
    [overlayWindow makeKeyAndOrderFront:sender];
    
    globalEventMonitor = [NSEvent addGlobalMonitorForEventsMatchingMask:NSEventMaskMouseMoved handler:^(NSEvent * _Nonnull event) {
        CGFloat screenHeight = NSScreen.mainScreen.frame.size.height;
        CGWindowID windowId = (CGWindowID)event.windowNumber;
        NSArray *windows = CFBridgingRelease(CGWindowListCopyWindowInfo(kCGWindowListOptionIncludingWindow, windowId));
        for (NSDictionary *window in windows) {
            NSNumber *layer = window[(NSString *)kCGWindowLayer];
            // If the layer is above 0, it may be a status bar item
            overlayWindow.level = layer.intValue <= 0 ? NSNormalWindowLevel : NSStatusWindowLevel;
            CGRect currentBounds;
            CGRectMakeWithDictionaryRepresentation((CFDictionaryRef)window[(NSString *)kCGWindowBounds], &currentBounds);
            currentBounds.origin.y = screenHeight - (currentBounds.origin.y + currentBounds.size.height);
            [overlayWindow setFrame:currentBounds display:YES];
            [overlayWindow orderWindow:NSWindowAbove relativeTo:windowId];
            [overlayWindow resetCursorRects];
        }
    }];
    
    localEventMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskLeftMouseDown|NSEventMaskKeyUp handler:^NSEvent * _Nullable(NSEvent * _Nonnull event) {
        if (event.type == NSEventTypeLeftMouseDown || event.keyCode == kVK_Escape) {
            [overlayWindow orderOut:nil];
            [self stopCapturing];
        }
        if (event.type == NSEventTypeLeftMouseDown) {
            CGWindowID windowId = (CGWindowID)[NSWindow windowNumberAtPoint:NSEvent.mouseLocation belowWindowWithWindowNumber:overlayWindow.windowNumber];
            CGImageRef cgImage = CGWindowListCreateImage(CGRectNull, kCGWindowListOptionIncludingWindow, windowId, kCGWindowImageDefault);
            if (cgImage) {
                NSURL *destURL = [NSURL fileURLWithPath:[self newFileName] relativeToURL:self->baseURL];
                [self saveImage:cgImage to:destURL];
            }
        }
        return event;
    }];
}

- (void)captureArea:(NSMenuItem *)sender {
    Panel *overlayWindow = [[Panel alloc] initWithContentRect:NSZeroRect
                                                    styleMask:NSWindowStyleMaskNonactivatingPanel
                                                      backing:NSBackingStoreBuffered
                                                        defer:NO];
    overlayWindow.level = NSStatusWindowLevel;
    overlayWindow.hasShadow = NO;
    overlayWindow.backgroundColor = [NSColor colorWithWhite:1 alpha:0.001];
    [overlayWindow setFrame:NSScreen.mainScreen.frame display:NO];
    
    NSImage *cursorImage = [NSImage imageNamed:@"screenshotselection"];
    NSPoint hotspot = NSMakePoint(cursorImage.size.width / 2, cursorImage.size.height / 2);
    NSCursor *selectionCursor = [[NSCursor alloc] initWithImage:cursorImage hotSpot:hotspot];
    
    SelectionView *selectionView = [SelectionView new];
    selectionView.cursor = selectionCursor;
    overlayWindow.contentView = selectionView;
    
    [overlayWindow makeKeyAndOrderFront:sender];
    
    localEventMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskLeftMouseUp|NSEventMaskKeyUp handler:^NSEvent * _Nullable(NSEvent * _Nonnull event) {
        if (event.type == NSEventTypeLeftMouseUp || event.keyCode == kVK_Escape) {
            [overlayWindow orderOut:nil];
            [self stopCapturing];
        }
        if (event.type == NSEventTypeLeftMouseUp) {
            CGFloat screenHeight = NSScreen.mainScreen.frame.size.height;
            CGRect selectedArea = selectionView.selection;
            selectedArea.origin.y = screenHeight - (selectedArea.origin.y + selectedArea.size.height);
            CGImageRef cgImage = CGWindowListCreateImage(selectedArea, kCGWindowListOptionOnScreenOnly, (CGWindowID)overlayWindow.windowNumber, kCGWindowImageDefault);
            if (cgImage) {
                NSURL *destURL = [NSURL fileURLWithPath:[self newFileName] relativeToURL:self->baseURL];
                [self saveImage:cgImage to:destURL];
            }
        }
        return event;
    }];
}

- (void)showScreenCapturePrivacySettings:(NSMenuItem *)sender {
    NSURL *url = [NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"];
    [NSWorkspace.sharedWorkspace openURL:url];
}

// MARK: - Global shortcut methods

- (void)registerShortcuts {
    UInt32 modifiers = cmdKey | shiftKey;
    UInt32 hotkeyID = 0;
    EventHotKeyID keyID = {.signature = 'MSHT'};
    
    // CMD + Shift + E (Capture Screen)
    keyID.id = ++hotkeyID;
    RegisterEventHotKey(0x0E, modifiers, keyID, GetApplicationEventTarget(), 0, &captureScreenHotKeyRef);
    
    // CMD + Shift + W (Capture Window)
    keyID.id = ++hotkeyID;
    RegisterEventHotKey(0x0D, modifiers, keyID, GetApplicationEventTarget(), 0, &captureWindowHotKeyRef);
    
    // CMD + Shift + R (Capture Selected Area)
    keyID.id = ++hotkeyID;
    RegisterEventHotKey(0x0F, modifiers, keyID, GetApplicationEventTarget(), 0, &captureAreaHotKeyRef);
    
    hotKeyFunction = NewEventHandlerUPP(hotKeyHandler);
    EventTypeSpec eventType;
    eventType.eventClass = kEventClassKeyboard;
    eventType.eventKind = kEventHotKeyReleased;
    InstallApplicationEventHandler(hotKeyFunction, 1, &eventType, (__bridge void*)self, NULL);
}

- (void)unregisterShortcuts {
    if (captureScreenHotKeyRef) {
        UnregisterEventHotKey(captureScreenHotKeyRef);
        captureScreenHotKeyRef = NULL;
    }
    if (captureWindowHotKeyRef) {
        UnregisterEventHotKey(captureWindowHotKeyRef);
        captureWindowHotKeyRef = NULL;
    }
    if (captureAreaHotKeyRef) {
        UnregisterEventHotKey(captureAreaHotKeyRef);
        captureAreaHotKeyRef = NULL;
    }
}

- (void)handleHotKey:(EventHotKeyID)keyID {
    if (keyID.id == 1) {
        [self captureScreen:nil];
    } else if (keyID.id == 2) {
        [self captureWindow:nil];
    } else if (keyID.id == 3) {
        [self captureArea:nil];
    }
}

// MARK: - Menu delegate

- (void)menuWillOpen:(NSMenu *)menu {
    if (!CGPreflightScreenCaptureAccess()) {
        CGRequestScreenCaptureAccess();
    }
}

- (void)menuNeedsUpdate:(NSMenu *)menu {
    BOOL isAuthorized = CGPreflightScreenCaptureAccess();
    for (NSMenuItem *item in menu.itemArray) {
        if (item.tag >= 100) {
            break;
        }
        item.enabled = isAuthorized;
    }
    NSMenuItem *permissionItem = [menu itemWithTag:100];
    if (isAuthorized && permissionItem) {
        [menu removeItem:permissionItem];
    }
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // Setup the app
        NSApplication *app = [NSApplication sharedApplication];
        app.activationPolicy = NSApplicationActivationPolicyAccessory;
        
        CaptureManager *captureManager = [CaptureManager new];
        
        // Create menu bar button
        NSStatusItem * statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSSquareStatusItemLength];
        statusItem.button.image = [NSImage imageWithSystemSymbolName:@"camera.shutter.button" accessibilityDescription:nil];
        statusItem.menu = [NSMenu new];
        statusItem.menu.autoenablesItems = NO;
        statusItem.menu.delegate = captureManager;
        
        [statusItem.menu addItemWithTitle:@"Capture screen"
                                   action:@selector(captureScreen:)
                            keyEquivalent:@"E"].target = captureManager;
        [statusItem.menu addItemWithTitle:@"Capture window"
                                   action:@selector(captureWindow:)
                            keyEquivalent:@"W"].target = captureManager;
        [statusItem.menu addItemWithTitle:@"Capture selected area"
                                   action:@selector(captureArea:)
                            keyEquivalent:@"R"].target = captureManager;
        NSMenuItem *permissionItem = [statusItem.menu addItemWithTitle:@"Grant screen capture permission..."
                                                                action:@selector(showScreenCapturePrivacySettings:)
                                                         keyEquivalent:@""];
        permissionItem.target = captureManager;
        permissionItem.tag = 100;
        [statusItem.menu addItem:[NSMenuItem separatorItem]];
        [statusItem.menu addItemWithTitle:@"Quit"
                                   action:@selector(terminate:)
                            keyEquivalent:@"q"].target = app;
        
        // Run the app
        [app run];
    }
    return EXIT_SUCCESS;
}
