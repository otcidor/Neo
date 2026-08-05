#import <UIKit/UIKit.h>

@class MatrixMessage;

@interface ForwardPickerController : UIViewController <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) MatrixMessage *message;

@end
