#import <Foundation/Foundation.h>

extern NSString *const NeoDemoModeDidChangeNotification;

@interface DemoModeManager : NSObject

+ (instancetype)sharedManager;

@property (nonatomic, assign) BOOL demoModeUnlocked;
@property (nonatomic, assign) BOOL demoModeEnabled;

- (NSString *)obfuscateName:(NSString *)realName;
- (NSString *)obfuscateMessage:(NSString *)realMessage;

@end
