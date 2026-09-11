#import "NeoMentionAutocompleteView.h"
#import "MatrixAPIClient.h"
#import <QuartzCore/QuartzCore.h>

@interface _NeoMentionItem : NSObject
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, copy) NSString *userId;
@property (nonatomic, copy) NSString *avatarUrl;
@property (nonatomic, assign) BOOL isRoom;
@end

@implementation _NeoMentionItem
@end

@interface NeoMentionAutocompleteView () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray *filteredItems;
@property (nonatomic, strong) UIView *topBorder;
@property (nonatomic, assign) BOOL isShowing;
@end

@implementation NeoMentionAutocompleteView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor colorWithRed:0.12f green:0.12f blue:0.14f alpha:0.96f];
        self.clipsToBounds = YES;
        self.layer.cornerRadius = 8.0f;
        self.layer.borderWidth = 1.0f;
        self.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.14].CGColor;

        _filteredItems = [[NSMutableArray alloc] init];

        _tableView = [[UITableView alloc] initWithFrame:self.bounds style:UITableViewStylePlain];
        _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _tableView.backgroundColor = [UIColor clearColor];
        _tableView.separatorColor = [UIColor colorWithWhite:1.0 alpha:0.10];
        _tableView.rowHeight = 44.0f;
        _tableView.dataSource = self;
        _tableView.delegate = self;
        if ([_tableView respondsToSelector:@selector(setSeparatorInset:)]) {
            [_tableView setSeparatorInset:UIEdgeInsetsMake(0, 48, 0, 0)];
        }
        [self addSubview:_tableView];

        self.alpha = 0.0f;
        self.hidden = YES;
        _isShowing = NO;
    }
    return self;
}

- (NSUInteger)itemCount {
    return [self.filteredItems count];
}

- (void)filterWithQuery:(NSString *)query
                members:(NSDictionary *)members
               myUserId:(NSString *)myUserId {
    NSString *clean = [query lowercaseString];
    if ([clean hasPrefix:@"@"]) {
        clean = [clean substringFromIndex:1];
    }

    [self.filteredItems removeAllObjects];

    // 1. Check for @room option
    if ([clean length] == 0 ||
        [@"room" hasPrefix:clean] ||
        [@"all" hasPrefix:clean] ||
        [@"todos" hasPrefix:clean]) {
        _NeoMentionItem *roomItem = [[_NeoMentionItem alloc] init];
        roomItem.displayName = @"room";
        roomItem.userId = @"@room";
        roomItem.isRoom = YES;
        [self.filteredItems addObject:roomItem];
    }

    // 2. Filter room members
    NSMutableArray *userItems = [NSMutableArray array];
    for (NSString *uId in [members allKeys]) {
        if (myUserId && [uId isEqualToString:myUserId]) continue; // Spec: don't self-mention

        NSDictionary *info = members[uId];
        NSString *disp = [info isKindOfClass:[NSDictionary class]] ? info[@"displayname"] : nil;
        if (!disp || [disp length] == 0) disp = uId;
        NSString *avatar = [info isKindOfClass:[NSDictionary class]] ? info[@"avatar_url"] : nil;

        if ([clean length] == 0 ||
            [[disp lowercaseString] rangeOfString:clean].location != NSNotFound ||
            [[uId lowercaseString] rangeOfString:clean].location != NSNotFound) {
            _NeoMentionItem *item = [[_NeoMentionItem alloc] init];
            item.displayName = disp;
            item.userId = uId;
            item.avatarUrl = avatar;
            item.isRoom = NO;
            [userItems addObject:item];
        }
    }

    // Sort member items alphabetically by display name
    [userItems sortUsingComparator:^NSComparisonResult(_NeoMentionItem *i1, _NeoMentionItem *i2) {
        return [i1.displayName localizedCaseInsensitiveCompare:i2.displayName];
    }];

    // Limit to 20 suggestions
    NSInteger maxCount = MIN(20, (NSInteger)[userItems count]);
    for (NSInteger i = 0; i < maxCount; i++) {
        [self.filteredItems addObject:userItems[i]];
    }

    if ([self.filteredItems count] == 0) {
        [self dismissAnimated:YES];
        return;
    }

    [self.tableView reloadData];
}

- (void)updatePositionAboveView:(UIView *)anchorView inContainer:(UIView *)containerView {
    if (!anchorView || !containerView || [self.filteredItems count] == 0) {
        [self dismissAnimated:YES];
        return;
    }

    CGFloat rowH = 44.0f;
    CGFloat targetH = MIN(4.0f, (CGFloat)[self.filteredItems count]) * rowH;
    CGFloat pad = 6.0f;
    CGFloat w = containerView.bounds.size.width - (pad * 2);
    CGFloat x = pad;

    CGRect anchorInContainer = [containerView convertRect:anchorView.frame fromView:anchorView.superview];
    CGFloat y = anchorInContainer.origin.y - targetH - 4.0f;

    CGRect newFrame = CGRectMake(x, y, w, targetH);

    if (self.hidden || !self.isShowing) {
        self.frame = CGRectMake(x, y + 10.0f, w, targetH);
        self.hidden = NO;
        self.alpha = 0.0f;
        [containerView addSubview:self];
        [containerView bringSubviewToFront:self];

        [UIView animateWithDuration:0.20 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            self.frame = newFrame;
            self.alpha = 1.0f;
        } completion:^(BOOL finished) {
            self.isShowing = YES;
        }];
    } else {
        [UIView animateWithDuration:0.15 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            self.frame = newFrame;
            self.alpha = 1.0f;
        } completion:nil];
    }
}

- (void)dismissAnimated:(BOOL)animated {
    if (!self.isShowing && self.hidden) return;

    if (animated) {
        [UIView animateWithDuration:0.18 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
            self.alpha = 0.0f;
            CGRect f = self.frame;
            f.origin.y += 8.0f;
            self.frame = f;
        } completion:^(BOOL finished) {
            self.hidden = YES;
            self.isShowing = NO;
            [self removeFromSuperview];
        }];
    } else {
        self.alpha = 0.0f;
        self.hidden = YES;
        self.isShowing = NO;
        [self removeFromSuperview];
    }
}

#pragma mark - UITableViewDataSource & Delegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.filteredItems count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"NeoMentionCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId];
        cell.backgroundColor = [UIColor clearColor];
        cell.selectionStyle = UITableViewCellSelectionStyleGray;

        UIView *selBg = [[UIView alloc] init];
        selBg.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.12];
        cell.selectedBackgroundView = selBg;

        cell.textLabel.font = [UIFont boldSystemFontOfSize:14.0f];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.textLabel.backgroundColor = [UIColor clearColor];

        cell.detailTextLabel.font = [UIFont systemFontOfSize:11.5f];
        cell.detailTextLabel.textColor = [UIColor colorWithWhite:0.70 alpha:1.0];
        cell.detailTextLabel.backgroundColor = [UIColor clearColor];

        UIImageView *avatar = [[UIImageView alloc] initWithFrame:CGRectMake(10, 8, 28, 28)];
        avatar.tag = 101;
        avatar.layer.cornerRadius = 14.0f;
        avatar.clipsToBounds = YES;
        avatar.contentMode = UIViewContentModeScaleAspectFill;
        [cell.contentView addSubview:avatar];

        // Indent labels to make room for avatar
        cell.indentationLevel = 1;
        cell.indentationWidth = 38.0f;
    }

    _NeoMentionItem *item = self.filteredItems[indexPath.row];
    UIImageView *avatar = (UIImageView *)[cell.contentView viewWithTag:101];

    if (item.isRoom) {
        cell.textLabel.text = @"@room";
        cell.detailTextLabel.text = NSLocalizedString(@"Notify everyone in this room", nil);
        cell.textLabel.textColor = [UIColor colorWithRed:1.0f green:0.65f blue:0.0f alpha:1.0f]; // Amber

        // Generate clean @room badge icon
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(28, 28), NO, [UIScreen mainScreen].scale);
        CGContextRef ctx = UIGraphicsGetCurrentContext();
        [[UIColor colorWithRed:1.0f green:0.65f blue:0.0f alpha:0.25f] setFill];
        CGContextFillEllipseInRect(ctx, CGRectMake(0, 0, 28, 28));
        [[UIColor colorWithRed:1.0f green:0.65f blue:0.0f alpha:1.0f] set];
        [@"@" drawInRect:CGRectMake(0, 4, 28, 20) withFont:[UIFont boldSystemFontOfSize:15.0f] lineBreakMode:NSLineBreakByClipping alignment:NSTextAlignmentCenter];
        UIImage *roomBadge = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        avatar.image = roomBadge;
    } else {
        cell.textLabel.text = item.displayName;
        cell.detailTextLabel.text = item.userId;
        cell.textLabel.textColor = [UIColor whiteColor];

        // Placeholder avatar with first letter
        NSString *initial = [item.displayName length] > 0 ? [[item.displayName substringToIndex:1] uppercaseString] : @"?";
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(28, 28), NO, [UIScreen mainScreen].scale);
        CGContextRef ctx = UIGraphicsGetCurrentContext();
        [[UIColor colorWithWhite:0.25 alpha:1.0] setFill];
        CGContextFillEllipseInRect(ctx, CGRectMake(0, 0, 28, 28));
        [[UIColor whiteColor] set];
        [initial drawInRect:CGRectMake(0, 5, 28, 18) withFont:[UIFont boldSystemFontOfSize:13.0f] lineBreakMode:NSLineBreakByClipping alignment:NSTextAlignmentCenter];
        UIImage *ph = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        avatar.image = ph;

        if ([item.avatarUrl length] > 0) {
            MatrixAPIClient *client = [MatrixAPIClient sharedClient];
            UIImage *cached = [client cachedImageForMXC:item.avatarUrl];
            if (cached) {
                avatar.image = cached;
            } else {
                [client downloadImageFromMXC:item.avatarUrl completion:^(UIImage *img, NSError *err) {
                    if (img) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            UITableViewCell *visible = [tableView cellForRowAtIndexPath:indexPath];
                            if (visible) {
                                UIImageView *vAvatar = (UIImageView *)[visible.contentView viewWithTag:101];
                                vAvatar.image = img;
                            }
                        });
                    }
                }];
            }
        }
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row >= [self.filteredItems count]) return;

    _NeoMentionItem *item = self.filteredItems[indexPath.row];
    if (self.onSelectMember) {
        self.onSelectMember(item.displayName, item.userId, item.isRoom);
    }
    [self dismissAnimated:YES];
}

@end
