#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <UIKit/UIKit.h>

#define IS_IOS6_OR_LATER ([[[UIDevice currentDevice] systemVersion] floatValue] >= 6.0)
#define IS_IOS7_OR_LATER ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0)
#define IS_IOS8_OR_LATER ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0)
#define IS_IOS10_OR_LATER ([[[UIDevice currentDevice] systemVersion] floatValue] >= 10.0)

static inline NSString *NeoGenerateUUID(void) {
    CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
    NSString *str = (__bridge_transfer NSString *)CFUUIDCreateString(kCFAllocatorDefault, uuid);
    CFRelease(uuid);
    return str;
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
#define NeoOrientationMask UIInterfaceOrientationMask
#else
#define NeoOrientationMask NSUInteger
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 70000
@interface UINavigationBar (iOS7Compat)
@property (nonatomic, retain) UIColor *barTintColor;
@end
@interface UITabBar (iOS7Compat)
@property (nonatomic, retain) UIColor *barTintColor;
@end
@interface UITabBarItem (iOS7Compat)
@property (nonatomic, retain) UIImage *selectedImage;
@end
#endif


