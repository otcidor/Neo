#import "FileMessageView.h"
#import "MatrixAPIClient.h"

@interface FileMessageView ()
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *sizeLabel;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, readwrite, getter=isDownloaded) BOOL downloaded;
@property (nonatomic, strong) NSData *fileData;
@end

@implementation FileMessageView

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];

        self.iconView = [[UIImageView alloc] initWithFrame:CGRectMake(6, 6, 48, 48)];
        self.iconView.contentMode = UIViewContentModeScaleAspectFit;
        [self addSubview:self.iconView];

        self.nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(60, 6, frame.size.width - 66, 22)];
        self.nameLabel.font = [UIFont boldSystemFontOfSize:14];
        self.nameLabel.textColor = [UIColor darkTextColor];
        self.nameLabel.backgroundColor = [UIColor clearColor];
        self.nameLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
        [self addSubview:self.nameLabel];

        self.sizeLabel = [[UILabel alloc] initWithFrame:CGRectMake(60, 28, frame.size.width - 66, 16)];
        self.sizeLabel.font = [UIFont systemFontOfSize:12];
        self.sizeLabel.textColor = [UIColor grayColor];
        self.sizeLabel.backgroundColor = [UIColor clearColor];
        [self addSubview:self.sizeLabel];

        self.downloadLabel = [[UILabel alloc] initWithFrame:CGRectMake(60, 44, frame.size.width - 66, 14)];
        self.downloadLabel.font = [UIFont systemFontOfSize:11];
        self.downloadLabel.textColor = [UIColor colorWithRed:0.2 green:0.5 blue:0.2 alpha:1.0];
        self.downloadLabel.backgroundColor = [UIColor clearColor];
        self.downloadLabel.text = @"";
        [self addSubview:self.downloadLabel];

        self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        self.spinner.center = self.iconView.center;
        self.spinner.hidesWhenStopped = YES;
        [self addSubview:self.spinner];
    }
    return self;
}

- (void)setFileName:(NSString *)fileName {
    _fileName = fileName;
    self.nameLabel.text = fileName;
    [self updateIcon];
}

- (void)setFileSize:(NSNumber *)fileSize {
    _fileSize = fileSize;
    self.sizeLabel.text = [self formattedSize:[fileSize longLongValue]];
}

- (void)setFileMimeType:(NSString *)fileMimeType {
    _fileMimeType = fileMimeType;
    [self updateIcon];
}

- (void)updateIcon {
    NSString *iconName = [self iconNameForFile];
    UIImage *icon = [UIImage imageNamed:iconName];
    if (!icon) icon = [UIImage imageNamed:@"filetype_icon_unknown"];
    self.iconView.image = icon;
}

- (NSString *)iconNameForFile {
    NSString *ext = [[self.fileName pathExtension] lowercaseString];
    NSString *mime = [self.fileMimeType lowercaseString];

    if ([ext length] > 0) {
        if ([@[@"png", @"jpg", @"jpeg", @"gif", @"bmp", @"webp", @"tiff", @"ico"] containsObject:ext])
            return @"filetype_icon_png";
        if ([@[@"pdf"] containsObject:ext])
            return @"filetype_icon_pdf";
        if ([@[@"doc", @"docx"] containsObject:ext])
            return @"filetype_icon_doc";
        if ([@[@"xls", @"xlsx", @"csv"] containsObject:ext])
            return @"filetype_icon_xls";
        if ([@[@"ppt", @"pptx", @"odp"] containsObject:ext])
            return @"filetype_icon_ppt";
        if ([@[@"zip", @"rar", @"7z", @"gz", @"tar", @"bz2"] containsObject:ext])
            return @"filetype_icon_zip";
        if ([@[@"txt", @"log", @"json", @"xml", @"yml", @"yaml", @"plist", @"conf", @"cfg", @"md", @"ini"] containsObject:ext])
            return @"filetype_icon_txt";
        if ([@[@"mp3", @"wav", @"wma", @"flac", @"aac", @"ogg", @"m4a"] containsObject:ext])
            return @"filetype_icon_audio";
        if ([@[@"mp4", @"avi", @"mov", @"wmv", @"mkv", @"m4v", @"3gp"] containsObject:ext])
            return @"filetype_icon_video";
        if ([@[@"exe", @"dmg", @"ipa", @"apk", @"deb", @"msi"] containsObject:ext])
            return @"filetype_icon_exe";
    }

    if ([mime length] > 0) {
        if ([mime hasPrefix:@"image/"]) return @"filetype_icon_png";
        if ([mime isEqualToString:@"application/pdf"]) return @"filetype_icon_pdf";
        if ([mime hasPrefix:@"text/"]) return @"filetype_icon_txt";
        if ([mime containsString:@"zip"] || [mime containsString:@"rar"] || [mime containsString:@"tar"] || [mime containsString:@"gzip"] || [mime containsString:@"bzip"])
            return @"filetype_icon_zip";
        if ([mime containsString:@"msword"] || [mime containsString:@"wordprocessingml"])
            return @"filetype_icon_doc";
        if ([mime containsString:@"spreadsheet"] || [mime containsString:@"excel"])
            return @"filetype_icon_xls";
        if ([mime containsString:@"presentation"] || [mime containsString:@"powerpoint"])
            return @"filetype_icon_ppt";
    }

    return @"filetype_icon_unknown";
}

- (NSString *)formattedSize:(long long)bytes {
    if (bytes < 1024) return [NSString stringWithFormat:@"%lld B", bytes];
    if (bytes < 1024 * 1024) return [NSString stringWithFormat:@"%.1f KB", bytes / 1024.0];
    if (bytes < 1024 * 1024 * 1024) return [NSString stringWithFormat:@"%.1f MB", bytes / (1024.0 * 1024.0)];
    return [NSString stringWithFormat:@"%.1f GB", bytes / (1024.0 * 1024.0 * 1024.0)];
}

- (void)setDownloadedData:(NSData *)data {
    _fileData = data;
    self.downloaded = YES;
    self.downloadLabel.text = @"";
    [self.spinner stopAnimating];
}

- (NSData *)downloadedData {
    return _fileData;
}

- (void)startDownloadWithCompletion:(void(^)(NSData *data, NSError *error))completion {
    if (self.downloaded) {
        if (completion) completion(_fileData, nil);
        return;
    }
    if (!self.mxcURL) {
        if (completion) completion(nil, [NSError errorWithDomain:@"FileMessage" code:-1 userInfo:nil]);
        return;
    }

    [self.spinner startAnimating];
    self.downloadLabel.text = NSLocalizedString(@"Downloading...", nil);

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        MatrixAPIClient *client = [MatrixAPIClient sharedClient];
        NSString *httpURLStr = [client mxcURLToHTTP:self.mxcURL];
        if (!httpURLStr) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.spinner stopAnimating];
                self.downloadLabel.text = @"";
                if (completion) completion(nil, [NSError errorWithDomain:@"FileMessage" code:-2 userInfo:nil]);
            });
            return;
        }

        NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:httpURLStr]];
        if (client.accessToken) {
            [req setValue:[NSString stringWithFormat:@"Bearer %@", client.accessToken] forHTTPHeaderField:@"Authorization"];
        }
        NSURLResponse *response = nil;
        NSError *error = nil;
        NSData *data = [NSURLConnection sendSynchronousRequest:req returningResponse:&response error:&error];

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.spinner stopAnimating];
            self.downloadLabel.text = @"";
            if (data && !error) {
                [self setDownloadedData:data];
                if (completion) completion(data, nil);
            } else {
                if (completion) completion(nil, error);
            }
        });
    });
}

@end
