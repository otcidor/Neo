#import <UIKit/UIKit.h>

@interface NeoProgressSpinnerView : UIView

@property (nonatomic, copy) void (^onSuccess)(void);

- (instancetype)initWithFrame:(CGRect)frame light:(BOOL)light;
- (void)setProgress;
- (void)setSucceed;

@end
