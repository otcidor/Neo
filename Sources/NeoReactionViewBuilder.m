#import "NeoReactionViewBuilder.h"
#import "NeoReactionPillView.h"
#import "MatrixModels.h"
#import "MatrixBubbleView.h"
#import <objc/runtime.h>

@implementation NeoReactionViewBuilder

+ (void)populatePillContainer:(UIView *)container
                   forMessage:(MatrixMessage *)msg
                  bubbleFrame:(CGRect)bubbleFrame
                       isSelf:(BOOL)isSelf
                       target:(id)target
                       action:(SEL)action {
    for (UIView *v in container.subviews) [v removeFromSuperview];

    if ([msg.reactions count] == 0) return;

    NSArray *sorted = [[msg.reactions allKeys] sortedArrayUsingComparator:^NSComparisonResult(NSString *e1, NSString *e2) {
        return [msg.reactions[e2] compare:msg.reactions[e1]];
    }];
    NSInteger limit = MIN(7, (NSInteger)[sorted count]);

    CGFloat pillX = isSelf ? (CGRectGetMaxX(bubbleFrame) - 4) : (CGRectGetMinX(bubbleFrame) + [MatrixBubbleView textXOffsetForType:MatrixBubbleMessageTypeIncoming]);

    for (NSInteger i = 0; i < limit; i++) {
        NSString *emoji = sorted[i];
        NSNumber *count = msg.reactions[emoji];

        NeoReactionPillView *pill = [[NeoReactionPillView alloc] initWithFrame:CGRectZero];
        pill.emoji = emoji;
        pill.count = [count integerValue];
        pill.pillSelected = [msg.myReactions[emoji] boolValue];
        [pill updateImage];

        if (isSelf) {
            pillX -= pill.frame.size.width + 3;
            pill.frame = CGRectMake(pillX, 0, pill.frame.size.width, pill.frame.size.height);
        } else {
            pill.frame = CGRectMake(pillX, 0, pill.frame.size.width, pill.frame.size.height);
            pillX += pill.frame.size.width + 3;
        }

        [pill addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
        objc_setAssociatedObject(pill, "msg", msg, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(pill, "emojiKey", emoji, OBJC_ASSOCIATION_COPY_NONATOMIC);

        [container addSubview:pill];
    }
}

@end
