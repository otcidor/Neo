#import <UIKit/UIKit.h>

@class MatrixMessage;

@interface NeoReactionViewBuilder : NSObject

+ (void)populatePillContainer:(UIView *)container
                   forMessage:(MatrixMessage *)msg
                  bubbleFrame:(CGRect)bubbleFrame
                       isSelf:(BOOL)isSelf
                       target:(id)target
                       action:(SEL)action;

@end
