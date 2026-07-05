#import <UIKit/UIKit.h>
#import "MatrixModels.h"

@class RoomListViewController;

@interface NetworksViewController : UIViewController
    <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *tableView;
@end
