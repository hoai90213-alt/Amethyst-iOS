#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>
#import <math.h>
#import "LauncherPreferences.h"
#import "UIKit+hook.h"
#import "utils.h"

__weak UIWindow *mainWindow, *externalWindow;
static void *kLiquidGlassBackgroundViewKey = &kLiquidGlassBackgroundViewKey;
static void *kLiquidGlassStyledTextFieldKey = &kLiquidGlassStyledTextFieldKey;
static void *kLiquidGlassStyledButtonKey = &kLiquidGlassStyledButtonKey;
static void *kLiquidGlassCellBackgroundKey = &kLiquidGlassCellBackgroundKey;
static void *kLiquidGlassCellSelectedKey = &kLiquidGlassCellSelectedKey;
static void *kLiquidGlassCellHighlightKey = &kLiquidGlassCellHighlightKey;
static void *kLiquidGlassHeaderBackgroundKey = &kLiquidGlassHeaderBackgroundKey;

@interface PLLiquidGlassBackgroundView : UIView
@property(nonatomic) CAGradientLayer *gradientLayer;
@property(nonatomic) UIVisualEffectView *materialView;
@property(nonatomic) UIVisualEffectView *vibrancyView;
@property(nonatomic) CAGradientLayer *causticLayer;
@property(nonatomic) CAGradientLayer *specularLayer;
@property(nonatomic) UIView *orbPrimary;
@property(nonatomic) UIView *orbSecondary;
@property(nonatomic) UIView *orbTertiary;
@end

@interface UIViewController(liquidGlass)
- (void)hook_viewDidLoad;
- (void)hook_viewDidLayoutSubviews;
@end

@interface UITableViewCell(liquidGlass)
- (void)hook_layoutSubviews;
@end

@interface UITableViewHeaderFooterView(liquidGlass)
- (void)hook_layoutSubviews;
@end

static UIColor *PLLiquidGlassAccentColor(void) {
    return [UIColor colorWithRed:37.0/255.0 green:163.0/255.0 blue:201.0/255.0 alpha:1.0];
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

static void PLAddParallax(UIView *view, CGFloat amount) {
    if (!view || amount <= 0.0) {
        return;
    }
    if (view.motionEffects.count > 0) {
        return;
    }

    UIInterpolatingMotionEffect *xEffect = [[UIInterpolatingMotionEffect alloc] initWithKeyPath:@"center.x" type:UIInterpolatingMotionEffectTypeTiltAlongHorizontalAxis];
    xEffect.minimumRelativeValue = @(-amount);
    xEffect.maximumRelativeValue = @(amount);

    UIInterpolatingMotionEffect *yEffect = [[UIInterpolatingMotionEffect alloc] initWithKeyPath:@"center.y" type:UIInterpolatingMotionEffectTypeTiltAlongVerticalAxis];
    yEffect.minimumRelativeValue = @(-amount);
    yEffect.maximumRelativeValue = @(amount);

    UIMotionEffectGroup *group = [UIMotionEffectGroup new];
    group.motionEffects = @[xEffect, yEffect];
    [view addMotionEffect:group];
}

static void PLStyleTextField(UITextField *field) {
    if (!field || objc_getAssociatedObject(field, kLiquidGlassStyledTextFieldKey)) {
        return;
    }
    field.borderStyle = UITextBorderStyleNone;
    field.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.16];
    field.layer.cornerRadius = 12.0;
    field.layer.borderWidth = 0.8;
    field.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.28].CGColor;
    if (@available(iOS 13.0, *)) {
        field.layer.cornerCurve = kCACornerCurveContinuous;
    }

    if (field.placeholder.length > 0) {
        field.attributedPlaceholder = [[NSAttributedString alloc] initWithString:field.placeholder attributes:@{
            NSForegroundColorAttributeName: [UIColor colorWithWhite:1.0 alpha:0.72]
        }];
    }

    objc_setAssociatedObject(field, kLiquidGlassStyledTextFieldKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void PLStyleButton(UIButton *button) {
    if (!button || objc_getAssociatedObject(button, kLiquidGlassStyledButtonKey)) {
        return;
    }
    if (button.bounds.size.height < 30.0) {
        return;
    }
    if ([button.superview isKindOfClass:NSClassFromString(@"_UIButtonBarButton")]) {
        return;
    }
    if (!button.currentTitle.length) {
        return;
    }
    if (PLViewHasAncestorOfClass(button, UISegmentedControl.class)) {
        return;
    }
    if (PLViewHasAncestorOfClass(button, UISearchBar.class)) {
        return;
    }

    button.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.14];
    button.layer.cornerRadius = 12.0;
    button.layer.borderWidth = 0.8;
    button.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.28].CGColor;
    if (@available(iOS 13.0, *)) {
        button.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [button setTitleColor:UIColor.labelColor forState:UIControlStateNormal];

    UIView *shine = [[UIView alloc] initWithFrame:CGRectZero];
    shine.userInteractionEnabled = NO;
    shine.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.07];
    shine.translatesAutoresizingMaskIntoConstraints = NO;
    shine.layer.cornerRadius = 12.0;
    if (@available(iOS 13.0, *)) {
        shine.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [button insertSubview:shine atIndex:0];
    [NSLayoutConstraint activateConstraints:@[
        [shine.leadingAnchor constraintEqualToAnchor:button.leadingAnchor constant:1.0],
        [shine.trailingAnchor constraintEqualToAnchor:button.trailingAnchor constant:-1.0],
        [shine.topAnchor constraintEqualToAnchor:button.topAnchor constant:1.0],
        [shine.bottomAnchor constraintEqualToAnchor:button.bottomAnchor constant:-1.0]
    ]];

    PLAddParallax(button, 3.0);
    objc_setAssociatedObject(button, kLiquidGlassStyledButtonKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
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

static void PLApplyLiquidGlassTableStyle(UITableView *tableView) {
    if (!tableView) {
        return;
    }
    tableView.backgroundColor = UIColor.clearColor;
    if (tableView.separatorStyle != UITableViewCellSeparatorStyleNone) {
        tableView.separatorColor = [UIColor colorWithWhite:1.0 alpha:0.16];
    }
}

static void PLApplyLiquidGlassGlobalAppearance(void) {
    UIColor *accentColor = PLLiquidGlassAccentColor();
    UINavigationBar *navigationBarAppearance = [UINavigationBar appearance];
    navigationBarAppearance.tintColor = accentColor;
    [UIBarButtonItem appearance].tintColor = accentColor;
    [UISwitch appearance].onTintColor = [accentColor colorWithAlphaComponent:0.75];
    [UIProgressView appearance].progressTintColor = accentColor;

    if (@available(iOS 13.0, *)) {
        [UISegmentedControl appearance].selectedSegmentTintColor = [accentColor colorWithAlphaComponent:0.24];

        UINavigationBarAppearance *navigationBar = [[UINavigationBarAppearance alloc] init];
        [navigationBar configureWithTransparentBackground];
        navigationBar.backgroundEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
        navigationBar.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.08];
        navigationBar.shadowColor = [UIColor colorWithWhite:1.0 alpha:0.15];
        navigationBar.titleTextAttributes = @{NSForegroundColorAttributeName: UIColor.labelColor};
        navigationBar.largeTitleTextAttributes = @{NSForegroundColorAttributeName: UIColor.labelColor};

        navigationBarAppearance.standardAppearance = navigationBar;
        navigationBarAppearance.compactAppearance = navigationBar;
        navigationBarAppearance.scrollEdgeAppearance = navigationBar;
        navigationBarAppearance.translucent = YES;

        UIToolbarAppearance *toolbar = [[UIToolbarAppearance alloc] init];
        [toolbar configureWithTransparentBackground];
        toolbar.backgroundEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
        toolbar.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.1];
        toolbar.shadowColor = [UIColor colorWithWhite:1.0 alpha:0.15];

        UIToolbar *toolbarAppearance = [UIToolbar appearance];
        toolbarAppearance.standardAppearance = toolbar;
        if (@available(iOS 15.0, *)) {
            toolbarAppearance.scrollEdgeAppearance = toolbar;
        }
        toolbarAppearance.translucent = YES;
    }
}

@implementation PLLiquidGlassBackgroundView

- (UIView *)buildOrb {
    UIView *orb = [[UIView alloc] initWithFrame:CGRectZero];
    orb.userInteractionEnabled = NO;
    orb.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        orb.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self addSubview:orb];
    return orb;
}

- (void)startAmbientAnimation {
    CABasicAnimation *primaryDrift = [CABasicAnimation animationWithKeyPath:@"transform.translation"];
    primaryDrift.duration = 10.0;
    primaryDrift.autoreverses = YES;
    primaryDrift.repeatCount = HUGE_VALF;
    primaryDrift.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    primaryDrift.toValue = [NSValue valueWithCGSize:CGSizeMake(-22.0, 16.0)];
    [self.orbPrimary.layer addAnimation:primaryDrift forKey:@"pl.orb.primary.drift"];

    CABasicAnimation *secondaryDrift = [CABasicAnimation animationWithKeyPath:@"transform.translation"];
    secondaryDrift.duration = 13.0;
    secondaryDrift.autoreverses = YES;
    secondaryDrift.repeatCount = HUGE_VALF;
    secondaryDrift.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    secondaryDrift.toValue = [NSValue valueWithCGSize:CGSizeMake(18.0, -14.0)];
    [self.orbSecondary.layer addAnimation:secondaryDrift forKey:@"pl.orb.secondary.drift"];

    CABasicAnimation *tertiaryScale = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    tertiaryScale.duration = 8.0;
    tertiaryScale.autoreverses = YES;
    tertiaryScale.repeatCount = HUGE_VALF;
    tertiaryScale.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    tertiaryScale.fromValue = @1.0;
    tertiaryScale.toValue = @1.08;
    [self.orbTertiary.layer addAnimation:tertiaryScale forKey:@"pl.orb.tertiary.scale"];

    CABasicAnimation *specularPulse = [CABasicAnimation animationWithKeyPath:@"opacity"];
    specularPulse.duration = 4.6;
    specularPulse.autoreverses = YES;
    specularPulse.repeatCount = HUGE_VALF;
    specularPulse.fromValue = @0.22;
    specularPulse.toValue = @0.44;
    specularPulse.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.specularLayer addAnimation:specularPulse forKey:@"pl.specular.pulse"];
}

- (void)startCausticSweep {
    [self.causticLayer removeAnimationForKey:@"pl.caustic.sweep"];
    CGFloat width = CGRectGetWidth(self.bounds);
    CABasicAnimation *sweep = [CABasicAnimation animationWithKeyPath:@"position.x"];
    sweep.duration = 7.2;
    sweep.repeatCount = HUGE_VALF;
    sweep.fromValue = @(-width * 0.9);
    sweep.toValue = @(width * 1.9);
    sweep.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.causticLayer addAnimation:sweep forKey:@"pl.caustic.sweep"];
}

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
    [self.layer addSublayer:self.gradientLayer];

    self.orbPrimary = [self buildOrb];
    self.orbSecondary = [self buildOrb];
    self.orbTertiary = [self buildOrb];

    self.materialView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial]];
    self.materialView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.materialView.userInteractionEnabled = NO;
    [self addSubview:self.materialView];

    UIVibrancyEffect *vibrancy = [UIVibrancyEffect effectForBlurEffect:(UIBlurEffect *)self.materialView.effect];
    self.vibrancyView = [[UIVisualEffectView alloc] initWithEffect:vibrancy];
    self.vibrancyView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.vibrancyView.userInteractionEnabled = NO;
    self.vibrancyView.frame = self.bounds;
    [self.materialView.contentView addSubview:self.vibrancyView];

    self.causticLayer = [CAGradientLayer layer];
    self.causticLayer.startPoint = CGPointMake(0.0, 0.5);
    self.causticLayer.endPoint = CGPointMake(1.0, 0.5);
    self.causticLayer.colors = @[
        (id)[UIColor clearColor].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.2].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
        (id)[UIColor clearColor].CGColor
    ];
    self.causticLayer.locations = @[@0.0, @0.34, @0.5, @0.66, @1.0];
    self.causticLayer.opacity = 0.82;
    [self.vibrancyView.layer addSublayer:self.causticLayer];

    self.specularLayer = [CAGradientLayer layer];
    self.specularLayer.colors = @[
        (id)[UIColor colorWithWhite:1.0 alpha:0.28].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.08].CGColor,
        (id)[UIColor clearColor].CGColor
    ];
    self.specularLayer.startPoint = CGPointMake(0.5, 0.0);
    self.specularLayer.endPoint = CGPointMake(0.5, 1.0);
    self.specularLayer.locations = @[@0.0, @0.26, @1.0];
    [self.layer addSublayer:self.specularLayer];

    [self sendSubviewToBack:self.orbPrimary];
    [self sendSubviewToBack:self.orbSecondary];
    [self sendSubviewToBack:self.orbTertiary];

    [self updatePalette];
    PLAddParallax(self.orbPrimary, 16.0);
    PLAddParallax(self.orbSecondary, 12.0);
    PLAddParallax(self.orbTertiary, 10.0);
    [self startAmbientAnimation];
    return self;
}

- (void)updatePalette {
    BOOL dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    if (dark) {
        self.gradientLayer.colors = @[
            (id)[UIColor colorWithRed:17.0/255.0 green:25.0/255.0 blue:44.0/255.0 alpha:1.0].CGColor,
            (id)[UIColor colorWithRed:26.0/255.0 green:44.0/255.0 blue:67.0/255.0 alpha:1.0].CGColor,
            (id)[UIColor colorWithRed:13.0/255.0 green:33.0/255.0 blue:54.0/255.0 alpha:1.0].CGColor
        ];
    } else {
        self.gradientLayer.colors = @[
            (id)[UIColor colorWithRed:225.0/255.0 green:240.0/255.0 blue:252.0/255.0 alpha:1.0].CGColor,
            (id)[UIColor colorWithRed:240.0/255.0 green:248.0/255.0 blue:255.0/255.0 alpha:1.0].CGColor,
            (id)[UIColor colorWithRed:219.0/255.0 green:236.0/255.0 blue:248.0/255.0 alpha:1.0].CGColor
        ];
    }

    self.orbPrimary.backgroundColor = [UIColor colorWithRed:116.0/255.0 green:198.0/255.0 blue:226.0/255.0 alpha:dark ? 0.18 : 0.28];
    self.orbSecondary.backgroundColor = [UIColor colorWithRed:140.0/255.0 green:160.0/255.0 blue:237.0/255.0 alpha:dark ? 0.12 : 0.22];
    self.orbTertiary.backgroundColor = [UIColor colorWithRed:170.0/255.0 green:220.0/255.0 blue:244.0/255.0 alpha:dark ? 0.1 : 0.2];
    self.specularLayer.opacity = dark ? 0.28 : 0.44;
    self.causticLayer.opacity = dark ? 0.54 : 0.82;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat width = self.bounds.size.width;
    CGFloat height = self.bounds.size.height;
    CGFloat minDimension = MIN(width, height);

    self.gradientLayer.frame = self.bounds;
    self.materialView.frame = self.bounds;
    self.vibrancyView.frame = self.bounds;
    self.specularLayer.frame = CGRectMake(0, 0, width, height * 0.6);

    CGFloat primarySize = minDimension * 0.85;
    CGFloat secondarySize = minDimension * 0.62;
    CGFloat tertiarySize = minDimension * 0.48;

    self.orbPrimary.frame = CGRectMake(width - primarySize * 0.68, -primarySize * 0.38, primarySize, primarySize);
    self.orbSecondary.frame = CGRectMake(-secondarySize * 0.35, height - secondarySize * 0.7, secondarySize, secondarySize);
    self.orbTertiary.frame = CGRectMake(width * 0.35, height * 0.25, tertiarySize, tertiarySize);

    self.orbPrimary.layer.cornerRadius = primarySize / 2.0;
    self.orbSecondary.layer.cornerRadius = secondarySize / 2.0;
    self.orbTertiary.layer.cornerRadius = tertiarySize / 2.0;

    CGFloat causticHeight = MAX(height * 1.4, 260.0);
    self.causticLayer.frame = CGRectMake(-width, -causticHeight * 0.2, width * 2.4, causticHeight);
    self.causticLayer.transform = CATransform3DMakeRotation((CGFloat)(M_PI / 7.0), 0, 0, 1);
    [self startCausticSweep];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (previousTraitCollection.userInterfaceStyle != self.traitCollection.userInterfaceStyle) {
        [self updatePalette];
    }
}

@end

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

void init_hookUIKitConstructor(void) {
    UIUserInterfaceIdiom idiom = getPrefBool(@"debug.debug_ipad_ui") ? UIUserInterfaceIdiomPad : UIUserInterfaceIdiomPhone;
    [UIDevice.currentDevice _setActiveUserInterfaceIdiom:idiom];
    [UIScreen.mainScreen _setUserInterfaceIdiom:idiom];

    static dispatch_once_t appearanceOnceToken;
    dispatch_once(&appearanceOnceToken, ^{
        PLApplyLiquidGlassGlobalAppearance();
    });
    
    swizzle(UIImageView.class, @selector(setImage:), @selector(hook_setImage:));
    swizzle(UIViewController.class, @selector(viewDidLoad), @selector(hook_viewDidLoad));
    swizzle(UIViewController.class, @selector(viewDidLayoutSubviews), @selector(hook_viewDidLayoutSubviews));
    swizzle(UITableViewCell.class, @selector(layoutSubviews), @selector(hook_layoutSubviews));
    swizzle(UITableViewHeaderFooterView.class, @selector(layoutSubviews), @selector(hook_layoutSubviews));
    if(UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
        swizzle(UIPointerInteraction.class, @selector(_updateInteractionIsEnabled), @selector(hook__updateInteractionIsEnabled));
    }
    
    // Add this line to swizzle the _imageWithSize: method
    swizzleUIImageMethod(NSSelectorFromString(@"_imageWithSize:"), @selector(hook_imageWithSize:));

    if (realUIIdiom == UIUserInterfaceIdiomTV) {
        if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            // If you are about to test iPadOS idiom on tvOS, there's no better way for this
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

// Patch: emulate scaleToFill for table views
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

// Implementation of UIImage hook for proper sizing across iOS versions
@implementation UIImage(hook)

- (UIImage *)hook_imageWithSize:(CGSize)size {
    if (CGSizeEqualToSize(self.size, size)) {
        return self;
    }
    
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    format.scale = self.scale;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size format:format];
    
    UIImage *newImage = [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull context) {
        // Calculate proper proportions
        CGFloat widthRatio = size.width / self.size.width;
        CGFloat heightRatio = size.height / self.size.height;
        CGFloat ratio = MIN(widthRatio, heightRatio);
        
        CGFloat newWidth = self.size.width * ratio;
        CGFloat newHeight = self.size.height * ratio;
        
        // Center the image
        CGFloat x = (size.width - newWidth) / 2;
        CGFloat y = (size.height - newHeight) / 2;
        
        [self drawInRect:CGRectMake(x, y, newWidth, newHeight)];
    }];
    
    return [newImage imageWithRenderingMode:self.renderingMode];
}

@end

@implementation UIViewController(liquidGlass)

- (void)hook_viewDidLoad {
    [self hook_viewDidLoad];
    if (!PLShouldStyleController(self)) {
        return;
    }

    UIView *containerView = nil;
    if ([self isKindOfClass:UITableViewController.class]) {
        UITableView *tableView = ((UITableViewController *)self).tableView;
        PLApplyLiquidGlassTableStyle(tableView);
        containerView = tableView;
    } else {
        containerView = self.view;
    }
    if (!containerView) {
        return;
    }

    PLLiquidGlassBackgroundView *backgroundView = objc_getAssociatedObject(self, kLiquidGlassBackgroundViewKey);
    if (backgroundView == nil) {
        backgroundView = [[PLLiquidGlassBackgroundView alloc] initWithFrame:containerView.bounds];
        backgroundView.frame = containerView.bounds;
        if ([containerView isKindOfClass:UITableView.class]) {
            ((UITableView *)containerView).backgroundView = backgroundView;
        } else {
            [containerView insertSubview:backgroundView atIndex:0];
        }
        objc_setAssociatedObject(self, kLiquidGlassBackgroundViewKey, backgroundView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    backgroundView.frame = containerView.bounds;
    self.view.backgroundColor = UIColor.clearColor;
    PLStyleControlsRecursively(self.view);
}

- (void)hook_viewDidLayoutSubviews {
    [self hook_viewDidLayoutSubviews];
    if (!PLShouldStyleController(self)) {
        return;
    }

    PLLiquidGlassBackgroundView *backgroundView = objc_getAssociatedObject(self, kLiquidGlassBackgroundViewKey);
    if (!backgroundView) {
        return;
    }

    UIView *containerView = [self isKindOfClass:UITableViewController.class] ?
        ((UITableViewController *)self).tableView : self.view;
    backgroundView.frame = containerView.bounds;
    PLStyleControlsRecursively(self.view);
}

@end

@implementation UITableViewCell(liquidGlass)

- (void)hook_layoutSubviews {
    [self hook_layoutSubviews];

    UIViewController *owner = PLOwningViewController(self);
    if (!PLShouldStyleController(owner)) {
        return;
    }

    UIView *backgroundCard = objc_getAssociatedObject(self, kLiquidGlassCellBackgroundKey);
    UIView *selectedCard = objc_getAssociatedObject(self, kLiquidGlassCellSelectedKey);
    CAGradientLayer *highlightLayer = objc_getAssociatedObject(self, kLiquidGlassCellHighlightKey);
    if (backgroundCard == nil || selectedCard == nil) {
        backgroundCard = [[UIView alloc] initWithFrame:CGRectZero];
        backgroundCard.clipsToBounds = YES;
        backgroundCard.userInteractionEnabled = NO;
        backgroundCard.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.24].CGColor;
        backgroundCard.layer.borderWidth = 0.8;
        if (@available(iOS 13.0, *)) {
            backgroundCard.layer.cornerCurve = kCACornerCurveContinuous;
        }

        UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial]];
        blur.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        blur.frame = backgroundCard.bounds;
        [backgroundCard addSubview:blur];
        UIView *tintLayer = [[UIView alloc] initWithFrame:backgroundCard.bounds];
        tintLayer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        tintLayer.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.09];
        [blur.contentView addSubview:tintLayer];

        selectedCard = [[UIView alloc] initWithFrame:CGRectZero];
        selectedCard.backgroundColor = [PLLiquidGlassAccentColor() colorWithAlphaComponent:0.20];
        selectedCard.userInteractionEnabled = NO;
        if (@available(iOS 13.0, *)) {
            selectedCard.layer.cornerCurve = kCACornerCurveContinuous;
        }

        highlightLayer = [CAGradientLayer layer];
        highlightLayer.colors = @[
            (id)[UIColor colorWithWhite:1.0 alpha:0.46].CGColor,
            (id)[UIColor colorWithWhite:1.0 alpha:0.16].CGColor,
            (id)[UIColor clearColor].CGColor
        ];
        highlightLayer.startPoint = CGPointMake(0.5, 0.0);
        highlightLayer.endPoint = CGPointMake(0.5, 1.0);
        highlightLayer.locations = @[@0.0, @0.35, @1.0];
        [backgroundCard.layer addSublayer:highlightLayer];

        self.backgroundView = backgroundCard;
        self.selectedBackgroundView = selectedCard;
        self.backgroundColor = UIColor.clearColor;
        self.contentView.backgroundColor = UIColor.clearColor;

        objc_setAssociatedObject(self, kLiquidGlassCellBackgroundKey, backgroundCard, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, kLiquidGlassCellSelectedKey, selectedCard, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, kLiquidGlassCellHighlightKey, highlightLayer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    CGRect insetBounds = CGRectInset(self.bounds, 10.0, 3.0);
    backgroundCard.frame = insetBounds;
    backgroundCard.layer.cornerRadius = 16.0;
    selectedCard.frame = insetBounds;
    selectedCard.layer.cornerRadius = 16.0;
    highlightLayer.frame = CGRectMake(0, 0, CGRectGetWidth(backgroundCard.bounds), CGRectGetHeight(backgroundCard.bounds) * 0.6);
}

@end

@implementation UITableViewHeaderFooterView(liquidGlass)

- (void)hook_layoutSubviews {
    [self hook_layoutSubviews];

    UIViewController *owner = PLOwningViewController(self);
    if (!PLShouldStyleController(owner)) {
        return;
    }
    if (!self.contentView) {
        return;
    }

    UIVisualEffectView *background = objc_getAssociatedObject(self, kLiquidGlassHeaderBackgroundKey);
    if (background == nil) {
        background = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial]];
        background.userInteractionEnabled = NO;
        background.clipsToBounds = YES;
        background.layer.borderWidth = 0.8;
        background.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.18].CGColor;
        if (@available(iOS 13.0, *)) {
            background.layer.cornerCurve = kCACornerCurveContinuous;
        }

        UIView *overlay = [[UIView alloc] initWithFrame:background.bounds];
        overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        overlay.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.06];
        [background.contentView addSubview:overlay];

        self.backgroundView = [[UIView alloc] initWithFrame:self.bounds];
        self.backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.backgroundView addSubview:background];
        self.contentView.backgroundColor = UIColor.clearColor;
        objc_setAssociatedObject(self, kLiquidGlassHeaderBackgroundKey, background, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    self.backgroundView.frame = self.bounds;
    CGRect frame = CGRectInset(self.bounds, 10.0, 4.0);
    background.frame = frame;
    background.layer.cornerRadius = 14.0;
}

@end

// Patch: unimplemented get/set UIToolbar functions on tvOS
@implementation UINavigationController(hook)

- (UIToolbar *)hook_toolbar {
    UIToolbar *toolbar = objc_getAssociatedObject(self, @selector(toolbar));
    if (toolbar == nil) {
        toolbar = [[UIToolbar alloc] initWithFrame:
            CGRectMake(self.view.bounds.origin.x, self.view.bounds.size.height - 100,
            self.view.bounds.size.width, 100)];
        toolbar.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
        toolbar.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.14];
        objc_setAssociatedObject(self, @selector(toolbar), toolbar, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [self performSelector:@selector(_configureToolbar)];
    }
    return toolbar;
}

- (void)hook_setToolbar:(UIToolbar *)toolbar {
    objc_setAssociatedObject(self, @selector(toolbar), toolbar, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

// Patch: UISwitch crashes if platform == tvOS
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

// This forces the navigation bar to keep its height (44dp) in landscape
@implementation UINavigationBar(forceFullHeightInLandscape)
- (BOOL)forceFullHeightInLandscape {
    return YES;
    //UIScreen.mainScreen.traitCollection.userInterfaceIdiom == UIUserInterfaceIdiomPhone;
}
@end

// Patch: allow UIHoverGestureRecognizer on iPhone
// from TrollPad (https://github.com/khanhduytran0/TrollPad/commit/8eab1b20315e73ed7d5319ff0833564fe2819b30#diff-98dd369a9e94e4f3a4b45dc0288b6b5ec666b35eae93c9cde4375921cbb20e48)
@implementation UIPointerInteraction(hook)
- (void)hook__updateInteractionIsEnabled {
    UIView *view = self.view;
    BOOL enabled = self.enabled; // && view.traitCollection.userInterfaceIdiom == UIUserInterfaceIdiomPad
    if([self respondsToSelector:@selector(drivers)]) {
        for(id<_UIPointerInteractionDriver> driver in self.drivers) {
            driver.view = enabled ? view : nil;
        }
    } else {
        self.driver.view = enabled ? view : nil;
    }
    // to keep it fast, ivar offset is cached for later direct access
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
