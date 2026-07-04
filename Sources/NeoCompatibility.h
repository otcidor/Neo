#define IS_IOS7_OR_LATER ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0)
#define IS_IOS8_OR_LATER ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0)

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


