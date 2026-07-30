#import <UIKit/UIKit.h>

@interface PhotoViewerController : UIViewController <UIScrollViewDelegate>

@property (nonatomic, retain) UIImage *image;

- (id)initWithImage:(UIImage *)image;
- (void)updateImage:(UIImage *)image;

@end
