//
//  main.m
//  SoundHub
//
//  Created by Eric Maciel on 09/10/23.
//

#import <Cocoa/Cocoa.h>
#import <CoreAudio/CoreAudio.h>
#import <ServiceManagement/ServiceManagement.h>

@interface AudioDevice : NSObject
@property (assign) AudioObjectID objectId;
@property (strong) NSString *name;
@property (assign) BOOL hasInput;
@property (assign) BOOL hasOutput;
@property (assign) BOOL isDefaultInput;
@property (assign) BOOL isDefaultOutput;
@end

@implementation AudioDevice

+ (AudioObjectID)defaultDevice:(AudioObjectPropertySelector)selector {
    AudioObjectPropertyAddress property = {
        selector,
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
        AudioObjectID defaultInput = [self defaultDevice:kAudioHardwarePropertyDefaultInputDevice];
        AudioObjectID defaultOutput = [self defaultDevice:kAudioHardwarePropertyDefaultOutputDevice];
        
        NSInteger numberOfDevices = size / sizeof(AudioObjectID);
        for (NSInteger i = 0; i < numberOfDevices; i++) {
            AudioDevice *device = [self audioDeviceFor:allDeviceIds[i]];
            device.isDefaultInput = defaultInput == allDeviceIds[i];
            device.isDefaultOutput = defaultOutput == allDeviceIds[i];
            [allDevices addObject:device];
        }
    }
    
    free(allDeviceIds);
    
    return allDevices;
}

+ (NSInteger)numberOfStreamsFor:(AudioObjectID)objectId inScope:(AudioObjectPropertyScope)scope {
    AudioObjectPropertyAddress property = {
        kAudioDevicePropertyStreams,
        scope,
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

+ (AudioDevice *)audioDeviceFor:(AudioObjectID)objectId {
    AudioDevice *device = [[AudioDevice alloc] init];
    device.objectId = objectId;
    device.name = [self deviceNameFor:objectId defaultName:@"Unknown Device"];
    device.hasInput = [self numberOfStreamsFor:objectId inScope:kAudioObjectPropertyScopeInput] > 0;
    device.hasOutput = [self numberOfStreamsFor:objectId inScope:kAudioObjectPropertyScopeOutput] > 0;
    return device;
}

- (void)setAsDefault:(AudioObjectPropertySelector)selector {
    AudioObjectPropertyAddress property = {
        selector,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMain
    };
    AudioObjectSetPropertyData(kAudioObjectSystemObject, &property, 0, NULL, sizeof(AudioObjectID), &_objectId);
}

@end

@interface SoundHub : NSObject <NSMenuDelegate>
@end

@implementation SoundHub

- (void)showSoundSettings {
    NSURL *url = [NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.sound"];
    [NSWorkspace.sharedWorkspace openURL:url];
}

// MARK: - Menu delegate methods

- (void)menuNeedsUpdate:(NSMenu *)menu {
    [menu removeAllItems];
    [menu addItemWithTitle:@"Output" action:nil keyEquivalent:@""];
    
    NSArray *allDevices = [AudioDevice allDevices];
    
    for (AudioDevice *device in allDevices) {
        if (device.hasOutput) {
            NSMenuItem *item = [menu addItemWithTitle:device.name
                                               action:@selector(selectDefaultOutputDevice:)
                                        keyEquivalent:@""];
            item.target = self;
            item.representedObject = device;
            [item setState:device.isDefaultOutput ? NSControlStateValueOn : NSControlStateValueOff];
        }
    }
    
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:@"Input" action:nil keyEquivalent:@""];
    
    for (AudioDevice *device in allDevices) {
        if (device.hasInput) {
            NSMenuItem *item = [menu addItemWithTitle:device.name
                                               action:@selector(selectDefaultInputDevice:)
                                        keyEquivalent:@""];
            item.target = self;
            item.representedObject = device;
            [item setState:device.isDefaultInput ? NSControlStateValueOn : NSControlStateValueOff];
        }
    }
    
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:@"Sound Settings..."
                    action:@selector(showSoundSettings)
             keyEquivalent:@""].target = self;
    
    [menu addItemWithTitle:@"Quit"
                    action:@selector(terminate:)
             keyEquivalent:@"q"].target = NSApplication.sharedApplication;
}

- (void)selectDefaultOutputDevice:(NSMenuItem *)sender {
    [(AudioDevice *)sender.representedObject setAsDefault:kAudioHardwarePropertyDefaultOutputDevice];
}

- (void)selectDefaultInputDevice:(NSMenuItem *)sender {
    [(AudioDevice *)sender.representedObject setAsDefault:kAudioHardwarePropertyDefaultInputDevice];
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSApplication *app = NSApplication.sharedApplication;
        app.activationPolicy = NSApplicationActivationPolicyAccessory;
        
        SoundHub *soundHub = [SoundHub new];
        
        NSStatusItem *statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSSquareStatusItemLength];
        statusItem.button.image = [NSImage imageWithSystemSymbolName:@"hifispeaker" accessibilityDescription:nil];
        statusItem.menu = [NSMenu new];
        statusItem.menu.delegate = soundHub;

        [app run];
    }
    return EXIT_SUCCESS;
}
