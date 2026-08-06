#import <UIKit/UIKit.h>

@interface NeoModernButton : UIButton

@property (nonatomic, assign) BOOL modernHighlight;
@property (nonatomic, strong) UIImage *highlightImage;
@property (nonatomic, assign) BOOL stretchHighlightImage;
@property (nonatomic, strong) UIColor *highlightBackgroundColor;
@property (nonatomic, assign) UIEdgeInsets backgroundSelectionInsets;
@property (nonatomic, assign) UIEdgeInsets extendedEdgeInsets;
@property (nonatomic, assign) BOOL fadeDisabled;

- (void)setTitleColor:(UIColor *)color;

@end
