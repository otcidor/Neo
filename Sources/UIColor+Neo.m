#import "UIColor+Neo.h"

@implementation UIColor (NeoColor)

+ (UIColor *)neo_colorWithHex:(NSInteger)hex
{
    return [UIColor colorWithRed:(((hex >> 16) & 0xff) / 255.0f)
                           green:(((hex >> 8) & 0xff) / 255.0f)
                            blue:(((hex) & 0xff) / 255.0f)
                           alpha:1.0f];
}

+ (UIColor *)neo_colorWithHex:(NSInteger)hex alpha:(CGFloat)alpha
{
    return [UIColor colorWithRed:(((hex >> 16) & 0xff) / 255.0f)
                           green:(((hex >> 8) & 0xff) / 255.0f)
                            blue:(((hex) & 0xff) / 255.0f)
                           alpha:alpha];
}

+ (NSArray *)neo_placeholderColors
{
    static NSArray *colors;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        colors = @[
            [UIColor neo_colorWithHex:0xff516a],
            [UIColor neo_colorWithHex:0xffa85c],
            [UIColor neo_colorWithHex:0x665fff],
            [UIColor neo_colorWithHex:0x54cb68],
            [UIColor neo_colorWithHex:0x28c9b7],
            [UIColor neo_colorWithHex:0x2a9ef1],
            [UIColor neo_colorWithHex:0xd669ed]
        ];
    });
    return colors;
}

+ (UIColor *)neo_colorForUserId:(NSString *)userId
{
    NSUInteger hash = [userId hash];
    return [self neo_placeholderColors][hash % 7];
}

+ (UIColor *)neo_accentColor
{
    return [UIColor neo_colorWithHex:0x2ea4e5];
}

+ (UIColor *)neo_subtitleColor
{
    return [UIColor neo_colorWithHex:0x8f8f8f];
}

@end
