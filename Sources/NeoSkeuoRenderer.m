#import "NeoSkeuoRenderer.h"
#import <QuartzCore/QuartzCore.h>

@implementation NeoSkeuoRenderer

#pragma mark - Color Manipulation Helpers

static void NeoGetRGBComponents(UIColor *color, CGFloat *r, CGFloat *g, CGFloat *b, CGFloat *a) {
    if (!color) {
        *r = 0.0f; *g = 0.48f; *b = 1.0f; *a = 1.0f;
        return;
    }
    CGColorRef cg = [color CGColor];
    size_t count = CGColorGetNumberOfComponents(cg);
    const CGFloat *components = CGColorGetComponents(cg);
    if (count >= 3) {
        *r = components[0];
        *g = components[1];
        *b = components[2];
        *a = (count >= 4) ? components[3] : 1.0f;
    } else if (count >= 1) {
        *r = components[0];
        *g = components[0];
        *b = components[0];
        *a = (count >= 2) ? components[1] : 1.0f;
    } else {
        *r = 0.2f; *g = 0.2f; *b = 0.2f; *a = 1.0f;
    }
}

static UIColor *NeoAdjustColor(UIColor *color, CGFloat factor, CGFloat add) {
    CGFloat r, g, b, a;
    NeoGetRGBComponents(color, &r, &g, &b, &a);
    CGFloat nr = fminf(fmaxf(r * factor + add, 0.0f), 1.0f);
    CGFloat ng = fminf(fmaxf(g * factor + add, 0.0f), 1.0f);
    CGFloat nb = fminf(fmaxf(b * factor + add, 0.0f), 1.0f);
    return [UIColor colorWithRed:nr green:ng blue:nb alpha:a];
}

+ (UIColor *)darkTabTintColorForThemeColor:(UIColor *)themeColor {
    CGFloat r, g, b, a;
    NeoGetRGBComponents(themeColor, &r, &g, &b, &a);
    // Deep dark tint retaining the theme hue (e.g., deep dark green, deep dark navy, deep dark plum)
    CGFloat nr = fminf(r * 0.16f + 0.05f, 1.0f);
    CGFloat ng = fminf(g * 0.16f + 0.05f, 1.0f);
    CGFloat nb = fminf(b * 0.16f + 0.05f, 1.0f);
    return [UIColor colorWithRed:nr green:ng blue:nb alpha:1.0f];
}

#pragma mark - Navigation Bar Generation

+ (UIImage *)navBarImageWithColor:(UIColor *)tintColor {
    return [self navBarImageWithColor:tintColor height:44.0f];
}

+ (UIImage *)navBarImage64WithColor:(UIColor *)tintColor {
    return [self navBarImageWithColor:tintColor height:64.0f];
}

+ (UIImage *)clearPixelImage {
    static UIImage *clearImg = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(1.0f, 1.0f), NO, 0.0f);
        CGContextRef ctx = UIGraphicsGetCurrentContext();
        CGContextClearRect(ctx, CGRectMake(0, 0, 1.0f, 1.0f));
        clearImg = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    });
    return clearImg;
}

+ (UIImage *)navBarImageWithColor:(UIColor *)tintColor height:(CGFloat)height {
    if (!tintColor) tintColor = [UIColor colorWithRed:0.0f green:0.48f blue:1.0f alpha:1.0f];
    static NSMutableDictionary *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [[NSMutableDictionary alloc] init];
    });

    CGFloat r, g, b, a;
    NeoGetRGBComponents(tintColor, &r, &g, &b, &a);
    NSString *key = [NSString stringWithFormat:@"nav_%.2f_%.2f_%.2f_%.0f", r, g, b, height];
    UIImage *cached = [cache objectForKey:key];
    if (cached) return cached;

    CGSize size = CGSizeMake(2.0f, height);
    UIGraphicsBeginImageContextWithOptions(size, YES, 0.0f);
    CGContextRef ctx = UIGraphicsGetCurrentContext();

    UIColor *darkTint = [self darkTabTintColorForThemeColor:tintColor];

    // Rich satin tones mirroring the elegance of the tab bar
    UIColor *navTop    = NeoAdjustColor(darkTint, 1.45f, 0.08f);
    UIColor *navBottom = NeoAdjustColor(darkTint, 0.95f, -0.01f);

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    NSArray *gradientColors = @[
        (__bridge id)[navTop CGColor],
        (__bridge id)[navBottom CGColor]
    ];
    CGFloat locations[] = {0.0f, 1.0f};
    CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)gradientColors, locations);

    if (height >= 64.0f) {
        // iOS 7+ bar attached to top layout guide:
        // 1. Status Bar area: y = 0 to 20 (deep dark satin base)
        UIColor *statusBg = NeoAdjustColor(darkTint, 1.05f, 0.02f);
        [statusBg setFill];
        CGContextFillRect(ctx, CGRectMake(0, 0, size.width, 20.0f));

        // Subtle 0.5pt separator line between status bar and nav bar
        [[UIColor colorWithWhite:0.0f alpha:0.45f] setFill];
        CGContextFillRect(ctx, CGRectMake(0, 19.5f, size.width, 0.5f));

        // 2. Navigation Bar area: exactly 44 points from y = 20.0 to height
        CGContextDrawLinearGradient(ctx, gradient, CGPointMake(0, 20.0f), CGPointMake(0, height), 0);

        // Top 0.5pt highlight line of the nav bar at y = 20.0
        [[UIColor colorWithWhite:1.0f alpha:0.25f] setFill];
        CGContextFillRect(ctx, CGRectMake(0, 20.0f, size.width, 0.5f));

        // Bottom dark bevel border at y = height - 1.0f
        [[UIColor colorWithWhite:0.0f alpha:0.55f] setFill];
        CGContextFillRect(ctx, CGRectMake(0, height - 1.0f, size.width, 0.5f));

        // Bottom crisp separator line at y = height - 0.5f (solid dark bottom rim)
        UIColor *bottomRim = NeoAdjustColor(darkTint, 0.35f, -0.04f);
        [bottomRim setFill];
        CGContextFillRect(ctx, CGRectMake(0, height - 0.5f, size.width, 0.5f));
    } else {
        // Standard 44pt bar (iOS 6 or unattached):
        CGContextDrawLinearGradient(ctx, gradient, CGPointMake(0, 0), CGPointMake(0, height), 0);

        // Top 0.5pt highlight line at y = 0
        [[UIColor colorWithWhite:1.0f alpha:0.25f] setFill];
        CGContextFillRect(ctx, CGRectMake(0, 0, size.width, 0.5f));

        // Bottom dark bevel border
        [[UIColor colorWithWhite:0.0f alpha:0.55f] setFill];
        CGContextFillRect(ctx, CGRectMake(0, height - 1.0f, size.width, 0.5f));

        // Bottom crisp separator line
        UIColor *bottomRim = NeoAdjustColor(darkTint, 0.35f, -0.04f);
        [bottomRim setFill];
        CGContextFillRect(ctx, CGRectMake(0, height - 0.5f, size.width, 0.5f));
    }

    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorSpace);

    UIImage *raw = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    UIImage *resizable = [raw resizableImageWithCapInsets:UIEdgeInsetsZero];
    if (resizable) {
        [cache setObject:resizable forKey:key];
    }
    return resizable;
}

#pragma mark - Tab Bar Generation

+ (UIImage *)tabBarBackgroundImageWithThemeColor:(UIColor *)themeColor {
    static NSMutableDictionary *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [[NSMutableDictionary alloc] init];
    });

    UIColor *darkTint = [self darkTabTintColorForThemeColor:themeColor];
    CGFloat r, g, b, a;
    NeoGetRGBComponents(darkTint, &r, &g, &b, &a);
    NSString *key = [NSString stringWithFormat:@"tab_%.2f_%.2f_%.2f", r, g, b];
    UIImage *cached = [cache objectForKey:key];
    if (cached) return cached;

    CGSize size = CGSizeMake(2.0f, 49.0f);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0f);
    CGContextRef ctx = UIGraphicsGetCurrentContext();

    UIColor *tabTop    = NeoAdjustColor(darkTint, 1.18f, 0.06f);
    UIColor *tabBottom = NeoAdjustColor(darkTint, 0.85f, -0.02f);

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    NSArray *gradientColors = @[
        (__bridge id)[tabTop CGColor],
        (__bridge id)[tabBottom CGColor]
    ];
    CGFloat locations[] = {0.0f, 1.0f};
    CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)gradientColors, locations);

    CGContextDrawLinearGradient(ctx, gradient, CGPointMake(0, 0), CGPointMake(0, size.height), 0);
    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorSpace);

    // Top border 1px dark bevel
    [[UIColor colorWithWhite:0.0f alpha:0.65f] setFill];
    CGContextFillRect(ctx, CGRectMake(0, 0, size.width, 0.5f));

    // Top highlight line 1px (etched line below top border)
    [[UIColor colorWithWhite:1.0f alpha:0.18f] setFill];
    CGContextFillRect(ctx, CGRectMake(0, 0.5f, size.width, 0.5f));

    UIImage *raw = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    UIImage *resizable = [raw resizableImageWithCapInsets:UIEdgeInsetsMake(1, 0, 0, 0)];
    if (resizable) {
        [cache setObject:resizable forKey:key];
    }
    return resizable;
}

+ (UIImage *)tabBarSelectionIndicatorWithColor:(UIColor *)themeColor width:(CGFloat)width {
    if (width <= 0) width = 64.0f;
    CGSize size = CGSizeMake(width, 49.0f);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0f);
    CGContextRef ctx = UIGraphicsGetCurrentContext();

    // Classic iOS 6 active tab indicator: glowing glossy capsule with top highlight
    CGRect glowRect = CGRectMake(3.0f, 2.0f, width - 6.0f, 45.0f);
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:glowRect cornerRadius:4.0f];

    CGContextSaveGState(ctx);
    [path addClip];

    UIColor *glowTop = [themeColor colorWithAlphaComponent:0.32f];
    UIColor *glowBottom = [themeColor colorWithAlphaComponent:0.08f];

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    NSArray *colors = @[(__bridge id)[glowTop CGColor], (__bridge id)[glowBottom CGColor]];
    CGFloat locations[] = {0.0f, 1.0f};
    CGGradientRef grad = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)colors, locations);

    CGContextDrawLinearGradient(ctx, grad, CGPointMake(0, glowRect.origin.y), CGPointMake(0, CGRectGetMaxY(glowRect)), 0);
    CGGradientRelease(grad);
    CGColorSpaceRelease(colorSpace);

    // Subtle inner border for the selection pill
    [[themeColor colorWithAlphaComponent:0.40f] setStroke];
    path.lineWidth = 1.0f;
    [path stroke];

    CGContextRestoreGState(ctx);

    // Top active line accent
    [[themeColor colorWithAlphaComponent:0.85f] setFill];
    CGContextFillRect(ctx, CGRectMake(glowRect.origin.x, 0, glowRect.size.width, 1.5f));

    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

#pragma mark - Button Generation

+ (UIImage *)buttonBackgroundImageWithColor:(UIColor *)tintColor highlighted:(BOOL)highlighted {
    if (!tintColor) tintColor = [UIColor colorWithRed:0.0f green:0.48f blue:1.0f alpha:1.0f];
    CGSize size = CGSizeMake(18.0f, 30.0f);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0f);
    CGContextRef ctx = UIGraphicsGetCurrentContext();

    CGRect rect = CGRectMake(0.5f, 0.5f, size.width - 1.0f, size.height - 1.0f);
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:4.5f];

    CGContextSaveGState(ctx);
    [path addClip];

    UIColor *topColor, *bottomColor;
    if (highlighted) {
        // Pressed state: darker on top
        topColor    = NeoAdjustColor(tintColor, 0.70f, -0.15f);
        bottomColor = NeoAdjustColor(tintColor, 0.90f, 0.0f);
    } else {
        // Normal state: glossy sheen on top
        topColor    = NeoAdjustColor(tintColor, 1.15f, 0.12f);
        bottomColor = NeoAdjustColor(tintColor, 0.85f, -0.08f);
    }

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    NSArray *colors = @[(__bridge id)[topColor CGColor], (__bridge id)[bottomColor CGColor]];
    CGFloat locations[] = {0.0f, 1.0f};
    CGGradientRef grad = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)colors, locations);

    CGContextDrawLinearGradient(ctx, grad, CGPointMake(0, 0), CGPointMake(0, size.height), 0);
    CGGradientRelease(grad);
    CGColorSpaceRelease(colorSpace);

    // Inner highlight arc at top
    if (!highlighted) {
        [[UIColor colorWithWhite:1.0f alpha:0.30f] setFill];
        CGContextFillRect(ctx, CGRectMake(1.0f, 1.0f, size.width - 2.0f, 0.5f));
    }

    CGContextRestoreGState(ctx);

    // Outer dark border
    [[UIColor colorWithWhite:0.0f alpha:0.40f] setStroke];
    path.lineWidth = 1.0f;
    [path stroke];

    UIImage *raw = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return [raw resizableImageWithCapInsets:UIEdgeInsetsMake(0, 8, 0, 8)];
}

+ (UIBarButtonItem *)backBarButtonItemWithTarget:(id)target action:(SEL)action {
    UIImage *arrow = [UIImage imageNamed:@"UINavigationBarBackArrow"];
    if (!arrow) arrow = [UIImage imageNamed:@"NavigationBackArrow"];

    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    CGFloat w = arrow ? (arrow.size.width + 16.0f) : 44.0f;
    if (w < 44.0f) w = 44.0f;
    btn.frame = CGRectMake(0, 0, w, 44.0f);
    [btn setImage:arrow forState:UIControlStateNormal];
    btn.showsTouchWhenHighlighted = YES;
    btn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    btn.imageEdgeInsets = UIEdgeInsetsMake(0, 2.0f, 0, 0);
    [btn addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];

    return [[UIBarButtonItem alloc] initWithCustomView:btn];
}

#pragma mark - Table & Cell Elements

+ (UIImage *)classicDisclosureIndicatorImage {
    static UIImage *img = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CGSize size = CGSizeMake(9.0f, 14.0f);
        UIGraphicsBeginImageContextWithOptions(size, NO, 0.0f);
        CGContextRef ctx = UIGraphicsGetCurrentContext();

        // 1. Embossed bottom-right light highlight (iOS 6 3D effect)
        CGContextSaveGState(ctx);
        UIBezierPath *pShadow = [UIBezierPath bezierPath];
        [pShadow moveToPoint:CGPointMake(1.5f, 1.5f + 0.75f)];
        [pShadow addLineToPoint:CGPointMake(7.0f, 7.0f + 0.75f)];
        [pShadow addLineToPoint:CGPointMake(1.5f, 12.5f + 0.75f)];
        pShadow.lineWidth = 2.5f;
        pShadow.lineCapStyle = kCGLineCapSquare;
        pShadow.lineJoinStyle = kCGLineJoinMiter;
        [[UIColor colorWithWhite:1.0f alpha:0.75f] setStroke];
        [pShadow stroke];
        CGContextRestoreGState(ctx);

        // 2. Solid dark gray chevron body
        UIBezierPath *p = [UIBezierPath bezierPath];
        [p moveToPoint:CGPointMake(1.5f, 1.5f)];
        [p addLineToPoint:CGPointMake(7.0f, 7.0f)];
        [p addLineToPoint:CGPointMake(1.5f, 12.5f)];
        p.lineWidth = 2.5f;
        p.lineCapStyle = kCGLineCapSquare;
        p.lineJoinStyle = kCGLineJoinMiter;
        [[UIColor colorWithRed:0.46f green:0.48f blue:0.52f alpha:1.0f] setStroke];
        [p stroke];

        img = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    });
    return img;
}

+ (UIView *)classicDisclosureIndicator {
    return [[UIImageView alloc] initWithImage:[self classicDisclosureIndicatorImage]];
}

@end
