#import "NeoBackSwipe.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <math.h>

#define NEO_BACK_SWIPE_EDGE_WIDTH 28.0f
#define NEO_BACK_SWIPE_PARALLAX   0.30f

typedef struct {
    CGFloat progress;
    CGFloat duration;
    BOOL completes;
} NeoSwipeMotion;

static NeoSwipeMotion NeoCalculateBackSwipeMotion(CGFloat width, CGFloat translation, CGFloat velocity, BOOL ended) {
    NeoSwipeMotion result;
    result.progress = 0.0f;
    result.duration = 0.0f;
    result.completes = NO;
    if (!isfinite(width) || width <= 0.0f || !isfinite(translation)) return result;
    if (!isfinite(velocity)) velocity = 0.0f;
    result.progress = (CGFloat)fmax(0.0, fmin(1.0, (double)(translation / width)));
    result.completes = ended && velocity > -600.0f && (result.progress > 0.33f || velocity > 600.0f);
    CGFloat distance = result.completes ? (1.0f - result.progress) : result.progress;
    if (distance <= 0.0f) return result;
    CGFloat toward = result.completes ? velocity : -velocity;
    CGFloat speed = (CGFloat)fmax((double)(width / 0.25f), (double)toward);
    result.duration = (CGFloat)fmax(0.08, fmin(0.25, (double)(distance * (width / speed))));
    return result;
}

static BOOL NeoViewTakesRightwardDrag(UIView *view) {
    if ([view isKindOfClass:[UISlider class]]) return YES;
    for (UIGestureRecognizer *recognizer in view.gestureRecognizers) {
        if (!recognizer.enabled) continue;
        if ([recognizer isKindOfClass:[UISwipeGestureRecognizer class]]) {
            UISwipeGestureRecognizer *swipe = (UISwipeGestureRecognizer *)recognizer;
            if (swipe.direction & UISwipeGestureRecognizerDirectionRight) return YES;
        }
    }
    if (![view isKindOfClass:[UIScrollView class]]) return NO;
    UIScrollView *scroll = (UIScrollView *)view;
    return scroll.scrollEnabled &&
           scroll.contentSize.width > scroll.bounds.size.width + 1.0f &&
           scroll.contentOffset.x > -scroll.contentInset.left + 1.0f;
}

@interface NeoBackSwipe () {
    __weak UINavigationController *_navigation;
    UIPanGestureRecognizer *_pan;
    __weak UIGestureRecognizer *_systemPan;
    BOOL _systemPanEnabled;
    BOOL _enabled;
    BOOL _active;
    CGFloat _width;
    
    UIView *_top;
    UIView *_below;
    UIView *_dim;
    UIView *_belowHost;
    NSUInteger _belowIndex;
    CGRect _belowBounds;
    CGPoint _belowCenter;
    CGAffineTransform _belowTransform;
    CGAffineTransform _topTransform;
    
    CGColorRef _shadowColor;
    CGPathRef _shadowPath;
    float _shadowOpacity;
    CGFloat _shadowRadius;
    CGSize _shadowOffset;
}
@end

@implementation NeoBackSwipe

@synthesize navigationController = _navigation;
@synthesize panGestureRecognizer = _pan;
@synthesize enabled = _enabled;

- (id)initWithNavigationController:(UINavigationController *)navigation {
    self = [super init];
    if (!self) return nil;
    _navigation = navigation;
    _enabled = YES;
    
    if ([navigation respondsToSelector:NSSelectorFromString(@"interactivePopGestureRecognizer")]) {
        _systemPan = [navigation valueForKey:@"interactivePopGestureRecognizer"];
        _systemPanEnabled = _systemPan.enabled;
        _systemPan.enabled = NO;
    }
    
    _pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panned:)];
    _pan.delegate = self;
    _pan.maximumNumberOfTouches = 1;
    [navigation.view addGestureRecognizer:_pan];
    
    return self;
}

- (void)dealloc {
    _pan.delegate = nil;
    [_pan.view removeGestureRecognizer:_pan];
    if (_active) {
        [self finishPopping:NO];
    }
    if (_systemPan) {
        _systemPan.enabled = _systemPanEnabled;
    }
    if (_shadowColor) {
        CGColorRelease(_shadowColor);
        _shadowColor = NULL;
    }
    if (_shadowPath) {
        CGPathRelease(_shadowPath);
        _shadowPath = NULL;
    }
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gesture {
    if (gesture != _pan || !_enabled || _active) return NO;
    UINavigationController *nav = _navigation;
    if (!nav || nav.viewControllers.count < 2) return NO;
    
    UIViewController *presented = nil;
    if ([nav respondsToSelector:@selector(presentedViewController)]) {
        presented = nav.presentedViewController;
    } else if ([nav respondsToSelector:@selector(modalViewController)]) {
        presented = [nav valueForKey:@"modalViewController"];
    }
    if (presented) return NO;
    
    UIViewController *top = nav.topViewController;
    if (!top.isViewLoaded || !top.view.window) return NO;
    if ([top respondsToSelector:@selector(blocksBackSwipe)] && [(id<NeoBackSwipeBlocking>)top blocksBackSwipe]) {
        return NO;
    }
    
    for (UIView *view = top.view; view; view = view.superview) {
        if (view.layer.animationKeys.count > 0) return NO;
        if (view == nav.view) break;
    }
    
    CGPoint velocity = [_pan velocityInView:nav.view];
    return velocity.x > 0 && fabs(velocity.x) > fabs(velocity.y);
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture shouldReceiveTouch:(UITouch *)touch {
    if (!_enabled) return NO;
    if ([touch.view isKindOfClass:[UISlider class]]) return NO;
    UINavigationController *nav = _navigation;
    if (!nav) return NO;
    
    CGPoint location = [touch locationInView:nav.view];
    if (location.x < NEO_BACK_SWIPE_EDGE_WIDTH) return YES;
    
    for (UIView *view = touch.view; view && view != nav.view; view = view.superview) {
        if (NeoViewTakesRightwardDrag(view)) return NO;
    }
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other {
    return NO;
}

- (void)begin {
    UINavigationController *nav = _navigation;
    if (!nav) return;
    NSArray *stack = nav.viewControllers;
    if (stack.count < 2) return;
    
    UIViewController *top = [stack objectAtIndex:stack.count - 1];
    UIViewController *below = [stack objectAtIndex:stack.count - 2];
    if (!top.isViewLoaded || !top.view.superview || !below.view) return;
    
    UIView *host = top.view.superview;
    _width = top.view.bounds.size.width;
    if (_width <= 0) return;
    
    _active = YES;
    _top = top.view;
    _below = below.view;
    _topTransform = _top.transform;
    _belowHost = _below.superview;
    _belowIndex = _belowHost ? [_belowHost.subviews indexOfObjectIdenticalTo:_below] : 0;
    _belowBounds = _below.bounds;
    _belowCenter = _below.center;
    _belowTransform = _below.transform;
    
    _below.transform = CGAffineTransformIdentity;
    CGRect bounds = _belowBounds;
    bounds.size = _top.bounds.size;
    _below.bounds = bounds;
    _below.center = _top.center;
    [host insertSubview:_below belowSubview:_top];
    [_below setNeedsLayout];
    [_below layoutIfNeeded];
    
    _below.transform = CGAffineTransformMakeTranslation(-_width * NEO_BACK_SWIPE_PARALLAX, 0);
    
    _dim = [[UIView alloc] initWithFrame:_top.frame];
    _dim.backgroundColor = [UIColor colorWithWhite:0 alpha:0.25f];
    _dim.userInteractionEnabled = NO;
    [host insertSubview:_dim aboveSubview:_below];
    
    if (_top.layer.shadowColor) _shadowColor = CGColorRetain(_top.layer.shadowColor);
    if (_top.layer.shadowPath) _shadowPath = CGPathRetain(_top.layer.shadowPath);
    _shadowOpacity = _top.layer.shadowOpacity;
    _shadowRadius = _top.layer.shadowRadius;
    _shadowOffset = _top.layer.shadowOffset;
    
    _top.layer.shadowColor = [UIColor blackColor].CGColor;
    _top.layer.shadowOpacity = 0.35f;
    _top.layer.shadowRadius = 6.0f;
    _top.layer.shadowOffset = CGSizeZero;
    _top.layer.shadowPath = [UIBezierPath bezierPathWithRect:_top.bounds].CGPath;
}

- (void)moveTo:(CGFloat)x {
    CGFloat progress = MAX(0.0f, MIN(1.0f, x / _width));
    _top.transform = CGAffineTransformTranslate(_topTransform, progress * _width, 0);
    _below.transform = CGAffineTransformMakeTranslation(-_width * NEO_BACK_SWIPE_PARALLAX * (1.0f - progress), 0);
    _dim.alpha = 1.0f - progress;
}

- (void)finishPopping:(BOOL)pops {
    UINavigationController *nav = _navigation;
    BOOL popped = pops && nav.topViewController.view == _top;
    if (popped) {
        [nav popViewControllerAnimated:NO];
    }
    
    _top.transform = _topTransform;
    _top.layer.shadowColor = _shadowColor;
    _top.layer.shadowPath = _shadowPath;
    _top.layer.shadowOpacity = _shadowOpacity;
    _top.layer.shadowRadius = _shadowRadius;
    _top.layer.shadowOffset = _shadowOffset;
    
    if (_shadowColor) {
        CGColorRelease(_shadowColor);
        _shadowColor = NULL;
    }
    if (_shadowPath) {
        CGPathRelease(_shadowPath);
        _shadowPath = NULL;
    }
    
    [_dim removeFromSuperview];
    _dim = nil;
    
    if (!popped && nav.topViewController.view != _below) {
        [_below removeFromSuperview];
        _below.transform = CGAffineTransformIdentity;
        _below.bounds = _belowBounds;
        _below.center = _belowCenter;
        _below.transform = _belowTransform;
        if (_belowHost) {
            [_belowHost insertSubview:_below atIndex:MIN(_belowIndex, _belowHost.subviews.count)];
        }
    } else if (!popped) {
        _below.transform = CGAffineTransformIdentity;
    }
    
    _belowHost = nil;
    _top = nil;
    _below = nil;
    _active = NO;
}

- (void)panned:(UIPanGestureRecognizer *)pan {
    UINavigationController *nav = _navigation;
    if (!nav) return;
    
    switch (pan.state) {
        case UIGestureRecognizerStateBegan: {
            [self begin];
            if (_active) {
                [self moveTo:[pan translationInView:nav.view].x];
            }
            break;
        }
        case UIGestureRecognizerStateChanged: {
            if (_active) {
                [self moveTo:[pan translationInView:nav.view].x];
            }
            break;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed: {
            if (!_active) break;
            CGFloat x = [pan translationInView:nav.view].x;
            CGFloat velocity = [pan velocityInView:nav.view].x;
            NeoSwipeMotion plan = NeoCalculateBackSwipeMotion(_width, x, velocity, pan.state == UIGestureRecognizerStateEnded);
            [self moveTo:plan.progress * _width];
            
            [UIView animateWithDuration:plan.duration delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                [self moveTo:plan.completes ? self->_width : 0.0f];
            } completion:^(BOOL finished) {
                [self finishPopping:plan.completes];
            }];
            break;
        }
        default:
            break;
    }
}

@end

static const char kNeoBackSwipeKey = 'b';

@implementation UINavigationController (NeoBackSwipe)

- (void)neo_enableBackSwipe {
    NeoBackSwipe *swipe = objc_getAssociatedObject(self, &kNeoBackSwipeKey);
    if (!swipe) {
        swipe = [[NeoBackSwipe alloc] initWithNavigationController:self];
        objc_setAssociatedObject(self, &kNeoBackSwipeKey, swipe, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

- (NeoBackSwipe *)neo_backSwipe {
    return objc_getAssociatedObject(self, &kNeoBackSwipeKey);
}

@end
