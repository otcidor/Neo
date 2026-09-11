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
        // 0 means never saved — default to Dark on fresh install
        if (saved == 0 && ![[NSUserDefaults standardUserDefaults] objectForKey:kThemeDefaultsKey]) {
            saved = NeoThemeDarkGray;
        }
        _currentThemeId = (NeoThemeId)saved;
        _isDarkMode = [ThemeManager isDarkThemeId:_currentThemeId];
        _isDarkGlass = (_currentThemeId == NeoThemeDarkGlass);
    }
    return self;
}

- (void)setThemeId:(NeoThemeId)themeId {
    _currentThemeId = themeId;
    _isDarkMode = [ThemeManager isDarkThemeId:themeId];
    _isDarkGlass = (themeId == NeoThemeDarkGlass);
    [[NSUserDefaults standardUserDefaults] setInteger:themeId forKey:kThemeDefaultsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:NeoThemeDidChangeNotification object:nil];
}

+ (BOOL)isDarkThemeId:(NeoThemeId)themeId {
    return (themeId == NeoThemeDarkGray || themeId == NeoThemeDarkGreen ||
            themeId == NeoThemeDarkBlue || themeId == NeoThemeDarkPurple ||
            themeId == NeoThemeDarkRed || themeId == NeoThemeDarkGlass);
}

+ (NSString *)nameForThemeId:(NeoThemeId)themeId {
    switch (themeId) {
        case NeoThemeLightDefault: return @"Blue";
        case NeoThemeLightGreen:   return @"Green";
        case NeoThemeLightCyan:    return @"Cyan";
        case NeoThemeLightPurple:  return @"Purple";
        case NeoThemeLightPink:    return @"Pink";
        case NeoThemeDarkGray:     return @"Dark";
        case NeoThemeDarkGreen:    return @"Dark Green";
        case NeoThemeDarkBlue:     return @"Dark Blue";
        case NeoThemeDarkPurple:   return @"Dark Purple";
        case NeoThemeDarkRed:      return @"Dark Red";
        case NeoThemeDarkGlass:    return @"Dark Modern";
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
        case NeoThemeDarkGray:     return [UIColor colorWithRed:0.28 green:0.28 blue:0.30 alpha:1.0];
        case NeoThemeDarkGreen:    return [UIColor colorWithRed:0.08 green:0.35 blue:0.20 alpha:1.0];
        case NeoThemeDarkBlue:     return [UIColor colorWithRed:0.08 green:0.25 blue:0.40 alpha:1.0];
        case NeoThemeDarkPurple:   return [UIColor colorWithRed:0.30 green:0.12 blue:0.40 alpha:1.0];
        case NeoThemeDarkRed:      return [UIColor colorWithRed:0.40 green:0.08 blue:0.12 alpha:1.0];
        case NeoThemeDarkGlass:    return [UIColor colorWithRed:0.12 green:0.12 blue:0.16 alpha:1.0];
    }
    return [UIColor grayColor];
}

- (UIColor *)navBarColor {
    return [ThemeManager swatchColorForThemeId:self.currentThemeId];
}

- (UIColor *)tintColor {
    if (self.isDarkGlass) {
        return [UIColor colorWithRed:0.20 green:0.60 blue:1.0 alpha:1.0];
    }
    return [ThemeManager swatchColorForThemeId:self.currentThemeId];
}

- (UIColor *)backgroundColor {
    if (self.isDarkGlass) {
        return [UIColor colorWithRed:0.10 green:0.10 blue:0.12 alpha:1.0];
    }
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
    if (self.isDarkGlass) {
        return [UIColor colorWithRed:0.14 green:0.14 blue:0.17 alpha:1.0];
    }
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
    if (self.isDarkGlass) {
        return [UIColor colorWithWhite:1.0 alpha:0.10];
    }
    return self.isDarkMode ? [UIColor colorWithWhite:0.30 alpha:1.0] : [UIColor colorWithWhite:0.85 alpha:1.0];
}

- (UIBarStyle)barStyle {
    if (self.isDarkGlass) {
        return UIBarStyleBlack;
    }
    return self.isDarkMode ? UIBarStyleBlack : UIBarStyleDefault;
}

- (void)applyThemeToNavigationBar:(UINavigationBar *)navBar {
    if (self.isDarkGlass) {
        navBar.translucent = NO;
        UIImage *barImg = [ThemeManager modernNavBarImage];
        [navBar setBackgroundImage:barImg forBarMetrics:UIBarMetricsDefault];
        if ([navBar respondsToSelector:@selector(setShadowImage:)]) {
            navBar.shadowImage = [[UIImage alloc] init];
        }
        if (IS_IOS7_OR_LATER) {
            navBar.barTintColor = [UIColor colorWithRed:0.09 green:0.09 blue:0.11 alpha:1.0];
            navBar.tintColor = [UIColor whiteColor];
        } else {
            navBar.barStyle = UIBarStyleBlack;
            navBar.tintColor = [UIColor colorWithRed:0.16 green:0.16 blue:0.20 alpha:1.0];
        }
        navBar.titleTextAttributes = @{
            UITextAttributeTextColor: [UIColor whiteColor],
            UITextAttributeTextShadowColor: [UIColor clearColor],
            UITextAttributeTextShadowOffset: [NSValue valueWithCGSize:CGSizeZero],
            UITextAttributeFont: [UIFont boldSystemFontOfSize:17]
        };
        return;
    }
    // Standard skeuomorphic themes:
    [navBar setBackgroundImage:nil forBarMetrics:UIBarMetricsDefault];
    if ([navBar respondsToSelector:@selector(setShadowImage:)]) {
        navBar.shadowImage = nil;
    }
    navBar.translucent = NO;
    UIColor *color = [self tintColor];
    if (IS_IOS7_OR_LATER) {
        navBar.barTintColor = color;
        navBar.tintColor = [UIColor whiteColor];
        navBar.titleTextAttributes = @{UITextAttributeTextColor: [UIColor whiteColor]};
    } else {
        navBar.translucent = NO;
        navBar.tintColor = color;
        navBar.barStyle = [self barStyle];
        navBar.titleTextAttributes = @{UITextAttributeTextColor: [UIColor whiteColor]};
    }
}

- (void)applyThemeToTabBar:(UITabBar *)tabBar {
    if (self.isDarkGlass) {
        UIImage *tabImg = [ThemeManager modernTabBarImage];
        [tabBar setBackgroundImage:tabImg];
        if ([tabBar respondsToSelector:@selector(setShadowImage:)]) {
            tabBar.shadowImage = [[UIImage alloc] init];
        }
        if ([tabBar respondsToSelector:@selector(setSelectedImageTintColor:)]) {
            tabBar.selectedImageTintColor = [UIColor colorWithRed:0.35 green:0.65 blue:1.0 alpha:1.0];
        }
        return;
    }
    // Standard skeuomorphic themes:
    [tabBar setBackgroundImage:nil];
    if ([tabBar respondsToSelector:@selector(setShadowImage:)]) {
        tabBar.shadowImage = nil;
    }
    UIColor *color = [self tintColor];
    if (IS_IOS7_OR_LATER) {
        tabBar.barTintColor = color;
        tabBar.tintColor = [UIColor whiteColor];
    } else {
        tabBar.tintColor = color;
        if ([tabBar respondsToSelector:@selector(setSelectedImageTintColor:)]) {
            tabBar.selectedImageTintColor = nil;
        }
    }
}

+ (UIImage *)modernNavBarImage {
    static UIImage *img = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CGSize size = CGSizeMake(2.0f, 44.0f);
        UIGraphicsBeginImageContextWithOptions(size, YES, 0.0f);
        CGContextRef ctx = UIGraphicsGetCurrentContext();
        [[UIColor colorWithRed:0.09 green:0.09 blue:0.11 alpha:1.0] setFill];
        CGContextFillRect(ctx, CGRectMake(0, 0, 2.0f, 44.0f));
        [[UIColor colorWithWhite:1.0 alpha:0.10] setFill];
        CGContextFillRect(ctx, CGRectMake(0, 43.5f, 2.0f, 0.5f));
        UIImage *raw = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        img = [raw resizableImageWithCapInsets:UIEdgeInsetsMake(0, 0, 1, 0)];
    });
    return img;
}

+ (UIImage *)modernTabBarImage {
    static UIImage *img = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CGSize size = CGSizeMake(2.0f, 49.0f);
        UIGraphicsBeginImageContextWithOptions(size, YES, 0.0f);
        CGContextRef ctx = UIGraphicsGetCurrentContext();
        [[UIColor colorWithRed:0.08 green:0.08 blue:0.10 alpha:1.0] setFill];
        CGContextFillRect(ctx, CGRectMake(0, 0, 2.0f, 49.0f));
        [[UIColor colorWithWhite:1.0 alpha:0.10] setFill];
        CGContextFillRect(ctx, CGRectMake(0, 0, 2.0f, 0.5f));
        UIImage *raw = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        img = [raw resizableImageWithCapInsets:UIEdgeInsetsMake(1, 0, 0, 0)];
    });
    return img;
}

+ (UIImage *)modernSearchFieldImage {
    static UIImage *img = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CGSize size = CGSizeMake(32.0f, 28.0f);
        UIGraphicsBeginImageContextWithOptions(size, NO, 0.0f);
        CGRect r = CGRectInset(CGRectMake(0, 0, 32.0f, 28.0f), 0.5f, 0.5f);
        UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:r cornerRadius:13.5f];
        [[UIColor colorWithWhite:1.0 alpha:0.08] setFill];
        [path fill];
        [[UIColor colorWithWhite:1.0 alpha:0.12] setStroke];
        path.lineWidth = 1.0f;
        [path stroke];
        UIImage *raw = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        img = [raw resizableImageWithCapInsets:UIEdgeInsetsMake(13, 14, 13, 14)];
    });
    return img;
}

+ (UIImage *)modernSearchBarBgImage {
    static UIImage *img = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CGSize size = CGSizeMake(2.0f, 44.0f);
        UIGraphicsBeginImageContextWithOptions(size, YES, 0.0f);
        CGContextRef ctx = UIGraphicsGetCurrentContext();
        [[UIColor colorWithRed:0.08 green:0.08 blue:0.10 alpha:1.0] setFill];
        CGContextFillRect(ctx, CGRectMake(0, 0, 2.0f, 44.0f));
        UIImage *raw = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        img = [raw resizableImageWithCapInsets:UIEdgeInsetsZero];
    });
    return img;
}

+ (UIImage *)modernDisclosureIndicatorImage {
    static UIImage *img = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CGSize size = CGSizeMake(8.0f, 13.0f);
        UIGraphicsBeginImageContextWithOptions(size, NO, 0.0f);
        UIBezierPath *p = [UIBezierPath bezierPath];
        [p moveToPoint:CGPointMake(1.5f, 1.5f)];
        [p addLineToPoint:CGPointMake(6.5f, 6.5f)];
        [p addLineToPoint:CGPointMake(1.5f, 11.5f)];
        p.lineWidth = 2.0f;
        p.lineCapStyle = kCGLineCapRound;
        p.lineJoinStyle = kCGLineJoinRound;
        [[UIColor colorWithWhite:1.0 alpha:0.28] setStroke];
        [p stroke];
        img = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    });
    return img;
}

+ (UIView *)modernDisclosureIndicator {
    UIImageView *iv = [[UIImageView alloc] initWithImage:[self modernDisclosureIndicatorImage]];
    return iv;
}

+ (UIImage *)settingsIconNamed:(NSString *)name {
    static NSMutableDictionary *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [[NSMutableDictionary alloc] init];
    });

    if (!name) return nil;
    UIImage *cached = [cache objectForKey:name];
    if (cached) return cached;

    CGSize size = CGSizeMake(29.0f, 29.0f);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0f);

    UIColor *bgColor = [UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:1.0];
    if ([name isEqualToString:@"user"]) {
        bgColor = [UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:1.0];
    } else if ([name isEqualToString:@"server"]) {
        bgColor = [UIColor colorWithRed:0.20 green:0.68 blue:0.90 alpha:1.0];
    } else if ([name isEqualToString:@"archive"]) {
        bgColor = [UIColor colorWithRed:0.55 green:0.55 blue:0.58 alpha:1.0];
    } else if ([name isEqualToString:@"wallpaper"]) {
        bgColor = [UIColor colorWithRed:0.20 green:0.78 blue:0.35 alpha:1.0];
    } else if ([name isEqualToString:@"bubble"]) {
        bgColor = [UIColor colorWithRed:0.0 green:0.75 blue:0.85 alpha:1.0];
    } else if ([name isEqualToString:@"theme"]) {
        bgColor = [UIColor colorWithRed:0.68 green:0.32 blue:0.88 alpha:1.0];
    } else if ([name isEqualToString:@"networks"]) {
        bgColor = [UIColor colorWithRed:0.35 green:0.34 blue:0.84 alpha:1.0];
    } else if ([name isEqualToString:@"limit"]) {
        bgColor = [UIColor colorWithRed:1.0 green:0.58 blue:0.0 alpha:1.0];
    } else if ([name isEqualToString:@"demo"]) {
        bgColor = [UIColor colorWithRed:0.40 green:0.25 blue:0.65 alpha:1.0];
    } else if ([name isEqualToString:@"clearcache"]) {
        bgColor = [UIColor colorWithRed:1.0 green:0.60 blue:0.15 alpha:1.0];
    } else if ([name isEqualToString:@"logout"] || [name isEqualToString:@"delete"]) {
        bgColor = [UIColor colorWithRed:1.0 green:0.23 blue:0.19 alpha:1.0];
    } else if ([name isEqualToString:@"rename"]) {
        bgColor = [UIColor colorWithRed:0.15 green:0.65 blue:0.85 alpha:1.0];
    } else if ([name isEqualToString:@"mute"]) {
        bgColor = [UIColor colorWithRed:1.0 green:0.58 blue:0.0 alpha:1.0];
    }

    UIBezierPath *bgPath = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, 29.0f, 29.0f) cornerRadius:6.5f];
    [bgColor setFill];
    [bgPath fill];

    [[UIColor whiteColor] setFill];
    [[UIColor whiteColor] setStroke];

    if ([name isEqualToString:@"user"]) {
        UIBezierPath *head = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(10.7f, 5.7f, 7.6f, 7.6f)];
        [head fill];
        UIBezierPath *body = [UIBezierPath bezierPath];
        [body moveToPoint:CGPointMake(7.5f, 22.0f)];
        [body addQuadCurveToPoint:CGPointMake(14.5f, 15.5f) controlPoint:CGPointMake(8.0f, 16.5f)];
        [body addQuadCurveToPoint:CGPointMake(21.5f, 22.0f) controlPoint:CGPointMake(21.0f, 16.5f)];
        [body closePath];
        [body fill];
    } else if ([name isEqualToString:@"server"]) {
        UIBezierPath *b1 = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(6.5f, 8.5f, 16.0f, 4.5f) cornerRadius:2.0f];
        [b1 fill];
        UIBezierPath *b2 = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(6.5f, 15.5f, 16.0f, 4.5f) cornerRadius:2.0f];
        [b2 fill];
        [bgColor setFill];
        [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(18.0f, 9.8f, 2.0f, 2.0f)] fill];
        [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(18.0f, 16.8f, 2.0f, 2.0f)] fill];
    } else if ([name isEqualToString:@"archive"]) {
        UIBezierPath *lid = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(5.5f, 8.0f, 18.0f, 3.5f) cornerRadius:1.0f];
        [lid fill];
        UIBezierPath *body = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(7.0f, 12.0f, 15.0f, 9.5f) cornerRadius:1.0f];
        [body fill];
        [bgColor setFill];
        [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(11.5f, 14.5f, 6.0f, 2.0f) cornerRadius:0.8f] fill];
    } else if ([name isEqualToString:@"wallpaper"]) {
        UIBezierPath *frame = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(6.0f, 7.5f, 17.0f, 14.0f) cornerRadius:2.0f];
        frame.lineWidth = 1.5f;
        [frame stroke];
        [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(9.0f, 10.0f, 3.5f, 3.5f)] fill];
        UIBezierPath *mt = [UIBezierPath bezierPath];
        [mt moveToPoint:CGPointMake(7.5f, 19.5f)];
        [mt addLineToPoint:CGPointMake(13.0f, 14.0f)];
        [mt addLineToPoint:CGPointMake(17.5f, 18.0f)];
        [mt addLineToPoint:CGPointMake(20.0f, 15.5f)];
        [mt addLineToPoint:CGPointMake(21.5f, 17.5f)];
        [mt addLineToPoint:CGPointMake(21.5f, 19.5f)];
        [mt closePath];
        [mt fill];
    } else if ([name isEqualToString:@"bubble"]) {
        UIBezierPath *bubble = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(6.5f, 7.5f, 16.0f, 11.0f) cornerRadius:4.0f];
        [bubble fill];
        UIBezierPath *tail = [UIBezierPath bezierPath];
        [tail moveToPoint:CGPointMake(9.0f, 17.0f)];
        [tail addLineToPoint:CGPointMake(6.5f, 21.0f)];
        [tail addLineToPoint:CGPointMake(13.5f, 17.0f)];
        [tail closePath];
        [tail fill];
    } else if ([name isEqualToString:@"theme"]) {
        UIBezierPath *pal = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(7.0f, 7.0f, 15.0f, 15.0f)];
        [pal fill];
        [bgColor setFill];
        [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(16.5f, 15.5f, 3.5f, 3.5f)] fill];
        [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(10.0f, 11.0f, 2.2f, 2.2f)] fill];
        [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(13.5f, 9.5f, 2.2f, 2.2f)] fill];
        [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(17.0f, 11.5f, 2.2f, 2.2f)] fill];
    } else if ([name isEqualToString:@"networks"]) {
        [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(7.5f, 7.5f, 5.5f, 5.5f) cornerRadius:1.5f] fill];
        [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(16.0f, 7.5f, 5.5f, 5.5f) cornerRadius:1.5f] fill];
        [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(7.5f, 16.0f, 5.5f, 5.5f) cornerRadius:1.5f] fill];
        [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(16.0f, 16.0f, 5.5f, 5.5f) cornerRadius:1.5f] fill];
    } else if ([name isEqualToString:@"limit"]) {
        UIBezierPath *clk = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(7.5f, 7.5f, 14.0f, 14.0f)];
        clk.lineWidth = 1.8f;
        [clk stroke];
        UIBezierPath *hands = [UIBezierPath bezierPath];
        [hands moveToPoint:CGPointMake(14.5f, 10.0f)];
        [hands addLineToPoint:CGPointMake(14.5f, 14.5f)];
        [hands addLineToPoint:CGPointMake(18.0f, 14.5f)];
        hands.lineWidth = 1.8f;
        hands.lineCapStyle = kCGLineCapRound;
        [hands stroke];
    } else if ([name isEqualToString:@"demo"]) {
        [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(6.5f, 11.0f, 6.5f, 5.5f) cornerRadius:1.8f] fill];
        [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(16.0f, 11.0f, 6.5f, 5.5f) cornerRadius:1.8f] fill];
        UIBezierPath *br = [UIBezierPath bezierPath];
        [br moveToPoint:CGPointMake(13.0f, 13.5f)];
        [br addLineToPoint:CGPointMake(16.0f, 13.5f)];
        br.lineWidth = 1.8f;
        [br stroke];
    } else if ([name isEqualToString:@"clearcache"]) {
        [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(7.0f, 7.5f, 15.0f, 3.8f) cornerRadius:1.9f] fill];
        [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(7.0f, 12.5f, 15.0f, 3.8f) cornerRadius:1.9f] fill];
        [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(7.0f, 17.5f, 15.0f, 3.8f) cornerRadius:1.9f] fill];
    } else if ([name isEqualToString:@"logout"]) {
        UIBezierPath *door = [UIBezierPath bezierPath];
        [door moveToPoint:CGPointMake(14.0f, 8.0f)];
        [door addLineToPoint:CGPointMake(7.5f, 8.0f)];
        [door addLineToPoint:CGPointMake(7.5f, 21.0f)];
        [door addLineToPoint:CGPointMake(14.0f, 21.0f)];
        door.lineWidth = 1.8f;
        door.lineCapStyle = kCGLineCapRound;
        door.lineJoinStyle = kCGLineJoinRound;
        [door stroke];

        UIBezierPath *arrow = [UIBezierPath bezierPath];
        [arrow moveToPoint:CGPointMake(11.0f, 14.5f)];
        [arrow addLineToPoint:CGPointMake(21.0f, 14.5f)];
        [arrow moveToPoint:CGPointMake(17.5f, 11.5f)];
        [arrow addLineToPoint:CGPointMake(21.5f, 14.5f)];
        [arrow addLineToPoint:CGPointMake(17.5f, 17.5f)];
        arrow.lineWidth = 1.8f;
        arrow.lineCapStyle = kCGLineCapRound;
        arrow.lineJoinStyle = kCGLineJoinRound;
        [arrow stroke];
    } else if ([name isEqualToString:@"rename"]) {
        UIBezierPath *pen = [UIBezierPath bezierPath];
        [pen moveToPoint:CGPointMake(8.0f, 20.5f)];
        [pen addLineToPoint:CGPointMake(19.5f, 9.0f)];
        pen.lineWidth = 2.4f;
        pen.lineCapStyle = kCGLineCapRound;
        [pen stroke];
        [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(19.0f, 7.5f, 3.0f, 3.0f)] fill];
    } else if ([name isEqualToString:@"mute"]) {
        UIBezierPath *bell = [UIBezierPath bezierPath];
        [bell moveToPoint:CGPointMake(14.5f, 7.5f)];
        [bell addQuadCurveToPoint:CGPointMake(9.0f, 17.5f) controlPoint:CGPointMake(9.0f, 11.0f)];
        [bell addLineToPoint:CGPointMake(20.0f, 17.5f)];
        [bell addQuadCurveToPoint:CGPointMake(14.5f, 7.5f) controlPoint:CGPointMake(20.0f, 11.0f)];
        [bell closePath];
        [bell fill];
        [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(13.0f, 18.0f, 3.0f, 2.0f)] fill];
        UIBezierPath *sl = [UIBezierPath bezierPath];
        [sl moveToPoint:CGPointMake(6.5f, 6.5f)];
        [sl addLineToPoint:CGPointMake(22.5f, 22.5f)];
        sl.lineWidth = 2.0f;
        sl.lineCapStyle = kCGLineCapRound;
        [bgColor setStroke];
        [sl stroke];
        [[UIColor whiteColor] setStroke];
        sl.lineWidth = 1.2f;
        [sl stroke];
    } else if ([name isEqualToString:@"delete"]) {
        UIBezierPath *lid = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(7.0f, 8.5f, 15.0f, 2.0f) cornerRadius:1.0f];
        [lid fill];
        [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(12.0f, 6.5f, 5.0f, 1.5f) cornerRadius:0.5f] fill];
        UIBezierPath *can = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(8.5f, 11.5f, 12.0f, 10.0f) cornerRadius:1.5f];
        [can fill];
        [bgColor setStroke];
        UIBezierPath *lines = [UIBezierPath bezierPath];
        [lines moveToPoint:CGPointMake(12.0f, 13.5f)];
        [lines addLineToPoint:CGPointMake(12.0f, 19.5f)];
        [lines moveToPoint:CGPointMake(17.0f, 13.5f)];
        [lines addLineToPoint:CGPointMake(17.0f, 19.5f)];
        lines.lineWidth = 1.2f;
        [lines stroke];
    }

    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    if (result) {
        [cache setObject:result forKey:name];
    }
    return result;
}

+ (UIImage *)inputBarImageForThemeId:(NeoThemeId)themeId {
    static NSMutableDictionary *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [[NSMutableDictionary alloc] init];
    });

    NSNumber *key = @(themeId);
    UIImage *cached = [cache objectForKey:key];
    if (cached) {
        return cached;
    }

    if (themeId == NeoThemeDarkGlass) {
        CGSize size = CGSizeMake(4.0f, 44.0f);
        UIGraphicsBeginImageContextWithOptions(size, YES, 0.0f);
        CGContextRef ctx = UIGraphicsGetCurrentContext();
        [[UIColor colorWithRed:0.10 green:0.10 blue:0.13 alpha:1.0] setFill];
        CGContextFillRect(ctx, CGRectMake(0, 0, 4.0f, 44.0f));
        [[UIColor colorWithWhite:1.0 alpha:0.15] setFill];
        CGContextFillRect(ctx, CGRectMake(0, 0, 4.0f, 0.5f));
        UIImage *raw = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        UIImage *res = [raw resizableImageWithCapInsets:UIEdgeInsetsMake(2, 1, 2, 1)];
        if (res) [cache setObject:res forKey:key];
        return res;
    }

    UIColor *swatch = [self swatchColorForThemeId:themeId];
    BOOL isDark = [self isDarkThemeId:themeId];

    CGFloat r = 0.3f, g = 0.3f, b = 0.3f, a = 1.0f;
    if (![swatch getRed:&r green:&g blue:&b alpha:&a]) {
        CGFloat w = 0;
        if ([swatch getWhite:&w alpha:&a]) {
            r = g = b = w;
        }
    }

    CGSize size = CGSizeMake(4.0f, 44.0f);
    UIGraphicsBeginImageContextWithOptions(size, YES, 0.0f);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();

    if (isDark) {
        // Dark Skeuomorphic Bar (Dark Gray, Dark Green, Dark Blue, Dark Purple, Dark Red)
        // 1. Top dark border (y = 0)
        [[UIColor colorWithRed:r * 0.30f green:g * 0.30f blue:b * 0.30f alpha:1.0f] setFill];
        CGContextFillRect(ctx, CGRectMake(0, 0, 4.0f, 1.0f));

        // 2. Bevel highlight line (y = 1)
        [[UIColor colorWithWhite:1.0f alpha:0.22f] setFill];
        CGContextFillRect(ctx, CGRectMake(0, 1.0f, 4.0f, 1.0f));

        // 3. Metallic gradient: uniform base color in the middle stretch slice (y = 16 to 28)
        CGFloat c0_r = MIN(r * 1.30f, 1.0f);
        CGFloat c0_g = MIN(g * 1.30f, 1.0f);
        CGFloat c0_b = MIN(b * 1.30f, 1.0f);

        CGFloat c1_r = r;
        CGFloat c1_g = g;
        CGFloat c1_b = b;

        CGFloat c2_r = r * 0.65f;
        CGFloat c2_g = g * 0.65f;
        CGFloat c2_b = b * 0.65f;

        CGFloat gradColors[] = {
            c0_r, c0_g, c0_b, 1.0f,
            c1_r, c1_g, c1_b, 1.0f,
            c1_r, c1_g, c1_b, 1.0f,
            c2_r, c2_g, c2_b, 1.0f
        };
        CGFloat locs[] = { 0.0f, 0.35f, 0.65f, 1.0f };
        CGGradientRef grad = CGGradientCreateWithColorComponents(cs, gradColors, locs, 4);
        CGContextDrawLinearGradient(ctx, grad, CGPointMake(2.0f, 1.0f), CGPointMake(2.0f, 43.0f), 0);
        CGGradientRelease(grad);

        // 4. Upper half specular sheen strictly inside top cap (y = 1 to 15)
        CGFloat sheenColors[] = {
            1.0f, 1.0f, 1.0f, 0.12f,
            1.0f, 1.0f, 1.0f, 0.00f
        };
        CGFloat sheenLocs[] = { 0.0f, 1.0f };
        CGGradientRef sheen = CGGradientCreateWithColorComponents(cs, sheenColors, sheenLocs, 2);
        CGContextDrawLinearGradient(ctx, sheen, CGPointMake(2.0f, 1.0f), CGPointMake(2.0f, 15.0f), 0);
        CGGradientRelease(sheen);

        // 5. Bottom dark edge (y = 43 to 44)
        [[UIColor colorWithRed:r * 0.20f green:g * 0.20f blue:b * 0.20f alpha:1.0f] setFill];
        CGContextFillRect(ctx, CGRectMake(0, 43.0f, 4.0f, 1.0f));

    } else {
        // Light Skeuomorphic Bar (Blue, Green, Cyan, Purple, Pink)
        // 1. Top dark border (y = 0)
        [[UIColor colorWithRed:r * 0.55f green:g * 0.55f blue:b * 0.55f alpha:1.0f] setFill];
        CGContextFillRect(ctx, CGRectMake(0, 0, 4.0f, 1.0f));

        // 2. Bevel highlight line (y = 1)
        [[UIColor colorWithWhite:1.0f alpha:0.45f] setFill];
        CGContextFillRect(ctx, CGRectMake(0, 1.0f, 4.0f, 1.0f));

        // 3. Colored gradient: uniform base color in the middle stretch slice (y = 16 to 28)
        CGFloat c0_r = r + (1.0f - r) * 0.35f;
        CGFloat c0_g = g + (1.0f - g) * 0.35f;
        CGFloat c0_b = b + (1.0f - b) * 0.35f;

        CGFloat c1_r = r;
        CGFloat c1_g = g;
        CGFloat c1_b = b;

        CGFloat c2_r = r * 0.80f;
        CGFloat c2_g = g * 0.80f;
        CGFloat c2_b = b * 0.80f;

        CGFloat gradColors[] = {
            c0_r, c0_g, c0_b, 1.0f,
            c1_r, c1_g, c1_b, 1.0f,
            c1_r, c1_g, c1_b, 1.0f,
            c2_r, c2_g, c2_b, 1.0f
        };
        CGFloat locs[] = { 0.0f, 0.35f, 0.65f, 1.0f };
        CGGradientRef grad = CGGradientCreateWithColorComponents(cs, gradColors, locs, 4);
        CGContextDrawLinearGradient(ctx, grad, CGPointMake(2.0f, 1.0f), CGPointMake(2.0f, 43.0f), 0);
        CGGradientRelease(grad);

        // 4. Upper half specular gloss strictly inside top cap (y = 1 to 15)
        CGFloat glossColors[] = {
            1.0f, 1.0f, 1.0f, 0.18f,
            1.0f, 1.0f, 1.0f, 0.00f
        };
        CGFloat glossLocs[] = { 0.0f, 1.0f };
        CGGradientRef gloss = CGGradientCreateWithColorComponents(cs, glossColors, glossLocs, 2);
        CGContextDrawLinearGradient(ctx, gloss, CGPointMake(2.0f, 1.0f), CGPointMake(2.0f, 15.0f), 0);
        CGGradientRelease(gloss);

        // 5. Bottom dark edge (y = 43 to 44)
        [[UIColor colorWithRed:r * 0.45f green:g * 0.45f blue:b * 0.45f alpha:1.0f] setFill];
        CGContextFillRect(ctx, CGRectMake(0, 43.0f, 4.0f, 1.0f));
    }

    CGColorSpaceRelease(cs);

    UIImage *raw = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    UIImage *res = [raw resizableImageWithCapInsets:UIEdgeInsetsMake(16, 1, 16, 1)];
    if (res) [cache setObject:res forKey:key];
    return res;
}

- (UIImage *)inputBarBackgroundImage {
    return [ThemeManager inputBarImageForThemeId:self.currentThemeId];
}

@end
