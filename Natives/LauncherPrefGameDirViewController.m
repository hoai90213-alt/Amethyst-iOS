#import "LauncherNavigationController.h"
#import "LauncherPreferences.h"
#import "LauncherPrefGameDirViewController.h"
#import "NSFileManager+NRFileManager.h"
#import "PLProfiles.h"
#import "ios_uikit_bridge.h"
#import "utils.h"

@interface LauncherPrefGameDirViewController ()<UITextFieldDelegate>
@property(nonatomic) NSMutableArray *array;
@property(nonatomic) UITextField *footerInputField;
@end

@implementation LauncherPrefGameDirViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setTitle:localize(@"preference.title.game_directory", nil)];

    self.array = [[NSMutableArray alloc] init];
    [self.array addObject:@"default"];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    self.tableView.sectionFooterHeight = 58.0;
    self.tableView.rowHeight = 58.0;
    self.tableView.estimatedRowHeight = 58.0;

    NSString *path = [NSString stringWithFormat:@"%s/instances", getenv("POJAV_HOME")];

    NSFileManager *fm = NSFileManager.defaultManager;
    NSArray *files = [fm contentsOfDirectoryAtPath:path error:nil];
    for (NSString *file in files) {
        BOOL isDir = NO;
        NSString *fullPath = [path stringByAppendingPathComponent:file];
        [fm fileExistsAtPath:fullPath isDirectory:&isDir];
        if (isDir && ![file isEqualToString:@"default"]) {
            [self.array addObject:file];
        }
    }
    [self.array sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    if ([self.array containsObject:@"default"]) {
        [self.array removeObject:@"default"];
    }
    [self.array insertObject:@"default" atIndex:0];
}

- (void)changeSelectionTo:(NSString *)name {
    if (getenv("DEMO_LOCK")) return;

    setPrefObject(@"general.game_directory", name);
    NSString *multidirPath = [NSString stringWithFormat:@"%s/instances/%@", getenv("POJAV_HOME"), name];
    NSString *lasmPath = @(getenv("POJAV_GAME_DIR"));
    [NSFileManager.defaultManager removeItemAtPath:lasmPath error:nil];
    [NSFileManager.defaultManager createSymbolicLinkAtPath:lasmPath withDestinationPath:multidirPath error:nil];
    [NSFileManager.defaultManager changeCurrentDirectoryPath:lasmPath];
    toggleIsolatedPref(NO);
    [self.navigationController performSelector:@selector(reloadProfileList)];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.array.count;
}

- (UITableViewCell *)tableView:(nonnull UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"];
        cell.textLabel.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightRegular];
        cell.detailTextLabel.textColor = [UIColor colorWithWhite:0.82 alpha:1.0];
        cell.textLabel.numberOfLines = 1;
        cell.detailTextLabel.numberOfLines = 1;
    }
    NSString *directoryName = self.array[indexPath.row];
    cell.textLabel.text = directoryName;
    cell.detailTextLabel.text = @"...";
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;

    // Calculate the instance size
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        unsigned long long folderSize = 0;
        NSString *directory = [NSString stringWithFormat:@"%s/instances/%@", getenv("POJAV_HOME"), directoryName];
        [NSFileManager.defaultManager nr_getAllocatedSize:&folderSize ofDirectoryAtURL:[NSURL fileURLWithPath:directory] error:nil];
        dispatch_async(dispatch_get_main_queue(), ^{
            UITableViewCell *target = [tableView cellForRowAtIndexPath:indexPath];
            if (target != nil && [target.textLabel.text isEqualToString:directoryName]) {
                target.detailTextLabel.text = [NSByteCountFormatter stringFromByteCount:folderSize countStyle:NSByteCountFormatterCountStyleMemory];
            }
        });
    });

    if ([getPrefObject(@"general.game_directory") isEqualToString:directoryName]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    }
    
    return cell;
}

- (UIView *)tableView:(UITableView *)tableView 
viewForFooterInSection:(NSInteger)section
{
    (void)tableView;
    (void)section;
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.tableView.bounds.size.width, 58.0)];
    UITextField *view = [[UITextField alloc] initWithFrame:CGRectInset(container.bounds, 0, 8.0)];
    [view addTarget:view action:@selector(resignFirstResponder) forControlEvents:UIControlEventEditingDidEndOnExit];
    view.autocorrectionType = UITextAutocorrectionTypeNo;
    view.autocapitalizationType = UITextAutocapitalizationTypeNone;
    view.delegate = self;
    view.placeholder = localize(@"preference.multidir.add_directory", nil);
    view.returnKeyType = UIReturnKeyDone;
    self.footerInputField = view;
    [container addSubview:view];
    return container;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self changeSelectionTo:self.array[indexPath.row]];
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    for (int i = 0; i < self.array.count; i++) {
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0]];
        if (i == indexPath.row) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        } else {
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
    }
}

- (id)createOpenScheme:(NSString *)scheme at:(NSString *)directory {
    return ^(UIAction *action) {
        [UIApplication.sharedApplication
            openURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@://%@", scheme, directory]]
            options:@{} completionHandler:nil];
    };
}

- (UIContextMenuConfiguration *)tableView:(UITableView *)tableView contextMenuConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath point:(CGPoint)point 
{
    NSArray *menuItems;
    NSMutableArray *openItems = [[NSMutableArray alloc] init];

    NSString *directory = [NSString stringWithFormat:@"%s/instances/%@", getenv("POJAV_HOME"), self.array[indexPath.row]];
    NSDictionary *apps = @{
        @"shareddocuments": @"Files",
        @"filza": @"Filza",
        @"santander": @"Santander",
    };
    for (NSString *key in apps.allKeys) {
        NSString *url = [NSString stringWithFormat:@"%@://", key];
        if ([UIApplication.sharedApplication canOpenURL:[NSURL URLWithString:url]]) {
            [openItems addObject:[UIAction
                actionWithTitle:apps[key]
                image:nil
                identifier:nil
                handler:[self createOpenScheme:key at:directory]]];
        }
    }
    UIMenu *open = [UIMenu
        menuWithTitle:@""
        image:nil
        identifier:nil
        options:UIMenuOptionsDisplayInline
        children:openItems];

    if (indexPath.row == 0) {
        // You can't delete or rename the default instance, though there will be a reset action (TODO)
        menuItems = @[open];
    } else {
        UIAction *rename = [UIAction
            actionWithTitle:localize(@"Rename", nil)
            image:[UIImage systemImageNamed:@"pencil"]
            identifier:nil
            handler:^(UIAction *action) {
                (void)action;
                [self promptRenameAtIndexPath:indexPath];
            }
        ];

        UIAction *delete = [UIAction
            actionWithTitle:localize(@"Delete", nil)
            image:[UIImage systemImageNamed:@"trash"]
            identifier:nil
            handler:^(UIAction *action) {
                [self actionDeleteAtIndexPath:indexPath];
            }
        ];
        delete.attributes = UIMenuElementAttributesDestructive;

        menuItems = @[open, rename, delete];
    }

    return [UIContextMenuConfiguration
        configurationWithIdentifier:nil
        previewProvider:nil
        actionProvider:^UIMenu *(NSArray<UIMenuElement *> *suggestedActions) {
            return [UIMenu menuWithTitle:self.array[indexPath.row] children:menuItems];
        }
    ];
}

- (void)promptRenameAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row <= 0 || indexPath.row >= self.array.count) {
        return;
    }
    NSString *currentName = self.array[indexPath.row];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:localize(@"Rename", nil)
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.autocorrectionType = UITextAutocorrectionTypeNo;
        field.autocapitalizationType = UITextAutocapitalizationTypeNone;
        field.returnKeyType = UIReturnKeyDone;
        field.text = currentName;
    }];

    [alert addAction:[UIAlertAction actionWithTitle:localize(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:localize(@"OK", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        (void)action;
        NSString *newName = [[alert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] copy];
        if (newName.length == 0 || [newName isEqualToString:currentName]) {
            return;
        }

        NSString *source = [NSString stringWithFormat:@"%s/instances/%@", getenv("POJAV_HOME"), currentName];
        NSString *dest = [NSString stringWithFormat:@"%s/instances/%@", getenv("POJAV_HOME"), newName];
        NSError *error = nil;
        [NSFileManager.defaultManager moveItemAtPath:source toPath:dest error:&error];
        if (error != nil) {
            showDialog(localize(@"Error", nil), error.localizedDescription);
            return;
        }
        self.array[indexPath.row] = newName;
        [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        if ([getPrefObject(@"general.game_directory") isEqualToString:currentName]) {
            [self changeSelectionTo:newName];
        }
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [self actionDeleteAtIndexPath:indexPath];
    }
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row == 0) {
        // TODO: Reset action?
        return UITableViewCellEditingStyleNone;
    } else {
        return UITableViewCellEditingStyleDelete;
    }
}

- (void)actionDeleteAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *view = [self.tableView cellForRowAtIndexPath:indexPath];
    NSString *title = localize(@"preference.title.confirm", nil);
    NSString *message = [NSString stringWithFormat:localize(@"preference.title.confirm.delete_game_directory", nil), self.array[indexPath.row]];
    UIAlertController *confirmAlert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleActionSheet];
    confirmAlert.popoverPresentationController.sourceView = view;
    confirmAlert.popoverPresentationController.sourceRect = view.bounds;
    UIAlertAction *ok = [UIAlertAction actionWithTitle:localize(@"OK", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        NSString *directory = [NSString stringWithFormat:@"%s/instances/%@", getenv("POJAV_HOME"), self.array[indexPath.row]];
        NSError *error;
        if([NSFileManager.defaultManager removeItemAtPath:directory error:&error]) {
            if ([getPrefObject(@"general.game_directory") isEqualToString:self.array[indexPath.row]]) {
                [self changeSelectionTo:self.array[0]];
                [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]].accessoryType = UITableViewCellAccessoryCheckmark;
            }
            [self.array removeObjectAtIndex:indexPath.row];
            [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        } else {
            showDialog(localize(@"Error", nil), error.localizedDescription);
        }
    }];
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:localize(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil];
    [confirmAlert addAction:cancel];
    [confirmAlert addAction:ok];
    [self presentViewController:confirmAlert animated:YES completion:nil];
}

- (void) dismissModalViewController {
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark UITextField

- (void)textFieldDidEndEditing:(UITextField *)sender {
    if (sender != self.footerInputField) {
        return;
    }

    NSString *name = [[sender.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] copy];
    if (name.length == 0) {
        sender.text = @"";
        return;
    }

    if ([self.array containsObject:name]) {
        sender.text = @"";
        showDialog(localize(@"Error", nil), @"Directory already exists.");
        return;
    }

    NSError *error;
    NSString *dest = [NSString stringWithFormat:@"%s/instances/%@", getenv("POJAV_HOME"), name];
    [NSFileManager.defaultManager createDirectoryAtPath:dest withIntermediateDirectories:NO attributes:nil error:&error];

    if (error == nil) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:self.array.count inSection:0];
        [self.array addObject:name];
        [self.tableView beginUpdates];
        [self.tableView insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        [self.tableView endUpdates];
        [self changeSelectionTo:name];
        [self tableView:self.tableView didSelectRowAtIndexPath:indexPath];
        sender.text = @"";
    } else {
        sender.text = @"";
        showDialog(localize(@"Error", nil), error.localizedDescription);
    }
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    (void)textField;
    (void)range;
    (void)string;
    return YES;
}

@end
