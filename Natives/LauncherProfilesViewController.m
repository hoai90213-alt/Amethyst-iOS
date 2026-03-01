#import "authenticator/BaseAuthenticator.h"
#import <QuartzCore/QuartzCore.h>
#import "LauncherMenuViewController.h"
#import "LauncherNavigationController.h"
#import "LauncherPreferencesViewController.h"
#import "LauncherProfileEditorViewController.h"
#import "LauncherProfilesViewController.h"
#import "PLProfiles.h"
#import "UIImageView+AFNetworking.h"
#import "UIKit+hook.h"
#import "ios_uikit_bridge.h"
#import "utils.h"

@interface LauncherProfilesViewController ()

@property(nonatomic) UIView *panelView;
@property(nonatomic) UIImageView *avatarView;
@property(nonatomic) UILabel *usernameLabel;
@property(nonatomic) UILabel *subtitleLabel;
@property(nonatomic) UILabel *profileNameLabel;
@property(nonatomic) UILabel *versionLabel;
@property(nonatomic) UIButton *launchButton;
@property(nonatomic) UIButton *selectProfileButton;
@property(nonatomic) UIButton *manageProfileButton;
@property(nonatomic) UIButton *installJarButton;

@end

@implementation LauncherProfilesViewController

- (id)init {
    self = [super init];
    self.title = @"Launcher";
    return self;
}

- (NSString *)imageName {
    return @"MenuProfiles";
}

- (UIButton *)makeActionButton:(NSString *)title systemImage:(NSString *)imageName primary:(BOOL)primary action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.layer.cornerRadius = 12.0;
    button.layer.borderWidth = 1.0;
    if (@available(iOS 13.0, *)) {
        button.layer.cornerCurve = kCACornerCurveContinuous;
    }

    UIColor *accent = [UIColor colorWithRed:19.0/255.0 green:212.0/255.0 blue:1.0 alpha:1.0];
    if (primary) {
        CAGradientLayer *gradient = [CAGradientLayer layer];
        gradient.name = @"pl.zenith.launch.gradient";
        gradient.startPoint = CGPointMake(0.0, 0.5);
        gradient.endPoint = CGPointMake(1.0, 0.5);
        gradient.colors = @[
            (id)[UIColor colorWithRed:20.0/255.0 green:196.0/255.0 blue:255.0/255.0 alpha:1.0].CGColor,
            (id)[UIColor colorWithRed:76.0/255.0 green:110.0/255.0 blue:1.0 alpha:1.0].CGColor
        ];
        gradient.frame = CGRectMake(0, 0, 260, 52);
        gradient.cornerRadius = 12.0;
        [button.layer insertSublayer:gradient atIndex:0];
        button.backgroundColor = UIColor.clearColor;
        button.layer.borderColor = [UIColor colorWithRed:99.0/255.0 green:206.0/255.0 blue:255.0/255.0 alpha:0.9].CGColor;
        button.layer.shadowColor = [accent colorWithAlphaComponent:0.6].CGColor;
        button.layer.shadowRadius = 12.0;
        button.layer.shadowOpacity = 0.32;
        button.layer.shadowOffset = CGSizeMake(0, 5);
        [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        button.tintColor = UIColor.whiteColor;
    } else {
        button.backgroundColor = [UIColor colorWithRed:16.0/255.0 green:28.0/255.0 blue:48.0/255.0 alpha:0.92];
        button.layer.borderColor = [UIColor colorWithRed:85.0/255.0 green:122.0/255.0 blue:170.0/255.0 alpha:0.55].CGColor;
        [button setTitleColor:[UIColor colorWithWhite:0.93 alpha:1.0] forState:UIControlStateNormal];
        button.tintColor = [UIColor colorWithWhite:0.93 alpha:1.0];
    }

    UIImageSymbolConfiguration *symbolCfg = [UIImageSymbolConfiguration configurationWithPointSize:15 weight:UIFontWeightSemibold];
    [button setImage:[UIImage systemImageNamed:imageName withConfiguration:symbolCfg] forState:UIControlStateNormal];
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    button.contentEdgeInsets = UIEdgeInsetsMake(12, 14, 12, 14);
    button.imageEdgeInsets = UIEdgeInsetsMake(0, -8, 0, 4);
    button.titleEdgeInsets = UIEdgeInsetsMake(0, 4, 0, 0);
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    [button addTarget:self action:action forControlEvents:UIControlEventPrimaryActionTriggered];

    return button;
}

- (void)buildLayout {
    self.tableView.hidden = YES;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.scrollEnabled = NO;
    self.navigationItem.leftBarButtonItem = self.splitViewController.displayModeButtonItem;
    self.navigationItem.leftItemsSupplementBackButton = YES;

    self.panelView = [[UIView alloc] init];
    self.panelView.translatesAutoresizingMaskIntoConstraints = NO;
    self.panelView.backgroundColor = [UIColor colorWithRed:18.0/255.0 green:29.0/255.0 blue:50.0/255.0 alpha:0.94];
    self.panelView.layer.cornerRadius = 18.0;
    self.panelView.layer.borderWidth = 1.0;
    self.panelView.layer.borderColor = [UIColor colorWithRed:85.0/255.0 green:122.0/255.0 blue:170.0/255.0 alpha:0.55].CGColor;
    if (@available(iOS 13.0, *)) {
        self.panelView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.view addSubview:self.panelView];

    self.avatarView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"DefaultAccount"]];
    self.avatarView.translatesAutoresizingMaskIntoConstraints = NO;
    self.avatarView.layer.cornerRadius = 40.0;
    self.avatarView.layer.masksToBounds = YES;
    self.avatarView.contentMode = UIViewContentModeScaleAspectFill;
    [self.panelView addSubview:self.avatarView];

    self.usernameLabel = [[UILabel alloc] init];
    self.usernameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.usernameLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
    self.usernameLabel.textColor = UIColor.whiteColor;
    self.usernameLabel.textAlignment = NSTextAlignmentCenter;
    self.usernameLabel.numberOfLines = 2;
    [self.panelView addSubview:self.usernameLabel];

    self.subtitleLabel = [[UILabel alloc] init];
    self.subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.subtitleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    self.subtitleLabel.textColor = [UIColor colorWithWhite:0.84 alpha:1.0];
    self.subtitleLabel.textAlignment = NSTextAlignmentCenter;
    self.subtitleLabel.numberOfLines = 1;
    [self.panelView addSubview:self.subtitleLabel];

    self.profileNameLabel = [[UILabel alloc] init];
    self.profileNameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.profileNameLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    self.profileNameLabel.textColor = [UIColor colorWithWhite:0.95 alpha:1.0];
    self.profileNameLabel.textAlignment = NSTextAlignmentLeft;
    [self.panelView addSubview:self.profileNameLabel];

    self.versionLabel = [[UILabel alloc] init];
    self.versionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.versionLabel.font = [UIFont monospacedDigitSystemFontOfSize:14 weight:UIFontWeightRegular];
    self.versionLabel.textColor = [UIColor colorWithWhite:0.8 alpha:1.0];
    self.versionLabel.textAlignment = NSTextAlignmentLeft;
    [self.panelView addSubview:self.versionLabel];

    self.launchButton = [self makeActionButton:@"LAUNCH GAME" systemImage:@"play.fill" primary:YES action:@selector(actionLaunch)];
    self.selectProfileButton = [self makeActionButton:@"Select Profile" systemImage:@"person.crop.circle" primary:NO action:@selector(actionSelectProfile)];
    self.manageProfileButton = [self makeActionButton:@"Edit Profile" systemImage:@"gearshape.fill" primary:NO action:@selector(actionManageProfile)];
    self.installJarButton = [self makeActionButton:@"Execute .jar" systemImage:@"shippingbox.fill" primary:NO action:@selector(actionInstallJar)];
    [self.panelView addSubview:self.launchButton];
    [self.panelView addSubview:self.selectProfileButton];
    [self.panelView addSubview:self.manageProfileButton];
    [self.panelView addSubview:self.installJarButton];

    UILayoutGuide *guide = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.panelView.centerXAnchor constraintEqualToAnchor:guide.centerXAnchor],
        [self.panelView.centerYAnchor constraintEqualToAnchor:guide.centerYAnchor constant:-6.0],
        [self.panelView.widthAnchor constraintLessThanOrEqualToConstant:420.0],
        [self.panelView.widthAnchor constraintEqualToAnchor:guide.widthAnchor multiplier:0.82],

        [self.avatarView.topAnchor constraintEqualToAnchor:self.panelView.topAnchor constant:26.0],
        [self.avatarView.centerXAnchor constraintEqualToAnchor:self.panelView.centerXAnchor],
        [self.avatarView.widthAnchor constraintEqualToConstant:80.0],
        [self.avatarView.heightAnchor constraintEqualToConstant:80.0],

        [self.usernameLabel.topAnchor constraintEqualToAnchor:self.avatarView.bottomAnchor constant:14.0],
        [self.usernameLabel.leadingAnchor constraintEqualToAnchor:self.panelView.leadingAnchor constant:18.0],
        [self.usernameLabel.trailingAnchor constraintEqualToAnchor:self.panelView.trailingAnchor constant:-18.0],

        [self.subtitleLabel.topAnchor constraintEqualToAnchor:self.usernameLabel.bottomAnchor constant:4.0],
        [self.subtitleLabel.leadingAnchor constraintEqualToAnchor:self.panelView.leadingAnchor constant:18.0],
        [self.subtitleLabel.trailingAnchor constraintEqualToAnchor:self.panelView.trailingAnchor constant:-18.0],

        [self.profileNameLabel.topAnchor constraintEqualToAnchor:self.subtitleLabel.bottomAnchor constant:14.0],
        [self.profileNameLabel.leadingAnchor constraintEqualToAnchor:self.panelView.leadingAnchor constant:20.0],
        [self.profileNameLabel.trailingAnchor constraintEqualToAnchor:self.panelView.trailingAnchor constant:-20.0],

        [self.versionLabel.topAnchor constraintEqualToAnchor:self.profileNameLabel.bottomAnchor constant:5.0],
        [self.versionLabel.leadingAnchor constraintEqualToAnchor:self.panelView.leadingAnchor constant:20.0],
        [self.versionLabel.trailingAnchor constraintEqualToAnchor:self.panelView.trailingAnchor constant:-20.0],

        [self.selectProfileButton.topAnchor constraintEqualToAnchor:self.versionLabel.bottomAnchor constant:16.0],
        [self.selectProfileButton.leadingAnchor constraintEqualToAnchor:self.panelView.leadingAnchor constant:20.0],
        [self.selectProfileButton.trailingAnchor constraintEqualToAnchor:self.panelView.trailingAnchor constant:-20.0],
        [self.selectProfileButton.heightAnchor constraintEqualToConstant:46.0],

        [self.manageProfileButton.topAnchor constraintEqualToAnchor:self.selectProfileButton.bottomAnchor constant:10.0],
        [self.manageProfileButton.leadingAnchor constraintEqualToAnchor:self.panelView.leadingAnchor constant:20.0],
        [self.manageProfileButton.trailingAnchor constraintEqualToAnchor:self.panelView.trailingAnchor constant:-20.0],
        [self.manageProfileButton.heightAnchor constraintEqualToConstant:46.0],

        [self.installJarButton.topAnchor constraintEqualToAnchor:self.manageProfileButton.bottomAnchor constant:10.0],
        [self.installJarButton.leadingAnchor constraintEqualToAnchor:self.panelView.leadingAnchor constant:20.0],
        [self.installJarButton.trailingAnchor constraintEqualToAnchor:self.panelView.trailingAnchor constant:-20.0],
        [self.installJarButton.heightAnchor constraintEqualToConstant:46.0],

        [self.launchButton.topAnchor constraintEqualToAnchor:self.installJarButton.bottomAnchor constant:16.0],
        [self.launchButton.leadingAnchor constraintEqualToAnchor:self.panelView.leadingAnchor constant:20.0],
        [self.launchButton.trailingAnchor constraintEqualToAnchor:self.panelView.trailingAnchor constant:-20.0],
        [self.launchButton.heightAnchor constraintEqualToConstant:52.0],
        [self.launchButton.bottomAnchor constraintEqualToAnchor:self.panelView.bottomAnchor constant:-20.0]
    ]];
}

- (void)syncUIData {
    [PLProfiles updateCurrent];
    if (PLProfiles.current.profiles.count > 0 && PLProfiles.current.selectedProfileName.length == 0) {
        PLProfiles.current.selectedProfileName = PLProfiles.current.profiles.allKeys.firstObject;
    }
    NSDictionary *profile = [PLProfiles.current selectedProfile];
    NSString *profileName = PLProfiles.current.selectedProfileName ?: @"No profile";
    NSString *versionId = profile[@"lastVersionId"] ?: @"latest-release";
    self.profileNameLabel.text = [NSString stringWithFormat:@"Profile: %@", profileName];
    self.versionLabel.text = [NSString stringWithFormat:@"Version: %@", versionId];

    NSDictionary *selected = BaseAuthenticator.current.authData;
    if (selected == nil) {
        self.usernameLabel.text = localize(@"login.option.select", nil);
        self.subtitleLabel.text = localize(@"login.option.local", nil);
        self.avatarView.image = [UIImage imageNamed:@"DefaultAccount"];
    } else {
        NSString *username = selected[@"username"] ?: @"Player";
        if ([username hasPrefix:@"Demo."]) {
            username = [username substringFromIndex:5];
        }
        self.usernameLabel.text = username;
        if (selected[@"xboxGamertag"] != nil) {
            self.subtitleLabel.text = selected[@"xboxGamertag"];
        } else if ([selected[@"username"] hasPrefix:@"Demo."]) {
            self.subtitleLabel.text = localize(@"login.option.demo", nil);
        } else {
            self.subtitleLabel.text = localize(@"login.option.local", nil);
        }

        NSString *urlString = [selected[@"profilePicURL"] stringByReplacingOccurrencesOfString:@"\\/" withString:@"/"];
        NSURL *url = [NSURL URLWithString:urlString ?: @""];
        [self.avatarView setImageWithURL:url placeholderImage:[UIImage imageNamed:@"DefaultAccount"]];
    }

    for (CALayer *layer in self.launchButton.layer.sublayers) {
        if ([layer.name isEqualToString:@"pl.zenith.launch.gradient"] && [layer isKindOfClass:CAGradientLayer.class]) {
            layer.frame = self.launchButton.bounds;
            layer.cornerRadius = self.launchButton.layer.cornerRadius;
            break;
        }
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self buildLayout];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationItem.rightBarButtonItem = [sidebarViewController drawAccountButton];
    [self syncUIData];
}

- (void)actionLaunch {
    if (PLProfiles.current.profiles.count == 0) {
        showDialog(localize(@"Error", nil), @"No profile available.");
        return;
    }

    LauncherNavigationController *nav = (LauncherNavigationController *)self.navigationController;
    NSString *profileName = PLProfiles.current.selectedProfileName ?: PLProfiles.current.profiles.allKeys.firstObject;
    if (profileName.length == 0) {
        showDialog(localize(@"Error", nil), @"Unable to resolve selected profile.");
        return;
    }

    [nav setValue:profileName forKeyPath:@"versionTextField.text"];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [nav performSelector:@selector(performInstallOrShowDetails:) withObject:self.launchButton];
#pragma clang diagnostic pop
}

- (void)actionSelectProfile {
    NSArray<NSString *> *profileNames = PLProfiles.current.profiles.allKeys;
    if (profileNames.count == 0) {
        showDialog(localize(@"Error", nil), @"No profile found.");
        return;
    }

    UIAlertController *picker = [UIAlertController alertControllerWithTitle:@"Select Profile" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSString *name in profileNames) {
        [picker addAction:[UIAlertAction actionWithTitle:name style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            PLProfiles.current.selectedProfileName = name;
            [PLProfiles.current save];
            [self syncUIData];
        }]];
    }
    [picker addAction:[UIAlertAction actionWithTitle:localize(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
    picker.popoverPresentationController.sourceView = self.selectProfileButton;
    picker.popoverPresentationController.sourceRect = self.selectProfileButton.bounds;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)actionManageProfile {
    NSMutableDictionary *profile = [PLProfiles.current selectedProfile];
    if (profile == nil) {
        showDialog(localize(@"Error", nil), @"No profile selected.");
        return;
    }
    LauncherProfileEditorViewController *vc = [LauncherProfileEditorViewController new];
    vc.profile = profile.mutableCopy;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)actionInstallJar {
    LauncherNavigationController *nav = (LauncherNavigationController *)self.navigationController;
    [nav enterModInstaller];
}

@end
