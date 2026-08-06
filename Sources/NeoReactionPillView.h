#import <UIKit/UIKit.h>

@interface NeoReactionPillView : UIButton

@property (nonatomic, copy) NSString *emoji;
@property (nonatomic, assign) NSInteger count;
@property (nonatomic, assign) BOOL pillSelected;

- (void)updateImage;

@end
