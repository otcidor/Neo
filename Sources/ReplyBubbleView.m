#import "ReplyBubbleView.h"

#define kBarWidth 3.0f
#define kBarMargin 8.0f
#define kTextMargin 6.0f
#define kNameHeight 18.0f
#define kBodyMaxLines 2
#define kFontSize 13.0f

@implementation ReplyBubbleView

- (void)setSenderName:(NSString *)name {
    _senderName = [name copy];
    [self setNeedsDisplay];
}

- (void)setBody:(NSString *)b {
    _body = [b copy];
    [self setNeedsDisplay];
}

- (void)setOutgoing:(BOOL)flag {
    _outgoing = flag;
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    CGFloat w = self.bounds.size.width;
    CGFloat h = self.bounds.size.height;

    // Background
    UIColor *bg = _outgoing ? [UIColor colorWithWhite:0.85 alpha:0.5] : [UIColor colorWithWhite:0.92 alpha:0.4];
    [bg set];
    UIRectFill(rect);

    // Colored bar on left
    NSUInteger hash = [_senderName hash];
    CGFloat r = ((hash >> 16) & 0xFF) / 255.0;
    CGFloat g = ((hash >> 8) & 0xFF) / 255.0;
    CGFloat b = (hash & 0xFF) / 255.0;
    UIColor *barColor = [UIColor colorWithRed:r green:g blue:b alpha:0.8];
    [barColor set];
    UIRectFill(CGRectMake(kBarMargin, 4, kBarWidth, h - 8));

    // Sender name
    CGFloat textX = kBarMargin + kBarWidth + kTextMargin;
    CGFloat textW = w - textX - 8;
    [[UIColor darkTextColor] set];
    [_senderName drawInRect:CGRectMake(textX, 5, textW, kNameHeight)
                  withFont:[UIFont boldSystemFontOfSize:13]
             lineBreakMode:NSLineBreakByTruncatingTail
                 alignment:NSTextAlignmentLeft];

    // Body
    [[UIColor grayColor] set];
    CGFloat bodyY = 5 + kNameHeight + 1;
    CGFloat bodyH = h - bodyY - 4;
    CGRect bodyRect = CGRectMake(textX, bodyY, textW, bodyH);
    [_body drawInRect:bodyRect
             withFont:[UIFont systemFontOfSize:12]
        lineBreakMode:NSLineBreakByTruncatingTail
            alignment:NSTextAlignmentLeft];
}

+ (CGFloat)viewHeight {
    return 46.0f;
}

@end
