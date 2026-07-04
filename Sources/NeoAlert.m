#import "NeoAlert.h"
#import "NeoCompatibility.h"
#import <objc/runtime.h>

@interface _NeoActionDelegate : NSObject <UIActionSheetDelegate>
@property (nonatomic, copy) void (^handler)(NSInteger index);
@end

@implementation _NeoActionDelegate
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (self.handler) self.handler(buttonIndex);
}
@end

@implementation NeoAlert

+ (void)showAlertWithTitle:(NSString *)title
                   message:(NSString *)message
               cancelTitle:(NSString *)cancelTitle
                controller:(UIViewController *)vc {
    if (IS_IOS8_OR_LATER) {
        UIAlertController *ac = [UIAlertController alertControllerWithTitle:title
                                                                    message:message
                                                             preferredStyle:UIAlertControllerStyleAlert];
        [ac addAction:[UIAlertAction actionWithTitle:cancelTitle
                                               style:UIAlertActionStyleCancel
                                             handler:nil]];
        [vc presentViewController:ac animated:YES completion:nil];
    } else {
        [[[UIAlertView alloc] initWithTitle:title
                                    message:message
                                   delegate:nil
                          cancelButtonTitle:cancelTitle
                          otherButtonTitles:nil] show];
    }
}

+ (void)showActionSheetWithTitle:(NSString *)title
                    cancelTitle:(NSString *)cancelTitle
               destructiveTitle:(NSString *)destructiveTitle
                    otherTitles:(NSArray *)otherTitles
                     controller:(UIViewController *)vc
                    sourceRect:(CGRect)sourceRect
                   sourceView:(UIView *)sourceView
                        handler:(void (^)(NSInteger index))handler {
    if (IS_IOS8_OR_LATER) {
        UIAlertController *ac = [UIAlertController alertControllerWithTitle:title
                                                                    message:nil
                                                             preferredStyle:UIAlertControllerStyleActionSheet];
        NSInteger base = 0;
        [ac addAction:[UIAlertAction actionWithTitle:cancelTitle
                                               style:UIAlertActionStyleCancel
                                             handler:^(UIAlertAction *a) { if (handler) handler(0); }]];
        if (destructiveTitle) {
            base = 1;
            [ac addAction:[UIAlertAction actionWithTitle:destructiveTitle
                                                   style:UIAlertActionStyleDestructive
                                                 handler:^(UIAlertAction *a) { if (handler) handler(1); }]];
        }
        for (NSString *other in otherTitles) {
            base++;
            [ac addAction:[UIAlertAction actionWithTitle:other
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(UIAlertAction *a) { if (handler) handler(base); }]];
        }
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            UIPopoverPresentationController *pop = ac.popoverPresentationController;
            pop.sourceView = sourceView;
            pop.sourceRect = sourceRect;
        }
        [vc presentViewController:ac animated:YES completion:nil];
    } else {
        UIActionSheet *as = [[UIActionSheet alloc] init];
        as.title = title;
        NSInteger destIndex = -1;
        if (destructiveTitle) {
            destIndex = [as addButtonWithTitle:destructiveTitle];
        }
        for (NSString *other in otherTitles) {
            [as addButtonWithTitle:other];
        }
        NSInteger cancelIndex = [as addButtonWithTitle:cancelTitle];
        as.cancelButtonIndex = cancelIndex;
        _NeoActionDelegate *del = [[_NeoActionDelegate alloc] init];
        del.handler = ^(NSInteger buttonIndex) {
            NSInteger mapped;
            if (buttonIndex == cancelIndex) {
                mapped = 0;
            } else if (destIndex >= 0 && buttonIndex == destIndex) {
                mapped = 1;
            } else {
                mapped = buttonIndex + 1;
            }
            if (handler) handler(mapped);
        };
        as.delegate = del;
        objc_setAssociatedObject(as, "del", del, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [as showInView:sourceView];
    }
}

@end
