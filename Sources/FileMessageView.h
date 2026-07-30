#import <UIKit/UIKit.h>

@interface FileMessageView : UIView

@property (nonatomic, strong) NSString *mxcURL;
@property (nonatomic, strong) NSString *fileName;
@property (nonatomic, strong) NSNumber *fileSize;
@property (nonatomic, strong) NSString *fileMimeType;
@property (nonatomic, readonly, getter=isDownloaded) BOOL downloaded;

@property (nonatomic, strong) UILabel *downloadLabel;

- (void)setDownloadedData:(NSData *)data;
- (NSData *)downloadedData;

@end
