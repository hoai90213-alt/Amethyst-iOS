#import <QuartzCore/QuartzCore.h>
#import <WebKit/WebKit.h>
#import "authenticator/BaseAuthenticator.h"
#import "LauncherMenuViewController.h"
#import "LauncherNavigationController.h"
#import "LauncherPreferences.h"
#import "LauncherPrefGameDirViewController.h"
#import "LauncherProfileEditorViewController.h"
#import "LauncherProfilesViewController.h"
#import "PLProfiles.h"
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#import "UIKit+AFNetworking.h"
#pragma clang diagnostic pop
#import "UIKit+hook.h"
#import "installer/FabricInstallViewController.h"
#import "installer/ForgeInstallViewController.h"
#import "installer/ModpackInstallViewController.h"
#import "ios_uikit_bridge.h"
#import "utils.h"

typedef NS_ENUM(NSUInteger, LauncherProfilesTableSection) {
    LauncherProfilesTableSectionInstance = 0,
    LauncherProfilesTableSectionProfiles = 1
};

@interface LauncherNavigationController (LauncherProfilesBridge)
- (void)reloadProfileList;
- (void)launchMinecraft:(id)sender;
@end

@interface LauncherProfilesViewController ()

@property(nonatomic) UIBarButtonItem *createButtonItem;
@property(nonatomic) UIView *dashboardHeaderView;
@property(nonatomic) UIView *heroCardView;
@property(nonatomic) UIImageView *heroImageView;
@property(nonatomic) UILabel *heroTitleLabel;
@property(nonatomic) UILabel *heroSubtitleLabel;
@property(nonatomic) UILabel *heroMetaLabel;
@property(nonatomic) UIButton *profileButton;
@property(nonatomic) UIButton *versionButton;
@property(nonatomic) UIButton *launchButton;
@property(nonatomic) UIProgressView *launchProgressView;
@property(nonatomic) UILabel *launchStatusLabel;
@property(nonatomic) BOOL launchTaskActive;
@property(nonatomic) BOOL playMode;
@property(nonatomic) WKWebView *skinWebView;
@property(nonatomic) BOOL skinWebViewReady;
@property(nonatomic) NSString *pendingSkinURL;

@end

@implementation LauncherProfilesViewController

static UIColor *ZenithCardColor(void) {
    UIColor *base = [UIColor colorWithRed:12.0/255.0 green:19.0/255.0 blue:36.0/255.0 alpha:0.96];
    return PLThemeAccentBlendColor(base, 0.10);
}

static UIColor *ZenithBorderColor(void) {
    return [PLThemeAccentBlendColor(UIColor.whiteColor, 0.2) colorWithAlphaComponent:0.62];
}

static UIColor *ZenithAccentColor(void) {
    return PLThemeAccentResolvedColor();
}

+ (instancetype)playController {
    LauncherProfilesViewController *vc = [LauncherProfilesViewController new];
    vc.playMode = YES;
    vc.title = localize(@"Play", nil);
    return vc;
}

- (instancetype)init {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) {
        self.title = localize(@"Profiles", nil);
    }
    return self;
}

- (NSString *)imageName {
    return @"MenuProfiles";
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.rowHeight = 56.0;
    self.tableView.sectionHeaderHeight = 30.0;
    self.tableView.sectionFooterHeight = 10.0;
    self.tableView.contentInset = UIEdgeInsetsMake(0, 0, 12, 0);

    [self buildCreateButton];
    if (self.playMode) {
        self.tableView.scrollEnabled = NO;
        self.tableView.sectionHeaderHeight = 0.0;
        self.tableView.sectionFooterHeight = 0.0;
        [self buildDashboardHeader];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(handlePlayStateChanged:) name:LauncherPlayStateDidChangeNotification object:nil];
    } else {
        self.tableView.tableHeaderView = nil;
    }
}

- (void)dealloc {
    if (self.playMode) {
        [NSNotificationCenter.defaultCenter removeObserver:self name:LauncherPlayStateDidChangeNotification object:nil];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    UIBarButtonItem *accountItem = [sidebarViewController drawAccountButton];
    if (self.playMode) {
        if (accountItem != nil) {
            self.navigationItem.rightBarButtonItems = @[accountItem];
        }
    } else if (accountItem != nil && self.createButtonItem != nil) {
        self.navigationItem.rightBarButtonItems = @[accountItem, self.createButtonItem];
    } else if (self.createButtonItem != nil) {
        self.navigationItem.rightBarButtonItems = @[self.createButtonItem];
    } else if (accountItem != nil) {
        self.navigationItem.rightBarButtonItems = @[accountItem];
    }

    [PLProfiles updateCurrent];
    [self normalizeSelectedProfileIfNeeded];
    if (self.playMode) {
        [self refreshDashboardContent];
        if (!self.launchTaskActive) {
            self.launchStatusLabel.text = @"Ready";
            self.launchProgressView.hidden = YES;
            [self.launchProgressView setProgress:0.0f animated:NO];
        }
    }
    [self.tableView reloadData];

    if ([self.navigationController isKindOfClass:LauncherNavigationController.class]) {
        [(LauncherNavigationController *)self.navigationController reloadProfileList];
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if (self.playMode) {
        [self layoutDashboardHeader];
    }
}

- (void)buildCreateButton {
    __weak LauncherProfilesViewController *weakSelf = self;
    if (@available(iOS 14.0, *)) {
        UIMenu *createMenu = [UIMenu menuWithTitle:localize(@"profile.title.create", nil) image:nil identifier:nil options:UIMenuOptionsDisplayInline children:@[
            [UIAction actionWithTitle:@"Vanilla" image:nil identifier:@"vanilla" handler:^(UIAction *action) {
                (void)action;
                [weakSelf actionEditProfile:@{
                    @"name": @"",
                    @"lastVersionId": @"latest-release"
                }];
            }],
            [UIAction actionWithTitle:@"Fabric/Quilt" image:nil identifier:@"fabric_or_quilt" handler:^(UIAction *action) {
                (void)action;
                [weakSelf actionCreateFabricProfile];
            }],
            [UIAction actionWithTitle:@"Forge" image:nil identifier:@"forge" handler:^(UIAction *action) {
                (void)action;
                [weakSelf actionCreateForgeProfile];
            }],
            [UIAction actionWithTitle:@"Modpack" image:nil identifier:@"modpack" handler:^(UIAction *action) {
                (void)action;
                [weakSelf actionCreateModpackProfile];
            }]
        ]];
        self.createButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd menu:createMenu];
    } else {
        self.createButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(actionCreateVanillaProfile)];
    }
}

- (void)buildDashboardHeader {
    self.dashboardHeaderView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.tableView.bounds.size.width, 430.0)];
    self.dashboardHeaderView.backgroundColor = UIColor.clearColor;

    self.heroCardView = [[UIView alloc] initWithFrame:CGRectZero];
    self.heroCardView.backgroundColor = ZenithCardColor();
    self.heroCardView.layer.cornerRadius = 18.0;
    self.heroCardView.layer.borderWidth = 1.0;
    self.heroCardView.layer.borderColor = ZenithBorderColor().CGColor;
    self.heroCardView.layer.shadowColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:1.0].CGColor;
    self.heroCardView.layer.shadowOpacity = 0.5;
    self.heroCardView.layer.shadowOffset = CGSizeMake(0, 6);
    self.heroCardView.layer.shadowRadius = 16.0;
    if (@available(iOS 13.0, *)) {
        self.heroCardView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.dashboardHeaderView addSubview:self.heroCardView];

    self.heroImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    self.heroImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.heroImageView.layer.cornerRadius = 16.0;
    self.heroImageView.layer.borderWidth = 1.0;
    self.heroImageView.layer.borderColor = [ZenithAccentColor() colorWithAlphaComponent:0.65].CGColor;
    self.heroImageView.clipsToBounds = YES;
    self.heroImageView.hidden = YES;
    [self.heroCardView addSubview:self.heroImageView];

    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    self.skinWebView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:config];
    self.skinWebView.opaque = NO;
    self.skinWebView.backgroundColor = UIColor.clearColor;
    self.skinWebView.scrollView.scrollEnabled = NO;
    self.skinWebView.layer.cornerRadius = 16.0;
    self.skinWebView.layer.borderWidth = 1.0;
    self.skinWebView.layer.borderColor = [ZenithAccentColor() colorWithAlphaComponent:0.65].CGColor;
    self.skinWebView.clipsToBounds = YES;
    [self.heroCardView addSubview:self.skinWebView];

    [self.skinWebView loadHTMLString:[self skinViewerHTML] baseURL:nil];
    self.skinWebViewReady = NO;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.skinWebViewReady = YES;
        if (self.pendingSkinURL.length > 0) {
            [self updateSkinWebViewWithURL:self.pendingSkinURL];
        }
    });

    self.heroTitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.heroTitleLabel.font = [UIFont systemFontOfSize:20.0 weight:UIFontWeightHeavy];
    self.heroTitleLabel.textColor = UIColor.whiteColor;
    self.heroTitleLabel.numberOfLines = 1;
    self.heroTitleLabel.textAlignment = NSTextAlignmentCenter;
    [self.heroCardView addSubview:self.heroTitleLabel];

    self.heroSubtitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.heroSubtitleLabel.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold];
    self.heroSubtitleLabel.textColor = [PLThemeAccentBlendColor(UIColor.whiteColor, 0.12) colorWithAlphaComponent:0.92];
    self.heroSubtitleLabel.numberOfLines = 1;
    self.heroSubtitleLabel.textAlignment = NSTextAlignmentCenter;
    [self.heroCardView addSubview:self.heroSubtitleLabel];

    self.heroMetaLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.heroMetaLabel.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightMedium];
    self.heroMetaLabel.textColor = [UIColor colorWithWhite:0.82 alpha:1.0];
    self.heroMetaLabel.textAlignment = NSTextAlignmentCenter;
    [self.heroCardView addSubview:self.heroMetaLabel];

    self.profileButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.profileButton addTarget:self action:@selector(actionPickProfile:) forControlEvents:UIControlEventPrimaryActionTriggered];
    [self.heroCardView addSubview:self.profileButton];

    self.versionButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.versionButton addTarget:self action:@selector(actionPickVersion:) forControlEvents:UIControlEventPrimaryActionTriggered];
    [self.heroCardView addSubview:self.versionButton];

    self.launchButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.launchButton setTitle:localize(@"Play", nil) forState:UIControlStateNormal];
    [self.launchButton addTarget:self action:@selector(actionLaunchSelectedProfile:) forControlEvents:UIControlEventPrimaryActionTriggered];
    [self.heroCardView addSubview:self.launchButton];

    self.launchProgressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.launchProgressView.trackTintColor = [UIColor colorWithWhite:1.0 alpha:0.15];
    self.launchProgressView.progressTintColor = ZenithAccentColor();
    self.launchProgressView.hidden = YES;
    [self.heroCardView addSubview:self.launchProgressView];

    self.launchStatusLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.launchStatusLabel.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightMedium];
    self.launchStatusLabel.textColor = [UIColor colorWithWhite:0.86 alpha:0.9];
    self.launchStatusLabel.textAlignment = NSTextAlignmentCenter;
    self.launchStatusLabel.numberOfLines = 1;
    self.launchStatusLabel.text = @"Ready";
    [self.heroCardView addSubview:self.launchStatusLabel];

    UIButton *openProfilesButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [openProfilesButton setTitle:@"Open Profiles" forState:UIControlStateNormal];
    [openProfilesButton addTarget:self action:@selector(actionOpenProfilesScreen:) forControlEvents:UIControlEventPrimaryActionTriggered];
    openProfilesButton.tag = 99101;
    [self.heroCardView addSubview:openProfilesButton];

    self.tableView.tableHeaderView = self.dashboardHeaderView;
    [self refreshDashboardContent];
}

- (void)layoutDashboardHeader {
    if (self.dashboardHeaderView == nil) {
        return;
    }

    CGFloat tableWidth = CGRectGetWidth(self.tableView.bounds);
    if (tableWidth <= 0.0) {
        return;
    }

    CGFloat horizontalPadding = 16.0;
    CGFloat heroHeight = 408.0;
    CGFloat heroWidth = MAX(0.0, tableWidth - horizontalPadding * 2.0);

    self.dashboardHeaderView.frame = CGRectMake(0, 0, tableWidth, heroHeight + 14.0);
    self.heroCardView.frame = CGRectMake(horizontalPadding, 6.0, heroWidth, heroHeight);

    CGFloat imageSize = MIN(heroWidth - 72.0, 170.0);
    self.heroImageView.frame = CGRectMake((heroWidth - imageSize) / 2.0, 18.0, imageSize, imageSize + 24.0);
    self.skinWebView.frame = self.heroImageView.frame;

    CGFloat textWidth = MAX(120.0, heroWidth - 28.0);
    self.heroTitleLabel.frame = CGRectMake(14.0, CGRectGetMaxY(self.heroImageView.frame) + 10.0, textWidth, 24.0);
    self.heroSubtitleLabel.frame = CGRectMake(14.0, CGRectGetMaxY(self.heroTitleLabel.frame) + 2.0, textWidth, 18.0);
    self.heroMetaLabel.frame = CGRectMake(14.0, CGRectGetMaxY(self.heroSubtitleLabel.frame) + 1.0, textWidth, 17.0);

    CGFloat contentWidth = MAX(0.0, heroWidth - 32.0);
    CGFloat buttonWidth = floor((contentWidth - 8.0) / 2.0);
    self.profileButton.frame = CGRectMake(16.0, CGRectGetMaxY(self.heroMetaLabel.frame) + 10.0, buttonWidth, 34.0);
    self.versionButton.frame = CGRectMake(CGRectGetMaxX(self.profileButton.frame) + 8.0, CGRectGetMinY(self.profileButton.frame), buttonWidth, 34.0);

    self.launchButton.frame = CGRectMake(16.0, CGRectGetMaxY(self.versionButton.frame) + 10.0, contentWidth, 40.0);
    self.launchProgressView.frame = CGRectMake(16.0, CGRectGetMaxY(self.launchButton.frame) + 12.0, contentWidth, 4.0);
    self.launchStatusLabel.frame = CGRectMake(16.0, CGRectGetMaxY(self.launchProgressView.frame) + 5.0, contentWidth, 16.0);

    UIButton *openProfilesButton = [self.heroCardView viewWithTag:99101];
    openProfilesButton.frame = CGRectMake(16.0, CGRectGetMaxY(self.launchStatusLabel.frame) + 9.0, contentWidth, 30.0);

    [self styleHeroButtons];

    if (!CGSizeEqualToSize(self.tableView.tableHeaderView.frame.size, self.dashboardHeaderView.frame.size)) {
        self.tableView.tableHeaderView = self.dashboardHeaderView;
    }
}

- (void)styleHeroButtons {
    [self styleSecondaryButton:self.profileButton symbol:@"person.crop.square"];
    [self styleSecondaryButton:self.versionButton symbol:@"shippingbox"];

    self.launchButton.layer.cornerRadius = 10.0;
    self.launchButton.layer.borderWidth = 1.0;
    self.launchButton.layer.borderColor = PLThemeAccentBlendColor(UIColor.whiteColor, 0.16).CGColor;
    self.launchButton.layer.shadowColor = [ZenithAccentColor() colorWithAlphaComponent:0.55].CGColor;
    self.launchButton.layer.shadowOffset = CGSizeMake(0, 8);
    self.launchButton.layer.shadowOpacity = 0.34;
    self.launchButton.layer.shadowRadius = 14.0;
    if (@available(iOS 13.0, *)) {
        self.launchButton.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.launchButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.launchButton.titleLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightBold];

    CAGradientLayer *gradient = nil;
    for (CALayer *layer in self.launchButton.layer.sublayers) {
        if ([layer.name isEqualToString:@"zenith.launch.gradient"] && [layer isKindOfClass:CAGradientLayer.class]) {
            gradient = (CAGradientLayer *)layer;
            break;
        }
    }
    if (gradient == nil) {
        gradient = [CAGradientLayer layer];
        gradient.name = @"zenith.launch.gradient";
        gradient.startPoint = CGPointMake(0.0, 0.5);
        gradient.endPoint = CGPointMake(1.0, 0.5);
        [self.launchButton.layer insertSublayer:gradient atIndex:0];
    }
    gradient.colors = @[
        (id)PLThemeAccentBlendColor(UIColor.whiteColor, 0.16).CGColor,
        (id)PLThemeAccentBlendColor([UIColor colorWithRed:23.0/255.0 green:33.0/255.0 blue:52.0/255.0 alpha:1.0], 0.34).CGColor
    ];
    gradient.frame = self.launchButton.bounds;
    gradient.cornerRadius = self.launchButton.layer.cornerRadius;

    UIButton *openProfilesButton = [self.heroCardView viewWithTag:99101];
    [self styleSecondaryButton:openProfilesButton symbol:@"list.bullet.rectangle.portrait"];
    openProfilesButton.titleLabel.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightBold];
}

- (void)styleSecondaryButton:(UIButton *)button symbol:(NSString *)symbol {
    if (button == nil) {
        return;
    }

    if (@available(iOS 13.0, *)) {
        [button setImage:[UIImage systemImageNamed:symbol] forState:UIControlStateNormal];
        button.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
        button.imageEdgeInsets = UIEdgeInsetsMake(0, -4, 0, 0);
        button.tintColor = [UIColor colorWithWhite:0.95 alpha:1.0];
    }
    [button setTitleColor:[UIColor colorWithWhite:0.94 alpha:1.0] forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold];
    button.titleLabel.adjustsFontSizeToFitWidth = YES;
    button.titleLabel.minimumScaleFactor = 0.8;
    button.backgroundColor = [PLThemeAccentBlendColor([UIColor colorWithRed:23.0/255.0 green:37.0/255.0 blue:62.0/255.0 alpha:0.9], 0.18) colorWithAlphaComponent:0.95];
    button.layer.cornerRadius = 10.0;
    button.layer.borderWidth = 1.0;
    button.layer.borderColor = PLThemeAccentBlendColor(UIColor.whiteColor, 0.12).CGColor;
    if (@available(iOS 13.0, *)) {
        button.layer.cornerCurve = kCACornerCurveContinuous;
    }
}

- (NSString *)skinViewerHTML {
    return @"<!doctype html><html><head><meta name='viewport' content='width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no' /><style>html,body{margin:0;padding:0;width:100%;height:100%;overflow:hidden;background:transparent;}#skin_container{width:100%;height:100%;touch-action:none;}</style></head><body><canvas id='skin_container'></canvas><script src='https://unpkg.com/skinview3d@3.3.0/bundles/skinview3d.bundle.js'></script><script>let viewer=null;let controls=null;function init(){const canvas=document.getElementById('skin_container');viewer=new skinview3d.SkinViewer({canvas:canvas,width:canvas.clientWidth||260,height:canvas.clientHeight||260,skin:'https://crafatar.com/skins/8667ba71b85a4004af54457a9734eed7'});viewer.fov=60;viewer.zoom=0.78;viewer.autoRotate=true;viewer.autoRotateSpeed=0.75;controls=skinview3d.createOrbitControls(viewer);controls.enableRotate=true;controls.enableZoom=false;controls.enablePan=false;controls.rotateSpeed=0.7;window.addEventListener('resize',()=>{if(!viewer)return;viewer.width=canvas.clientWidth||260;viewer.height=canvas.clientHeight||260;});if(window.pendingSkinUrl){viewer.loadSkin(window.pendingSkinUrl);}}function updateSkin(url){window.pendingSkinUrl=url;if(!viewer)return;viewer.loadSkin(url);}init();window.updateSkin=updateSkin;</script></body></html>";
}

- (NSString *)escapedForJavaScript:(NSString *)value {
    if (![value isKindOfClass:NSString.class]) {
        return @"";
    }
    NSString *escaped = [value stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
    escaped = [escaped stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
    escaped = [escaped stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    escaped = [escaped stringByReplacingOccurrencesOfString:@"\r" withString:@""];
    return escaped;
}

- (NSString *)skinURLForCurrentAccount {
    NSDictionary *account = BaseAuthenticator.current.authData;
    NSString *profileId = [account isKindOfClass:NSDictionary.class] ? account[@"profileId"] : nil;
    if (![profileId isKindOfClass:NSString.class] || profileId.length == 0 || [profileId isEqualToString:@"00000000-0000-0000-0000-000000000000"]) {
        return @"https://crafatar.com/skins/8667ba71b85a4004af54457a9734eed7";
    }
    NSString *uuidNoDash = [[profileId stringByReplacingOccurrencesOfString:@"-" withString:@""] lowercaseString];
    if (uuidNoDash.length == 0) {
        uuidNoDash = @"8667ba71b85a4004af54457a9734eed7";
    }
    return [NSString stringWithFormat:@"https://crafatar.com/skins/%@", uuidNoDash];
}

- (void)updateSkinWebViewWithURL:(NSString *)skinURL {
    if (skinURL.length == 0) {
        return;
    }
    self.pendingSkinURL = skinURL;
    if (!self.skinWebViewReady || self.skinWebView == nil) {
        return;
    }

    NSString *escaped = [self escapedForJavaScript:skinURL];
    NSString *script = [NSString stringWithFormat:@"window.pendingSkinUrl='%@'; if(window.updateSkin){window.updateSkin(window.pendingSkinUrl);} ", escaped];
    [self.skinWebView evaluateJavaScript:script completionHandler:nil];
}

- (NSArray<NSDictionary *> *)profileEntries {
    NSMutableArray<NSDictionary *> *entries = [NSMutableArray array];
    NSDictionary *profiles = PLProfiles.current.profiles;
    [profiles enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        (void)stop;
        if (![key isKindOfClass:NSString.class] || ![obj isKindOfClass:NSDictionary.class]) {
            return;
        }
        [entries addObject:@{
            @"key": key,
            @"profile": obj
        }];
    }];

    [entries sortUsingComparator:^NSComparisonResult(NSDictionary *lhs, NSDictionary *rhs) {
        NSDictionary *lhsProfile = lhs[@"profile"];
        NSDictionary *rhsProfile = rhs[@"profile"];
        NSString *lhsName = lhsProfile[@"name"];
        NSString *rhsName = rhsProfile[@"name"];
        if (![lhsName isKindOfClass:NSString.class] || lhsName.length == 0) {
            lhsName = lhs[@"key"];
        }
        if (![rhsName isKindOfClass:NSString.class] || rhsName.length == 0) {
            rhsName = rhs[@"key"];
        }
        return [lhsName localizedCaseInsensitiveCompare:rhsName];
    }];
    return entries;
}

- (NSString *)entryKey:(NSDictionary *)entry {
    NSString *key = entry[@"key"];
    return [key isKindOfClass:NSString.class] ? key : @"";
}

- (NSDictionary *)entryProfile:(NSDictionary *)entry {
    NSDictionary *profile = entry[@"profile"];
    return [profile isKindOfClass:NSDictionary.class] ? profile : @{};
}

- (NSString *)entryDisplayName:(NSDictionary *)entry {
    NSDictionary *profile = [self entryProfile:entry];
    NSString *name = profile[@"name"];
    if (![name isKindOfClass:NSString.class] || name.length == 0) {
        name = [self entryKey:entry];
    }
    return name ?: @"";
}

- (NSDictionary *)selectedProfileEntry {
    NSArray<NSDictionary *> *entries = [self profileEntries];
    if (entries.count == 0) {
        return nil;
    }

    NSString *selectedName = PLProfiles.current.selectedProfileName;
    if (![selectedName isKindOfClass:NSString.class]) {
        selectedName = @"";
    }

    for (NSDictionary *entry in entries) {
        if ([[self entryKey:entry] isEqualToString:selectedName]) {
            return entry;
        }
    }
    for (NSDictionary *entry in entries) {
        if ([[self entryDisplayName:entry] isEqualToString:selectedName]) {
            return entry;
        }
    }
    return entries.firstObject;
}

- (void)normalizeSelectedProfileIfNeeded {
    NSDictionary *selected = [self selectedProfileEntry];
    if (selected == nil) {
        return;
    }

    NSString *key = [self entryKey:selected];
    if (key.length == 0) {
        return;
    }

    if (![PLProfiles.current.selectedProfileName isEqualToString:key]) {
        PLProfiles.current.selectedProfileName = key;
        [PLProfiles.current save];
    }
}

- (void)refreshDashboardContent {
    NSArray<NSDictionary *> *entries = [self profileEntries];
    NSDictionary *selected = [self selectedProfileEntry];

    UIImage *placeholder = [[UIImage imageNamed:@"DefaultProfile"] _imageWithSize:CGSizeMake(140, 140)];
    if (selected == nil) {
        self.heroTitleLabel.text = localize(@"profile.title.create", nil);
        self.heroSubtitleLabel.text = @"No profile selected";
        self.heroMetaLabel.text = localize(@"profile.section.profiles", nil);
        self.heroImageView.image = placeholder;
        [self.profileButton setTitle:@"Profile: -" forState:UIControlStateNormal];
        [self.versionButton setTitle:@"Version: -" forState:UIControlStateNormal];
        self.launchButton.enabled = NO;
        [self updateSkinWebViewWithURL:[self skinURLForCurrentAccount]];
        return;
    }

    NSDictionary *profile = [self entryProfile:selected];
    NSString *name = [self entryDisplayName:selected];
    NSString *version = profile[@"lastVersionId"];
    if (![version isKindOfClass:NSString.class] || version.length == 0) {
        version = @"latest-release";
    }

    self.heroTitleLabel.text = name;
    self.heroSubtitleLabel.text = @"Ready to launch";
    self.heroMetaLabel.text = [NSString stringWithFormat:@"%@: %lu", localize(@"profile.section.profiles", nil), (unsigned long)entries.count];
    [self.profileButton setTitle:[NSString stringWithFormat:@"Profile: %@", name] forState:UIControlStateNormal];
    [self.versionButton setTitle:[NSString stringWithFormat:@"Version: %@", version] forState:UIControlStateNormal];
    [self updateSkinWebViewWithURL:[self skinURLForCurrentAccount]];
    self.launchButton.enabled = YES;
}

- (void)setSelectedProfileWithEntry:(NSDictionary *)entry {
    NSString *key = [self entryKey:entry];
    if (key.length == 0) {
        return;
    }

    if (![PLProfiles.current.selectedProfileName isEqualToString:key]) {
        PLProfiles.current.selectedProfileName = key;
        [PLProfiles.current save];
    }

    if ([self.navigationController isKindOfClass:LauncherNavigationController.class]) {
        [(LauncherNavigationController *)self.navigationController reloadProfileList];
    }
}

- (NSArray<NSString *> *)versionCandidates {
    NSMutableOrderedSet<NSString *> *set = [NSMutableOrderedSet orderedSet];
    [set addObject:@"latest-release"];
    [set addObject:@"latest-snapshot"];

    for (NSDictionary *item in localVersionList ?: @[]) {
        NSString *versionId = [item isKindOfClass:NSDictionary.class] ? item[@"id"] : nil;
        if ([versionId isKindOfClass:NSString.class] && versionId.length > 0) {
            [set addObject:versionId];
        }
    }

    NSInteger releaseCount = 0;
    NSInteger snapshotCount = 0;
    for (NSDictionary *item in remoteVersionList ?: @[]) {
        if (![item isKindOfClass:NSDictionary.class]) {
            continue;
        }
        NSString *versionId = item[@"id"];
        NSString *type = item[@"type"];
        if (![versionId isKindOfClass:NSString.class] || versionId.length == 0) {
            continue;
        }

        BOOL isRelease = [type isEqualToString:@"release"];
        BOOL isSnapshot = [type isEqualToString:@"snapshot"];
        if (isRelease && releaseCount < 12) {
            [set addObject:versionId];
            releaseCount++;
        } else if (isSnapshot && snapshotCount < 8) {
            [set addObject:versionId];
            snapshotCount++;
        }
        if (releaseCount >= 12 && snapshotCount >= 8) {
            break;
        }
    }

    return set.array;
}

- (void)applyVersionId:(NSString *)versionId forEntry:(NSDictionary *)entry {
    if (![versionId isKindOfClass:NSString.class] || versionId.length == 0 || entry == nil) {
        return;
    }
    NSString *key = [self entryKey:entry];
    if (key.length == 0) {
        return;
    }

    NSDictionary *source = [self entryProfile:entry];
    NSMutableDictionary *updatedProfile = [source isKindOfClass:NSDictionary.class] ? source.mutableCopy : [NSMutableDictionary dictionary];
    updatedProfile[@"lastVersionId"] = versionId;
    if (updatedProfile[@"name"] == nil) {
        updatedProfile[@"name"] = key;
    }
    PLProfiles.current.profiles[key] = updatedProfile;
    if (![PLProfiles.current.selectedProfileName isEqualToString:key]) {
        PLProfiles.current.selectedProfileName = key;
    } else {
        [PLProfiles.current save];
    }

    [self refreshDashboardContent];
    [self.tableView reloadData];
    if ([self.navigationController isKindOfClass:LauncherNavigationController.class]) {
        [(LauncherNavigationController *)self.navigationController reloadProfileList];
    }
}

- (void)handlePlayStateChanged:(NSNotification *)notification {
    if (!self.playMode || self.launchProgressView == nil) {
        return;
    }
    NSDictionary *userInfo = notification.userInfo;
    BOOL active = [userInfo[@"active"] boolValue];
    NSString *text = [userInfo[@"text"] isKindOfClass:NSString.class] ? userInfo[@"text"] : nil;
    NSNumber *progress = [userInfo[@"progress"] isKindOfClass:NSNumber.class] ? userInfo[@"progress"] : nil;
    self.launchTaskActive = active;
    self.launchProgressView.hidden = !active;
    if (progress != nil) {
        [self.launchProgressView setProgress:progress.floatValue animated:YES];
    } else if (!active) {
        [self.launchProgressView setProgress:0.0f animated:NO];
    }
    if (text.length > 0) {
        self.launchStatusLabel.text = text;
    } else {
        self.launchStatusLabel.text = active ? @"Preparing..." : @"Ready";
    }
}

- (void)actionCreateVanillaProfile {
    [self actionEditProfile:@{
        @"name": @"",
        @"lastVersionId": @"latest-release"
    }];
}

- (void)actionTogglePrefIsolation:(UISwitch *)sender {
    if (!sender.isOn) {
        setPrefBool(@"internal.isolated", NO);
    }
    toggleIsolatedPref(sender.isOn);
}

- (void)actionCreateFabricProfile {
    [self presentNavigatedViewController:[FabricInstallViewController new]];
}

- (void)actionCreateForgeProfile {
    [self presentNavigatedViewController:[ForgeInstallViewController new]];
}

- (void)actionCreateModpackProfile {
    [self presentNavigatedViewController:[ModpackInstallViewController new]];
}

- (void)actionEditProfile:(NSDictionary *)profile {
    LauncherProfileEditorViewController *vc = [LauncherProfileEditorViewController new];
    vc.profile = profile.mutableCopy;
    [self presentNavigatedViewController:vc];
}

- (void)actionEditSelectedProfile:(id)sender {
    (void)sender;
    NSDictionary *selected = [self selectedProfileEntry];
    if (selected == nil) {
        return;
    }
    [self actionEditProfile:[self entryProfile:selected]];
}

- (void)actionPickProfile:(id)sender {
    (void)sender;
    NSArray<NSDictionary *> *entries = [self profileEntries];
    if (entries.count == 0) {
        return;
    }

    NSDictionary *selected = [self selectedProfileEntry];
    NSString *selectedKey = [self entryKey:selected];
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Select profile"
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    NSInteger maxItems = MIN((NSInteger)entries.count, 18);
    for (NSInteger i = 0; i < maxItems; i++) {
        NSDictionary *entry = entries[i];
        NSString *entryKey = [self entryKey:entry];
        NSString *entryName = [self entryDisplayName:entry];
        NSString *title = [entryKey isEqualToString:selectedKey] ? [NSString stringWithFormat:@"%@ (current)", entryName] : entryName;
        UIAlertAction *action = [UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *alertAction) {
            (void)alertAction;
            [self setSelectedProfileWithEntry:entry];
            [self refreshDashboardContent];
        }];
        [sheet addAction:action];
    }

    [sheet addAction:[UIAlertAction actionWithTitle:localize(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
    UIPopoverPresentationController *popover = sheet.popoverPresentationController;
    if (popover != nil) {
        popover.sourceView = self.profileButton;
        popover.sourceRect = self.profileButton.bounds;
    }
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)actionPickVersion:(id)sender {
    (void)sender;
    NSDictionary *selected = [self selectedProfileEntry];
    if (selected == nil) {
        return;
    }

    NSArray<NSString *> *choices = [self versionCandidates];
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Select version"
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    NSDictionary *profile = [self entryProfile:selected];
    NSString *current = [profile[@"lastVersionId"] isKindOfClass:NSString.class] ? profile[@"lastVersionId"] : @"latest-release";

    NSInteger maxItems = MIN((NSInteger)choices.count, 16);
    for (NSInteger i = 0; i < maxItems; i++) {
        NSString *versionId = choices[i];
        NSString *title = [versionId isEqualToString:current] ? [NSString stringWithFormat:@"%@ (current)", versionId] : versionId;
        UIAlertAction *action = [UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *alertAction) {
            (void)alertAction;
            [self applyVersionId:versionId forEntry:selected];
        }];
        [sheet addAction:action];
    }

    UIAlertAction *manual = [UIAlertAction actionWithTitle:@"Nhap ma version..." style:UIAlertActionStyleDefault handler:^(UIAlertAction *alertAction) {
        (void)alertAction;
        UIAlertController *input = [UIAlertController alertControllerWithTitle:@"Version ID"
                                                                       message:@"Vi du: 1.21.4, latest-release, latest-snapshot"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [input addTextFieldWithConfigurationHandler:^(UITextField *field) {
            field.autocorrectionType = UITextAutocorrectionTypeNo;
            field.autocapitalizationType = UITextAutocapitalizationTypeNone;
            field.text = current;
        }];
        [input addAction:[UIAlertAction actionWithTitle:localize(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
        [input addAction:[UIAlertAction actionWithTitle:localize(@"OK", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *saveAction) {
            (void)saveAction;
            NSString *value = [[input.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] copy];
            if (value.length > 0) {
                [self applyVersionId:value forEntry:selected];
            }
        }]];
        [self presentViewController:input animated:YES completion:nil];
    }];
    [sheet addAction:manual];
    [sheet addAction:[UIAlertAction actionWithTitle:localize(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];

    UIPopoverPresentationController *popover = sheet.popoverPresentationController;
    if (popover != nil) {
        popover.sourceView = self.versionButton;
        popover.sourceRect = self.versionButton.bounds;
    }
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)actionOpenGameDirectory:(id)sender {
    (void)sender;
    [self.navigationController pushViewController:[LauncherPrefGameDirViewController new] animated:YES];
}

- (void)actionOpenProfilesScreen:(id)sender {
    (void)sender;
    LauncherProfilesViewController *vc = [LauncherProfilesViewController new];
    vc.navigationItem.leftBarButtonItem = self.splitViewController.displayModeButtonItem;
    vc.navigationItem.leftItemsSupplementBackButton = YES;
    [self.navigationController setViewControllers:@[vc] animated:YES];
}

- (void)actionLaunchSelectedProfile:(id)sender {
    NSDictionary *selected = [self selectedProfileEntry];
    if (selected == nil) {
        return;
    }
    [self setSelectedProfileWithEntry:selected];
    self.launchStatusLabel.text = @"Preparing...";
    self.launchProgressView.hidden = NO;
    [self.launchProgressView setProgress:0.02f animated:NO];
    if ([self.navigationController isKindOfClass:LauncherNavigationController.class]) {
        LauncherNavigationController *nav = (LauncherNavigationController *)self.navigationController;
        id trigger = [sender isKindOfClass:UIButton.class] ? sender : self.launchButton;
        [nav launchMinecraft:trigger];
    }
}

- (void)presentNavigatedViewController:(UIViewController *)vc {
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    [self presentViewController:nav animated:YES completion:nil];
}

#pragma mark Table view

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    (void)tableView;
    if (self.playMode) {
        return 0;
    }
    return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    (void)tableView;
    if (self.playMode) {
        return nil;
    }
    if (section == LauncherProfilesTableSectionInstance) {
        return localize(@"profile.section.instance", nil);
    }
    return localize(@"profile.section.profiles", nil);
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView;
    if (self.playMode) {
        return 0;
    }
    if (section == LauncherProfilesTableSectionInstance) {
        return 5;
    }
    return [self profileEntries].count;
}

- (void)configureInstanceCell:(UITableViewCell *)cell atRow:(NSInteger)row {
    BOOL demoLocked = getenv("DEMO_LOCK") != NULL;
    cell.userInteractionEnabled = YES;
    cell.imageView.tintColor = [UIColor colorWithWhite:0.95 alpha:1.0];
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.accessoryView = nil;

    if (row == 0) {
        cell.userInteractionEnabled = !demoLocked;
        cell.imageView.image = [UIImage systemImageNamed:@"folder"];
        cell.textLabel.text = localize(@"preference.title.game_directory", nil);
        cell.detailTextLabel.text = demoLocked ? @".demo" : getPrefObject(@"general.game_directory");
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return;
    }

    if (row == 1) {
        cell.userInteractionEnabled = !demoLocked;
        NSString *imageName;
        if (@available(iOS 15.0, *)) {
            imageName = @"folder.badge.gearshape";
        } else {
            imageName = @"folder.badge.gear";
        }
        cell.imageView.image = [UIImage systemImageNamed:imageName];
        cell.textLabel.text = localize(@"profile.title.separate_preference", nil);
        cell.detailTextLabel.text = localize(@"profile.detail.separate_preference", nil);
        UISwitch *switchView = [UISwitch new];
        [switchView setOn:getPrefBool(@"internal.isolated") animated:NO];
        [switchView addTarget:self action:@selector(actionTogglePrefIsolation:) forControlEvents:UIControlEventValueChanged];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.accessoryView = switchView;
        return;
    }

    if (row == 2) {
        cell.imageView.image = [UIImage systemImageNamed:@"shippingbox.circle"];
        cell.textLabel.text = @"Install Fabric/Quilt";
        cell.detailTextLabel.text = @"Create profile from Fabric or Quilt loader";
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return;
    }

    if (row == 3) {
        cell.imageView.image = [UIImage systemImageNamed:@"flame.fill"];
        cell.textLabel.text = @"Install Forge";
        cell.detailTextLabel.text = @"Create profile from Minecraft Forge";
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return;
    }

    cell.imageView.image = [UIImage systemImageNamed:@"square.stack.3d.up.fill"];
    cell.textLabel.text = @"Install Modpack";
    cell.detailTextLabel.text = @"Install Modrinth/CurseForge modpack";
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
}

- (void)configureProfileCell:(UITableViewCell *)cell atRow:(NSInteger)row {
    NSArray<NSDictionary *> *entries = [self profileEntries];
    if (row < 0 || row >= entries.count) {
        return;
    }
    NSDictionary *entry = entries[row];
    NSDictionary *profile = [self entryProfile:entry];

    cell.textLabel.text = [self entryDisplayName:entry];
    NSString *version = profile[@"lastVersionId"];
    cell.detailTextLabel.text = ([version isKindOfClass:NSString.class] && version.length > 0) ? version : @"latest-release";
    cell.imageView.layer.magnificationFilter = kCAFilterNearest;
    cell.imageView.layer.minificationFilter = kCAFilterNearest;
    cell.imageView.isSizeFixed = YES;

    UIImage *fallbackImage = [[UIImage imageNamed:@"DefaultProfile"] _imageWithSize:CGSizeMake(40, 40)];
    NSString *iconURL = profile[@"icon"];
    if ([iconURL isKindOfClass:NSString.class] && iconURL.length > 0) {
        [cell.imageView setImageWithURL:[NSURL URLWithString:iconURL] placeholderImage:fallbackImage];
    } else {
        cell.imageView.image = fallbackImage;
    }

    cell.accessoryType = UITableViewCellAccessoryNone;
    if ([[self entryKey:entry] isEqualToString:PLProfiles.current.selectedProfileName] ||
        [[self entryDisplayName:entry] isEqualToString:PLProfiles.current.selectedProfileName]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *cellID = (indexPath.section == LauncherProfilesTableSectionInstance) ? @"InstanceCell" : @"ProfileCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellID];
    } else {
        cell.imageView.image = nil;
    }

    cell.textLabel.numberOfLines = 1;
    cell.textLabel.textColor = UIColor.whiteColor;
    cell.textLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    cell.detailTextLabel.numberOfLines = 2;
    cell.detailTextLabel.textColor = [UIColor colorWithWhite:0.84 alpha:1.0];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightMedium];
    cell.accessoryView = nil;
    cell.userInteractionEnabled = YES;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    cell.accessoryType = UITableViewCellAccessoryNone;

    if (indexPath.section == LauncherProfilesTableSectionInstance) {
        [self configureInstanceCell:cell atRow:indexPath.row];
    } else {
        [self configureProfileCell:cell atRow:indexPath.row];
    }

    cell.textLabel.enabled = cell.detailTextLabel.enabled = cell.userInteractionEnabled;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == LauncherProfilesTableSectionInstance) {
        if (indexPath.row == 0) {
            [self.navigationController pushViewController:[LauncherPrefGameDirViewController new] animated:YES];
        } else if (indexPath.row == 2) {
            [self actionCreateFabricProfile];
        } else if (indexPath.row == 3) {
            [self actionCreateForgeProfile];
        } else if (indexPath.row == 4) {
            [self actionCreateModpackProfile];
        }
        return;
    }

    NSArray<NSDictionary *> *entries = [self profileEntries];
    if (indexPath.row < 0 || indexPath.row >= entries.count) {
        return;
    }
    [self setSelectedProfileWithEntry:entries[indexPath.row]];
    [self refreshDashboardContent];
    [self.tableView reloadData];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    (void)tableView;
    if (editingStyle != UITableViewCellEditingStyleDelete || indexPath.section != LauncherProfilesTableSectionProfiles) {
        return;
    }

    NSArray<NSDictionary *> *entries = [self profileEntries];
    if (indexPath.row < 0 || indexPath.row >= entries.count) {
        return;
    }
    NSDictionary *entry = entries[indexPath.row];
    NSString *profileKey = [self entryKey:entry];
    NSString *profileName = [self entryDisplayName:entry];

    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
    NSString *title = localize(@"preference.title.confirm", nil);
    NSString *message = [NSString stringWithFormat:localize(@"preference.title.confirm.delete_runtime", nil), profileName];
    UIAlertController *confirmAlert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleActionSheet];
    confirmAlert.popoverPresentationController.sourceView = cell;
    confirmAlert.popoverPresentationController.sourceRect = cell.bounds;

    __weak LauncherProfilesViewController *weakSelf = self;
    UIAlertAction *ok = [UIAlertAction actionWithTitle:localize(@"OK", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        (void)action;
        [PLProfiles.current.profiles removeObjectForKey:profileKey];
        if ([PLProfiles.current.selectedProfileName isEqualToString:profileKey] ||
            [PLProfiles.current.selectedProfileName isEqualToString:profileName]) {
            NSString *fallback = PLProfiles.current.profiles.allKeys.firstObject;
            PLProfiles.current.selectedProfileName = fallback ?: @"";
            if ([weakSelf.navigationController isKindOfClass:LauncherNavigationController.class]) {
                [(LauncherNavigationController *)weakSelf.navigationController reloadProfileList];
            }
        } else {
            [PLProfiles.current save];
        }
        [weakSelf refreshDashboardContent];
        [weakSelf.tableView reloadData];
    }];
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:localize(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil];
    [confirmAlert addAction:cancel];
    [confirmAlert addAction:ok];
    [self presentViewController:confirmAlert animated:YES completion:nil];
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    (void)tableView;
    if (indexPath.section == LauncherProfilesTableSectionInstance || PLProfiles.current.profiles.count <= 1) {
        return UITableViewCellEditingStyleNone;
    }
    return UITableViewCellEditingStyleDelete;
}

@end
