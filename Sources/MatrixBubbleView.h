#import <UIKit/UIKit.h>

typedef enum {
    MatrixBubbleMessageTypeIncoming,
    MatrixBubbleMessageTypeOutgoing
} MatrixBubbleMessageType;

@interface MatrixBubbleView : UIView

@property (assign, nonatomic) MatrixBubbleMessageType type;
@property (copy, nonatomic) NSString *text;
@property (strong, nonatomic) NSDate *timestamp;
@property (assign, nonatomic) BOOL showTimestamp;
@property (copy, nonatomic) NSString *userName;
@property (assign, nonatomic) BOOL showUser;
@property (assign, nonatomic) BOOL isRedacted;
@property (assign, nonatomic) NSInteger ack;
@property (assign, nonatomic) BOOL hasMedia;
@property (strong, nonatomic) UIView *mediaView;
@property (assign, nonatomic) BOOL selectedToShowCopyMenu;

- (id)initWithFrame:(CGRect)frame
               type:(MatrixBubbleMessageType)type
           showUser:(BOOL)showUser
      showTimestamp:(BOOL)showTimestamp
           hasMedia:(BOOL)hasMedia
          mediaView:(UIView *)mediaView;

- (CGRect)bubbleFrame;

+ (CGFloat)cellHeightForText:(NSString *)txt
                    showUser:(BOOL)showUserFlag
               showTimestamp:(BOOL)showTimestampFlag
                  isRedacted:(BOOL)isRedactedFlag;

+ (CGFloat)cellHeightForMediaWithText:(NSString *)txt
                             showUser:(BOOL)showUserFlag
                        showTimestamp:(BOOL)showTimestampFlag
                           isRedacted:(BOOL)isRedactedFlag
                          mediaHeight:(CGFloat)mediaHeight;

+ (CGFloat)textXOffsetForType:(MatrixBubbleMessageType)type;

+ (UIFont *)font;
+ (CGSize)textSizeForText:(NSString *)txt;
+ (CGSize)bubbleSizeForText:(NSString *)txt;

@end
