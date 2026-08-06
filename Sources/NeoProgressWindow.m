#import "NeoProgressWindow.h"
#import "NeoProgressSpinnerView.h"

static BOOL NeoProgressWindowIsLight = YES;

@interface NeoProgressWindowController : UIViewController
@property (nonatomic, weak) UIWindow *weakWindow;
@end

@interface NeoProgressWindowController ()
{
    BOOL _light;
    UIView *_backgroundView;
    UIView *_containerView;
    NeoProgressSpinnerView *_spinner;
}
@end

@implementation NeoProgressWindowController

- (instancetype)init
{
    self = [super init];
    if (self) _light = NeoProgressWindowIsLight;
    return self;
}

- (instancetype)initWithLight:(BOOL)light
{
    self = [super init];
    if (self) _light = light;
    return self;
}

- (void)loadView
{
    [super loadView];

    _containerView = [[UIView alloc] initWithFrame:CGRectMake(floorf(self.view.frame.size.width - 100) / 2, floorf(self.view.frame.size.height - 100) / 2, 100, 100)];
    _containerView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    _containerView.alpha = 0.0f;
    _containerView.clipsToBounds = YES;
    _containerView.layer.cornerRadius = 20.0f;
    [self.view addSubview:_containerView];

    _backgroundView = [[UIView alloc] initWithFrame:_containerView.bounds];
    _backgroundView.backgroundColor = _light ? [UIColor colorWithRed:0xea/255.0f green:0xea/255.0f blue:0xea/255.0f alpha:0.92f] : [UIColor colorWithWhite:0.0f alpha:0.9f];
    [_containerView addSubview:_backgroundView];

    _spinner = [[NeoProgressSpinnerView alloc] initWithFrame:CGRectMake(26.0f, 26.0f, 48.0f, 48.0f) light:_light];
    [_containerView addSubview:_spinner];
}

- (void)show:(BOOL)animated
{
    UIWindow *window = _weakWindow;
    window.userInteractionEnabled = YES;
    window.hidden = NO;
    [_spinner setProgress];

    if (animated)
    {
        _containerView.transform = CGAffineTransformMakeScale(0.6f, 0.6f);
        [UIView animateWithDuration:0.3 animations:^{
            _containerView.alpha = 1.0f;
            _containerView.transform = CGAffineTransformIdentity;
        }];
    }
    else
        _containerView.alpha = 1.0f;
}

- (void)dismiss:(BOOL)animated completion:(void(^)(void))completion
{
    NeoProgressWindow *window = (NeoProgressWindow *)_weakWindow;
    window.userInteractionEnabled = NO;

    if (animated)
    {
        [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
            _containerView.alpha = 0.0f;
        } completion:^(BOOL finished) {
            if (completion) completion();
            if (finished)
            {
                window.hidden = YES;
                if (!window.skipMakeKeyWindowOnDismiss)
                    [[UIApplication sharedApplication].keyWindow makeKeyWindow];
            }
        }];
    }
    else
    {
        _containerView.alpha = 0.0f;
        window.hidden = YES;
        if (!window.skipMakeKeyWindowOnDismiss)
            [[UIApplication sharedApplication].keyWindow makeKeyWindow];
        if (completion) completion();
    }
}

- (void)dismissWithSuccess:(void(^)(void))completion
{
    NeoProgressWindow *window = (NeoProgressWindow *)_weakWindow;
    window.userInteractionEnabled = NO;

    void (^dismissBlock)(void) = ^{
        [UIView animateWithDuration:0.3 delay:0.55 options:0 animations:^{
            _containerView.alpha = 0.0f;
        } completion:^(BOOL finished) {
            if (finished)
            {
                if (completion) completion();
                window.hidden = YES;
                if (!window.skipMakeKeyWindowOnDismiss)
                    [[UIApplication sharedApplication].keyWindow makeKeyWindow];
            }
        }];
    };

    if (window.hidden || window == nil)
    {
        window.hidden = NO;
        _containerView.transform = CGAffineTransformMakeScale(0.6f, 0.6f);
        [UIView animateWithDuration:0.3 animations:^{
            _containerView.alpha = 1.0f;
            _containerView.transform = CGAffineTransformIdentity;
        } completion:^(BOOL finished) {
            (void)finished;
            dismissBlock();
        }];

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [_spinner setSucceed];
        });
    }
    else
    {
        _spinner.onSuccess = ^{ dismissBlock(); };
        [_spinner setSucceed];
    }
}

- (BOOL)canBecomeFirstResponder { return NO; }

@end

@interface NeoProgressWindow () { BOOL _dismissed; BOOL _appeared; }
@end

@implementation NeoProgressWindow

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        self.windowLevel = UIWindowLevelStatusBar;
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        NeoProgressWindowController *ctl = [[NeoProgressWindowController alloc] init];
        ctl.weakWindow = self;
        self.rootViewController = ctl;
    }
    return self;
}

- (void)showAnimated { [self show:YES]; }

- (void)showWithDelay:(NSTimeInterval)delay
{
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf && !strongSelf->_dismissed) [strongSelf show:YES];
    });
}

- (void)show:(BOOL)animated
{
    _appeared = YES;
    [(NeoProgressWindowController *)self.rootViewController show:animated];
}

- (void)dismiss:(BOOL)animated
{
    if (!_dismissed) { _dismissed = YES; self.userInteractionEnabled = NO; [(NeoProgressWindowController *)self.rootViewController dismiss:animated completion:nil]; }
}

- (void)dismissWithSuccess
{
    if (!_dismissed) { _dismissed = YES; [(NeoProgressWindowController *)self.rootViewController dismissWithSuccess:nil]; }
}

+ (void)setDarkStyle:(BOOL)dark { NeoProgressWindowIsLight = !dark; }

@end
