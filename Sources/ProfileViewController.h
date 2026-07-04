#import <UIKit/UIKit.h>
#import "MatrixModels.h"

@interface ProfileViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) MatrixRoom *room;
@property (nonatomic, strong) UIImage *roomAvatar;

@end
