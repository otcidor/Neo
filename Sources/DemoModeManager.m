#import "DemoModeManager.h"

NSString *const NeoDemoModeDidChangeNotification = @"NeoDemoModeDidChangeNotification";
static NSString *const kDemoModeEnabledKey = @"neo_demo_mode_enabled";
static NSString *const kDemoModeUnlockedKey = @"neo_demo_mode_unlocked";

@implementation DemoModeManager

+ (instancetype)sharedManager {
    static DemoModeManager *instance = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _demoModeEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:kDemoModeEnabledKey];
        _demoModeUnlocked = [[NSUserDefaults standardUserDefaults] boolForKey:kDemoModeUnlockedKey];
    }
    return self;
}

- (void)setDemoModeEnabled:(BOOL)enabled {
    _demoModeEnabled = enabled;
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kDemoModeEnabledKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:NeoDemoModeDidChangeNotification object:nil];
}

- (void)setDemoModeUnlocked:(BOOL)unlocked {
    _demoModeUnlocked = unlocked;
    [[NSUserDefaults standardUserDefaults] setBool:unlocked forKey:kDemoModeUnlockedKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSString *)obfuscateName:(NSString *)realName {
    if (!self.demoModeEnabled || [realName length] == 0) return realName;
    NSUInteger hash = [realName hash] % 20;
    return [NSString stringWithFormat:@"Contact %02lu", (unsigned long)hash];
}

- (NSString *)obfuscateMessage:(NSString *)realMessage {
    if (!self.demoModeEnabled || [realMessage length] == 0) return realMessage;
    NSUInteger len = MIN([realMessage length], 40);
    return [@"" stringByPaddingToLength:len withString:@"\u2022" startingAtIndex:0];
}

@end
