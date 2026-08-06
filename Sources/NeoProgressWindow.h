#import <UIKit/UIKit.h>

@interface NeoProgressWindow : UIWindow

@property (nonatomic, assign) BOOL skipMakeKeyWindowOnDismiss;

- (void)show:(BOOL)animated;
- (void)showWithDelay:(NSTimeInterval)delay;
- (void)showAnimated;
- (void)dismiss:(BOOL)animated;
- (void)dismissWithSuccess;

+ (void)setDarkStyle:(BOOL)dark;

@end
