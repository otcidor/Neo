#import <UIKit/UIKit.h>

typedef enum {
    NeoSymbolMagnifier,
    NeoSymbolPaperclip,
    NeoSymbolCamera,
    NeoSymbolMicrophone,
    NeoSymbolCheckmark,
    NeoSymbolCheckmarkDouble,
    NeoSymbolLock,
    NeoSymbolClock,
    NeoSymbolChevronRight,
    NeoSymbolPin,
    NeoSymbolMapPin,
    NeoSymbolPlay,
    NeoSymbolPause,
    NeoSymbolClose,
    NeoSymbolTrash,
    NeoSymbolReply,
    NeoSymbolForward,
    NeoSymbolSettings,
    NeoSymbolShare
} NeoSymbolType;

@interface NeoSymbol : NSObject

+ (UIImage *)imageForType:(NeoSymbolType)type size:(CGFloat)size color:(UIColor *)color;
+ (UIImage *)imageFromPathData:(const char *)pathData size:(CGFloat)size grid:(CGFloat)grid color:(UIColor *)color stroke:(CGFloat)stroke;
+ (UIBezierPath *)bezierPathFromSVGData:(const char *)d;

@end
