#import <UIKit/UIKit.h>

@interface ReplyBubbleView : UIView
@property (copy, nonatomic) NSString *senderName;
@property (copy, nonatomic) NSString *body;
@property (assign, nonatomic) BOOL outgoing;
+ (CGFloat)viewHeight;
@end
