#import <UIKit/UIKit.h>

extern NSString *const NeoThemeDidChangeNotification;

typedef NS_ENUM(NSInteger, NeoThemeId) {
    NeoThemeLightDefault,
    NeoThemeLightGreen,
    NeoThemeLightCyan,
    NeoThemeLightPurple,
    NeoThemeLightPink,
    NeoThemeDarkGray,
    NeoThemeDarkGreen,
    NeoThemeDarkBlue,
    NeoThemeDarkPurple,
    NeoThemeDarkRed,
    NeoThemeDarkGlass
};

@interface ThemeManager : NSObject

+ (instancetype)sharedManager;

@property (nonatomic, assign, readonly) NeoThemeId currentThemeId;
@property (nonatomic, assign, readonly) BOOL isDarkMode;
@property (nonatomic, assign, readonly) BOOL isDarkGlass;
@property (nonatomic, assign) BOOL isSkeuomorphicMode;

- (void)setThemeId:(NeoThemeId)themeId;
- (void)setSkeuomorphicMode:(BOOL)skeuomorphicMode;
+ (UIBarButtonItem *)backBarButtonItemWithTarget:(id)target action:(SEL)action;
+ (UIView *)disclosureIndicator;

- (UIColor *)navBarColor;
- (UIColor *)tintColor;
- (UIColor *)backgroundColor;
- (UIColor *)cellBackgroundColor;
- (UIColor *)primaryTextColor;
- (UIColor *)secondaryTextColor;
- (UIColor *)separatorColor;
- (UIBarStyle)barStyle;
- (void)applyThemeToNavigationBar:(UINavigationBar *)navBar;
- (void)applyThemeToTabBar:(UITabBar *)tabBar;

+ (NSString *)nameForThemeId:(NeoThemeId)themeId;
+ (UIColor *)swatchColorForThemeId:(NeoThemeId)themeId;
+ (BOOL)isDarkThemeId:(NeoThemeId)themeId;
+ (UIImage *)modernNavBarImage;
+ (UIImage *)modernTabBarImage;
+ (UIImage *)modernSearchFieldImage;
+ (UIImage *)modernSearchBarBgImage;
+ (UIImage *)modernDisclosureIndicatorImage;
+ (UIView *)modernDisclosureIndicator;
+ (UIImage *)settingsIconNamed:(NSString *)name;
+ (UIImage *)inputBarImageForThemeId:(NeoThemeId)themeId;
- (UIImage *)inputBarBackgroundImage;

@end
