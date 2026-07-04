#import <UIKit/UIKit.h>

@interface NeoAlert : NSObject
+ (void)showAlertWithTitle:(NSString *)title
                   message:(NSString *)message
               cancelTitle:(NSString *)cancelTitle
                controller:(UIViewController *)vc;
+ (void)showActionSheetWithTitle:(NSString *)title
                    cancelTitle:(NSString *)cancelTitle
               destructiveTitle:(NSString *)destructiveTitle
                    otherTitles:(NSArray *)otherTitles
                     controller:(UIViewController *)vc
                    sourceRect:(CGRect)sourceRect
                   sourceView:(UIView *)sourceView
                        handler:(void (^)(NSInteger index))handler;
@end
