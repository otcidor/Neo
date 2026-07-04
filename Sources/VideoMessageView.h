#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>

@interface VideoMessageView : UIView

@property (nonatomic, strong) NSString *videoMxcURL;
@property (nonatomic, strong) NSString *thumbnailMxcURL;
@property (nonatomic, strong) NSNumber *duration; // milliseconds
@property (nonatomic, strong) UIImage *thumbnailImage;
@property (nonatomic, strong) UIImageView *thumbnailView;
@property (nonatomic, strong) UIButton *playOverlay;
@property (nonatomic, strong) UILabel *durationLabel;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;

- (void)startThumbnailDownload;
- (void)stop;

@end
