#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>
#import "LauncherPreferences.h"
#import "UIKit+hook.h"
#import "utils.h"

__weak UIWindow *mainWindow, *externalWindow;

static void *kThemeBackgroundViewKey = &kThemeBackgroundViewKey;
static void *kThemeTextFieldStyledKey = &kThemeTextFieldStyledKey;
static void *kThemeButtonStyledKey = &kThemeButtonStyledKey;
static void *kThemeCellBackgroundKey = &kThemeCellBackgroundKey;
static void *kThemeCellSelectedKey = &kThemeCellSelectedKey;

@interface PLThemeBackgroundView : UIView
@property(nonatomic) CAGradientLayer *gradientLayer;
@property(nonatomic) CAGradientLayer *glowLayer;
@end

@interface UIViewController(theme)
- (void)hook_viewDidLoad;
- (void)hook_viewDidLayoutSubviews;
@end

@interface UITableViewCell(theme)
- (void)hook_layoutSubviews;
@end

static UIColor *PLThemeAccentColor(void) {
    static UIColor *fallbackColor = nil;
    if (fallbackColor == nil) {
        fallbackColor = [UIColor colorWithRed:19.0/255.0 green:212.0/255.0 blue:1.0 alpha:1.0];
    }

    NSString *hex = getPrefObject(@"general.theme_accent_hex");
    if (![hex isKindOfClass:NSString.class]) {
        return fallbackColor;
    }

    NSString *sanitized = [[hex stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] uppercaseString];
    if ([sanitized hasPrefix:@"#"]) {
        sanitized = [sanitized substringFromIndex:1];
    }
    if (sanitized.length != 6 && sanitized.length != 8) {
        return fallbackColor;
    }

    NSCharacterSet *hexCharset = [NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEF"];
    if ([[sanitized stringByTrimmingCharactersInSet:hexCharset] length] > 0) {
        return fallbackColor;
    }

    unsigned long long hexValue = 0;
    NSScanner *scanner = [NSScanner scannerWithString:sanitized];
    if (![scanner scanHexLongLong:&hexValue]) {
        return fallbackColor;
    }

    CGFloat red;
    CGFloat green;
    CGFloat blue;
    CGFloat alpha = 1.0;
    if (sanitized.length == 8) {
        red = ((hexValue >> 24) & 0xFF) / 255.0;
        green = ((hexValue >> 16) & 0xFF) / 255.0;
        blue = ((hexValue >> 8) & 0xFF) / 255.0;
        alpha = (hexValue & 0xFF) / 255.0;
    } else {
        red = ((hexValue >> 16) & 0xFF) / 255.0;
        green = ((hexValue >> 8) & 0xFF) / 255.0;
        blue = (hexValue & 0xFF) / 255.0;
    }
    return [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
}

static UIColor *PLThemeBlendColor(UIColor *base, UIColor *target, CGFloat ratio) {
    CGFloat baseR = 0.0, baseG = 0.0, baseB = 0.0, baseA = 1.0;
    CGFloat targetR = 0.0, targetG = 0.0, targetB = 0.0, targetA = 1.0;
    if (![base getRed:&baseR green:&baseG blue:&baseB alpha:&baseA]) {
        return base;
    }
    if (![target getRed:&targetR green:&targetG blue:&targetB alpha:&targetA]) {
        return base;
    }
    ratio = MAX(0.0, MIN(1.0, ratio));
    return [UIColor colorWithRed:(baseR + (targetR - baseR) * ratio)
                           green:(baseG + (targetG - baseG) * ratio)
                            blue:(baseB + (targetB - baseB) * ratio)
                           alpha:(baseA + (targetA - baseA) * ratio)];
}

static UIColor *PLThemeBackgroundStart(UITraitCollection *__unused traits) {
    UIColor *base = [UIColor colorWithRed:7.0/255.0 green:12.0/255.0 blue:24.0/255.0 alpha:1.0];
    return PLThemeBlendColor(base, PLThemeAccentColor(), 0.08);
}

static UIColor *PLThemeBackgroundEnd(UITraitCollection *__unused traits) {
    UIColor *base = [UIColor colorWithRed:17.0/255.0 green:27.0/255.0 blue:49.0/255.0 alpha:1.0];
    return PLThemeBlendColor(base, PLThemeAccentColor(), 0.20);
}

static UIColor *PLThemeBackgroundMid(UITraitCollection *__unused traits) {
    UIColor *base = [UIColor colorWithRed:12.0/255.0 green:20.0/255.0 blue:38.0/255.0 alpha:1.0];
    return PLThemeBlendColor(base, PLThemeAccentColor(), 0.14);
}

static UIColor *PLThemeCardColor(UITraitCollection *__unused traits) {
    UIColor *base = [UIColor colorWithRed:18.0/255.0 green:29.0/255.0 blue:50.0/255.0 alpha:0.94];
    return PLThemeBlendColor(base, PLThemeAccentColor(), 0.10);
}

static UIColor *PLThemeCardBorderColor(UITraitCollection *__unused traits) {
    return [PLThemeBlendColor(PLThemeAccentColor(), [UIColor colorWithWhite:0.75 alpha:1.0], 0.5)
            colorWithAlphaComponent:0.55];
}

static UIColor *PLThemeButtonGradientStart(void) {
    return PLThemeBlendColor(PLThemeAccentColor(), UIColor.whiteColor, 0.15);
}

static UIColor *PLThemeButtonGradientEnd(void) {
    return PLThemeBlendColor(PLThemeAccentColor(), [UIColor colorWithRed:24.0/255.0 green:33.0/255.0 blue:52.0/255.0 alpha:1.0], 0.35);
}

void swizzle(Class class, SEL originalAction, SEL swizzledAction) {
    method_exchangeImplementations(class_getInstanceMethod(class, originalAction), class_getInstanceMethod(class, swizzledAction));
}

void swizzleClass(Class class, SEL originalAction, SEL swizzledAction) {
    method_exchangeImplementations(class_getClassMethod(class, originalAction), class_getClassMethod(class, swizzledAction));
}

void swizzleUIImageMethod(SEL originalAction, SEL swizzledAction) {
    Class class = [UIImage class];
    Method originalMethod = class_getInstanceMethod(class, originalAction);
    Method swizzledMethod = class_getInstanceMethod(class, swizzledAction);

    if (originalMethod && swizzledMethod) {
        method_exchangeImplementations(originalMethod, swizzledMethod);
    } else {
        NSLog(@"[UIKit+hook] Warning: Could not swizzle UIImage methods (%@ and %@)",
              NSStringFromSelector(originalAction),
              NSStringFromSelector(swizzledAction));
    }
}

static BOOL PLClassNameContainsAny(NSString *className, NSArray<NSString *> *blockedClassNames) {
    for (NSString *blocked in blockedClassNames) {
        if ([className containsString:blocked]) {
            return YES;
        }
    }
    return NO;
}

static BOOL PLShouldStyleController(UIViewController *controller) {
    if (controller == nil) {
        return NO;
    }
    if ([controller isKindOfClass:UIAlertController.class]) {
        return NO;
    }
    if ([NSBundle bundleForClass:controller.class] != NSBundle.mainBundle) {
        return NO;
    }

    NSString *className = NSStringFromClass(controller.class);
    return !PLClassNameContainsAny(className, @[
        @"SurfaceViewController",
        @"JavaGUIViewController",
        @"CustomControlsViewController"
    ]);
}

static UIViewController *PLOwningViewController(UIView *view) {
    UIResponder *responder = view;
    while (responder != nil) {
        if ([responder isKindOfClass:UIViewController.class]) {
            return (UIViewController *)responder;
        }
        responder = responder.nextResponder;
    }
    return nil;
}

static BOOL PLViewHasAncestorOfClass(UIView *view, Class targetClass) {
    UIView *current = view.superview;
    while (current != nil) {
        if ([current isKindOfClass:targetClass]) {
            return YES;
        }
        current = current.superview;
    }
    return NO;
}

static CAGradientLayer *PLThemeButtonGradientLayer(UIButton *button) {
    for (CALayer *layer in button.layer.sublayers) {
        if ([layer.name isEqualToString:@"pl.theme.button.gradient"] && [layer isKindOfClass:CAGradientLayer.class]) {
            return (CAGradientLayer *)layer;
        }
    }
    return nil;
}

static void PLStyleTextField(UITextField *field) {
    if (!field) {
        return;
    }

    BOOL wasStyled = [objc_getAssociatedObject(field, kThemeTextFieldStyledKey) boolValue];
    field.borderStyle = UITextBorderStyleNone;
    field.backgroundColor = [PLThemeBlendColor([UIColor colorWithRed:13.0/255.0 green:25.0/255.0 blue:45.0/255.0 alpha:0.88]
                                              PLThemeAccentColor()
                                              0.10] colorWithAlphaComponent:0.92];
    field.layer.cornerRadius = 10.0;
    field.layer.borderWidth = 1.0;
    field.layer.borderColor = [PLThemeAccentColor() colorWithAlphaComponent:0.4].CGColor;
    field.textColor = UIColor.whiteColor;
    field.tintColor = PLThemeAccentColor();
    if (@available(iOS 13.0, *)) {
        field.layer.cornerCurve = kCACornerCurveContinuous;
    }

    if (!wasStyled && field.placeholder.length > 0) {
        field.attributedPlaceholder = [[NSAttributedString alloc] initWithString:field.placeholder attributes:@{
            NSForegroundColorAttributeName: [UIColor colorWithWhite:0.86 alpha:0.58]
        }];
    }

    objc_setAssociatedObject(field, kThemeTextFieldStyledKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void PLStyleButton(UIButton *button) {
    if (!button) {
        return;
    }
    if (!button.currentTitle.length || button.bounds.size.height < 30.0) {
        return;
    }
    if ([button.superview isKindOfClass:NSClassFromString(@"_UIButtonBarButton")]) {
        return;
    }
    if (PLViewHasAncestorOfClass(button, UISegmentedControl.class) || PLViewHasAncestorOfClass(button, UISearchBar.class)) {
        return;
    }

    CAGradientLayer *gradient = PLThemeButtonGradientLayer(button);
    if (!gradient) {
        gradient = [CAGradientLayer layer];
        gradient.name = @"pl.theme.button.gradient";
        gradient.startPoint = CGPointMake(0.0, 0.5);
        gradient.endPoint = CGPointMake(1.0, 0.5);
        [button.layer insertSublayer:gradient atIndex:0];
    }
    gradient.colors = @[
        (id)PLThemeButtonGradientStart().CGColor,
        (id)PLThemeButtonGradientEnd().CGColor
    ];
    button.layer.cornerRadius = 12.0;
    gradient.frame = button.bounds;
    gradient.cornerRadius = button.layer.cornerRadius;

    button.backgroundColor = UIColor.clearColor;
    button.layer.borderWidth = 1.0;
    button.layer.borderColor = PLThemeBlendColor(PLThemeAccentColor(), UIColor.whiteColor, 0.20).CGColor;
    button.layer.shadowColor = [PLThemeAccentColor() colorWithAlphaComponent:0.65].CGColor;
    button.layer.shadowRadius = 12.0;
    button.layer.shadowOpacity = 0.32;
    button.layer.shadowOffset = CGSizeMake(0, 5);
    if (@available(iOS 13.0, *)) {
        button.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    button.tintColor = UIColor.whiteColor;

    if (!objc_getAssociatedObject(button, kThemeButtonStyledKey)) {
        objc_setAssociatedObject(button, kThemeButtonStyledKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

static void PLStyleControlsRecursively(UIView *rootView) {
    if (!rootView) {
        return;
    }

    if ([rootView isKindOfClass:UITextField.class]) {
        PLStyleTextField((UITextField *)rootView);
    } else if ([rootView isKindOfClass:UIButton.class]) {
        PLStyleButton((UIButton *)rootView);
    } else if ([rootView isKindOfClass:UISearchBar.class]) {
        UISearchBar *searchBar = (UISearchBar *)rootView;
        if ([searchBar respondsToSelector:@selector(searchTextField)]) {
            PLStyleTextField(searchBar.searchTextField);
        }
    }

    for (UIView *subview in rootView.subviews) {
        PLStyleControlsRecursively(subview);
    }
}

static void PLApplyTableStyle(UITableView *tableView) {
    if (!tableView) {
        return;
    }
    tableView.backgroundColor = UIColor.clearColor;
    tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    tableView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
}

static void PLApplyGlobalAppearance(void) {
    UIColor *accent = PLThemeAccentColor();
    [UIBarButtonItem appearance].tintColor = accent;
    [UISwitch appearance].onTintColor = [accent colorWithAlphaComponent:0.85];
    [UIProgressView appearance].progressTintColor = accent;

    if (@available(iOS 13.0, *)) {
        UINavigationBarAppearance *navigationBar = [[UINavigationBarAppearance alloc] init];
        [navigationBar configureWithOpaqueBackground];
        navigationBar.backgroundColor = PLThemeBlendColor([UIColor colorWithRed:11.0/255.0 green:17.0/255.0 blue:31.0/255.0 alpha:1.0], accent, 0.10);
        navigationBar.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.35];
        navigationBar.titleTextAttributes = @{NSForegroundColorAttributeName: UIColor.whiteColor};
        navigationBar.largeTitleTextAttributes = @{NSForegroundColorAttributeName: UIColor.whiteColor};

        UINavigationBar *navigationAppearance = [UINavigationBar appearance];
        navigationAppearance.standardAppearance = navigationBar;
        navigationAppearance.compactAppearance = navigationBar;
        navigationAppearance.scrollEdgeAppearance = navigationBar;
        navigationAppearance.tintColor = accent;

        UIToolbarAppearance *toolbar = [[UIToolbarAppearance alloc] init];
        [toolbar configureWithOpaqueBackground];
        toolbar.backgroundColor = PLThemeBlendColor([UIColor colorWithRed:10.0/255.0 green:16.0/255.0 blue:29.0/255.0 alpha:1.0], accent, 0.08);
        toolbar.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.35];

        UIToolbar *toolbarAppearance = [UIToolbar appearance];
        toolbarAppearance.standardAppearance = toolbar;
        if (@available(iOS 15.0, *)) {
            toolbarAppearance.scrollEdgeAppearance = toolbar;
        }
        toolbarAppearance.tintColor = accent;

        UISegmentedControl *segmented = [UISegmentedControl appearance];
        segmented.selectedSegmentTintColor = [accent colorWithAlphaComponent:0.3];
        [segmented setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor colorWithWhite:0.85 alpha:1.0]} forState:UIControlStateNormal];
        [segmented setTitleTextAttributes:@{NSForegroundColorAttributeName: UIColor.whiteColor} forState:UIControlStateSelected];
    }
}

@implementation PLThemeBackgroundView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }

    self.userInteractionEnabled = NO;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.gradientLayer = [CAGradientLayer layer];
    self.gradientLayer.startPoint = CGPointMake(0.0, 0.0);
    self.gradientLayer.endPoint = CGPointMake(1.0, 1.0);
    self.gradientLayer.locations = @[@0.0, @0.55, @1.0];
    [self.layer addSublayer:self.gradientLayer];

    self.glowLayer = [CAGradientLayer layer];
    self.glowLayer.startPoint = CGPointMake(0.0, 0.0);
    self.glowLayer.endPoint = CGPointMake(1.0, 1.0);
    self.glowLayer.locations = @[@0.0, @0.35, @0.78];
    [self.layer addSublayer:self.glowLayer];
    [self updateColors];
    return self;
}

- (void)updateColors {
    UIColor *accent = PLThemeAccentColor();
    self.gradientLayer.colors = @[
        (id)PLThemeBackgroundStart(self.traitCollection).CGColor,
        (id)PLThemeBackgroundMid(self.traitCollection).CGColor,
        (id)PLThemeBackgroundEnd(self.traitCollection).CGColor
    ];
    self.glowLayer.colors = @[
        (id)[[accent colorWithAlphaComponent:0.34] CGColor],
        (id)[[PLThemeBlendColor(accent, [UIColor colorWithRed:15.0/255.0 green:22.0/255.0 blue:38.0/255.0 alpha:1.0], 0.38)
              colorWithAlphaComponent:0.18] CGColor],
        (id)[UIColor.clearColor CGColor]
    ];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.gradientLayer.frame = self.bounds;
    self.glowLayer.frame = self.bounds;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (previousTraitCollection.userInterfaceStyle != self.traitCollection.userInterfaceStyle) {
        [self updateColors];
    }
}

@end

void init_hookUIKitConstructor(void) {
    UIUserInterfaceIdiom idiom = getPrefBool(@"debug.debug_ipad_ui") ? UIUserInterfaceIdiomPad : UIUserInterfaceIdiomPhone;
    [UIDevice.currentDevice _setActiveUserInterfaceIdiom:idiom];
    [UIScreen.mainScreen _setUserInterfaceIdiom:idiom];

    static dispatch_once_t appearanceOnceToken;
    dispatch_once(&appearanceOnceToken, ^{
        PLApplyGlobalAppearance();
    });

    swizzle(UIImageView.class, @selector(setImage:), @selector(hook_setImage:));
    swizzle(UIViewController.class, @selector(viewDidLoad), @selector(hook_viewDidLoad));
    swizzle(UIViewController.class, @selector(viewDidLayoutSubviews), @selector(hook_viewDidLayoutSubviews));
    swizzle(UITableViewCell.class, @selector(layoutSubviews), @selector(hook_layoutSubviews));

    if(UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
        swizzle(UIPointerInteraction.class, @selector(_updateInteractionIsEnabled), @selector(hook__updateInteractionIsEnabled));
    }

    swizzleUIImageMethod(NSSelectorFromString(@"_imageWithSize:"), @selector(hook_imageWithSize:));

    if (realUIIdiom == UIUserInterfaceIdiomTV) {
        if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            class_setSuperclass(NSClassFromString(@"UITableConstants_Pad"), NSClassFromString(@"UITableConstants_TV"));
#pragma clang diagnostic pop
        }
        swizzle(UINavigationController.class, @selector(toolbar), @selector(hook_toolbar));
        swizzle(UINavigationController.class, @selector(setToolbar:), @selector(hook_setToolbar:));
        swizzleClass(UISwitch.class, @selector(visualElementForTraitCollection:), @selector(hook_visualElementForTraitCollection:));
   }
}

@implementation UIDevice(hook)

- (NSString *)completeOSVersion {
    return [NSString stringWithFormat:@"%@ %@ (%@)", self.systemName, self.systemVersion, self.buildVersion];
}

@end

@implementation UIImageView(hook)

- (BOOL)isSizeFixed {
    return [objc_getAssociatedObject(self, @selector(isSizeFixed)) boolValue];
}

- (void)setIsSizeFixed:(BOOL)fixed {
    objc_setAssociatedObject(self, @selector(isSizeFixed), @(fixed), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)hook_setImage:(UIImage *)image {
    if (self.isSizeFixed) {
        UIImage *resizedImage = [image _imageWithSize:self.frame.size];
        [self hook_setImage:resizedImage];
    } else {
        [self hook_setImage:image];
    }
}

@end

@implementation UIImage(hook)

- (UIImage *)hook_imageWithSize:(CGSize)size {
    if (CGSizeEqualToSize(self.size, size)) {
        return self;
    }

    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    format.scale = self.scale;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size format:format];

    UIImage *newImage = [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull context) {
        CGFloat widthRatio = size.width / self.size.width;
        CGFloat heightRatio = size.height / self.size.height;
        CGFloat ratio = MIN(widthRatio, heightRatio);

        CGFloat newWidth = self.size.width * ratio;
        CGFloat newHeight = self.size.height * ratio;
        CGFloat x = (size.width - newWidth) / 2;
        CGFloat y = (size.height - newHeight) / 2;
        [self drawInRect:CGRectMake(x, y, newWidth, newHeight)];
    }];

    return [newImage imageWithRenderingMode:self.renderingMode];
}

@end

@implementation UIViewController(theme)

- (void)hook_viewDidLoad {
    [self hook_viewDidLoad];
    if (!PLShouldStyleController(self)) {
        return;
    }

    if (@available(iOS 13.0, *)) {
        self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    }

    UIView *containerView = nil;
    if ([self isKindOfClass:UITableViewController.class]) {
        UITableView *tableView = ((UITableViewController *)self).tableView;
        PLApplyTableStyle(tableView);
        containerView = tableView;
    } else {
        containerView = self.view;
    }
    if (!containerView) {
        return;
    }

    PLThemeBackgroundView *backgroundView = objc_getAssociatedObject(self, kThemeBackgroundViewKey);
    if (backgroundView == nil) {
        backgroundView = [[PLThemeBackgroundView alloc] initWithFrame:containerView.bounds];
        if ([containerView isKindOfClass:UITableView.class]) {
            ((UITableView *)containerView).backgroundView = backgroundView;
        } else {
            [containerView insertSubview:backgroundView atIndex:0];
        }
        objc_setAssociatedObject(self, kThemeBackgroundViewKey, backgroundView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    backgroundView.frame = containerView.bounds;
    self.view.backgroundColor = UIColor.clearColor;
    if ([containerView respondsToSelector:@selector(setTintColor:)]) {
        containerView.tintColor = PLThemeAccentColor();
    }
    PLStyleControlsRecursively(self.view);
}

- (void)hook_viewDidLayoutSubviews {
    [self hook_viewDidLayoutSubviews];
    if (!PLShouldStyleController(self)) {
        return;
    }

    PLThemeBackgroundView *backgroundView = objc_getAssociatedObject(self, kThemeBackgroundViewKey);
    if (!backgroundView) {
        return;
    }

    UIView *containerView = [self isKindOfClass:UITableViewController.class]
        ? ((UITableViewController *)self).tableView
        : self.view;
    backgroundView.frame = containerView.bounds;
    PLStyleControlsRecursively(self.view);
}

@end

@implementation UITableViewCell(theme)

- (void)hook_layoutSubviews {
    [self hook_layoutSubviews];

    UIViewController *owner = PLOwningViewController(self);
    if (!PLShouldStyleController(owner)) {
        return;
    }

    UIView *backgroundCard = objc_getAssociatedObject(self, kThemeCellBackgroundKey);
    UIView *selectedCard = objc_getAssociatedObject(self, kThemeCellSelectedKey);
    if (backgroundCard == nil || selectedCard == nil) {
        backgroundCard = [[UIView alloc] initWithFrame:CGRectZero];
        backgroundCard.clipsToBounds = YES;
        backgroundCard.userInteractionEnabled = NO;
        if (@available(iOS 13.0, *)) {
            backgroundCard.layer.cornerCurve = kCACornerCurveContinuous;
        }

        selectedCard = [[UIView alloc] initWithFrame:CGRectZero];
        selectedCard.userInteractionEnabled = NO;
        if (@available(iOS 13.0, *)) {
            selectedCard.layer.cornerCurve = kCACornerCurveContinuous;
        }

        self.backgroundView = backgroundCard;
        self.selectedBackgroundView = selectedCard;
        self.backgroundColor = UIColor.clearColor;
        self.contentView.backgroundColor = UIColor.clearColor;

        objc_setAssociatedObject(self, kThemeCellBackgroundKey, backgroundCard, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, kThemeCellSelectedKey, selectedCard, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    CGRect insetBounds = CGRectInset(self.bounds, 10.0, 3.0);
    backgroundCard.frame = insetBounds;
    backgroundCard.layer.cornerRadius = 14.0;
    backgroundCard.backgroundColor = PLThemeCardColor(self.traitCollection);
    backgroundCard.layer.borderWidth = 1.0;
    backgroundCard.layer.borderColor = PLThemeCardBorderColor(self.traitCollection).CGColor;
    backgroundCard.layer.shadowColor = [UIColor colorWithRed:2.0/255.0 green:11.0/255.0 blue:26.0/255.0 alpha:1.0].CGColor;
    backgroundCard.layer.shadowOpacity = 0.42;
    backgroundCard.layer.shadowRadius = 10.0;
    backgroundCard.layer.shadowOffset = CGSizeMake(0, 5);

    selectedCard.frame = insetBounds;
    selectedCard.layer.cornerRadius = 14.0;
    selectedCard.backgroundColor = [PLThemeAccentColor() colorWithAlphaComponent:0.3];

    CGFloat nudgeLeft = 6.0;
    if (self.textLabel.text.length > 0) {
        CGRect textFrame = self.textLabel.frame;
        textFrame.origin.x = MAX(12.0, textFrame.origin.x - nudgeLeft);
        self.textLabel.frame = textFrame;
    }
    if (self.detailTextLabel.text.length > 0) {
        CGRect detailFrame = self.detailTextLabel.frame;
        detailFrame.origin.x = MAX(12.0, detailFrame.origin.x - nudgeLeft);
        self.detailTextLabel.frame = detailFrame;
    }
}

@end

@implementation UINavigationController(hook)

- (UIToolbar *)hook_toolbar {
    UIToolbar *toolbar = objc_getAssociatedObject(self, @selector(toolbar));
    if (toolbar == nil) {
        toolbar = [[UIToolbar alloc] initWithFrame:
            CGRectMake(self.view.bounds.origin.x, self.view.bounds.size.height - 100,
            self.view.bounds.size.width, 100)];
        toolbar.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
        toolbar.backgroundColor = UIColor.systemBackgroundColor;
        objc_setAssociatedObject(self, @selector(toolbar), toolbar, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [self performSelector:@selector(_configureToolbar)];
    }
    return toolbar;
}

- (void)hook_setToolbar:(UIToolbar *)toolbar {
    objc_setAssociatedObject(self, @selector(toolbar), toolbar, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

@implementation UISwitch(hook)
+ (id)hook_visualElementForTraitCollection:(UITraitCollection *)collection {
    if (collection.userInterfaceIdiom == UIUserInterfaceIdiomTV) {
        UITraitCollection *override = [UITraitCollection traitCollectionWithUserInterfaceIdiom:UIUserInterfaceIdiomPad];
        UITraitCollection *new = [UITraitCollection traitCollectionWithTraitsFromCollections:@[collection, override]];
        return [self hook_visualElementForTraitCollection:new];
    }
    return [self hook_visualElementForTraitCollection:collection];
}
@end

@implementation UITraitCollection(hook)

- (UIUserInterfaceSizeClass)horizontalSizeClass {
    return UIUserInterfaceSizeClassRegular;
}

- (UIUserInterfaceSizeClass)verticalSizeClass {
    return UIUserInterfaceSizeClassRegular;
}

@end

@implementation UIWindow(hook)

+ (UIWindow *)mainWindow {
    return mainWindow;
}

+ (UIWindow *)externalWindow {
    return externalWindow;
}

- (UIViewController *)visibleViewController {
    UIViewController *current = self.rootViewController;
    while (current.presentedViewController) {
        if ([current.presentedViewController isKindOfClass:UIAlertController.class] || [current.presentedViewController isKindOfClass:NSClassFromString(@"UIInputWindowController")]) {
            break;
        }
        current = current.presentedViewController;
    }
    if ([current isKindOfClass:UINavigationController.class]) {
        return [(UINavigationController *)self.rootViewController visibleViewController];
    } else {
        return current;
    }
}

@end

@implementation UINavigationBar(forceFullHeightInLandscape)
- (BOOL)forceFullHeightInLandscape {
    return YES;
}
@end

@implementation UIPointerInteraction(hook)
- (void)hook__updateInteractionIsEnabled {
    UIView *view = self.view;
    BOOL enabled = self.enabled;
    if([self respondsToSelector:@selector(drivers)]) {
        for(id<_UIPointerInteractionDriver> driver in self.drivers) {
            driver.view = enabled ? view : nil;
        }
    } else {
        self.driver.view = enabled ? view : nil;
    }
    static ptrdiff_t ivarOff = 0;
    if(!ivarOff) {
        ivarOff = ivar_getOffset(class_getInstanceVariable(self.class, "_observingPresentationNotification"));
    }

    BOOL *observingPresentationNotification = (BOOL *)((uint64_t)(__bridge void *)self + ivarOff);
    if(!enabled && *observingPresentationNotification) {
        [NSNotificationCenter.defaultCenter removeObserver:self name:UIPresentationControllerPresentationTransitionWillBeginNotification object:nil];
        *observingPresentationNotification = NO;
    }
}
@end

UIViewController* currentVC() {
    return UIWindow.mainWindow.visibleViewController;
}

UIColor *PLThemeAccentResolvedColor(void) {
    return PLThemeAccentColor();
}

UIColor *PLThemeAccentBlendColor(UIColor *target, CGFloat ratio) {
    return PLThemeBlendColor(target, PLThemeAccentColor(), ratio);
}

void PLRefreshThemeAppearance(void) {
    PLApplyGlobalAppearance();
    dispatch_async(dispatch_get_main_queue(), ^{
        UIColor *accent = PLThemeAccentColor();
        NSArray *scenes = UIApplication.sharedApplication.connectedScenes.allObjects;
        for (id sceneObj in scenes) {
            if (![sceneObj isKindOfClass:UIWindowScene.class]) {
                continue;
            }
            UIWindowScene *scene = (UIWindowScene *)sceneObj;
            for (UIWindow *window in scene.windows) {
                window.tintColor = accent;
                [window setNeedsLayout];
                [window layoutIfNeeded];
                [window.rootViewController.view setNeedsLayout];
                [window.rootViewController.view layoutIfNeeded];
            }
        }
    });
}
