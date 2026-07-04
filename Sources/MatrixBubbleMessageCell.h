#import <UIKit/UIKit.h>
#import "MatrixBubbleView.h"

@interface MatrixBubbleMessageCell : UITableViewCell

@property (retain, nonatomic) MatrixBubbleView *bubbleView;
@property (retain, nonatomic) UILabel *dateSeparatorLabel;

- (void)configureWithType:(MatrixBubbleMessageType)type
                   msgId:(NSString *)msgId
               showUser:(BOOL)showUser
          showTimestamp:(BOOL)showTimestamp
               hasMedia:(BOOL)hasMedia
              mediaView:(UIView *)mediaView
        dateSeparator:(NSString *)dateSeparator;

- (void)setMessage:(NSString *)msg;
- (void)setTimestamp:(NSDate *)date;
- (void)setIsRedacted:(BOOL)flag;
- (void)setAck:(NSInteger)ackValue;
- (void)setUserWrited:(NSString *)user;
- (void)setBubbleSelected:(BOOL)selected;

@end
