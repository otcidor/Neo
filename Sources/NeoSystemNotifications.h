#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

int NeoSystemNotificationsRun(const char *command);

#ifdef __cplusplus
}
#endif

@interface NeoSystemNotifications : NSObject

+ (void)setupSystemNotificationsIfNeeded;

@end
