#import "UIImage+NeoBlur.h"

@implementation UIImage (NeoBlur)

- (UIImage *)neo_blurredImageWithFactor:(CGFloat)factor {
    if (factor <= 0 || factor >= 1) factor = 0.08;

    CGSize originalSize = self.size;
    CGSize smallSize = CGSizeMake(MAX(1, originalSize.width * factor),
                                   MAX(1, originalSize.height * factor));

    UIGraphicsBeginImageContext(smallSize);
    [self drawInRect:CGRectMake(0, 0, smallSize.width, smallSize.height)];
    UIImage *small = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    if (!small) return self;

    UIGraphicsBeginImageContext(originalSize);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetInterpolationQuality(ctx, kCGInterpolationHigh);
    [small drawInRect:CGRectMake(0, 0, originalSize.width, originalSize.height)];
    UIImage *blurred = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return blurred ?: self;
}

@end
