#import <UIKit/UIKit.h>

@interface NeoTypingBubbleView : UIView

+ (CGSize)bubbleSize;

- (void)startAnimating;
- (void)stopAnimating;
- (void)applyTheme;

@end
