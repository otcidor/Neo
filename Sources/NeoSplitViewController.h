#import <UIKit/UIKit.h>
#import "NeoCompatibility.h"

@class ChatViewController;

@interface NeoSplitViewController : UIViewController

+ (BOOL)isPad;
+ (instancetype)sharedSplitViewController;

@property (nonatomic, strong) UIViewController *masterViewController;
@property (nonatomic, strong, readonly) UINavigationController *detailNavigationController;

- (void)showChatViewController:(ChatViewController *)chatVC;
- (void)clearDetail;
- (ChatViewController *)currentChatViewController;

@end
