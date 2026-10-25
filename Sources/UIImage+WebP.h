#import <UIKit/UIKit.h>

@interface UIImage (NeoWebP)

+ (BOOL)neo_isWebPData:(NSData *)data;
+ (UIImage *)neo_imageWithWebPData:(NSData *)data;
+ (UIImage *)neo_imageWithWebPData:(NSData *)data scale:(CGFloat)scale;
+ (UIImage *)neo_imageWithDataOrWebP:(NSData *)data;

@end
