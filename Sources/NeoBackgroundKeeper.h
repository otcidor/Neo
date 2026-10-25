#import <Foundation/Foundation.h>

@interface NeoBackgroundKeeper : NSObject

@property (nonatomic, assign) BOOL isEnabled;
@property (nonatomic, readonly) BOOL isRunning;

+ (instancetype)sharedKeeper;

- (void)startKeepAlive;
- (void)stopKeepAlive;

@end
