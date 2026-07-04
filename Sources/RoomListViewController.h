#import <UIKit/UIKit.h>
#import "MatrixModels.h"

@interface RoomListViewController : UIViewController
    <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate, UIAlertViewDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray *rooms;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, copy) NSString *nextBatch;

@property (nonatomic, copy) NSString *spaceFilter;
@property (nonatomic, assign) SpaceTheme theme;

@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UISegmentedControl *filterControl;
@property (nonatomic, strong) NSMutableArray *filteredRooms;
@property (nonatomic, copy) NSString *activeSegment;

- (void)loadRooms;
- (void)navigateToRoom:(NSString *)roomId;

@end
