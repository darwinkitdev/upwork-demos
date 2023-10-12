//
//  main.m
//  AudioSnap
//
//  Created by Eric Maciel on 09/10/23.
//

#import <AVFAudio/AVFAudio.h>
#import <Cocoa/Cocoa.h>
#import <CoreAudio/CoreAudio.h>
#import <ServiceManagement/ServiceManagement.h>

@interface AudioInputDevice : NSObject
@property (assign) AudioObjectID objectId;
@property (strong) NSString *name;
@property (assign) BOOL isDefault;
@end

@implementation AudioInputDevice

+ (AudioObjectID)defaultDevice {
    AudioObjectPropertyAddress property = {
        kAudioHardwarePropertyDefaultInputDevice,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMain
    };
    
    OSStatus status;
    UInt32 size;
    
    status = AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &property, 0, NULL, &size);
    if (status != noErr) {
        return kAudioDeviceUnknown;
    }
    
    AudioObjectID deviceId;
    status = AudioObjectGetPropertyData(kAudioObjectSystemObject, &property, 0, NULL, &size, &deviceId);
    if (status != noErr) {
        return kAudioDeviceUnknown;
    }
    
    return deviceId;
}

+ (NSArray *)allDevices {
    AudioObjectPropertyAddress property = {
        kAudioHardwarePropertyDevices,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMain
    };
    
    OSStatus status;
    UInt32 size;
    
    status = AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &property, 0, NULL, &size);
    if (status != noErr) {
        return @[];
    }
    
    AudioObjectID *allDeviceIds = malloc(size);
    status = AudioObjectGetPropertyData(kAudioObjectSystemObject, &property, 0, NULL, &size, allDeviceIds);
    
    NSMutableArray *allDevices = [NSMutableArray array];
    
    if (status == noErr) {
        AudioObjectID defaultDevice = [self defaultDevice];
        
        NSInteger numberOfDevices = size / sizeof(AudioObjectID);
        for (NSInteger i = 0; i < numberOfDevices; i++) {
            if ([self numberOfStreamsFor:allDeviceIds[i]] > 0) {
                AudioInputDevice *device = [self audioDeviceFor:allDeviceIds[i]];
                device.isDefault = defaultDevice == allDeviceIds[i];
                [allDevices addObject:device];
            }
        }
    }
    
    free(allDeviceIds);
    
    return allDevices;
}

+ (NSInteger)numberOfStreamsFor:(AudioObjectID)objectId {
    AudioObjectPropertyAddress property = {
        kAudioDevicePropertyStreams,
        kAudioObjectPropertyScopeInput,
        kAudioObjectPropertyElementMain
    };
    
    OSStatus status;
    UInt32 size;
    
    status = AudioObjectGetPropertyDataSize(objectId, &property, 0, NULL, &size);
    if (status != noErr) {
        return 0;
    }
    
    return size / sizeof(AudioStreamID);
}

+ (NSString *)deviceNameFor:(AudioObjectID)objectId defaultName:(NSString *)defaultName {
    AudioObjectPropertyAddress property = {
        kAudioDevicePropertyDeviceNameCFString,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMain
    };
    
    OSStatus status;
    UInt32 size;
    
    status = AudioObjectGetPropertyDataSize(objectId, &property, 0, NULL, &size);
    if (status != noErr) {
        return defaultName;
    }
    
    CFStringRef string;
    status = AudioObjectGetPropertyData(objectId, &property, 0, NULL, &size, &string);
    if (status != noErr) {
        return defaultName;
    }
    
    return CFBridgingRelease(string);
}

+ (AudioInputDevice *)audioDeviceFor:(AudioObjectID)objectId {
    AudioInputDevice *device = [AudioInputDevice new];
    device.objectId = objectId;
    device.name = [self deviceNameFor:objectId defaultName:@"Unknown Device"];
    return device;
}

- (void)setAsDefault {
    AudioObjectPropertyAddress property = {
        kAudioHardwarePropertyDefaultInputDevice,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMain
    };
    AudioObjectSetPropertyData(kAudioObjectSystemObject, &property, 0, NULL, sizeof(AudioObjectID), &_objectId);
}

@end

@implementation NSImage (Tint)

- (NSImage *)imageWithTintColor:(NSColor *)tintColor {
    NSImage *image = [self copy];
    [image lockFocus];
    [tintColor setFill];
    NSRect imageRect = {.origin = NSZeroPoint, .size = image.size};
    NSRectFillUsingOperation(imageRect, NSCompositingOperationSourceAtop);
    [image unlockFocus];
    image.template = NO;
    return image;
}

@end

@interface AudioSnap : NSObject <NSMenuDelegate>
@end

@implementation AudioSnap {
    BOOL isRecording;
    AVAudioRecorder *recorder;
    NSTimer *recordingTimer;
    NSDateComponentsFormatter *timeFormatter;
    NSDateFormatter *dateFormatter;
    
    NSImage *micImage;
    NSStatusItem *statusItem;
    NSTextField *timeLabel;
    NSStackView *statusView;
    NSArray *constraints;
}

- (void)setup {
    micImage = [NSImage imageWithSystemSymbolName:@"music.mic"
                         accessibilityDescription:nil];
    
    statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
    statusItem.behavior = NSStatusItemBehaviorTerminationOnRemoval;
    statusItem.visible = YES;
    statusItem.button.image = micImage;
    statusItem.menu = [NSMenu new];
    statusItem.menu.delegate = self;
    
    timeLabel = [NSTextField labelWithString:@"00:00"];
    timeLabel.font = [NSFont monospacedDigitSystemFontOfSize:statusItem.button.font.pointSize
                                                      weight:NSFontWeightRegular];
    NSImage *recordImage = [[NSImage imageWithSystemSymbolName:@"record.circle"
                                      accessibilityDescription:nil] imageWithTintColor:NSColor.redColor];
    NSButton *stopButton = [NSButton buttonWithImage:recordImage
                                              target:self
                                              action:@selector(toggleRecording:)];
    stopButton.bordered = NO;
    statusView = [NSStackView stackViewWithViews:@[timeLabel, stopButton]];
    
    constraints = @[
        [statusView.leftAnchor constraintEqualToAnchor:statusItem.button.leftAnchor constant:4],
        [statusView.rightAnchor constraintEqualToAnchor:statusItem.button.rightAnchor constant:-4],
        [statusView.topAnchor constraintEqualToAnchor:statusItem.button.topAnchor constant:4],
        [statusView.bottomAnchor constraintEqualToAnchor:statusItem.button.bottomAnchor constant:-4]
    ];
    
    timeFormatter = [NSDateComponentsFormatter new];
    timeFormatter.zeroFormattingBehavior = NSDateComponentsFormatterZeroFormattingBehaviorPad;
    timeFormatter.allowedUnits = NSCalendarUnitMinute | NSCalendarUnitSecond;
    
    dateFormatter = [NSDateFormatter new];
    dateFormatter.dateFormat = @"yy-MM-dd 'at' HH.mm.ss";
}

// MARK: - File methods

- (NSString *)newFileName {
    NSString *dateTime = [dateFormatter stringFromDate:[NSDate new]];
    return [NSString stringWithFormat:@"AudioSnap %@.mp4", dateTime];
}

- (NSURL *)newFileURL {
    NSURL *downloadsURL = [NSFileManager.defaultManager URLsForDirectory:NSDownloadsDirectory
                                                               inDomains:NSUserDomainMask][0];
    return [downloadsURL URLByAppendingPathComponent:[self newFileName]];
}

// MARK: - Recording methods

- (void)startRecording {
    NSDictionary *settings = @{
        AVFormatIDKey: @(kAudioFormatMPEG4AAC),
        AVSampleRateKey: @22050,
        AVNumberOfChannelsKey: @1,
        AVLinearPCMBitDepthKey: @16,
        AVEncoderBitRateKey: @32000,
        AVEncoderAudioQualityKey: @(AVAudioQualityHigh)
    };
    recorder = [[AVAudioRecorder alloc] initWithURL:[self newFileURL]
                                           settings:settings
                                              error:nil];
    
    // Avoid blocking the interface
    dispatch_async(dispatch_get_main_queue(), ^{
        [self->recorder record];
    });
}

- (void)stopRecording {
    [recorder stop];
    recorder = nil;
}

// MARK: - Timer methods

- (void)startTimer {
    recordingTimer = [NSTimer scheduledTimerWithTimeInterval:1
                                                      target:self
                                                    selector:@selector(tick:)
                                                    userInfo:timeFormatter
                                                     repeats:YES];
}

- (void)tick:(NSTimer *)timer {
    timeLabel.stringValue = [timeFormatter stringFromTimeInterval:recorder.currentTime];
}

- (void)stopTimer {
    [recordingTimer invalidate];
    recordingTimer = nil;
}

// MARK: - Action methods

- (void)toggleRecording:(NSMenuItem *)sender {
    isRecording = !isRecording;
    if (isRecording) {
        [self startRecording];
        [self startTimer];
        
        // Setup recording interface
        [statusItem.button addSubview:statusView];
        [NSLayoutConstraint activateConstraints:constraints];
        statusItem.button.image = nil;
    } else {
        [self stopTimer];
        [self stopRecording];
        
        // Setup stopped interface
        timeLabel.stringValue = @"00:00";
        [NSLayoutConstraint deactivateConstraints:constraints];
        [statusView removeFromSuperview];
        statusItem.button.image = micImage;
    }
}

- (void)selectDefaultDevice:(NSMenuItem *)sender {
    [(AudioInputDevice *)sender.representedObject setAsDefault];
}

// MARK: - Launch at login methods

static NSString *launcherBundleId = @"com.demos.AudioSnap-Launcher";

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

// MARK: - Menu delegate methods

- (void)menuNeedsUpdate:(NSMenu *)menu {
    [menu removeAllItems];
    
    NSString *recordTitle = isRecording ? @"Stop Recording" : @"Record";
    NSMenuItem *recordItem = [menu addItemWithTitle:recordTitle
                                             action:@selector(toggleRecording:)
                                      keyEquivalent:@""];
    recordItem.target = self;
    
    NSFont *boldFont = [NSFont boldSystemFontOfSize:menu.font.pointSize];
    NSDictionary *attributes = @{
        NSFontAttributeName: boldFont
    };
    NSAttributedString *attributedTitle = [[NSAttributedString alloc] initWithString:recordItem.title
                                                                          attributes:attributes];
    recordItem.attributedTitle = attributedTitle;
    
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:@"Input Device"
                    action:nil
             keyEquivalent:@""];
    
    NSArray *allDevices = [AudioInputDevice allDevices];
    for (AudioInputDevice *device in allDevices) {
        NSMenuItem *item = [menu addItemWithTitle:device.name
                                           action:@selector(selectDefaultDevice:)
                                    keyEquivalent:@""];
        item.target = self;
        item.representedObject = device;
        [item setState:device.isDefault ? NSControlStateValueOn : NSControlStateValueOff];
    }
    
    [menu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *launchAtLoginItem = [menu addItemWithTitle:@"Launch at Login"
                                                    action:@selector(toggleLaunchAtLogin:)
                                             keyEquivalent:@""];
    launchAtLoginItem.target = self;
    [launchAtLoginItem setState:[self isLaunchAtLoginEnabled] ? NSControlStateValueOn : NSControlStateValueOff];
    [menu addItemWithTitle:@"Quit"
                    action:@selector(terminate:)
             keyEquivalent:@"q"].target = NSApplication.sharedApplication;
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSApplication *app = NSApplication.sharedApplication;
        app.activationPolicy = NSApplicationActivationPolicyAccessory;
        AudioSnap *audioSnap = [AudioSnap new];
        [audioSnap setup];
        [app run];
    }
    return EXIT_SUCCESS;
}
