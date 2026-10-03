#import "WallpaperGalleryViewController.h"
#import "ThemeManager.h"
#import "NeoCompatibility.h"
#import <QuartzCore/QuartzCore.h>

static NSString *kWpNames[] = {
    @"Default", @"Abstract", @"Particles", @"Flowers",
    @"Leaves", @"Landscape", @"Sunset", @"Texture",
    @"Bubbles", @"Circles", @"Stripes", @"Hexagons",
    @"Triangles", @"Fabric",
};

static NSString *kWpImages[] = {
    @"wallpaper_61", @"wallpaper_01", @"wallpaper_03",
    @"wallpaper_04.jpg", @"wallpaper_05.jpg", @"wallpaper_07.jpg",
    @"wallpaper_08.jpg", @"wallpaper_12.jpg", @"wallpaper_14.jpg",
    @"wallpaper_55", @"wallpaper_56", @"wallpaper_57",
    @"wallpaper_59", @"wallpaper_60.jpg",
};

#define kWpCount 14
static NSString *kCellId = @"WPCell";

@interface WallpaperGalleryViewController () {
    UIScrollView *_scrollView;
}
@end

@implementation WallpaperGalleryViewController

- (id)init {
    self = [super init];
    if (self) {
        self.title = NSLocalizedString(@"Chat Wallpaper", nil);
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.leftBarButtonItem = [ThemeManager backBarButtonItemWithTarget:self action:@selector(neoBackAction)];
    _scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    _scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _scrollView.alwaysBounceVertical = YES;
    [self.view addSubview:_scrollView];

    [self applyTheme];
    [self layoutThumbnails];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applyTheme)
                                                 name:NeoThemeDidChangeNotification
                                               object:nil];
}

- (void)neoBackAction {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if ([self.navigationController respondsToSelector:@selector(interactivePopGestureRecognizer)]) {
        self.navigationController.interactivePopGestureRecognizer.delegate = (id<UIGestureRecognizerDelegate>)self;
    }
    [self applyTheme];
    [self layoutThumbnails];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self layoutThumbnails];
}

- (void)applyTheme {
    ThemeManager *tm = [ThemeManager sharedManager];
    self.view.backgroundColor = [tm backgroundColor];
    if (_scrollView) _scrollView.backgroundColor = [tm backgroundColor];
    [tm applyThemeToNavigationBar:self.navigationController.navigationBar];
    if (!IS_IOS7_OR_LATER) self.navigationController.navigationBar.barStyle = [tm barStyle];
}

- (void)layoutThumbnails {
    if (!_scrollView) return;
    for (UIView *v in [_scrollView subviews]) {
        [v removeFromSuperview];
    }
    CGFloat screenW = _scrollView.bounds.size.width;
    if (screenW <= 0) screenW = [UIScreen mainScreen].bounds.size.width;
    CGFloat spacing = 10;
    CGFloat itemW = (screenW - spacing * 4) / 3;
    if (itemW < 80) itemW = 80;
    CGFloat itemH = itemW * 1.4f;

    ThemeManager *tm = [ThemeManager sharedManager];
    NSString *current = [[NSUserDefaults standardUserDefaults] stringForKey:@"neo_wallpaper"] ?: kWpImages[0];

    CGFloat curY = spacing;
    for (NSInteger i = 0; i < kWpCount; i++) {
        NSInteger col = i % 3;
        NSInteger row = i / 3;
        CGFloat x = spacing + col * (itemW + spacing);
        CGFloat y = spacing + row * (itemH + spacing);

        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame = CGRectMake(x, y, itemW, itemH);
        btn.tag = 100 + i;
        btn.clipsToBounds = YES;
        btn.layer.cornerRadius = 6;
        btn.layer.borderWidth = 1;
        btn.layer.borderColor = [tm isDarkMode]
            ? [[UIColor colorWithWhite:0.35 alpha:1.0] CGColor]
            : [[UIColor colorWithWhite:0.85 alpha:1.0] CGColor];
        [btn addTarget:self action:@selector(wallpaperTapped:) forControlEvents:UIControlEventTouchUpInside];

        NSString *base = kWpImages[i];
        NSString *thumbFile = [base hasSuffix:@".jpg"]
            ? [@"thumb_" stringByAppendingString:base]
            : [[NSString alloc] initWithFormat:@"thumb_%@.jpg", base];

        UIImageView *iv = [[UIImageView alloc] initWithFrame:btn.bounds];
        iv.image = [UIImage imageNamed:thumbFile];
        iv.contentMode = UIViewContentModeScaleAspectFill;
        iv.clipsToBounds = YES;
        iv.userInteractionEnabled = NO;
        iv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [btn addSubview:iv];

        if ([current isEqualToString:kWpImages[i]]) {
            UILabel *check = [[UILabel alloc] initWithFrame:CGRectMake(itemW - 28, 4, 24, 24)];
            check.text = @"✓";
            check.textColor = [tm primaryTextColor];
            check.font = [UIFont boldSystemFontOfSize:20];
            check.textAlignment = NSTextAlignmentCenter;
            check.backgroundColor = [tm isDarkMode]
                ? [UIColor colorWithWhite:0.2 alpha:0.85]
                : [UIColor colorWithWhite:1 alpha:0.8];
            check.layer.cornerRadius = 12;
            check.clipsToBounds = YES;
            [btn addSubview:check];
        }

        UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(0, itemH - 26, itemW, 24)];
        lbl.text = NSLocalizedString(kWpNames[i], nil);
        lbl.font = [UIFont systemFontOfSize:11];
        lbl.textAlignment = NSTextAlignmentCenter;
        lbl.backgroundColor = [tm isDarkMode]
            ? [UIColor colorWithWhite:0.15 alpha:0.8]
            : [UIColor colorWithWhite:1 alpha:0.7];
        lbl.textColor = [tm primaryTextColor];
        [btn addSubview:lbl];

        [_scrollView addSubview:btn];
        curY = y + itemH + spacing;
    }
    _scrollView.contentSize = CGSizeMake(screenW, curY);
}

- (void)wallpaperTapped:(UIButton *)btn {
    NSInteger idx = btn.tag - 100;
    if (idx >= 0 && idx < kWpCount) {
        [[NSUserDefaults standardUserDefaults] setObject:kWpImages[idx] forKey:@"neo_wallpaper"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [self.navigationController popViewControllerAnimated:YES];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
