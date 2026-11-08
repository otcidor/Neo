#import <UIKit/UIKit.h>

@interface PhotoViewerController : UIViewController <UIScrollViewDelegate, UIGestureRecognizerDelegate>

@property (nonatomic, strong) UIImage *image;

- (id)initWithImage:(UIImage *)image;
- (id)initWithMessages:(NSArray *)messages initialIndex:(NSUInteger)initialIndex;
- (void)updateImage:(UIImage *)image;

@end
