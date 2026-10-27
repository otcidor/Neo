#import "MatrixBubbleView.h"
#import "NeoCompatibility.h"
#import "ThemeManager.h"
#import <QuartzCore/QuartzCore.h>
#import <CoreText/CoreText.h>

#define kMarginTop 2.0f
#define kMarginBottom 2.0f
#define kPaddingTop 7.0f
#define kPaddingBottomInline 9.0f
#define kPaddingBottomBreak 18.0f
#define kStandardMinBubbleHeight 38.0f
#define kBubblePaddingHorizontalOutgoing 28.0f
#define kBubblePaddingHorizontalIncoming 30.0f
#define kLargeEmojiFontSize 40.0f
#define kSenderHeight 16.0f
#define kTimestampHeight 14.0f
#define kReplyPreviewHeight 38.0f

@interface NeoMediaTimestampBadgeView : UIView
@property (nonatomic, copy) NSString *timeString;
@property (nonatomic, assign) NSInteger ack;
@property (nonatomic, assign) BOOL isOutgoing;
@end

@implementation NeoMediaTimestampBadgeView

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.55f];
        self.clipsToBounds = YES;
        self.userInteractionEnabled = NO;
        self.layer.cornerRadius = 9.0f;
    }
    return self;
}

- (void)setTimeString:(NSString *)timeString {
    if (![_timeString isEqualToString:timeString]) {
        _timeString = [timeString copy];
        [self setNeedsDisplay];
    }
}

- (void)setAck:(NSInteger)ack {
    if (_ack != ack) {
        _ack = ack;
        [self setNeedsDisplay];
    }
}

- (void)setIsOutgoing:(BOOL)isOutgoing {
    if (_isOutgoing != isOutgoing) {
        _isOutgoing = isOutgoing;
        [self setNeedsDisplay];
    }
}

- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];
    self.layer.cornerRadius = self.bounds.size.height / 2.0f;

    UIFont *font = [UIFont systemFontOfSize:11];
    [[UIColor whiteColor] set];

    CGFloat x = 6.0f;
    NSString *tsStr = self.timeString ?: @"12:00";
    CGSize ts = [tsStr sizeWithFont:font];
    CGFloat y = floorf((self.bounds.size.height - ts.height) / 2.0f);
    [tsStr drawInRect:CGRectMake(x, y, ts.width, ts.height)
             withFont:font
        lineBreakMode:NSLineBreakByClipping];

    if (self.isOutgoing) {
        CGFloat ackX = x + ts.width + 3.0f;
        CGFloat ackY = floorf((self.bounds.size.height - 11.0f) / 2.0f);
        if (self.ack == 3) {
            UIImage *notSent = [UIImage imageNamed:@"NotSent"];
            if (notSent) {
                [notSent drawInRect:CGRectMake(ackX, ackY - 1.0f, 12.0f, 12.0f)];
            }
        } else if (self.ack == 0) {
            CGFloat const kAckSize = 10.0f;
            CGContextRef ctx = UIGraphicsGetCurrentContext();
            CGContextSetStrokeColorWithColor(ctx, [UIColor whiteColor].CGColor);
            CGContextSetLineWidth(ctx, 1.0f);
            CGContextStrokeEllipseInRect(ctx, CGRectMake(ackX + 0.5f, ackY + 0.5f, kAckSize - 1.0f, kAckSize - 1.0f));
            CGFloat cx = ackX + kAckSize / 2.0f;
            CGFloat cy = ackY + kAckSize / 2.0f;
            CGContextMoveToPoint(ctx, cx, cy);
            CGContextAddLineToPoint(ctx, cx, ackY + 2.0f);
            CGContextMoveToPoint(ctx, cx, cy);
            CGContextAddLineToPoint(ctx, cx + 2.0f, cy + 1.0f);
            CGContextStrokePath(ctx);
        } else {
            NSString *checkName = (self.ack == 2) ? @"ModernMessageCheckmarkMedia2" : @"ModernMessageCheckmarkMedia1";
            UIImage *checkImg = [UIImage imageNamed:checkName];
            if (!checkImg) {
                checkName = (self.ack == 2) ? @"MessageCheckFull" : @"MessageCheckHalf";
                checkImg = [UIImage imageNamed:checkName];
            }
            if (checkImg) {
                [checkImg drawInRect:CGRectMake(ackX, ackY, 12.0f, 11.0f)];
            }
        }
    }
}

@end

typedef struct {
    CGSize bubbleSize;
    CGRect textRect;
    CGRect tsRect;
    CGRect ackRect;
    CGRect userRect;
    CGRect replyRect;
    CGRect mediaRect;
    BOOL isInline;
} NeoBubbleLayout;

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

@interface MatrixBubbleView () {
    NSArray *_linkResults;
    CTFrameRef _ctFrame;
    UITapGestureRecognizer *_linkTap;
    NeoMediaTimestampBadgeView *_mediaBadgeView;
}
+ (NeoBubbleLayout)layoutForText:(NSString *)txt
                            type:(MatrixBubbleMessageType)type
                        showUser:(BOOL)showUserFlag
                   userTitleText:(NSString *)userTitleText
                   showTimestamp:(BOOL)showTimestampFlag
                       timestamp:(NSDate *)timestamp
                             ack:(NSInteger)ack
                        hasReply:(BOOL)hasReplyFlag
                 replySenderName:(NSString *)replySenderName
                       replyBody:(NSString *)replyBody
                        hasMedia:(BOOL)hasMediaFlag
                       mediaSize:(CGSize)mediaSize
                   isVisualMedia:(BOOL)isVisualMediaFlag
                      isRedacted:(BOOL)isRedactedFlag;
+ (NeoBubbleLayout)layoutForText:(NSString *)txt
                            type:(MatrixBubbleMessageType)type
                        showUser:(BOOL)showUserFlag
                   userTitleText:(NSString *)userTitleText
                   showTimestamp:(BOOL)showTimestampFlag
                       timestamp:(NSDate *)timestamp
                             ack:(NSInteger)ack
                        hasReply:(BOOL)hasReplyFlag
                 replySenderName:(NSString *)replySenderName
                       replyBody:(NSString *)replyBody
                        hasMedia:(BOOL)hasMediaFlag
                       mediaSize:(CGSize)mediaSize
                      isRedacted:(BOOL)isRedactedFlag;
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

@synthesize type, text, timestamp, showTimestamp, userName, showUser, isRedacted, ack, hasMedia, mediaView,selectedToShowCopyMenu, replySenderName, replyBody, isMentioned, isVisualMedia;

- (BOOL)effectiveIsVisualMedia {
    if (self.isVisualMedia) return YES;
    if (self.hasMedia && self.mediaView) {
        if ([self.mediaView isKindOfClass:[UIImageView class]]) return YES;
        if ([self.mediaView isKindOfClass:NSClassFromString(@"VideoMessageView")]) return YES;
    }
    return NO;
}

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
    _mediaBadgeView = [[NeoMediaTimestampBadgeView alloc] initWithFrame:CGRectZero];
    _mediaBadgeView.hidden = YES;
    [self addSubview:_mediaBadgeView];
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
            if (_mediaBadgeView) {
                [self bringSubviewToFront:_mediaBadgeView];
            }
        }
        [self setNeedsDisplay];
    }
}

- (NSString *)formattedTimeString {
    if (!self.timestamp) return @"12:00";
    static NSDateFormatter *sFmt = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sFmt = [[NSDateFormatter alloc] init];
        sFmt.dateFormat = @"HH:mm";
    });
    return [sFmt stringFromDate:self.timestamp] ?: @"12:00";
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (self.hasMedia && self.mediaView) {
        CGRect bFrame = [self bubbleFrame];
        BOOL hasReply = ([self.replySenderName length] > 0 && [self.replyBody length] > 0);
        CGSize mediaSize = self.mediaView.frame.size;
        BOOL visualMedia = [self effectiveIsVisualMedia];
        NSString *displayText = self.isRedacted ? NSLocalizedString(@"Deleted message", nil) : (self.text ?: @"");
        BOOL mediaWithoutCaption = (visualMedia && self.hasMedia && [displayText length] == 0 && !self.showUser && !hasReply);

        NeoBubbleLayout layout = [MatrixBubbleView layoutForText:self.text
                                                            type:self.type
                                                        showUser:self.showUser
                                                   userTitleText:self.userName
                                                   showTimestamp:self.showTimestamp
                                                       timestamp:self.timestamp
                                                             ack:self.ack
                                                        hasReply:hasReply
                                                 replySenderName:self.replySenderName
                                                       replyBody:self.replyBody
                                                        hasMedia:self.hasMedia
                                                       mediaSize:mediaSize
                                                   isVisualMedia:visualMedia
                                                      isRedacted:self.isRedacted];

        if (!CGRectIsEmpty(layout.mediaRect)) {
            self.mediaView.frame = CGRectOffset(layout.mediaRect, bFrame.origin.x, bFrame.origin.y);
        }
        if (mediaWithoutCaption && self.showTimestamp) {
            _mediaBadgeView.hidden = NO;
            _mediaBadgeView.timeString = [self formattedTimeString];
            _mediaBadgeView.ack = self.ack;
            _mediaBadgeView.isOutgoing = (self.type == MatrixBubbleMessageTypeOutgoing);
            CGFloat totalInfoW = layout.tsRect.size.width + (self.type == MatrixBubbleMessageTypeOutgoing ? (12.0f + 3.0f) : 0.0f);
            CGFloat badgeW = totalInfoW + 12.0f;
            CGFloat badgeH = 18.0f;
            CGRect mediaRect = CGRectOffset(layout.mediaRect, bFrame.origin.x, bFrame.origin.y);
            _mediaBadgeView.frame = CGRectMake(CGRectGetMaxX(mediaRect) - badgeW - 6.0f,
                                               CGRectGetMaxY(mediaRect) - badgeH - 6.0f,
                                               badgeW, badgeH);
            [self bringSubviewToFront:_mediaBadgeView];
        } else {
            _mediaBadgeView.hidden = YES;
        }
    } else {
        _mediaBadgeView.hidden = YES;
    }
}

#pragma mark - Drawing

- (BOOL)isNeoStyle {
    NSString *style = [[NSUserDefaults standardUserDefaults] stringForKey:@"neo_bubble_style"];
    return (style == nil || [style hasPrefix:@"neo"]);
}

- (NSString *)outgoingName {
    NSString *style = [[NSUserDefaults standardUserDefaults] stringForKey:@"neo_bubble_style"];
    if ([style isEqualToString:@"whatsapp"])   return @"bubble-square-outgoing";
    if (style == nil || [style isEqualToString:@"neo-telegram-classic"]) return @"bubbleMine";
    if ([style isEqualToString:@"neo"])        return @"neo-bubble-mine-green";
    if ([style isEqualToString:@"neo-cyan"])   return @"neo-bubble-mine-cyan";
    if ([style isEqualToString:@"neo-purple"]) return @"neo-bubble-mine-purple";
    if ([style isEqualToString:@"neo-pink"])   return @"neo-bubble-mine-pink";
    if ([style isEqualToString:@"neo-orange"]) return @"neo-bubble-mine-orange";
    if ([style isEqualToString:@"neo-red"])    return @"neo-bubble-mine-red";
    if ([style isEqualToString:@"neo-teal"])   return @"neo-bubble-mine-teal";
    if ([style isEqualToString:@"neo-indigo"]) return @"neo-bubble-mine-indigo";
    if ([style isEqualToString:@"neo-telegram"]) return @"neo-bubble-mine-telegram";
    return @"bubbleMine";
}

- (NSString *)incomingName {
    NSString *style = [[NSUserDefaults standardUserDefaults] stringForKey:@"neo_bubble_style"];
    if ([style isEqualToString:@"whatsapp"])   return @"bubble-square-incoming";
    if (style == nil || [style isEqualToString:@"neo-telegram-classic"]) return @"bubbleSomeone";
    if ([style isEqualToString:@"neo"])        return @"neo-bubble-someone-green";
    if ([style isEqualToString:@"neo-cyan"])   return @"neo-bubble-someone-cyan";
    if ([style isEqualToString:@"neo-purple"]) return @"neo-bubble-someone-purple";
    if ([style isEqualToString:@"neo-pink"])   return @"neo-bubble-someone-pink";
    if ([style isEqualToString:@"neo-orange"]) return @"neo-bubble-someone-orange";
    if ([style isEqualToString:@"neo-red"])    return @"neo-bubble-someone-red";
    if ([style isEqualToString:@"neo-teal"])   return @"neo-bubble-someone-teal";
    if ([style isEqualToString:@"neo-indigo"]) return @"neo-bubble-someone-indigo";
    if ([style isEqualToString:@"neo-telegram"]) return @"neo-bubble-someone-telegram";
    return @"bubbleSomeone";
}

- (NSString *)bubbleImageName {
    return self.type == MatrixBubbleMessageTypeOutgoing ? [self outgoingName] : [self incomingName];
}

- (UIImage *)bubbleImage {
    UIImage *img = [UIImage imageNamed:[self bubbleImageName]];
    BOOL isOutgoing = (self.type == MatrixBubbleMessageTypeOutgoing);
    NSInteger leftCap = isOutgoing ? 18 : 25;
    NSInteger topCap = 15;
    return [img stretchableImageWithLeftCapWidth:leftCap topCapHeight:topCap];
}

- (UIColor *)metadataColor {
    NSString *style = [[NSUserDefaults standardUserDefaults] stringForKey:@"neo_bubble_style"];
    if ([style isEqualToString:@"whatsapp"]) {
        return [UIColor colorWithRed:0.45f green:0.45f blue:0.45f alpha:0.85f];
    }
    if (self.type == MatrixBubbleMessageTypeOutgoing) {
        // Onegram chatOutgoingDateColor: UIColorRGBA(0x008c09, 0.8f)
        return [UIColor colorWithRed:0.0f green:0.55f blue:0.04f alpha:0.85f];
    } else {
        // Onegram chatIncomingDateColor: UIColorRGBA(0x525252, 0.6f)
        return [UIColor colorWithRed:0.32f green:0.32f blue:0.32f alpha:0.65f];
    }
}

- (CGRect)bubbleFrame {
    BOOL hasReply = ([self.replySenderName length] > 0 && [self.replyBody length] > 0);
    CGSize mediaSize = (self.hasMedia && self.mediaView) ? self.mediaView.frame.size : CGSizeZero;
    BOOL visualMedia = [self effectiveIsVisualMedia];
    NeoBubbleLayout layout = [MatrixBubbleView layoutForText:self.text
                                                        type:self.type
                                                    showUser:self.showUser
                                               userTitleText:self.userName
                                               showTimestamp:self.showTimestamp
                                                   timestamp:self.timestamp
                                                         ack:self.ack
                                                    hasReply:hasReply
                                             replySenderName:self.replySenderName
                                                   replyBody:self.replyBody
                                                    hasMedia:self.hasMedia
                                                   mediaSize:mediaSize
                                               isVisualMedia:visualMedia
                                                  isRedacted:self.isRedacted];
    CGFloat bw = layout.bubbleSize.width;
    CGFloat bh = layout.bubbleSize.height;
    BOOL isPad = ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad);
    CGFloat sideMargin = isPad ? 17.0f : 4.0f;
    CGFloat bx = (self.type == MatrixBubbleMessageTypeOutgoing)
        ? (self.frame.size.width - bw - sideMargin)
        : sideMargin;
    return CGRectMake(bx, kMarginTop, bw, bh);
}

- (void)drawRect:(CGRect)frame {
    [super drawRect:frame];

    if (self.isEmojiOnly && !self.isRedacted) {
        NSString *emojiText = self.text ?: @"";
        CGFloat w = self.bounds.size.width;
        UIFont *bigFont = [UIFont systemFontOfSize:kLargeEmojiFontSize];
        CGSize ts = [self.text sizeWithFont:bigFont];

        CGFloat x = (self.type == MatrixBubbleMessageTypeOutgoing) ? w - ts.width - 12.0f : 12.0f;
        CGFloat y = (self.bounds.size.height - ts.height) / 2.0f;
        [emojiText drawInRect:CGRectMake(x, y, ts.width, ts.height) withFont:bigFont];

        if (self.showTimestamp && self.timestamp) {
            NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
            fmt.dateFormat = @"HH:mm";
            NSString *timeStr = [fmt stringFromDate:self.timestamp];
            CGSize tsz = [timeStr sizeWithFont:[UIFont systemFontOfSize:10]];
            [[UIColor grayColor] set];
            CGFloat tx = (self.type == MatrixBubbleMessageTypeOutgoing) ? x - tsz.width - 6.0f : x + ts.width + 6.0f;
            [timeStr drawInRect:CGRectMake(tx, y + ts.height - tsz.height, tsz.width, tsz.height)
                       withFont:[UIFont systemFontOfSize:10]];
        }
        return;
    }

    CGRect bFrame = [self bubbleFrame];
    BOOL hasReply = ([self.replySenderName length] > 0 && [self.replyBody length] > 0);
    CGSize mediaSize = (self.hasMedia && self.mediaView) ? self.mediaView.frame.size : CGSizeZero;
    BOOL visualMedia = [self effectiveIsVisualMedia];
    NSString *displayText = self.isRedacted ? NSLocalizedString(@"Deleted message", nil) : (self.text ?: @"");
    BOOL mediaWithoutCaption = (visualMedia && self.hasMedia && [displayText length] == 0 && !self.showUser && !hasReply);

    if (!mediaWithoutCaption) {
        UIImage *image = [self bubbleImage];
        if (self.isRedacted) {
            [image drawInRect:bFrame blendMode:kCGBlendModeNormal alpha:0.6f];
        } else {
            [image drawInRect:bFrame];
        }
    }

    NeoBubbleLayout layout = [MatrixBubbleView layoutForText:self.text
                                                        type:self.type
                                                    showUser:self.showUser
                                               userTitleText:self.userName
                                               showTimestamp:self.showTimestamp
                                                   timestamp:self.timestamp
                                                         ack:self.ack
                                                    hasReply:hasReply
                                             replySenderName:self.replySenderName
                                                   replyBody:self.replyBody
                                                    hasMedia:self.hasMedia
                                                   mediaSize:mediaSize
                                               isVisualMedia:visualMedia
                                                  isRedacted:self.isRedacted];

    CGFloat bx = bFrame.origin.x;
    CGFloat by = bFrame.origin.y;

    // 1. Draw sender name (if showUser)
    if (self.showUser && [self.userName length] > 0 && !CGRectIsEmpty(layout.userRect)) {
        CGRect userRect = CGRectOffset(layout.userRect, bx, by);
        [[MatrixBubbleView colorForUserId:self.senderId] set];
        [self.userName drawInRect:userRect
                         withFont:[UIFont boldSystemFontOfSize:13]
                    lineBreakMode:NSLineBreakByTruncatingTail
                        alignment:NSTextAlignmentLeft];
    }

    // 2. Draw reply preview block (if hasReply)
    if (hasReply && !CGRectIsEmpty(layout.replyRect)) {
        CGRect replyRect = CGRectOffset(layout.replyRect, bx, by);
        CGFloat replyContentX = replyRect.origin.x + 8.0f;
        CGFloat replyContentW = replyRect.size.width - 10.0f;

        BOOL isOutgoing = (self.type == MatrixBubbleMessageTypeOutgoing);
        UIColor *lineColor = isOutgoing ? [UIColor colorWithRed:0.16 green:0.80 blue:0.06 alpha:1.0] : [UIColor colorWithRed:0.24 green:0.65 blue:1.0 alpha:1.0];
        [lineColor set];
        UIRectFill(CGRectMake(replyRect.origin.x, replyRect.origin.y, 2.5f, replyRect.size.height));

        UIColor *nameColor = isOutgoing ? [UIColor colorWithRed:0.0 green:0.55 blue:0.0 alpha:1.0] : [UIColor colorWithRed:0.04 green:0.48 blue:0.92 alpha:1.0];
        [nameColor set];
        CGFloat nameH = 15.0f;
        [self.replySenderName drawInRect:CGRectMake(replyContentX, replyRect.origin.y + 1.0f, replyContentW, nameH)
                               withFont:[UIFont boldSystemFontOfSize:12]
                          lineBreakMode:NSLineBreakByTruncatingTail
                              alignment:NSTextAlignmentLeft];

        [[UIColor colorWithWhite:0.30 alpha:1.0] set];
        CGFloat bodyY = replyRect.origin.y + 1.0f + nameH;
        CGFloat bodyMaxH = replyRect.size.height - nameH - 2.0f;
        [self.replyBody drawInRect:CGRectMake(replyContentX, bodyY, replyContentW, bodyMaxH)
                          withFont:[UIFont systemFontOfSize:11]
                     lineBreakMode:NSLineBreakByTruncatingTail
                         alignment:NSTextAlignmentLeft];
    }

    // 3. Media view placement & overlay badge
    if (self.hasMedia && self.mediaView && !CGRectIsEmpty(layout.mediaRect)) {
        CGRect mediaRect = CGRectOffset(layout.mediaRect, bx, by);
        self.mediaView.frame = mediaRect;
    }

    if (mediaWithoutCaption && self.showTimestamp) {
        _mediaBadgeView.hidden = NO;
        _mediaBadgeView.timeString = [self formattedTimeString];
        _mediaBadgeView.ack = self.ack;
        _mediaBadgeView.isOutgoing = (self.type == MatrixBubbleMessageTypeOutgoing);
        CGFloat totalInfoW = layout.tsRect.size.width + (self.type == MatrixBubbleMessageTypeOutgoing ? (12.0f + 3.0f) : 0.0f);
        CGFloat badgeW = totalInfoW + 12.0f;
        CGFloat badgeH = 18.0f;
        CGRect mediaRect = CGRectOffset(layout.mediaRect, bx, by);
        _mediaBadgeView.frame = CGRectMake(CGRectGetMaxX(mediaRect) - badgeW - 6.0f,
                                           CGRectGetMaxY(mediaRect) - badgeH - 6.0f,
                                           badgeW, badgeH);
        [self bringSubviewToFront:_mediaBadgeView];
    } else {
        _mediaBadgeView.hidden = YES;
    }

    // 4. Text drawing
    if ([displayText length] > 0 && !CGRectIsEmpty(layout.textRect)) {
        CGRect textFrame = CGRectOffset(layout.textRect, bx, by);
        if (self.isRedacted) {
            [[UIColor grayColor] set];
            [displayText drawInRect:textFrame
                           withFont:[UIFont italicSystemFontOfSize:15]
                      lineBreakMode:NSLineBreakByWordWrapping
                          alignment:NSTextAlignmentLeft];
        } else {
            [self drawTextWithLinks:displayText inRect:textFrame];
        }
    }

    // 5. Timestamp and status drawing (for text or media with caption)
    if (!mediaWithoutCaption && self.showTimestamp && !CGRectIsEmpty(layout.tsRect)) {
        CGRect tsRect = CGRectOffset(layout.tsRect, bx, by);
        CGRect ackRect = CGRectOffset(layout.ackRect, bx, by);
        NSString *timeStr = [self formattedTimeString];
            UIColor *metaColor = [self metadataColor];
            UIFont *tsFont = [UIFont systemFontOfSize:11];
            Class psClass = NSClassFromString(@"NSMutableParagraphStyle");
            if (IS_IOS7_OR_LATER && tsFont && psClass) {
                id ps = [[psClass alloc] init];
                if (ps) [ps setLineBreakMode:NSLineBreakByClipping];
                NSMutableDictionary *attrs = [NSMutableDictionary dictionary];
                [attrs setObject:tsFont forKey:NSFontAttributeName];
                [attrs setObject:metaColor forKey:NSForegroundColorAttributeName];
                if (ps) [attrs setObject:ps forKey:NSParagraphStyleAttributeName];
                [timeStr drawWithRect:tsRect
                              options:NSStringDrawingUsesLineFragmentOrigin
                           attributes:attrs
                              context:nil];
            } else {
                [metaColor set];
                [timeStr drawInRect:tsRect
                           withFont:tsFont
                      lineBreakMode:NSLineBreakByClipping
                          alignment:NSTextAlignmentLeft];
            }

            if (self.type == MatrixBubbleMessageTypeOutgoing) {
                CGFloat ackX = ackRect.origin.x;
                CGFloat ackY = ackRect.origin.y;

                if (self.ack == 3) {
                    UIImage *notSent = [UIImage imageNamed:@"NotSent"];
                    if (notSent) {
                        [notSent drawInRect:CGRectMake(ackX, ackY - 1.0f, 12.0f, 12.0f)];
                    } else {
                        CGContextRef ctx = UIGraphicsGetCurrentContext();
                        CGContextSetFillColorWithColor(ctx, [UIColor colorWithRed:0.86f green:0.22f blue:0.15f alpha:1.0f].CGColor);
                        CGContextFillEllipseInRect(ctx, CGRectMake(ackX, ackY, 12.0f, 12.0f));
                        [[UIColor whiteColor] set];
                        [@"!" drawInRect:CGRectMake(ackX, ackY - 1.0f, 12.0f, 13.0f)
                                withFont:[UIFont boldSystemFontOfSize:10]
                           lineBreakMode:NSLineBreakByClipping
                               alignment:NSTextAlignmentCenter];
                    }
                } else if (self.ack == 0) {
                    CGFloat const kAckSize = 11.0f;
                    CGContextRef ctx = UIGraphicsGetCurrentContext();
                    CGContextSetStrokeColorWithColor(ctx, metaColor.CGColor);
                    CGContextSetLineWidth(ctx, 1.0f);
                    CGContextStrokeEllipseInRect(ctx, CGRectMake(ackX + 0.5f, ackY + 0.5f, kAckSize - 1.0f, kAckSize - 1.0f));
                    CGFloat cx = ackX + kAckSize / 2.0f;
                    CGFloat cy = ackY + kAckSize / 2.0f;
                    CGContextMoveToPoint(ctx, cx, cy);
                    CGContextAddLineToPoint(ctx, cx, ackY + 2.0f);
                    CGContextMoveToPoint(ctx, cx, cy);
                    CGContextAddLineToPoint(ctx, cx + 2.0f, cy + 1.0f);
                    CGContextStrokePath(ctx);
                } else {
                    NSString *checkName = (self.ack == 2) ? @"MessageCheckFull" : @"MessageCheckHalf";
                    UIImage *checkImg = [UIImage imageNamed:checkName];
                    if (checkImg) {
                        [checkImg drawInRect:CGRectMake(ackX, ackY, 12.0f, 10.0f)];
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

    static NSDataDetector *sDetector = nil;
    static NSRegularExpression *sManual = nil;
    static NSRegularExpression *sMentionRegex = nil;
    static dispatch_once_t sInitToken;
    dispatch_once(&sInitToken, ^{
        sDetector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:NULL];
        NSString *pattern = @"(?:https?://|www\\.)[^\\s]+";
        sManual = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:NULL];
        sMentionRegex = [NSRegularExpression regularExpressionWithPattern:@"(?<=^|\\s)@([a-zA-Z0-9_\\-\\.\\+=]+(:[a-zA-Z0-9_\\-\\.]+)?)" options:0 error:NULL];
    });

    if (sDetector) {
        [sDetector enumerateMatchesInString:self.text options:0
                                      range:NSMakeRange(0, [self.text length])
                                 usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
            if (result.resultType == NSTextCheckingTypeLink) {
                [results addObject:result];
            }
        }];
    }

    // Supplement with manual regex for URLs that NSDataDetector misses (varies by iOS version)
    if (sManual) {
        [sManual enumerateMatchesInString:self.text options:0
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
    if (sMentionRegex) {
        NSArray *matches = [sMentionRegex matchesInString:self.text options:0 range:NSMakeRange(0, [self.text length])];
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
    // Onegram/Classic iOS 6 bubbles are light, so bubble text is ALWAYS dark black:
    UIColor *textColor = [UIColor colorWithRed:0.08f green:0.08f blue:0.09f alpha:1.0f];

    if ([_linkResults count] == 0) {
        UIFont *msgFont = [MatrixBubbleView font];
        Class psClass = NSClassFromString(@"NSMutableParagraphStyle");
        if (IS_IOS7_OR_LATER && msgFont && psClass) {
            id ps = [[psClass alloc] init];
            if (ps) [ps setLineBreakMode:NSLineBreakByWordWrapping];
            NSMutableDictionary *attrs = [NSMutableDictionary dictionary];
            [attrs setObject:msgFont forKey:NSFontAttributeName];
            [attrs setObject:textColor forKey:NSForegroundColorAttributeName];
            if (ps) [attrs setObject:ps forKey:NSParagraphStyleAttributeName];
            [displayText drawWithRect:textFrame
                              options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                           attributes:attrs
                              context:nil];
        } else {
            [textColor set];
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
        [textColor set];
        [displayText drawInRect:textFrame
                       withFont:nil
                  lineBreakMode:NSLineBreakByWordWrapping
                      alignment:NSTextAlignmentLeft];
        return;
    }
    if (IS_IOS6_OR_LATER && NSFontAttributeName && NSForegroundColorAttributeName) {
        [attrStr addAttribute:NSFontAttributeName value:font range:fullRange];
        [attrStr addAttribute:NSForegroundColorAttributeName value:textColor range:fullRange];

        for (NSTextCheckingResult *result in _linkResults) {
            if ([result.URL.scheme isEqualToString:@"matrix"]) {
                [attrStr addAttribute:NSForegroundColorAttributeName value:[UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:1.0] range:result.range];
                [attrStr addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:15] range:result.range];
            } else {
                [attrStr addAttribute:NSForegroundColorAttributeName value:[UIColor colorWithRed:0.04 green:0.45 blue:0.88 alpha:1.0] range:result.range];
                if (NSUnderlineStyleAttributeName) {
                    [attrStr addAttribute:NSUnderlineStyleAttributeName value:@(NSUnderlineStyleSingle) range:result.range];
                }
            }
        }
    } else {
        CTFontRef ctFont = CTFontCreateWithName((__bridge CFStringRef)font.fontName, font.pointSize, NULL);
        if (ctFont) {
            [attrStr addAttribute:(id)kCTFontAttributeName value:(__bridge id)ctFont range:fullRange];
            CFRelease(ctFont);
        }
        [attrStr addAttribute:(id)kCTForegroundColorAttributeName value:(__bridge id)[textColor CGColor] range:fullRange];

        for (NSTextCheckingResult *result in _linkResults) {
            if ([result.URL.scheme isEqualToString:@"matrix"]) {
                CGColorRef c = [[UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:1.0] CGColor];
                [attrStr addAttribute:(id)kCTForegroundColorAttributeName value:(__bridge id)c range:result.range];
                CTFontRef boldFont = CTFontCreateWithName((__bridge CFStringRef)[[UIFont boldSystemFontOfSize:15] fontName], 15.0, NULL);
                if (boldFont) {
                    [attrStr addAttribute:(id)kCTFontAttributeName value:(__bridge id)boldFont range:result.range];
                    CFRelease(boldFont);
                }
            } else {
                [attrStr addAttribute:(id)kCTForegroundColorAttributeName value:(__bridge id)[[UIColor colorWithRed:0.04 green:0.45 blue:0.88 alpha:1.0] CGColor] range:result.range];
                int32_t uStyle = kCTUnderlineStyleSingle;
                CFNumberRef uNum = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &uStyle);
                if (uNum) {
                    [attrStr addAttribute:(id)kCTUnderlineStyleAttributeName value:(__bridge id)uNum range:result.range];
                    CFRelease(uNum);
                }
            }
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
    if (!_ctFrame || [_linkResults count] == 0) return;
    CGPoint point = [tap locationInView:self];

    // Convert tap to Core Text coordinate space
    CGPoint ctPoint = CGPointMake(point.x, self.bounds.size.height - point.y);

    NSArray *lines = (__bridge NSArray *)CTFrameGetLines(_ctFrame);
    if (!lines || [lines count] == 0) return;

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
    return [UIFont systemFontOfSize:16];
}

+ (CGFloat)maxBubbleWidth {
    BOOL isPad = ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad);
    if (isPad) {
        return 460.0f;
    }
    CGFloat screenW = [UIScreen mainScreen].applicationFrame.size.width;
    return floorf(screenW * 0.78f);
}

+ (CGSize)neoSizeForString:(NSString *)str
                      font:(UIFont *)font
                  maxWidth:(CGFloat)maxWidth
             lineBreakMode:(NSLineBreakMode)mode {
    if ([str length] == 0) return CGSizeZero;
    Class psClass = NSClassFromString(@"NSMutableParagraphStyle");
    if (IS_IOS7_OR_LATER && font && psClass) {
        id ps = [[psClass alloc] init];
        if (ps) [ps setLineBreakMode:mode];
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

+ (void)calculateTextLayoutForText:(NSString *)txt
                          maxWidth:(CGFloat)maxTextWidth
                          textSize:(CGSize *)outTextSize
                     lastLineWidth:(CGFloat *)outLastLineWidth
                         lineCount:(NSUInteger *)outLineCount {
    if ([txt length] == 0) {
        if (outTextSize) *outTextSize = CGSizeZero;
        if (outLastLineWidth) *outLastLineWidth = 0;
        if (outLineCount) *outLineCount = 0;
        return;
    }

    UIFont *font = [MatrixBubbleView font];
    CGSize singleLineSize;
    if (IS_IOS7_OR_LATER) {
        singleLineSize = [txt sizeWithAttributes:@{NSFontAttributeName: font}];
    } else {
        singleLineSize = [txt sizeWithFont:font];
    }

    if ([txt rangeOfString:@"\n"].location == NSNotFound && singleLineSize.width <= maxTextWidth) {
        if (outTextSize) *outTextSize = CGSizeMake(ceilf(singleLineSize.width), ceilf(singleLineSize.height));
        if (outLastLineWidth) *outLastLineWidth = ceilf(singleLineSize.width);
        if (outLineCount) *outLineCount = 1;
        return;
    }

    NSMutableAttributedString *attrStr = [[NSMutableAttributedString alloc] initWithString:txt];
    NSRange fullRange = NSMakeRange(0, [txt length]);
    if (IS_IOS6_OR_LATER && NSFontAttributeName) {
        [attrStr addAttribute:NSFontAttributeName value:font range:fullRange];
    } else {
        CTFontRef ctFont = CTFontCreateWithName((__bridge CFStringRef)font.fontName, font.pointSize, NULL);
        if (ctFont) {
            [attrStr addAttribute:(id)kCTFontAttributeName value:(__bridge id)ctFont range:fullRange];
            CFRelease(ctFont);
        }
    }

    CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)attrStr);
    CGSize constraint = CGSizeMake(maxTextWidth, CGFLOAT_MAX);
    CGSize suggestedSize = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRangeMake(0, 0), NULL, constraint, NULL);

    CGMutablePathRef path = CGPathCreateMutable();
    CGPathAddRect(path, NULL, CGRectMake(0, 0, maxTextWidth, ceilf(suggestedSize.height) + 10.0f));
    CTFrameRef ctFrame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, NULL);

    CFArrayRef lines = CTFrameGetLines(ctFrame);
    CFIndex count = CFArrayGetCount(lines);
    CGFloat lastW = 0.0f;
    if (count > 0) {
        CTLineRef lastLine = (CTLineRef)CFArrayGetValueAtIndex(lines, count - 1);
        CGFloat ascent, descent, leading;
        lastW = (CGFloat)CTLineGetTypographicBounds(lastLine, &ascent, &descent, &leading);
    }

    CFRelease(ctFrame);
    CFRelease(path);
    CFRelease(framesetter);

    if (outTextSize) *outTextSize = CGSizeMake(ceilf(suggestedSize.width), ceilf(suggestedSize.height));
    if (outLastLineWidth) *outLastLineWidth = ceilf(lastW);
    if (outLineCount) *outLineCount = (NSUInteger)count;
}

+ (NeoBubbleLayout)layoutForText:(NSString *)txt
                            type:(MatrixBubbleMessageType)type
                        showUser:(BOOL)showUserFlag
                   userTitleText:(NSString *)userTitleText
                   showTimestamp:(BOOL)showTimestampFlag
                       timestamp:(NSDate *)timestamp
                             ack:(NSInteger)ack
                        hasReply:(BOOL)hasReplyFlag
                 replySenderName:(NSString *)replySenderName
                       replyBody:(NSString *)replyBody
                        hasMedia:(BOOL)hasMediaFlag
                       mediaSize:(CGSize)mediaSize
                      isRedacted:(BOOL)isRedactedFlag {
    return [self layoutForText:txt
                          type:type
                      showUser:showUserFlag
                 userTitleText:userTitleText
                 showTimestamp:showTimestampFlag
                     timestamp:timestamp
                           ack:ack
                      hasReply:hasReplyFlag
               replySenderName:replySenderName
                     replyBody:replyBody
                      hasMedia:hasMediaFlag
                     mediaSize:mediaSize
                 isVisualMedia:NO
                    isRedacted:isRedactedFlag];
}

+ (NeoBubbleLayout)layoutForText:(NSString *)txt
                            type:(MatrixBubbleMessageType)type
                        showUser:(BOOL)showUserFlag
                   userTitleText:(NSString *)userTitleText
                   showTimestamp:(BOOL)showTimestampFlag
                       timestamp:(NSDate *)timestamp
                             ack:(NSInteger)ack
                        hasReply:(BOOL)hasReplyFlag
                 replySenderName:(NSString *)replySenderName
                       replyBody:(NSString *)replyBody
                        hasMedia:(BOOL)hasMediaFlag
                       mediaSize:(CGSize)mediaSize
                   isVisualMedia:(BOOL)isVisualMediaFlag
                      isRedacted:(BOOL)isRedactedFlag {
    CGFloat maxW = [MatrixBubbleView maxBubbleWidth];
    BOOL isOutgoing = (type == MatrixBubbleMessageTypeOutgoing);
    
    // Insets matching Onegram TGContentBubbleViewModel
    CGFloat leftInset = isOutgoing ? 10.0f : 16.0f;
    CGFloat rightInset = isOutgoing ? 16.0f : 10.0f;
    CGFloat hPadding = leftInset + rightInset; // 26.0f
    CGFloat maxContentW = maxW - hPadding;

    NSString *timeStr = @"";
    if (showTimestampFlag) {
        if (timestamp) {
            static NSDateFormatter *sFmt = nil;
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^{
                sFmt = [[NSDateFormatter alloc] init];
                sFmt.dateFormat = @"HH:mm";
            });
            timeStr = [sFmt stringFromDate:timestamp];
        }
        if ([timeStr length] == 0) timeStr = @"12:00";
    }
    UIFont *tsFont = [UIFont systemFontOfSize:11];
    CGSize tsSize = [self neoSizeForString:timeStr font:tsFont maxWidth:CGFLOAT_MAX lineBreakMode:NSLineBreakByClipping];

    CGFloat const kAckWidth = 12.0f;
    CGFloat const kAckHeight = 10.0f;
    CGFloat const kAckGap = 3.0f;
    CGFloat ackW = isOutgoing ? (kAckWidth + kAckGap) : 0.0f;
    CGFloat totalInfoW = showTimestampFlag ? (tsSize.width + ackW) : 0.0f;

    CGFloat userH = 0.0f;
    CGFloat userW = 0.0f;
    if (showUserFlag) {
        userH = kSenderHeight;
        if ([userTitleText length] > 0) {
            CGSize uSize = [self neoSizeForString:userTitleText
                                             font:[UIFont boldSystemFontOfSize:13]
                                         maxWidth:maxContentW
                                    lineBreakMode:NSLineBreakByTruncatingTail];
            userW = uSize.width;
        }
    }

    CGFloat replyH = 0.0f;
    if (hasReplyFlag && [replySenderName length] > 0 && [replyBody length] > 0) {
        replyH = kReplyPreviewHeight;
    }

    CGFloat mediaW = (hasMediaFlag && mediaSize.width > 0) ? mediaSize.width : 0.0f;
    CGFloat mediaH = (hasMediaFlag && mediaSize.height > 0) ? mediaSize.height : 0.0f;

    NSString *displayText = isRedactedFlag ? NSLocalizedString(@"Deleted message", nil) : (txt ?: @"");
    CGSize textSize = CGSizeZero;
    CGFloat lastLineWidth = 0.0f;
    NSUInteger lineCount = 0;

    // Media without text (edge-to-edge media bubble)
    BOOL mediaWithoutCaption = (isVisualMediaFlag && hasMediaFlag && [displayText length] == 0 && !showUserFlag && !hasReplyFlag);

    if (mediaWithoutCaption) {
        CGFloat bubbleW = mediaW;
        CGFloat bubbleH = mediaH;

        CGRect mediaRect = CGRectMake(0.0f, 0.0f, mediaW, mediaH);

        // Overlay timestamp in bottom right corner of media
        CGFloat tsX = mediaW - totalInfoW - 8.0f;
        CGFloat tsY = mediaH - tsSize.height - 6.0f;
        CGRect tsRect = CGRectMake(tsX, tsY, tsSize.width, tsSize.height);
        CGRect ackRect = CGRectZero;
        if (isOutgoing) {
            ackRect = CGRectMake(tsX + tsSize.width + kAckGap, tsY + (tsSize.height - kAckHeight) / 2.0f, kAckWidth, kAckHeight);
        }

        NeoBubbleLayout layout;
        layout.bubbleSize = CGSizeMake(ceilf(bubbleW), ceilf(bubbleH));
        layout.textRect = CGRectZero;
        layout.tsRect = tsRect;
        layout.ackRect = ackRect;
        layout.userRect = CGRectZero;
        layout.replyRect = CGRectZero;
        layout.mediaRect = mediaRect;
        layout.isInline = YES;
        return layout;
    }

    // Media WITH caption (or text only):
    // Ensure media inside the bubble never exceeds maxContentW
    if (mediaW > maxContentW) {
        CGFloat scale = maxContentW / mediaW;
        mediaW = maxContentW;
        mediaH = floorf(mediaH * scale);
    }

    CGFloat textConstraintW = maxContentW;
    if (mediaW > 0) {
        textConstraintW = mediaW;
    }

    if ([displayText length] > 0) {
        [self calculateTextLayoutForText:displayText
                                maxWidth:textConstraintW
                                textSize:&textSize
                           lastLineWidth:&lastLineWidth
                               lineCount:&lineCount];
    }

    // Text or media WITH caption
    BOOL isInline = NO;
    if ([displayText length] > 0) {
        isInline = showTimestampFlag && ((lastLineWidth + 8.0f + totalInfoW) <= maxContentW);
    } else {
        isInline = YES;
    }
    if (!showTimestampFlag) {
        isInline = YES;
    }

    CGFloat contentW = MAX(userW, mediaW);
    if (isInline) {
        contentW = MAX(contentW, textSize.width);
        contentW = MAX(contentW, lastLineWidth + 8.0f + totalInfoW);
    } else {
        contentW = MAX(contentW, textSize.width);
        contentW = MAX(contentW, totalInfoW);
    }
    if (hasReplyFlag) {
        contentW = MAX(contentW, 160.0f);
    }
    contentW = MIN(contentW, maxContentW);

    CGFloat bubbleW = contentW + hPadding;
    bubbleW = MAX(bubbleW, 64.0f);

    CGFloat currentY = kPaddingTop;
    CGRect userRect = CGRectZero;
    if (showUserFlag) {
        userRect = CGRectMake(leftInset, currentY, contentW, userH);
        currentY += userH + 2.0f;
    }

    CGRect replyRect = CGRectZero;
    if (replyH > 0) {
        replyRect = CGRectMake(leftInset, currentY, contentW, replyH);
        currentY += replyH + 4.0f;
    }

    CGRect mediaRect = CGRectZero;
    if (mediaH > 0) {
        mediaRect = CGRectMake(leftInset, currentY, mediaW, mediaH);
        currentY += mediaH + 4.0f;
    }

    CGRect textRect = CGRectZero;
    if ([displayText length] > 0) {
        textRect = CGRectMake(leftInset, currentY, textSize.width, textSize.height);
        currentY += textSize.height;
    }

    CGFloat bubbleH = 0.0f;
    CGRect tsRect = CGRectZero;
    CGRect ackRect = CGRectZero;

    BOOL isSingleLineOnly = (lineCount <= 1 && !showUserFlag && !hasReplyFlag && mediaH == 0);

    if (isSingleLineOnly && [displayText length] > 0 && isInline) {
        // Uniform Onegram single-line bubble: exactly 38pt standard height!
        bubbleH = kStandardMinBubbleHeight;

        // Perfectly vertically centered text
        textRect.origin.y = floorf((kStandardMinBubbleHeight - textSize.height) / 2.0f);

        if (showTimestampFlag) {
            CGFloat tsX = bubbleW - rightInset - totalInfoW;
            CGFloat tsY = floorf((kStandardMinBubbleHeight - tsSize.height) / 2.0f) + 1.0f;
            tsRect = CGRectMake(tsX, tsY, tsSize.width, tsSize.height);
            if (isOutgoing) {
                CGFloat ackX = tsX + tsSize.width + kAckGap;
                CGFloat ackY = floorf((kStandardMinBubbleHeight - kAckHeight) / 2.0f) + 1.0f;
                ackRect = CGRectMake(ackX, ackY, kAckWidth, kAckHeight);
            }
        }
    } else {
        if (showTimestampFlag) {
            if (isInline) {
                bubbleH = currentY + kPaddingBottomInline;
                CGFloat tsX = bubbleW - rightInset - totalInfoW;
                CGFloat tsY = currentY - tsSize.height;
                tsRect = CGRectMake(tsX, tsY, tsSize.width, tsSize.height);
                if (isOutgoing) {
                    CGFloat ackX = tsX + tsSize.width + kAckGap;
                    CGFloat ackY = tsY + (tsSize.height - kAckHeight) / 2.0f;
                    ackRect = CGRectMake(ackX, ackY, kAckWidth, kAckHeight);
                }
            } else {
                bubbleH = currentY + kPaddingBottomBreak;
                CGFloat tsX = bubbleW - rightInset - totalInfoW;
                CGFloat tsY = bubbleH - kTimestampHeight - 4.0f;
                tsRect = CGRectMake(tsX, tsY, tsSize.width, tsSize.height);
                if (isOutgoing) {
                    CGFloat ackX = tsX + tsSize.width + kAckGap;
                    CGFloat ackY = tsY + (tsSize.height - kAckHeight) / 2.0f;
                    ackRect = CGRectMake(ackX, ackY, kAckWidth, kAckHeight);
                }
            }
        } else {
            bubbleH = currentY + kPaddingBottomInline;
        }
        bubbleH = MAX(bubbleH, kStandardMinBubbleHeight);
        if (showUserFlag) {
            bubbleH = MAX(bubbleH, kStandardMinBubbleHeight + userH + 2.0f);
        }
    }

    NeoBubbleLayout layout;
    layout.bubbleSize = CGSizeMake(ceilf(bubbleW), ceilf(bubbleH));
    layout.textRect = textRect;
    layout.tsRect = tsRect;
    layout.ackRect = ackRect;
    layout.userRect = userRect;
    layout.replyRect = replyRect;
    layout.mediaRect = mediaRect;
    layout.isInline = isInline;
    return layout;
}

+ (CGSize)textSizeForText:(NSString *)txt {
    CGFloat maxW = [MatrixBubbleView maxBubbleWidth];
    CGFloat hPadding = 30.0f;
    if ([txt length] == 0) return CGSizeZero;
    CGSize size;
    CGFloat lastW = 0.0f;
    NSUInteger count = 0;
    [self calculateTextLayoutForText:txt
                            maxWidth:maxW - hPadding
                            textSize:&size
                       lastLineWidth:&lastW
                           lineCount:&count];
    return size;
}

+ (CGSize)largeEmojiSizeForText:(NSString *)txt {
    CGSize size = [txt sizeWithFont:[UIFont systemFontOfSize:kLargeEmojiFontSize]];
    return size;
}

+ (CGSize)bubbleSizeForText:(NSString *)txt {
    NeoBubbleLayout layout = [self layoutForText:txt
                                            type:MatrixBubbleMessageTypeIncoming
                                        showUser:NO
                                   userTitleText:nil
                                   showTimestamp:YES
                                       timestamp:nil
                                             ack:1
                                        hasReply:NO
                                 replySenderName:nil
                                       replyBody:nil
                                        hasMedia:NO
                                       mediaSize:CGSizeZero
                                      isRedacted:NO];
    return layout.bubbleSize;
}

+ (CGFloat)cellHeightForText:(NSString *)txt
                  isOutgoing:(BOOL)isOutgoing
                    showUser:(BOOL)showUserFlag
               showTimestamp:(BOOL)showTimestampFlag
                  isRedacted:(BOOL)isRedactedFlag {
    NeoBubbleLayout layout = [self layoutForText:txt
                                            type:isOutgoing ? MatrixBubbleMessageTypeOutgoing : MatrixBubbleMessageTypeIncoming
                                        showUser:showUserFlag
                                   userTitleText:showUserFlag ? @"Sender" : nil
                                   showTimestamp:showTimestampFlag
                                       timestamp:nil
                                             ack:1
                                        hasReply:NO
                                 replySenderName:nil
                                       replyBody:nil
                                        hasMedia:NO
                                       mediaSize:CGSizeZero
                                      isRedacted:isRedactedFlag];
    return kMarginTop + layout.bubbleSize.height + kMarginBottom;
}

+ (CGFloat)cellHeightForText:(NSString *)txt
                     showUser:(BOOL)showUserFlag
                showTimestamp:(BOOL)showTimestampFlag
                   isRedacted:(BOOL)isRedactedFlag {
    return [self cellHeightForText:txt
                        isOutgoing:YES
                          showUser:showUserFlag
                     showTimestamp:showTimestampFlag
                        isRedacted:isRedactedFlag];
}

+ (CGFloat)cellHeightForEmojiOnly:(NSString *)txt {
    if ([txt length] == 0) return 0;
    CGSize ts = [MatrixBubbleView largeEmojiSizeForText:txt];
    return MAX(ts.height + 20, 60);
}

+ (CGFloat)textXOffsetForType:(MatrixBubbleMessageType)type {
    return (type == MatrixBubbleMessageTypeOutgoing) ? 12.0f : 18.0f;
}

+ (CGFloat)cellHeightForMediaWithText:(NSString *)txt
                           isOutgoing:(BOOL)isOutgoing
                             showUser:(BOOL)showUserFlag
                        showTimestamp:(BOOL)showTimestampFlag
                           isRedacted:(BOOL)isRedactedFlag
                            mediaSize:(CGSize)mediaSize
                        isVisualMedia:(BOOL)isVisualMedia {
    NSString *displayText = isRedactedFlag ? NSLocalizedString(@"Deleted message", nil) : txt;
    NeoBubbleLayout layout = [self layoutForText:displayText
                                            type:isOutgoing ? MatrixBubbleMessageTypeOutgoing : MatrixBubbleMessageTypeIncoming
                                        showUser:showUserFlag
                                   userTitleText:showUserFlag ? @"Sender" : nil
                                   showTimestamp:showTimestampFlag
                                       timestamp:nil
                                             ack:1
                                        hasReply:NO
                                 replySenderName:nil
                                       replyBody:nil
                                        hasMedia:YES
                                       mediaSize:mediaSize
                                   isVisualMedia:isVisualMedia
                                      isRedacted:isRedactedFlag];
    return kMarginTop + layout.bubbleSize.height + kMarginBottom;
}

+ (CGFloat)cellHeightForMediaWithText:(NSString *)txt
                           isOutgoing:(BOOL)isOutgoing
                             showUser:(BOOL)showUserFlag
                        showTimestamp:(BOOL)showTimestampFlag
                           isRedacted:(BOOL)isRedactedFlag
                            mediaSize:(CGSize)mediaSize {
    return [self cellHeightForMediaWithText:txt
                                 isOutgoing:isOutgoing
                                   showUser:showUserFlag
                              showTimestamp:showTimestampFlag
                                 isRedacted:isRedactedFlag
                                  mediaSize:mediaSize
                              isVisualMedia:NO];
}

+ (CGFloat)cellHeightForMediaWithText:(NSString *)txt
                           isOutgoing:(BOOL)isOutgoing
                             showUser:(BOOL)showUserFlag
                        showTimestamp:(BOOL)showTimestampFlag
                           isRedacted:(BOOL)isRedactedFlag
                          mediaHeight:(CGFloat)mediaHeight {
    return [self cellHeightForMediaWithText:txt
                                 isOutgoing:isOutgoing
                                   showUser:showUserFlag
                              showTimestamp:showTimestampFlag
                                 isRedacted:isRedactedFlag
                                  mediaSize:CGSizeMake(200.0f, mediaHeight)];
}

+ (CGFloat)cellHeightForMediaWithText:(NSString *)txt
                             showUser:(BOOL)showUserFlag
                        showTimestamp:(BOOL)showTimestampFlag
                           isRedacted:(BOOL)isRedactedFlag
                          mediaHeight:(CGFloat)mediaHeight {
    return [self cellHeightForMediaWithText:txt
                                 isOutgoing:YES
                                   showUser:showUserFlag
                              showTimestamp:showTimestampFlag
                                 isRedacted:isRedactedFlag
                                mediaHeight:mediaHeight];
}

+ (CGFloat)replyPreviewHeight {
    return kReplyPreviewHeight + 5;
}

@end
