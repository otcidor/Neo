#import "VideoMessageView.h"
#import "MatrixAPIClient.h"
#import <QuartzCore/QuartzCore.h>

@implementation VideoMessageView

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor colorWithWhite:0.18 alpha:1.0];
        self.clipsToBounds = YES;
        self.layer.cornerRadius = 6;

        _thumbnailView = [[UIImageView alloc] initWithFrame:self.bounds];
        _thumbnailView.contentMode = UIViewContentModeScaleAspectFill;
        _thumbnailView.clipsToBounds = YES;
        _thumbnailView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:_thumbnailView];

        _playOverlay = [UIButton buttonWithType:UIButtonTypeCustom];
        UIImage *playImg = [UIImage imageNamed:@"VideoOverlayPlay"];
        if (!playImg) playImg = [UIImage imageNamed:@"Video-play-button"];
        [_playOverlay setImage:playImg forState:UIControlStateNormal];
        [_playOverlay setImage:[UIImage imageNamed:@"VideoOverlayPlayDown"] forState:UIControlStateHighlighted];
        _playOverlay.frame = CGRectMake(0, 0, 48, 48);
        _playOverlay.center = CGPointMake(frame.size.width / 2, frame.size.height / 2);
        _playOverlay.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
                                         UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        _playOverlay.userInteractionEnabled = NO;
        [self addSubview:_playOverlay];

        _durationLabel = [[UILabel alloc] initWithFrame:CGRectMake(6, frame.size.height - 22, 48, 16)];
        _durationLabel.font = [UIFont boldSystemFontOfSize:11];
        _durationLabel.textColor = [UIColor whiteColor];
        _durationLabel.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.55f];
        _durationLabel.layer.cornerRadius = 3;
        _durationLabel.clipsToBounds = YES;
        _durationLabel.textAlignment = NSTextAlignmentCenter;
        _durationLabel.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin;
        _durationLabel.shadowColor = [UIColor colorWithWhite:0 alpha:0.6];
        _durationLabel.shadowOffset = CGSizeMake(0, -1);
        [self addSubview:_durationLabel];

        _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        _spinner.center = CGPointMake(frame.size.width / 2, frame.size.height / 2);
        _spinner.hidesWhenStopped = YES;
        _spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
                                     UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        [self addSubview:_spinner];

        if (self.thumbnailImage) {
            _thumbnailView.image = self.thumbnailImage;
        }
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _thumbnailView.frame = self.bounds;
    _playOverlay.center = CGPointMake(self.bounds.size.width / 2.0f, self.bounds.size.height / 2.0f);
    CGFloat dw = self.durationLabel.frame.size.width > 20 ? self.durationLabel.frame.size.width : 48;
    _durationLabel.frame = CGRectMake(6, self.bounds.size.height - 22, dw, 16);
    _spinner.center = CGPointMake(self.bounds.size.width / 2.0f, self.bounds.size.height / 2.0f);
}

- (void)setThumbnailImage:(UIImage *)thumbnailImage {
    _thumbnailImage = thumbnailImage;
    _thumbnailView.image = thumbnailImage;
    if (thumbnailImage) {
        [self.spinner stopAnimating];
    }
}

- (void)setDuration:(NSNumber *)duration {
    _duration = duration;
    NSInteger ms = [duration integerValue];
    NSInteger sec = ms / 1000;
    self.durationLabel.text = [NSString stringWithFormat:@"%d:%02d", (int)sec / 60, (int)sec % 60];
    CGSize sz = [self.durationLabel.text sizeWithFont:self.durationLabel.font];
    CGFloat w = ceilf(sz.width) + 12.0f;
    self.durationLabel.frame = CGRectMake(6, self.bounds.size.height - 22, w, 16);
}

- (NSString *)cachePathForThumbnailMXC:(NSString *)mxcURL {
    NSString *cacheDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)[0]
                          stringByAppendingPathComponent:@"MediaCache"];
    [[NSFileManager defaultManager] createDirectoryAtPath:cacheDir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    NSString *safeName = [mxcURL stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    safeName = [safeName stringByReplacingOccurrencesOfString:@":" withString:@"_"];
    return [cacheDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.jpg", safeName]];
}

- (void)startThumbnailDownload {
    [self startThumbnailDownloadWithCompletion:nil];
}

- (void)startThumbnailDownloadWithCompletion:(void(^)(UIImage *image))completion {
    if (!self.thumbnailMxcURL || [self.thumbnailMxcURL length] == 0) {
        if (completion) completion(nil);
        return;
    }
    if (self.thumbnailImage) {
        if (completion) completion(self.thumbnailImage);
        return;
    }

    NSString *cachePath = [self cachePathForThumbnailMXC:self.thumbnailMxcURL];
    if ([[NSFileManager defaultManager] fileExistsAtPath:cachePath]) {
        UIImage *cached = [UIImage imageWithContentsOfFile:cachePath];
        if (cached) {
            self.thumbnailImage = cached;
            if (completion) completion(cached);
            return;
        }
    }

    [self.spinner startAnimating];

    __weak typeof(self) weakSelf = self;
    [[MatrixAPIClient sharedClient] downloadImageFromMXC:self.thumbnailMxcURL
                                              completion:^(UIImage *image, NSError *error) {
        typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf) {
            [strongSelf.spinner stopAnimating];
            if (image) {
                strongSelf.thumbnailImage = image;
                NSData *jpgData = UIImageJPEGRepresentation(image, 0.8);
                [jpgData writeToFile:cachePath atomically:YES];
            }
        }
        if (completion) completion(image);
    }];
}

- (void)stop {
    // no-op, playback handled by ChatVC via MPMoviePlayerViewController
}

@end
