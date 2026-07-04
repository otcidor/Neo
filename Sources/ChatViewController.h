#import <UIKit/UIKit.h>
#import "MatrixModels.h"

@interface ChatViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate>

@property (nonatomic, strong) MatrixRoom *room;
@property (nonatomic, strong) UIImage *roomAvatar;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UITextField *messageField;
@property (nonatomic, strong) UIButton *sendButton;
@property (nonatomic, strong) NSMutableArray *messages;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;

@end
