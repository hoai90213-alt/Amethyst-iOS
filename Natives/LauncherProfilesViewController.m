#import <QuartzCore/QuartzCore.h>
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
@property(nonatomic) UIButton *launchButton;
@property(nonatomic) UIButton *editButton;
@property(nonatomic) UIButton *directoryButton;

@end

@implementation LauncherProfilesViewController

static UIColor *ZenithCardColor(void) {
    return [UIColor colorWithRed:12.0/255.0 green:19.0/255.0 blue:36.0/255.0 alpha:0.96];
}

static UIColor *ZenithBorderColor(void) {
    return [UIColor colorWithRed:72.0/255.0 green:114.0/255.0 blue:170.0/255.0 alpha:0.65];
}

static UIColor *ZenithAccentColor(void) {
    return [UIColor colorWithRed:41.0/255.0 green:206.0/255.0 blue:255.0/255.0 alpha:1.0];
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
    self.tableView.rowHeight = 68.0;
    self.tableView.sectionHeaderHeight = 38.0;
    self.tableView.sectionFooterHeight = 18.0;
    self.tableView.contentInset = UIEdgeInsetsMake(0, 0, 24, 0);

    [self buildCreateButton];
    [self buildDashboardHeader];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    UIBarButtonItem *accountItem = [sidebarViewController drawAccountButton];
    if (accountItem != nil && self.createButtonItem != nil) {
        self.navigationItem.rightBarButtonItems = @[accountItem, self.createButtonItem];
    } else if (self.createButtonItem != nil) {
        self.navigationItem.rightBarButtonItems = @[self.createButtonItem];
    } else if (accountItem != nil) {
        self.navigationItem.rightBarButtonItems = @[accountItem];
    }

    [PLProfiles updateCurrent];
    [self normalizeSelectedProfileIfNeeded];
    [self refreshDashboardContent];
    [self.tableView reloadData];

    if ([self.navigationController isKindOfClass:LauncherNavigationController.class]) {
        [(LauncherNavigationController *)self.navigationController reloadProfileList];
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self layoutDashboardHeader];
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
    self.dashboardHeaderView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.tableView.bounds.size.width, 292.0)];
    self.dashboardHeaderView.backgroundColor = UIColor.clearColor;

    self.heroCardView = [[UIView alloc] initWithFrame:CGRectZero];
    self.heroCardView.backgroundColor = ZenithCardColor();
    self.heroCardView.layer.cornerRadius = 22.0;
    self.heroCardView.layer.borderWidth = 1.0;
    self.heroCardView.layer.borderColor = ZenithBorderColor().CGColor;
    self.heroCardView.layer.shadowColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:1.0].CGColor;
    self.heroCardView.layer.shadowOpacity = 0.5;
    self.heroCardView.layer.shadowOffset = CGSizeMake(0, 10);
    self.heroCardView.layer.shadowRadius = 22.0;
    if (@available(iOS 13.0, *)) {
        self.heroCardView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.dashboardHeaderView addSubview:self.heroCardView];

    self.heroImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    self.heroImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.heroImageView.layer.cornerRadius = 18.0;
    self.heroImageView.layer.borderWidth = 1.0;
    self.heroImageView.layer.borderColor = [ZenithAccentColor() colorWithAlphaComponent:0.65].CGColor;
    self.heroImageView.clipsToBounds = YES;
    [self.heroCardView addSubview:self.heroImageView];

    self.heroTitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.heroTitleLabel.font = [UIFont systemFontOfSize:26.0 weight:UIFontWeightHeavy];
    self.heroTitleLabel.textColor = UIColor.whiteColor;
    self.heroTitleLabel.numberOfLines = 2;
    [self.heroCardView addSubview:self.heroTitleLabel];

    self.heroSubtitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.heroSubtitleLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    self.heroSubtitleLabel.textColor = [UIColor colorWithRed:177.0/255.0 green:226.0/255.0 blue:1.0 alpha:1.0];
    self.heroSubtitleLabel.numberOfLines = 1;
    [self.heroCardView addSubview:self.heroSubtitleLabel];

    self.heroMetaLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.heroMetaLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium];
    self.heroMetaLabel.textColor = [UIColor colorWithWhite:0.82 alpha:1.0];
    [self.heroCardView addSubview:self.heroMetaLabel];

    self.launchButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.launchButton setTitle:localize(@"Play", nil) forState:UIControlStateNormal];
    [self.launchButton addTarget:self action:@selector(actionLaunchSelectedProfile:) forControlEvents:UIControlEventPrimaryActionTriggered];
    [self.heroCardView addSubview:self.launchButton];

    self.editButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.editButton setTitle:@"Edit" forState:UIControlStateNormal];
    [self.editButton addTarget:self action:@selector(actionEditSelectedProfile:) forControlEvents:UIControlEventPrimaryActionTriggered];
    [self.heroCardView addSubview:self.editButton];

    self.directoryButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.directoryButton setTitle:@"Directory" forState:UIControlStateNormal];
    [self.directoryButton addTarget:self action:@selector(actionOpenGameDirectory:) forControlEvents:UIControlEventPrimaryActionTriggered];
    [self.heroCardView addSubview:self.directoryButton];

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
    CGFloat heroHeight = 270.0;
    CGFloat heroWidth = MAX(0.0, tableWidth - horizontalPadding * 2.0);

    self.dashboardHeaderView.frame = CGRectMake(0, 0, tableWidth, heroHeight + 16.0);
    self.heroCardView.frame = CGRectMake(horizontalPadding, 8.0, heroWidth, heroHeight);

    self.heroImageView.frame = CGRectMake(16.0, 18.0, 82.0, 82.0);

    CGFloat titleX = CGRectGetMaxX(self.heroImageView.frame) + 14.0;
    CGFloat textWidth = MAX(80.0, heroWidth - titleX - 14.0);
    self.heroTitleLabel.frame = CGRectMake(titleX, 18.0, textWidth, 58.0);
    self.heroSubtitleLabel.frame = CGRectMake(titleX, 79.0, textWidth, 18.0);
    self.heroMetaLabel.frame = CGRectMake(titleX, 102.0, textWidth, 18.0);

    CGFloat controlY = heroHeight - 58.0;
    CGFloat contentWidth = MAX(0.0, heroWidth - 32.0);
    CGFloat launchWidth = floor(contentWidth * 0.52);
    CGFloat sideWidth = floor((contentWidth - launchWidth - 16.0) / 2.0);
    CGFloat minSideWidth = 84.0;
    if (sideWidth < minSideWidth) {
        sideWidth = minSideWidth;
        launchWidth = MAX(120.0, contentWidth - (sideWidth * 2.0) - 16.0);
    }

    self.launchButton.frame = CGRectMake(16.0, controlY, launchWidth, 44.0);
    self.editButton.frame = CGRectMake(CGRectGetMaxX(self.launchButton.frame) + 8.0, controlY, sideWidth, 44.0);
    self.directoryButton.frame = CGRectMake(CGRectGetMaxX(self.editButton.frame) + 8.0, controlY, sideWidth, 44.0);

    [self styleHeroButtons];

    if (!CGSizeEqualToSize(self.tableView.tableHeaderView.frame.size, self.dashboardHeaderView.frame.size)) {
        self.tableView.tableHeaderView = self.dashboardHeaderView;
    }
}

- (void)styleHeroButtons {
    [self styleSecondaryButton:self.editButton symbol:@"square.and.pencil"];
    [self styleSecondaryButton:self.directoryButton symbol:@"folder"];

    self.launchButton.layer.cornerRadius = 12.0;
    self.launchButton.layer.borderWidth = 1.0;
    self.launchButton.layer.borderColor = [UIColor colorWithRed:110.0/255.0 green:224.0/255.0 blue:1.0 alpha:0.8].CGColor;
    self.launchButton.layer.shadowColor = [ZenithAccentColor() colorWithAlphaComponent:0.55].CGColor;
    self.launchButton.layer.shadowOffset = CGSizeMake(0, 8);
    self.launchButton.layer.shadowOpacity = 0.34;
    self.launchButton.layer.shadowRadius = 14.0;
    if (@available(iOS 13.0, *)) {
        self.launchButton.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.launchButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.launchButton.titleLabel.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightBold];

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
        gradient.colors = @[
            (id)[UIColor colorWithRed:38.0/255.0 green:192.0/255.0 blue:1.0 alpha:1.0].CGColor,
            (id)[UIColor colorWithRed:59.0/255.0 green:111.0/255.0 blue:1.0 alpha:1.0].CGColor
        ];
        [self.launchButton.layer insertSublayer:gradient atIndex:0];
    }
    gradient.frame = self.launchButton.bounds;
    gradient.cornerRadius = self.launchButton.layer.cornerRadius;
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
    button.titleLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    button.backgroundColor = [UIColor colorWithRed:23.0/255.0 green:37.0/255.0 blue:62.0/255.0 alpha:0.9];
    button.layer.cornerRadius = 12.0;
    button.layer.borderWidth = 1.0;
    button.layer.borderColor = [UIColor colorWithRed:84.0/255.0 green:133.0/255.0 blue:1.0 alpha:0.45].CGColor;
    if (@available(iOS 13.0, *)) {
        button.layer.cornerCurve = kCACornerCurveContinuous;
    }
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

    UIImage *placeholder = [[UIImage imageNamed:@"DefaultProfile"] _imageWithSize:CGSizeMake(84, 84)];
    if (selected == nil) {
        self.heroTitleLabel.text = localize(@"profile.title.create", nil);
        self.heroSubtitleLabel.text = @"No profile selected";
        self.heroMetaLabel.text = localize(@"profile.section.profiles", nil);
        self.heroImageView.image = placeholder;
        self.launchButton.enabled = NO;
        self.editButton.enabled = NO;
        return;
    }

    NSDictionary *profile = [self entryProfile:selected];
    NSString *name = [self entryDisplayName:selected];
    NSString *version = profile[@"lastVersionId"];
    if (![version isKindOfClass:NSString.class] || version.length == 0) {
        version = @"latest-release";
    }

    self.heroTitleLabel.text = name;
    self.heroSubtitleLabel.text = [NSString stringWithFormat:@"Version: %@", version];
    self.heroMetaLabel.text = [NSString stringWithFormat:@"%@: %lu", localize(@"profile.section.profiles", nil), (unsigned long)entries.count];

    NSString *iconURLString = profile[@"icon"];
    if ([iconURLString isKindOfClass:NSString.class] && iconURLString.length > 0) {
        [self.heroImageView setImageWithURL:[NSURL URLWithString:iconURLString] placeholderImage:placeholder];
    } else {
        self.heroImageView.image = placeholder;
    }

    self.launchButton.enabled = YES;
    self.editButton.enabled = YES;
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

- (void)actionOpenGameDirectory:(id)sender {
    (void)sender;
    [self.navigationController pushViewController:[LauncherPrefGameDirViewController new] animated:YES];
}

- (void)actionLaunchSelectedProfile:(id)sender {
    NSDictionary *selected = [self selectedProfileEntry];
    if (selected == nil) {
        return;
    }
    [self setSelectedProfileWithEntry:selected];
    if ([self.navigationController isKindOfClass:LauncherNavigationController.class]) {
        LauncherNavigationController *nav = (LauncherNavigationController *)self.navigationController;
        [nav launchMinecraft:sender];
    }
}

- (void)presentNavigatedViewController:(UIViewController *)vc {
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    [self presentViewController:nav animated:YES completion:nil];
}

#pragma mark Table view

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    (void)tableView;
    return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    (void)tableView;
    if (section == LauncherProfilesTableSectionInstance) {
        return localize(@"profile.section.instance", nil);
    }
    return localize(@"profile.section.profiles", nil);
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView;
    if (section == LauncherProfilesTableSectionInstance) {
        return 2;
    }
    return [self profileEntries].count;
}

- (void)configureInstanceCell:(UITableViewCell *)cell atRow:(NSInteger)row {
    cell.userInteractionEnabled = !getenv("DEMO_LOCK");
    cell.imageView.tintColor = [UIColor colorWithWhite:0.95 alpha:1.0];
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.accessoryView = nil;

    if (row == 0) {
        cell.imageView.image = [UIImage systemImageNamed:@"folder"];
        cell.textLabel.text = localize(@"preference.title.game_directory", nil);
        cell.detailTextLabel.text = getenv("DEMO_LOCK") ? @".demo" : getPrefObject(@"general.game_directory");
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return;
    }

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
    cell.textLabel.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
    cell.detailTextLabel.numberOfLines = 2;
    cell.detailTextLabel.textColor = [UIColor colorWithWhite:0.84 alpha:1.0];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium];
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
