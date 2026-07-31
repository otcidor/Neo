#import "PhotoViewerController.h"
#import "NeoAlert.h"

@implementation PhotoViewerController {
    UIImageView *_imageView;
    UIScrollView *_scrollView;
    BOOL _viewReady;
}

- (id)initWithImage:(UIImage *)image {
    self = [super init];
    if (self) {
        _image = image;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];

    _scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    _scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _scrollView.minimumZoomScale = 1.0;
    _scrollView.maximumZoomScale = 4.0;
    _scrollView.delegate = self;
    [self.view addSubview:_scrollView];

    _imageView = [[UIImageView alloc] initWithFrame:_scrollView.bounds];
    _imageView.contentMode = UIViewContentModeScaleAspectFit;
    [_scrollView addSubview:_imageView];

    _viewReady = YES;
    [self layoutImage];

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
}

- (void)updateImage:(UIImage *)image {
    _image = image;
    if (_viewReady) {
        [self layoutImage];
    }
}

- (void)layoutImage {
    _imageView.image = _image;
    if (!_image) return;
    CGSize fitSize = [self fitSize:_image.size inSize:_scrollView.bounds.size];
    _imageView.frame = CGRectMake(0, 0, fitSize.width, fitSize.height);
    _scrollView.contentSize = fitSize;
    [self centerImage];
}

- (void)centerImage {
    CGFloat insetX = MAX((_scrollView.bounds.size.width - _imageView.frame.size.width) / 2, 0);
    CGFloat insetY = MAX((_scrollView.bounds.size.height - _imageView.frame.size.height) / 2, 0);
    _scrollView.contentInset = UIEdgeInsetsMake(insetY, insetX, insetY, insetX);
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
    [self centerImage];
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return _imageView;
}

- (void)close {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)savePhoto {
    if (!_image) return;
    UIImageWriteToSavedPhotosAlbum(_image, nil, nil, nil);
    [NeoAlert showAlertWithTitle:nil message:NSLocalizedString(@"Saved", nil) cancelTitle:@"OK" controller:self];
}

- (CGSize)fitSize:(CGSize)from inSize:(CGSize)to {
    CGFloat scale = MIN(to.width / from.width, to.height / from.height);
    return CGSizeMake(from.width * scale, from.height * scale);
}

@end
