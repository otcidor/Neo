#import "UIImage+NeoBlur.h"

static inline uint64_t get_colors(const uint8_t *p) {
    return p[0] + (p[1] << 16) + ((uint64_t)p[2] << 32);
}

static void NeoTelegramFastBlur(int imageWidth, int imageHeight, int imageStride, void *pixels) {
    uint8_t *pix = (uint8_t *)pixels;
    const int w = imageWidth;
    const int h = imageHeight;
    const int stride = imageStride;
    const int radius = 3;
    const int r1 = radius + 1;
    const int div = radius * 2 + 1;

    if (radius > 15 || div >= w || div >= h) {
        return;
    }

    uint64_t *rgb = malloc(imageStride * imageHeight * sizeof(uint64_t));
    if (!rgb) return;

    int x, y, i;
    int yw = 0;
    const int we = w - r1;

    for (y = 0; y < h; y++) {
        uint64_t cur = get_colors(&pix[yw]);
        uint64_t rgballsum = -radius * cur;
        uint64_t rgbsum = cur * ((r1 * (r1 + 1)) >> 1);

        for (i = 1; i <= radius; i++) {
            uint64_t c = get_colors(&pix[yw + i * 4]);
            rgbsum += c * (r1 - i);
            rgballsum += c;
        }

        x = 0;

#define update_h(start, middle, end)                         \
rgb[y * w + x] = (rgbsum >> 4) & 0x00FF00FF00FF00FF;        \
rgballsum += get_colors(&pix[yw + (start) * 4]) -            \
2 * get_colors(&pix[yw + (middle) * 4]) +                   \
get_colors(&pix[yw + (end) * 4]);                           \
rgbsum += rgballsum;                                        \
x++;

        while (x < r1) {
            update_h(0, x, x + r1);
        }
        while (x < we) {
            update_h(x - r1, x, x + r1);
        }
        while (x < w) {
            update_h(x - r1, x, w - 1);
        }
#undef update_h

        yw += stride;
    }

    const int he = h - r1;
    for (x = 0; x < w; x++) {
        uint64_t rgballsum = -radius * rgb[x];
        uint64_t rgbsum = rgb[x] * ((r1 * (r1 + 1)) >> 1);
        for (i = 1; i <= radius; i++) {
            rgbsum += rgb[i * w + x] * (r1 - i);
            rgballsum += rgb[i * w + x];
        }

        y = 0;
        int yi = x * 4;

#define update_v(start, middle, end)                        \
int64_t res = rgbsum >> 4;                                  \
pix[yi] = (uint8_t)res;                                     \
pix[yi + 1] = (uint8_t)(res >> 16);                         \
pix[yi + 2] = (uint8_t)(res >> 32);                         \
rgballsum += rgb[x + (start) * w] -                         \
2 * rgb[x + (middle) * w] +                                 \
rgb[x + (end) * w];                                         \
rgbsum += rgballsum;                                        \
y++;                                                        \
yi += stride;

        while (y < r1) {
            update_v(0, y, y + r1);
        }
        while (y < he) {
            update_v(y - r1, y, y + r1);
        }
        while (y < h) {
            update_v(y - r1, y, h - 1);
        }
#undef update_v
    }

    free(rgb);
}

@implementation UIImage (NeoBlur)

- (UIImage *)neo_blurredImageWithFactor:(CGFloat)factor {
    if (factor <= 0.0f || factor >= 1.0f) factor = 0.25f;

    int targetW = (int)MAX(16, self.size.width * factor);
    int targetH = (int)MAX(16, self.size.height * factor);

    size_t bytesPerRow = (size_t)targetW * 4;
    void *pixels = calloc(1, bytesPerRow * (size_t)targetH);
    if (!pixels) return self;

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(pixels, targetW, targetH, 8, bytesPerRow,
                                             colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    if (!ctx) {
        free(pixels);
        return self;
    }

    CGContextDrawImage(ctx, CGRectMake(0, 0, targetW, targetH), self.CGImage);
    NeoTelegramFastBlur(targetW, targetH, (int)bytesPerRow, pixels);

    CGImageRef blurredRef = CGBitmapContextCreateImage(ctx);
    CGContextRelease(ctx);
    free(pixels);

    if (!blurredRef) return self;

    UIImage *result = [UIImage imageWithCGImage:blurredRef scale:self.scale orientation:self.imageOrientation];
    CGImageRelease(blurredRef);
    return result;
}

@end
