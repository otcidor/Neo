#import "MatrixBubbleMessageCell.h"

@implementation MatrixBubbleMessageCell

@synthesize bubbleView, dateSeparatorLabel, dateSeparatorBgView;

- (void)setup {
    self.backgroundColor = [UIColor clearColor];
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.accessoryType = UITableViewCellAccessoryNone;
    self.accessoryView = nil;
    self.imageView.image = nil;
    self.imageView.hidden = YES;
    self.textLabel.text = nil;
    self.textLabel.hidden = YES;
    self.detailTextLabel.text = nil;
    self.detailTextLabel.hidden = YES;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self setup];
    }
    return self;
}

- (void)configureWithType:(MatrixBubbleMessageType)type
                   msgId:(NSString *)msgId
               showUser:(BOOL)showUser
          showTimestamp:(BOOL)showTimestamp
               hasMedia:(BOOL)hasMedia
              mediaView:(UIView *)mediaView
        dateSeparator:(NSString *)dateSeparator {

    if (dateSeparator) {
        if (!self.dateSeparatorBgView) {
            self.dateSeparatorBgView = [[UIImageView alloc] initWithFrame:CGRectZero];
            UIImage *rawImg = [UIImage imageNamed:@"SystemMessageBackground"];
            if (rawImg) {
                self.dateSeparatorBgView.image = [rawImg stretchableImageWithLeftCapWidth:(int)(rawImg.size.width / 2) topCapHeight:(int)(rawImg.size.height / 2)];
            }
            [self.contentView addSubview:self.dateSeparatorBgView];
        }
        if (!self.dateSeparatorLabel) {
            self.dateSeparatorLabel = [[UILabel alloc] initWithFrame:CGRectZero];
            self.dateSeparatorLabel.font = [UIFont boldSystemFontOfSize:12];
            self.dateSeparatorLabel.textColor = [UIColor whiteColor];
            self.dateSeparatorLabel.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.45f];
            self.dateSeparatorLabel.shadowOffset = CGSizeMake(0, -1);
            self.dateSeparatorLabel.textAlignment = NSTextAlignmentCenter;
            self.dateSeparatorLabel.backgroundColor = [UIColor clearColor];
            [self.contentView addSubview:self.dateSeparatorLabel];
        }
        self.dateSeparatorLabel.text = dateSeparator;
        self.dateSeparatorBgView.hidden = NO;
        self.dateSeparatorLabel.hidden = NO;
    } else {
        if (self.dateSeparatorBgView) self.dateSeparatorBgView.hidden = YES;
        if (self.dateSeparatorLabel) self.dateSeparatorLabel.hidden = YES;
    }

    CGFloat y = dateSeparator ? 28 : 0;
    CGRect bubbleFrame = CGRectMake(0, y,
                                    self.contentView.frame.size.width,
                                    self.contentView.frame.size.height - y);

    if (!self.bubbleView) {
        self.bubbleView = [[MatrixBubbleView alloc] initWithFrame:bubbleFrame
                                                             type:type
                                                         showUser:showUser
                                                    showTimestamp:showTimestamp
                                                         hasMedia:hasMedia
                                                        mediaView:mediaView];
        [self.contentView addSubview:self.bubbleView];
        [self.contentView sendSubviewToBack:self.bubbleView];
    } else {
        self.bubbleView.frame = bubbleFrame;
        self.bubbleView.type = type;
        self.bubbleView.showUser = showUser;
        self.bubbleView.showTimestamp = showTimestamp;
        self.bubbleView.hasMedia = hasMedia;
        self.bubbleView.mediaView = mediaView;
        [self.bubbleView setNeedsDisplay];
    }
}

- (void)setMessage:(NSString *)msg {
    self.bubbleView.text = msg;
}

- (void)setTimestamp:(NSDate *)date {
    self.bubbleView.timestamp = date;
}

- (void)setIsRedacted:(BOOL)flag {
    self.bubbleView.isRedacted = flag;
}

- (void)setAck:(NSInteger)ackValue {
    self.bubbleView.ack = ackValue;
}

- (void)setUserWrited:(NSString *)user {
    self.bubbleView.userName = user;
}

- (void)setBubbleSelected:(BOOL)selected {
    self.bubbleView.selectedToShowCopyMenu = selected;
}

- (void)setReplySender:(NSString *)sender replyBody:(NSString *)body {
    self.bubbleView.replySenderName = sender;
    self.bubbleView.replyBody = body;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (!self.bubbleView) return;
    CGFloat y = (self.dateSeparatorLabel && !self.dateSeparatorLabel.hidden) ? 28 : 0;
    CGRect bf = CGRectMake(0, y,
                           self.contentView.bounds.size.width,
                           self.contentView.bounds.size.height - y);
    if (!CGRectEqualToRect(self.bubbleView.frame, bf)) {
        self.bubbleView.frame = bf;
        [self.bubbleView setNeedsDisplay];
    }
    if (self.dateSeparatorLabel && !self.dateSeparatorLabel.hidden) {
        CGSize sz = [self.dateSeparatorLabel.text sizeWithFont:self.dateSeparatorLabel.font];
        CGFloat bw = ceilf(sz.width) + 18.0f;
        CGFloat bh = 20.0f;
        CGFloat bx = floorf((self.contentView.bounds.size.width - bw) / 2.0f);
        CGFloat by = 4.0f;
        if (self.dateSeparatorBgView) {
            self.dateSeparatorBgView.frame = CGRectMake(bx, by, bw, bh);
        }
        self.dateSeparatorLabel.frame = CGRectMake(bx, by, bw, bh);
    }
}

- (void)prepareForReuse {
    [super prepareForReuse];
    if (self.bubbleView && [self.bubbleView.mediaView respondsToSelector:@selector(stop)]) {
        [(id)self.bubbleView.mediaView stop];
    }
    self.bubbleView.replySenderName = nil;
    self.bubbleView.replyBody = nil;
    self.bubbleView.mediaView = nil;
}

@end
