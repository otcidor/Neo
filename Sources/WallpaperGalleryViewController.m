#import "WallpaperGalleryViewController.h"
#import <QuartzCore/QuartzCore.h>

static NSString *kWpNames[] = {
    @"Default", @"Abstract", @"Particles", @"Flowers",
    @"Leaves", @"Landscape", @"Sunset", @"Texture",
    @"Bubbles", @"Circles", @"Stripes", @"Hexagons",
    @"Triangles", @"Fabric", @"TG Classic", @"TG Blue",
    @"TG Purple", @"TG Dark", @"TG Green", @"TG Pink",
};

static NSString *kWpImages[] = {
    @"wallpaper_61", @"wallpaper_01", @"wallpaper_03",
    @"wallpaper_04.jpg", @"wallpaper_05.jpg", @"wallpaper_07.jpg",
    @"wallpaper_08.jpg", @"wallpaper_12.jpg", @"wallpaper_14.jpg",
    @"wallpaper_55", @"wallpaper_56", @"wallpaper_57",
    @"wallpaper_59", @"wallpaper_60.jpg",
    @"wallpaper_tg.jpg", @"wallpaper_tg_0.jpg", @"wallpaper_tg_1.jpg",
    @"wallpaper_tg_2.jpg", @"wallpaper_tg_3.jpg", @"wallpaper_tg_4.jpg",
};

#define kWpCount 20
static NSString *kCellId = @"WPCell";

@implementation WallpaperGalleryViewController

- (id)init {
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    CGFloat screenW = [UIScreen mainScreen].bounds.size.width;
    CGFloat spacing = 10;
    CGFloat itemW = (screenW - spacing * 4) / 3;
    if (itemW < 80) itemW = 80;
    layout.itemSize = CGSizeMake(itemW, itemW * 1.4);
    layout.minimumInteritemSpacing = spacing;
    layout.minimumLineSpacing = spacing;
    layout.sectionInset = UIEdgeInsetsMake(spacing, spacing, spacing, spacing);
    self = [super initWithCollectionViewLayout:layout];
    if (self) {
        self.title = NSLocalizedString(@"Chat Wallpaper", nil);
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.collectionView.backgroundColor = [UIColor colorWithWhite:0.93 alpha:1.0];
    [self.collectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:kCellId];
}

- (NSInteger)collectionView:(UICollectionView *)cv numberOfItemsInSection:(NSInteger)section {
    return kWpCount;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)cv cellForItemAtIndexPath:(NSIndexPath *)ip {
    UICollectionViewCell *cell = [cv dequeueReusableCellWithReuseIdentifier:kCellId forIndexPath:ip];
    cell.contentView.clipsToBounds = YES;

    [[cell.contentView subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];

    NSString *base = kWpImages[ip.row];
    NSString *thumbFile;
    if ([base hasSuffix:@".jpg"]) {
        thumbFile = [@"thumb_" stringByAppendingString:base];
    } else {
        thumbFile = [[NSString alloc] initWithFormat:@"thumb_%@.jpg", base];
    }

    UIImageView *iv = [[UIImageView alloc] initWithFrame:cell.contentView.bounds];
    iv.image = [UIImage imageNamed:thumbFile];
    iv.contentMode = UIViewContentModeScaleAspectFill;
    iv.clipsToBounds = YES;
    iv.layer.cornerRadius = 6;
    iv.layer.borderWidth = 1;
    iv.layer.borderColor = [[UIColor colorWithWhite:0.85 alpha:1.0] CGColor];
    iv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [cell.contentView addSubview:iv];

    // Checkmark on current selection
    NSString *current = [[NSUserDefaults standardUserDefaults] stringForKey:@"neo_wallpaper"] ?: kWpImages[0];
    if ([current isEqualToString:kWpImages[ip.row]]) {
        UILabel *check = [[UILabel alloc] initWithFrame:CGRectMake(cell.bounds.size.width - 28, 4, 24, 24)];
        check.text = @"✓";
        check.textColor = [UIColor colorWithRed:0 green:0.48 blue:1 alpha:1];
        check.font = [UIFont boldSystemFontOfSize:20];
        check.textAlignment = NSTextAlignmentCenter;
        check.backgroundColor = [UIColor colorWithWhite:1 alpha:0.8];
        check.layer.cornerRadius = 12;
        check.clipsToBounds = YES;
        [cell.contentView addSubview:check];
    }

    // Name label at bottom
    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(0, cell.bounds.size.height - 26, cell.bounds.size.width, 24)];
    lbl.text = NSLocalizedString(kWpNames[ip.row], nil);
    lbl.font = [UIFont systemFontOfSize:11];
    lbl.textAlignment = NSTextAlignmentCenter;
    lbl.backgroundColor = [UIColor colorWithWhite:1 alpha:0.7];
    lbl.textColor = [UIColor darkGrayColor];
    [cell.contentView addSubview:lbl];

    return cell;
}

- (void)collectionView:(UICollectionView *)cv didSelectItemAtIndexPath:(NSIndexPath *)ip {
    [[NSUserDefaults standardUserDefaults] setObject:kWpImages[ip.row] forKey:@"neo_wallpaper"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self.navigationController popViewControllerAnimated:YES];
}

@end
