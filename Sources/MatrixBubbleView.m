#import "MatrixBubbleView.h"
#import "NeoCompatibility.h"
#import <QuartzCore/QuartzCore.h>
#import <CoreText/CoreText.h>

#define kMarginTop 4.0f
#define kMarginBottom 2.0f
#define kPaddingTop 8.0f
#define kPaddingBottom 24.0f
#define kBubblePaddingRight 35.0f
#define kLargeEmojiFontSize 40.0f

static bool isEmojiChar(NSString *singleChar) {
    if ([singleChar length] == 0) return false;
    const unichar high = [singleChar characterAtIndex:0];
    if (0xd800 <= high && high <= 0xdbff && [singleChar length] >= 2) {
        const unichar low = [singleChar characterAtIndex:1];
        const int cp = ((high - 0xd800) * 0x400) + (low - 0xdc00) + 0x10000;
        return (0x1d000 <= cp && cp <= 0x1f77f);
    }
    return (0x2100 <= high && high <= 0x27bf);
}

#define kSenderHeight 22.0f
#define kTimestampHeight 16.0f
#define kReplyPreviewHeight 40.0f

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

+ (BOOL)stringContainsEmojiOnly:(NSString *)string length:(NSUInteger *)count {
    if ([string length] == 0) return false;
    __block BOOL result = YES;
    __block NSUInteger c = 0;
    [string enumerateSubstringsInRange:NSMakeRange(0, [string length])
                               options:NSStringEnumerationByComposedCharacterSequences
                            usingBlock:^(NSString *sub, NSRange r, NSRange e, BOOL *stop) {
        if (!isEmojiChar(sub)) { result = NO; *stop = YES; }
        c++;
    }];
    if (count) *count = c;
    return result;
}

+ (UIColor *)colorForUserId:(NSString *)userId {
    if ([userId length] == 0) return [UIColor grayColor];
    NSUInteger hash = [userId hash];
    NSArray *palette = @[
        [UIColor colorWithRed:1.0 green:0.32 blue:0.35 alpha:1.0],
        [UIColor colorWithRed:1.0 green:0.66 blue:0.36 alpha:1.0],
        [UIColor colorWithRed:0.4 green:0.37 blue:1.0 alpha:1.0],
        [UIColor colorWithRed:0.33 green:0.8 blue:0.41 alpha:1.0],
        [UIColor colorWithRed:0.16 green:0.79 blue:0.72 alpha:1.0],
        [UIColor colorWithRed:0.16 green:0.62 blue:0.95 alpha:1.0],
        [UIColor colorWithRed:0.84 green:0.41 blue:0.93 alpha:1.0],
    ];
    return palette[hash % 7];
}

@synthesize type, text, timestamp, showTimestamp, userName, showUser, isRedacted, ack, hasMedia, mediaView,selectedToShowCopyMenu, replySenderName, replyBody, isMentioned;

- (void)setIsMentioned:(BOOL)flag {
    isMentioned = flag;
    [self setNeedsDisplay];
}

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
- (void)setReplySenderName:(NSString *)name {
    replySenderName = [name copy];
    [self setNeedsDisplay];
}
- (void)setReplyBody:(NSString *)b {
    replyBody = [b copy];
    [self setNeedsDisplay];
}
- (void)setMediaView:(UIView *)newMediaView {
    if (mediaView != newMediaView) {
        [mediaView removeFromSuperview];
        mediaView = newMediaView;
        if (mediaView) {
            [self addSubview:mediaView];
        }
        [self setNeedsDisplay];
    }
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
    if ([style isEqualToString:@"neo-telegram"]) return @"neo-bubble-mine-telegram";
    if ([style isEqualToString:@"neo-telegram-classic"]) return @"neo-bubble-mine-telegram-classic";
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
    if ([style isEqualToString:@"neo-telegram"]) return @"neo-bubble-someone-telegram";
    if ([style isEqualToString:@"neo-telegram-classic"]) return @"neo-bubble-someone-telegram-classic";
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
    CGFloat replyH = ([self.replySenderName length] > 0 && [self.replyBody length] > 0) ? (kReplyPreviewHeight + 5) : 0;
    return CGRectMake(bx, kMarginTop, bw, bSize.height + userH + mediaH + replyH);
}

- (void)drawRect:(CGRect)frame {
    [super drawRect:frame];

    if (self.isEmojiOnly && !isRedacted) {
        NSString *emojiText = self.text ?: @"";
        CGFloat w = self.bounds.size.width;
        UIFont *bigFont = [UIFont systemFontOfSize:kLargeEmojiFontSize];
        CGSize ts = [text sizeWithFont:bigFont];

        CGFloat x = (self.type == MatrixBubbleMessageTypeOutgoing) ? w - ts.width - 12 : 12;
        CGFloat y = (self.bounds.size.height - ts.height) / 2;
        [emojiText drawInRect:CGRectMake(x, y, ts.width, ts.height) withFont:bigFont];

        if (self.showTimestamp && self.timestamp) {
            NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
            fmt.dateFormat = @"HH:mm";
            NSString *timeStr = [fmt stringFromDate:self.timestamp];
            CGSize tsz = [timeStr sizeWithFont:[UIFont systemFontOfSize:10]];
            [[UIColor grayColor] set];
            CGFloat tx = (self.type == MatrixBubbleMessageTypeOutgoing) ? x - tsz.width - 6 : x + ts.width + 6;
            [timeStr drawInRect:CGRectMake(tx, y + ts.height - tsz.height, tsz.width, tsz.height)
                       withFont:[UIFont systemFontOfSize:10]];
        }
        return;
    }

    UIImage *image = [self bubbleImage];
    CGRect bFrame = [self bubbleFrame];

    if (isRedacted) {
        [image drawInRect:bFrame blendMode:kCGBlendModeNormal alpha:0.6];
    } else {
        [image drawInRect:bFrame];
    }

    if (self.isMentioned && self.type == MatrixBubbleMessageTypeIncoming) {
        CGContextRef ctx = UIGraphicsGetCurrentContext();
        CGContextSaveGState(ctx);
        CGFloat barWidth = 3.5f;
        CGFloat barX = bFrame.origin.x + 4.0f;
        CGFloat barY = bFrame.origin.y + 6.0f;
        CGFloat barH = MAX(16.0f, bFrame.size.height - 12.0f);
        UIBezierPath *barPath = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(barX, barY, barWidth, barH) cornerRadius:1.75f];
        [[UIColor colorWithRed:1.0f green:0.60f blue:0.0f alpha:0.95f] setFill];
        [barPath fill];
        CGContextRestoreGState(ctx);
    }

    CGFloat textX = image.leftCapWidth - 3.0f + (self.type == MatrixBubbleMessageTypeOutgoing ? bFrame.origin.x : 0);
    CGFloat userH = self.showUser ? kSenderHeight : 0;
    CGFloat mediaH = self.hasMedia ? self.mediaView.frame.size.height : 0;

    NSString *displayText = isRedacted ? NSLocalizedString(@"Deleted message", nil) : self.text;
    CGSize textSize = [MatrixBubbleView textSizeForText:displayText];
    CGFloat mediaW = self.hasMedia ? self.mediaView.frame.size.width : 0;
    CGFloat contentWidth = MAX(textSize.width, mediaW);

    CGFloat contentY = kPaddingTop + kMarginTop + userH;

    // Draw reply quote block inside bubble (if present)
    BOOL hasReply = ([self.replySenderName length] > 0 && [self.replyBody length] > 0);
    if (hasReply) {
        CGFloat replyContentX = textX + 6;
        CGFloat replyContentW = contentWidth - 6;
        CGFloat replyY = contentY;

        // Colored bar left
        NSUInteger hash = [self.replySenderName hash];
        CGFloat r = ((hash >> 16) & 0xFF) / 255.0;
        CGFloat g = ((hash >> 8) & 0xFF) / 255.0;
        CGFloat b = (hash & 0xFF) / 255.0;
        [[UIColor colorWithRed:r green:g blue:b alpha:0.8] set];
        UIRectFill(CGRectMake(textX, replyY, 3, kReplyPreviewHeight - 4));

        // Sender name
        [[UIColor darkTextColor] set];
        CGFloat nameH = 16;
        [self.replySenderName drawInRect:CGRectMake(replyContentX, replyY + 2, replyContentW, nameH)
                               withFont:[UIFont boldSystemFontOfSize:12]
                          lineBreakMode:NSLineBreakByTruncatingTail
                              alignment:NSTextAlignmentLeft];

        // Body (1-2 lines)
        [[UIColor grayColor] set];
        CGFloat bodyY = replyY + 2 + nameH + 1;
        CGFloat bodyMaxH = kReplyPreviewHeight - 4 - 2 - nameH - 1;
        CGRect bodyRect = CGRectMake(replyContentX, bodyY, replyContentW, bodyMaxH);
        [self.replyBody drawInRect:bodyRect
                          withFont:[UIFont systemFontOfSize:11]
                     lineBreakMode:NSLineBreakByTruncatingTail
                         alignment:NSTextAlignmentLeft];

        // Separator line below reply
        [[UIColor colorWithWhite:0.8 alpha:0.6] set];
        UIRectFill(CGRectMake(textX, replyY + kReplyPreviewHeight - 1, contentWidth, 0.5));

        contentY += kReplyPreviewHeight;
    }

    if (self.hasMedia && self.mediaView) {
        self.mediaView.frame = CGRectMake(textX, contentY, self.mediaView.frame.size.width, self.mediaView.frame.size.height);
        contentY += mediaH;
    }

    CGRect textFrame = CGRectMake(textX, contentY, textSize.width, textSize.height);

    CGFloat tsY = CGRectGetMaxY(bFrame) - kTimestampHeight - 4.0f;
    NSString *timeStr = @"";
    if (self.timestamp) {
        NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
        fmt.dateFormat = @"HH:mm";
        timeStr = [fmt stringFromDate:self.timestamp];
    }
    CGSize tsSize = [MatrixBubbleView neoSizeForString:timeStr
                                                  font:[UIFont italicSystemFontOfSize:12]
                                              maxWidth:CGFLOAT_MAX
                                         lineBreakMode:NSLineBreakByClipping];

    CGFloat const kAckSize = 12.0f;
    CGFloat const kAckGap = 4.0f;
    BOOL isOutgoing = (self.type == MatrixBubbleMessageTypeOutgoing);
    BOOL doubleCheck = (isOutgoing && ack == 2);
    CGFloat ackReserve = isOutgoing ? (kAckSize + kAckGap + (doubleCheck ? 6.0f : 0)) : 0;

    CGFloat tsX = textX;
    if (isOutgoing) {
        tsX = textX + contentWidth - tsSize.width - ackReserve;
    }

    if (self.showUser) {
        [[MatrixBubbleView colorForUserId:self.senderId] set];
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
        CGRect tsRect = CGRectMake(tsX, tsY, tsSize.width, tsSize.height);
        UIFont *tsFont = [UIFont italicSystemFontOfSize:12];
        if (IS_IOS7_OR_LATER && tsFont) {
            NSMutableParagraphStyle *ps = [[NSMutableParagraphStyle alloc] init];
            if (ps) ps.lineBreakMode = NSLineBreakByClipping;
            NSMutableDictionary *attrs = [NSMutableDictionary dictionary];
            [attrs setObject:tsFont forKey:NSFontAttributeName];
            [attrs setObject:[UIColor grayColor] forKey:NSForegroundColorAttributeName];
            if (ps) [attrs setObject:ps forKey:NSParagraphStyleAttributeName];
            [timeStr drawWithRect:tsRect
                          options:NSStringDrawingUsesLineFragmentOrigin
                       attributes:attrs
                          context:nil];
        } else {
            [[UIColor grayColor] set];
            [timeStr drawInRect:tsRect
                       withFont:tsFont
                  lineBreakMode:NSLineBreakByClipping
                      alignment:NSTextAlignmentLeft];
        }

        if (isOutgoing) {
            CGFloat ackX = tsX + tsSize.width + kAckGap;
            CGFloat ackY = tsY + (tsSize.height - kAckSize) / 2.0f;
            if (ack == 3) {
                CGContextRef ctx = UIGraphicsGetCurrentContext();
                CGContextSetFillColorWithColor(ctx, [UIColor colorWithRed:0.86f green:0.22f blue:0.15f alpha:1.0f].CGColor);
                CGContextFillEllipseInRect(ctx, CGRectMake(ackX, ackY, kAckSize, kAckSize));
                [[UIColor whiteColor] set];
                [@"!" drawInRect:CGRectMake(ackX, ackY - 1.0f, kAckSize, kAckSize + 1.0f)
                        withFont:[UIFont boldSystemFontOfSize:10]
                   lineBreakMode:NSLineBreakByClipping
                       alignment:NSTextAlignmentCenter];
            } else if (ack == 0) {
                CGContextRef ctx = UIGraphicsGetCurrentContext();
                CGContextSetStrokeColorWithColor(ctx, [UIColor grayColor].CGColor);
                CGContextSetLineWidth(ctx, 1.0f);
                CGContextStrokeEllipseInRect(ctx, CGRectMake(ackX + 0.5f, ackY + 0.5f, kAckSize - 1.0f, kAckSize - 1.0f));
                CGFloat cx = ackX + kAckSize / 2.0f;
                CGFloat cy = ackY + kAckSize / 2.0f;
                CGContextMoveToPoint(ctx, cx, cy);
                CGContextAddLineToPoint(ctx, cx, ackY + 2.5f);
                CGContextMoveToPoint(ctx, cx, cy);
                CGContextAddLineToPoint(ctx, cx + 2.5f, cy + 1.5f);
                CGContextStrokePath(ctx);
            } else {
                UIImage *ackImg = [UIImage imageNamed:@"MessageAckCheckSingle"];
                if (ackImg) {
                    if (ack == 2) {
                        [ackImg drawInRect:CGRectMake(ackX, ackY, kAckSize, kAckSize)];
                        [ackImg drawInRect:CGRectMake(ackX + 5.0f, ackY, kAckSize, kAckSize)];
                    } else {
                        [ackImg drawInRect:CGRectMake(ackX, ackY, kAckSize, kAckSize)];
                    }
                }
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
    NSMutableArray *results = [NSMutableArray array];

    NSError *err = nil;
    NSDataDetector *detector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:&err];
    if (detector) {
        [detector enumerateMatchesInString:self.text options:0
                                     range:NSMakeRange(0, [self.text length])
                                 usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
            if (result.resultType == NSTextCheckingTypeLink) {
                [results addObject:result];
            }
        }];
    }

    // Supplement with manual regex for URLs that NSDataDetector misses (varies by iOS version)
    NSString *pattern = @"(?:https?://|www\\.)[^\\s]+";
    NSRegularExpression *manual = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:NULL];
    if (manual) {
        [manual enumerateMatchesInString:self.text options:0
                                   range:NSMakeRange(0, [self.text length])
                              usingBlock:^(NSTextCheckingResult *match, NSMatchingFlags flags, BOOL *stop) {
            // Avoid duplicates with detector results
            BOOL dup = NO;
            for (NSTextCheckingResult *existing in results) {
                if (NSEqualRanges(existing.range, match.range)) { dup = YES; break; }
            }
            if (!dup) {
                NSString *urlStr = [self.text substringWithRange:match.range];
                if (![urlStr hasPrefix:@"http"]) urlStr = [@"http://" stringByAppendingString:urlStr];
                NSURL *url = [NSURL URLWithString:urlStr];
                if (url) {
                    NSTextCheckingResult *link = [NSTextCheckingResult linkCheckingResultWithRange:match.range URL:url];
                    [results addObject:link];
                }
            }
        }];
    }

    // Detect mentions like @user:server or @DisplayName or @room
    NSError *mentionErr = nil;
    NSRegularExpression *mentionRegex = [NSRegularExpression regularExpressionWithPattern:@"(?<=^|\\s)@([a-zA-Z0-9_\\-\\.\\+=]+(:[a-zA-Z0-9_\\-\\.]+)?)" options:0 error:&mentionErr];
    if (mentionRegex) {
        NSArray *matches = [mentionRegex matchesInString:self.text options:0 range:NSMakeRange(0, [self.text length])];
        for (NSTextCheckingResult *m in matches) {
            BOOL dup = NO;
            for (NSTextCheckingResult *existing in results) {
                if (NSEqualRanges(existing.range, m.range)) { dup = YES; break; }
            }
            if (!dup) {
                NSString *target = [self.text substringWithRange:m.range];
                NSString *cleanTarget = [target stringByReplacingOccurrencesOfString:@"@" withString:@""];
                NSURL *mentionURL = [NSURL URLWithString:[NSString stringWithFormat:@"matrix://%@", cleanTarget]];
                if (mentionURL) {
                    NSTextCheckingResult *link = [NSTextCheckingResult linkCheckingResultWithRange:m.range URL:mentionURL];
                    [results addObject:link];
                }
            }
        }
    }

    _linkResults = results;
    _linkTap.enabled = ([_linkResults count] > 0);
}

- (void)drawTextWithLinks:(NSString *)displayText inRect:(CGRect)textFrame {
    if ([_linkResults count] == 0) {
        UIFont *msgFont = [MatrixBubbleView font];
        if (IS_IOS7_OR_LATER && msgFont) {
            NSMutableParagraphStyle *ps = [[NSMutableParagraphStyle alloc] init];
            if (ps) ps.lineBreakMode = NSLineBreakByWordWrapping;
            NSMutableDictionary *attrs = [NSMutableDictionary dictionary];
            [attrs setObject:msgFont forKey:NSFontAttributeName];
            [attrs setObject:[UIColor darkTextColor] forKey:NSForegroundColorAttributeName];
            if (ps) [attrs setObject:ps forKey:NSParagraphStyleAttributeName];
            [displayText drawWithRect:textFrame
                              options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                           attributes:attrs
                              context:nil];
        } else {
            [[UIColor darkTextColor] set];
            [displayText drawInRect:textFrame
                           withFont:msgFont
                      lineBreakMode:NSLineBreakByWordWrapping
                          alignment:NSTextAlignmentLeft];
        }
        return;
    }

    NSMutableAttributedString *attrStr = [[NSMutableAttributedString alloc] initWithString:displayText];
    NSRange fullRange = NSMakeRange(0, [displayText length]);
    UIFont *font = [MatrixBubbleView font];
    if (!font) {
        [[UIColor darkTextColor] set];
        [displayText drawInRect:textFrame
                       withFont:nil
                  lineBreakMode:NSLineBreakByWordWrapping
                      alignment:NSTextAlignmentLeft];
        return;
    }
    [attrStr addAttribute:NSFontAttributeName value:font range:fullRange];
    [attrStr addAttribute:NSForegroundColorAttributeName value:[UIColor darkTextColor] range:fullRange];

    for (NSTextCheckingResult *result in _linkResults) {
        if ([result.URL.scheme isEqualToString:@"matrix"]) {
            [attrStr addAttribute:NSForegroundColorAttributeName value:[UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:1.0] range:result.range];
            [attrStr addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:15] range:result.range];
        } else {
            [attrStr addAttribute:NSForegroundColorAttributeName value:[UIColor blueColor] range:result.range];
            [attrStr addAttribute:NSUnderlineStyleAttributeName value:@(NSUnderlineStyleSingle) range:result.range];
        }
    }

    CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)attrStr);

    CGSize suggestedSize = CTFramesetterSuggestFrameSizeWithConstraints(
        framesetter, CFRangeMake(0, 0), NULL,
        CGSizeMake(textFrame.size.width, CGFLOAT_MAX), NULL);
    CGFloat actualTextHeight = MAX(textFrame.size.height, ceilf(suggestedSize.height));

    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSaveGState(ctx);
    CGContextSetTextMatrix(ctx, CGAffineTransformIdentity);
    CGContextTranslateCTM(ctx, 0, self.bounds.size.height);
    CGContextScaleCTM(ctx, 1.0, -1.0);

    CGRect flippedFrame = CGRectMake(textFrame.origin.x,
                                     self.bounds.size.height - textFrame.origin.y - actualTextHeight,
                                     textFrame.size.width,
                                     actualTextHeight);
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
                            if ([url.scheme isEqualToString:@"matrix"]) {
                                [[NSNotificationCenter defaultCenter] postNotificationName:@"NeoMentionTappedNotification" object:url.resourceSpecifier ?: @""];
                                return;
                            }
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

+ (CGSize)neoSizeForString:(NSString *)str
                      font:(UIFont *)font
                 maxWidth:(CGFloat)maxWidth
            lineBreakMode:(NSLineBreakMode)mode {
    if ([str length] == 0) return CGSizeZero;
    if (IS_IOS7_OR_LATER && font) {
        NSMutableParagraphStyle *ps = [[NSMutableParagraphStyle alloc] init];
        if (ps) ps.lineBreakMode = mode;
        NSMutableDictionary *attrs = [NSMutableDictionary dictionary];
        [attrs setObject:font forKey:NSFontAttributeName];
        if (ps) [attrs setObject:ps forKey:NSParagraphStyleAttributeName];
        CGRect r = [str boundingRectWithSize:CGSizeMake(maxWidth, CGFLOAT_MAX)
                                     options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                                  attributes:attrs
                                     context:nil];
        return CGSizeMake(ceilf(r.size.width), ceilf(r.size.height));
    }
    return [str sizeWithFont:font
           constrainedToSize:CGSizeMake(maxWidth, CGFLOAT_MAX)
               lineBreakMode:mode];
}

+ (CGSize)textSizeForText:(NSString *)txt {
    CGFloat maxW = [UIScreen mainScreen].applicationFrame.size.width * 0.75f;
    if ([txt length] == 0) return CGSizeZero;
    CGSize size = [MatrixBubbleView neoSizeForString:txt
                                                font:[MatrixBubbleView font]
                                            maxWidth:maxW - kBubblePaddingRight
                                       lineBreakMode:NSLineBreakByWordWrapping];
    size.width = MAX(size.width, 72);
    return size;
}

+ (CGSize)largeEmojiSizeForText:(NSString *)txt {
    CGSize size = [txt sizeWithFont:[UIFont systemFontOfSize:kLargeEmojiFontSize]];
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

+ (CGFloat)cellHeightForEmojiOnly:(NSString *)txt {
    if ([txt length] == 0) return 0;
    CGSize ts = [MatrixBubbleView largeEmojiSizeForText:txt];
    return MAX(ts.height + 20, 60);
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

+ (CGFloat)replyPreviewHeight {
    return kReplyPreviewHeight + 5;
}

@end
