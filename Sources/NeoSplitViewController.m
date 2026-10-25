#import "NeoSplitViewController.h"
#import "NeoDetailEmptyViewController.h"
#import "ChatViewController.h"
#import "ThemeManager.h"
#import "NeoCompatibility.h"

@interface NeoSplitViewController () {
    UIView *_masterContainer;
    UIView *_stripeView;
    UIView *_detailContainer;
    UINavigationController *_detailNavigationController;
}
@end

@implementation NeoSplitViewController

+ (BOOL)isPad {
    return (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
}

+ (instancetype)sharedSplitViewController {
    static NeoSplitViewController *sInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sInstance = [[NeoSplitViewController alloc] init];
    });
    return sInstance;
}

- (id)init {
    self = [super init];
    if (self) {
        NeoDetailEmptyViewController *emptyVC = [[NeoDetailEmptyViewController alloc] init];
        _detailNavigationController = [[UINavigationController alloc] initWithRootViewController:emptyVC];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];

    _masterContainer = [[UIView alloc] initWithFrame:CGRectZero];
    _masterContainer.clipsToBounds = YES;
    [self.view addSubview:_masterContainer];

    _stripeView = [[UIView alloc] initWithFrame:CGRectZero];
    [self.view addSubview:_stripeView];

    _detailContainer = [[UIView alloc] initWithFrame:CGRectZero];
    _detailContainer.clipsToBounds = YES;
    [self.view addSubview:_detailContainer];

    // Attach detail navigation controller
    [self addChildViewController:_detailNavigationController];
    _detailNavigationController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [_detailContainer addSubview:_detailNavigationController.view];
    [_detailNavigationController didMoveToParentViewController:self];

    // Attach master if available
    if (self.masterViewController) {
        [self attachMasterViewController:self.masterViewController];
    }

    [self applyTheme];
    [self layoutColumnsForSize:self.view.bounds.size];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applyTheme)
                                                 name:NeoThemeDidChangeNotification
                                               object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setMasterViewController:(UIViewController *)masterViewController {
    if (_masterViewController == masterViewController) return;

    if (_masterViewController && _masterViewController.parentViewController == self) {
        [_masterViewController willMoveToParentViewController:nil];
        [_masterViewController.view removeFromSuperview];
        [_masterViewController removeFromParentViewController];
    }

    _masterViewController = masterViewController;

    if ([self isViewLoaded] && _masterViewController) {
        [self attachMasterViewController:_masterViewController];
        [self layoutColumnsForSize:self.view.bounds.size];
    }
}

- (void)attachMasterViewController:(UIViewController *)vc {
    [self addChildViewController:vc];
    vc.view.frame = _masterContainer.bounds;
    vc.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [_masterContainer addSubview:vc.view];
    [vc didMoveToParentViewController:self];
}

- (UINavigationController *)detailNavigationController {
    return _detailNavigationController;
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    [self layoutColumnsForSize:self.view.bounds.size];
}

- (void)layoutColumnsForSize:(CGSize)size {
    CGFloat totalW = size.width;
    CGFloat totalH = size.height;
    if (totalW <= 0 || totalH <= 0) return;

    CGFloat masterW = (totalW >= 1024.0f) ? 360.0f : 320.0f;
    CGFloat stripeW = ([[UIScreen mainScreen] scale] > 1.0f) ? 0.5f : 1.0f;
    CGFloat detailW = MAX(0.0f, totalW - masterW - stripeW);

    _masterContainer.frame = CGRectMake(0, 0, masterW, totalH);
    _stripeView.frame = CGRectMake(masterW, 0, stripeW, totalH);
    _detailContainer.frame = CGRectMake(masterW + stripeW, 0, detailW, totalH);

    if (_masterViewController && _masterViewController.isViewLoaded) {
        _masterViewController.view.frame = _masterContainer.bounds;
    }
    if (_detailNavigationController && _detailNavigationController.isViewLoaded) {
        _detailNavigationController.view.frame = _detailContainer.bounds;
    }
}

- (void)showChatViewController:(ChatViewController *)chatVC {
    if (!chatVC) return;
    chatVC.hidesBottomBarWhenPushed = NO;
    [_detailNavigationController setViewControllers:@[chatVC] animated:NO];
}

- (void)clearDetail {
    NeoDetailEmptyViewController *emptyVC = [[NeoDetailEmptyViewController alloc] init];
    [_detailNavigationController setViewControllers:@[emptyVC] animated:NO];
}

- (ChatViewController *)currentChatViewController {
    UIViewController *top = _detailNavigationController.topViewController;
    if ([top isKindOfClass:[ChatViewController class]]) {
        return (ChatViewController *)top;
    }
    return nil;
}

- (void)applyTheme {
    ThemeManager *tm = [ThemeManager sharedManager];
    _stripeView.backgroundColor = [tm separatorColor] ?: [UIColor colorWithWhite:0.75f alpha:1.0f];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    [self layoutColumnsForSize:self.view.bounds.size];
}

- (BOOL)shouldAutorotate { return YES; }

- (NeoOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation {
    return YES;
}

@end
