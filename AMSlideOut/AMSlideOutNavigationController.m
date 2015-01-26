//
//  AMSlideOutNavigationController.m
//  SlideOut
//
//  Created by Andrea on 12/08/12.
//  Copyright (c) 2012 Andrea Mazzini. All rights reserved.
//

#import "AMSlideOutNavigationController.h"
#import "AMSlideTableCell.h"
#import "AMSlideTableHeader.h"

#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)
#define UISCREEN_WIDTH [[UIScreen mainScreen] bounds].size.width
#define UISCREEN_HEIGHT [[UIScreen mainScreen] bounds].size.height
#define IS_PORTRAIT_ORIENTATION ((([UIApplication sharedApplication].statusBarOrientation == UIInterfaceOrientationPortrait) || ([UIApplication sharedApplication].statusBarOrientation == UIInterfaceOrientationPortraitUpsideDown)))
#define SCREEN_WIDTH (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8.0")? UISCREEN_WIDTH : (IS_PORTRAIT_ORIENTATION ? UISCREEN_WIDTH : UISCREEN_HEIGHT))
#define SCREEN_HEIGHT (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8.0")? UISCREEN_HEIGHT : (IS_PORTRAIT_ORIENTATION ? UISCREEN_HEIGHT : UISCREEN_WIDTH))

@interface AMSlideOutNavigationController ()

@property (strong, nonatomic)	NSMutableDictionary     *options;
@property (strong, nonatomic)	AMTableView             *tableView;
@property (strong, nonatomic)	UIView					*overlayView;
@property (strong, nonatomic)	UIView					*darkView;
@property (strong, nonatomic)	UIBarButtonItem         *barButton;
@property (strong, nonatomic)	UITapGestureRecognizer	*tapGesture;
@property (strong, nonatomic)	UIPanGestureRecognizer	*panGesture;
@property (strong, nonatomic)	UILabel                 *badge;
@property (assign, nonatomic)   BOOL                    menuVisible;
@property (assign, nonatomic)   BOOL                    viewHasBeenShownOnce;
@property (strong, nonatomic)   UIImageView             *logoImage;
@property (strong, nonatomic)   NSString                *logoImageName;
@end

@implementation AMSlideOutNavigationController


- (void)setSlideoutOptions:(NSDictionary *)options
{
	[self.options addEntriesFromDictionary:options];
}

- (NSMutableDictionary*)options
{
	if (_options == nil) {
		_options = [[AMSlideOutGlobals defaultOptions] mutableCopy];
	}
	return _options;
}

- (id)initWithMenuItems:(NSArray*)items
{
	self = [super init];
	if (self) {
		[self commonInitialization];
		_menuItems = [NSMutableArray arrayWithArray:items];
	}
	return self;
}

+ (id)slideOutNavigationWithMenuItems:(NSArray*)items
{
	return [[AMSlideOutNavigationController alloc] initWithMenuItems:items];
}

- (id)initWithImage:(NSString *)image
{
	self = [super init];
	if (self) {
		[self commonInitialization];
		_menuItems = [[NSMutableArray alloc] init];
        _logoImageName = image;
	}
	return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
	if (self) {
		[self commonInitialization];
		_menuItems = [[NSMutableArray alloc] init];
	}
	return self;
}

+ (id)slideOutNavigationWithImage:(NSString *)image
{
    return [[AMSlideOutNavigationController alloc] initWithImage:image];
}

- (void)commonInitialization
{
	_menuVisible = NO;
	_accessibilityDelegate = nil;
	_viewHasBeenShownOnce = NO;
	_startingControllerTag = -1;
	_navigationControllerClass = [UINavigationController class];
}

- (void)setLeftBarButton:(UIBarButtonItem*)barButton
{
	self.barButton = barButton;
	if (self.barButton.target == nil || self.barButton.action == nil) {
		self.barButton.target = self;
		self.barButton.action = @selector(toggleMenu);
	}
    [self.currentViewController.navigationItem setLeftBarButtonItem:self.barButton];
}

- (void)addSectionWithTitle:(NSString*)title
{
	[self addSectionWithTitle:title andHeaderClassName:nil withHeight:[self.options[AMOptionsHeaderHeight] floatValue]];
}

- (void)addSectionWithTitle:(NSString*)title andHeaderClassName:(NSString*)klass withHeight:(CGFloat)height
{
	NSMutableDictionary* section = [[NSMutableDictionary alloc] init];
	if (title) {
		section[kSOSectionTitle] = title;
	}
	if (klass) {
		section[kSOSectionClass] = klass;
	}
	section[kSOSectionHeight] = @(height);
	section[kSOSection] = [[NSMutableArray alloc] init];
	
	[self.menuItems addObject:section];
}

- (void)addViewController:(UIViewController*)controller
                   tagged:(NSInteger)tag
                withTitle:(NSString*)title
                  andIcon:(id)icon
                toSection:(NSInteger)section
{
	[self addViewController:controller
					 tagged:tag
				  withTitle:title
					andIcon:icon
           andSelectionIcon:nil
				  toSection:section
			   beforeChange:nil
			 onCompletion:nil];
}

- (void)addViewController:(UIViewController*)controller
                   tagged:(NSInteger)tag
                withTitle:(NSString*)title
                  andIcon:(id)icon
         andSelectionIcon:(id)selectionIcon
                toSection:(NSInteger)section
{
	[self addViewController:controller
					 tagged:tag
				  withTitle:title
					andIcon:icon
           andSelectionIcon:selectionIcon
				  toSection:section
			   beforeChange:nil
			 onCompletion:nil];
}

- (void)addViewController:(UIViewController*)controller
                   tagged:(NSInteger)tag
                withTitle:(NSString*)title
                  andIcon:(id)icon
                toSection:(NSInteger)section
             beforeChange:(void(^)())before
           onCompletion:(void(^)())after
{
	[self addViewController:controller
                     tagged:tag
                  withTitle:title
                    andIcon:icon
           andSelectionIcon:nil
                  toSection:section
               beforeChange:before
             onCompletion:after];
}

- (void)addViewController:(UIViewController*)controller
                   tagged:(NSInteger)tag
                withTitle:(NSString*)title
                  andIcon:(id)icon
         andSelectionIcon:(id)selectionIcon
                toSection:(NSInteger)section
             beforeChange:(void(^)())before
           onCompletion:(void(^)())after
{
	if (section < [self.menuItems count]) {
		NSMutableDictionary* item = [[NSMutableDictionary alloc] init];
		item[kSOController] = controller;
		item[kSOViewTitle] = title;
		if (icon) {
            item[kSOViewIcon] = icon;
        }
        if (selectionIcon) {
            item[kSOViewSelectionIcon] = selectionIcon;
        }
		if (before) {
			item[kSOBeforeBlock] = [before copy];
		}
		if (after) {
			item[kSOAfterBlock] = [after copy];
		}
		item[kSOViewTag] = @(tag);
		[(self.menuItems)[section][kSOSection] addObject:item];
	} else {
		NSLog(@"AMSlideOutNavigation: section index out of bounds");
	}
}

- (void)addAction:(void(^)())action
           tagged:(NSInteger)tag
        withTitle:(NSString*)title
          andIcon:(id)icon
        toSection:(NSInteger)section
{
    [self addAction:action
             tagged:tag
          withTitle:title
            andIcon:icon
   andSelectionIcon:nil
          toSection:section];
}

- (void)addAction:(void(^)())action
           tagged:(NSInteger)tag
        withTitle:(NSString*)title
          andIcon:(id)icon
 andSelectionIcon:(id)selectionIcon
        toSection:(NSInteger)section
{
	if (section < [self.menuItems count]) {
		NSMutableDictionary* item = [[NSMutableDictionary alloc] init];
		item[kSOViewTitle] = title;
		item[kSOViewIcon] = icon;
        if (selectionIcon) {
            item[kSOViewSelectionIcon] = selectionIcon;
        }
		// Note: The action is stored in the before block
		item[kSOBeforeBlock] = [action copy];
		item[kSOViewTag] = @(tag);
		item[kSOItemIsAction] = @(YES);
		[(self.menuItems)[section][kSOSection] addObject:item];
	} else {
		NSLog(@"AMSlideOutNavigation: section index out of bounds");
	}
}

- (void)addViewControllerClass:(Class)cls
                   withNibName:(NSString*)nibName
                        tagged:(NSInteger)tag
                     withTitle:(NSString*)title
                       andIcon:(id)icon
                     toSection:(NSInteger)section
{
	[self addViewControllerClass:cls
                     withNibName:nibName
                          tagged:tag
                       withTitle:title
                         andIcon:icon
                andSelectionIcon:nil
                       toSection:section
                    beforeChange:nil
                  onCompletion:nil];
}

- (void)addViewControllerClass:(Class)cls
                   withNibName:(NSString*)nibName
                        tagged:(NSInteger)tag
                     withTitle:(NSString*)title
                       andIcon:(id)icon
              andSelectionIcon:(id)selectionIcon
                     toSection:(NSInteger)section
{
    [self addViewControllerClass:cls
                     withNibName:nibName
                          tagged:tag
                       withTitle:title
                         andIcon:icon
                andSelectionIcon:selectionIcon
                       toSection:section
                    beforeChange:nil
                  onCompletion:nil];
}

- (void)addViewControllerClass:(Class)cls
                   withNibName:(NSString*)nibName
                        tagged:(NSInteger)tag
                     withTitle:(NSString*)title
                       andIcon:(id)icon
                     toSection:(NSInteger)section
                  beforeChange:(void(^)())before
                onCompletion:(void(^)())after
{
    [self addViewControllerClass:cls
                     withNibName:nibName
                          tagged:tag
                       withTitle:title
                         andIcon:icon
                andSelectionIcon:nil
                       toSection:section
                    beforeChange:before
                  onCompletion:after];
}

- (void)addViewControllerClass:(Class)cls
                   withNibName:(NSString*)nibName
                        tagged:(NSInteger)tag
                     withTitle:(NSString*)title
                       andIcon:(id)icon
              andSelectionIcon:(id)selectionIcon
                     toSection:(NSInteger)section
                  beforeChange:(void(^)())before
                onCompletion:(void(^)())after
{
    if([cls isSubclassOfClass:[UIViewController class]]) {
        if (section < [self.menuItems count]) {
            NSMutableDictionary* item = [[NSMutableDictionary alloc] init];
            item[kSOItemClass] = cls;
            if(nibName) {
                item[kSOItemNibName] = nibName;
            }
            item[kSOViewTitle] = title;
            if (icon) {
                item[kSOViewIcon] = icon;
            }
            if (selectionIcon) {
                item[kSOViewSelectionIcon] = selectionIcon;
            }
            if (before) {
                item[kSOBeforeBlock] = [before copy];
            }
            if (after) {
                item[kSOAfterBlock] = [after copy];
            }
            item[kSOViewTag] = @(tag);
            [(self.menuItems)[section][kSOSection] addObject:item];
        } else {
            NSLog(@"AMSlideOutNavigation: section index out of bounds");
        }
    } else {
        NSLog(@"AMSlideOutNavigation: controller class must be a subclass of UIViewController");
    }
}

- (void)setBadgeValue:(NSString*)value forTag:(NSInteger)tag
{
	int count = 0;
	for (NSDictionary* section in self.menuItems) {
		for (NSMutableDictionary* item in section[kSOSection]) {
			if ([item[kSOViewTag] intValue] == tag) {
				item[kSOViewBadge] = value;
			}
			count += [item[kSOViewBadge] intValue];
		}
	}
	
	if ([self.options[AMOptionsBadgeShowTotal] boolValue]) {
		if (count != 0) {
			[self.badge setText:[NSString stringWithFormat:@"%d", count]];
			[self.badge setAlpha:1];
		} else {
			[self.badge setAlpha:0];
		}
	}
	
	// Save and reselect the row after the reload
	NSIndexPath *ipath = [self.tableView indexPathForSelectedRow];
	[self.tableView reloadData];
	[self.tableView selectRowAtIndexPath:ipath animated:NO scrollPosition:UITableViewScrollPositionNone];
}

- (void)setBadgeTotalValue:(NSString*)value
{
	if (value == nil) {
		[self.badge setAlpha:0];
	} else {
		[self.badge setText:value];
		[self.badge setAlpha:1];
	}
}

- (void)addViewControllerToLastSection:(UIViewController*)controller
                                tagged:(NSInteger)tag
                             withTitle:(NSString*)title
                               andIcon:(id)icon
{
	[self addViewController:controller
                     tagged:tag
                  withTitle:title
                    andIcon:icon
                  toSection:([self.menuItems count]-1)];
}

- (void)addViewControllerToLastSection:(UIViewController*)controller
                                tagged:(NSInteger)tag
                             withTitle:(NSString*)title
                               andIcon:(id)icon
                      andSelectionIcon:(id)selectionIcon
{
	[self addViewController:controller
                     tagged:tag
                  withTitle:title
                    andIcon:icon
           andSelectionIcon:selectionIcon
                  toSection:([self.menuItems count]-1)];
}

- (void)addViewControllerToLastSection:(UIViewController*)controller
                                tagged:(NSInteger)tag
                             withTitle:(NSString*)title
                               andIcon:(id)icon
                          beforeChange:(void(^)())before
                        onCompletion:(void(^)())after
{
	[self addViewController:controller
                     tagged:tag
                  withTitle:title
                    andIcon:icon
                  toSection:([self.menuItems count]-1)
               beforeChange:before
             onCompletion:after];
}

- (void)addViewControllerToLastSection:(UIViewController*)controller
                                tagged:(NSInteger)tag
                             withTitle:(NSString*)title
                               andIcon:(id)icon
                      andSelectionIcon:(id)selectionIcon
                          beforeChange:(void(^)())before
                        onCompletion:(void(^)())after
{
	[self addViewController:controller
                     tagged:tag
                  withTitle:title
                    andIcon:icon
           andSelectionIcon:selectionIcon
                  toSection:([self.menuItems count]-1)
               beforeChange:before
             onCompletion:after];
}

- (void)addActionToLastSection:(void(^)())action
                        tagged:(NSInteger)tag
                     withTitle:(NSString*)title
                       andIcon:(id)icon
{
	[self addAction:action
             tagged:tag
          withTitle:title
            andIcon:icon
          toSection:([self.menuItems count]-1)];
}

- (void)addActionToLastSection:(void(^)())action
                        tagged:(NSInteger)tag
                     withTitle:(NSString*)title
                       andIcon:(id)icon
              andSelectionIcon:(id)selectionIcon
{
	[self addAction:action
             tagged:tag
          withTitle:title
            andIcon:icon
   andSelectionIcon:selectionIcon
          toSection:([self.menuItems count]-1)];
}

- (void)setContentViewController:(UIViewController *)controller
{
	[self.contentController setViewControllers:@[controller]];
    [controller.navigationItem setLeftBarButtonItem:self.barButton];
    self.currentViewController = controller;
	if (self.contentController.navigationBar.translucent) {
		if ([self.currentViewController respondsToSelector:@selector(edgesForExtendedLayout)]) {
			self.currentViewController.edgesForExtendedLayout = UIRectEdgeNone;
		}
	}

}

- (void)addViewControllerClassToLastSection:(Class)cls
                                withNibName:(NSString*)nibName
                                     tagged:(NSInteger)tag
                                  withTitle:(NSString*)title
                                    andIcon:(id)icon
{
    [self addViewControllerClass:cls
                     withNibName:nibName
                          tagged:tag
                       withTitle:title
                         andIcon:icon
                       toSection:([self.menuItems count]-1)];
}

- (void)addViewControllerClassToLastSection:(Class)cls
                                withNibName:(NSString*)nibName
                                     tagged:(NSInteger)tag
                                  withTitle:(NSString*)title
                                    andIcon:(id)icon
                           andSelectionIcon:(id)selectionIcon
{
    [self addViewControllerClass:cls
                     withNibName:nibName
                          tagged:tag
                       withTitle:title
                         andIcon:icon
                andSelectionIcon:selectionIcon
                       toSection:([self.menuItems count]-1)];
}

- (void)addViewControllerClassToLastSection:(Class)cls
                                withNibName:(NSString*)nibName
                                     tagged:(NSInteger)tag
                                  withTitle:(NSString*)title
                                    andIcon:(id)icon
                               beforeChange:(void(^)())before
                             onCompletion:(void(^)())after
{
    [self addViewControllerClass:cls
                     withNibName:nibName
                          tagged:tag
                       withTitle:title
                         andIcon:icon
                       toSection:([self.menuItems count]-1)
                    beforeChange:before
                  onCompletion:after];
}

- (void)addViewControllerClassToLastSection:(Class)cls
                                withNibName:(NSString*)nibName
                                     tagged:(NSInteger)tag
                                  withTitle:(NSString*)title
                                    andIcon:(id)icon
                           andSelectionIcon:(id)selectionIcon
                               beforeChange:(void(^)())before
                             onCompletion:(void(^)())after
{
    [self addViewControllerClass:cls
                     withNibName:nibName
                          tagged:tag
                       withTitle:title
                         andIcon:icon
                andSelectionIcon:selectionIcon
                       toSection:([self.menuItems count]-1)
                    beforeChange:before
                  onCompletion:after];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	[self.currentViewController.navigationController.navigationBar sizeToFit];
}

- (void)loadView
{
	UIView* view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)];
	[view setBackgroundColor:self.options[AMOptionsBackground]];
    
    self.logoImage = [[UIImageView alloc] initWithFrame:CGRectMake(20, 25, 115, 46)];
    self.logoImage.image = [UIImage imageNamed:self.logoImageName];
	// Table View setup
	self.tableView = [[AMTableView alloc] initWithFrame:[self tableRect]];

	self.tableView.options = self.options;
	self.tableView.autoresizingMask = ~UIViewAutoresizingFlexibleBottomMargin;
	self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
	self.tableView.backgroundColor = self.options[AMOptionsBackground];
	[self.tableView setScrollsToTop:NO];
        
    self.tableView.contentInset = UIEdgeInsetsMake([self.options[AMOptionsContentInsetTop] floatValue], 0, 0, 0);
    
	// Dark view
	self.darkView = [[UIView alloc] initWithFrame:
					 CGRectMake(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
					 ];
	[self.darkView setBackgroundColor:self.options[AMOptionsAnimationDarkenColor]];
	[self.darkView setAlpha:0];
	
	// The content is displayed in a UINavigationController
	self.contentController = [[self.navigationControllerClass alloc] initWithNavigationBarClass:self.navigationBarClass toolbarClass:self.navigationToolbarClass];
    [self.contentController.view setFrame:view.frame];

    self.contentController.navigationBar.translucent = [self.options[AMOptionsNavbarTranslucent] boolValue];
    
	if ([self.options[AMOptionsEnableShadow] boolValue]) {
		self.contentController.view.layer.shadowPath = [UIBezierPath bezierPathWithRect:self.contentController.view.bounds].CGPath;
		self.contentController.view.layer.shadowColor = [UIColor blackColor].CGColor;
		self.contentController.view.layer.shadowOffset = CGSizeMake([self.options[AMOptionsSlideShadowOffset] floatValue], 0);
		self.contentController.view.layer.shadowOpacity = [self.options[AMOptionsSlideShadowOpacity] floatValue];
		self.contentController.view.clipsToBounds = NO;
	}
	
	/* The transparent overlay view will catch all the user touches in the content area
	 when the slide menu is visible */
	self.overlayView = [[UIView alloc] initWithFrame:self.contentController.view.frame];
	self.overlayView.userInteractionEnabled = YES;
	self.overlayView.backgroundColor = [UIColor clearColor];
	
    [view addSubview:self.logoImage];
	[view addSubview:self.tableView];
    [view addSubview:self.darkView];
	[view addSubview:self.contentController.view];
	
    [self addChildViewController:self.contentController];
	self.view = view;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	self.currentViewController = nil;
	
	[self.tableView setDelegate:self];
	[self.tableView setDataSource:self];
	
    id accessibilityObject = nil;
    
	if ([self.options[AMOptionsUseBorderedButton] boolValue]) {
		self.barButton = [[UIBarButtonItem alloc] initWithImage:self.options[AMOptionsButtonIcon]
														  style:UIBarButtonItemStylePlain
														 target:self
														 action:@selector(toggleMenu)];
		
        accessibilityObject = self.barButton;
        
	} else  {
		UIButton* button = [UIButton buttonWithType:UIButtonTypeCustom];
		[button setImage:self.options[AMOptionsButtonIcon] forState:UIControlStateNormal];
		[button setFrame:CGRectMake(0, 0, 44, 22)];
		button.imageEdgeInsets = UIEdgeInsetsMake(0, 10, 0, 10);
		[button addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];
		self.barButton = [[UIBarButtonItem alloc] initWithCustomView:button];
		
        accessibilityObject = button;
	}
	
    if (self.accessibilityDelegate) {
        if ([self.accessibilityDelegate respondsToSelector: @selector(applyAccessibilityPropertiesToSlideOutButton:)]) {
            [self.accessibilityDelegate applyAccessibilityPropertiesToSlideOutButton: accessibilityObject];
        }
    }
    
	// Detect when the content recieves a single tap
	self.tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
	[self.overlayView addGestureRecognizer:self.tapGesture];
	
	// Detect when the content is touched and dragged
	self.panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
	[self.panGesture setMaximumNumberOfTouches:2];
	[self.panGesture setDelegate:self];
	[self.overlayView addGestureRecognizer:self.panGesture];
    
	[self.contentController.view addGestureRecognizer:self.panGesture];
	
	// Select the first view controller
	if (self.startingControllerTag < 0) {
		[self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] animated:NO scrollPosition:UITableViewScrollPositionTop];
		[self tableView:self.tableView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
	} else {
		[self switchToControllerTagged:self.startingControllerTag andPerformSelector:nil withObject:nil];
	}
    
    id navbarImage = self.options[AMOptionsNavBarImage];
    if([navbarImage isKindOfClass:[UIImage class]]) {
        [[[self contentController] navigationBar] setBackgroundImage:navbarImage forBarMetrics:UIBarMetricsDefault];
    }
}

- (UILabel*)badge
{
	if (_badge == nil) {
		_badge = [[UILabel alloc] initWithFrame:CGRectMake([self.options[AMOptionsBadgeGlobalPositionX] floatValue],
														   [self.options[AMOptionsBadgeGlobalPositionY] floatValue],
														   [self.options[AMOptionsBadgeGlobalPositionW] floatValue],
														   [self.options[AMOptionsBadgeGlobalPositionH] floatValue])];
		_badge.font = self.options[AMOptionsBadgeGlobalFont];
		_badge.textColor = self.options[AMOptionsBadgeGlobalTextColor];
		_badge.adjustsFontSizeToFitWidth = YES;
		if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"6.0")) {
			_badge.textAlignment = NSTextAlignmentCenter;
		} else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
			_badge.textAlignment = UITextAlignmentCenter;
#pragma clang diagnostic pop
		}
		_badge.opaque = YES;
		_badge.backgroundColor = [UIColor clearColor];
		_badge.shadowOffset = CGSizeMake(0, 1);
		_badge.shadowColor = self.options[AMOptionsBadgeGlobalShadowColor];
		_badge.layer.cornerRadius = [self.options[AMOptionsBadgeGlobalCornerRadius] floatValue];
		_badge.layer.backgroundColor = [self.options[AMOptionsBadgeGlobalBackColor] CGColor];
		[self.barButton.customView addSubview:_badge];
	}
	
	return _badge;
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
}

- (CGRect)tableRect
{
    return (CGRect){
        (CGPoint){
            [self.options[AMOptionsTableInsetX] floatValue],
            [self.options[AMOptionsTableOffsetY] floatValue]
        }, (CGSize) {
            [self.options[AMOptionsSlideValue] floatValue]-[self.options[AMOptionsTableInsetX] floatValue]*2,
            SCREEN_HEIGHT - [self.options[AMOptionsTableOffsetY] floatValue]}
    };
}

- (void)viewDidLayoutSubviews
{
    [self setMenuScrollingEnabled:![self.options[AMOptionsDisableMenuScroll] boolValue]];
    self.tableView.frame = [self tableRect];
}

- (void)setMenuItems:(NSArray *)menuItems
{
	// Makes sure to refresh the table data when new items are set
	_menuItems = [NSMutableArray arrayWithArray:menuItems];
	NSIndexPath *ipath = [self.tableView indexPathForSelectedRow];
	[self.tableView reloadData];
	if (ipath) {
		[self.tableView selectRowAtIndexPath:ipath animated:NO scrollPosition:UITableViewScrollPositionNone];
	}
}

#pragma mark Table View delegates

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return [self.menuItems count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [self.menuItems[section][kSOSection] count];
}

- (NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	return self.menuItems[section][kSOSectionTitle];
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	NSString* cellID = self.options[AMOptionsTableCellClass];
	
	NSDictionary* dict = (self.menuItems)[indexPath.section][kSOSection][indexPath.row];
	UITableViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:cellID];
	if (cell == nil) {
		cell = [[NSClassFromString(self.options[AMOptionsTableCellClass]) alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellID];
		UIView* selection = [[UIView alloc] initWithFrame:cell.frame];
		CGRect selFrame = selection.frame;
		selFrame.size.height =[self.options[AMOptionsTableCellHeight] floatValue];
		selection.frame = selFrame;
		[selection setBackgroundColor:self.options[AMOptionsSelectionBackground]];
		cell.selectedBackgroundView = selection;
        [cell.textLabel setHighlightedTextColor:self.options[AMOptionsCellSelectionFontColor]];
	}
    
    if([indexPath row] >= [(self.menuItems)[[indexPath section]][kSOSection] count] - 1 &&
       [indexPath section] < [self.menuItems count] - 1) {
        [(AMSlideTableCell*)cell setIsCellBeforeHeader:YES];
    } else {
        [(AMSlideTableCell*)cell setIsCellBeforeHeader:NO];
	}
	
	((AMSlideTableCell*)cell).options = self.options;
	cell.textLabel.text = dict[kSOViewTitle];
	[(AMSlideTableCell*)cell setBadgeText:dict[kSOViewBadge]];
    
	id imageData = dict[kSOViewIcon];
	
	if (imageData != nil) {
		if ([imageData isKindOfClass:[NSString class]] && ![imageData isEqualToString:@""]) {
			cell.imageView.image = [UIImage imageNamed:imageData];
		} else if ([imageData isKindOfClass:[UIImage class]]) {
			cell.imageView.image = imageData;
		} else {
			cell.imageView.image = nil;
		}
	} else {
		cell.imageView.image = nil;
	}
    
    id selectionImageData = dict[kSOViewSelectionIcon];
    
    if (selectionImageData != nil) {
        if ([selectionImageData isKindOfClass:[NSString class]] && ![selectionImageData isEqualToString:@""]) {
			cell.imageView.highlightedImage = [UIImage imageNamed:selectionImageData];
		} else if ([selectionImageData isKindOfClass:[UIImage class]]) {
			cell.imageView.highlightedImage = selectionImageData;
		} else {
			cell.imageView.highlightedImage = nil;
		}
    } else {
        cell.imageView.highlightedImage = nil;
    }
    
    if (self.accessibilityDelegate) {
        if ([self.accessibilityDelegate respondsToSelector: @selector(applyAccessibilityPropertiesToSlideOutCell:withTag:fromSection:)]) {
            [self.accessibilityDelegate applyAccessibilityPropertiesToSlideOutCell: cell withTag: [dict[kSOViewTag] intValue] fromSection: indexPath.section];
        }
    }
	
	return cell;
}

- (UIView*)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
	// If the custom class is nil, use the one in the options
	NSString* klass = self.menuItems[section][kSOSectionClass];
	if (!klass) {
		klass = self.options[AMOptionsTableHeaderClass];
	}
	if (!klass) {
		klass = [AMSlideOutGlobals defaultOptions][AMOptionsTableHeaderClass];
	}
	AMSlideTableHeader *header = [[NSClassFromString(klass) alloc] init];
	header.options = self.options;
	header.titleLabel.text = [self tableView:tableView titleForHeaderInSection:section];
    
    if (self.accessibilityDelegate) {
        if ([self.accessibilityDelegate respondsToSelector: @selector(applyAccessibilityPropertiesToHeaderView:fromSection:)]) {
            [self.accessibilityDelegate applyAccessibilityPropertiesToHeaderView: header fromSection: section];
        }
    }
    
    return header;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
	NSString* title = [self tableView:tableView titleForHeaderInSection:section];
	if (title == nil) {
		return 0;
	}
	// If the header has a specific height use that
	NSNumber* height = self.menuItems[section][kSOSectionHeight];
	if (height) {
		return [height floatValue];
	}
    return [self.options[AMOptionsHeaderHeight] floatValue];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return [self.options[AMOptionsTableCellHeight] floatValue];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	NSDictionary* dict = (self.menuItems)[indexPath.section][kSOSection][indexPath.row];
	
	AMSlideOutBeforeHandler before = dict[kSOBeforeBlock];
	if (before) {
		before();
	}
	
	if ([dict[kSOItemIsAction] boolValue]) {
		// If an items only contains an action (saved as a beofre handler), don't change view controller
		// just exit
		[self hideSideMenu];
		return;
	}
	
    UIViewController* newController = dict[kSOController];
    if(dict[kSOItemClass] != nil) {
        Class controllerClass = dict[kSOItemClass];
        if([dict[kSOItemNibName] isKindOfClass:[NSString class]]) {
            newController = (UIViewController*)[[controllerClass alloc] initWithNibName:dict[kSOItemNibName] bundle:nil];
        } else {
            newController = (UIViewController*)[controllerClass new];
        }
    }
    
	[self setContentViewController:newController];
    _currentTag = [dict[kSOViewTag] integerValue];
    
	if ([self.options[AMOptionsUseDefaultTitles] boolValue]) {
		[newController setTitle:dict[kSOViewTitle]];
	}
    [self hideSideMenu];
	AMSlideOutCompletionHandler after = dict[kSOAfterBlock];
	if (after) {
		after();
	}
}

- (void)reloadTableView
{
    [self.tableView reloadData];
}

- (void)switchToControllerTagged:(NSInteger)tag andPerformSelector:(SEL)selector withObject:(id)obj
{
	[self switchToControllerTagged:tag andPerformSelector:selector withObject:obj afterDelay:0];
}

- (void)switchToControllerTagged:(NSInteger)tag andPerformSelector:(SEL)selector withObject:(id)obj afterDelay:(NSTimeInterval)delay
{
	for (NSDictionary* section in self.menuItems) {
		for (NSMutableDictionary* item in [section objectForKey:kSOSection]) {
			if ([[item objectForKey:kSOViewTag] intValue] == tag) {
				NSInteger sectionIndex = [self.menuItems indexOfObject:section];
				NSInteger rowIndex = [[section objectForKey:kSOSection] indexOfObject:item];
				[self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:rowIndex inSection:sectionIndex] animated:YES scrollPosition:UITableViewScrollPositionNone];
				[self tableView:self.tableView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:rowIndex inSection:sectionIndex]];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
				if ([[item objectForKey:kSOController] respondsToSelector:selector]) {
					[[item objectForKey:kSOController] performSelector:selector withObject:obj afterDelay:delay];
				}
#pragma clang diagnostic pop
				return;
			}
		}
	}
}

- (id)getControllerWithTag:(NSInteger)tag
{
    for (NSDictionary* section in self.menuItems) {
		for (NSMutableDictionary* item in [section objectForKey:kSOSection]) {
			if ([[item objectForKey:kSOViewTag] intValue] == tag) {
                if(item[kSOController]) {
                    return item[kSOController];
                } else {
                    return item[kSOItemClass];
                }
			}
		}
	}
    return nil;
}

- (void)disableGesture
{
    [[self options] setObject:[NSNumber numberWithBool:NO] forKey:AMOptionsEnableGesture];
}

- (void)enableGesture
{
    [[self options] setObject:[NSNumber numberWithBool:YES] forKey:AMOptionsEnableGesture];
}

- (void)toggleMenu
{
	if (self.menuVisible) {
		[self hideSideMenu];
	} else {
		[self showSideMenu];
	}
}

- (void)showSideMenu
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kAMSlideOutMenuWillShow object:self];
    [UIView animateWithDuration:[self.options[AMOptionsSlideoutTime] floatValue]
						  delay:0
						options:UIViewAnimationOptionCurveEaseInOut
					 animations:^{
                         
						 // Expand the tableview
						 if ([self.options[AMOptionsAnimationShrink] boolValue]) {
							 [self.tableView setTransform:CGAffineTransformMakeScale(1, 1)];
						 }
						 
						 // Table fadeout animation
						 if ([self.options[AMOptionsAnimationDarken] boolValue]) {
							 [self.darkView setAlpha:0];
						 }
						 
						 // Slide the table
						 if ([self.options[AMOptionsAnimationSlide] boolValue]) {
							 CGRect tableFrame = self.tableView.frame;
							 tableFrame.origin.x = [self.options[AMOptionsTableInsetX] floatValue];
							 [self.tableView setFrame:tableFrame];
						 }
						 
						 // Move the whole NavigationController view aside
						 CGRect frame = self.contentController.view.frame;
						 frame.origin.x = [self.options[AMOptionsSlideValue] floatValue];
						 self.contentController.view.frame = frame;
					 }
                     completion:^(BOOL finished) {
						 // Add the overlay that will receive the gestures
						 [self.tableView setScrollsToTop:YES];
						 [self.contentController.view addSubview:self.overlayView];
						 self.menuVisible = YES;
						 if ([self.options[AMOptionsSetButtonDone] boolValue]) {
							 [self.barButton setStyle:UIBarButtonItemStyleDone];
						 }
                         [[NSNotificationCenter defaultCenter] postNotificationName:kAMSlideOutDidShow object:self];
					 }];
	
}

- (void)hideSideMenu
{
    // this animates the view back to the left before telling the app delegate to swap out the MenuViewController
    // it tells the app delegate using the completion block of the animation
    [[NSNotificationCenter defaultCenter] postNotificationName:kAMSlideOutWillHide object:self];
    [UIView animateWithDuration:[self.options[AMOptionsSlideoutTime] floatValue]
						  delay:0
						options:UIViewAnimationOptionCurveEaseInOut
					 animations:^{
						 
						 // Shrink the table
						 if ([self.options[AMOptionsAnimationShrink] boolValue]) {
							 CGFloat value = [self.options[AMOptionsAnimationShrinkValue] floatValue];
							 [self.tableView setTransform:CGAffineTransformMakeScale(1-value, 1-value)];
						 }
						 
						 // Table fadeout animation
						 if ([self.options[AMOptionsAnimationDarken] boolValue]) {
							 CGFloat value = [self.options[AMOptionsAnimationDarkenValue] floatValue];
							 [self.darkView setAlpha:value];
						 }
						 
						 // Slide the table
						 if ([self.options[AMOptionsAnimationSlide] boolValue]) {
							 CGRect tableFrame = self.tableView.frame;
							 tableFrame.origin.x = -[self.options[AMOptionsSlideValue] floatValue];
							 tableFrame.origin.x = tableFrame.origin.x * [self.options[AMOptionsAnimationSlidePercentage] floatValue];
							 [self.tableView setFrame:tableFrame];
						 }
						 
						 // Move back the NavigationController
						 CGRect frame = self.contentController.view.frame;
						 frame.origin.x = 0;
						 self.contentController.view.frame = frame;
					 }
                     completion:^(BOOL finished) {
						 [self.overlayView removeFromSuperview];
						 self.menuVisible = NO;
						 [self.tableView setScrollsToTop:NO];
						 [self.barButton setStyle:UIBarButtonItemStylePlain];
                         [[NSNotificationCenter defaultCenter] postNotificationName:kAMSlideOutDidHide object:self];
					 }];
}

- (void)handleTap:(UITapGestureRecognizer *)gestureRecognizer
{
    // A single tap hides the slide menu
    [self hideSideMenu];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
	return [self.options[AMOptionsEnableGesture] boolValue];
}

/* The following is from
 http://blog.shoguniphicus.com/2011/06/15/working-with-uigesturerecognizers-uipangesturerecognizer-uipinchgesturerecognizer/
 as mentioned by Nick Harris, in his approach to slide-out navigation:
 http://nickharris.wordpress.com/2012/02/05/ios-slide-out-navigation-code/
 */
- (void)handlePan:(UIPanGestureRecognizer *)gesture;
{
	// The pan gesture moves horizontally the view
    UIView *piece = self.contentController.view;
    [self adjustAnchorPointForGestureRecognizer:gesture];
    
    if ([gesture state] == UIGestureRecognizerStateBegan || [gesture state] == UIGestureRecognizerStateChanged) {
        
        CGPoint translation = [gesture translationInView:[piece superview]];
        [piece setCenter:CGPointMake([piece center].x + translation.x, [piece center].y)];
		if (piece.frame.origin.x < 0) {
			[piece setFrame:CGRectMake(0, piece.frame.origin.y, piece.frame.size.width, piece.frame.size.height)];
		}
		if (piece.frame.origin.x > 320) {
			[piece setFrame:CGRectMake(320, piece.frame.origin.y, piece.frame.size.width, piece.frame.size.height)];
		}
        [gesture setTranslation:CGPointZero inView:[piece superview]];
		
		// Shrink the table
		if ([self.options[AMOptionsAnimationShrink] boolValue]) {
			CGFloat value = [self.options[AMOptionsAnimationShrinkValue] floatValue];
			CGFloat scale = piece.frame.origin.x / [self.options[AMOptionsSlideValue] floatValue];
			scale = scale > 1 ? 1 : scale;
			scale = (1 - value) + value * scale;
			[self.tableView setTransform:CGAffineTransformMakeScale(scale, scale)];
		}
		
		// Table fadeout animation
		if ([self.options[AMOptionsAnimationDarken] boolValue]) {
			CGFloat value = [self.options[AMOptionsAnimationDarkenValue] floatValue];
			CGFloat scale = piece.frame.origin.x / [self.options[AMOptionsSlideValue] floatValue];
			scale = scale > value ? value : scale;
			scale = value - scale;
			[self.darkView setAlpha:scale];
		}
		
		// Move the table if needed
		if ([self.options[AMOptionsAnimationSlide] boolValue]) {
			CGFloat maxValue = piece.frame.origin.x;
			if (maxValue > [self.options[AMOptionsSlideValue] floatValue]) {
				maxValue = [self.options[AMOptionsSlideValue] floatValue];
			}
			CGRect frame = self.tableView.frame;
			frame.origin.x = maxValue - [self.options[AMOptionsSlideValue] floatValue];
			frame.origin.x = frame.origin.x * [self.options[AMOptionsAnimationSlidePercentage] floatValue];
			[self.tableView setFrame:frame];
		}
    }
    else if ([gesture state] == UIGestureRecognizerStateEnded) {
		// Hide the slide menu only if the view is released under a certain threshold, the threshold is lower when the menu is hidden
		float threshold;
		if (self.menuVisible) {
			threshold = [self.options[AMOptionsSlideValue] floatValue];
		} else {
			threshold = [self.options[AMOptionsSlideValue] floatValue] / 2;
		}
        
		if (self.contentController.view.frame.origin.x < threshold) {
			[self hideSideMenu];
		} else {
			[self showSideMenu];
		}
	}
}

- (void)adjustAnchorPointForGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
        UIView *piece = self.contentController.view;
        CGPoint locationInView = [gestureRecognizer locationInView:piece];
        CGPoint locationInSuperview = [gestureRecognizer locationInView:piece.superview];
        
        piece.layer.anchorPoint = CGPointMake(locationInView.x / piece.bounds.size.width, locationInView.y / piece.bounds.size.height);
        piece.center = locationInSuperview;
    }
}

- (void)setMenuScrollingEnabled:(BOOL)enabled
{
	// Please note: call this method AFTER the view loaded, to make sure that the tableView was created
	if (self.tableView.contentSize.height < self.tableView.frame.size.height) {
		[self.tableView setScrollEnabled:enabled];
		[self.tableView setAlwaysBounceVertical:enabled];
	}
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return YES;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    self.tableView.frame = [self tableRect];
	[self setMenuScrollingEnabled:![self.options[AMOptionsDisableMenuScroll] boolValue]];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
	[self setTableView:nil];
	[self setContentController:nil];
	[self.overlayView removeGestureRecognizer:self.tapGesture];
    [self.overlayView removeGestureRecognizer:self.panGesture];
	self.tapGesture = nil;
	self.panGesture = nil;
	self.overlayView = nil;
	self.barButton = nil;
}

@end
