#import "ThemeManager.h"
#import "NeoCompatibility.h"

NSString *const NeoThemeDidChangeNotification = @"NeoThemeDidChangeNotification";
static NSString *const kThemeDefaultsKey = @"neo_theme_id";

@implementation ThemeManager

+ (instancetype)sharedManager {
    static ThemeManager *instance = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSInteger saved = [[NSUserDefaults standardUserDefaults] integerForKey:kThemeDefaultsKey];
        _currentThemeId = (NeoThemeId)saved;
        _isDarkMode = [ThemeManager isDarkThemeId:_currentThemeId];
    }
    return self;
}

- (void)setThemeId:(NeoThemeId)themeId {
    _currentThemeId = themeId;
    _isDarkMode = [ThemeManager isDarkThemeId:themeId];
    [[NSUserDefaults standardUserDefaults] setInteger:themeId forKey:kThemeDefaultsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:NeoThemeDidChangeNotification object:nil];
}

+ (BOOL)isDarkThemeId:(NeoThemeId)themeId {
    return (themeId == NeoThemeDarkGray || themeId == NeoThemeDarkGreen ||
            themeId == NeoThemeDarkBlue || themeId == NeoThemeDarkPurple ||
            themeId == NeoThemeDarkRed);
}

+ (NSString *)nameForThemeId:(NeoThemeId)themeId {
    switch (themeId) {
        case NeoThemeLightDefault: return @"Default";
        case NeoThemeLightGreen:   return @"Green";
        case NeoThemeLightCyan:    return @"Cyan";
        case NeoThemeLightPurple:  return @"Purple";
        case NeoThemeLightPink:    return @"Pink";
        case NeoThemeDarkGray:     return @"Dark";
        case NeoThemeDarkGreen:    return @"Dark Green";
        case NeoThemeDarkBlue:     return @"Dark Blue";
        case NeoThemeDarkPurple:   return @"Dark Purple";
        case NeoThemeDarkRed:      return @"Dark Red";
    }
    return @"";
}

+ (UIColor *)swatchColorForThemeId:(NeoThemeId)themeId {
    switch (themeId) {
        case NeoThemeLightDefault: return [UIColor colorWithRed:0.0 green:0.478 blue:1.0 alpha:1.0];
        case NeoThemeLightGreen:   return [UIColor colorWithRed:0.145 green:0.827 blue:0.400 alpha:1.0];
        case NeoThemeLightCyan:    return [UIColor colorWithRed:0.0 green:0.68 blue:0.85 alpha:1.0];
        case NeoThemeLightPurple:  return [UIColor colorWithRed:0.58 green:0.35 blue:0.90 alpha:1.0];
        case NeoThemeLightPink:    return [UIColor colorWithRed:0.90 green:0.35 blue:0.60 alpha:1.0];
        case NeoThemeDarkGray:     return [UIColor colorWithWhite:0.30 alpha:1.0];
        case NeoThemeDarkGreen:    return [UIColor colorWithRed:0.08 green:0.35 blue:0.20 alpha:1.0];
        case NeoThemeDarkBlue:     return [UIColor colorWithRed:0.08 green:0.25 blue:0.40 alpha:1.0];
        case NeoThemeDarkPurple:   return [UIColor colorWithRed:0.30 green:0.12 blue:0.40 alpha:1.0];
        case NeoThemeDarkRed:      return [UIColor colorWithRed:0.40 green:0.08 blue:0.12 alpha:1.0];
    }
    return [UIColor grayColor];
}

- (UIColor *)navBarColor {
    return [ThemeManager swatchColorForThemeId:self.currentThemeId];
}

- (UIColor *)tintColor {
    return [ThemeManager swatchColorForThemeId:self.currentThemeId];
}

- (UIColor *)backgroundColor {
    if (!self.isDarkMode) {
        UIColor *swatch = [self tintColor];
        CGFloat r, g, b, a;
        [swatch getRed:&r green:&g blue:&b alpha:&a];
        return [UIColor colorWithRed:(r * 0.08 + 0.92)
                                green:(g * 0.08 + 0.92)
                                 blue:(b * 0.08 + 0.92)
                                alpha:1.0];
    } else {
        switch (self.currentThemeId) {
            case NeoThemeDarkGreen:
                return [UIColor colorWithRed:0.05 green:0.10 blue:0.07 alpha:1.0];
            case NeoThemeDarkBlue:
                return [UIColor colorWithRed:0.04 green:0.06 blue:0.12 alpha:1.0];
            case NeoThemeDarkPurple:
                return [UIColor colorWithRed:0.08 green:0.04 blue:0.12 alpha:1.0];
            case NeoThemeDarkRed:
                return [UIColor colorWithRed:0.12 green:0.04 blue:0.05 alpha:1.0];
            default:
                return [UIColor colorWithWhite:0.12 alpha:1.0];
        }
    }
}

- (UIColor *)cellBackgroundColor {
    if (!self.isDarkMode) {
        return [UIColor whiteColor];
    } else {
        switch (self.currentThemeId) {
            case NeoThemeDarkGreen:
                return [UIColor colorWithRed:0.09 green:0.16 blue:0.11 alpha:1.0];
            case NeoThemeDarkBlue:
                return [UIColor colorWithRed:0.06 green:0.09 blue:0.18 alpha:1.0];
            case NeoThemeDarkPurple:
                return [UIColor colorWithRed:0.12 green:0.06 blue:0.18 alpha:1.0];
            case NeoThemeDarkRed:
                return [UIColor colorWithRed:0.18 green:0.06 blue:0.08 alpha:1.0];
            default:
                return [UIColor colorWithWhite:0.18 alpha:1.0];
        }
    }
}

- (UIColor *)primaryTextColor {
    return self.isDarkMode ? [UIColor whiteColor] : [UIColor darkTextColor];
}

- (UIColor *)secondaryTextColor {
    return self.isDarkMode ? [UIColor colorWithWhite:0.65 alpha:1.0] : [UIColor grayColor];
}

- (UIColor *)separatorColor {
    return self.isDarkMode ? [UIColor colorWithWhite:0.30 alpha:1.0] : [UIColor colorWithWhite:0.85 alpha:1.0];
}

- (UIBarStyle)barStyle {
    return self.isDarkMode ? UIBarStyleBlack : UIBarStyleDefault;
}

- (void)applyThemeToNavigationBar:(UINavigationBar *)navBar {
    UIColor *color = [self tintColor];
    if (IS_IOS7_OR_LATER) {
        navBar.barTintColor = color;
        navBar.tintColor = [UIColor whiteColor];
        navBar.titleTextAttributes = @{UITextAttributeTextColor: [UIColor whiteColor]};
    } else {
        navBar.tintColor = color;
        navBar.barStyle = [self barStyle];
    }
}

- (void)applyThemeToTabBar:(UITabBar *)tabBar {
    UIColor *color = [self tintColor];
    if (IS_IOS7_OR_LATER) {
        tabBar.barTintColor = color;
        tabBar.tintColor = [UIColor whiteColor];
    } else {
        tabBar.tintColor = color;
    }
}

@end
