#import "NeoMessageContextMenuView.h"
#import <QuartzCore/QuartzCore.h>

@interface _NeoContextMenuItem : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, assign) BOOL isDestructive;
@property (nonatomic, copy) void (^action)(void);
@end

@implementation _NeoContextMenuItem
@end

@interface NeoMessageContextMenuView ()
@property (nonatomic, strong) UIView *dimmingView;
@property (nonatomic, strong) UIView *menuContainer;
@property (nonatomic, strong) NSArray *menuItems;
@property (nonatomic, copy) void (^onReactionSelected)(NSString *emoji);
@property (nonatomic, copy) void (^onCustomReaction)(void);
@end

@implementation NeoMessageContextMenuView

+ (void)showForMessage:(MatrixMessage *)msg
                inView:(UIView *)parentView
          bubbleCenter:(CGPoint)bubbleCenter
                isSelf:(BOOL)isSelf
    onReactionSelected:(void(^)(NSString *emoji))onReaction
      onCustomReaction:(void(^)(void))onCustomReaction
               onReply:(void(^)(void))onReply
                onCopy:(void(^)(void))onCopy
             onForward:(void(^)(void))onForward
           onSaveMedia:(void(^)(void))onSaveMedia
              onOpenIn:(void(^)(void))onOpenIn
            onDownload:(void(^)(void))onDownload
                onEdit:(void(^)(void))onEdit
              onDelete:(void(^)(void))onDelete {

    if (!parentView) return;

    // Dismiss any existing context menu
    for (UIView *sub in parentView.subviews) {
        if ([sub isKindOfClass:[NeoMessageContextMenuView class]]) {
            [(NeoMessageContextMenuView *)sub dismissAnimated:NO];
        }
    }

    NeoMessageContextMenuView *overlay = [[NeoMessageContextMenuView alloc] initWithFrame:parentView.bounds];
    overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    overlay.onReactionSelected = onReaction;
    overlay.onCustomReaction = onCustomReaction;

    BOOL isImage = [msg.msgType isEqualToString:@"m.image"] || [msg.body hasPrefix:@"mxc://"];
    BOOL isVideo = [msg.msgType isEqualToString:@"m.video"];
    BOOL isFile = [msg.msgType isEqualToString:@"m.file"];
    BOOL fileDownloaded = isFile && (msg.cachedFileData != nil);
    BOOL isText = [msg.msgType isEqualToString:@"m.text"] || [msg.msgType isEqualToString:@"m.notice"] || [msg.msgType isEqualToString:@"m.emote"];

    NSMutableArray *items = [NSMutableArray array];

    // 1. Reply (always available)
    if (onReply) {
        _NeoContextMenuItem *reply = [[_NeoContextMenuItem alloc] init];
        reply.title = NSLocalizedString(@"Reply", nil);
        reply.action = onReply;
        [items addObject:reply];
    }

    // 2. Copy (for text or messages with content)
    if (onCopy && (isText || [msg.body length] > 0)) {
        _NeoContextMenuItem *copy = [[_NeoContextMenuItem alloc] init];
        copy.title = NSLocalizedString(@"Copy", nil);
        copy.action = onCopy;
        [items addObject:copy];
    }

    // 3. Forward (always available)
    if (onForward) {
        _NeoContextMenuItem *fwd = [[_NeoContextMenuItem alloc] init];
        fwd.title = NSLocalizedString(@"Forward", nil);
        fwd.action = onForward;
        [items addObject:fwd];
    }

    // 4. Save Media (for photo or video)
    if (onSaveMedia && (isImage || isVideo)) {
        _NeoContextMenuItem *save = [[_NeoContextMenuItem alloc] init];
        save.title = isVideo ? NSLocalizedString(@"Save Video", nil) : NSLocalizedString(@"Save Photo", nil);
        save.action = onSaveMedia;
        [items addObject:save];
    }

    // 5. File actions (Open In or Download)
    if (isFile) {
        if (fileDownloaded && onOpenIn) {
            _NeoContextMenuItem *open = [[_NeoContextMenuItem alloc] init];
            open.title = NSLocalizedString(@"Open in...", nil);
            open.action = onOpenIn;
            [items addObject:open];
        } else if (onDownload) {
            _NeoContextMenuItem *down = [[_NeoContextMenuItem alloc] init];
            down.title = NSLocalizedString(@"Download", nil);
            down.action = onDownload;
            [items addObject:down];
        }
    }

    // 6. Edit (only if self and text message)
    if (isSelf && isText && onEdit && !msg.isRedacted) {
        _NeoContextMenuItem *edit = [[_NeoContextMenuItem alloc] init];
        edit.title = NSLocalizedString(@"Edit", nil);
        edit.action = onEdit;
        [items addObject:edit];
    }

    // 7. Delete (only if self or outgoing)
    if (isSelf && onDelete) {
        _NeoContextMenuItem *del = [[_NeoContextMenuItem alloc] init];
        del.title = NSLocalizedString(@"Delete", nil);
        del.isDestructive = YES;
        del.action = onDelete;
        [items addObject:del];
    }

    overlay.menuItems = items;
    [overlay buildSubviewsWithBubbleCenter:bubbleCenter];
    [parentView addSubview:overlay];
    [overlay presentAnimated:YES];
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];

        _dimmingView = [[UIView alloc] initWithFrame:self.bounds];
        _dimmingView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.45];
        _dimmingView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(backdropTapped)];
        [_dimmingView addGestureRecognizer:tap];
        [self addSubview:_dimmingView];
    }
    return self;
}

- (void)buildSubviewsWithBubbleCenter:(CGPoint)bubbleCenter {
    CGFloat cardW = 268.0f;
    CGFloat pillH = 44.0f;
    CGFloat rowH = 42.0f;
    CGFloat gap = 9.0f;
    CGFloat actionCardH = [self.menuItems count] * rowH;
    CGFloat cancelH = 42.0f;

    CGFloat totalH = pillH + gap + actionCardH + gap + cancelH;

    CGFloat containerX = floorf((self.bounds.size.width - cardW) / 2.0f);
    CGFloat minY = 28.0f;
    CGFloat maxY = self.bounds.size.height - totalH - 16.0f;
    if (maxY < minY) maxY = minY;

    CGFloat targetY = bubbleCenter.y - (totalH * 0.45f);
    if (targetY < minY) targetY = minY;
    if (targetY > maxY) targetY = maxY;

    _menuContainer = [[UIView alloc] initWithFrame:CGRectMake(containerX, floorf(targetY), cardW, totalH)];
    _menuContainer.backgroundColor = [UIColor clearColor];
    _menuContainer.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [self addSubview:_menuContainer];

    // 1. REACTION PILL
    UIView *pill = [[UIView alloc] initWithFrame:CGRectMake(0, 0, cardW, pillH)];
    pill.backgroundColor = [UIColor colorWithRed:0.14f green:0.14f blue:0.15f alpha:0.96f];
    pill.layer.cornerRadius = 22.0f;
    pill.layer.borderWidth = 1.0f;
    pill.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.13].CGColor;
    pill.layer.shadowColor = [UIColor blackColor].CGColor;
    pill.layer.shadowOpacity = 0.35f;
    pill.layer.shadowRadius = 8.0f;
    pill.layer.shadowOffset = CGSizeMake(0, 3);
    [_menuContainer addSubview:pill];

    NSArray *quickEmojis = @[@"👍", @"❤️", @"😂", @"😮", @"😢", @"🙏"];
    CGFloat emojiW = 34.0f;
    CGFloat plusW = 30.0f;
    CGFloat padLeft = 8.0f;

    for (NSUInteger i = 0; i < [quickEmojis count]; i++) {
        UIButton *eBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        eBtn.frame = CGRectMake(padLeft + i * emojiW, 2, emojiW, 40);
        [eBtn setTitle:quickEmojis[i] forState:UIControlStateNormal];
        eBtn.titleLabel.font = [UIFont systemFontOfSize:22.0f];
        eBtn.tag = 100 + i;
        [eBtn addTarget:self action:@selector(quickEmojiTapped:) forControlEvents:UIControlEventTouchUpInside];
        [pill addSubview:eBtn];
    }

    // Plus button for custom reaction
    UIButton *plusBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    plusBtn.frame = CGRectMake(cardW - plusW - 10.0f, (pillH - plusW) / 2.0f, plusW, plusW);
    plusBtn.backgroundColor = [UIColor colorWithWhite:0.25 alpha:0.85];
    plusBtn.layer.cornerRadius = plusW / 2.0f;
    plusBtn.layer.borderWidth = 0.5f;
    plusBtn.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.2].CGColor;
    [plusBtn setTitle:@"+" forState:UIControlStateNormal];
    [plusBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    plusBtn.titleLabel.font = [UIFont boldSystemFontOfSize:19.0f];
    [plusBtn addTarget:self action:@selector(customPlusTapped) forControlEvents:UIControlEventTouchUpInside];
    [pill addSubview:plusBtn];

    // 2. ACTION CARD
    CGFloat cardY = pillH + gap;
    UIView *card = [[UIView alloc] initWithFrame:CGRectMake(0, cardY, cardW, actionCardH)];
    card.backgroundColor = [UIColor colorWithRed:0.14f green:0.14f blue:0.15f alpha:0.96f];
    card.layer.cornerRadius = 14.0f;
    card.layer.borderWidth = 1.0f;
    card.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.13].CGColor;
    card.layer.shadowColor = [UIColor blackColor].CGColor;
    card.layer.shadowOpacity = 0.35f;
    card.layer.shadowRadius = 8.0f;
    card.layer.shadowOffset = CGSizeMake(0, 4);
    card.clipsToBounds = YES;
    [_menuContainer addSubview:card];

    CGFloat scale = [UIScreen mainScreen].scale;
    CGFloat sepHeight = (scale > 1.0f) ? (1.0f / scale) : 1.0f;

    for (NSUInteger i = 0; i < [self.menuItems count]; i++) {
        _NeoContextMenuItem *item = self.menuItems[i];
        CGFloat itemY = i * rowH;

        if (i > 0) {
            UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(14, itemY, cardW - 28, sepHeight)];
            sep.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.10];
            [card addSubview:sep];
        }

        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame = CGRectMake(0, itemY, cardW, rowH);
        btn.tag = 200 + i;
        [btn addTarget:self action:@selector(actionButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [btn addTarget:self action:@selector(buttonTouchDown:) forControlEvents:UIControlEventTouchDown];
        [btn addTarget:self action:@selector(buttonTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];

        UILabel *titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(18.0f, 0, cardW - 36.0f, rowH)];
        titleLbl.text = item.title;
        titleLbl.backgroundColor = [UIColor clearColor];
        titleLbl.font = [UIFont systemFontOfSize:16.0f];
        titleLbl.textColor = item.isDestructive ?
            [UIColor colorWithRed:1.0f green:0.27f blue:0.27f alpha:1.0f] :
            [UIColor whiteColor];
        titleLbl.userInteractionEnabled = NO;
        [btn addSubview:titleLbl];

        [card addSubview:btn];
    }

    // 3. CANCEL BUTTON
    CGFloat cancelY = cardY + actionCardH + gap;
    UIButton *cancelBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    cancelBtn.frame = CGRectMake(0, cancelY, cardW, cancelH);
    cancelBtn.backgroundColor = [UIColor colorWithRed:0.14f green:0.14f blue:0.15f alpha:0.96f];
    cancelBtn.layer.cornerRadius = 14.0f;
    cancelBtn.layer.borderWidth = 1.0f;
    cancelBtn.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.13].CGColor;
    [cancelBtn setTitle:NSLocalizedString(@"Cancel", nil) forState:UIControlStateNormal];
    [cancelBtn setTitleColor:[UIColor colorWithWhite:0.92 alpha:1.0] forState:UIControlStateNormal];
    cancelBtn.titleLabel.font = [UIFont boldSystemFontOfSize:16.0f];
    [cancelBtn addTarget:self action:@selector(backdropTapped) forControlEvents:UIControlEventTouchUpInside];
    [cancelBtn addTarget:self action:@selector(buttonTouchDown:) forControlEvents:UIControlEventTouchDown];
    [cancelBtn addTarget:self action:@selector(buttonTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    [_menuContainer addSubview:cancelBtn];
}

#pragma mark - Button Highlights

- (void)buttonTouchDown:(UIButton *)sender {
    sender.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.12];
}

- (void)buttonTouchUp:(UIButton *)sender {
    sender.backgroundColor = [UIColor clearColor];
}

#pragma mark - Actions

- (void)backdropTapped {
    [self dismissAnimated:YES];
}

- (void)quickEmojiTapped:(UIButton *)sender {
    NSArray *quickEmojis = @[@"👍", @"❤️", @"😂", @"😮", @"😢", @"🙏"];
    NSUInteger idx = sender.tag - 100;
    if (idx < [quickEmojis count]) {
        NSString *emoji = quickEmojis[idx];
        void (^callback)(NSString *) = self.onReactionSelected;
        [self dismissWithAction:^{
            if (callback) callback(emoji);
        } animated:YES];
    }
}

- (void)customPlusTapped {
    void (^callback)(void) = self.onCustomReaction;
    [self dismissWithAction:^{
        if (callback) callback();
    } animated:YES];
}

- (void)actionButtonTapped:(UIButton *)sender {
    NSUInteger idx = sender.tag - 200;
    if (idx < [self.menuItems count]) {
        _NeoContextMenuItem *item = self.menuItems[idx];
        void (^action)(void) = item.action;
        [self dismissWithAction:^{
            if (action) action();
        } animated:YES];
    }
}

#pragma mark - Animations

- (void)presentAnimated:(BOOL)animated {
    if (!animated) {
        _dimmingView.alpha = 1.0f;
        _menuContainer.alpha = 1.0f;
        return;
    }

    _dimmingView.alpha = 0.0f;
    _menuContainer.alpha = 0.0f;
    _menuContainer.transform = CGAffineTransformMakeScale(0.88f, 0.88f);

    [UIView animateWithDuration:0.22 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.dimmingView.alpha = 1.0f;
        self.menuContainer.alpha = 1.0f;
        self.menuContainer.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)dismissAnimated:(BOOL)animated {
    [self dismissWithAction:nil animated:animated];
}

- (void)dismissWithAction:(void(^)(void))action animated:(BOOL)animated {
    if (!animated) {
        [self removeFromSuperview];
        if (action) action();
        return;
    }

    [UIView animateWithDuration:0.18 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
        self.dimmingView.alpha = 0.0f;
        self.menuContainer.alpha = 0.0f;
        self.menuContainer.transform = CGAffineTransformMakeScale(0.92f, 0.92f);
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
        if (action) action();
    }];
}

@end
