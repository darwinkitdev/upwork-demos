//
//  main.m
//  PlayBar
//
//  Created by Eric Maciel on 13/10/23.
//

#import <Cocoa/Cocoa.h>
#import <ServiceManagement/ServiceManagement.h>

// MARK: - MediaRemote.framework types

typedef enum {
    /*
     * Use nil for userInfo.
     */
    MRMediaRemoteCommandPlay,
    MRMediaRemoteCommandPause,
    MRMediaRemoteCommandTogglePlayPause,
    MRMediaRemoteCommandStop,
    MRMediaRemoteCommandNextTrack,
    MRMediaRemoteCommandPreviousTrack,
    MRMediaRemoteCommandAdvanceShuffleMode,
    MRMediaRemoteCommandAdvanceRepeatMode,
    MRMediaRemoteCommandBeginFastForward,
    MRMediaRemoteCommandEndFastForward,
    MRMediaRemoteCommandBeginRewind,
    MRMediaRemoteCommandEndRewind,
    MRMediaRemoteCommandRewind15Seconds,
    MRMediaRemoteCommandFastForward15Seconds,
    MRMediaRemoteCommandRewind30Seconds,
    MRMediaRemoteCommandFastForward30Seconds,
    MRMediaRemoteCommandToggleRecord,
    MRMediaRemoteCommandSkipForward,
    MRMediaRemoteCommandSkipBackward,
    MRMediaRemoteCommandChangePlaybackRate,
    
    /*
     * Use a NSDictionary for userInfo, which contains three keys:
     * kMRMediaRemoteOptionTrackID
     * kMRMediaRemoteOptionStationID
     * kMRMediaRemoteOptionStationHash
     */
    MRMediaRemoteCommandRateTrack,
    MRMediaRemoteCommandLikeTrack,
    MRMediaRemoteCommandDislikeTrack,
    MRMediaRemoteCommandBookmarkTrack,
    
    /*
     * Use nil for userInfo.
     */
    MRMediaRemoteCommandSeekToPlaybackPosition,
    MRMediaRemoteCommandChangeRepeatMode,
    MRMediaRemoteCommandChangeShuffleMode,
    MRMediaRemoteCommandEnableLanguageOption,
    MRMediaRemoteCommandDisableLanguageOption
} MRMediaRemoteCommand;

typedef void (*MRMediaRemoteRegisterForNowPlayingNotificationsFunction)(dispatch_queue_t queue);
typedef void (*MRMediaRemoteUnregisterForNowPlayingNotificationsFunction)(void);
typedef void (*MRMediaRemoteGetNowPlayingInfoFunction)(dispatch_queue_t queue, void (^handler)(NSDictionary* information));
typedef void (*MRMediaRemoteGetNowPlayingApplicationIsPlayingFunction)(dispatch_queue_t queue, void (^handler)(BOOL isPlaying));
typedef Boolean (*MRMediaRemoteSendCommandFunction)(MRMediaRemoteCommand cmd, NSDictionary* userInfo);

// MARK: - Application components

@interface PaddedButton : NSButton
@end

@implementation PaddedButton

- (NSSize)intrinsicContentSize {
    NSSize size = [super intrinsicContentSize];
    size.width += 8;
    size.height += 8;
    return size;
}

@end

@implementation NSString (Truncate)

- (NSString *)stringByTruncatingMaxLength:(NSUInteger)maxLength {
    return self.length > maxLength ? [[self substringToIndex:maxLength] stringByAppendingString:@"…"] : self;
}

@end

@interface PlayBar : NSObject <NSMenuDelegate>
@end

@implementation PlayBar {
    NSStatusItem *statusItem;
    
    // Menu views
    NSButton *playButton;
    NSButton *pauseButton;
    NSTextField *songLabel;
    NSTextField *artistLabel;
    
    // Menu Bar views
    NSStackView *menuBarControlsView;
    NSStackView *menuBarSongView;
    NSButton *menuBarPlayButton;
    NSButton *menuBarPausebutton;
    NSTextField *menuBarSongLabel;
    NSTextField *menuBarArtistLabel;
    
    // MediaRemote functions
    MRMediaRemoteRegisterForNowPlayingNotificationsFunction MRMediaRemoteRegisterForNowPlayingNotifications;
    MRMediaRemoteUnregisterForNowPlayingNotificationsFunction MRMediaRemoteUnregisterForNowPlayingNotifications;
    MRMediaRemoteGetNowPlayingInfoFunction MRMediaRemoteGetNowPlayingInfo;
    MRMediaRemoteGetNowPlayingApplicationIsPlayingFunction MRMediaRemoteGetNowPlayingApplicationIsPlaying;
    MRMediaRemoteSendCommandFunction MRMediaRemoteSendCommand;
}

// UserDefaults keys
NSString *const kShowSongInMenuBarUserDefaultsKey = @"kShowSongInMenuBarUserDefaultsKey";
NSString *const kShowControlsInMenuBarUserDefaultsKey = @"kShowControlsInMenuBarUserDefaultsKey";

- (void)setup {
    statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
    
    [self setupMenuBarControls];
    [self setupMenu];
    [self setupMediaRemote];
}

- (void)setupMediaRemote {
    // Load MediaRemote framework
    CFURLRef ref = (__bridge CFURLRef) [NSURL fileURLWithPath:@"/System/Library/PrivateFrameworks/MediaRemote.framework"];
    CFBundleRef bundle = CFBundleCreate(kCFAllocatorDefault, ref);
    
    // Load MediaRemote functions
    MRMediaRemoteRegisterForNowPlayingNotifications = (MRMediaRemoteRegisterForNowPlayingNotificationsFunction) CFBundleGetFunctionPointerForName(bundle, CFSTR("MRMediaRemoteRegisterForNowPlayingNotifications"));
    MRMediaRemoteUnregisterForNowPlayingNotifications = (MRMediaRemoteUnregisterForNowPlayingNotificationsFunction) CFBundleGetFunctionPointerForName(bundle, CFSTR("MRMediaRemoteUnregisterForNowPlayingNotifications"));;;
    MRMediaRemoteGetNowPlayingInfo = (MRMediaRemoteGetNowPlayingInfoFunction) CFBundleGetFunctionPointerForName(bundle, CFSTR("MRMediaRemoteGetNowPlayingInfo"));
    MRMediaRemoteGetNowPlayingApplicationIsPlaying = (MRMediaRemoteGetNowPlayingApplicationIsPlayingFunction) CFBundleGetFunctionPointerForName(bundle, CFSTR("MRMediaRemoteGetNowPlayingApplicationIsPlaying"));
    MRMediaRemoteSendCommand = (MRMediaRemoteSendCommandFunction) CFBundleGetFunctionPointerForName(bundle, CFSTR("MRMediaRemoteSendCommand"));
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(applicationDidChange:)
                                               name:@"kMRMediaRemoteNowPlayingApplicationDidChangeNotification"
                                             object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(nowPlayingInfoDidChange:)
                                               name:@"kMRMediaRemoteNowPlayingInfoDidChangeNotification"
                                             object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(isPlayingDidChange:)
                                               name:@"kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification"
                                             object:nil];
    
    MRMediaRemoteRegisterForNowPlayingNotifications(dispatch_get_main_queue());
    
    [self updateNowPlayingInfo];
    [self updateIsPlayingInfo];
}

- (void)setupMenu {
    statusItem.menu = [NSMenu new];
    statusItem.menu.delegate = self;
    
    // Create menu bar settings
    
    NSMenuItem *showSongItem = [statusItem.menu addItemWithTitle:@"Show Song in Menu Bar"
                                                          action:@selector(toggleShowSongInMenuBar:)
                                                   keyEquivalent:@""];
    showSongItem.target = self;
    showSongItem.tag = 100;
    
    NSMenuItem *showControlsItem = [statusItem.menu addItemWithTitle:@"Show Controls in Menu Bar"
                                                              action:@selector(toggleShowControlsInMenuBar:)
                                                       keyEquivalent:@""];
    showControlsItem.target = self;
    showControlsItem.tag = 101;
    
    [statusItem.menu addItem:[NSMenuItem separatorItem]];
    
    // Create menu player controls
    
    NSImageSymbolConfiguration *configMedium = [NSImageSymbolConfiguration configurationWithPointSize:18
                                                                                               weight:NSFontWeightRegular
                                                                                                scale:NSImageSymbolScaleMedium];
    NSImageSymbolConfiguration *configLarge = [NSImageSymbolConfiguration configurationWithPointSize:20
                                                                                              weight:NSFontWeightRegular
                                                                                               scale:NSImageSymbolScaleLarge];
    
    playButton = [NSButton buttonWithImage:[[NSImage imageWithSystemSymbolName:@"play.fill"
                                                      accessibilityDescription:@""] imageWithSymbolConfiguration:configLarge]
                                    target:self
                                    action:@selector(play:)];
    playButton.bordered = NO;
    pauseButton = [NSButton buttonWithImage:[[NSImage imageWithSystemSymbolName:@"pause.fill"
                                                       accessibilityDescription:@""] imageWithSymbolConfiguration:configLarge]
                                     target:self
                                     action:@selector(pause:)];
    pauseButton.bordered = NO;
    pauseButton.hidden = YES;
    NSButton *prevButton = [NSButton buttonWithImage:[[NSImage imageWithSystemSymbolName:@"backward.fill"
                                                                accessibilityDescription:@""] imageWithSymbolConfiguration:configMedium]
                                              target:self
                                              action:@selector(goPrevius:)];
    prevButton.bordered = NO;
    NSButton *nextButton = [NSButton buttonWithImage:[[NSImage imageWithSystemSymbolName:@"forward.fill"
                                                                accessibilityDescription:@""] imageWithSymbolConfiguration:configMedium]
                                              target:self
                                              action:@selector(goNext:)];
    nextButton.bordered = NO;
    
    NSStackView *controlsView = [NSStackView stackViewWithViews:@[prevButton, playButton, pauseButton, nextButton]];
    controlsView.spacing = 14;
    [controlsView.heightAnchor constraintEqualToConstant:26].active = YES;
    
    songLabel = [NSTextField labelWithString:@"No song title"];
    artistLabel = [NSTextField labelWithString:@"No artist name"];
    songLabel.font = artistLabel.font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
    songLabel.textColor = artistLabel.textColor = NSColor.secondaryLabelColor;
    
    NSStackView *contentView = [NSStackView stackViewWithViews:@[controlsView, songLabel, artistLabel]];
    contentView.orientation = NSUserInterfaceLayoutOrientationVertical;
    contentView.edgeInsets = NSEdgeInsetsMake(16, 0, 16, 0);
    [contentView setCustomSpacing:0 afterView:songLabel];
    
    NSMenuItem *controlsItem = [NSMenuItem new];
    controlsItem.view = contentView;
    [statusItem.menu addItem:controlsItem];
    
    [statusItem.menu addItem:[NSMenuItem separatorItem]];
    
    // Create quit item
    
    [statusItem.menu addItemWithTitle:@"Quit"
                               action:@selector(terminate:)
                        keyEquivalent:@"q"].target = NSApplication.sharedApplication;
}

- (void)setupMenuBarControls {
    NSImageSymbolConfiguration *configSmall = [NSImageSymbolConfiguration configurationWithScale:NSImageSymbolScaleSmall];
    NSImageSymbolConfiguration *configMedium = [NSImageSymbolConfiguration configurationWithScale:NSImageSymbolScaleMedium];
    menuBarPlayButton = [PaddedButton buttonWithImage:[[NSImage imageWithSystemSymbolName:@"play.fill"
                                                                 accessibilityDescription:@""] imageWithSymbolConfiguration:configMedium]
                                               target:self
                                               action:@selector(play:)];
    menuBarPlayButton.bordered = NO;
    menuBarPausebutton = [PaddedButton buttonWithImage:[[NSImage imageWithSystemSymbolName:@"pause.fill"
                                                                  accessibilityDescription:@""] imageWithSymbolConfiguration:configMedium]
                                                target:self
                                                action:@selector(pause:)];
    menuBarPausebutton.bordered = NO;
    menuBarPausebutton.hidden = YES;
    NSButton *prevButton = [PaddedButton buttonWithImage:[[NSImage imageWithSystemSymbolName:@"backward.fill"
                                                                    accessibilityDescription:@""] imageWithSymbolConfiguration:configSmall]
                                                  target:self
                                                  action:@selector(goPrevius:)];
    prevButton.bordered = NO;
    NSButton *nextButton = [PaddedButton buttonWithImage:[[NSImage imageWithSystemSymbolName:@"forward.fill"
                                                                    accessibilityDescription:@""] imageWithSymbolConfiguration:configSmall]
                                                  target:self
                                                  action:@selector(goNext:)];
    nextButton.bordered = NO;
    
    NSImageView *imageView = [NSImageView imageViewWithImage:[NSImage imageWithSystemSymbolName:@"music.note.house"
                                                                       accessibilityDescription:nil]];
    
    menuBarControlsView = [NSStackView stackViewWithViews:@[prevButton, menuBarPlayButton, menuBarPausebutton, nextButton]];
    menuBarControlsView.spacing = 0;
    menuBarControlsView.hidden = ![NSUserDefaults.standardUserDefaults boolForKey:kShowSongInMenuBarUserDefaultsKey];
    
    menuBarSongLabel = [NSTextField labelWithString:@"No song title"];
    menuBarArtistLabel = [NSTextField labelWithString:@"No artist name"];
    menuBarSongLabel.font = menuBarArtistLabel.font = [NSFont systemFontOfSize:10];
    
    menuBarSongView = [NSStackView stackViewWithViews:@[menuBarSongLabel, menuBarArtistLabel]];
    menuBarSongView.orientation = NSUserInterfaceLayoutOrientationVertical;
    menuBarSongView.spacing = 0;
    menuBarSongView.hidden = ![NSUserDefaults.standardUserDefaults boolForKey:kShowSongInMenuBarUserDefaultsKey];
    
    NSStackView *contentView = [NSStackView stackViewWithViews:@[menuBarSongView, menuBarControlsView, imageView]];
    contentView.edgeInsets = NSEdgeInsetsMake(8, 8, 8, 8);
    
    [statusItem.button addSubview:contentView];
    
    NSArray *constraints = @[
        [contentView.leftAnchor constraintEqualToAnchor:statusItem.button.leftAnchor],
        [contentView.rightAnchor constraintEqualToAnchor:statusItem.button.rightAnchor],
        [contentView.topAnchor constraintEqualToAnchor:statusItem.button.topAnchor],
        [contentView.bottomAnchor constraintEqualToAnchor:statusItem.button.bottomAnchor]
    ];
    
    [NSLayoutConstraint activateConstraints:constraints];
}

- (void)dealloc {
    [super dealloc];
    [NSNotificationCenter.defaultCenter removeObserver:self];
    MRMediaRemoteUnregisterForNowPlayingNotifications();
}

// MARK: - Settings methods

- (void)toggleShowSongInMenuBar:(NSMenuItem *)sender {
    BOOL isSongViewHidden = [NSUserDefaults.standardUserDefaults boolForKey:kShowSongInMenuBarUserDefaultsKey];
    [NSUserDefaults.standardUserDefaults setBool:!isSongViewHidden forKey:kShowSongInMenuBarUserDefaultsKey];
    menuBarSongView.hidden = isSongViewHidden;
    statusItem.button.title = @""; // Force layout update
}

- (void)toggleShowControlsInMenuBar:(NSMenuItem *)sender {
    BOOL isControlsViewHidden = [NSUserDefaults.standardUserDefaults boolForKey:kShowControlsInMenuBarUserDefaultsKey];
    [NSUserDefaults.standardUserDefaults setBool:!isControlsViewHidden forKey:kShowControlsInMenuBarUserDefaultsKey];
    menuBarControlsView.hidden = isControlsViewHidden;
    statusItem.button.title = @""; // Force layout update
}

// MARK: - Controls methods

- (void)play:(NSButton *)sender {
    MRMediaRemoteSendCommand(MRMediaRemoteCommandPlay, nil);
}

- (void)pause:(NSButton *)sender {
    MRMediaRemoteSendCommand(MRMediaRemoteCommandPause, nil);
}

- (void)goPrevius:(NSButton *)sender {
    MRMediaRemoteSendCommand(MRMediaRemoteCommandPreviousTrack, nil);
}

- (void)goNext:(NSButton *)sender {
    MRMediaRemoteSendCommand(MRMediaRemoteCommandNextTrack, nil);
}

// MARK: - State methods

- (void)updateNowPlayingInfo {
    MRMediaRemoteGetNowPlayingInfo(dispatch_get_main_queue(), ^(NSDictionary* information) {
        [self updateSongName:information[@"kMRMediaRemoteNowPlayingInfoTitle"]
                  artistName:information[@"kMRMediaRemoteNowPlayingInfoArtist"]];
    });
}

- (void)updateIsPlayingInfo {
    MRMediaRemoteGetNowPlayingApplicationIsPlaying(dispatch_get_main_queue(), ^(BOOL isPlaying) {
        [self updateIsPlaying:isPlaying];
    });
}

- (void)updateSongName:(NSString *)songName artistName:(NSString *)artistName {
    if (!songName || songName.length == 0) {
        songName = @"No song title";
    }
    if (!artistName || artistName.length == 0) {
        artistName = @"No artist name";
    }
    songLabel.stringValue = menuBarSongLabel.stringValue = [songName stringByTruncatingMaxLength:30];
    artistLabel.stringValue = menuBarArtistLabel.stringValue = [artistName stringByTruncatingMaxLength:30];
    statusItem.button.title = @""; // Force layout update
}

- (void)updateIsPlaying:(BOOL)isPlaying {
    playButton.hidden = menuBarPlayButton.hidden = isPlaying;
    pauseButton.hidden = menuBarPausebutton.hidden = !isPlaying;
}

// MARK: - Notification handlers

- (void)applicationDidChange:(NSNotification *)notification {
    [self updateNowPlayingInfo];
}

- (void)nowPlayingInfoDidChange:(NSNotification *)notification {
    [self updateNowPlayingInfo];
}

- (void)isPlayingDidChange:(NSNotification *)notification {
    [self updateNowPlayingInfo];
    [self updateIsPlaying:[notification.userInfo[@"kMRMediaRemoteNowPlayingApplicationIsPlayingUserInfoKey"] boolValue]];
}

// MARK: - Menu delegate

- (void)menuNeedsUpdate:(NSMenu *)menu {
    NSMenuItem *showSongItem = [menu itemWithTag:100];
    [showSongItem setState:[NSUserDefaults.standardUserDefaults boolForKey:kShowSongInMenuBarUserDefaultsKey] ? NSControlStateValueOn : NSControlStateValueOff];
    NSMenuItem *showControlsItem = [menu itemWithTag:101];
    [showControlsItem setState:[NSUserDefaults.standardUserDefaults boolForKey:kShowControlsInMenuBarUserDefaultsKey] ? NSControlStateValueOn : NSControlStateValueOff];
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSApplication *app = NSApplication.sharedApplication;
        app.activationPolicy = NSApplicationActivationPolicyAccessory;
        PlayBar *playBar = [PlayBar new];
        [playBar setup];
        [app run];
    }
    return EXIT_SUCCESS;
}
