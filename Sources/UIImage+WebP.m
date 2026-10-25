#import "UIImage+WebP.h"
#import <webp/decode.h>

static void NeoFreeWebPBuffer(void *info, const void *data, size_t size) {
    if (data) {
        free((void *)data);
    }
}

@implementation UIImage (NeoWebP)

+ (BOOL)neo_isWebPData:(NSData *)data {
    if (!data || data.length < 12) return NO;
    const uint8_t *bytes = (const uint8_t *)data.bytes;
    return (bytes[0] == 'R' && bytes[1] == 'I' && bytes[2] == 'F' && bytes[3] == 'F' &&
            bytes[8] == 'W' && bytes[9] == 'E' && bytes[10] == 'B' && bytes[11] == 'P');
}

+ (UIImage *)neo_imageWithWebPData:(NSData *)data {
    return [self neo_imageWithWebPData:data scale:1.0f];
}

+ (UIImage *)neo_imageWithWebPData:(NSData *)data scale:(CGFloat)scale {
    if (!data || data.length < 12) return nil;

    int width = 0, height = 0;
    if (!WebPGetInfo((const uint8_t *)data.bytes, data.length, &width, &height)) {
        return nil;
    }
    if (width <= 0 || height <= 0) return nil;

    size_t bytesPerRow = (size_t)width * 4;
    size_t bufferSize = bytesPerRow * (size_t)height;
    uint8_t *buffer = malloc(bufferSize);
    if (!buffer) return nil;

    if (!WebPDecodeRGBAInto((const uint8_t *)data.bytes, data.length, buffer, bufferSize, (int)bytesPerRow)) {
        free(buffer);
        return nil;
    }

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, buffer, bufferSize, NeoFreeWebPBuffer);
    CGImageRef imageRef = CGImageCreate((size_t)width, (size_t)height, 8, 32, bytesPerRow, colorSpace,
                                        kCGImageAlphaLast | kCGBitmapByteOrderDefault,
                                        provider, NULL, NO, kCGRenderingIntentDefault);
    CGColorSpaceRelease(colorSpace);
    CGDataProviderRelease(provider);

    if (!imageRef) {
        return nil;
    }

    CGFloat s = (scale > 0.0f) ? scale : 1.0f;
    UIImage *image = [[UIImage alloc] initWithCGImage:imageRef scale:s orientation:UIImageOrientationUp];
    CGImageRelease(imageRef);
    return image;
}

+ (UIImage *)neo_imageWithDataOrWebP:(NSData *)data {
    if (!data || data.length == 0) return nil;
    if ([self neo_isWebPData:data]) {
        return [self neo_imageWithWebPData:data scale:1.0f];
    }
    UIImage *img = [UIImage imageWithData:data];
    if (!img && data.length >= 12) {
        img = [self neo_imageWithWebPData:data scale:1.0f];
    }
    return img;
}

@end
