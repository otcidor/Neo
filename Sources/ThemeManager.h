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
    NeoThemeDarkRed
};

@interface ThemeManager : NSObject

+ (instancetype)sharedManager;

@property (nonatomic, assign, readonly) NeoThemeId currentThemeId;
@property (nonatomic, assign, readonly) BOOL isDarkMode;

- (void)setThemeId:(NeoThemeId)themeId;

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

@end
