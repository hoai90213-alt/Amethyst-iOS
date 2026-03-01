#import <UIKit/UIKit.h>

NSMutableArray<NSDictionary *> *localVersionList, *remoteVersionList;
FOUNDATION_EXPORT NSString * const LauncherPlayStateDidChangeNotification;

@interface LauncherNavigationController : UINavigationController

@property(nonatomic) UIProgressView *progressViewMain, *progressViewSub;
@property(nonatomic) UILabel* progressText;

- (void)enterModInstallerWithPath:(NSString *)path hitEnterAfterWindowShown:(BOOL)hitEnter;
- (void)fetchLocalVersionList;
- (void)setInteractionEnabled:(BOOL)enable forDownloading:(BOOL)downloading;
- (void)reloadProfileList;
- (void)launchMinecraft:(id)sender;
- (NSString *)selectedProfileKey;
- (NSDictionary *)selectedProfileDictionary;

@end
