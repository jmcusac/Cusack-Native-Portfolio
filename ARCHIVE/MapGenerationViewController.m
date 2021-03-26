//
//  MapGenerationViewController.m
//  TechAssistant
//
//  Copyright © 2013-2021 B2Innovation, L.L.C. All rights reserved
//  Created by Jason Cusack on 09/16/18
//

#import "MapGenerationViewController.h"

//we need to be at the right default distance in order to view the job
#define ZOOM_LEVEL 17

@interface MapGenerationViewController ()

@end

@implementation MapGenerationViewController

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    self.allFootages = [[NSMutableArray alloc] init];
}

-(void) viewDidLoad {
    [super viewDidLoad];
    
    [self.navigationController setToolbarHidden:YES animated:YES];
    [self setBarButtons];
    [self zoomAction];
    
    self.locationManager.delegate=self;
    self.mapView.delegate=self;
    self.mapView.mapType = MKMapTypeHybrid;
    self.mapVersion=@"Hybrid";
}

- (BOOL) shouldAutorotate {
    return YES;
}

-(void)clearQuickStackForMemory {
    NSMutableArray *navigationArray = [[NSMutableArray alloc] initWithArray: self.navigationController.viewControllers];
        NSLog(@"%d view controllers.", navigationArray.count);
        
        for(int i=0; i<navigationArray.count; i++) {
            NSLog(@"%@ is at index: %d.", [navigationArray objectAtIndex:i], i);
            if ([[navigationArray objectAtIndex:i] isKindOfClass:[MapGenerationViewController class]]){
                NSLog(@"Removing MapGenerationViewController at index %d", i);
                [navigationArray removeObjectAtIndex:i];
                i--;
            }
        }
        self.navigationController.viewControllers = navigationArray;
}

- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    NSLog(@"MAP PAGE: exit called");
    
    self.mapView = nil;
    self.jobDestination = nil;
    self.locationManager = nil;
    self.mapVersion = nil;
    self.routeLine = nil;
    self.totalFootage = nil;
    self.allFootages = nil;
}

//user has searched for a location and we need to zoom out to observe results better
- (void) zoomAction {
    //USA coordinte data
    MKCoordinateRegion region;
    region.span.latitudeDelta = 111;
    region.span.longitudeDelta = 111;
    region.center.latitude = 41;
    region.center.longitude = -94;
    
    //fill job data if present
    if(self.jobDestination.coordinate.latitude!=0) {
        region.center.latitude = self.jobDestination.coordinate.latitude;
        region.span.latitudeDelta = (CGFloat)0.0025;
    }
    if(self.jobDestination.coordinate.longitude!=0) {
        region.center.longitude = self.jobDestination.coordinate.longitude;
        region.span.longitudeDelta = (CGFloat)0.0025;
        NSLog(@"Zooming to coordinates... Lat: %f Long: %f Span: %f", region.center.latitude, region.center.longitude, region.span.longitudeDelta);
    }
    else {
        NSLog(@"USA zoom out... Lat: %f Long: %f Span: %f", region.center.latitude, region.center.longitude, region.span.longitudeDelta);
    }
    
    [self.mapView setRegion:region animated:YES];
}

- (IBAction)goToUser {
    NSLog(@"GO TO USER");
    [self.mapView removeAnnotations:[self.mapView annotations]];
    
    if (self.locationManager == nil) {
        self.locationManager = [[CLLocationManager alloc] init];
        self.locationManager.delegate = self;
    }
    
    if ([self.locationManager respondsToSelector:@selector(requestWhenInUseAuthorization)])
        [self.locationManager requestWhenInUseAuthorization];
    
    self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    [self.locationManager startUpdatingLocation];
}

- (IBAction) goToJob:(id)sender {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"MapIt PRO"
                                                                             message:@"\nPlease choose one."
                                                                      preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *addressAction = [UIAlertAction actionWithTitle:@"GO TO: Job"
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction *action) {
        [alertController dismissViewControllerAnimated:YES completion:nil];
        [self findJob];
    }];
    
    UIAlertAction *customAction = [UIAlertAction actionWithTitle:@"GO TO: Custom"
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction *action) {
        [alertController dismissViewControllerAnimated:YES completion:nil];
        [self findCustom];
    }];
    
    UIAlertAction *findMeAction = [UIAlertAction actionWithTitle:@"GO TO: Me"
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction *action) {
        [alertController dismissViewControllerAnimated:YES completion:nil];
        [self goToUser];
    }];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                       style:UIAlertActionStyleCancel
                                                     handler:^(UIAlertAction *action) {
        [alertController dismissViewControllerAnimated:YES completion:nil];
    }];
    
    [alertController addAction:addressAction];
    [addressAction setValue:[[UIImage imageNamed:@"address32.png"] imageWithRenderingMode:UIImageRenderingModeAutomatic] forKey:@"image"];
    [alertController addAction:findMeAction];
    [findMeAction setValue:[[UIImage imageNamed:@"user32.png"] imageWithRenderingMode:UIImageRenderingModeAutomatic] forKey:@"image"];
    [alertController addAction:customAction];
    [customAction setValue:[[UIImage imageNamed:@"marker32.png"] imageWithRenderingMode:UIImageRenderingModeAutomatic] forKey:@"image"];
    [alertController addAction:cancelAction];
    
    UIPopoverPresentationController *popover = alertController.popoverPresentationController;
    if (popover) {
        popover.sourceView = sender;
        //popover.sourceRect = sender.bounds;
      popover.permittedArrowDirections = UIPopoverArrowDirectionAny;
    }
    
    [self presentViewController:alertController animated:YES completion:nil];
}

//if nothing found, go to the statue of liberty
-(void) findCustom {
    NSLog(@"GO TO CUSTOM");
    NSString *location=@"1 Liberty Island, New York, NY 10004";
    CLGeocoder *geocoder = [[CLGeocoder alloc] init];
    
    [geocoder geocodeAddressString:location completionHandler:^(NSArray* placemarks, NSError* error){
        NSLog(@"Address: %@", location);
        MKCoordinateRegion region;
        //40.6892° N, 74.0445° W
        region.center.latitude = 40.6892;
        region.center.longitude = -74.0445;
        region.span.longitudeDelta = (CGFloat)0.0025;
        region.span.latitudeDelta = (CGFloat)0.0025;
        [self.mapView setRegion:region animated:YES];
    }];
    self.mapView.showsUserLocation=NO;
    [self customAddressController];
}

-(void) findJob {
    NSLog(@"GO TO JOB");
    NSString* location = [[(AppDelegate *) [UIApplication sharedApplication].delegate surveyDataDictionary] objectForKey:@"Address"];
    NSLog(@"---Current location data: %@---", location);
    if ([location isEqual:@"No Address, No City, No State, No ZIP"])
        location=@"1 Liberty Island, New York, NY 10004";
    CLGeocoder *geocoder = [[CLGeocoder alloc] init];
    
    [geocoder geocodeAddressString:location completionHandler:^(NSArray* placemarks, NSError* error){
        NSLog(@"Address: %@", location);
        if (placemarks && placemarks.count > 0) {
            CLPlacemark *topResult = [placemarks objectAtIndex:0];
            MKPlacemark *placemark = [[MKPlacemark alloc] initWithPlacemark:topResult];
            MKCoordinateRegion region;
            
            self.jobDestination = [[MKPointAnnotation alloc] init];
            self.jobDestination.coordinate = placemark.coordinate;
            self.jobDestination.title = location;//@"Job Location";
            region.center.latitude = self.jobDestination.coordinate.latitude;
            region.center.longitude = self.jobDestination.coordinate.longitude;
            region.span.longitudeDelta = (CGFloat)0.0025;
            region.span.latitudeDelta = (CGFloat)0.0025;
            
            NSLog(@"COORDINATES: lat: %f long: %f span: %f.", region.center.latitude, region.center.longitude, region.span.longitudeDelta);
            [self.mapView setRegion:region animated:YES];
            
            NSLog(@"---Final location data: %@---", location);
            [self.mapView addAnnotation:self.jobDestination];
        }
    }];
    self.mapView.showsUserLocation=NO;
}

- (IBAction)setMapType:(id)sender {
    //rotate map type per user request
    
    if ([self.mapVersion  isEqual: @"Hybrid"]) {
        self.mapVersion=@"Satellite";
        self.mapView.mapType = MKMapTypeSatellite;
    }
    else if ([self.mapVersion  isEqual: @"Satellite"]) {
        self.mapVersion=@"Standard";
        self.mapView.mapType = MKMapTypeStandard;
    }
    else {//@"Standard"->Hybrid
        self.mapVersion=@"Hybrid";
        self.mapView.mapType = MKMapTypeHybrid;
    }
    NSLog (@"Map view changed type: %@.", self.mapVersion);
}

- (void) goBack:(id)sender {
    [self clearQuickStackForMemory];
    
    [self.navigationController popViewControllerAnimated:YES];
}

//custom icons for top bar
- (void) barButtonUpdate {
    UIBarButtonItem *rotateItem, *userItem, *locationItem, *polesItem;
    
    [self.navigationController setNavigationBarHidden:NO animated:YES];
    self.navigationItem.title = NSLocalizedString(@"MapIt PRO", @"MapIt PRO");
    
    UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Back", @"Back")
                                                                 style:UIBarButtonItemStyleBordered
                                                                target:self
                                                                action:@selector(goBack:)];
    
    UIButton *rotateButton=[UIButton buttonWithType:UIButtonTypeSystem];
    UIImage *buttonImage = [UIImage imageNamed:@"aroundTheWorld72.png"];
    [rotateButton addTarget:self action:@selector(setMapType:) forControlEvents:UIControlEventTouchUpInside];
    [rotateButton setImage:buttonImage forState:UIControlStateNormal];
    NSLayoutConstraint *heightConstraint = [NSLayoutConstraint constraintWithItem:rotateButton attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:32];
    NSLayoutConstraint *widthConstraint = [NSLayoutConstraint constraintWithItem:rotateButton attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:32];
    [heightConstraint setActive:TRUE];
    [widthConstraint setActive:TRUE];
    rotateItem = [[UIBarButtonItem alloc]initWithCustomView:rotateButton];
    
    UIButton *userButton=[UIButton buttonWithType:UIButtonTypeSystem];
    buttonImage = [UIImage imageNamed:@"user100.png"];
    [userButton addTarget:self action:@selector(goToUser:) forControlEvents:UIControlEventTouchUpInside];
    [userButton setImage:buttonImage forState:UIControlStateNormal];
    heightConstraint = [NSLayoutConstraint constraintWithItem:userButton attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:32];
    widthConstraint = [NSLayoutConstraint constraintWithItem:userButton attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:32];
    [heightConstraint setActive:TRUE];
    [widthConstraint setActive:TRUE];
    userItem = [[UIBarButtonItem alloc]initWithCustomView:userButton];
    
    UIButton *locationButton=[UIButton buttonWithType:UIButtonTypeSystem];
    buttonImage = [UIImage imageNamed:@"geoFence128.png"];
    [locationButton addTarget:self action:@selector(goToJob:) forControlEvents:UIControlEventTouchUpInside];
    [locationButton setImage:buttonImage forState:UIControlStateNormal];
    heightConstraint = [NSLayoutConstraint constraintWithItem:locationButton attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:32];
    widthConstraint = [NSLayoutConstraint constraintWithItem:locationButton attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:32];
    [heightConstraint setActive:TRUE];
    [widthConstraint setActive:TRUE];
    locationItem = [[UIBarButtonItem alloc]initWithCustomView:locationButton];
    
    UIButton *polesButton=[UIButton buttonWithType:UIButtonTypeSystem];
    buttonImage = [UIImage imageNamed:@"mapPin100.png"];
    [polesButton addTarget:self action:@selector(dropPins:) forControlEvents:UIControlEventTouchUpInside];
    [polesButton setImage:buttonImage forState:UIControlStateNormal];
    heightConstraint = [NSLayoutConstraint constraintWithItem:polesButton attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:32];
    widthConstraint = [NSLayoutConstraint constraintWithItem:polesButton attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:32];
    [heightConstraint setActive:TRUE];
    [widthConstraint setActive:TRUE];
    polesItem = [[UIBarButtonItem alloc]initWithCustomView:polesButton];
    
    UIBarButtonItem *snapShotItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"MapIt", @"MapIt")
                                                                 style:UIBarButtonItemStyleBordered
                                                                target:self
                                                                action:@selector(boundsScreenShot:)];
    
    NSMutableArray *upperLeftBarButtons = [NSMutableArray array];
    NSMutableArray *upperRightBarButtons = [NSMutableArray array];
    UIBarButtonItem *fixedItem;
    
    if([[UIDevice currentDevice].model isEqualToString:@"iPhone"]) {
        fixedItem = [UIBarButtonItem fixedItemWithWidth:32];
    } else {
        fixedItem = [UIBarButtonItem fixedItemWithWidth:64];
    }
    
    [upperLeftBarButtons addObject:fixedItem];
    [upperLeftBarButtons addObject:backItem];
    [upperLeftBarButtons addObject:fixedItem];
    [upperLeftBarButtons addObject:locationItem];
    
    [upperRightBarButtons addObject:snapShotItem];
    [upperRightBarButtons addObject:fixedItem];
    [upperRightBarButtons addObject:rotateItem];
    
    self.navigationItem.leftBarButtonItems = upperLeftBarButtons;
    self.navigationItem.rightBarButtonItems = upperRightBarButtons;
}

//default custom icons for "demo" version
- (void) setBarButtons {
    UIBarButtonItem *rotateItem, *userItem, *locationItem, *polesItem;
    
    [self.navigationController setNavigationBarHidden:NO animated:YES];
    self.navigationItem.title = NSLocalizedString(@"MapIt", @"MapIt");
    
    UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Back", @"Back")
                                                                 style:UIBarButtonItemStyleBordered
                                                                target:self
                                                                action:@selector(goBack:)];
    
    UIButton* rotateButton=[UIButton buttonWithType:UIButtonTypeSystem];
    UIImage* buttonImage = [UIImage imageNamed:@"aroundTheWorld72.png"];
    [rotateButton addTarget:self action:@selector(setMapType:) forControlEvents:UIControlEventTouchUpInside];
    [rotateButton setImage:buttonImage forState:UIControlStateNormal];
    NSLayoutConstraint *heightConstraint = [NSLayoutConstraint constraintWithItem:rotateButton attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:32];
    NSLayoutConstraint *widthConstraint = [NSLayoutConstraint constraintWithItem:rotateButton attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:32];
    [heightConstraint setActive:TRUE];
    [widthConstraint setActive:TRUE];
    rotateItem = [[UIBarButtonItem alloc]initWithCustomView:rotateButton];
    
    UIButton* userButton=[UIButton buttonWithType:UIButtonTypeSystem];
    buttonImage = [UIImage imageNamed:@"user100.png"];
    [userButton addTarget:self action:@selector(goToUser:) forControlEvents:UIControlEventTouchUpInside];
    [userButton setImage:buttonImage forState:UIControlStateNormal];
    heightConstraint = [NSLayoutConstraint constraintWithItem:userButton attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:32];
    widthConstraint = [NSLayoutConstraint constraintWithItem:userButton attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:32];
    [heightConstraint setActive:TRUE];
    [widthConstraint setActive:TRUE];
    userItem = [[UIBarButtonItem alloc]initWithCustomView:userButton];
    
    UIButton* locationButton=[UIButton buttonWithType:UIButtonTypeSystem];
    buttonImage = [UIImage imageNamed:@"geoFence128.png"];
    [locationButton addTarget:self action:@selector(goToJob:) forControlEvents:UIControlEventTouchUpInside];
    [locationButton setImage:buttonImage forState:UIControlStateNormal];
    heightConstraint = [NSLayoutConstraint constraintWithItem:locationButton attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:32];
    widthConstraint = [NSLayoutConstraint constraintWithItem:locationButton attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:32];
    [heightConstraint setActive:TRUE];
    [widthConstraint setActive:TRUE];
    locationItem = [[UIBarButtonItem alloc]initWithCustomView:locationButton];
    
    UIButton* polesButton=[UIButton buttonWithType:UIButtonTypeSystem];
    buttonImage = [UIImage imageNamed:@"mapPin100.png"];
    [polesButton addTarget:self action:@selector(dropPins:) forControlEvents:UIControlEventTouchUpInside];
    [polesButton setImage:buttonImage forState:UIControlStateNormal];
    heightConstraint = [NSLayoutConstraint constraintWithItem:polesButton attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:32];
    widthConstraint = [NSLayoutConstraint constraintWithItem:polesButton attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:32];
    [heightConstraint setActive:TRUE];
    [widthConstraint setActive:TRUE];
    polesItem = [[UIBarButtonItem alloc]initWithCustomView:polesButton];
    
    UIBarButtonItem *snapShotItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"MapIt", @"MapIt")
                                                                 style:UIBarButtonItemStyleBordered
                                                                target:self
                                                                action:@selector(boundsScreenShot:)];
    
    NSMutableArray *upperLeftBarButtons = [NSMutableArray array];
    NSMutableArray *upperRightBarButtons = [NSMutableArray array];
    UIBarButtonItem *fixedItem;
    
    if([[UIDevice currentDevice].model isEqualToString:@"iPhone"]) {
        fixedItem = [UIBarButtonItem fixedItemWithWidth:32];
    } else {
        fixedItem = [UIBarButtonItem fixedItemWithWidth:64];
    }
    
    [upperLeftBarButtons addObject:fixedItem];
    [upperLeftBarButtons addObject:backItem];
    [upperLeftBarButtons addObject:fixedItem];
    [upperLeftBarButtons addObject:locationItem];
    [upperLeftBarButtons addObject:fixedItem];
    [upperLeftBarButtons addObject:polesItem];
    
    [upperRightBarButtons addObject:snapShotItem];
    [upperRightBarButtons addObject:fixedItem];
    [upperRightBarButtons addObject:rotateItem];
    
    self.navigationItem.leftBarButtonItems = upperLeftBarButtons;
    self.navigationItem.rightBarButtonItems = upperRightBarButtons;
}

- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    self.mapView = nil;
    self.mapVersion = nil;
    self.locationManager = nil;
    self.routeLine = nil;
    self.totalFootage = nil;
    self.jobDestination = nil;
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(locationUpdated:)
                                                 name:@"com.cusoft.locationUpdated"
                                               object:nil];
}

-(void)locationUpdated:(NSNotification *)notification {
    NSLog(@"FOUND USER!");
    CLLocation *location = [notification object];
    if (self.mapView!=nil) {
        [self.mapView setCenterCoordinate:location.coordinate];
    }
    
    [self zoomAction];
}

//when building poles into x,y,z array -> setup graphics
-(MKOverlayRenderer *) mapView:(MKMapView *)mapView rendererForOverlay:(id<MKOverlay>)overlay {
    if ([overlay isKindOfClass:[MKPolyline class]]) {
        MKPolylineRenderer *renderer = [[MKPolylineRenderer alloc] initWithPolyline:overlay];
        renderer.lineWidth = 4;
        renderer.strokeColor = [[UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:1.0] colorWithAlphaComponent:1.0];
        return renderer;
    }
    return nil;
}

//clear the map
- (void) removeVisualAll {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.mapView removeAnnotations:[self.mapView annotations]];
    });
}

//add to users' maps to draw onto
- (IBAction)boundsScreenShot:(UIBarButtonItem *)sender {
    CGRect rect = [[UIScreen mainScreen] bounds];
    rect.size.height -= 128;
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    [self.view.layer renderInContext:context];
    UIImage *screenshot = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    AppDelegate *delegate = (AppDelegate *) [UIApplication sharedApplication].delegate;
    [delegate.imageList addObject:screenshot];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[WDDrawingManager sharedInstance] createNewMapWithImage:screenshot];
    });
    [self mapAddedNotification];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation {
    NSLog(@"--- USER LAT/LONG UPDATED!!! ---");
    CLGeocoder *geocoder = [[CLGeocoder alloc] init];
    [geocoder reverseGeocodeLocation:newLocation
                   completionHandler:^(NSArray *placemarks, NSError *error) {
                       if (error){
                           NSLog(@"Geocode failed with error: %@", error);
                           return;
                           
                       } else {
                           CLPlacemark *topResult = [placemarks objectAtIndex:0];
                           MKPlacemark *placemark = [[MKPlacemark alloc] initWithPlacemark:topResult];
                           
                           MKCoordinateRegion region = self.mapView.region;
                           region.center = placemark.region.center;
                           region.span.longitudeDelta /= 8.0;
                           region.span.latitudeDelta /= 8.0;
                           
                           [self.mapView setRegion:region animated:YES];
                           [self.mapView addAnnotation:placemark];
                       }
                   }];
    
    [self.locationManager stopUpdatingLocation];
}

- (void)mapAddedNotification {
    UIAlertController * alertController = [UIAlertController alertControllerWithTitle: @"SUCCESS"
                                                                              message: @"Map has been added to the gallery!"
                                                                       preferredStyle: UIAlertControllerStyleAlert];
    
    UIAlertAction *buttonOK = [UIAlertAction actionWithTitle:@"Thank You" style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction *action) {
                                                         
                                                     }];
    
    [alertController addAction:buttonOK];
    
    [self presentViewController:alertController animated:YES completion:nil];
}

-(void)marketingMaterials {
    UIAlertController * alertController = [UIAlertController alertControllerWithTitle: @"CONTACT US FOR FULL BETA ACCESS"
                                                                              message: @"Drop pins, automate paths and auto log (X,Y,Z) coordinate data. Full suite functionality for all subscribers to B2 MAPS PRO! Thank you for your enthusiasm!\n\ncontactus@b2innovation.com"
                                                                       preferredStyle: UIAlertControllerStyleAlert];
    
    UIAlertAction *buttonOK = [UIAlertAction actionWithTitle:@"WOW!" style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction *action) {
                                                         
                                                     }];
    
    [alertController addAction:buttonOK];
    
    [self presentViewController:alertController animated:YES completion:nil];
}

- (IBAction)nothing:(UIBarButtonItem *)sender {

}

//user readability
-(NSMutableString *) addCommas:(NSMutableString *)footageString {
    //2147483647
    NSMutableString *finalString = [NSMutableString stringWithFormat:@"%@", footageString];
    
    if (footageString.length==10) {
        [finalString insertString:@"," atIndex:1];
        [finalString insertString:@"," atIndex:5];
        [finalString insertString:@"," atIndex:9];
    } else if (footageString.length==9) {
        [finalString insertString:@"," atIndex:3];
        [finalString insertString:@"," atIndex:7];
    } else if (footageString.length==8) {
        [finalString insertString:@"," atIndex:2];
        [finalString insertString:@"," atIndex:6];
    }else if (footageString.length==7) {
        [finalString insertString:@"," atIndex:1];
        [finalString insertString:@"," atIndex:5];
    }else if (footageString.length==6) {
        [finalString insertString:@"," atIndex:3];
    }else if (footageString.length==5) {
        [finalString insertString:@"," atIndex:2];
    }else if (footageString.length==4) {
        [finalString insertString:@"," atIndex:1];
    } else {
    
    }
    
    return finalString;
}

//total footage and individual footages
-(void) updateFootage {
    int footageInt = [self.totalFootage intValue];
    NSMutableString *footageString = [NSMutableString stringWithFormat:@"%d", footageInt];
    footageString = [self addCommas:footageString];
    footageString = [NSMutableString stringWithFormat:@"Total Footage: %@ ft", footageString];
    UIBarButtonItem *FootageItem = [[UIBarButtonItem alloc] initWithTitle:footageString style:UIBarButtonItemStyleBordered target:self action:@selector(nothing:)];
    
    [FootageItem setTitleTextAttributes:
     @{UITextAttributeTextColor:[UIColor colorWithRed:0.0/255.0 green:0.0/255.0 blue:0.0/255.0 alpha:0.8],
       UITextAttributeTextShadowOffset:[NSValue valueWithUIOffset:UIOffsetMake(0, 0)],
       UITextAttributeTextShadowColor:[UIColor whiteColor],
       UITextAttributeFont:[UIFont fontWithName:@"IowanOldStyle-Roman" size:18.0]
       }forState:UIControlStateNormal];
    
    UIButton *glassButton=[UIButton buttonWithType:UIButtonTypeSystem];
    UIImage *glassImage = [UIImage imageNamed:@"magnifier128.png"];
    [glassButton addTarget:self action:@selector(footagesAlert:) forControlEvents:UIControlEventTouchUpInside];
    [glassButton setImage:glassImage forState:UIControlStateNormal];
    NSLayoutConstraint *heightConstraint = [NSLayoutConstraint constraintWithItem:glassButton attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:32];
    NSLayoutConstraint *widthConstraint = [NSLayoutConstraint constraintWithItem:glassButton attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:32];
    [heightConstraint setActive:TRUE];
    [widthConstraint setActive:TRUE];
    UIBarButtonItem *glassItem = [[UIBarButtonItem alloc]initWithCustomView:glassButton];
    
    NSMutableArray *bottomBarButtons = [NSMutableArray array];
    UIBarButtonItem *flexBar = [UIBarButtonItem flexibleItem];
    
    [bottomBarButtons addObject:FootageItem];
    [bottomBarButtons addObject:flexBar];
    [bottomBarButtons addObject:glassItem];
    
    [self setToolbarItems:bottomBarButtons animated:YES];
}

-(IBAction) footagesAlert:(id)sender {
    if ([self.navigationController.visibleViewController isKindOfClass:[UIAlertController class]]) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
    
    NSString *footagesMessage = [NSString stringWithFormat:@"Run 1: %@ ft", self.allFootages[0]];
    for(int j=1; j<self.allFootages.count; j++) {
        footagesMessage = [NSString stringWithFormat:@"%@\nRun %d: %@ ft", footagesMessage, j+1, self.allFootages[j]];
    }
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"All User Entered Poles"
                                                                             message:footagesMessage
                                                                      preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"THANK YOU"
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction *action) {
        [alertController dismissViewControllerAnimated:YES completion:nil];
    }];
    
    UIPopoverPresentationController *popover = alertController.popoverPresentationController;
    if (popover) {
        popover.permittedArrowDirections = UIPopoverArrowDirectionAny;
    }
    
    [alertController addAction:okAction];
    [self presentViewController:alertController animated:YES completion:nil];
}

//when user presses and holds the map, a pole must be dropped
- (IBAction)dropPins:(UIBarButtonItem *)sender {
    UIBarButtonItem *PinItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Poles:ON", @"Poles:ON")
                                                                 style:UIBarButtonItemStyleBordered
                                                                target:self
                                                                action:@selector(resetPinSet:)];
    
    UIBarButtonItem *ManyPinsItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Paths:ON", @"Paths:ON")
                                                                    style:UIBarButtonItemStyleBordered
                                                                   target:self
                                                                   action:@selector(resetPinSet:)];
    
    UIBarButtonItem *CoordinatesItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Coordinates:ON", @"Coordinates:ON")
                                                                     style:UIBarButtonItemStyleBordered
                                                                    target:self
                                                                    action:@selector(resetPinSet:)];
    
    [self.navigationController setToolbarHidden:NO animated:YES];
    self.navigationController.toolbar.translucent = NO;
    NSMutableArray *bottomBarButtons = [NSMutableArray array];
    UIBarButtonItem *flexBar = [UIBarButtonItem flexibleItem];
    [bottomBarButtons addObject:PinItem];
    [bottomBarButtons addObject:flexBar];
    [bottomBarButtons addObject:ManyPinsItem];
    [bottomBarButtons addObject:flexBar];
    [bottomBarButtons addObject:CoordinatesItem];
    [self setToolbarItems:bottomBarButtons animated:YES];
    
    self.totalFootage=0;
    [self removeVisualAll];
    
    UILongPressGestureRecognizer *lpgr = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(userDroppedPole:)];
    lpgr.minimumPressDuration = 1.0;
    [self.mapView addGestureRecognizer:lpgr];
    
    [self barButtonUpdate];
}

- (IBAction)resetPinSet:(UIBarButtonItem *)sender {
    
}

//by client request
- (void) willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    
}

- (NSString *)getPoleNumber {
    NSMutableDictionary *surveyDictionary = [(AppDelegate *) [UIApplication sharedApplication].delegate surveyDataDictionary];
    NSMutableDictionary *poleLocationDictionary = [surveyDictionary objectForKey:@"coordinatesDictionary"];
    NSString *poleNumber = [NSString stringWithFormat:@"%d", poleLocationDictionary.count];
    
    if(poleLocationDictionary == nil) {
        poleNumber = @"0";
        NSMutableDictionary *newPoleLocationDictionary = [[NSMutableDictionary alloc]init];
        [surveyDictionary setObject:newPoleLocationDictionary forKey:@"coordinatesDictionary"];
    }
    
    NSLog(@"Current pole: %@.", poleNumber);
    return poleNumber;
}

//one pole inserted into map
-(IBAction) userDroppedPole:(UIGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer.state != UIGestureRecognizerStateBegan) {
        return;
    }
    
    NSString *poleNumber = [self getPoleNumber];
    NSMutableDictionary *surveyDictionary = [(AppDelegate *) [UIApplication sharedApplication].delegate surveyDataDictionary];
    NSMutableDictionary *allPolesDictionary = [surveyDictionary objectForKey:@"coordinatesDictionary"];
    CGPoint touchPoint = [gestureRecognizer locationInView:self.mapView];
    CLLocationCoordinate2D touchMapCoordinate = [self.mapView convertPoint:touchPoint toCoordinateFromView:self.mapView];
    MKPointAnnotation *annotation = [[MKPointAnnotation alloc] init];
    annotation.coordinate = touchMapCoordinate;
    annotation.title = [NSString stringWithFormat:@"Pole %d", [poleNumber intValue]+1];
    annotation.subtitle = [NSString stringWithFormat:@"(%f, %f)", touchMapCoordinate.latitude, touchMapCoordinate.longitude];

    dispatch_async(dispatch_get_main_queue(), ^{
        MKAnnotationView *annotationView = [self.mapView viewForAnnotation:annotation];
    });
    [self.mapView addAnnotation:annotation];
    NSLog(@"Pole %@ dropped", poleNumber);
    
    NSNumber *latNumber = [NSNumber numberWithDouble:touchMapCoordinate.latitude];
    NSNumber *longNumber = [NSNumber numberWithDouble:touchMapCoordinate.longitude];
    NSMutableDictionary *coordinateDataDictionary = [[NSMutableDictionary alloc]init];
    [coordinateDataDictionary setObject:latNumber forKey:@"lat"];
    [coordinateDataDictionary setObject:longNumber forKey:@"long"];
    
    [allPolesDictionary setObject:coordinateDataDictionary forKey:poleNumber];
    //NSLog(@"All Poles: %@.", allPolesDictionary);
    NSMutableDictionary *dicData = [(AppDelegate *) [UIApplication sharedApplication].delegate surveyDataDictionary];
    [dicData setObject:allPolesDictionary forKey:@"coordinatesDictionary"];
    
    [self drawTheLine];
}

//custom pole icon
-(MKPinAnnotationView *) mapView:(MKMapView *)mapView viewForAnnotation:(MKPointAnnotation *)annotation {
    NSLog(@"MAP GENERATION CONTROLLER: View for annotation");

    MKPinAnnotationView *pinView = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:@"energyPin"];
    //pinView.image = [UIImage imageNamed:@"energy32.png"];
    pinView.pinTintColor = [UIColor blackColor];
    pinView.animatesDrop = YES;
    pinView.canShowCallout = YES;
    pinView.draggable = YES;
    
    return pinView;
}

//map a line in between poles
- (void)drawTheLine {
    NSMutableDictionary *dicData = [(AppDelegate *) [UIApplication sharedApplication].delegate surveyDataDictionary];
    NSMutableDictionary *poleLocationsDic = [dicData objectForKey:@"coordinatesDictionary"];
    if(poleLocationsDic.count<2) {
        NSLog(@"Less than 2 total poles. Exitting polyline function at %@.", [NSNumber numberWithDouble:poleLocationsDic.count]);
        return;
    }
    
    long poleZeroInt = poleLocationsDic.count-2;
    long poleOneInt = poleLocationsDic.count-1;
    NSMutableDictionary *poleZeroDic = [poleLocationsDic objectForKey:[NSString stringWithFormat:@"%d", poleZeroInt]];
    NSMutableDictionary *poleOneDic = [poleLocationsDic objectForKey:[NSString stringWithFormat:@"%d", poleOneInt]];
    //NSLog(@"Building the line between the two poles %@ and %@.", poleZeroDic, poleOneDic);
    NSNumber *poleZeroLat = [poleZeroDic objectForKey: @"lat"];
    NSNumber *poleZeroLong = [poleZeroDic objectForKey: @"long"];
    NSNumber *poleOneLat = [poleOneDic objectForKey: @"lat"];
    NSNumber *poleOneLong = [poleOneDic objectForKey: @"long"];
    
    //add polyline
    CLLocationCoordinate2D coordinateArray[2];
    coordinateArray[0] = CLLocationCoordinate2DMake([poleZeroLat doubleValue], [poleZeroLong doubleValue]);
    coordinateArray[1] = CLLocationCoordinate2DMake([poleOneLat doubleValue], [poleOneLong doubleValue]);
    MKPolyline *routeLine = [MKPolyline polylineWithCoordinates:coordinateArray count:2];
    
    //add total footage
    CLLocation *zeroLocation = [[CLLocation alloc] initWithLatitude:[poleZeroLat doubleValue] longitude:[poleZeroLong doubleValue]];
    CLLocation *oneLocation = [[CLLocation alloc] initWithLatitude:[poleOneLat doubleValue] longitude:[poleOneLong doubleValue]];
    CLLocationDistance distToTally = [zeroLocation distanceFromLocation:oneLocation];
    
    MKPolylineRenderer *lineView = [[MKPolylineRenderer alloc]initWithPolyline:routeLine];
    int twoPoleInt = (distToTally * 3.28084);
    NSMutableString *twoPoleString = [NSMutableString stringWithFormat:@"%d", twoPoleInt];
    twoPoleString = [self addCommas:twoPoleString];
    [self.allFootages addObject:twoPoleString];
    [self.mapView addOverlay:routeLine];
    
    self.totalFootage = [NSNumber numberWithDouble:([self.totalFootage doubleValue] + (distToTally * 3.28084))];
    NSLog(@"Adding footage %@ to total.", self.totalFootage);
    [self updateFootage];
}

//user wants to search for a custom location
- (void) customAddressController {
    if ([self.navigationController.visibleViewController isKindOfClass:[UIAlertController class]]) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
    
    UIAlertController *customAddressAlert = [UIAlertController alertControllerWithTitle:@"ENTER ANY ADDRESS\n"
                                                                              message:nil
                                                                       preferredStyle:UIAlertControllerStyleAlert];
    
    [customAddressAlert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"Street";
    }];
    [customAddressAlert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"City";
    }];
    [customAddressAlert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"State";
    }];
    
    NSArray *textfields = customAddressAlert.textFields;
    UITextField *streetField = textfields[0];
    UITextField *cityField = textfields[1];
    UITextField *stateField = textfields[2];
    
    UIAlertAction *doneButton = [UIAlertAction actionWithTitle:@"Done" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self removeVisualAll];
        [self dismissViewControllerAnimated:YES completion:nil];
        
        NSString* location = [NSString stringWithFormat:@"%@, %@, %@", streetField.text, cityField.text, stateField.text];
        CLGeocoder *geocoder = [[CLGeocoder alloc] init];
        
        [geocoder geocodeAddressString:location completionHandler:^(NSArray* placemarks, NSError* error){
            if (placemarks && placemarks.count > 0) {
                CLPlacemark *topResult = [placemarks objectAtIndex:0];
                MKPlacemark *placemark = [[MKPlacemark alloc] initWithPlacemark:topResult];
                MKCoordinateRegion region;
                self.jobDestination = [[MKPointAnnotation alloc] init];
                self.jobDestination.coordinate = placemark.coordinate;
                self.jobDestination.title = location;
                region.center.latitude = self.jobDestination.coordinate.latitude;
                region.center.longitude = self.jobDestination.coordinate.longitude;
                region.span.longitudeDelta = (CGFloat)0.0025;
                region.span.latitudeDelta = (CGFloat)0.0025;
                NSLog(@"Zooming to coordinates... Lat: %f Long: %f Span: %f", region.center.latitude, region.center.longitude, region.span.longitudeDelta);
                [self.mapView setRegion:region animated:YES];
                NSLog(@"---Final location data: %@---", location);
                [self.mapView addAnnotation:self.jobDestination];
            }
        }];
        self.mapView.showsUserLocation=NO;
    }];
    
    UIAlertAction *cancelButton = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }];
    
    [customAddressAlert addAction:doneButton];
    [customAddressAlert addAction:cancelButton];

    [self presentViewController:customAddressAlert animated:YES completion:nil];
}

@end

