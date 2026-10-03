#import <UIKit/UIKit.h>

@interface NeoSkeuoRenderer : NSObject

// Navigation Bar Images
+ (UIImage *)navBarImageWithColor:(UIColor *)tintColor height:(CGFloat)height;
+ (UIImage *)navBarImageWithColor:(UIColor *)tintColor; // 44pt default
+ (UIImage *)navBarImage64WithColor:(UIColor *)tintColor; // 64pt with status bar

// Tab Bar Images
+ (UIImage *)tabBarBackgroundImageWithThemeColor:(UIColor *)themeColor;
+ (UIImage *)tabBarSelectionIndicatorWithColor:(UIColor *)themeColor width:(CGFloat)width;

// Button Images & Helpers
+ (UIImage *)buttonBackgroundImageWithColor:(UIColor *)tintColor highlighted:(BOOL)highlighted;
+ (UIBarButtonItem *)backBarButtonItemWithTarget:(id)target action:(SEL)action;

// Table & Cell Elements
+ (UIImage *)classicDisclosureIndicatorImage;
+ (UIView *)classicDisclosureIndicator;

// Color Helpers
+ (UIColor *)darkTabTintColorForThemeColor:(UIColor *)themeColor;
+ (UIImage *)clearPixelImage;

@end
