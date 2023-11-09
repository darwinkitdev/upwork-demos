//
//  main.m
//  HexPicker
//
//  Created by Eric Maciel on 03/11/23.
//

#import <Carbon/Carbon.h>
#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>

@implementation NSColor (Additions)

- (NSColor *)bestContrastingColor {
    CGFloat rgb[] = {self.redComponent, self.greenComponent, self.blueComponent};
    for (int i = 0; i < 3; i++) {
        CGFloat v = rgb[i];
        rgb[i] = v < 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4);
    }
    CGFloat L = 0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2];
    return L > 0.197 ? NSColor.blackColor : NSColor.whiteColor;
}

- (NSString *)hexString {
    return [NSString stringWithFormat:@"%02X%02X%02X",
            (int)(self.redComponent * 0xFF),
            (int)(self.greenComponent * 0xFF),
            (int)(self.blueComponent * 0xFF)];
}

- (void)copyToPasteboard {
    [NSPasteboard.generalPasteboard declareTypes:@[NSPasteboardTypeString] owner:nil];
    [NSPasteboard.generalPasteboard setString:[self hexString] forType:NSPasteboardTypeString];
}

@end

@implementation NSImage (Additions)

+ (NSImage *)roundedRectImageWithSize:(NSSize)size andColor:(NSColor *)color {
    return [NSImage imageWithSize:size
                          flipped:NO
                   drawingHandler:^BOOL(NSRect dstRect) {
        [color set];
        [[NSBezierPath bezierPathWithRoundedRect:dstRect
                                         xRadius:5
                                         yRadius:4] fill];
        return YES;
    }];
}

@end

@interface MagnifierView : NSView
@property (nonatomic) CGFloat numberOfPixels;
@property (strong) CAShapeLayer *centerPixelCell;
@property (strong) NSColor *centerPixelColor;
@end

@implementation MagnifierView

- (void)setNumberOfPixels:(CGFloat)numberOfPixels {
    if ((NSInteger)numberOfPixels % 2 == 0) {
        _numberOfPixels = numberOfPixels + 1;
    } else {
        _numberOfPixels = numberOfPixels;
    }
}

- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    self.wantsLayer = YES;
    self.layer.magnificationFilter = kCAFilterNearest;
    self.layer.contentsGravity = kCAGravityResizeAspectFill;
    self.layer.cornerRadius = 15;
    self.layer.borderWidth = 3;
    
    CGFloat pixelSize = self.bounds.size.width / self.numberOfPixels;
    
    CAShapeLayer *grid = [CAShapeLayer layer];
    grid.strokeColor = NSColor.grayColor.CGColor;
    grid.fillColor = nil;
    grid.opacity = 0.3;
    [self.layer addSublayer:grid];
    
    CGMutablePathRef path = CGPathCreateMutable();
    CGFloat start = 0;
    CGFloat end = self.numberOfPixels * pixelSize;
    int n = self.numberOfPixels;
    for (int i = 0; i < n; i++) {
        CGFloat pos = (CGFloat)i * pixelSize;
        CGPathMoveToPoint(path, NULL, pos, start);
        CGPathAddLineToPoint(path, NULL, pos, end);
        CGPathMoveToPoint(path, NULL, start, pos);
        CGPathAddLineToPoint(path, NULL, end, pos);
    }
    grid.path = path;
    
    CGFloat pos = (self.bounds.size.width - pixelSize) / 2;
    NSRect pixelRect = NSMakeRect(pos, pos, pixelSize, pixelSize);
    CAShapeLayer *centerPixel = [CAShapeLayer layer];
    centerPixel.path = CGPathCreateWithRect(pixelRect, nil);
    centerPixel.strokeColor = NSColor.lightGrayColor.CGColor;
    centerPixel.fillColor = nil;
    [self.layer addSublayer:centerPixel];
    
    self.centerPixelCell = centerPixel;
}

- (NSColor *)pixelColorInImage:(CGImageRef)image atX:(int)x atY:(int)y {
    NSBitmapImageRep *bitmapRep = [[NSBitmapImageRep alloc] initWithCGImage:image];
    return [bitmapRep colorAtX:x y:y];
}

- (CGImageRef)captureScreenAroundPoint:(NSPoint)point {
    CGFloat screenHeight = self.window.screen.frame.size.height;
    CGFloat size = self.numberOfPixels;
    CGFloat offset = size / 2;
    NSRect captureRect = NSMakeRect(point.x - offset, screenHeight - point.y - offset, size, size);
    CGWindowID excludingWindowID = (CGWindowID)self.window.windowNumber;
    return CGWindowListCreateImage(captureRect, kCGWindowListOptionOnScreenBelowWindow, excludingWindowID, kCGWindowImageBestResolution);
}

- (void)updatePreview {
    CGImageRef cgImage = [self captureScreenAroundPoint:NSEvent.mouseLocation];
    NSColor *pixelColor = [self pixelColorInImage:cgImage
                                              atX:self.numberOfPixels/2
                                              atY:self.numberOfPixels/2];
    
    self.layer.contents = CFBridgingRelease(cgImage);
    self.layer.borderColor = pixelColor.CGColor;
    self.centerPixelCell.strokeColor = [pixelColor bestContrastingColor].CGColor;
    self.centerPixelColor = pixelColor;
}

@end

@interface HexPicker : NSObject <NSMenuDelegate>
@property (strong) NSWindow *window;
@property (strong) id eventMonitor;
@property (strong) NSArray *recentColors;
- (void)handleHotKey:(EventHotKeyID)keyID;
@end

EventHandlerUPP hotKeyFunction;
OSStatus hotKeyHandler(EventHandlerCallRef nextHandler, EventRef event, void *userData) {
    EventHotKeyID keyID;
    GetEventParameter(event, kEventParamDirectObject, typeEventHotKeyID, NULL, sizeof(keyID), NULL, &keyID);
    HexPicker *hexPicker = (__bridge HexPicker *)(userData);
    [hexPicker handleHotKey:keyID];
    return noErr;
}

@implementation HexPicker {
    EventHotKeyRef pickColorHotKeyRef;
}

NSUInteger const kMaxRecentColors = 10;

- (instancetype)init {
    if (self = [super init]) {
        [self registerShortcuts];
    }
    return self;
}

- (void)dealloc {
    [self unregisterShortcuts];
}

- (void)addRecentColor:(NSColor *)color {
    if (self.recentColors) {
        self.recentColors = [self.recentColors arrayByAddingObject:color];
    } else {
        self.recentColors = @[color];
    }
    
    NSUInteger location = self.recentColors.count / (kMaxRecentColors + 1);
    NSUInteger length = self.recentColors.count - location;
    self.recentColors = [self.recentColors subarrayWithRange:NSMakeRange(location, length)];
    
    [color copyToPasteboard];
}

- (void)pickColor:(NSMenuItem *)sender {
    if (!CGPreflightScreenCaptureAccess()) {
        CGRequestScreenCaptureAccess();
        return;
    }
    
    NSRunningApplication *previousActiveApp = NSWorkspace.sharedWorkspace.frontmostApplication;
    
    NSWindow *window = [[NSWindow alloc] init];
    window.styleMask = NSWindowStyleMaskBorderless | NSWindowStyleMaskFullSizeContentView;
    window.level = NSStatusWindowLevel;
    window.movable = NO;
    window.movableByWindowBackground = NO;
    window.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorFullScreenAuxiliary | NSWindowCollectionBehaviorStationary | NSWindowCollectionBehaviorIgnoresCycle;
    window.opaque = NO;
    window.hasShadow = NO;
    window.backgroundColor = NSColor.clearColor;
    window.ignoresMouseEvents = NO;
    
    MagnifierView *magView = [[MagnifierView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
    magView.numberOfPixels = 11;
    [window.contentView addSubview:magView];
    
    [window orderFrontRegardless];
    [NSApp activateIgnoringOtherApps:YES];
    [NSCursor hide];
    
    void (^updateMagnifier)(void) = ^void() {
        if (!NSEqualRects(window.frame, window.screen.frame)) {
            [window setFrame:window.screen.frame display:YES];
        }
        
        NSPoint origin = NSEvent.mouseLocation;
        origin.x -= magView.frame.size.width / 2;
        origin.y -= magView.frame.size.height / 2;
        [magView setFrameOrigin:origin];
        [magView updatePreview];
    };
    
    updateMagnifier();
    
    self.eventMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskMouseMoved | NSEventMaskLeftMouseUp | NSEventMaskKeyUp handler:^NSEvent * _Nullable(NSEvent * _Nonnull event) {
        if (event.type == NSEventTypeLeftMouseUp) {
            [self addRecentColor:magView.centerPixelColor];
        }
        
        if (event.type == NSEventTypeLeftMouseUp || (event.type == NSEventTypeKeyUp && event.keyCode == kVK_Escape)) {
            [NSCursor unhide];
            [window orderOut:NSApp];
            [NSEvent removeMonitor:self.eventMonitor];
            [previousActiveApp activateWithOptions:0];
            return event;
        }
        
        updateMagnifier();
        
        return event;
    }];
}

- (void)copyToPasteboard:(NSMenuItem *)sender {
    [(NSColor *)sender.representedObject copyToPasteboard];
}

- (void)menuNeedsUpdate:(NSMenu *)menu {
    // Preserve the "Pick Color", separator and "Quit" items and remove the rest.
    NSArray *menuItems = [menu.itemArray subarrayWithRange:NSMakeRange(1, menu.numberOfItems - 3)];
    for (NSMenuItem *item in menuItems) {
        [menu removeItem:item];
    }
    
    if (self.recentColors.count > 0) {
        [menu insertItem:[NSMenuItem separatorItem]
                 atIndex:1];
        [menu insertItemWithTitle:@"Recent Colors"
                           action:nil
                    keyEquivalent:@""
                          atIndex:2];
    }
    
    for (NSColor *color in self.recentColors) {
        NSMenuItem *item = [menu insertItemWithTitle:[color hexString]
                                              action:@selector(copyToPasteboard:)
                                       keyEquivalent:@""
                                             atIndex:menu.numberOfItems - 2];
        item.representedObject = color;
        item.image = [NSImage roundedRectImageWithSize:NSMakeSize(16, 16) andColor:color];
        item.target = self;
    }
}

// MARK: - Global shortcut methods

- (void)registerShortcuts {
    UInt32 modifiers = cmdKey | shiftKey;
    UInt32 hotkeyID = 0;
    EventHotKeyID keyID = {.signature = 'HXPK'};
    
    // CMD + Shift + M (Pick Color)
    keyID.id = ++hotkeyID;
    RegisterEventHotKey(kVK_ANSI_M, modifiers, keyID, GetApplicationEventTarget(), 0, &pickColorHotKeyRef);
    
    hotKeyFunction = NewEventHandlerUPP(hotKeyHandler);
    EventTypeSpec eventType;
    eventType.eventClass = kEventClassKeyboard;
    eventType.eventKind = kEventHotKeyReleased;
    InstallApplicationEventHandler(hotKeyFunction, 1, &eventType, (__bridge void*)self, NULL);
}

- (void)unregisterShortcuts {
    if (pickColorHotKeyRef) {
        UnregisterEventHotKey(pickColorHotKeyRef);
        pickColorHotKeyRef = NULL;
    }
}

- (void)handleHotKey:(EventHotKeyID)keyID {
    if (keyID.id == 1) {
        [self pickColor:nil];
    }
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSApplication *app = NSApplication.sharedApplication;
        app.activationPolicy = NSApplicationActivationPolicyAccessory;
        
        HexPicker *hexPicker = [HexPicker new];
        
        NSStatusItem *statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSSquareStatusItemLength];
        statusItem.button.image = [NSImage imageWithSystemSymbolName:@"paintpalette"
                                            accessibilityDescription:nil];
        statusItem.menu = [NSMenu new];
        statusItem.menu.delegate = hexPicker;
        
        [statusItem.menu addItemWithTitle:@"Pick Color"
                                   action:@selector(pickColor:)
                            keyEquivalent:@"M"].target = hexPicker;
        [statusItem.menu addItem:[NSMenuItem separatorItem]];
        [statusItem.menu addItemWithTitle:@"Quit"
                                   action:@selector(terminate:)
                            keyEquivalent:@"q"];
        
        [app run];
    }
    return EXIT_SUCCESS;
}
