#import "NeoDetailEmptyViewController.h"
#import "ThemeManager.h"
#import "NeoCompatibility.h"
#import <QuartzCore/QuartzCore.h>

@interface NeoDetailEmptyViewController () {
    UIView *_iconContainer;
    UIImageView *_iconView;
    UILabel *_titleLabel;
    UILabel *_messageLabel;
}
@end

@implementation NeoDetailEmptyViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Neo";

    _iconContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 80.0f, 80.0f)];
    _iconContainer.layer.shadowColor = [UIColor blackColor].CGColor;
    _iconContainer.layer.shadowOpacity = 0.25f;
    _iconContainer.layer.shadowOffset = CGSizeMake(0, 3.0f);
    _iconContainer.layer.shadowRadius = 5.0f;
    _iconContainer.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
                                     UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    [self.view addSubview:_iconContainer];

    _iconView = [[UIImageView alloc] initWithFrame:_iconContainer.bounds];
    _iconView.image = [UIImage imageNamed:@"Icon"];
    _iconView.contentMode = UIViewContentModeScaleAspectFit;
    _iconView.layer.cornerRadius = 16.0f;
    _iconView.layer.masksToBounds = YES;
    _iconView.layer.borderWidth = 0.5f;
    _iconView.layer.borderColor = [UIColor colorWithWhite:1.0f alpha:0.20f].CGColor;
    [_iconContainer addSubview:_iconView];

    _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _titleLabel.text = @"Neo";
    _titleLabel.font = [UIFont boldSystemFontOfSize:22.0f];
    _titleLabel.textAlignment = NSTextAlignmentCenter;
    _titleLabel.backgroundColor = [UIColor clearColor];
    _titleLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
                                   UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    [self.view addSubview:_titleLabel];

    _messageLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _messageLabel.text = NSLocalizedString(@"Select a conversation to start chatting", nil);
    _messageLabel.font = [UIFont systemFontOfSize:15.0f];
    _messageLabel.textAlignment = NSTextAlignmentCenter;
    _messageLabel.backgroundColor = [UIColor clearColor];
    _messageLabel.numberOfLines = 2;
    _messageLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
                                     UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    [self.view addSubview:_messageLabel];

    [self applyTheme];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applyTheme)
                                                 name:NeoThemeDidChangeNotification
                                               object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self applyTheme];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    CGSize viewSize = self.view.bounds.size;
    if (viewSize.width <= 0 || viewSize.height <= 0) return;

    CGFloat totalBlockH = 80.0f + 14.0f + 26.0f + 8.0f + 40.0f;
    CGFloat startY = roundf((viewSize.height - totalBlockH) / 2.0f) - 20.0f;
    if (startY < 40.0f) startY = 40.0f;

    _iconContainer.frame = CGRectMake(roundf((viewSize.width - 80.0f) / 2.0f), startY, 80.0f, 80.0f);
    _iconView.frame = _iconContainer.bounds;

    _titleLabel.frame = CGRectMake(20.0f, startY + 80.0f + 14.0f, viewSize.width - 40.0f, 26.0f);

    CGFloat labelW = MIN(340.0f, viewSize.width - 40.0f);
    _messageLabel.frame = CGRectMake(roundf((viewSize.width - labelW) / 2.0f),
                                     startY + 80.0f + 14.0f + 26.0f + 8.0f,
                                     labelW,
                                     40.0f);
}

- (void)applyTheme {
    ThemeManager *tm = [ThemeManager sharedManager];
    if (self.navigationController) {
        [tm applyThemeToNavigationBar:self.navigationController.navigationBar];
        if (!IS_IOS7_OR_LATER) {
            self.navigationController.navigationBar.barStyle = [tm barStyle];
        }
    }

    _titleLabel.textColor = [tm primaryTextColor] ?: [UIColor whiteColor];
    _messageLabel.textColor = [tm secondaryTextColor] ?: [UIColor grayColor];

    if (tm.isDarkGlass) {
        self.view.backgroundColor = [UIColor colorWithRed:0.09f green:0.11f blue:0.14f alpha:1.0f];
        _iconContainer.alpha = 0.85f;
    } else if (tm.isDarkMode) {
        self.view.backgroundColor = [UIColor colorWithRed:0.12f green:0.13f blue:0.15f alpha:1.0f];
        _iconContainer.alpha = 0.85f;
    } else {
        self.view.backgroundColor = [UIColor colorWithRed:0.93f green:0.94f blue:0.96f alpha:1.0f];
        _iconContainer.alpha = 0.95f;
    }
}

- (BOOL)shouldAutorotate { return YES; }

- (NeoOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation {
    return YES;
}

@end
