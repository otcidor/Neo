#import "NeoAlert.h"
#import "NeoCompatibility.h"
#import "LoginViewController.h"
#import "MatrixAPIClient.h"
#import "ThemeManager.h"
#import "RoomListViewController.h"
#import "TabBarController.h"
#import <QuartzCore/QuartzCore.h>

@implementation LoginViewController

- (void)loadView {
    [super loadView];
    self.view.backgroundColor = [[ThemeManager sharedManager] backgroundColor];

    self.navigationController.navigationBarHidden = YES;

    CGFloat w = self.view.bounds.size.width;
    CGFloat midY = self.view.bounds.size.height / 2 - 80;

    UILabel *logoLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, midY - 100, w, 50)];
    logoLabel.text = @"◈ Neo";
    logoLabel.font = [UIFont boldSystemFontOfSize:32];
    logoLabel.textAlignment = NSTextAlignmentCenter;
    logoLabel.textColor = [[ThemeManager sharedManager] tintColor];
    logoLabel.backgroundColor = [UIColor clearColor];
    [self.view addSubview:logoLabel];

    UILabel *subLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, midY - 60, w, 20)];
    subLabel.text = NSLocalizedString(@"Connect to your server", nil);
    subLabel.font = [UIFont systemFontOfSize:14];
    subLabel.textAlignment = NSTextAlignmentCenter;
    subLabel.textColor = [UIColor grayColor];
    subLabel.backgroundColor = [UIColor clearColor];
    [self.view addSubview:subLabel];

    self.homeserverField = [[UITextField alloc] initWithFrame:CGRectMake(20, midY, w - 40, 44)];
    self.homeserverField.placeholder = @"https://matrix.example.com";
    self.homeserverField.borderStyle = UITextBorderStyleRoundedRect;
    self.homeserverField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.homeserverField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.homeserverField.keyboardType = UIKeyboardTypeURL;
    self.homeserverField.delegate = self;
    self.homeserverField.returnKeyType = UIReturnKeyNext;
    self.homeserverField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    self.homeserverField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 0)];
    self.homeserverField.leftViewMode = UITextFieldViewModeAlways;
    NSString *savedHomeserver = [[NSUserDefaults standardUserDefaults]
        stringForKey:@"matrix_homeserver"];
    if ([savedHomeserver length] > 0) {
        self.homeserverField.text = savedHomeserver;
    }
    [self.view addSubview:self.homeserverField];

    self.usernameField = [[UITextField alloc] initWithFrame:CGRectMake(20, midY + 54, w - 40, 44)];
    self.usernameField.placeholder = NSLocalizedString(@"Username", nil);
    self.usernameField.borderStyle = UITextBorderStyleRoundedRect;
    self.usernameField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.usernameField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.usernameField.delegate = self;
    self.usernameField.returnKeyType = UIReturnKeyNext;
    self.usernameField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    self.usernameField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 0)];
    self.usernameField.leftViewMode = UITextFieldViewModeAlways;
    [self.view addSubview:self.usernameField];

    self.passwordField = [[UITextField alloc] initWithFrame:CGRectMake(20, midY + 108, w - 40, 44)];
    self.passwordField.placeholder = NSLocalizedString(@"Password", nil);
    self.passwordField.borderStyle = UITextBorderStyleRoundedRect;
    self.passwordField.secureTextEntry = YES;
    self.passwordField.delegate = self;
    self.passwordField.returnKeyType = UIReturnKeyDone;
    self.passwordField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    self.passwordField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 0)];
    self.passwordField.leftViewMode = UITextFieldViewModeAlways;
    [self.view addSubview:self.passwordField];

    self.loginButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.loginButton.frame = CGRectMake(20, midY + 172, w - 40, 44);
    [self.loginButton setTitle:NSLocalizedString(@"Sign In", nil) forState:UIControlStateNormal];
    self.loginButton.titleLabel.font = [UIFont boldSystemFontOfSize:17];
    self.loginButton.backgroundColor = [[ThemeManager sharedManager] tintColor];
    [self.loginButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.loginButton setTitleColor:[UIColor colorWithWhite:1.0 alpha:0.5] forState:UIControlStateHighlighted];
    self.loginButton.layer.cornerRadius = 8;
    [self.loginButton addTarget:self action:@selector(loginTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.loginButton];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.spinner.center = CGPointMake(self.view.center.x, midY + 234);
    self.spinner.hidesWhenStopped = YES;
    [self.view addSubview:self.spinner];

    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, midY + 254, w - 40, 20)];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.font = [UIFont systemFontOfSize:14];
    self.statusLabel.textColor = [UIColor grayColor];
    self.statusLabel.backgroundColor = [UIColor clearColor];
    self.statusLabel.text = @"";
    [self.view addSubview:self.statusLabel];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBarHidden = YES;
}

- (void)loginTapped {
    NSString *homeserver = [self.homeserverField.text
        stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSString *user = self.usernameField.text;
    NSString *pass = self.passwordField.text;

    if ([homeserver length] == 0 || [user length] == 0 || [pass length] == 0) {
        [NeoAlert showAlertWithTitle:NSLocalizedString(@"Error", nil)
                             message:NSLocalizedString(@"Please enter server, username and password", nil)
                         cancelTitle:NSLocalizedString(@"OK", nil)
                          controller:self];
        return;
    }

    if (![homeserver hasPrefix:@"http://"] && ![homeserver hasPrefix:@"https://"]) {
        homeserver = [NSString stringWithFormat:@"https://%@", homeserver];
    }
    if ([homeserver hasSuffix:@"/"]) {
        homeserver = [homeserver substringToIndex:[homeserver length] - 1];
    }

    [[NSUserDefaults standardUserDefaults] setObject:homeserver forKey:@"matrix_homeserver"];
    [[NSUserDefaults standardUserDefaults] synchronize];

    [[MatrixAPIClient sharedClient] setHomeserver:homeserver];

    [self.spinner startAnimating];
    self.loginButton.enabled = NO;
    self.statusLabel.text = NSLocalizedString(@"Signing in...", nil);

    [[MatrixAPIClient sharedClient] loginWithUser:user password:pass
        completion:^(NSDictionary *response, NSError *error) {
        [self.spinner stopAnimating];
        self.loginButton.enabled = YES;
        self.statusLabel.text = @"";

        if (error) {
            NSString *msg = [error localizedDescription];
            NSDictionary *userInfo = [error userInfo];
            if (userInfo[@"body"]) {
                msg = userInfo[@"body"];
            }
            [NeoAlert showAlertWithTitle:NSLocalizedString(@"Login Failed", nil)
                                message:msg
                            cancelTitle:NSLocalizedString(@"OK", nil)
                             controller:self];
            return;
        }

        UIWindow *keyWindow = [[UIApplication sharedApplication] keyWindow];
        TabBarController *tbc = [[TabBarController alloc] init];
        keyWindow.rootViewController = tbc;
    }];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == self.homeserverField) {
        [self.usernameField becomeFirstResponder];
    } else if (textField == self.usernameField) {
        [self.passwordField becomeFirstResponder];
    } else {
        [textField resignFirstResponder];
        [self loginTapped];
    }
    return YES;
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (NeoOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

@end
