//
//  main.m
//  EarthTime
//
//  Created by Eric Maciel on 04/11/23.
//

#import <Cocoa/Cocoa.h>

@interface NSMenu (HighlightItemUsingPrivateAPIs)
- (void)_highlightItem:(NSMenuItem*)menuItem;
@end
@implementation NSMenu (HighlightItemUsingPrivateAPIs)
- (void)_highlightItem:(NSMenuItem*)menuItem{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
    const SEL selHighlightItem = @selector(highlightItem:);
#pragma clang diagnostic pop
    if ([self respondsToSelector:selHighlightItem]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:selHighlightItem withObject:menuItem];
#pragma clang diagnostic pop
    }
}
@end

@interface City : NSObject
@property (strong) NSString *name;
@property (strong) NSString *administrativeArea; // State or province
@property (strong) NSString *ISOcountryCode;
@property (strong) NSString *timeZone;
@property (strong) NSString *details;
@property (strong) NSString *queryDetails;
@end

@implementation City
@end

@interface MenuBarItem : NSObject <NSMenuDelegate, NSSearchFieldDelegate>
@property (strong) NSStatusItem *statusItem;
@property (weak) NSTextField *cityDetailsLabel;
@property (weak) NSTextField *cityDateLabel;
@property (weak) NSSearchField *searchField;
@property (strong) City *selectedCity;
@property (strong) NSTimer *cityTimer;
@property (strong) id activeAppObserver;
@property (strong) dispatch_source_t debounceTimer;
@end

@implementation MenuBarItem

// MARK: - Class methods and variables

static NSArray *gCities;
static NSMutableArray *gMenuBarItems;

+ (void)initialize {
    [self loadCitiesData];
    gMenuBarItems = [NSMutableArray array];
}

+ (void)loadCitiesData {
    NSURL *citiesFileURL = [NSBundle.mainBundle URLForResource:@"cities" withExtension:@"csv"];
    NSString *citiesData = [NSString stringWithContentsOfURL:citiesFileURL encoding:NSUTF8StringEncoding error:nil];
    NSMutableArray *cities = [NSMutableArray array];
    [citiesData enumerateLinesUsingBlock:^(NSString * _Nonnull line, BOOL * _Nonnull stop) {
        NSArray *components = [line componentsSeparatedByString:@","];
        City *city = [City new];
        city.name = components[0];
        city.administrativeArea = components[1];
        city.ISOcountryCode = components[2];
        city.timeZone = components[3];
        city.details = [NSString stringWithFormat:@"%@, %@, %@", city.name, city.administrativeArea, city.ISOcountryCode];
        city.queryDetails = [NSString stringWithFormat:@"%@ %@ %@", city.name, city.administrativeArea, city.ISOcountryCode];
        [cities addObject:city];
    }];
    gCities = [cities sortedArrayUsingComparator:^NSComparisonResult(City *  _Nonnull city1, City *  _Nonnull city2) {
        return [city1.name localizedCaseInsensitiveCompare:city2.name];
    }];
}

+ (void)addItem {
    MenuBarItem *item = [MenuBarItem new];
    [item setup];
    [gMenuBarItems addObject:item];
}

+ (void)removeItem:(MenuBarItem *)item {
    [NSStatusBar.systemStatusBar removeStatusItem:item.statusItem];
    item.statusItem = nil;
    [item.cityTimer invalidate];
    [gMenuBarItems removeObject:item];
    if (gMenuBarItems.count == 0) {
        [NSApp terminate:nil];
    }
}

+ (NSArray *)items {
    return gMenuBarItems;
}

// MARK: - Instance methods, constants and helpers

dispatch_source_t CreateDebounceDispatchTimer(double debounceTime, dispatch_queue_t queue, dispatch_block_t block) {
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    
    if (timer) {
        dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, debounceTime * NSEC_PER_SEC), DISPATCH_TIME_FOREVER, (1ull * NSEC_PER_SEC) / 10);
        dispatch_source_set_event_handler(timer, block);
        dispatch_resume(timer);
    }
    
    return timer;
}

NSString * const kDefaultCityDetails = @"Los Angeles, California, US";
NSInteger const kCitiesMenuItemTag = 100;

- (void)setup {
    NSStatusItem *statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
    statusItem.menu = [NSMenu new];
    statusItem.menu.delegate = self;
    
    
    NSTextField *cityDetailsLabel = [NSTextField labelWithString:kDefaultCityDetails];
    NSTextField *cityDateLabel = [NSTextField labelWithString:@"00:00"];
    cityDetailsLabel.font = cityDateLabel.font = [NSFont systemFontOfSize:NSFont.smallSystemFontSize];
    NSStackView *cityView = [NSStackView stackViewWithViews:@[cityDetailsLabel, cityDateLabel]];
    cityView.orientation = NSUserInterfaceLayoutOrientationVertical;
    cityView.spacing = -2;
    [statusItem.button addSubview:cityView];
    
    [NSLayoutConstraint activateConstraints:@[
        [cityView.leftAnchor constraintEqualToAnchor:statusItem.button.leftAnchor constant:6],
        [cityView.rightAnchor constraintEqualToAnchor:statusItem.button.rightAnchor constant:-6],
        [cityView.topAnchor constraintEqualToAnchor:statusItem.button.topAnchor],
        [cityView.bottomAnchor constraintEqualToAnchor:statusItem.button.bottomAnchor],
    ]];
    
    NSTextField *searchLabel = [NSTextField labelWithString:@"  Search for a city"];
    searchLabel.textColor = NSColor.secondaryLabelColor;
    NSSearchField *searchField = [NSSearchField textFieldWithString:kDefaultCityDetails];
    searchField.bezelStyle = NSTextFieldRoundedBezel;
    searchField.focusRingType = NSFocusRingTypeNone;
    searchField.delegate = self;
    NSStackView *stackView = [NSStackView stackViewWithViews:@[searchLabel, searchField]];
    stackView.translatesAutoresizingMaskIntoConstraints = NO;
    stackView.orientation = NSUserInterfaceLayoutOrientationVertical;
    stackView.alignment = NSLayoutAttributeLeading;
    stackView.spacing = 4;
    stackView.edgeInsets = NSEdgeInsetsMake(0, 5, 5, 5);
    [stackView.widthAnchor constraintGreaterThanOrEqualToConstant:200].active = YES;
    NSMenuItem *searchItem = [NSMenuItem new];
    searchItem.view = stackView;
    [statusItem.menu addItem:searchItem];
    
    [statusItem.menu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *citiesItem = [statusItem.menu addItemWithTitle:@"Cities"
                                                        action:nil
                                                 keyEquivalent:@""];
    citiesItem.submenu = [NSMenu new];
    citiesItem.tag = kCitiesMenuItemTag;
    [citiesItem.submenu addItemWithTitle:@"Add City"
                                  action:@selector(addMenuBarItem:)
                           keyEquivalent:@""].target = self;
    
    [statusItem.menu addItem:[NSMenuItem separatorItem]];
    [statusItem.menu addItemWithTitle:@"Quit"
                               action:@selector(terminate:)
                        keyEquivalent:@"q"];
    
    self.statusItem = statusItem;
    self.cityDetailsLabel = cityDetailsLabel;
    self.cityDateLabel = cityDateLabel;
    self.searchField = searchField;
    
    [self selectCityByDetails:kDefaultCityDetails];
}

- (void)changeSelectedCity:(City *)selectedCity {
    if (self.cityTimer.isValid) {
        [self.cityTimer invalidate];
    }
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"E HH':'mm";
    dateFormatter.timeZone = [NSTimeZone timeZoneWithName:selectedCity.timeZone];
    
    self.cityDetailsLabel.stringValue = self.searchField.stringValue = selectedCity.name;
    self.cityDateLabel.stringValue = [dateFormatter stringFromDate:[NSDate date]];
    self.cityTimer = [NSTimer scheduledTimerWithTimeInterval:30
                                                     repeats:YES
                                                       block:^(NSTimer * _Nonnull timer) {
        self.cityDateLabel.stringValue = [dateFormatter stringFromDate:[NSDate date]];
    }];
    self.selectedCity = selectedCity;
}

- (void)selectCityByDetails:(NSString *)cityDetails {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"details LIKE[cd] %@", cityDetails];
    NSArray *filteredCities = [gCities filteredArrayUsingPredicate:predicate];
    City *city = filteredCities.firstObject;
    if (city) {
        [self changeSelectedCity:city];
    }
}

- (void)queryCityDetails:(NSString *)cityDetails {
    // First try to match details at the beginning of the string
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"queryDetails BEGINSWITH[cd] %@", cityDetails];
    NSArray *filteredCities = [gCities filteredArrayUsingPredicate:predicate];
    if (filteredCities.count < 10) {
        // Try to match whole details string
        NSPredicate *predicate1 = [NSPredicate predicateWithFormat:@"details CONTAINS[cd] %@", cityDetails];
        NSMutableArray *predicates = [NSMutableArray array];
        for (City *city in filteredCities) {
            [predicates addObject:[NSPredicate predicateWithFormat:@"NOT details LIKE[cd] %@", city.details]];
        }
        // Exclude alredy match cities
        NSPredicate *predicate2 = [NSCompoundPredicate andPredicateWithSubpredicates:predicates];
        NSCharacterSet *spaceAndComma = [NSCharacterSet characterSetWithCharactersInString:@", "];
        NSArray *words = [cityDetails componentsSeparatedByCharactersInSet:spaceAndComma];
        [predicates removeAllObjects];
        for (NSString *word in words) {
            [predicates addObject:[NSPredicate predicateWithFormat:@"details CONTAINS[cd] %@", word]];
        }
        // Try to match details to each word
        NSPredicate *predicate3 = [NSCompoundPredicate andPredicateWithSubpredicates:predicates];
        // Combine predicates
        NSPredicate *predicate4 = [NSCompoundPredicate orPredicateWithSubpredicates:@[predicate1, predicate3]];
        NSPredicate *predicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[predicate2, predicate4]];
        NSArray *moreFilteredCities = [gCities filteredArrayUsingPredicate:predicate];
        filteredCities = [filteredCities arrayByAddingObjectsFromArray:moreFilteredCities];
    }
    filteredCities = [filteredCities subarrayWithRange:NSMakeRange(0, MIN(10, filteredCities.count))];
    [self buildCitySearchItemsFor:filteredCities];
}

- (void)debouncedQueryCityDetails:(NSString *)cityDetails {
    if (self.debounceTimer != nil) {
        dispatch_source_cancel(self.debounceTimer);
        self.debounceTimer = nil;
    }
    
    dispatch_queue_t queue = dispatch_get_main_queue();
    double secondsToThrottle = 0.500f;
    self.debounceTimer = CreateDebounceDispatchTimer(secondsToThrottle, queue, ^{
        [self queryCityDetails:cityDetails];
    });
}

- (void)removeCitySearchItems {
    NSMenu *menu = self.statusItem.menu;
    NSArray *menuItems = [menu.itemArray subarrayWithRange:NSMakeRange(1, menu.numberOfItems - 5)];
    for (NSMenuItem *item in menuItems) {
        [menu removeItem:item];
    }
}

- (void)buildCitySearchItemsFor:(NSArray *)cities {
    [self removeCitySearchItems];
    NSMenu *menu = self.statusItem.menu;
    for (City *city in cities) {
        NSMenuItem *item = [menu insertItemWithTitle:city.details
                                              action:@selector(selectCity:)
                                       keyEquivalent:@""
                                             atIndex:menu.numberOfItems - 4];
        item.representedObject = city;
        item.target = self;
    }
}

- (void)removeCityItems {
    NSMenu *menu = [self.statusItem.menu itemWithTag:kCitiesMenuItemTag].submenu;
    NSArray *menuItems = [menu.itemArray subarrayWithRange:NSMakeRange(1, menu.numberOfItems - 1)];
    for (NSMenuItem *item in menuItems) {
        [menu removeItem:item];
    }
}

- (void)buildCityItemsFor:(NSArray *)menuBarItems {
    [self removeCityItems];
    if (menuBarItems.count == 0) {
        return;
    }
    NSMenu *menu = [self.statusItem.menu itemWithTag:kCitiesMenuItemTag].submenu;
    [menu addItem:[NSMenuItem separatorItem]];
    for (MenuBarItem *item in menuBarItems) {
        NSMenuItem *cityItem = [menu addItemWithTitle:item.selectedCity.details
                                               action:nil
                                        keyEquivalent:@""];
        cityItem.submenu = [NSMenu new];
        NSMenuItem *removeCityItem = [cityItem.submenu addItemWithTitle:@"Remove City"
                                                                 action:@selector(removeMenuBarItem:)
                                                          keyEquivalent:@""];
        removeCityItem.representedObject = item;
        removeCityItem.target = self;
    }
}

- (void)selectCity:(NSMenuItem *)sender {
    [self changeSelectedCity:sender.representedObject];
    [self removeCitySearchItems];
}

- (void)addMenuBarItem:(NSMenuItem *)sender {
    [MenuBarItem addItem];
}

- (void)removeMenuBarItem:(NSMenuItem *)sender {
    [MenuBarItem removeItem:sender.representedObject];
}

// MARK: - Search field delegate methods

- (void)controlTextDidChange:(NSNotification *)notification {
    NSSearchField *searchField = notification.object;
    [self debouncedQueryCityDetails:searchField.stringValue];
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {
    if (commandSelector == @selector(insertTab:)
        || commandSelector == @selector(moveDown:)) {
        [self highlightNextItem];
        return YES;
    }
    return NO;
}

// MARK: - Menu delegate methods

- (void)menuNeedsUpdate:(NSMenu *)menu {
    [self buildCityItemsFor:[MenuBarItem items]];
}

- (void)menuWillOpen:(NSMenu *)menu {
    if (!NSApp.isActive) {
        self.activeAppObserver = [NSNotificationCenter.defaultCenter addObserverForName:NSApplicationDidBecomeActiveNotification
                                                                                 object:NSApp
                                                                                  queue:NSOperationQueue.mainQueue
                                                                             usingBlock:^(NSNotification * _Nonnull notification) {
            [self.statusItem.button performClick:self];
            [NSNotificationCenter.defaultCenter removeObserver:self.activeAppObserver
                                                          name:NSApplicationDidBecomeActiveNotification
                                                        object:NSApp];
        }];
        [menu cancelTrackingWithoutAnimation];
        [NSApp activateIgnoringOtherApps:YES];
    }
}

- (void)highlightNextItem {
    NSMenu *menu = self.statusItem.menu;
    NSArray *menuItems = [menu.itemArray subarrayWithRange:NSMakeRange(1, menu.numberOfItems - 1)];
    NSMenuItem *nextItem;
    for (NSMenuItem *item in menuItems) {
        if (!item.isSeparatorItem) {
            nextItem = item;
            break;
        }
    }
    [menu _highlightItem:nextItem];
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSApplication *app = NSApplication.sharedApplication;
        app.activationPolicy = NSApplicationActivationPolicyAccessory;
        
        [MenuBarItem addItem];
        
        [app run];
    }
    return EXIT_SUCCESS;
}
