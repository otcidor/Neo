#import <UIKit/UIKit.h>

@interface UIColor (NeoColor)

+ (UIColor *)neo_colorWithHex:(NSInteger)hex;
+ (UIColor *)neo_colorWithHex:(NSInteger)hex alpha:(CGFloat)alpha;

+ (UIColor *)neo_colorForUserId:(NSString *)userId;
+ (UIColor *)neo_accentColor;
+ (UIColor *)neo_subtitleColor;

@end
