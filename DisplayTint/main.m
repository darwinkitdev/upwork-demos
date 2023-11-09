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

@interface MenuItemView : NSView
@property (weak) NSVisualEffectView *effectView;
@property (weak) NSStackView *stackView;
@end

@implementation MenuItemView {
    NSTrackingArea *trackingArea;
}

- (instancetype)init {
    if (self = [super init]) {
        NSVisualEffectView *effectView = [NSVisualEffectView new];
        effectView.translatesAutoresizingMaskIntoConstraints = NO;
        effectView.state = NSVisualEffectStateActive;
        effectView.material = NSVisualEffectMaterialSelection;
        effectView.emphasized = YES;
        effectView.blendingMode = NSVisualEffectBlendingModeBehindWindow;
        effectView.hidden = YES;
        effectView.wantsLayer = YES;
        effectView.layer.cornerRadius = 4;
        [self addSubview:effectView];
        self.effectView = effectView;
        [NSLayoutConstraint activateConstraints:@[
            [effectView.leftAnchor constraintEqualToAnchor:self.leftAnchor constant:5],
            [effectView.rightAnchor constraintEqualToAnchor:self.rightAnchor constant:-5],
            [effectView.topAnchor constraintEqualToAnchor:self.topAnchor],
            [effectView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor]
        ]];
        
        NSStackView *stackView = [NSStackView stackViewWithViews:@[]];
        stackView.translatesAutoresizingMaskIntoConstraints = NO;
        stackView.distribution = NSStackViewDistributionEqualSpacing;
        [self addSubview:stackView];
        self.stackView = stackView;
        [NSLayoutConstraint activateConstraints:@[
            [stackView.leftAnchor constraintEqualToAnchor:self.leftAnchor constant:12],
            [stackView.rightAnchor constraintEqualToAnchor:self.rightAnchor constant:-14],
            [stackView.topAnchor constraintEqualToAnchor:self.topAnchor constant:3],
            [stackView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-3]
        ]];
    }
    return self;
}

- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    [self.window becomeKeyWindow];
}

- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    if (trackingArea) {
        [self removeTrackingArea:trackingArea];
    }
    trackingArea = [[NSTrackingArea alloc] initWithRect:self.bounds
                                                        options:NSTrackingMouseEnteredAndExited | NSTrackingMouseMoved | NSTrackingActiveAlways
                                                          owner:self
                                                       userInfo:nil];
    [self addTrackingArea:trackingArea];
}

- (void)mouseExited:(NSEvent *)event {
    self.effectView.hidden = YES;
}

- (void)mouseMoved:(NSEvent *)event {
    self.effectView.hidden = !self.enclosingMenuItem.isHighlighted;
}

- (void)mouseUp:(NSEvent *)event {
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull context) {
        context.duration = 0.05;
        self.effectView.animator.alphaValue = 0;
    } completionHandler:^{
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull context) {
            context.duration = 0.1;
            self.effectView.animator.alphaValue = 1;
        } completionHandler:^{
            NSMenuItem *menuItem = self.enclosingMenuItem;
            NSMenu *menu = menuItem.menu;
            [menu cancelTracking];
            [menu performActionForItemAtIndex:[menu indexOfItem:menuItem]];
            self.effectView.hidden = YES;
        }];
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
    MenuItemView *tintView = (MenuItemView *)tintItem.view;
    tintView.stackView.edgeInsets = NSEdgeInsetsMake(0, [menu stateColumnWidth] - 6, 0, 0);
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
        MenuItemView *tintView = [MenuItemView new];
        tintView.translatesAutoresizingMaskIntoConstraints = NO;
        [tintView.stackView setViews:@[tintLabel, tintImageView]
                           inGravity:NSStackViewGravityCenter];
        
        NSMenuItem *tintItem = [NSMenuItem new];
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
                                                              styleMask:NSWindowStyleMaskBorderless
                                                                backing:NSBackingStoreBuffered
                                                                  defer:NO];
        overlayWindow.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorStationary;
        overlayWindow.level = NSScreenSaverWindowLevel;
        overlayWindow.ignoresMouseEvents = YES;
        overlayWindow.hasShadow = NO;
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
