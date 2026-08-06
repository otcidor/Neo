#import "NeoModernButton.h"

@interface NeoModernButton ()
{
    BOOL _animateHighlight;
    UIColor *_titleColor;
    UIImageView *_highlightImageView;
    UIView *_highlightBackgroundView;
}
@end

@implementation NeoModernButton

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) _modernHighlight = YES;
    return self;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    if (self.alpha > FLT_EPSILON && !self.hidden)
    {
        CGRect bounds = self.bounds;
        bounds.origin.x -= _extendedEdgeInsets.left;
        bounds.size.width += _extendedEdgeInsets.left + _extendedEdgeInsets.right;
        bounds.origin.y -= _extendedEdgeInsets.top;
        bounds.size.height += _extendedEdgeInsets.top + _extendedEdgeInsets.bottom;
        if (CGRectContainsPoint(bounds, point)) return self;
    }
    return [super hitTest:point withEvent:event];
}

- (void)setModernHighlight:(BOOL)modernHighlight
{
    _modernHighlight = modernHighlight;
    if (!_modernHighlight) self.alpha = 1.0f;
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event { _animateHighlight = YES; [super touchesMoved:touches withEvent:event]; _animateHighlight = NO; }
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event { _animateHighlight = YES; [super touchesCancelled:touches withEvent:event]; _animateHighlight = NO; }
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event { _animateHighlight = YES; [super touchesEnded:touches withEvent:event]; _animateHighlight = NO; }

- (void)setHighlightImage:(UIImage *)highlightImage
{
    _highlightImage = highlightImage;
    if (_highlightImage != nil && _highlightImageView == nil)
    {
        _highlightImageView = [[UIImageView alloc] init];
        _highlightImageView.alpha = 0.0f;
        [self insertSubview:_highlightImageView belowSubview:self.titleLabel];
    }
    _highlightImageView.image = _highlightImage;
    if (_stretchHighlightImage)
        _highlightImageView.frame = self.bounds;
    else
        _highlightImageView.frame = CGRectMake(floorf((self.bounds.size.width - _highlightImage.size.width) / 2.0f), floorf((self.bounds.size.height - _highlightImage.size.height) / 2.0f), _highlightImage.size.width, _highlightImage.size.height);
}

- (void)setHighlightBackgroundColor:(UIColor *)color
{
    _highlightBackgroundColor = color;
    if (_highlightBackgroundColor != nil && _highlightBackgroundView == nil)
    {
        _highlightBackgroundView = [[UIView alloc] init];
        _highlightBackgroundView.alpha = 0.0f;
        [self insertSubview:_highlightBackgroundView atIndex:0];
    }
    _highlightBackgroundView.backgroundColor = _highlightBackgroundColor;
    CGRect frame = self.bounds;
    frame.origin.x -= _backgroundSelectionInsets.left;
    frame.origin.y -= _backgroundSelectionInsets.top;
    frame.size.width += _backgroundSelectionInsets.left + _backgroundSelectionInsets.right;
    frame.size.height += _backgroundSelectionInsets.top + _backgroundSelectionInsets.bottom;
    _highlightBackgroundView.frame = frame;
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    if (_highlightImageView)
    {
        if (_stretchHighlightImage)
            _highlightImageView.frame = self.bounds;
        else
            _highlightImageView.frame = CGRectMake(floorf((frame.size.width - _highlightImage.size.width) / 2.0f), floorf((frame.size.height - _highlightImage.size.height) / 2.0f), _highlightImage.size.width, _highlightImage.size.height);
    }
    if (_highlightBackgroundView)
    {
        CGRect f = self.bounds;
        f.origin.x -= _backgroundSelectionInsets.left;
        f.origin.y -= _backgroundSelectionInsets.top;
        f.size.width += _backgroundSelectionInsets.left + _backgroundSelectionInsets.right;
        f.size.height += _backgroundSelectionInsets.top + _backgroundSelectionInsets.bottom;
        _highlightBackgroundView.frame = f;
    }
}

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    if (!_modernHighlight) return;

    if (_highlightImage)
    {
        CGFloat alpha = highlighted ? 1.0f : 0.0f;
        if (ABS(alpha - _highlightImageView.alpha) > FLT_EPSILON)
            [UIView animateWithDuration:_animateHighlight ? 0.2 : 0.0 animations:^{ _highlightImageView.alpha = alpha; }];
    }
    else if (_highlightBackgroundColor)
    {
        CGFloat alpha = highlighted ? 1.0f : 0.0f;
        if (ABS(alpha - _highlightBackgroundView.alpha) > FLT_EPSILON)
            [UIView animateWithDuration:_animateHighlight ? 0.2 : 0.0 animations:^{ _highlightBackgroundView.alpha = alpha; }];
    }
    else
    {
        CGFloat alpha = (highlighted ? 0.4f : 1.0f) * (_fadeDisabled ? 1.0f : (self.enabled ? 1.0f : 0.5f));
        if (ABS(alpha - self.alpha) > FLT_EPSILON)
            [UIView animateWithDuration:_animateHighlight ? 0.2 : 0.0 animations:^{ self.alpha = alpha; }];
    }
}

- (void)setTitleColor:(UIColor *)color
{
    _titleColor = color;
    [self setTitleColor:color forState:UIControlStateNormal];
    if (_modernHighlight && _highlightImage == nil && _highlightBackgroundColor == nil)
        self.alpha = (self.highlighted ? 0.4f : 1.0f) * (_fadeDisabled ? 1.0f : (self.enabled ? 1.0f : 0.5f));
}

- (void)setEnabled:(BOOL)enabled
{
    [super setEnabled:enabled];
    if (_modernHighlight && _highlightImage == nil)
        self.alpha = (self.highlighted ? 0.4f : 1.0f) * (_fadeDisabled ? 1.0f : (self.enabled ? 1.0f : 0.5f));
}

- (void)setFadeDisabled:(BOOL)fadeDisabled
{
    _fadeDisabled = fadeDisabled;
    if (_modernHighlight && _highlightImage == nil)
        self.alpha = (self.highlighted ? 0.4f : 1.0f) * (_fadeDisabled ? 1.0f : (self.enabled ? 1.0f : 0.5f));
}

@end
