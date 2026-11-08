#import "NeoSymbol.h"
#include <ctype.h>
#include <stdlib.h>
#include <math.h>

@implementation NeoSymbol

+ (UIBezierPath *)bezierPathFromSVGData:(const char *)d {
    if (!d) return nil;
    UIBezierPath *path = [UIBezierPath bezierPath];
    CGPoint current = CGPointZero, start = CGPointZero;
    CGPoint lastControl = CGPointZero;
    char command = 0;
    const char *p = d;

    while (*p) {
        while (*p == ' ' || *p == ',' || *p == '\t' || *p == '\r' || *p == '\n') p++;
        if (!*p) break;

        if ((*p >= 'A' && *p <= 'Z') || (*p >= 'a' && *p <= 'z')) {
            command = *p++;
            if (command == 'Z' || command == 'z') {
                [path closePath];
                current = start;
                lastControl = current;
                command = 0;
                continue;
            }
        } else if (!command) {
            break;
        }

        BOOL isRelative = (command >= 'a' && command <= 'z');
        char upper = (char)toupper((unsigned char)command);

        int need = 0;
        if (upper == 'C') need = 6;
        else if (upper == 'S' || upper == 'Q') need = 4;
        else if (upper == 'M' || upper == 'L') need = 2;
        else if (upper == 'H' || upper == 'V') need = 1;
        else break;

        double v[6];
        for (int i = 0; i < need; i++) {
            while (*p == ' ' || *p == ',' || *p == '\t' || *p == '\r' || *p == '\n') p++;
            char *end = NULL;
            v[i] = strtod(p, &end);
            if (end == p) return path;
            p = end;
        }

        if (upper == 'M') {
            CGPoint pt = CGPointMake((CGFloat)v[0], (CGFloat)v[1]);
            if (isRelative) pt = CGPointMake(current.x + pt.x, current.y + pt.y);
            current = pt;
            start = current;
            lastControl = current;
            [path moveToPoint:current];
            command = isRelative ? 'l' : 'L';
        } else if (upper == 'L') {
            CGPoint pt = CGPointMake((CGFloat)v[0], (CGFloat)v[1]);
            if (isRelative) pt = CGPointMake(current.x + pt.x, current.y + pt.y);
            current = pt;
            lastControl = current;
            [path addLineToPoint:current];
        } else if (upper == 'H') {
            CGFloat x = (CGFloat)v[0];
            if (isRelative) x = current.x + x;
            current.x = x;
            lastControl = current;
            [path addLineToPoint:current];
        } else if (upper == 'V') {
            CGFloat y = (CGFloat)v[0];
            if (isRelative) y = current.y + y;
            current.y = y;
            lastControl = current;
            [path addLineToPoint:current];
        } else if (upper == 'C') {
            CGPoint cp1 = CGPointMake((CGFloat)v[0], (CGFloat)v[1]);
            CGPoint cp2 = CGPointMake((CGFloat)v[2], (CGFloat)v[3]);
            CGPoint endPt = CGPointMake((CGFloat)v[4], (CGFloat)v[5]);
            if (isRelative) {
                cp1 = CGPointMake(current.x + cp1.x, current.y + cp1.y);
                cp2 = CGPointMake(current.x + cp2.x, current.y + cp2.y);
                endPt = CGPointMake(current.x + endPt.x, current.y + endPt.y);
            }
            [path addCurveToPoint:endPt controlPoint1:cp1 controlPoint2:cp2];
            lastControl = cp2;
            current = endPt;
        } else if (upper == 'S') {
            CGPoint cp1 = CGPointMake(2 * current.x - lastControl.x, 2 * current.y - lastControl.y);
            CGPoint cp2 = CGPointMake((CGFloat)v[0], (CGFloat)v[1]);
            CGPoint endPt = CGPointMake((CGFloat)v[2], (CGFloat)v[3]);
            if (isRelative) {
                cp2 = CGPointMake(current.x + cp2.x, current.y + cp2.y);
                endPt = CGPointMake(current.x + endPt.x, current.y + endPt.y);
            }
            [path addCurveToPoint:endPt controlPoint1:cp1 controlPoint2:cp2];
            lastControl = cp2;
            current = endPt;
        } else if (upper == 'Q') {
            CGPoint cp = CGPointMake((CGFloat)v[0], (CGFloat)v[1]);
            CGPoint endPt = CGPointMake((CGFloat)v[2], (CGFloat)v[3]);
            if (isRelative) {
                cp = CGPointMake(current.x + cp.x, current.y + cp.y);
                endPt = CGPointMake(current.x + endPt.x, current.y + endPt.y);
            }
            [path addQuadCurveToPoint:endPt controlPoint:cp];
            lastControl = cp;
            current = endPt;
        }
    }
    return path;
}

+ (UIImage *)imageFromPathData:(const char *)pathData size:(CGFloat)size grid:(CGFloat)grid color:(UIColor *)color stroke:(CGFloat)stroke {
    if (!pathData || size <= 0 || grid <= 0) return nil;
    UIColor *drawColor = color ?: [UIColor whiteColor];

    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0.0f);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) {
        UIGraphicsEndImageContext();
        return nil;
    }

    CGFloat scale = size / grid;
    CGContextScaleCTM(ctx, scale, scale);

    UIBezierPath *path = [self bezierPathFromSVGData:pathData];
    if (stroke > 0) {
        path.lineWidth = stroke;
        path.lineCapStyle = kCGLineCapRound;
        path.lineJoinStyle = kCGLineJoinRound;
        [drawColor setStroke];
        [path stroke];
    } else {
        path.usesEvenOddFillRule = YES;
        [drawColor setFill];
        [path fill];
    }

    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

+ (UIImage *)imageForType:(NeoSymbolType)type size:(CGFloat)size color:(UIColor *)color {
    static NSCache *symbolCache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        symbolCache = [[NSCache alloc] init];
        symbolCache.countLimit = 160;
    });

    UIColor *c = color ?: [UIColor whiteColor];
    CGFloat r = 0, g = 0, b = 0, a = 1.0f;
    if (![c getRed:&r green:&g blue:&b alpha:&a]) {
        CGFloat white = 0;
        if ([c getWhite:&white alpha:&a]) {
            r = g = b = white;
        }
    }

    NSString *key = [NSString stringWithFormat:@"%d_%.1f_%.2f_%.2f_%.2f_%.2f", (int)type, size, r, g, b, a];
    UIImage *cached = [symbolCache objectForKey:key];
    if (cached) return cached;

    const char *pathStr = NULL;
    CGFloat grid = 24.0f;
    CGFloat stroke = 0.0f;

    switch (type) {
        case NeoSymbolMagnifier:
            pathStr = "M15.5 14h-.79l-.28-.27C15.41 12.59 16 11.11 16 9.5 16 5.91 13.09 3 9.5 3S3 5.91 3 9.5 5.91 16 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z";
            break;
        case NeoSymbolPaperclip:
            pathStr = "M16.5 6v11.5c0 2.21-1.79 4-4 4s-4-1.79-4-4V5c0-1.38 1.12-2.5 2.5-2.5s2.5 1.12 2.5 2.5v10.5c0 .55-.45 1-1 1s-1-.45-1-1V6H10v9.5c0 1.38 1.12 2.5 2.5 2.5s2.5-1.12 2.5-2.5V5c0-2.21-1.79-4-4-4S7 2.79 7 5v12.5c0 3.04 2.46 5.5 5.5 5.5s5.5-2.46 5.5-5.5V6h-1.5z";
            break;
        case NeoSymbolCamera:
            pathStr = "M9 2L7.17 4H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2h-3.17L15 2H9zm3 15c-2.76 0-5-2.24-5-5s2.24-5 5-5 5 2.24 5 5-2.24 5-5 5zm0-8c-1.66 0-3 1.34-3 3s1.34 3 3 3 3-1.34 3-3-1.34-3-3-3z";
            break;
        case NeoSymbolMicrophone:
            pathStr = "M12 14c1.66 0 3-1.34 3-3V5c0-1.66-1.34-3-3-3S9 3.34 9 5v6c0 1.66 1.34 3 3 3zm5.3-3c0 3-2.54 5.1-5.3 5.1S6.7 14 6.7 11H5c0 3.41 2.72 6.23 6 6.72V21h2v-3.28c3.28-.48 6-3.3 6-6.72h-1.7z";
            break;
        case NeoSymbolCheckmark:
            pathStr = "M9 16.2L4.8 12l-1.4 1.4L9 19 21 7l-1.4-1.4L9 16.2z";
            break;
        case NeoSymbolCheckmarkDouble:
            pathStr = "M0.41 13.41L6 19l1.41-1.41L1.83 12m4.58-1.59L12 4.99 10.59 3.58 5 9.17m11.59-.17L18 7.59 7.41 18.17 6 16.76l9.59-9.59M21.59 4.41L23 5.82 12.41 16.41 11 15z";
            break;
        case NeoSymbolLock:
            pathStr = "M18 8h-1V6c0-2.76-2.24-5-5-5S7 3.24 7 6v2H6c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V10c0-1.1-.9-2-2-2zm-6 9c-1.1 0-2-.9-2-2s.9-2 2-2 2 .9 2 2-.9 2-2 2zm3.1-9H8.9V6c0-1.71 1.39-3.1 3.1-3.1 1.71 0 3.1 1.39 3.1 3.1v2z";
            break;
        case NeoSymbolClock:
            pathStr = "M11.99 2C6.47 2 2 6.48 2 12s4.47 10 9.99 10C17.52 22 22 17.52 22 12S17.52 2 11.99 2zM12 20c-4.42 0-8-3.58-8-8s3.58-8 8-8 8 3.58 8 8-3.58 8-8 8zm.5-13H11v6l5.25 3.15.75-1.23-4.5-2.67z";
            break;
        case NeoSymbolChevronRight:
            pathStr = "M10 6L8.59 7.41 13.17 12l-4.58 4.59L10 18l6-6z";
            break;
        case NeoSymbolPin:
            pathStr = "M16 9V4l1 0c.55 0 1-.45 1-1s-.45-1-1-1H7c-.55 0-1 .45-1 1s.45 1 1 1l1 0v5c0 1.66-1.34 3-3 3v2h5.97v7l1 1 1-1v-7H19v-2c-1.66 0-3-1.34-3-3z";
            break;
        case NeoSymbolMapPin:
            pathStr = "M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5c-1.38 0-2.5-1.12-2.5-2.5s1.12-2.5 2.5-2.5 2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5z";
            break;
        case NeoSymbolPlay:
            pathStr = "M8 5v14l11-7z";
            break;
        case NeoSymbolPause:
            pathStr = "M6 19h4V5H6v14zm8-14v14h4V5h-4z";
            break;
        case NeoSymbolClose:
            pathStr = "M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z";
            break;
        case NeoSymbolTrash:
            pathStr = "M6 19c0 1.1.9 2 2 2h8c1.1 0 2-.9 2-2V7H6v12zM19 4h-3.5l-1-1h-5l-1 1H5v2h14V4z";
            break;
        case NeoSymbolReply:
            pathStr = "M10 9V5l-7 7 7 7v-4.1c5 0 8.5 1.6 11 5.1-1-5-4-10-11-11z";
            break;
        case NeoSymbolForward:
            pathStr = "M14 9V5l7 7-7 7v-4.1c-5 0-8.5 1.6-11 5.1 1-5 4-10 11-11z";
            break;
        case NeoSymbolSettings:
            pathStr = "M19.14 12.94c.04-.3.06-.61.06-.94 0-.32-.02-.64-.07-.94l2.03-1.58c.18-.14.23-.41.12-.61l-1.92-3.32c-.12-.22-.37-.29-.59-.22l-2.39.96c-.5-.38-1.03-.7-1.62-.94l-.36-2.54c-.04-.24-.24-.41-.48-.41h-3.84c-.24 0-.43.17-.47.41l-.36 2.54c-.59.24-1.13.57-1.62.94l-2.39-.96c-.22-.08-.47 0-.59.22L2.74 8.87c-.12.21-.08.47.12.61l2.03 1.58c-.05.3-.09.63-.09.94s.02.64.07.94l-2.03 1.58c-.18.14-.23.41-.12.61l1.92 3.32c.12.22.37.29.59.22l2.39-.96c.5.38 1.03.7 1.62.94l.36 2.54c.05.24.24.41.48.41h3.84c.24 0 .44-.17.47-.41l.36-2.54c.59-.24 1.13-.56 1.62-.94l2.39.96c.22.08.47 0 .59-.22l1.92-3.32c.12-.22.07-.47-.12-.61l-2.01-1.58zM12 15.6c-1.98 0-3.6-1.62-3.6-3.6s1.62-3.6 3.6-3.6 3.6 1.62 3.6 3.6-1.62 3.6-3.6 3.6z";
            break;
        case NeoSymbolShare:
            pathStr = "M18 16.08c-.76 0-1.44.3-1.96.77L8.91 12.7c.05-.23.09-.46.09-.7s-.04-.47-.09-.7l7.05-4.11c.54.5 1.25.81 2.04.81 1.66 0 3-1.34 3-3s-1.34-3-3-3-3 1.34-3 3c0 .24.04.47.09.7L8.04 9.81C7.5 9.31 6.79 9 6 9c-1.66 0-3 1.34-3 3s1.34 3 3 3c.79 0 1.5-.31 2.04-.81l7.12 4.16c-.05.21-.08.43-.08.65 0 1.61 1.31 2.92 2.92 2.92s2.92-1.31 2.92-2.92c0-1.61-1.31-2.92-2.92-2.92z";
            break;
    }

    UIImage *rendered = [self imageFromPathData:pathStr size:size grid:grid color:c stroke:stroke];
    if (rendered) {
        [symbolCache setObject:rendered forKey:key];
    }
    return rendered;
}

@end
