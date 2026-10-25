#import <UIKit/UIKit.h>

@interface NeoNotificationBanner : NSObject

+ (instancetype)sharedBanner;

+ (void)showMessage:(NSString *)message
             sender:(NSString *)sender
           roomName:(NSString *)roomName
             roomId:(NSString *)roomId;

- (void)dismissAnimated:(BOOL)animated;

@end
