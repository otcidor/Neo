#import "MatrixBubbleView.h"
#import <QuartzCore/QuartzCore.h>
#import <CoreText/CoreText.h>

#define kMarginTop 4.0f
#define kMarginBottom 2.0f
#define kPaddingTop 4.0f
#define kPaddingBottom 24.0f
#define kBubblePaddingRight 35.0f
#define kSenderHeight 22.0f
#define kTimestampHeight 16.0f

@interface MatrixBubbleView () {
    NSArray *_linkResults;
    CTFrameRef _ctFrame;
    UITapGestureRecognizer *_linkTap;
}
- (void)detectLinks;
- (void)drawTextWithLinks:(NSString *)displayText inRect:(CGRect)textFrame;
- (void)handleLinkTap:(UITapGestureRecognizer *)tap;
@end

@implementation MatrixBubbleView

@synthesize type, text, timestamp, showTimestamp, userName, showUser, isRedacted, ack, hasMedia, mediaView, selectedToShowCopyMenu;

- (void)setup {
    self.backgroundColor = [UIColor clearColor];
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.userInteractionEnabled = YES;
    _linkTap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                       action:@selector(handleLinkTap:)];
    _linkTap.enabled = NO;
    [self addGestureRecognizer:_linkTap];
    _linkResults = @[];
}

- (id)initWithFrame:(CGRect)frame
               type:(MatrixBubbleMessageType)bubbleType
           showUser:(BOOL)showUserFlag
      showTimestamp:(BOOL)showTimestampFlag
           hasMedia:(BOOL)hasMediaFlag
          mediaView:(UIView *)mediaViewObj {
    self = [super initWithFrame:frame];
    if (self) {
        [self setup];
        self.type = bubbleType;
        self.showUser = showUserFlag;
        self.showTimestamp = showTimestampFlag;
        self.hasMedia = hasMediaFlag;
        self.mediaView = mediaViewObj;
        if (self.mediaView) {
            [self addSubview:self.mediaView];
        }
    }
    return self;
}

#pragma mark - Setters

- (void)setType:(MatrixBubbleMessageType)newType {
    type = newType;
    [self setNeedsDisplay];
}
- (void)setText:(NSString *)newText {
    text = newText;
    [self detectLinks];
    [self setNeedsDisplay];
}
- (void)setTimestamp:(NSDate *)newTimestamp {
    timestamp = newTimestamp;
    [self setNeedsDisplay];
}
- (void)setShowTimestamp:(BOOL)flag {
    showTimestamp = flag;
    [self setNeedsDisplay];
}
- (void)setUserName:(NSString *)newUserName {
    userName = newUserName;
    [self setNeedsDisplay];
}
- (void)setShowUser:(BOOL)flag {
    showUser = flag;
    [self setNeedsDisplay];
}
- (void)setIsRedacted:(BOOL)flag {
    isRedacted = flag;
    [self setNeedsDisplay];
}
- (void)setAck:(NSInteger)newAck {
    ack = newAck;
    [self setNeedsDisplay];
}
- (void)setHasMedia:(BOOL)flag {
    hasMedia = flag;
    [self setNeedsDisplay];
}
- (void)setSelectedToShowCopyMenu:(BOOL)flag {
    selectedToShowCopyMenu = flag;
    [self setNeedsDisplay];
}

#pragma mark - Drawing

- (BOOL)isNeoStyle {
    NSString *style = [[NSUserDefaults standardUserDefaults] stringForKey:@"neo_bubble_style"];
    return (style == nil || [style hasPrefix:@"neo"]);
}

- (NSString *)outgoingName {
    NSString *style = [[NSUserDefaults standardUserDefaults] stringForKey:@"neo_bubble_style"];
    if (style == nil || [style isEqualToString:@"neo"]) return @"neo-bubble-mine-green";
    if ([style isEqualToString:@"neo-cyan"])   return @"neo-bubble-mine-cyan";
    if ([style isEqualToString:@"neo-purple"]) return @"neo-bubble-mine-purple";
    if ([style isEqualToString:@"neo-pink"])   return @"neo-bubble-mine-pink";
    if ([style isEqualToString:@"neo-orange"]) return @"neo-bubble-mine-orange";
    if ([style isEqualToString:@"neo-red"])    return @"neo-bubble-mine-red";
    if ([style isEqualToString:@"neo-teal"])   return @"neo-bubble-mine-teal";
    if ([style isEqualToString:@"neo-indigo"]) return @"neo-bubble-mine-indigo";
    return @"bubble-square-outgoing";
}

- (NSString *)incomingName {
    NSString *style = [[NSUserDefaults standardUserDefaults] stringForKey:@"neo_bubble_style"];
    if (style == nil || [style isEqualToString:@"neo"]) return @"neo-bubble-someone-green";
    if ([style isEqualToString:@"neo-cyan"])   return @"neo-bubble-someone-cyan";
    if ([style isEqualToString:@"neo-purple"]) return @"neo-bubble-someone-purple";
    if ([style isEqualToString:@"neo-pink"])   return @"neo-bubble-someone-pink";
    if ([style isEqualToString:@"neo-orange"]) return @"neo-bubble-someone-orange";
    if ([style isEqualToString:@"neo-red"])    return @"neo-bubble-someone-red";
    if ([style isEqualToString:@"neo-teal"])   return @"neo-bubble-someone-teal";
    if ([style isEqualToString:@"neo-indigo"]) return @"neo-bubble-someone-indigo";
    return @"bubble-square-incoming";
}

- (NSString *)bubbleImageName {
    return self.type == MatrixBubbleMessageTypeOutgoing ? [self outgoingName] : [self incomingName];
}

- (UIImage *)bubbleImage {
    UIImage *img = [UIImage imageNamed:[self bubbleImageName]];
    NSInteger leftCap = self.type == MatrixBubbleMessageTypeOutgoing
        ? ([self isNeoStyle] ? 15 : 14)
        : ([self isNeoStyle] ? 21 : 20);
    return [img stretchableImageWithLeftCapWidth:leftCap topCapHeight:14];
}

- (CGRect)bubbleFrame {
    CGFloat userH = self.showUser ? kSenderHeight : 0;
    CGFloat mediaW = self.hasMedia ? self.mediaView.frame.size.width + kBubblePaddingRight : 0;
    CGFloat mediaH = self.hasMedia ? self.mediaView.frame.size.height : 0;
    CGSize bSize = [MatrixBubbleView bubbleSizeForText:self.text];
    CGFloat bw = MAX(bSize.width, mediaW);
    CGFloat bx = (self.type == MatrixBubbleMessageTypeOutgoing)
        ? self.frame.size.width - bw
        : 0;
    return CGRectMake(bx, kMarginTop, bw, bSize.height + userH + mediaH);
}

- (void)drawRect:(CGRect)frame {
    [super drawRect:frame];
    UIImage *image = [self bubbleImage];
    CGRect bFrame = [self bubbleFrame];

    if (isRedacted) {
        [image drawInRect:bFrame blendMode:kCGBlendModeNormal alpha:0.6];
    } else {
        [image drawInRect:bFrame];
    }

    CGFloat textX = image.leftCapWidth - 3.0f + (self.type == MatrixBubbleMessageTypeOutgoing ? bFrame.origin.x : 0);
    CGFloat userH = self.showUser ? kSenderHeight : 0;
    CGFloat mediaH = self.hasMedia ? self.mediaView.frame.size.height : 0;

    CGFloat contentY = kPaddingTop + kMarginTop + userH;
    if (self.hasMedia && self.mediaView) {
        self.mediaView.frame = CGRectMake(textX, contentY, self.mediaView.frame.size.width, self.mediaView.frame.size.height);
        contentY += mediaH;
    }

    NSString *displayText = isRedacted ? NSLocalizedString(@"Deleted message", nil) : self.text;
    CGSize textSize = [MatrixBubbleView textSizeForText:displayText];

    CGRect textFrame = CGRectMake(textX, contentY, textSize.width, textSize.height);

    CGFloat contentWidth = self.hasMedia
        ? MAX(textSize.width, self.mediaView.frame.size.width)
        : textSize.width;

    CGFloat tsY = contentY + textSize.height + 4;
    NSString *timeStr = @"";
    if (self.timestamp) {
        NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
        fmt.dateFormat = @"HH:mm";
        timeStr = [fmt stringFromDate:self.timestamp];
    }
    CGSize tsSize = [timeStr sizeWithFont:[UIFont italicSystemFontOfSize:12]];

    CGFloat const kAckSize = 12.0f;
    CGFloat const kAckGap = 4.0f;
    BOOL isOutgoing = (self.type == MatrixBubbleMessageTypeOutgoing);
    CGFloat ackReserve = isOutgoing ? (kAckSize + kAckGap) : 0;

    CGFloat tsX = textX;
    if (isOutgoing) {
        tsX = textX + contentWidth - tsSize.width - ackReserve;
    }

    if (self.showUser) {
        UIColor *userColor = [UIColor darkGrayColor];
        NSUInteger hash = [self.userName hash];
        CGFloat r = ((hash >> 16) & 0xFF) / 255.0;
        CGFloat g = ((hash >> 8) & 0xFF) / 255.0;
        CGFloat b = (hash & 0xFF) / 255.0;
        userColor = [UIColor colorWithRed:r green:g blue:b alpha:1.0];
        [userColor set];
        [self.userName drawInRect:CGRectMake(textX, kPaddingTop + kMarginTop, textSize.width, kSenderHeight)
                         withFont:[UIFont boldSystemFontOfSize:15]
                    lineBreakMode:NSLineBreakByClipping
                        alignment:NSTextAlignmentLeft];
    }

    if (isRedacted) {
        [[UIColor grayColor] set];
        [displayText drawInRect:textFrame
                      withFont:[UIFont italicSystemFontOfSize:14]
                 lineBreakMode:NSLineBreakByWordWrapping
                     alignment:NSTextAlignmentLeft];
    } else {
        [self drawTextWithLinks:displayText inRect:textFrame];
    }

    if (self.showTimestamp) {
        [[UIColor grayColor] set];
        [timeStr drawInRect:CGRectMake(tsX, tsY, tsSize.width, tsSize.height)
                   withFont:[UIFont italicSystemFontOfSize:12]
              lineBreakMode:NSLineBreakByClipping
                  alignment:isOutgoing ? NSTextAlignmentRight : NSTextAlignmentLeft];

        if (isOutgoing) {
            UIImage *ackImg = [UIImage imageNamed:@"MessageAckCheckSingle"];
            if (ackImg) {
                CGFloat ackX = tsX + tsSize.width + kAckGap;
                CGFloat ackY = tsY + (tsSize.height - kAckSize) / 2.0f;
                [ackImg drawInRect:CGRectMake(ackX, ackY, kAckSize, kAckSize)];
            }
        }
    }
}

#pragma mark - Links

- (void)detectLinks {
    if (!self.text || isRedacted) {
        _linkResults = @[];
        _linkTap.enabled = NO;
        return;
    }
    NSDataDetector *detector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:NULL];
    if (!detector) { _linkResults = @[]; _linkTap.enabled = NO; return; }
    NSMutableArray *results = [NSMutableArray array];
    [detector enumerateMatchesInString:self.text options:0
                                 range:NSMakeRange(0, [self.text length])
                            usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
        if (result.resultType == NSTextCheckingTypeLink) {
            [results addObject:result];
        }
    }];
    _linkResults = results;
    _linkTap.enabled = ([_linkResults count] > 0);
}

- (void)drawTextWithLinks:(NSString *)displayText inRect:(CGRect)textFrame {
    if ([_linkResults count] == 0) {
        [[UIColor darkTextColor] set];
        [displayText drawInRect:textFrame
                      withFont:[MatrixBubbleView font]
                 lineBreakMode:NSLineBreakByWordWrapping
                     alignment:NSTextAlignmentLeft];
        return;
    }

    NSMutableAttributedString *attrStr = [[NSMutableAttributedString alloc] initWithString:displayText];
    NSRange fullRange = NSMakeRange(0, [displayText length]);
    UIFont *font = [MatrixBubbleView font];
    [attrStr addAttribute:NSFontAttributeName value:font range:fullRange];
    [attrStr addAttribute:NSForegroundColorAttributeName value:[UIColor darkTextColor] range:fullRange];

    for (NSTextCheckingResult *result in _linkResults) {
        [attrStr addAttribute:NSForegroundColorAttributeName value:[UIColor blueColor] range:result.range];
        [attrStr addAttribute:NSUnderlineStyleAttributeName value:@(NSUnderlineStyleSingle) range:result.range];
    }

    CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)attrStr);

    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSaveGState(ctx);
    CGContextSetTextMatrix(ctx, CGAffineTransformIdentity);
    CGContextTranslateCTM(ctx, 0, self.bounds.size.height);
    CGContextScaleCTM(ctx, 1.0, -1.0);

    // Path in flipped coordinate space
    CGRect flippedFrame = CGRectMake(textFrame.origin.x,
                                     self.bounds.size.height - textFrame.origin.y - textFrame.size.height,
                                     textFrame.size.width,
                                     textFrame.size.height);
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathAddRect(path, NULL, flippedFrame);
    CTFrameRef ctFrame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, NULL);

    if (_ctFrame) CFRelease(_ctFrame);
    _ctFrame = (CTFrameRef)CFRetain(ctFrame);

    CTFrameDraw(ctFrame, ctx);
    CGContextRestoreGState(ctx);

    CFRelease(ctFrame);
    CFRelease(path);
    CFRelease(framesetter);
}

- (void)handleLinkTap:(UITapGestureRecognizer *)tap {
    if ([_linkResults count] == 0) return;
    CGPoint point = [tap locationInView:self];

    // Convert tap to Core Text coordinate space
    CGPoint ctPoint = CGPointMake(point.x, self.bounds.size.height - point.y);

    NSArray *lines = (__bridge NSArray *)CTFrameGetLines(_ctFrame);
    if (!lines) return;

    CGPoint origins[[lines count]];
    CTFrameGetLineOrigins(_ctFrame, CFRangeMake(0, 0), origins);

    for (NSUInteger i = 0; i < [lines count]; i++) {
        CTLineRef line = (__bridge CTLineRef)lines[i];
        CGPoint lineOrigin = origins[i];
        CGFloat ascent, descent, leading;
        CGFloat lineWidth = CTLineGetTypographicBounds(line, &ascent, &descent, &leading);

        CGRect lineBounds = CGRectMake(lineOrigin.x,
                                       lineOrigin.y - descent,
                                       lineWidth,
                                       ascent + descent);

        if (CGRectContainsPoint(lineBounds, ctPoint)) {
            CFIndex charIndex = CTLineGetStringIndexForPosition(line, CGPointMake(ctPoint.x - lineOrigin.x, ctPoint.y - lineOrigin.y));
            if (charIndex != kCFNotFound) {
                for (NSTextCheckingResult *result in _linkResults) {
                    if (charIndex >= (CFIndex)result.range.location &&
                        charIndex < (CFIndex)(result.range.location + result.range.length)) {
                        NSURL *url = result.URL;
                        if (url) {
                            [[UIApplication sharedApplication] openURL:url];
                        }
                        return;
                    }
                }
            }
            // Tapped within text but not on a link → ignore
            return;
        }
    }
}

- (void)dealloc {
    if (_ctFrame) CFRelease(_ctFrame);
}

#pragma mark - Sizing

+ (UIFont *)font {
    return [UIFont systemFontOfSize:15];
}

+ (CGSize)textSizeForText:(NSString *)txt {
    CGFloat maxW = [UIScreen mainScreen].applicationFrame.size.width * 0.75f;
    if ([txt length] == 0) return CGSizeZero;
    CGSize size = [txt sizeWithFont:[MatrixBubbleView font]
                  constrainedToSize:CGSizeMake(maxW - kBubblePaddingRight, CGFLOAT_MAX)
                      lineBreakMode:NSLineBreakByWordWrapping];
    size.width = MAX(size.width, 72);
    return size;
}

+ (CGSize)bubbleSizeForText:(NSString *)txt {
    CGSize textSize = [MatrixBubbleView textSizeForText:txt];
    return CGSizeMake(textSize.width + kBubblePaddingRight,
                      textSize.height + kPaddingTop + kPaddingBottom);
}

+ (CGFloat)cellHeightForText:(NSString *)txt
                    showUser:(BOOL)showUserFlag
               showTimestamp:(BOOL)showTimestampFlag
                  isRedacted:(BOOL)isRedactedFlag {
    NSString *displayText = isRedactedFlag ? NSLocalizedString(@"Deleted message", nil) : txt;
    CGSize bSize = [MatrixBubbleView bubbleSizeForText:displayText];
    CGFloat userH = showUserFlag ? kSenderHeight : 0;
    return kMarginTop + userH + bSize.height + kMarginBottom;
}

+ (CGFloat)textXOffsetForType:(MatrixBubbleMessageType)type {
    NSString *style = [[NSUserDefaults standardUserDefaults] stringForKey:@"neo_bubble_style"];
    BOOL isNeo = (style == nil || [style hasPrefix:@"neo"]);
    NSInteger leftCap = (type == MatrixBubbleMessageTypeOutgoing)
        ? (isNeo ? 15 : 14)
        : (isNeo ? 21 : 20);
    return leftCap - 3.0f;
}

+ (CGFloat)cellHeightForMediaWithText:(NSString *)txt
                             showUser:(BOOL)showUserFlag
                        showTimestamp:(BOOL)showTimestampFlag
                           isRedacted:(BOOL)isRedactedFlag
                          mediaHeight:(CGFloat)mediaHeight {
    NSString *displayText = isRedactedFlag ? NSLocalizedString(@"Deleted message", nil) : txt;
    CGSize bSize = [MatrixBubbleView bubbleSizeForText:displayText];
    CGFloat userH = showUserFlag ? kSenderHeight : 0;
    return kMarginTop + userH + bSize.height + mediaHeight + kMarginBottom;
}

@end
