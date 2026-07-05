#import "BubbleStylePickerController.h"
#import "NeoCompatibility.h"

static NSString *const kBubbleStyleKey = @"neo_bubble_style";

@interface BubblePreview : UIView
@property (nonatomic, strong) UIColor *outgoingColor;
@end

@implementation BubblePreview
- (void)drawRect:(CGRect)rect {
    CGFloat w = self.bounds.size.width;
    CGFloat h = self.bounds.size.height;

    // Incoming bubble (left side, gray)
    UIBezierPath *inPath = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, h * 0.15, w * 0.4, h * 0.7)
                                                      cornerRadius:6];
    [[UIColor colorWithWhite:0.85 alpha:1.0] setFill];
    [inPath fill];

    // Outgoing bubble (right side, colored)
    UIBezierPath *outPath = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(w * 0.55, h * 0.15, w * 0.4, h * 0.7)
                                                       cornerRadius:6];
    [self.outgoingColor setFill];
    [outPath fill];
}
@end

@interface BubbleStylePickerController ()
@property (nonatomic, strong) NSArray *styles;
@end

@implementation BubbleStylePickerController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Bubble Style";
    self.tableView.rowHeight = 60;
    self.tableView.backgroundColor = [UIColor whiteColor];

    self.styles = @[
        @{@"key": @"neo",        @"name": @"Neo",        @"color": [UIColor colorWithRed:30/255.0  green:160/255.0 blue:80/255.0   alpha:1.0]},
        @{@"key": @"neo-cyan",   @"name": @"Cyan",       @"color": [UIColor colorWithRed:0/255.0   green:150/255.0 blue:150/255.0 alpha:1.0]},
        @{@"key": @"neo-purple", @"name": @"Purple",     @"color": [UIColor colorWithRed:140/255.0 green:35/255.0  blue:160/255.0 alpha:1.0]},
        @{@"key": @"neo-pink",   @"name": @"Pink",       @"color": [UIColor colorWithRed:180/255.0 green:55/255.0  blue:110/255.0 alpha:1.0]},
        @{@"key": @"neo-orange", @"name": @"Orange",     @"color": [UIColor colorWithRed:200/255.0 green:100/255.0 blue:20/255.0  alpha:1.0]},
        @{@"key": @"neo-red",    @"name": @"Red",        @"color": [UIColor colorWithRed:180/255.0 green:40/255.0  blue:40/255.0  alpha:1.0]},
        @{@"key": @"neo-teal",   @"name": @"Teal",       @"color": [UIColor colorWithRed:0/255.0   green:130/255.0 blue:110/255.0 alpha:1.0]},
        @{@"key": @"neo-indigo", @"name": @"Indigo",     @"color": [UIColor colorWithRed:75/255.0  green:30/255.0  blue:130/255.0 alpha:1.0]},
        @{@"key": @"whatsapp",   @"name": @"WhatsApp",   @"color": [UIColor colorWithRed:0/255.0   green:100/255.0 blue:200/255.0 alpha:1.0]},
    ];
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)section {
    return [self.styles count];
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                      reuseIdentifier:@"cell"];
        cell.selectionStyle = UITableViewCellSelectionStyleGray;

        BubblePreview *preview = [[BubblePreview alloc] initWithFrame:CGRectMake(8, 5, 80, 44)];
        preview.tag = 99;
        preview.backgroundColor = [UIColor clearColor];
        [cell.contentView addSubview:preview];

        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(96, 0, 180, 50)];
        label.tag = 100;
        label.font = [UIFont systemFontOfSize:17];
        label.backgroundColor = [UIColor clearColor];
        [cell.contentView addSubview:label];
    }

    NSDictionary *style = self.styles[ip.row];
    BubblePreview *preview = (BubblePreview *)[cell.contentView viewWithTag:99];
    preview.outgoingColor = style[@"color"];
    [preview setNeedsDisplay];

    UILabel *label = (UILabel *)[cell.contentView viewWithTag:100];
    label.text = style[@"name"];

    NSString *current = [[NSUserDefaults standardUserDefaults] stringForKey:kBubbleStyleKey];
    NSString *key = style[@"key"];
    if ((current == nil && [key isEqualToString:@"neo"]) || [current isEqualToString:key]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }

    return cell;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    NSDictionary *style = self.styles[ip.row];
    NSString *key = style[@"key"];

    if ([key isEqualToString:@"neo"]) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kBubbleStyleKey];
    } else {
        [[NSUserDefaults standardUserDefaults] setObject:key forKey:kBubbleStyleKey];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
    [tv reloadData];
}

@end
