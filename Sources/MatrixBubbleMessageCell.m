#import "MatrixBubbleMessageCell.h"

@implementation MatrixBubbleMessageCell

@synthesize bubbleView, dateSeparatorLabel;

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
        if (!self.dateSeparatorLabel) {
            self.dateSeparatorLabel = [[UILabel alloc] initWithFrame:CGRectZero];
            self.dateSeparatorLabel.font = [UIFont systemFontOfSize:12];
            self.dateSeparatorLabel.textColor = [UIColor colorWithWhite:0.45 alpha:1.0];
            self.dateSeparatorLabel.textAlignment = NSTextAlignmentCenter;
            self.dateSeparatorLabel.backgroundColor = [UIColor clearColor];
            [self.contentView addSubview:self.dateSeparatorLabel];
        }
        self.dateSeparatorLabel.text = dateSeparator;
        self.dateSeparatorLabel.frame = CGRectMake(0, 4, self.contentView.frame.size.width, 20);
        self.dateSeparatorLabel.hidden = NO;
    } else if (self.dateSeparatorLabel) {
        self.dateSeparatorLabel.hidden = YES;
    }

    [self.bubbleView removeFromSuperview];
    self.bubbleView = nil;

    CGFloat bubbleY = dateSeparator ? 28 : 0;
    CGRect bubbleFrame = CGRectMake(0, bubbleY,
                                    self.contentView.frame.size.width,
                                    self.contentView.frame.size.height - bubbleY);

    self.bubbleView = [[MatrixBubbleView alloc] initWithFrame:bubbleFrame
                                                         type:type
                                                     showUser:showUser
                                                showTimestamp:showTimestamp
                                                     hasMedia:hasMedia
                                                    mediaView:mediaView];
    [self.contentView addSubview:self.bubbleView];
    [self.contentView sendSubviewToBack:self.bubbleView];
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

@end
