//
//  main.m
//  DisplayTint
//
//  Created by Eric Maciel on 07/11/23.
//

#import <Cocoa/Cocoa.h>
#import <IOKit/graphics/IOGraphicsLib.h>

@implementation NSMenu (Additions)
- (CGFloat)stateColumnWidth {
    CGFloat stateWidth = 0;
    for (NSMenuItem *item in self.itemArray) {
        if (item.state == NSControlStateValueOn) {
            stateWidth = item.onStateImage.size.width;
            break;
        } else if (item.state == NSControlStateValueMixed) {
            stateWidth = item.mixedStateImage.size.width;
            break;
        }
    }
    return stateWidth;
}
@end

@interface NSMenuItem ()
@property (setter=_setViewHandlesEvents:) BOOL _viewHandlesEvents;
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

@interface DisplayTint : NSObject <NSMenuDelegate, NSWindowDelegate>
@property (nonatomic, weak) NSWindow *overlayWindow;
@property (nonatomic, weak) NSSlider *brightnessSlider;
@property (nonatomic, weak) NSImageView *tintImageView;
@property (nonatomic, strong) NSColor *selectedColor;
@property (nonatomic, assign) BOOL tintIsEnabled;
@end

NSInteger const kEnableTintMenuItemTag = 100;
NSInteger const kSetTintMenuItemTag = 101;

@implementation DisplayTint

- (void)handleColor:(NSColorPanel *)colorPanel {
    self.selectedColor = [colorPanel color];
    self.overlayWindow.backgroundColor = self.selectedColor;
}

- (void)chooseColor:(NSMenuItem *)sender {
    NSColorPanel *colorPanel = [NSColorPanel sharedColorPanel];
    [colorPanel setTarget:self];
    [colorPanel setAction:@selector(handleColor:)];
    [colorPanel center];
    [colorPanel makeKeyAndOrderFront:sender];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)updateOverlayState {
    if (self.tintIsEnabled) {
        self.overlayWindow.alphaValue = 0;
        [self.overlayWindow orderFrontRegardless];
    }
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull context) {
        context.duration = 0.5;
        self.overlayWindow.animator.alphaValue = self.tintIsEnabled ? 0.25 : 0;
    } completionHandler:^{
        if (!self.tintIsEnabled) {
            [self.overlayWindow orderOut:self];
        }
    }];
}

- (void)toggleEnableTint:(NSMenuItem *)sender {
    self.tintIsEnabled = !self.tintIsEnabled;
    [self updateOverlayState];
}

- (void)adjustBrightness:(NSSlider *)sender {
    [self setDisplayBrightness:sender.floatValue];
}

// MARK: - Display brightness methods

- (float)getDisplayBrightness {
    float brightness = 1.0f;
    io_iterator_t iterator;
    kern_return_t result =
    IOServiceGetMatchingServices(kIOMasterPortDefault,
                                 IOServiceMatching("IODisplayConnect"),
                                 &iterator);
    
    if (result == kIOReturnSuccess) {
        io_object_t service;
        
        while ((service = IOIteratorNext(iterator)) != MACH_PORT_NULL) {
            IODisplayGetFloatParameter(service,
                                       kNilOptions,
                                       CFSTR(kIODisplayBrightnessKey),
                                       &brightness);
            
            IOObjectRelease(service);
        }
    }
    
    return brightness;
}

- (void)setDisplayBrightness:(float)brightness {
    io_iterator_t iterator;
    kern_return_t result =
    IOServiceGetMatchingServices(kIOMasterPortDefault,
                                 IOServiceMatching("IODisplayConnect"),
                                 &iterator);
    
    if (result == kIOReturnSuccess) {
        io_object_t service;
        
        while ((service = IOIteratorNext(iterator)) != MACH_PORT_NULL) {
            IODisplaySetFloatParameter(service,
                                       kNilOptions,
                                       CFSTR(kIODisplayBrightnessKey),
                                       brightness);
            
            IOObjectRelease(service);
        }
    }
}

// MARK: - Menu delegate methods

- (void)menuNeedsUpdate:(NSMenu *)menu {
    self.brightnessSlider.doubleValue = [self getDisplayBrightness];
    self.tintImageView.image = [NSImage roundedRectImageWithSize:NSMakeSize(16, 16)
                                                        andColor:self.selectedColor];
    
    NSMenuItem *enableTintItem = [menu itemWithTag:kEnableTintMenuItemTag];
    [enableTintItem setState:self.tintIsEnabled ? NSControlStateValueOn : NSControlStateValueOff];
    
    NSMenuItem *tintItem = [menu itemWithTag:kSetTintMenuItemTag];
    NSStackView *tintView = (NSStackView *)tintItem.view;
    tintView.edgeInsets = NSEdgeInsetsMake(3, MAX([menu stateColumnWidth], 6), 3, 10);
}

// MARK: - Window delegate methods

- (void)windowDidChangeScreen:(NSNotification *)notification {
    NSWindow *window = notification.object;
    [window setFrame:window.screen.frame display:YES];
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSApplication *app = NSApplication.sharedApplication;
        app.activationPolicy = NSApplicationActivationPolicyAccessory;
        
        DisplayTint *displayTint = [DisplayTint new];
        displayTint.selectedColor = [NSColor colorWithRed:0.58 green:0.46 blue:0.35 alpha:1];
        displayTint.tintIsEnabled = YES;
        
        // Setup the menu
        
        NSStatusItem *statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSSquareStatusItemLength];
        statusItem.button.image = [NSImage imageWithSystemSymbolName:@"photo.tv"
                                            accessibilityDescription:nil];
        statusItem.menu = [NSMenu new];
        statusItem.menu.minimumWidth = 220;
        statusItem.menu.autoenablesItems = NO;
        statusItem.menu.delegate = displayTint;
        
        [statusItem.menu addItemWithTitle:@"Brightness"
                                   action:nil
                            keyEquivalent:@""].enabled = NO;
        
        NSSlider *brightnessSlider = [NSSlider sliderWithValue:0.0f
                                                      minValue:0.0f
                                                      maxValue:1.0f
                                                        target:displayTint
                                                        action:@selector(adjustBrightness:)];
        brightnessSlider.translatesAutoresizingMaskIntoConstraints = NO;
        NSView *brightnessView = [NSView new];
        brightnessView.translatesAutoresizingMaskIntoConstraints = NO;
        [brightnessView addSubview:brightnessSlider];
        
        [NSLayoutConstraint activateConstraints:@[
            [brightnessSlider.leftAnchor constraintEqualToAnchor:brightnessView.leftAnchor constant:14],
            [brightnessSlider.rightAnchor constraintEqualToAnchor:brightnessView.rightAnchor constant:-14],
            [brightnessSlider.topAnchor constraintEqualToAnchor:brightnessView.topAnchor],
            [brightnessSlider.bottomAnchor constraintEqualToAnchor:brightnessView.bottomAnchor]
        ]];
        
        NSMenuItem *brightnessItem = [NSMenuItem new];
        brightnessItem.view = brightnessView;
        [statusItem.menu addItem:brightnessItem];
        
        [statusItem.menu addItem:[NSMenuItem separatorItem]];
        
        [statusItem.menu addItemWithTitle:@"Tint"
                                   action:nil
                            keyEquivalent:@""].enabled = NO;
        
        NSTextField *tintLabel = [NSTextField labelWithString:@"Set Tint..."];
        NSImageView *tintImageView = [NSImageView imageViewWithImage:[NSImage roundedRectImageWithSize:NSMakeSize(16, 16)
                                                                                              andColor:displayTint.selectedColor]];
        NSStackView *tintView = [NSStackView stackViewWithViews:@[tintLabel, tintImageView]];
        tintView.distribution = NSStackViewDistributionEqualSpacing;
        
        NSMenuItem *tintItem = [NSMenuItem new];
        tintItem._viewHandlesEvents = NO;
        tintItem.view = tintView;
        tintItem.action = @selector(chooseColor:);
        tintItem.target = displayTint;
        tintItem.tag = kSetTintMenuItemTag;
        [statusItem.menu addItem:tintItem];
        
        NSMenuItem *enableTintItem = [statusItem.menu addItemWithTitle:@"Enable Tint"
                                                                action:@selector(toggleEnableTint:)
                                                         keyEquivalent:@""];
        enableTintItem.target = displayTint;
        enableTintItem.tag = kEnableTintMenuItemTag;
        
        [statusItem.menu addItem:[NSMenuItem separatorItem]];
        
        [statusItem.menu addItemWithTitle:@"Quit"
                                   action:@selector(terminate:)
                            keyEquivalent:@"q"];
        
        // Setup the overlay window
        
        NSWindow *overlayWindow = [[NSWindow alloc] initWithContentRect:NSZeroRect
                                                              styleMask:0
                                                                backing:NSBackingStoreBuffered
                                                                  defer:NO];
        overlayWindow.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorStationary | NSWindowCollectionBehaviorIgnoresCycle;
        overlayWindow.level = CGShieldingWindowLevel();
        overlayWindow.ignoresMouseEvents = YES;
        overlayWindow.opaque = NO;
        overlayWindow.alphaValue = 0.25;
        overlayWindow.backgroundColor = displayTint.selectedColor;
        overlayWindow.delegate = displayTint;
        
        [overlayWindow setFrame:NSScreen.mainScreen.frame display:YES];
        
        // Give access to views and windows to the delegate
        
        displayTint.overlayWindow = overlayWindow;
        displayTint.brightnessSlider = brightnessSlider;
        displayTint.tintImageView = tintImageView;
        
        [displayTint updateOverlayState];
        
        [app run];
    }
    return EXIT_SUCCESS;
}
