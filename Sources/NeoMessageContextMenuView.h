#import <UIKit/UIKit.h>
#import "MatrixModels.h"

@interface NeoMessageContextMenuView : UIView

+ (void)showForMessage:(MatrixMessage *)msg
                inView:(UIView *)parentView
          bubbleCenter:(CGPoint)bubbleCenter
                isSelf:(BOOL)isSelf
    onReactionSelected:(void(^)(NSString *emoji))onReaction
      onCustomReaction:(void(^)(void))onCustomReaction
               onReply:(void(^)(void))onReply
                onCopy:(void(^)(void))onCopy
             onForward:(void(^)(void))onForward
           onSaveMedia:(void(^)(void))onSaveMedia
              onOpenIn:(void(^)(void))onOpenIn
            onDownload:(void(^)(void))onDownload
                onEdit:(void(^)(void))onEdit
              onDelete:(void(^)(void))onDelete;

- (void)dismissAnimated:(BOOL)animated;

@end
