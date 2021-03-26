//
//  IntroController.m
//  TechAssistant
//
//  Copyright © 2013-2021 B2Innovation, L.L.C. All rights reserved
//  Created by Jason Cusack on 09/03/18
//

#import "IntroController.h"

#define SYSTEM_VERSION_EQUAL_TO(v)                  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedSame)
#define SYSTEM_VERSION_GREATER_THAN(v)              ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedDescending)
#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN(v)                 ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN_OR_EQUAL_TO(v)     ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedDescending)

@interface IntroController ()

@end

@implementation IntroController

-(void) showAlert:(NSString*) title withText:(NSString*) message {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title
                                                                             message:message
                                                                      preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"THANK YOU"
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction *action) {
        [alertController dismissViewControllerAnimated:YES completion:nil];
    }];
    
    [alertController addAction:okAction];
    [self presentViewController:alertController animated:YES completion:nil];
}

//simplified front end to funnel user into workload
-(void) setBarButtons {
    NSString *version = [[NSBundle mainBundle] infoDictionary][(NSString *)kCFBundleVersionKey];
    NSString *productName = [NSString stringWithFormat:@"%@© %@", [AppDelegate deliverProductName], version];
    self.navigationItem.title = productName;
    self.cloudButton.hidden = YES;
    self.cloudCompleteButton.hidden = YES;
    self.cloudOfflineButton.hidden = YES;
    
    NSMutableArray *upperLeftBarButtons = [NSMutableArray array];
    NSMutableArray *upperRightBarButtons = [NSMutableArray array];
    NSMutableArray *bottomBarButtons = [NSMutableArray array];
    UIBarButtonItem *flexibleSpaceItem = [UIBarButtonItem flexibleItem];
    
    UIButton *logInButton =[UIButton buttonWithType:UIButtonTypeSystem];
    UIImage *logInImage = [UIImage imageNamed:@"logIn100.png"];
    [logInButton addTarget:self action:@selector(logIn:) forControlEvents:UIControlEventTouchUpInside];
    [logInButton setImage:logInImage forState:UIControlStateNormal];
    NSLayoutConstraint *heightConstraint = [NSLayoutConstraint constraintWithItem:logInButton attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:32];
    NSLayoutConstraint *widthConstraint = [NSLayoutConstraint constraintWithItem:logInButton attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:32];
    [heightConstraint setActive:TRUE];
    [widthConstraint setActive:TRUE];
    UIBarButtonItem *logInBarButtonItem = [[UIBarButtonItem alloc]initWithCustomView:logInButton];
    
    UIButton *menuButton=[UIButton buttonWithType:UIButtonTypeSystem];
    UIImage *menuImage = [UIImage imageNamed:@"lines128.png"];
    [menuButton addTarget:self action:@selector(menuButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    [menuButton setImage:menuImage forState:UIControlStateNormal];
    heightConstraint = [NSLayoutConstraint constraintWithItem:menuButton attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:32];
    widthConstraint = [NSLayoutConstraint constraintWithItem:menuButton attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:32];
    [heightConstraint setActive:TRUE];
    [widthConstraint setActive:TRUE];
    UIBarButtonItem *menuItem = [[UIBarButtonItem alloc]initWithCustomView:menuButton];
    
    UIButton *aboutUsButton =[UIButton buttonWithType:UIButtonTypeSystem];
    UIImage *aboutUsImage = [UIImage imageNamed:@"about128.png"];
    [aboutUsButton addTarget:self action:@selector(goToProductsPage:) forControlEvents:UIControlEventTouchUpInside];
    [aboutUsButton setImage:aboutUsImage forState:UIControlStateNormal];
    heightConstraint = [NSLayoutConstraint constraintWithItem:aboutUsButton attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:24];
    widthConstraint = [NSLayoutConstraint constraintWithItem:aboutUsButton attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:24];
    [heightConstraint setActive:TRUE];
    [widthConstraint setActive:TRUE];
    UIBarButtonItem *aboutUsItem = [[UIBarButtonItem alloc]initWithCustomView:aboutUsButton];
    
    UIBarButtonItem *legalBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"legal", @"legal")
                                                                          style:UIBarButtonItemStyleBordered
                                                                         target:self
                                                                         action:@selector(goToLegalPage:)];
    
    [upperLeftBarButtons addObject:menuItem];
    
    [bottomBarButtons addObject:flexibleSpaceItem];
    [bottomBarButtons addObject:logInBarButtonItem];
    [bottomBarButtons addObject:flexibleSpaceItem];
    
    self.navigationItem.leftBarButtonItems = upperLeftBarButtons;
    [self setToolbarItems:[NSArray arrayWithArray:bottomBarButtons] animated:YES];
}

//clients requesting users engage with updated iOS
-(void) outOfDateAlert {
    if ([AppDelegate throwOutOfDateWarning]) {
        NSLog(@"INTRO VIEW CONTROLLER: upload ready alert: true");
    } else {
        NSLog(@"INTRO VIEW CONTROLLER: upload ready alert: false");
        return;
    }
    
    NSString *version = [[NSBundle mainBundle] infoDictionary][(NSString *)kCFBundleVersionKey];
    NSString *showVersion = [NSString stringWithFormat:@"%@: %@: %@", [AppDelegate deliverCompanyName], [AppDelegate deliverProductName], version];
    NSString *alertMessage = [NSString stringWithFormat:@"\n%@ was designed to run on a modern operating system.\n\nPlease run 'Software Update' to update your iPad to the latest iOS inside the 'General' tab of the 'Settings' app.", showVersion];
    UIAlertController *outOfDateAlert = [UIAlertController alertControllerWithTitle:@"iOS OUT OF DATE"
                                                                              message:alertMessage
                                                                       preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *thankYouAction = [UIAlertAction actionWithTitle:@"Thank You"
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction *action) {
        [outOfDateAlert dismissViewControllerAnimated:YES completion:nil];
    }];
                                
    [outOfDateAlert addAction:thankYouAction];
    [self presentViewController:outOfDateAlert animated:YES completion:nil];
}

//KVOs
- (void)viewDidLoad {
    [super viewDidLoad];
    
    [BoxSynchronizer sharedSynchronizer];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateJobListComplete:)
                                                 name:@"com.cusoft.updateJobListComplete"
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(logInReady:)
                                                 name:@"com.cusoft.logInReady"
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(acceptedLegal:)
                                                 name:@"com.cusoft.acceptedLegal"
                                               object:nil];
    
    if (![LegalController wasLegalAgreed]) {
        [self goToLegal];
    }
    if([[UIDevice currentDevice].model isEqualToString:@"iPhone"]) {
        self.brandNameLabel.text = @"B2Innovation Presents";
    } else {
        self.brandNameLabel.text = @"B2Innovation Presents: The→Flow→Through→Process";
    }
}

- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    self.logInAlert = nil;
    self.loginButton = nil;
    self.brandNameLabel = nil;
    self.cloudButton = nil;
    self.cloudCompleteButton = nil;
    self.cloudOfflineButton = nil;
    self.processingButton = nil;
}

- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

//credentials accepted
- (void)showJobsPage {
    UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"TechAssistant" bundle: nil];
    SelectJob *jobsPageController = (SelectJob *)[mainStoryboard instantiateViewControllerWithIdentifier: @"JobsPage"];
    [self.navigationController pushViewController:jobsPageController animated:YES];
}
    
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (!self) {
        return nil;
    }
    return self;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

//halt animations and run login window
-(void) logIn {
    [self stopProcessingBlink];
    if ([self.navigationController.visibleViewController isKindOfClass:[UIAlertController class]]) {
        return;
    }
    
    NSLog(@"-LOG IN iOS %@-", [AppDelegate deliverIosVersion]);
    
    if(self.logInAlert) {//just present again, minus password
        NSArray *textfields = self.logInAlert.textFields;
        [textfields[1] setText:@""];
        [self presentViewController:self.logInAlert animated:YES completion:nil];
    } else {//build it manually from scratch otherwise
        NSString *version = [[NSBundle mainBundle] infoDictionary][(NSString *)kCFBundleVersionKey];
        NSString *insertVersionString = [NSString stringWithFormat:@"%@ %@", [AppDelegate deliverProductName], version];
        
        self.logInAlert = [UIAlertController alertControllerWithTitle: @"WELCOME\n"
                                                              message: insertVersionString
                                                       preferredStyle: UIAlertControllerStyleAlert];
        
        [self.logInAlert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
            textField.placeholder = [NSString stringWithFormat:@"%@ user", [AppDelegate deliverProductName]];
            textField.textColor = [UIColor blackColor];
            textField.borderStyle = UITextBorderStyleRoundedRect;
            textField.secureTextEntry = NO;
        }];
        [self.logInAlert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
            textField.placeholder = @"Secure Passphrase";
            textField.textColor = [UIColor blackColor];
            textField.borderStyle = UITextBorderStyleRoundedRect;
            textField.secureTextEntry = YES;
        }];
        
        NSArray * textfields = self.logInAlert.textFields;
        UITextField *nameField = textfields[0];
        UITextField *passwordField = textfields[1];
        [nameField setText:((AppDelegate *) [UIApplication sharedApplication].delegate).currentUser];
        nameField.autocorrectionType = UITextAutocorrectionTypeNo;
        nameField.keyboardType = UIKeyboardTypeDefault;
        passwordField.autocorrectionType = UITextAutocorrectionTypeNo;
        passwordField.keyboardType = UIKeyboardTypeASCIICapable;
        
        UIAlertAction *buttonOnAlertLogIn = [UIAlertAction actionWithTitle:@"Login" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            NSString* userName = nameField.text;
            NSString* password = passwordField.text;
            AppDelegate* delegate = (AppDelegate *) [UIApplication sharedApplication].delegate;
            NSLog(@"User name: %@.", userName);
            
            if ([userName isEqual:@""]||userName==nil||[delegate.fieldEngineerDictionary objectForKey:userName] == nil) {
                NSLog(@"User name %@ does not exist in downloaded data.\n%@", userName, delegate.fieldEngineerDictionary);
                [self showAlert:@"Invalid User" withText:[NSString stringWithFormat:@"User name %@ does not exist in the data from the cloud. Either re-try your user name or please try again with an improved internet connection. Thank you!", userName]];
                return;
            } else {
                FieldEngineer* engineer = [delegate.fieldEngineerDictionary objectForKey:userName];
                assert(engineer != nil);
                if (![password isEqualToString:engineer.password]) {
                    [self showAlert:[NSString stringWithFormat:@"User name: %@ found!", userName] withText:@"We apologize. That password does not match our records. Please retry."];
                    return;
                }
            }
            ((AppDelegate *) [UIApplication sharedApplication].delegate).currentUser = nameField.text;
            [self checkJobForUser:userName];
        }];
        
        UIAlertAction *buttonOnAlertReInit = [UIAlertAction actionWithTitle:@"Check For New Jobs" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [self boxAPIInitiateLogin];
            
            UIPasteboard *pb = [UIPasteboard generalPasteboard];
            [pb setValue:@"" forPasteboardType:UIPasteboardNameGeneral];
            
            [self dismissViewControllerAnimated:YES completion:nil];
            [self reInitNotification];
        }];
        
        [buttonOnAlertLogIn setValue:[[UIImage imageNamed:@"logIn32.png"] imageWithRenderingMode:UIImageRenderingModeAutomatic] forKey:@"image"];
        [buttonOnAlertReInit setValue:[[UIImage imageNamed:@"cloudRefresh32.png"] imageWithRenderingMode:UIImageRenderingModeAutomatic] forKey:@"image"];
        [self.logInAlert addAction:buttonOnAlertLogIn];
        [self.logInAlert addAction:buttonOnAlertReInit];

        [self presentViewController:self.logInAlert animated:YES completion:nil];
    }
}

//user is manually refreshing from the cloud
- (void)reInitNotification {
    [self startBlink];
    
    /*UIAlertController * alertController = [UIAlertController alertControllerWithTitle: @"PLEASE WAIT"
                                                                              message: @"Downloading all relevant files now... this will take a moment."
                                                                       preferredStyle: UIAlertControllerStyleAlert];
    
    UIAlertAction *buttonOK = [UIAlertAction actionWithTitle:@"Thank You" style:UIAlertActionStyleDefault
                                                               handler:^(UIAlertAction *action) {
                                                                   
                                                               }];
    
    [alertController addAction:buttonOK];
    
    [self presentViewController:alertController animated:YES completion:nil];*/
}

//user manually tapped login without waiting for automated process
- (IBAction)logIn:(id)sender {
    [self logIn];
}

//user requested legal page
- (IBAction) goToLegalPage:(id) sender {
    UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"TechAssistant" bundle: nil];
    LegalController *onwardController = (LegalController *)[mainStoryboard instantiateViewControllerWithIdentifier: @"LegalPage"];
    [self.navigationController pushViewController:onwardController animated:YES];
}

//user has not agreed to legal
- (void) goToLegal {
    UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"TechAssistant" bundle: nil];
    LegalController *onwardController = (LegalController *)[mainStoryboard instantiateViewControllerWithIdentifier: @"LegalPage"];
    [self.navigationController pushViewController:onwardController animated:YES];
}

- (IBAction) goToProductsPage:(id) sender {
    UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"TechAssistant" bundle: nil];
    LegalController *onwardController = (LegalController *)[mainStoryboard instantiateViewControllerWithIdentifier: @"ProductsPage0"];
    [self.navigationController pushViewController:onwardController animated:YES];
}

- (IBAction) goToSalesForce:(id) sender {
    UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"TechAssistant" bundle: nil];
    LegalController *onwardController = (LegalController *)[mainStoryboard instantiateViewControllerWithIdentifier: @"SalesForcePage"];
    [self.navigationController pushViewController:onwardController animated:YES];
}

#pragma mark - Popovers

- (void) dismissPopoverAnimated:(BOOL)animated {
}

- (void) dismissPopover {
    [self dismissPopoverAnimated:YES];
}

- (void) popoverControllerDidDismissPopover:(UIPopoverController *)popoverController {
    
}

- (void)didDismissModalView {
    [self dismissViewControllerAnimated:YES completion:nil];
}

//user has entered info into all fields
- (void)checkJobForUser:(NSString *)userName {
    AppDelegate* delegate = (AppDelegate *) [UIApplication sharedApplication].delegate;
    FieldEngineer* engineer = [delegate.fieldEngineerDictionary objectForKey:userName];
    NSMutableArray* jobs = engineer.assignedJobs;
    if ( jobs == nil || [jobs count] == 0) {
        [self showAlert:@"NO JOBS ASSIGNED?" withText:[NSString stringWithFormat:@"\nNothing has been found for:  %@.\n\nNothing has been assigned to you yet, or this iPad/iPhone is having difficulty with your current network connection. Please try again after double checking with your admin.\n\nTHANK YOU", userName]];
        return;
    }
    ((AppDelegate *) [UIApplication sharedApplication].delegate).currentJobs = jobs;
    
    //get 2nd page display addresses
    NSMutableArray* addresses = engineer.assignedAddresses;
    ((AppDelegate *) [UIApplication sharedApplication].delegate).currentAddresses = addresses;
    
    [self showJobsPage];
    
    [[NSUserDefaults standardUserDefaults] setObject:((AppDelegate *) [UIApplication sharedApplication].delegate).currentUser forKey:@"CurrentUser"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

//run animations before window appears
- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    /*dispatch_async(dispatch_get_main_queue(), ^{
        AppDelegate *delegate = (AppDelegate *) [UIApplication sharedApplication].delegate;
        NSLog(@"INTRO CONTROLLER: Dictionary: %@.", delegate.surveyDataDictionary);
    });*/
    
    [self outOfDateAlert];
    [self hideBar];
    [self startProcessingBlink];
    [self setBarButtons];
}

//begin reading current jobs
-(void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [self supportedInterfaceOrientations];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"com.cusoft.parseUsersList" object:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"com.cusoft.parseUserJobList" object:nil];
}

//does the client allow user to use software in both landscape AND portrait mode?
-(BOOL) shouldAutorotate {
    return YES;
}

-(NSUInteger) supportedInterfaceOrientations {
    return (UIInterfaceOrientationMaskPortrait);
}

//allow user login
-(void) showBar {
    [self.navigationController setToolbarHidden:NO animated:YES];
    [self.navigationController setNavigationBarHidden:NO animated:YES];
    self.navigationController.navigationBar.translucent = NO;
    self.navigationController.toolbar.translucent = NO;
}

//if navigating here from a toolbar class
-(void) hideBar {
    [self.navigationController setToolbarHidden:YES animated:YES];
    [self.navigationController setNavigationBarHidden:NO animated:YES];
    self.navigationController.navigationBar.translucent = NO;
    self.navigationController.toolbar.translucent = NO;
}

//ready for login
-(void) updateJobListComplete:(NSNotification *)notification {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"com.cusoft.parseUsersList" object:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"com.cusoft.parseUserJobList" object:nil];
}

-(void) logInReady:(NSNotification *)notification {
    [self showBar];
    
    if ([LegalController wasLegalAgreed]) {
        [self logIn];
    }
    [self stopBlink];
}

//iphone specific menu
-(IBAction) menuButtonPressed:(id)sender {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Welcome Options"
                                                                             message:@"\nPlease select one."
                                                                      preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *aboutAction = [UIAlertAction actionWithTitle:@"About B2"
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction *action) {
        [alertController dismissViewControllerAnimated:YES completion:nil];
        [self goToProductsPage:nil];
    }];
    
    UIAlertAction *legalAction = [UIAlertAction actionWithTitle:@"Legal"
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction *action) {
        [alertController dismissViewControllerAnimated:YES completion:nil];
        [self goToLegalPage:nil];
    }];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                       style:UIAlertActionStyleCancel
                                                     handler:^(UIAlertAction *action) {
        [alertController dismissViewControllerAnimated:YES completion:nil];
    }];
    
    [alertController addAction:aboutAction];
    [aboutAction setValue:[[UIImage imageNamed:@"about32.png"] imageWithRenderingMode:UIImageRenderingModeAutomatic] forKey:@"image"];
    [alertController addAction:legalAction];
    [alertController addAction:cancelAction];
    
    [self presentViewController:alertController animated:YES completion:nil];
}

//notify user of last instance of full cloud sync
-(void) dateEntry {
    [AppDelegate playSave];
    NSDate *currDate = [NSDate date];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc]init];
    [dateFormatter setDateFormat:@"MM.dd.YYYY HH:mm:ss"];
    NSString *dateString = [dateFormatter stringFromDate:currDate];
    NSLog(@"Entered date: %@",dateString);
    
    NSString *version = [[NSBundle mainBundle] infoDictionary][(NSString *)kCFBundleVersionKey];
    NSString *insertVersionString = [NSString stringWithFormat:@"%@ %@\n\nJobs updated %@", [AppDelegate deliverProductName], version, dateString];
    if(self.logInAlert) {
        self.logInAlert.message = insertVersionString;
    }
}

//animate and consume API
- (void) boxAPIInitiateLogin {
    [self startBlink];
    
    BOXContentClient *contentClient = [BOXContentClient defaultClient];
    [contentClient authenticateWithCompletionBlock:^(BOXUser *user, NSError *error) {
            if(error) {
                NSLog(@"User cancellation? Failed with error %@.", error);
                [self oopsNotification];
                [[NSNotificationCenter defaultCenter] postNotificationName:@"com.cusoft.parseUsersList" object:nil];
                [[NSNotificationCenter defaultCenter] postNotificationName:@"com.cusoft.parseUserJobList" object:nil];
            } else {
                NSLog(@"Login succeeded with user %@.", user);
                [[NSNotificationCenter defaultCenter] postNotificationName:@"com.cusoft.updateJobsList" object:nil];
                [self dateEntry];
            }
    }];
}

//first time use
- (void)acceptedLegal:(NSNotification *)notification {
    [self startBlink];

    BOXContentClient *contentClient = [BOXContentClient defaultClient];
    [contentClient authenticateWithCompletionBlock:^(BOXUser *user, NSError *error) {
        if(error) {
            NSLog(@"User cancellation? Failed with error %@.", error);
            [self oopsNotification];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"com.cusoft.parseUsersList" object:nil];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"com.cusoft.parseUserJobList" object:nil];
        } else {
            NSLog(@"Login succeeded with user %@.", user);
            [[NSNotificationCenter defaultCenter] postNotificationName:@"com.cusoft.updateJobsList" object:nil];
            [self dateEntry];
        }
    }];
}

//Find a Starbucks
- (void)oopsNotification {
    UIAlertController * alertController = [UIAlertController alertControllerWithTitle: @"Offline Mode" message: @"Using previously saved cloud files, if already available on this iPad/iPhone." preferredStyle: UIAlertControllerStyleAlert];
    
    UIAlertAction *buttonOK = [UIAlertAction actionWithTitle:@"Thank You" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self logIn];
    }];
    
    [alertController addAction:buttonOK];
    
    [self presentViewController:alertController animated:YES completion:nil];
    [self stopBlink];
    
    self.cloudCompleteButton.hidden=TRUE;
    self.cloudButton.hidden=TRUE;
    self.cloudOfflineButton.hidden=FALSE;
}

//animations
#pragma mark blink effect
- (void)startBlink {
    self.cloudCompleteButton.hidden=TRUE;
    self.cloudButton.hidden=FALSE;
    
    self.cloudButton.alpha = 1.0f;
    [UIView animateWithDuration:0.5
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionRepeat | UIViewAnimationOptionAutoreverse | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
                         self.cloudButton.alpha = 0.0f;
                     }
                     completion:^(BOOL finished){
                     }];
}

- (void)stopBlink {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.cloudCompleteButton.hidden=FALSE;
        self.cloudButton.hidden=TRUE;
        
        [UIView animateWithDuration:0.1
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
                             self.cloudButton.alpha = 1.0f;
                         }
                         completion:^(BOOL finished){
                         }];
    });
}

- (void)startProcessingBlink {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.cloudButton.hidden=TRUE;
        self.cloudCompleteButton.hidden=TRUE;
        self.cloudOfflineButton.hidden=TRUE;
        self.processingButton.hidden=FALSE;
    
        self.processingButton.alpha = 1.0f;
        [UIView animateWithDuration:0.5
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionRepeat | UIViewAnimationOptionAutoreverse | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
                             self.processingButton.alpha = 0.0f;
                         } completion:^(BOOL finished){
                         }];
    });
}

- (void)stopProcessingBlink {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.cloudButton.hidden=TRUE;
        self.cloudCompleteButton.hidden=FALSE;
        self.cloudOfflineButton.hidden=TRUE;
        self.processingButton.hidden=TRUE;
        
        [UIView animateWithDuration:0.1
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
                             self.processingButton.alpha = 1.0f;
                         } completion:^(BOOL finished){
                         }];
    });
}

@end
