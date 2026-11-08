#import "PhotoViewerController.h"
#import "NeoAlert.h"
#import "NeoCompatibility.h"
#import "MatrixModels.h"
#import "MatrixAPIClient.h"

@interface PhotoViewerController () {
    UIImageView *_imageView;
    UIScrollView *_scrollView;
    UIActivityIndicatorView *_spinner;
    NSArray *_messages;
    NSInteger _currentIndex;
    BOOL _viewReady;
    BOOL _isDismissing;
    
    UIPanGestureRecognizer *_dismissPan;
    UISwipeGestureRecognizer *_swipeLeft;
    UISwipeGestureRecognizer *_swipeRight;
    UITapGestureRecognizer *_doubleTap;
    UITapGestureRecognizer *_singleTap;
}
@end

@implementation PhotoViewerController

- (id)initWithImage:(UIImage *)image {
    self = [super init];
    if (self) {
        _image = image;
        _messages = nil;
        _currentIndex = 0;
    }
    return self;
}

- (id)initWithMessages:(NSArray *)messages initialIndex:(NSUInteger)initialIndex {
    self = [super init];
    if (self) {
        _messages = [messages copy];
        _currentIndex = (NSInteger)initialIndex;
        if (_currentIndex < 0) _currentIndex = 0;
        if (_currentIndex >= (NSInteger)[_messages count]) _currentIndex = [_messages count] - 1;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    self.wantsFullScreenLayout = YES;

    _scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    _scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _scrollView.minimumZoomScale = 1.0f;
    _scrollView.maximumZoomScale = 4.0f;
    _scrollView.delegate = self;
    _scrollView.showsHorizontalScrollIndicator = NO;
    _scrollView.showsVerticalScrollIndicator = NO;
    [self.view addSubview:_scrollView];

    _imageView = [[UIImageView alloc] initWithFrame:_scrollView.bounds];
    _imageView.contentMode = UIViewContentModeScaleAspectFit;
    _imageView.userInteractionEnabled = YES;
    [_scrollView addSubview:_imageView];

    _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    _spinner.center = CGPointMake(self.view.bounds.size.width / 2.0f, self.view.bounds.size.height / 2.0f);
    _spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
                                UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    _spinner.hidesWhenStopped = YES;
    [self.view addSubview:_spinner];

    // Navigation Bar items
    UIBarButtonItem *closeBtn = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Close", nil)
                                                                 style:UIBarButtonItemStyleDone
                                                                target:self
                                                                action:@selector(close)];
    self.navigationItem.rightBarButtonItem = closeBtn;

    UIBarButtonItem *saveBtn = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Save", nil)
                                                                style:UIBarButtonItemStylePlain
                                                               target:self
                                                               action:@selector(savePhoto)];
    self.navigationItem.leftBarButtonItem = saveBtn;

    // Gestures
    _doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
    _doubleTap.numberOfTapsRequired = 2;
    [self.view addGestureRecognizer:_doubleTap];

    _singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSingleTap)];
    [_singleTap requireGestureRecognizerToFail:_doubleTap];
    [self.view addGestureRecognizer:_singleTap];

    _dismissPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDismissPan:)];
    _dismissPan.delegate = self;
    [self.view addGestureRecognizer:_dismissPan];

    if ([_messages count] > 1) {
        _swipeLeft = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipeLeft)];
        _swipeLeft.direction = UISwipeGestureRecognizerDirectionLeft;
        _swipeLeft.delegate = self;
        [self.view addGestureRecognizer:_swipeLeft];

        _swipeRight = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipeRight)];
        _swipeRight.direction = UISwipeGestureRecognizerDirectionRight;
        _swipeRight.delegate = self;
        [self.view addGestureRecognizer:_swipeRight];
    }

    _viewReady = YES;

    if ([_messages count] > 0) {
        [self loadMessageAtIndex:_currentIndex animated:NO];
    } else if (_image) {
        [self layoutImage];
        self.title = NSLocalizedString(@"Photo", nil);
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (self.navigationController) {
        self.navigationController.navigationBar.barStyle = UIBarStyleBlackTranslucent;
    }
}

#pragma mark - Message Paging

- (void)loadMessageAtIndex:(NSInteger)index animated:(BOOL)animated {
    if (index < 0 || index >= (NSInteger)[_messages count]) return;
    _currentIndex = index;

    self.title = [NSString stringWithFormat:NSLocalizedString(@"%d of %d", nil), (int)(_currentIndex + 1), (int)[_messages count]];

    MatrixMessage *msg = [_messages objectAtIndex:_currentIndex];

    // Check if full-resolution original is already cached
    UIImage *fullImage = [[MatrixAPIClient sharedClient] cachedFullImageForMXC:msg.imageURL];
    if (!fullImage && msg.cachedImage && (msg.cachedImage.size.width >= 1200 || msg.cachedImage.size.height >= 1200)) {
        fullImage = msg.cachedImage;
    }

    if (fullImage) {
        [_spinner stopAnimating];
        msg.cachedImage = fullImage;
        [self setImage:fullImage animated:animated];
        return;
    }

    // Display preview thumbnail immediately as placeholder while downloading original
    if (msg.cachedImage) {
        [self setImage:msg.cachedImage animated:animated];
    } else {
        UIImage *thumb = [[MatrixAPIClient sharedClient] cachedImageForMXC:msg.imageURL];
        if (thumb) {
            [self setImage:thumb animated:animated];
        }
    }

    if ([msg.imageURL length] > 0) {
        [_spinner startAnimating];
        __weak typeof(self) weakSelf = self;
        [[MatrixAPIClient sharedClient] downloadFullImageFromMXC:msg.imageURL completion:^(UIImage *downloaded, NSError *err) {
            PhotoViewerController *strongSelf = weakSelf;
            if (!strongSelf) return;
            if (strongSelf->_currentIndex == index) {
                [strongSelf->_spinner stopAnimating];
                if (downloaded) {
                    msg.cachedImage = downloaded;
                    [strongSelf setImage:downloaded animated:YES];
                }
            }
        }];
    } else {
        [_spinner stopAnimating];
    }
}

- (void)setImage:(UIImage *)newImage animated:(BOOL)animated {
    _image = newImage;
    if (!_viewReady) return;

    if (_scrollView.zoomScale > 1.01f) {
        _imageView.image = _image;
        return;
    }

    if (animated) {
        [UIView transitionWithView:_imageView
                          duration:0.22
                           options:UIViewAnimationOptionTransitionCrossDissolve
                        animations:^{
            [self layoutImage];
        } completion:nil];
    } else {
        [self layoutImage];
    }
}

- (void)handleSwipeLeft {
    if (_scrollView.zoomScale > 1.01f || _isDismissing) return;
    if (_currentIndex + 1 < (NSInteger)[_messages count]) {
        [self loadMessageAtIndex:_currentIndex + 1 animated:YES];
    }
}

- (void)handleSwipeRight {
    if (_scrollView.zoomScale > 1.01f || _isDismissing) return;
    if (_currentIndex - 1 >= 0) {
        [self loadMessageAtIndex:_currentIndex - 1 animated:YES];
    }
}

#pragma mark - Dismiss Pan Gesture

- (void)handleDismissPan:(UIPanGestureRecognizer *)pan {
    if (_isDismissing) return;

    CGPoint translation = [pan translationInView:self.view];
    CGPoint velocity = [pan velocityInView:self.view];

    switch (pan.state) {
        case UIGestureRecognizerStateBegan:
        case UIGestureRecognizerStateChanged: {
            CGFloat progress = MIN(1.0f, (CGFloat)(fabs(translation.y) / 240.0));
            _imageView.transform = CGAffineTransformMakeTranslation(0, translation.y);
            self.view.backgroundColor = [UIColor colorWithWhite:0.0f alpha:1.0f - progress * 0.75f];
            if (self.navigationController) {
                self.navigationController.navigationBar.alpha = 1.0f - progress;
            }
            break;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed: {
            BOOL shouldDismiss = (fabs(translation.y) > 95.0f || fabs(velocity.y) > 550.0f);
            if (shouldDismiss && pan.state == UIGestureRecognizerStateEnded) {
                _isDismissing = YES;
                CGFloat targetY = (translation.y < 0) ? -self.view.bounds.size.height : self.view.bounds.size.height;
                [UIView animateWithDuration:0.20 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                    self->_imageView.transform = CGAffineTransformMakeTranslation(0, targetY);
                    self.view.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.0f];
                    if (self.navigationController) {
                        self.navigationController.navigationBar.alpha = 0.0f;
                    }
                } completion:^(BOOL finished) {
                    [self dismissViewControllerAnimated:NO completion:nil];
                }];
            } else {
                [UIView animateWithDuration:0.22 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                    self->_imageView.transform = CGAffineTransformIdentity;
                    self.view.backgroundColor = [UIColor blackColor];
                    if (self.navigationController) {
                        self.navigationController.navigationBar.alpha = 1.0f;
                    }
                } completion:nil];
            }
            break;
        }
        default:
            break;
    }
}

#pragma mark - Tap & Zoom

- (void)handleSingleTap {
    if (self.navigationController) {
        BOOL willHide = !self.navigationController.navigationBarHidden;
        [self.navigationController setNavigationBarHidden:willHide animated:YES];
        [[UIApplication sharedApplication] setStatusBarHidden:willHide withAnimation:UIStatusBarAnimationFade];
    }
}

- (void)handleDoubleTap:(UITapGestureRecognizer *)tap {
    if (_scrollView.zoomScale > 1.01f) {
        [_scrollView setZoomScale:1.0f animated:YES];
    } else {
        CGPoint touchPoint = [tap locationInView:_imageView];
        CGFloat newZoomScale = 2.5f;
        CGSize scrollViewSize = _scrollView.bounds.size;
        CGFloat w = scrollViewSize.width / newZoomScale;
        CGFloat h = scrollViewSize.height / newZoomScale;
        CGRect zoomRect = CGRectMake(touchPoint.x - (w / 2.0f), touchPoint.y - (h / 2.0f), w, h);
        [_scrollView zoomToRect:zoomRect animated:YES];
    }
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gesture {
    if (gesture == _dismissPan) {
        if (_scrollView.zoomScale > 1.01f || _isDismissing) return NO;
        CGPoint vel = [_dismissPan velocityInView:self.view];
        return fabs(vel.y) > fabs(vel.x) * 1.5f;
    }
    if (gesture == _swipeLeft || gesture == _swipeRight) {
        return (_scrollView.zoomScale <= 1.01f && !_isDismissing);
    }
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other {
    if (gesture == _dismissPan || other == _dismissPan) return NO;
    return YES;
}

#pragma mark - Layout & Zoom

- (void)updateImage:(UIImage *)image {
    _image = image;
    if (_viewReady) {
        [self layoutImage];
    }
}

- (void)layoutImage {
    _scrollView.zoomScale = 1.0f;
    _imageView.transform = CGAffineTransformIdentity;
    _imageView.image = _image;
    if (!_image) return;

    CGSize fitSize = [self fitSize:_image.size inSize:_scrollView.bounds.size];
    _imageView.frame = CGRectMake(0, 0, fitSize.width, fitSize.height);
    _scrollView.contentSize = fitSize;
    [self centerImage];
}

- (void)centerImage {
    CGFloat insetX = MAX((_scrollView.bounds.size.width - _imageView.frame.size.width) / 2.0f, 0.0f);
    CGFloat insetY = MAX((_scrollView.bounds.size.height - _imageView.frame.size.height) / 2.0f, 0.0f);
    _scrollView.contentInset = UIEdgeInsetsMake(insetY, insetX, insetY, insetX);
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
    [self centerImage];
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return _imageView;
}

#pragma mark - Actions

- (void)close {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)savePhoto {
    MatrixMessage *msg = (_currentIndex >= 0 && _currentIndex < (NSInteger)[_messages count]) ? [_messages objectAtIndex:_currentIndex] : nil;
    UIImage *saveImg = msg ? [[MatrixAPIClient sharedClient] cachedFullImageForMXC:msg.imageURL] : nil;
    if (!saveImg) saveImg = _image;

    if (!saveImg) return;
    UIImageWriteToSavedPhotosAlbum(saveImg, nil, nil, nil);
    [NeoAlert showAlertWithTitle:nil message:NSLocalizedString(@"Saved to Photos", nil) cancelTitle:@"OK" controller:self];
}

- (CGSize)fitSize:(CGSize)from inSize:(CGSize)to {
    if (from.width <= 0.0f || from.height <= 0.0f || to.width <= 0.0f || to.height <= 0.0f) {
        return CGSizeZero;
    }
    CGFloat scale = MIN(to.width / from.width, to.height / from.height);
    return CGSizeMake(floorf(from.width * scale), floorf(from.height * scale));
}

- (BOOL)shouldAutorotate { return YES; }
- (NeoOrientationMask)supportedInterfaceOrientations { return UIInterfaceOrientationMaskAll; }
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation { return YES; }

@end
