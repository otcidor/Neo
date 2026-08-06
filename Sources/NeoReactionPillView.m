#import "NeoReactionPillView.h"
#import "NeoReactionParser.h"

@implementation NeoReactionPillView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        self.adjustsImageWhenHighlighted = NO;
        self.layer.cornerRadius = 11.0f;
        self.clipsToBounds = YES;
    }
    return self;
}

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    [UIView animateWithDuration:0.15 animations:^{
        self.alpha = highlighted ? 0.6f : 1.0f;
    }];
}

- (void)updateImage
{
    UIImage *image = NeoReactionPillImage(_emoji, _count, _pillSelected);
    [self setImage:image forState:UIControlStateNormal];
    if (image)
    {
        CGRect frame = self.frame;
        frame.size = image.size;
        self.frame = frame;
    }
}

@end
