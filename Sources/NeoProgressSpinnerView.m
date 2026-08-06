#import "NeoProgressSpinnerView.h"
#import <QuartzCore/QuartzCore.h>

@interface NeoProgressSpinnerViewInternal : UIView
@property (nonatomic, copy) void (^onDraw)(void);
@property (nonatomic, copy) void (^onSuccess)(void);
- (instancetype)initWithFrame:(CGRect)frame light:(BOOL)light;
- (void)setProgress;
- (void)setSucceed:(BOOL)fromRotation progress:(CGFloat)progress;
@end

@interface NeoProgressSpinnerView ()
{
    UIImageView *_arcView;
    NeoProgressSpinnerViewInternal *_internalView;
    BOOL _progressing;
}
@end

@implementation NeoProgressSpinnerView

- (instancetype)initWithFrame:(CGRect)frame light:(BOOL)light
{
    self = [super initWithFrame:frame];
    if (self)
    {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO;

        CGRect rect = CGRectMake(0.0f, 0.0f, 48.0f, 48.0f);
        UIGraphicsBeginImageContextWithOptions(rect.size, NO, 0.0f);
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGPoint centerPoint = CGPointMake(rect.size.width / 2.0f, rect.size.height / 2.0f);
        CGFloat lineWidth = 4.0f;
        CGFloat inset = 3.0f;
        UIColor *fg = light ? [UIColor colorWithRed:0x5a/255.0f green:0x5a/255.0f blue:0x5a/255.0f alpha:1.0f] : [UIColor whiteColor];
        CGContextSetFillColorWithColor(context, fg.CGColor);
        CGContextSetStrokeColorWithColor(context, fg.CGColor);
        CGMutablePathRef arcPath = CGPathCreateMutable();
        CGPathAddArc(arcPath, NULL, centerPoint.x, centerPoint.y, (48.0f - inset * 2.0f - lineWidth) / 2.0f, -2.0f * M_PI, -2.0f * M_PI + 3.0f * M_PI_2, NO);
        CGPathRef strokedArc = CGPathCreateCopyByStrokingPath(arcPath, NULL, lineWidth, kCGLineCapRound, kCGLineJoinMiter, 10);
        CGContextAddPath(context, strokedArc);
        CGPathRelease(strokedArc);
        CGPathRelease(arcPath);
        CGContextFillPath(context);
        UIImage *arcImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();

        _arcView = [[UIImageView alloc] initWithFrame:self.bounds];
        _arcView.image = arcImage;
        _arcView.hidden = YES;
        [self addSubview:_arcView];

        _internalView = [[NeoProgressSpinnerViewInternal alloc] initWithFrame:self.bounds light:light];
        _internalView.hidden = YES;
        [self addSubview:_internalView];
    }
    return self;
}

- (void)setProgress
{
    _arcView.hidden = NO;
    _progressing = YES;
    CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
    anim.toValue = @(-M_PI * 2.0f);
    anim.duration = 0.75;
    anim.cumulative = YES;
    anim.repeatCount = HUGE_VALF;
    [_arcView.layer addAnimation:anim forKey:@"rotationAnimation"];
}

- (void)setSucceed
{
    _internalView.hidden = NO;
    if (_progressing)
    {
        CGFloat value = [[_arcView.layer.presentationLayer valueForKeyPath:@"transform.rotation.z"] doubleValue] / (-2.0 * M_PI);
        [_internalView setSucceed:YES progress:value];
        __weak typeof(self) weakSelf = self;
        _internalView.onDraw = ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf) strongSelf->_arcView.hidden = YES;
        };
        _internalView.onSuccess = ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf && strongSelf.onSuccess) strongSelf.onSuccess();
        };
    }
    else
    {
        [_internalView setSucceed:NO progress:0.0f];
    }
}

@end

@interface NeoProgressSpinnerViewInternal ()
{
    CADisplayLink *_displayLink;
    BOOL _light;
    BOOL _isProgressing;
    CGFloat _rotationValue;
    BOOL _isRotating;
    CGFloat _checkValue;
    BOOL _delay;
    BOOL _isSucceed;
    BOOL _isChecking;
    NSTimeInterval _previousTime;
}
@end

@implementation NeoProgressSpinnerViewInternal

- (instancetype)initWithFrame:(CGRect)frame light:(BOOL)light
{
    self = [super initWithFrame:frame];
    if (self)
    {
        _light = light;
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO;
    }
    return self;
}

- (void)dealloc
{
    _displayLink.paused = YES;
    [_displayLink removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (CADisplayLink *)displayLink
{
    if (_displayLink == nil)
    {
        _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkUpdate)];
        _displayLink.paused = YES;
        [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }
    return _displayLink;
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGPoint center = CGPointMake(rect.size.width / 2.0f, rect.size.height / 2.0f);
    CGFloat lineWidth = 4.0f;
    CGFloat inset = 3.0f;
    UIColor *fg = _light ? [UIColor colorWithRed:0x5a/255.0f green:0x5a/255.0f blue:0x5a/255.0f alpha:1.0f] : [UIColor whiteColor];
    CGContextSetFillColorWithColor(context, fg.CGColor);
    CGContextSetStrokeColorWithColor(context, fg.CGColor);

    if (_isProgressing)
    {
        CGMutablePathRef path = CGPathCreateMutable();
        CGFloat offset = -_rotationValue * 2.0f * M_PI;
        CGPathAddArc(path, NULL, center.x, center.y, (rect.size.width - inset * 2.0f - lineWidth) / 2.0f, offset, offset + (3.0f * M_PI_2) * (1.0f - _checkValue), NO);
        CGPathRef stroked = CGPathCreateCopyByStrokingPath(path, NULL, lineWidth, kCGLineCapRound, kCGLineJoinMiter, 10);
        CGContextAddPath(context, stroked);
        CGPathRelease(stroked);
        CGPathRelease(path);
        CGContextFillPath(context);
    }

    if (_checkValue > FLT_EPSILON)
    {
        CGContextSetLineWidth(context, 5.0f);
        CGContextSetLineCap(context, kCGLineCapRound);
        CGContextSetLineJoin(context, kCGLineJoinRound);
        CGContextSetMiterLimit(context, 10);
        CGFloat firstSeg = MIN(1.0f, _checkValue * 3.0f);
        CGPoint s = CGPointMake(inset + 2.5f, center.y);
        CGPoint p1 = CGPointMake(13.0f, 13.0f);
        CGPoint p2 = CGPointMake(27.0f, -27.0f);
        if (firstSeg < 1.0f)
        {
            CGContextMoveToPoint(context, s.x + p1.x * firstSeg, s.y + p1.y * firstSeg);
            CGContextAddLineToPoint(context, s.x, s.y);
        }
        else
        {
            CGFloat secondSeg = (_checkValue - 0.33f) * 1.5f;
            CGContextMoveToPoint(context, s.x + p1.x + p2.x * secondSeg, s.y + p1.y + p2.y * secondSeg);
            CGContextAddLineToPoint(context, s.x + p1.x, s.y + p1.y);
            CGContextAddLineToPoint(context, s.x, s.y);
        }
        CGContextStrokePath(context);
    }
}

- (void)displayLinkUpdate
{
    NSTimeInterval prev = _previousTime;
    NSTimeInterval now = CACurrentMediaTime();
    _previousTime = now;
    NSTimeInterval delta = prev > DBL_EPSILON ? now - prev : 0.0;
    if (delta < DBL_EPSILON) return;

    if (_isRotating) _rotationValue += delta * 1.35f;
    if (_isSucceed && _isRotating && !_delay && _rotationValue >= 0.5f)
    {
        _rotationValue = 0.5f;
        _isRotating = NO;
        _isChecking = YES;
    }
    if (_isChecking) _checkValue += delta * M_PI * 1.6f;
    if (_rotationValue > 1.0f) { _rotationValue = 0.0f; _delay = NO; }
    if (_checkValue > 1.0f)
    {
        _checkValue = 1.0f;
        [self displayLink].paused = YES;
        if (self.onSuccess) { void (^cb)(void) = [self.onSuccess copy]; self.onSuccess = nil; cb(); }
    }
    [self setNeedsDisplay];
    if (self.onDraw) { void (^cb)(void) = [self.onDraw copy]; self.onDraw = nil; cb(); }
}

- (void)setProgress
{
    _isRotating = YES;
    _isProgressing = YES;
    [self displayLink].paused = NO;
}

- (void)setSucceed:(BOOL)fromRotation progress:(CGFloat)progress
{
    if (_isSucceed) return;
    if (fromRotation) { _isRotating = YES; _isProgressing = YES; _rotationValue = progress; }
    _isSucceed = YES;
    if (!_isRotating) _isChecking = YES;
    else if (_rotationValue > 0.5f) _delay = YES;
    [self displayLink].paused = NO;
}

@end
