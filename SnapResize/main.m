//
//  main.m
//  SnapResize
//
//  Created by Eric Maciel on 12/10/23.
//

#import <Carbon/Carbon.h>
#import <Cocoa/Cocoa.h>
#import <ServiceManagement/ServiceManagement.h>

typedef NS_ENUM(NSInteger, WindowPosition) {
    WindowPositionLeft,
    WindowPositionRight,
    WindowPositionTop,
    WindowPositionBottom,
    WindowPositionTopLeft,
    WindowPositionTopRight,
    WindowPositionBottomLeft,
    WindowPositionBottomRight,
    WindowPositionCenter
};

@interface Shortcut : NSObject
@property (readonly) EventHotKeyID keyID;
@property (assign) WindowPosition windowPosition;
@end

@implementation Shortcut {
    EventHotKeyRef hotKeyRef;
}

+ (instancetype)shortcutWithKeyCode:(UInt32)code keyModifiers:(UInt32)modifiers windowPosition:(WindowPosition)position {
    Shortcut *shortcut = [[self alloc] initWithKeyCode:code keyModifiers:modifiers];
    shortcut.windowPosition = position;
    return shortcut;
}

- (instancetype)initWithKeyCode:(UInt32)code keyModifiers:(UInt32)modifiers {
    if (self = [super init]) {
        static UInt32 hotkeyID = 0;
        _keyID.signature = 'MSHT';
        _keyID.id = ++hotkeyID;
        RegisterEventHotKey(code, modifiers, _keyID, GetApplicationEventTarget(), 0, &hotKeyRef);
    }
    return self;
}

- (void)dealloc {
    [super dealloc];
    if (hotKeyRef) {
        UnregisterEventHotKey(hotKeyRef);
        hotKeyRef = NULL;
    }
}

@end

@interface SnapResize : NSObject
@end

@implementation SnapResize {
    NSArray *registeredShortcuts;
}

- (instancetype)init {
    if (self = [super init]) {
        [self registerShortcuts];
    }
    return self;
}

- (void)dealloc {
    [super dealloc];
    [self unregisterShortcuts];
}

// MARK: - Arrange methods

- (void)arrangeWithPosition:(WindowPosition)windowPosition {
    NSDictionary *options = @{(__bridge NSString *)kAXTrustedCheckOptionPrompt: @YES};
    if (!AXIsProcessTrustedWithOptions((CFDictionaryRef)options)) {
        return;
    }
    
    NSRect screenFrame = NSScreen.mainScreen.visibleFrame;
    
    CGPoint newPoint = screenFrame.origin;
    CGSize newSize = screenFrame.size;
    
    switch (windowPosition) {
        case WindowPositionLeft:
            newSize.width /= 2;
            break;
        case WindowPositionRight:
            newSize.width /= 2;
            newPoint.x += newSize.width;
            break;
        case WindowPositionTop:
            newSize.height /= 2;
            break;
        case WindowPositionBottom:
            newSize.height /= 2;
            newPoint.y += newSize.height;
            break;
        case WindowPositionTopLeft:
            newSize.width /= 2;
            newSize.height /= 2;
            break;
        case WindowPositionTopRight:
            newSize.width /= 2;
            newSize.height /= 2;
            newPoint.x += newSize.width;
            break;
        case WindowPositionBottomLeft:
            newSize.width /= 2;
            newSize.height /= 2;
            newPoint.y += newSize.height;
            break;
        case WindowPositionBottomRight:
            newSize.width /= 2;
            newSize.height /= 2;
            newPoint.x += newSize.width;
            newPoint.y += newSize.height;
            break;
        case WindowPositionCenter:
            break;
    }
    
    NSRunningApplication *frontmostApp = NSWorkspace.sharedWorkspace.frontmostApplication;
    AXUIElementRef app = AXUIElementCreateApplication(frontmostApp.processIdentifier);
    
    AXUIElementRef window;
    AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute, (CFTypeRef *)&window);
    
    AXValueRef position = AXValueCreate(kAXValueTypeCGPoint, &newPoint);
    AXUIElementSetAttributeValue(window, kAXPositionAttribute, position);
    
    AXValueRef size = AXValueCreate(kAXValueTypeCGSize, &newSize);
    AXUIElementSetAttributeValue(window, kAXSizeAttribute, size);
}

- (void)arrange:(NSMenuItem *)sender {
    WindowPosition position = ((NSNumber *)sender.representedObject).integerValue;
    [self arrangeWithPosition:position];
}

// MARK: - Global shortcut methods

EventHandlerUPP hotKeyFunction;
OSStatus hotKeyHandler(EventHandlerCallRef nextHandler, EventRef event, void *userData) {
    EventHotKeyID keyID;
    GetEventParameter(event, kEventParamDirectObject, typeEventHotKeyID, NULL, sizeof(keyID), NULL, &keyID);
    SnapResize *snapResize = (__bridge SnapResize *)(userData);
    [snapResize handleHotKey:keyID];
    return noErr;
}

- (void)registerShortcuts {
    
    NSMutableArray *shortcuts = [NSMutableArray array];
    
    UInt32 modifiers = cmdKey | controlKey | optionKey;
    // Cmd + Ctrl + Opt + Left
    [shortcuts addObject:[Shortcut shortcutWithKeyCode:kVK_LeftArrow keyModifiers:modifiers windowPosition:WindowPositionLeft]];
    // Cmd + Ctrl + Opt + Right
    [shortcuts addObject:[Shortcut shortcutWithKeyCode:kVK_RightArrow keyModifiers:modifiers windowPosition:WindowPositionRight]];
    // Cmd + Ctrl + Opt + Top
    [shortcuts addObject:[Shortcut shortcutWithKeyCode:kVK_UpArrow keyModifiers:modifiers windowPosition:WindowPositionTop]];
    // Cmd + Ctrl + Opt + Bottom
    [shortcuts addObject:[Shortcut shortcutWithKeyCode:kVK_DownArrow keyModifiers:modifiers windowPosition:WindowPositionBottom]];
    // Cmd + Ctrl + Opt + 1
    [shortcuts addObject:[Shortcut shortcutWithKeyCode:kVK_ANSI_1 keyModifiers:modifiers windowPosition:WindowPositionTopLeft]];
    // Cmd + Ctrl + Opt + 2
    [shortcuts addObject:[Shortcut shortcutWithKeyCode:kVK_ANSI_2 keyModifiers:modifiers windowPosition:WindowPositionTopRight]];
    // Cmd + Ctrl + Opt + 3
    [shortcuts addObject:[Shortcut shortcutWithKeyCode:kVK_ANSI_3 keyModifiers:modifiers windowPosition:WindowPositionBottomLeft]];
    // Cmd + Ctrl + Opt + 4
    [shortcuts addObject:[Shortcut shortcutWithKeyCode:kVK_ANSI_4 keyModifiers:modifiers windowPosition:WindowPositionBottomRight]];
    // Cmd + Ctrl + Opt + C
    [shortcuts addObject:[Shortcut shortcutWithKeyCode:kVK_ANSI_C keyModifiers:modifiers windowPosition:WindowPositionCenter]];
    
    registeredShortcuts = shortcuts;
    
    if (!hotKeyFunction) {
        hotKeyFunction = NewEventHandlerUPP(hotKeyHandler);
        EventTypeSpec eventType;
        eventType.eventClass = kEventClassKeyboard;
        eventType.eventKind = kEventHotKeyReleased;
        InstallApplicationEventHandler(hotKeyFunction, 1, &eventType, (__bridge void*)self, NULL);
    }
}

- (void)unregisterShortcuts {
    registeredShortcuts = nil;
}

- (void)handleHotKey:(EventHotKeyID)keyID {
    for (Shortcut *shortcut in registeredShortcuts) {
        if (shortcut.keyID.id == keyID.id) {
            [self arrangeWithPosition:shortcut.windowPosition];
        }
    }
}

@end

@implementation NSMenu (Extensions)

- (NSMenuItem *)addItemWithTitle:(nonnull NSString *)title
                          action:(nullable SEL)action
                          target:(nullable id)target
               representedObject:(nullable id)object
                   keyEquivalent:(nonnull NSString *)key
       keyEquivalentModifierMask:(NSEventModifierFlags)modifiers {
    NSMenuItem *item = [self addItemWithTitle:title action:action keyEquivalent:key];
    item.keyEquivalentModifierMask = modifiers;
    item.target = target;
    item.representedObject = object;
    return item;
}

@end

NS_INLINE NSString* NSStringFromKeyCode(unsigned short ch) {
    return [NSString stringWithFormat:@"%C", ch];
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSApplication *app = NSApplication.sharedApplication;
        app.activationPolicy = NSApplicationActivationPolicyAccessory;
        
        SnapResize *snapResize = [SnapResize new];
        
        NSStatusItem *statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSSquareStatusItemLength];
        statusItem.button.image = [NSImage imageWithSystemSymbolName:@"uiwindow.split.2x1"
                                            accessibilityDescription:nil];
        statusItem.menu = [NSMenu new];
        
        NSEventModifierFlags modifiers = NSEventModifierFlagCommand|NSEventModifierFlagControl|NSEventModifierFlagOption;
        [statusItem.menu addItemWithTitle:@"Left"
                                   action:@selector(arrange:)
                                   target:snapResize
                        representedObject:@(WindowPositionLeft)
                            keyEquivalent:NSStringFromKeyCode(NSLeftArrowFunctionKey)
                keyEquivalentModifierMask:modifiers];
        [statusItem.menu addItemWithTitle:@"Right"
                                   action:@selector(arrange:)
                                   target:snapResize
                        representedObject:@(WindowPositionRight)
                            keyEquivalent:NSStringFromKeyCode(NSRightArrowFunctionKey)
                keyEquivalentModifierMask:modifiers];
        [statusItem.menu addItemWithTitle:@"Top"
                                   action:@selector(arrange:)
                                   target:snapResize
                        representedObject:@(WindowPositionTop)
                            keyEquivalent:NSStringFromKeyCode(NSUpArrowFunctionKey)
                keyEquivalentModifierMask:modifiers];
        [statusItem.menu addItemWithTitle:@"Bottom"
                                   action:@selector(arrange:)
                                   target:snapResize
                        representedObject:@(WindowPositionBottom)
                            keyEquivalent:NSStringFromKeyCode(NSDownArrowFunctionKey)
                keyEquivalentModifierMask:modifiers];
        
        [statusItem.menu addItem:[NSMenuItem separatorItem]];
        
        [statusItem.menu addItemWithTitle:@"Top Left"
                                   action:@selector(arrange:)
                                   target:snapResize
                        representedObject:@(WindowPositionTopLeft)
                            keyEquivalent:@"1"
                keyEquivalentModifierMask:modifiers];
        [statusItem.menu addItemWithTitle:@"Top Right"
                                   action:@selector(arrange:)
                                   target:snapResize
                        representedObject:@(WindowPositionTopRight)
                            keyEquivalent:@"2"
                keyEquivalentModifierMask:modifiers];
        [statusItem.menu addItemWithTitle:@"Bottom Left"
                                   action:@selector(arrange:)
                                   target:snapResize
                        representedObject:@(WindowPositionBottomLeft)
                            keyEquivalent:@"3"
                keyEquivalentModifierMask:modifiers];
        [statusItem.menu addItemWithTitle:@"Bottom Right"
                                   action:@selector(arrange:)
                                   target:snapResize
                        representedObject:@(WindowPositionBottomRight)
                            keyEquivalent:@"4"
                keyEquivalentModifierMask:modifiers];
        
        [statusItem.menu addItem:[NSMenuItem separatorItem]];
        
        [statusItem.menu addItemWithTitle:@"Center"
                                   action:@selector(arrange:)
                                   target:snapResize
                        representedObject:@(WindowPositionCenter)
                            keyEquivalent:@"c"
                keyEquivalentModifierMask:modifiers];
        
        [statusItem.menu addItem:[NSMenuItem separatorItem]];
        
        [statusItem.menu addItemWithTitle:@"Quit"
                                   action:@selector(terminate:)
                            keyEquivalent:@"q"].target = app;
        
        [app run];
    }
    return EXIT_SUCCESS;
}
