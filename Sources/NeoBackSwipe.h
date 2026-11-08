#import <UIKit/UIKit.h>

@protocol NeoBackSwipeBlocking <NSObject>
- (BOOL)blocksBackSwipe;
@end

@interface NeoBackSwipe : NSObject <UIGestureRecognizerDelegate>

@property (nonatomic, weak, readonly) UINavigationController *navigationController;
@property (nonatomic, strong, readonly) UIPanGestureRecognizer *panGestureRecognizer;
@property (nonatomic, assign, getter=isEnabled) BOOL enabled;

- (id)initWithNavigationController:(UINavigationController *)navigation;

@end

@interface UINavigationController (NeoBackSwipe)

- (void)neo_enableBackSwipe;
- (NeoBackSwipe *)neo_backSwipe;

@end
