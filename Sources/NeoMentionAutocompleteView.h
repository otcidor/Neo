#import <UIKit/UIKit.h>

@interface NeoMentionAutocompleteView : UIView

@property (nonatomic, copy) void (^onSelectMember)(NSString *displayName, NSString *userId, BOOL isRoom);
@property (nonatomic, readonly) BOOL isShowing;
@property (nonatomic, readonly) NSUInteger itemCount;

- (instancetype)initWithFrame:(CGRect)frame;
- (void)filterWithQuery:(NSString *)query
                members:(NSDictionary *)members
               myUserId:(NSString *)myUserId;
- (void)updatePositionAboveView:(UIView *)anchorView inContainer:(UIView *)containerView;
- (void)dismissAnimated:(BOOL)animated;

@end
