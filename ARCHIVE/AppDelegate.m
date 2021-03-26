//
//  AppDelegate.m
//  TechAssistant
//
//  Copyright © 2013-2021 B2Innovation, L.L.C.
//  Created by Jason Cusack on 11/09/18
//

#import "AppDelegate.h"
#import "KeychainItemWrapper.h"
#import "ALAssetsLibrary+CustomPhotoAlbum.h"
#import "CustomNavController.h"
#import "FieldEngineer.h"

#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreLocation/CoreLocation.h>

#include <stdlib.h>

#define REFRESH_TOKEN_KEY   (@"box_api_refresh_token")

#define SYSTEM_VERSION_EQUAL_TO(v)                  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedSame)
#define SYSTEM_VERSION_GREATER_THAN(v)              ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedDescending)
#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN(v)                 ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN_OR_EQUAL_TO(v)     ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedDescending)

@interface AppDelegate ()

@property (nonatomic, readwrite, strong) KeychainItemWrapper *keychain;

@end

@implementation AppDelegate {
    CLLocationManager *locationManager;
    CLGeocoder *geocoder;
}

@synthesize window;
@synthesize surveyDataDictionary;
@synthesize poleDataDictionary;

//encrypting user data locally
@synthesize keychain = _keychain;

#pragma mark -
#pragma mark Application lifecycle

+(void) playFanfare {
    //warning
    //AudioServicesPlayAlertSound;
    
    //chime
    //AudioServicesPlaySystemSound(1109);
    
    //fanfare / successful cloud package delivery
    AudioServicesPlaySystemSound(1328);
}

+(void) playSave {//reassuring user every page flip has saved their data successfully with a subtle audible "clap"
    int randomNumber = arc4random_uniform(5);
    NSLog(@"APP DELEGATE: random chime sound %d called.", randomNumber);
    CFURLRef soundFileURLRef;
    switch (randomNumber) {
        case 0:
            soundFileURLRef = CFBundleCopyResourceURL (CFBundleGetMainBundle (),CFSTR ("Npc_CommonClap01"),CFSTR ("wav"),NULL );
            break;
        case 1:
            soundFileURLRef = CFBundleCopyResourceURL (CFBundleGetMainBundle (),CFSTR ("Npc_CommonClap02"),CFSTR ("wav"),NULL );
            break;
        case 2:
            soundFileURLRef = CFBundleCopyResourceURL (CFBundleGetMainBundle (),CFSTR ("Npc_CommonClap03"),CFSTR ("wav"),NULL );
            break;
        case 3:
            soundFileURLRef = CFBundleCopyResourceURL (CFBundleGetMainBundle (),CFSTR ("Npc_CommonClap04"),CFSTR ("wav"),NULL );
            break;
        default:
            soundFileURLRef = CFBundleCopyResourceURL (CFBundleGetMainBundle (),CFSTR ("Npc_CommonClap05"),CFSTR ("wav"),NULL );
    }
    
    SystemSoundID chimeObject;
    AudioServicesCreateSystemSoundID (soundFileURLRef, &chimeObject);
    AudioServicesPlaySystemSound (chimeObject);
    
    AudioServicesPlaySystemSoundWithCompletion(chimeObject, ^{
        AudioServicesDisposeSystemSoundID(chimeObject);
    });
}

//system architecture warning pop up for user
+(NSString *) deliverIosVersion {
    NSString *iosVersion;
    
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"11.0")) {
        iosVersion = @"x64";
    } else if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0")) {
        iosVersion = @"x86 & x64";
    } else {
    	iosVersion = @"x86";
    }
    return iosVersion;
}

//global strings for iterative marketing
+(NSString *) deliverCompanyName {
    NSString *pageData = @"B2 Innovation";
    return pageData;
}

+(NSString *) deliverProductName {
    NSString *pageData = @"TechAssistant";
    return pageData;
}

//pole photos
+(float) deliverPhotosCompressionRatio {
    float compressionRatio = 0.75f;
    return compressionRatio;
}

//MapKit -> JPG
+(float) deliverMapsCompressionRatio {
    float compressionRatio = 0.9f;
    return compressionRatio;
}

+(NSString *) deliverCompanyWebsite {
    NSString *pageData = @"https://www.b2innovation.com/";
    return pageData;
}

+(NSString *) defaultPoleCount {
    NSString *pageData = @"99";
    return pageData;
}

//cloud addresses
+(NSString *) boxMasterPage {
    NSString *pageData = @"11774172390";
    return pageData;
}

+(NSString *) boxInputPage {
    NSString *pageData = @"11774176742";
    return pageData;
}

+(NSString *) boxListsPage {
    NSString *pageData = @"11774175718";
    return pageData;
}

+(NSString *) boxTemplatesPage {
    NSString *pageData = @"11774177766";
    return pageData;
}

+(NSString *) boxEmailedPage {
    NSString *pageData = @"11774177510";
    return pageData;
}

+(NSString *) boxEmailAddress {
    NSString *pageData = @"Emailed.66jv998kkwmhtqpw@u.box.com";
    return pageData;
}

+(NSString *) boxOutputPage {
    NSString *pageData = @"11774175974";
    return pageData;
}

+(NSString *) boxOutputTemplateFile {
    NSString *fileData = @"Output Template.xlsx";
    return fileData;
}

+(NSString *) boxInputJobsFile {
    NSString *fileData = @"Input Info.xlsx";
    return fileData;
}

//automated output email CC
+(NSArray *) deliverRecipients {
    NSArray *ccRecipients = [NSArray arrayWithObjects:@"contactus@b2innovation.com", nil];
    return ccRecipients;
}

//updated to client need
+(BOOL) throwOutOfDateWarning {
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"14.0")) {
        return FALSE;
    } else {
        return TRUE;
    }
}

//all photos in TechAssistant to be output using identical dimensions
+(UIImage*) resizeImage:(UIImage*)image fromCamera:(BOOL)fromCamera {
    float imageHeightFloat = image.size.height;
    float imageWidthFloat = image.size.width;
    
    if(imageHeightFloat>imageWidthFloat) {
        imageHeightFloat = 1050;
        imageWidthFloat = 750;
    } else {
        imageHeightFloat = 750;
        imageWidthFloat = 1050;
    }
    NSLog(@"APP DELEGATE: Generating 150DPI 5x7 : Initial=%.0fx%.0f. Final=5x7 %.0fx%.0f.", image.size.height, image.size.width, imageHeightFloat, imageWidthFloat);
    
    CGRect rect = CGRectMake(0.0, 0.0, imageWidthFloat, imageHeightFloat);
    UIGraphicsBeginImageContext(rect.size);
    [image drawInRect:rect];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return img;
}

//global setup of fonts
- (void)customizeAppearance {
    [UIButton buttonWithType:UIButtonTypeSystem];
    
    [[UINavigationBar appearance] setTitleTextAttributes:
     [NSDictionary dictionaryWithObjectsAndKeys:
      [UIColor colorWithRed:0.0/255.0 green:0.0/255.0 blue:0.0/255.0 alpha:0.5],
      UITextAttributeTextColor,
      [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.0],
      UITextAttributeTextShadowColor,
      [NSValue valueWithUIOffset:UIOffsetMake(0, 0)],
      UITextAttributeTextShadowOffset,
      [UIFont fontWithName:@"IowanOldStyle-Roman" size:18.0],
      UITextAttributeFont,
      nil]];
    
    [[UIBarButtonItem appearanceWhenContainedIn:[UINavigationBar class], nil] setTitleTextAttributes:
     @{UITextAttributeTextColor:[UIColor colorWithRed:0.0/255.0 green:100.0/255.0 blue:255.0/255.0 alpha:0.8],
       UITextAttributeTextShadowOffset:[NSValue valueWithUIOffset:UIOffsetMake(0, 0)],
       UITextAttributeTextShadowColor:[UIColor whiteColor],
       UITextAttributeFont:[UIFont fontWithName:@"IowanOldStyle-Roman" size:18.0]
       }forState:UIControlStateNormal];
    
    UIFont *font = [UIFont fontWithName:@"IowanOldStyle-Roman" size:18.0];
    NSDictionary *attributes = [NSDictionary dictionaryWithObject:font
                                                           forKey:NSFontAttributeName];
    [[UISegmentedControl appearance] setTitleTextAttributes:attributes forState:UIControlStateNormal];
}

//landscape and portrait mode globals
-(NSUInteger) application:(UIApplication *)application supportedInterfaceOrientationsForWindow:(UIWindow *)window {
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskLandscape;
}

//no more retain cycles
-(void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    self.surveyDataDictionary = nil;
    self.userJobsDictionary = nil;
    self.userAddressesDictionary = nil;
    self.fieldEngineerDictionary = nil;
    self.poleDataDictionary = nil;
    
    self->locationManager_ = nil;
    locationManager_ = nil;
}

//cloud tokens saved to keychain
- (void)setRefreshTokenInKeychain:(NSString *)refreshToken {
    [self.keychain setObject:@"TechAssistance" forKey: (__bridge id)kSecAttrService];
    [self.keychain setObject:refreshToken forKey:(__bridge id)kSecValueData];
}

- (void)applicationDidFinishLaunching:(UIApplication *)application {
    //keys changed for portfolio version of file
    [BOXContentClient setClientID:@"098a7sdflkj2q98a7sdlkjcvouiyawtkljasd" clientSecret:@"98345kjhasflkjasoiuy1245oaegrlkjhafsdgp8"];
    
    [BOXContentClient oneTimeSetUpInAppToSupportBackgroundTasksWithDelegate:self
                                                               rootCacheDir:[BOXSampleAppSessionManager rootCacheDirGivenSharedContainerId:@"com.B2Innovation.TechAssistantInternal"]
                                                                 completion:^(NSError *error) {
        BOXAssert(error == nil, @"Failed to set up to support background tasks with error %@", error);
    }];
    
    locationManager_ = [[CLLocationManager alloc] init];
    locationManager_.delegate = self;
    locationManager_.desiredAccuracy = kCLLocationAccuracyBest;
    locationManager_.distanceFilter = kCLDistanceFilterNone;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [WDFontManager sharedInstance];
    });
    
    self.memoList = [[NSMutableArray alloc] init];
    self.imageList = [[NSMutableArray alloc] init];
    self.bomList = [[NSMutableArray alloc] init];
    
    [self setupDefaults];
    self.currentUser = [[NSUserDefaults standardUserDefaults] stringForKey:@"CurrentUser"];
    [self customizeAppearance];
    
    NSLog(@"appDelegate applicationDidFinishLaunching method running. Login attempting now.");
    
    NSData *returnedData = //copyrighted

    // probably check here that returnedData isn't nil; attempting
    NSString* path = [[NSBundle mainBundle] pathForResource:@"index" ofType:@"json"];
    NSString* jsonString = [[NSString alloc] initWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    NSData* jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSError *jsonError;
    id allKeys = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONWritingPrettyPrinted error:&jsonError];

    for (int i=0; i<[allKeys count]; i++) {
        NSDictionary *arrayResult = [allKeys objectAtIndex:i];
        NSLog(@"name=%@", [arrayResult objectForKey:@"TechAssistant"]);

    }
    
    //grab data from xlsx
    BRAOfficeDocumentPackage *spreadsheet = [BRAOfficeDocumentPackage open : usersPath];
    BRAWorksheet *mainSheet = spreadsheet.workbook.worksheets[1];
    
    self.allPhotosRequired = [NSArray arrayWithObjects: [mainSheet cellForCellReference:A1], nil];
    self.allPhotosMemos = [NSArray arrayWithObjects: [mainSheet cellForCellReference:B1], nil];
    self.leftBomArray = [NSArray arrayWithObjects: [mainSheet cellForCellReference:C1], nil];
    self.rightBomArray = [NSArray arrayWithObjects: [mainSheet cellForCellReference:D1], nil];
    
    [locationManager requestWhenInUseAuthorization];
}

+ (NSString*) convertDictionaryToString:(NSMutableDictionary*) dict {
    NSError* error;
    NSDictionary* tempDict = [dict copy];
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:tempDict
                                                       options:NSJSONReadingMutableLeaves error:&error];
    NSString* nsJson=  [[NSString alloc] initWithData:jsonData
                                             encoding:NSUTF8StringEncoding];
    return nsJson;
}

+(void) saveSurveyDataToLocal {
    if ([(AppDelegate *) [UIApplication sharedApplication].delegate selectedJob] == nil) {
        NSLog(@"Not working on any job, skip saving job data.");
        return;
    } else {
        [self playSave];
    }
    
    NSString *error = nil;
    NSString *drawingsPath = [WDDrawingManager drawingPath];
    NSString *plistPath = [drawingsPath stringByAppendingPathComponent:@"surveyData.plist"];
    
	NSData *plistData = [NSPropertyListSerialization dataFromPropertyList:[(AppDelegate *) [UIApplication sharedApplication].delegate surveyDataDictionary] format:NSPropertyListXMLFormat_v1_0 errorDescription:&error];
	if(plistData) {
		[plistData writeToFile:plistPath atomically:YES];
        //NSLog(@"AppDelegate: Saved Survey Data To %@.", plistPath);
    } else {
        NSLog(@"Error in saveSurveyDataToLocal: %@", error);
    }
}

+(void) savePoleDataToLocal {
    if ([(AppDelegate *) [UIApplication sharedApplication].delegate selectedJob] == nil) {
        NSLog(@"Not working on any job, skip saving job data.");
        return;
    } else {
        [self playSave];
    }
    
    NSString *error = nil;
    NSString *drawingsPath = [WDDrawingManager drawingPath];
    NSString *plistPath = [drawingsPath stringByAppendingPathComponent:@"poleData.plist"];
    
    NSData *plistData = [NSPropertyListSerialization dataFromPropertyList:[(AppDelegate *) [UIApplication sharedApplication].delegate poleDataDictionary] format:NSPropertyListXMLFormat_v1_0 errorDescription:&error];
    if(plistData) {
        [plistData writeToFile:plistPath atomically:YES];
    }
    else {
        NSLog(@"Error in Saving Pole Data To Local: %@", error);
    }
}

#pragma mark - CLLocationManagerDelegate

- (void)stopUpdatingLocation:(NSString *)state {
    [locationManager_ stopUpdatingLocation];
    locationManager_.delegate = nil;
}

//found the user successfully
- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation {
    NSLog(@"location is updated.");
    self.currentLocation = newLocation;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"com.cusoft.locationUpdated" object:newLocation];
    
    CLGeocoder *geocoder = [[CLGeocoder alloc] init];
    [geocoder reverseGeocodeLocation:self.currentLocation
                   completionHandler:^(NSArray *placemarks, NSError *error) {
                       if (error){
                           NSLog(@"Geocode failed with error: %@", error);
                           return;
                           
                       }
                       
                       if(placemarks && placemarks.count > 0) {
                           CLPlacemark *topResult = [placemarks objectAtIndex:0];
                           self.addressText = [NSString stringWithFormat:@"%@ %@,%@ %@",
                                                   [topResult subThoroughfare],[topResult thoroughfare],
                                                   [topResult locality], [topResult administrativeArea]];
                       }
                   }];
    if (newLocation.horizontalAccuracy <= manager.desiredAccuracy) {
        [self stopUpdatingLocation:NSLocalizedString(@"Acquired Location", @"Acquired Location")];
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(stopUpdatingLocation:) object:nil];
    }
}

//files MUST be of proper file type
-(BOOL) validFile:(NSURL *)url {
    WDDrawing *drawing = nil;
    
    @try {
        NSData *data = [NSData dataWithContentsOfURL:url];
        NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
        drawing = [unarchiver decodeObjectForKey:WDDrawingKey];
        [unarchiver finishDecoding];
    } @catch (NSException *exception) {
    } @finally {
    }
    
    return (drawing ? YES : NO);
}

-(BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [self applicationDidFinishLaunching:application];
    
    if (launchOptions) {
        NSURL *url = launchOptions[UIApplicationLaunchOptionsURLKey];
        
        if (url) {
            return [self validFile:url];
        }
    }
    
    return YES;
}

-(void) setupDefaults {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *defaultPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Defaults.plist"];
    [defaults registerDefaults:[NSDictionary dictionaryWithContentsOfFile:defaultPath]];
    
    if (![defaults objectForKey:WDStrokeColorProperty]) {
        NSData *value = [NSKeyedArchiver archivedDataWithRootObject:[WDColor blackColor]];
        [defaults setObject:value forKey:WDStrokeColorProperty];
    }
    
    if (![defaults objectForKey:WDFillProperty]) {
        NSData *value = [NSKeyedArchiver archivedDataWithRootObject:[NSNull null]];
        [defaults setObject:value forKey:WDFillProperty];
    }
    
    if (![defaults objectForKey:WDFillColorProperty]) {
        NSData *value = [NSKeyedArchiver archivedDataWithRootObject:[WDColor whiteColor]];
        [defaults setObject:value forKey:WDFillColorProperty];
    }
    
    if (![defaults objectForKey:WDFillGradientProperty]) {
        NSData *value = [NSKeyedArchiver archivedDataWithRootObject:[WDGradient defaultGradient]];
        [defaults setObject:value forKey:WDFillGradientProperty];
    }
    
    if (![defaults objectForKey:WDStrokeDashPatternProperty]) {
        NSArray *dashes = @[];
        [defaults setObject:dashes forKey:WDStrokeDashPatternProperty];
    }
    
    if (![defaults objectForKey:WDShadowColorProperty]) {
        NSData *value = [NSKeyedArchiver archivedDataWithRootObject:[WDColor colorWithRed:0 green:0 blue:0 alpha:0.333f]];
        [defaults setObject:value forKey:WDShadowColorProperty];
    }
}

@end
