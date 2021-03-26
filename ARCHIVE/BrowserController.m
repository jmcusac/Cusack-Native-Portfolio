//
//  BrowserController.m
//  TechAssistant©
//
//  Copyright © 2013-2021 B2Innovation, L.L.C.
//  Created by Jason Cusack on 08/09/18
//

#import "BrowserController.h"

#define kEditingHighlightRadius     125

NSString *AttachmentNotification = @"AttachmentNotification";

@implementation BrowserController

- (id) initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    
    if (!self) {
        return nil;
    }
    
    selectedDrawings_ = [[NSMutableSet alloc] init];
    filesBeingUploaded_ = [[NSMutableSet alloc] init];
    activities_ = [[WDActivityManager alloc] init];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(drawingChanged:)
                                                 name:UIDocumentStateChangedNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(drawingAdded:)
                                                 name:WDDrawingAdded
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(drawingsDeleted:)
                                                 name:WDDrawingsDeleted
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didEnterBackground:)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(activityCountChanged:)
                                                 name:WDActivityAddedNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(activityCountChanged:)
                                                 name:WDActivityRemovedNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(emailAttached:)
                                                 name:WDAttachmentNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(newDrawingAdded:)
                                                 name:@"com.cusoft.newDrawingAdded"
                                               object:nil];
    
    return self;
}

- (void)viewDidLoad:(BOOL)animated {
    [super viewDidLoad];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [self showBar];
    
    [self installAllInitial];
}

-(void) reloadTheView {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.collectionView reloadData];
    });
}

-(void) installAllInitial {
    NSString *drawingsPath = [WDDrawingManager drawingPath];
    NSString *filesFolderPath = [drawingsPath stringByAppendingPathComponent:@"Downloads"];
    NSArray *downloadedFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:filesFolderPath error:nil];
    int downloadedInt = (int)[downloadedFiles count];
    
    if(downloadedInt>0) {
        NSLog(@"GALLERY: %d files to install", downloadedInt);
        static dispatch_queue_t __serialQueue = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            __serialQueue = dispatch_queue_create("com.cusoft.installAllFilesSerialQueue", DISPATCH_QUEUE_SERIAL);
        });

        dispatch_async(__serialQueue, ^{
            [self emptyProgressView];
        });
        
        dispatch_async(__serialQueue, ^{
            [self installSVGs:^{
                [self installPictureFiles:^{
                    [self installPDFs:nil];
                }];
            }];
        });
    } else {
        NSLog(@"GALLERY: No files to install");
        [self reloadTheView];
    }
}

//display a visual indicator for user to monitor installation of their drawings
-(void) fullProgressView {
    dispatch_async(dispatch_get_main_queue(), ^{
        float progressCalculation = 1.0f;
        
        [self->progress_ setProgress:progressCalculation animated:YES];
        NSLog(@"GALLERY: FULL PERCENT: %.01f", progressCalculation*100);
    });
}

-(void) emptyProgressView {
    //get the progress bar on screen IMMEDIATELY -> updated later
    dispatch_async(dispatch_get_main_queue(), ^{
        self->progress_ = [[UIProgressView alloc] init];
        CGFloat goalFloat = self.navigationController.toolbar.bounds.size.height;
        CGRect screenRect = [[UIScreen mainScreen] bounds];
        CGFloat progressWidth = screenRect.size.width-40;
        CGFloat progressHeight = 4.0f;
        CGFloat progressY = screenRect.size.height-(goalFloat*3)+16;
        CGFloat progressX = 20.0f;
        
        self->progress_.frame = (CGRectMake(progressX, progressY, progressWidth, progressHeight));
        
        float progressCalculation = 0.025f;
        
        [self.view addSubview:self->progress_];
        
        [self->progress_ setProgress:progressCalculation animated:YES];
        NSLog(@"GALLERY: EMPTY PERCENT: %.01f", progressCalculation*100);
    });
}

-(void) updateProgressView:(int)printInt {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSMutableDictionary *dicData = [(AppDelegate *) [UIApplication sharedApplication].delegate surveyDataDictionary];
        float downloadsFloat = [([dicData objectForKey:@"totalDownloadsForJob"])floatValue];
        float totalFiles = (float)printInt;
        float progressCalculation = totalFiles/downloadsFloat;
        
        [self->progress_ setProgress:progressCalculation animated:YES];
        
        NSLog(@"GALLERY: PERCENT COMPLETE: %.01f", progressCalculation*100);
    });
}

- (void) newDrawingAdded:(NSNotification *)aNotification {
    [self installSVGs:^{
        [self installPictureFiles:^{
            [self installPDFs:nil];
        }];
    }];
    NSLog(@"Installed all new Box files to the gallery.");
    
    [self dismissPopover];
    [self reloadTheView];
}

-(IBAction) menuButtonPressed:(id)sender {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Gallery Nav Options"
                                                                             message:@"\nPlease select one."
                                                                      preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *photoAction = [UIAlertAction actionWithTitle:@"5x7 Photos"
                                                          style:UIAlertActionStyleDefault
                                                        handler:^(UIAlertAction *action) {
        [alertController dismissViewControllerAnimated:YES completion:nil];
        [self goToCameraPage:nil];
    }];
    
    UIAlertAction *memoAction = [UIAlertAction actionWithTitle:@"Memos"
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction *action) {
        [alertController dismissViewControllerAnimated:YES completion:nil];
        [self memoAction:nil];
    }];
    
    UIAlertAction *polesAction = [UIAlertAction actionWithTitle:@"Poles"
                                                          style:UIAlertActionStyleDefault
                                                        handler:^(UIAlertAction *action) {
        [alertController dismissViewControllerAnimated:YES completion:nil];
        [self goToPolePage:nil];
    }];
    
    UIAlertAction *mapItAction = [UIAlertAction actionWithTitle:@"MapIt"
                                                          style:UIAlertActionStyleDefault
                                                        handler:^(UIAlertAction *action) {
        [alertController dismissViewControllerAnimated:YES completion:nil];
        [self goToMakeMap:nil];
    }];
    
    UIAlertAction *goBackAction = [UIAlertAction actionWithTitle:@"Go Back"
                                                          style:UIAlertActionStyleDefault
                                                        handler:^(UIAlertAction *action) {
        [alertController dismissViewControllerAnimated:YES completion:nil];
        [self goBack:nil];
    }];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction *action) {
        [alertController dismissViewControllerAnimated:YES completion:nil];
    }];
    
    [alertController addAction:goBackAction];
    [goBackAction setValue:[[UIImage imageNamed:@"back32.png"] imageWithRenderingMode:UIImageRenderingModeAutomatic] forKey:@"image"];
    [alertController addAction:photoAction];
    [photoAction setValue:[[UIImage imageNamed:@"camera32.png"] imageWithRenderingMode:UIImageRenderingModeAutomatic] forKey:@"image"];
    [alertController addAction:memoAction];
    [memoAction setValue:[[UIImage imageNamed:@"pin-32.png"] imageWithRenderingMode:UIImageRenderingModeAutomatic] forKey:@"image"];
    [alertController addAction:polesAction];
    [polesAction setValue:[[UIImage imageNamed:@"poleIcon32.png"] imageWithRenderingMode:UIImageRenderingModeAutomatic] forKey:@"image"];
    [alertController addAction:mapItAction];
    [mapItAction setValue:[[UIImage imageNamed:@"map32.png"] imageWithRenderingMode:UIImageRenderingModeAutomatic] forKey:@"image"];
    [alertController addAction:cancelAction];
    
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void) setBarButtons {
    NSMutableArray * upperLeftBarButtons = [NSMutableArray array];
    self.navigationItem.title = [NSString stringWithFormat:@"%@ Gallery", [(AppDelegate *) [UIApplication sharedApplication].delegate selectedJob]];
    
    UIButton *menuButton=[UIButton buttonWithType:UIButtonTypeSystem];
    UIImage *menuImage = [UIImage imageNamed:@"lines128.png"];
    [menuButton addTarget:self action:@selector(menuButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    [menuButton setImage:menuImage forState:UIControlStateNormal];
    NSLayoutConstraint *heightConstraint = [NSLayoutConstraint constraintWithItem:menuButton attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:32];
    NSLayoutConstraint *widthConstraint = [NSLayoutConstraint constraintWithItem:menuButton attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:32];
    [heightConstraint setActive:TRUE];
    [widthConstraint setActive:TRUE];
    UIBarButtonItem *menuItem = [[UIBarButtonItem alloc]initWithCustomView:menuButton];
    
    UIButton* starButt4 =[UIButton buttonWithType:UIButtonTypeSystem];
    UIImage* buttonImage4 = [UIImage imageNamed:@"camera128.png"];
    [starButt4 addTarget:self action:@selector(goToCameraPage:) forControlEvents:UIControlEventTouchUpInside];
    [starButt4 setImage:buttonImage4 forState:UIControlStateNormal];
    heightConstraint = [NSLayoutConstraint constraintWithItem:starButt4 attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:32];
    widthConstraint = [NSLayoutConstraint constraintWithItem:starButt4 attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:32];
    [heightConstraint setActive:TRUE];
    [widthConstraint setActive:TRUE];
    UIBarButtonItem *cameraBarButtonItem = [[UIBarButtonItem alloc]initWithCustomView:starButt4];
        
    UIButton* pinButton =[UIButton buttonWithType:UIButtonTypeSystem];
    UIImage* pinImage = [UIImage imageNamed:@"pin-128.png"];
    [pinButton addTarget:self action:@selector(memoAction:) forControlEvents:UIControlEventTouchUpInside];
    [pinButton setImage:pinImage forState:UIControlStateNormal];
    heightConstraint = [NSLayoutConstraint constraintWithItem:pinButton attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:32];
    widthConstraint = [NSLayoutConstraint constraintWithItem:pinButton attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:32];
    [heightConstraint setActive:TRUE];
    [widthConstraint setActive:TRUE];
    UIBarButtonItem * memoBarButtonItem = [[UIBarButtonItem alloc]initWithCustomView:pinButton];
    
    UIButton* poleButton =[UIButton buttonWithType:UIButtonTypeSystem];
    UIImage* poleImage = [UIImage imageNamed:@"poleIcon128.png"];
    [poleButton addTarget:self action:@selector(goToPolePage:) forControlEvents:UIControlEventTouchUpInside];
    [poleButton setImage:poleImage forState:UIControlStateNormal];
    heightConstraint = [NSLayoutConstraint constraintWithItem:poleButton attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:32];
    widthConstraint = [NSLayoutConstraint constraintWithItem:poleButton attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:32];
    [heightConstraint setActive:TRUE];
    [widthConstraint setActive:TRUE];
    UIBarButtonItem *poleItem = [[UIBarButtonItem alloc]initWithCustomView:poleButton];
    
    UIBarButtonItem *backTextItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Back", @"Back")
                                                                     style:UIBarButtonItemStyleBordered
                                                                    target:self
                                                                    action:@selector(goBack:)];
        
    if([[UIDevice currentDevice].model isEqualToString:@"iPhone"]) {
        [upperLeftBarButtons addObject:menuItem];
    } else {
        UIBarButtonItem *fixedItem = [UIBarButtonItem fixedItemWithWidth:32];
        [upperLeftBarButtons addObject:backTextItem];
        [upperLeftBarButtons addObject:fixedItem];
        [upperLeftBarButtons addObject:cameraBarButtonItem];
        [upperLeftBarButtons addObject:fixedItem];
        [upperLeftBarButtons addObject:memoBarButtonItem];
    }
    
    self.navigationItem.leftBarButtonItems = upperLeftBarButtons;

    self.toolbarItems = [self defaultToolbarItems];
}

-(void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [self hideBar];
}

- (NSArray *) defaultToolbarItems {
    if (!toolbarItems_) {
        toolbarItems_ = [[NSMutableArray alloc] init];
        
            UIButton* camButton0 =[UIButton buttonWithType:UIButtonTypeSystem];
            UIImage* camImage0 = [UIImage imageNamed:@"galleryCamera100.png"];
            [camButton0 addTarget:self action:@selector(importFromCamera:)
                 forControlEvents:UIControlEventTouchUpInside];
            [camButton0 setImage:camImage0 forState:UIControlStateNormal];
            NSLayoutConstraint *heightConstraint = [NSLayoutConstraint constraintWithItem:camButton0 attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:32];
            NSLayoutConstraint *widthConstraint = [NSLayoutConstraint constraintWithItem:camButton0 attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:32];
            [heightConstraint setActive:TRUE];
            [widthConstraint setActive:TRUE];
            UIBarButtonItem *galleryCameraBarButtonItem = [[UIBarButtonItem alloc]initWithCustomView:camButton0];
            
            UIButton* templatesButton =[UIButton buttonWithType:UIButtonTypeSystem];
            UIImage* tempImage = [UIImage imageNamed:@"file128.png"];
            [templatesButton addTarget:self action:@selector(reallyShowBoxImportPanel:)
                 forControlEvents:UIControlEventTouchUpInside];
            [templatesButton setImage:tempImage forState:UIControlStateNormal];
            heightConstraint = [NSLayoutConstraint constraintWithItem:templatesButton attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:32];
            widthConstraint = [NSLayoutConstraint constraintWithItem:templatesButton attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:32];
            [heightConstraint setActive:TRUE];
            [widthConstraint setActive:TRUE];
            UIBarButtonItem * boxTemplatesItem = [[UIBarButtonItem alloc]initWithCustomView:templatesButton];
            
            UIButton* addButton =[UIButton buttonWithType:UIButtonTypeSystem];
            UIImage* addImage = [UIImage imageNamed:@"add_image-128.png"];
            [addButton addTarget:self action:@selector(addDrawing:)
                forControlEvents:UIControlEventTouchUpInside];
            [addButton setImage:addImage forState:UIControlStateNormal];
            heightConstraint = [NSLayoutConstraint constraintWithItem:addButton attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:32];
            widthConstraint = [NSLayoutConstraint constraintWithItem:addButton attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:32];
            [heightConstraint setActive:TRUE];
            [widthConstraint setActive:TRUE];
            UIBarButtonItem * AddBarButtonItem = [[UIBarButtonItem alloc]initWithCustomView:addButton];
            
            UIButton* pictButton =[UIButton buttonWithType:UIButtonTypeSystem];
            UIImage* pictImage = [UIImage imageNamed:@"picture-128.png"];
            [pictButton addTarget:self action:@selector(importFromAlbum:)
                 forControlEvents:UIControlEventTouchUpInside];
            [pictButton setImage:pictImage forState:UIControlStateNormal];
            heightConstraint = [NSLayoutConstraint constraintWithItem:pictButton attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:32];
            widthConstraint = [NSLayoutConstraint constraintWithItem:pictButton attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:32];
            [heightConstraint setActive:TRUE];
            [widthConstraint setActive:TRUE];
            UIBarButtonItem * ImportBarButtonItem = [[UIBarButtonItem alloc]initWithCustomView:pictButton];
            
            UIButton* pinButton =[UIButton buttonWithType:UIButtonTypeSystem];
            UIImage* pinImage = [UIImage imageNamed:@"pin-128.png"];
            [pinButton addTarget:self action:@selector(showMemo:)
                forControlEvents:UIControlEventTouchUpInside];
            [pinButton setImage:pinImage forState:UIControlStateNormal];
            heightConstraint = [NSLayoutConstraint constraintWithItem:pinButton attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:32];
            widthConstraint = [NSLayoutConstraint constraintWithItem:pinButton attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:32];
            [heightConstraint setActive:TRUE];
            [widthConstraint setActive:TRUE];
            UIBarButtonItem * MemoBarButtonItem = [[UIBarButtonItem alloc]initWithCustomView:pinButton];
            
            UIButton* navButton =[UIButton buttonWithType:UIButtonTypeSystem];
            UIImage* navImage = [UIImage imageNamed:@"exercise128.png"];
            [navButton addTarget:self action:@selector(goToNav:)
                forControlEvents:UIControlEventTouchUpInside];
            [navButton setImage:navImage forState:UIControlStateNormal];
            heightConstraint = [NSLayoutConstraint constraintWithItem:navButton attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:32];
            widthConstraint = [NSLayoutConstraint constraintWithItem:navButton attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:32];
            [heightConstraint setActive:TRUE];
            [widthConstraint setActive:TRUE];
            UIBarButtonItem * NavBarButtonItem = [[UIBarButtonItem alloc]initWithCustomView:navButton];
            
            UIButton* editButton =[UIButton buttonWithType:UIButtonTypeSystem];
            UIImage* editImage = [UIImage imageNamed:@"settings128.png"];
            [editButton addTarget:self action:@selector(startEditing:)
                 forControlEvents:UIControlEventTouchUpInside];
            [editButton setImage:editImage forState:UIControlStateNormal];
            heightConstraint = [NSLayoutConstraint constraintWithItem:editButton attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:32];
            widthConstraint = [NSLayoutConstraint constraintWithItem:editButton attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:32];
            [heightConstraint setActive:TRUE];
            [widthConstraint setActive:TRUE];
            UIBarButtonItem * editItem = [[UIBarButtonItem alloc]initWithCustomView:editButton];
            
            UIButton* poleButton =[UIButton buttonWithType:UIButtonTypeSystem];
            UIImage* poleImage = [UIImage imageNamed:@"poleIcon128.png"];
            [poleButton addTarget:self action:@selector(goToPolePage:)
                 forControlEvents:UIControlEventTouchUpInside];
            [poleButton setImage:poleImage forState:UIControlStateNormal];
            heightConstraint = [NSLayoutConstraint constraintWithItem:poleButton attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:32];
            widthConstraint = [NSLayoutConstraint constraintWithItem:poleButton attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:32];
            [heightConstraint setActive:TRUE];
            [widthConstraint setActive:TRUE];
            UIBarButtonItem *poleItem = [[UIBarButtonItem alloc]initWithCustomView:poleButton];
            
            UIButton* mapItButton =[UIButton buttonWithType:UIButtonTypeSystem];
            UIImage* mapItImage = [UIImage imageNamed:@"map128.png"];
            [mapItButton addTarget:self action:@selector(goToMakeMap:)
                  forControlEvents:UIControlEventTouchUpInside];
            [mapItButton setImage:mapItImage forState:UIControlStateNormal];
            heightConstraint = [NSLayoutConstraint constraintWithItem:mapItButton attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:32];
            widthConstraint = [NSLayoutConstraint constraintWithItem:mapItButton attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:32];
            [heightConstraint setActive:TRUE];
            [widthConstraint setActive:TRUE];
            UIBarButtonItem * mapItItem = [[UIBarButtonItem alloc]initWithCustomView:mapItButton];
        
            editItem.style = UIBarButtonItemStyleBordered;
            
        UIBarButtonItem *flexBar = [UIBarButtonItem flexibleItem];
        
        [toolbarItems_ addObject:editItem];
        [toolbarItems_ addObject:flexBar];
        [toolbarItems_ addObject:boxTemplatesItem];
        [toolbarItems_ addObject:flexBar];
        [toolbarItems_ addObject:galleryCameraBarButtonItem];
        [toolbarItems_ addObject:flexBar];
        [toolbarItems_ addObject:AddBarButtonItem];
        [toolbarItems_ addObject:flexBar];
        [toolbarItems_ addObject:ImportBarButtonItem];
            
        NSMutableArray * upperRightBarButtons = [NSMutableArray array];
        if([[UIDevice currentDevice].model isEqualToString:@"iPhone"]) {
            [upperRightBarButtons addObject:NavBarButtonItem];
        } else {
            UIBarButtonItem *fixedItem = [UIBarButtonItem fixedItemWithWidth:32];
            [upperRightBarButtons addObject:mapItItem];
            [upperRightBarButtons addObject:fixedItem];
            [upperRightBarButtons addObject:NavBarButtonItem];
            [upperRightBarButtons addObject:fixedItem];
            [upperRightBarButtons addObject:poleItem];
        }
        self.navigationItem.rightBarButtonItems = upperRightBarButtons;
    }
    return toolbarItems_;
}

- (IBAction)goToCameraPage:(id)sender {
    [self dismissPopover];
    UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"Modules" bundle: nil];
    InfinitePhotosController *navController = (InfinitePhotosController *)[mainStoryboard instantiateViewControllerWithIdentifier: @"InfinitePhotosPage"];
    [self.navigationController pushViewController:navController animated:YES];
}

-(IBAction) goBack:(id)sender {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark -

- (void) startEditingDrawing:(WDDocument *)document {
    [self setEditing:NO animated:NO];
    
    WDCanvasController *canvasController = [[WDCanvasController alloc] init];
    [canvasController setDocument:document];
    
    [self.navigationController pushViewController:canvasController animated:YES];
}

- (void) createNewDrawing:(id)sender {
    [self dismissViewControllerAnimated:YES
                             completion:nil];
    
    WDDocument *document = [[WDDrawingManager sharedInstance] createNewDrawingWithSize:pageSizeController_.size
                                                                              andUnits:pageSizeController_.units];

    [self startEditingDrawing:document];
}

- (void) addDrawing:(id)sender {
    if (popoverController_) {
        [self dismissPopover];
    } else {
        pageSizeController_ = [[WDPageSizeController alloc] initWithNibName:nil bundle:nil];
        UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:pageSizeController_];
        
        pageSizeController_.target = self;
        pageSizeController_.action = @selector(createNewDrawing:);
        
        navController.modalPresentationStyle = UIModalPresentationPopover;
        navController.popoverPresentationController.sourceView = sender;
        navController.preferredContentSize = self.view.bounds.size;
        
        [self presentViewController:navController animated:YES completion:nil];
    }
}

#pragma mark - Camera

- (void) importFromImagePicker:(id)sender sourceType:(UIImagePickerControllerSourceType)sourceType {
    if (pickerController_ && (pickerController_.sourceType == sourceType)) {
        [self dismissPopover];
        return;
    }
    
    pickerController_ = [[UIImagePickerController alloc] init];
    pickerController_.sourceType = sourceType;
    pickerController_.delegate = self;
    pickerController_.preferredContentSize = self.view.bounds.size;
    pickerController_.allowsEditing = YES;
    
    if([[UIDevice currentDevice].model isEqualToString:@"iPhone"]) {
        [self presentViewController:pickerController_ animated:YES completion:NULL];
    } else {
        popoverController_.delegate = self;
        popoverController_ = [[UIPopoverController alloc] initWithContentViewController:pickerController_];
        
        if ([sender isKindOfClass:[UIBarButtonItem class]]) {
            [popoverController_ presentPopoverFromBarButtonItem:sender permittedArrowDirections:UIPopoverArrowDirectionAny animated:NO];
        } else {
            [popoverController_ presentPopoverFromRect:[sender frame] inView:[sender superview] permittedArrowDirections:UIPopoverArrowDirectionAny animated:NO];
        }
    }
}

- (void) importFromAlbum:(id)sender {
    [self importFromImagePicker:sender sourceType:UIImagePickerControllerSourceTypePhotoLibrary];
}

- (void) importFromCamera:(id)sender {
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        
        UIAlertView *cameraAlertView = [[UIAlertView alloc] initWithTitle:@"Error"
                                                                  message:@"Sorry, your device has no camera"
                                                                 delegate:nil
                                                        cancelButtonTitle:@"OK"
                                                        otherButtonTitles: nil];
        
        [cameraAlertView show];
        return;
    }
    [self importFromImagePicker:sender sourceType:UIImagePickerControllerSourceTypeCamera];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    int imageSize = 1;
    UIImage *image = info[UIImagePickerControllerOriginalImage];
    
    float actualHeight = image.size.height;
    float actualWidth = image.size.width;
    
    CGRect rect = CGRectMake(0.0, 0.0, actualWidth/imageSize, actualHeight/imageSize);
    UIGraphicsBeginImageContext(rect.size);
    [image drawInRect:rect];
    
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    NSLog(@"Successfully built photo with width: %f and height: %f.", actualWidth, actualHeight);
    [[WDDrawingManager sharedInstance] createNewDrawingWithImage:img];
    [self reloadTheView];
    
    [self imagePickerControllerDidCancel:picker];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [popoverController_ dismissPopoverAnimated:YES];
    popoverController_ = nil;
}

#pragma mark - View Lifecycle

- (void) showAlert:(NSString*) title withText:(NSString*) message {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle: title message: message delegate: nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alert show];
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self setBarButtons];
}

- (void) willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    if (editingThumbnail_) {
        [editingThumbnail_ stopEditing];
    }
}

- (void) keyboardWillShow:(NSNotification *)aNotification {
    if (!editingThumbnail_ || blockingView_) {
        return;
    }
    
    NSValue     *endFrame = [aNotification userInfo][UIKeyboardFrameEndUserInfoKey];
    NSNumber    *duration = [aNotification userInfo][UIKeyboardAnimationDurationUserInfoKey];
    CGRect      frame = [endFrame CGRectValue];
    float       delta = 0;
    
    CGRect thumbFrame = editingThumbnail_.frame;
    thumbFrame.size.height += 20; // add a little extra margin between the thumb and the keyboard
    frame = [self.collectionView convertRect:frame fromView:nil];
    
    if (CGRectIntersectsRect(thumbFrame, frame)) {
        delta = CGRectGetMaxY(thumbFrame) - CGRectGetMinY(frame);
        
        CGPoint offset = self.collectionView.contentOffset;
        offset.y += delta;
        [self.collectionView setContentOffset:offset animated:YES];
    }
    
    blockingView_ = [[WDBlockingView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    AppDelegate *delegate = (AppDelegate *) [UIApplication sharedApplication].delegate;
    
    blockingView_.passthroughViews = @[editingThumbnail_.titleField];
    [delegate.window addSubview:blockingView_];
    
    blockingView_.target = self;
    blockingView_.action = @selector(blockingViewTapped:);
    
    CGPoint shadowCenter = [self.collectionView convertPoint:editingThumbnail_.center toView:delegate.window];
    [blockingView_ setShadowCenter:shadowCenter radius:kEditingHighlightRadius];
    blockingView_.alpha = 0;
    
    [UIView animateWithDuration:[duration doubleValue] animations:^{ blockingView_.alpha = 1; }];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (blockingView_ && editingThumbnail_) {
        AppDelegate *delegate = (AppDelegate *) [UIApplication sharedApplication].delegate;
        CGPoint shadowCenter = [self.collectionView convertPoint:editingThumbnail_.center toView:delegate.window];
        [blockingView_ setShadowCenter:shadowCenter radius:kEditingHighlightRadius];
    }
}

- (void) didEnterBackground:(NSNotification *)aNotification {
    if (!editingThumbnail_) {
        return;
    }
    
    [editingThumbnail_ stopEditing];
}

#pragma mark - Thumbnail Editing

- (BOOL) thumbnailShouldBeginEditing:(WDThumbnailView *)thumb {
    if (self.isEditing) {
        return NO;
    }
    
    // can't start editing if we're already editing another thumbnail
    return (editingThumbnail_ ? NO : YES);
}

- (void) blockingViewTapped:(id)sender {
    [editingThumbnail_ stopEditing];
}

- (void) thumbnailDidBeginEditing:(WDThumbnailView *)thumbView {
    editingThumbnail_ = thumbView;
}

- (void) thumbnailDidEndEditing:(WDThumbnailView *)thumbView {
    [UIView animateWithDuration:0.2f
                     animations:^{ blockingView_.alpha = 0; }
                     completion:^(BOOL finished) {
                         [blockingView_ removeFromSuperview];
                         blockingView_ = nil;
                     }];
    
    editingThumbnail_ = nil;
}

- (WDThumbnailView *) getThumbnail:(NSString *)filename {
    NSString *barefile = [[filename stringByDeletingPathExtension] stringByAppendingPathExtension:@"cusack"];
    NSIndexPath *indexPath = [[WDDrawingManager sharedInstance] indexPathForFilename:barefile];
    
    return (WDThumbnailView *) [self.collectionView cellForItemAtIndexPath:indexPath];
}

#pragma mark - Drawing Notifications

- (void) drawingChanged:(NSNotification *)aNotification {
    WDDocument *document = [aNotification object];
    
    [[self getThumbnail:document.filename] reload];
}

- (void) drawingAdded:(NSNotification *)aNotification {
    [self reloadTheView];
}

- (void) drawingsDeleted:(NSNotification *)aNotification {
    NSArray *indexPaths = aNotification.object;
    [self.collectionView deleteItemsAtIndexPaths:indexPaths];
    
    [selectedDrawings_ removeAllObjects];
    [self properlyEnableToolbarItems];
}

#pragma mark - Deleting Drawings

- (void) deleteSelectedDrawings {
    NSString *format = NSLocalizedString(@"Delete %d File(s)", @"Delete %d File(s)");
    NSString *title = (selectedDrawings_.count) == 1 ? NSLocalizedString(@"Delete File", @"Delete File") :
    [NSString stringWithFormat:format, selectedDrawings_.count];
    
    NSString *message;
    
    if (selectedDrawings_.count == 1) {
        message = NSLocalizedString(@"Once deleted, this file cannot be recovered.", @"Alert text when deleting 1 file");
    } else {
        message = NSLocalizedString(@"Once deleted, these file(s) cannot be recovered.", @"Alert text when deleting multiple file(s)");
    }
    
    NSString *deleteButtonTitle = NSLocalizedString(@"Delete", @"Delete");
    NSString *cancelButtonTitle = NSLocalizedString(@"Cancel", @"Cancel");

    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title
                                                        message:message
                                                       delegate:self
                                              cancelButtonTitle:nil
                                              otherButtonTitles:deleteButtonTitle, cancelButtonTitle, nil];
    alertView.cancelButtonIndex = 1;
    
    [alertView show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == alertView.cancelButtonIndex) {
        return;
    }
    [[WDDrawingManager sharedInstance] deleteDrawings:selectedDrawings_];
}

- (void) showDeleteMenu:(id)sender {
    if (deleteSheet_) {
        [self dismissPopover];
        return;
    }
    
    [self dismissPopover];
    
    NSString *format = NSLocalizedString(@"Delete %d Files", @"Delete %d Files");
    NSString *title = (selectedDrawings_.count) == 1 ?
        NSLocalizedString(@"Delete File", @"Delete File") :
        [NSString stringWithFormat:format, selectedDrawings_.count];
    
	deleteSheet_ = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:@"Cancel"
                                 destructiveButtonTitle:title otherButtonTitles:nil];

    [deleteSheet_ showFromBarButtonItem:sender animated:YES];
}
     
 - (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (actionSheet == deleteSheet_) {
        if (buttonIndex == actionSheet.destructiveButtonIndex) {
            [self deleteSelectedDrawings];
        }
    }
    deleteSheet_ = nil;
}

#pragma mark - Editing

- (void) startEditing:(id)sender {
    [self setEditing:YES animated:YES];
}

- (void) stopEditing:(id)sender {
    [self setEditing:NO animated:YES];
}

- (void) setEditing:(BOOL)editing animated:(BOOL)animated {
    [self dismissPopover];
    
    [super setEditing:editing animated:animated];
    
    if (editing) {
        self.title = NSLocalizedString(@"Select File(s)", @"Select File(s)");
        [self setToolbarItems:[self editingToolbarItems] animated:YES];
        [self properlyEnableToolbarItems];
    } else {
        self.title = NSLocalizedString(@"Your Gallery", @"Your Gallery");

        self.collectionView.allowsSelection = NO;
        self.collectionView.allowsSelection = YES;
        
        [selectedDrawings_ removeAllObjects];
        [self setToolbarItems:[self defaultToolbarItems] animated:NO];
    }
    
    self.collectionView.allowsMultipleSelection = editing;
}

#pragma mark - Toolbar

- (void) properlyEnableToolbarItems {
    deleteItem_.enabled = [selectedDrawings_ count] == 0 ? NO : YES;
    emailItem_.enabled = ([selectedDrawings_ count] > 0 && [selectedDrawings_ count] < 6) ? YES : NO;
}

- (NSArray *) editingToolbarItems {
    NSMutableArray *items = [NSMutableArray array];
    
    UIBarButtonItem *fixedItem = [UIBarButtonItem fixedItemWithWidth:32];
	UIBarButtonItem *flexibleItem = [UIBarButtonItem flexibleItem];
    
    if ([MFMailComposeViewController canSendMail]) {
        if (!emailItem_) {
            emailItem_ = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Email (Up To 5)", @"Email (Up To 5)")
                                                          style:UIBarButtonItemStyleBordered
                                                         target:self
                                                         action:@selector(showEmailPanel:)];
        }
        [items addObject:emailItem_];
        [items addObject:fixedItem];
    }
    
    if (!deleteItem_) {
        deleteItem_ = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Delete", @"Delete")
                                                                    style:UIBarButtonItemStyleBordered
                                                                    target:self
                                                                    action:@selector(showDeleteMenu:)];
    }
    
    UIBarButtonItem *doneItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Close Options", @"Close Options")
                                                                                style:UIBarButtonItemStyleBordered
                                                                              target:self
                                                                              action:@selector(stopEditing:)];
    
    [items addObject:deleteItem_];
    [items addObject:flexibleItem];
    [items addObject:doneItem];
    
    return items;
}

- (void) goToNav:(id)sender {
    UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"Modules" bundle: nil];
    WDBrowserController *galleryViewController = (WDBrowserController*)[mainStoryboard instantiateViewControllerWithIdentifier: @"NavPage"];
    [self.navigationController pushViewController:galleryViewController animated:YES];
}

- (void) goToMakeMap:(id)sender {
    UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"Modules" bundle: nil];
    MapGenerationViewController *makeMapViewController = (MapGenerationViewController*)[mainStoryboard instantiateViewControllerWithIdentifier: @"MakeMapPage"];
    [self.navigationController pushViewController:makeMapViewController animated:YES];
}

-(void) showBar {
    [self.navigationController setToolbarHidden:NO animated:YES];
    [self.navigationController setNavigationBarHidden:NO animated:YES];
    self.navigationController.navigationBar.translucent = NO;
    self.navigationController.toolbar.translucent = NO;
}

-(void) hideBar {
    [self.navigationController setToolbarHidden:YES animated:YES];
    [self.navigationController setNavigationBarHidden:NO animated:YES];
    self.navigationController.navigationBar.translucent = NO;
    self.navigationController.toolbar.translucent = NO;
}

#pragma mark - Memos
-(IBAction) memoAction:(id)sender {
    if(![self.restorationIdentifier isEqual: @"MemoPage"]){
        UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"TechAssistant" bundle: nil];
        SurveyController *goForwardController = (SurveyController *)[mainStoryboard instantiateViewControllerWithIdentifier: @"MemoPage"];
        [self.navigationController pushViewController:goForwardController animated:YES];
    }
}

#pragma mark - Panels
- (void) showFontLibraryPanel:(id)sender {
    if (fontLibraryController_) {
        [self dismissPopover];
        return;
    }
    
    [self dismissPopover];
    
    fontLibraryController_ = [[WDFontLibraryController alloc] initWithNibName:nil bundle:nil];

    UINavigationController  *navController = [[UINavigationController alloc] initWithRootViewController:fontLibraryController_];
    
    popoverController_ = [[UIPopoverController alloc] initWithContentViewController:navController];
    popoverController_.delegate = self;
    [popoverController_ presentPopoverFromBarButtonItem:sender permittedArrowDirections:UIPopoverArrowDirectionAny animated:NO];
}

- (void) showActivityPanel:(id)sender {
    if (activityController_) {
        [self dismissPopover];
        return;
    }
    
    [self dismissPopover];
    
    activityController_ = [[WDActivityController alloc] initWithNibName:nil bundle:nil];
    activityController_.activityManager = activities_;
    
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:activityController_];
    
    popoverController_ = [[UIPopoverController alloc] initWithContentViewController:navController];
    popoverController_.delegate = self;
    [popoverController_ presentPopoverFromBarButtonItem:sender permittedArrowDirections:UIPopoverArrowDirectionAny animated:NO];
}

- (void) activityCountChanged:(NSNotification *)aNotification {
    NSUInteger numActivities = activities_.count;
    
    if (numActivities) {
        //[activityIndicator_ startAnimating];
    } else {
        //[activityIndicator_ stopAnimating];
    }
    
    if (numActivities == 0) {
        if (activityController_) {
            [self dismissPopoverAnimated:YES];
        }
        
        [toolbarItems_ removeObject:activityItem_];
        
        if (!self.isEditing) {
            [self setToolbarItems:[NSArray arrayWithArray:[self defaultToolbarItems]] animated:YES];
        }
    } else if (![toolbarItems_ containsObject:activityItem_]) {
        [toolbarItems_ insertObject:activityItem_ atIndex:(toolbarItems_.count - 2)];
        
        if (!self.isEditing) {
            [self setToolbarItems:[NSArray arrayWithArray:[self defaultToolbarItems]] animated:YES];
        }
    }
}

- (void) showHelp:(id)sender {
    WDHelpController *helpController = [[WDHelpController alloc] initWithNibName:nil bundle:nil];
    
    [self.navigationController pushViewController:helpController animated:YES];
}

#pragma mark - Popovers

- (void) dismissPopoverAnimated:(BOOL)animated {
    if (popoverController_) {
        [popoverController_ dismissPopoverAnimated:animated];
        popoverController_ = nil;
    }
    
    exportController_ = nil;
    importController_ = nil;
    pickerController_ = nil;
    fontLibraryController_ = nil;
    activityController_ = nil;
    
    if (deleteSheet_) {
        [deleteSheet_ dismissWithClickedButtonIndex:deleteSheet_.cancelButtonIndex animated:NO];
        deleteSheet_ = nil;
    }
}

- (void) dismissPopover {
    [self dismissPopoverAnimated:NO];
}

- (void) popoverControllerDidDismissPopover:(UIPopoverController *)popoverController {
    if (popoverController == popoverController_) {
        popoverController_ = nil;
    }
    
    exportController_ = nil;
    importController_ = nil;
    pickerController_ = nil;
    fontLibraryController_ = nil;
    activityController_ = nil;
}

- (void)didDismissModalView {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Email

-(void) mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error {
	switch (result) {
        case MFMailComposeResultCancelled:
            NSLog(@"Mail cancelled");
            break;
        case MFMailComposeResultSaved:
            NSLog(@"Mail saved");
            break;
        case MFMailComposeResultSent:
            NSLog(@"Mail sent");
            break;
        case MFMailComposeResultFailed:
            NSLog(@"Mail sent failure: %@", [error localizedDescription]);
            break;
        default:
            break;
    }
    [self dismissViewControllerAnimated:YES completion:NULL];
}

-(void) emailDrawings:(id)sender {
    if([[UIDevice currentDevice].model isEqualToString:@"iPhone"]) {
        [self dismissViewControllerAnimated:YES completion:NULL];
    } else {
        [self dismissPopover];
    }
    
    //web locations
    NSString *cloudImage = @"<img src=\"https://www.home.b2innovation.com/img/hero-bg.png\" width=\"600\" height=\"61\">";
    NSString *reverseCloud = @"<img src=\"https://www.home.b2innovation.com/img/cloudReverse.png\" width=\"600\" height=\"61\">";
    NSString *privateImage = @"<img src=\"https://www.home.b2innovation.com/img/emailPhotos/optimizedPic.jpg\" width=\"600\" height=\"120\">";
    NSString *privateGif = @"<img src=\"https://www.home.b2innovation.com/img/emailPhotos/optimizedGif.gif\" width=\"600\" height=\"160\">";
    
    //addresses
    NSString *version = [[NSBundle mainBundle] infoDictionary][(NSString *)kCFBundleVersionKey];
    NSString *showVersion = [NSString stringWithFormat:@"%@:<br><i>%@: %@</i><br>", [AppDelegate deliverCompanyName], [AppDelegate deliverProductName], version];
    NSString *jobNum = [(AppDelegate *) [UIApplication sharedApplication].delegate selectedJob];
    NSString *htmlAddress = [NSString stringWithFormat:@"Job Number:<br><i>%@</i><br>", jobNum];
    NSString *currentUser = [(AppDelegate *) [UIApplication sharedApplication].delegate currentUser];
    NSString *systemID = [NSString stringWithFormat:@"System ID:<br><i>%@</i><br>", currentUser];
    NSString *jobAddress = [[(AppDelegate *) [UIApplication sharedApplication].delegate surveyDataDictionary] objectForKey:@"Address"];
    NSString *projectLocation = [NSString stringWithFormat:@"Project Location:<br><i>%@</i><br>", jobAddress];
    NSString *boxFolder = [AppDelegate boxEmailAddress];
    NSString *filesLocationString = [NSString stringWithFormat:@"Files now available here, in the cloud:<br><i>https://app.box.com/folder/%@</i><br>", [AppDelegate boxEmailedPage]];
    
    
    //HTML IMAGES/GIFS
    NSString *htmlBody = [NSString stringWithFormat:@"%@<br><br>%@<br>%@<br>%@<br>%@<br>%@<br>%@<br>%@<h3>Tech Assistant available <i>NOW</i> for iPad and iPhone.</h3>Tech Assistant <i>COMING SOON</i> to Android 11!<br>B2 Innovation © 2013-2021. All Rights Reserved.<br><br>Visit us at:<br>https://www.b2innovation.com/", reverseCloud, showVersion, projectLocation, htmlAddress, systemID, filesLocationString, cloudImage, privateGif];
    
    //NSString *htmlBody = [NSString stringWithFormat:@"<center>%@%@</center>%@<br>%@<br>%@<br>%@<center>%@<br>%@: %@ available now for tablet and phone.<br>© B2Innovation 2013-2021. All Rights Reserved.<br>https://www.b2innovation.com/<h3>Coming soon to OSX and Android</h3></center>", showVersion, reverseCloud, projectLocation, htmlAddress, systemID, filesLocationString, htmlString, [AppDelegate deliverProductName], version];
    
    //send it
    NSString *emailTitle = [NSString stringWithFormat:@"[MAP UPDATE] %@ Cloud Preparation.", jobNum];
    NSString *eMailFE = [[(AppDelegate *) [UIApplication sharedApplication].delegate surveyDataDictionary] objectForKey:@"Field Engineer Email"];
    NSArray *ccRecipients = [AppDelegate deliverRecipients];
    NSArray *toRecipients = [NSArray arrayWithObjects: eMailFE, boxFolder, nil];
    NSString *format = [[NSUserDefaults standardUserDefaults] objectForKey:WDEmailFormatDefault];
    MFMailComposeViewController *picker = [[MFMailComposeViewController alloc] init];
    picker.mailComposeDelegate = self;
    [picker setSubject:emailTitle];
    [picker setMessageBody:htmlBody isHTML:YES];
    [picker setToRecipients:toRecipients];
    [picker setCcRecipients:ccRecipients];
    WDEmail *email = [[WDEmail alloc] init];
    email.completeAttachments = 0;
    email.expectedAttachments = [selectedDrawings_ count];
    email.picker = picker;
    
    for (NSString *filename in selectedDrawings_) {
        [[self getThumbnail:filename] startActivity];
        [[WDDrawingManager sharedInstance] openDocumentWithName:filename withCompletionHandler:^(WDDocument *document) {
            WDDrawing *drawing = document.drawing; // TODO use document contentForType
            NSData *data = nil;
            NSString *extension = nil;
            NSString *mimeType = nil;
            
            if ([format isEqualToString:@"cusack"]) {
                data = [[WDDrawingManager sharedInstance] dataForFilename:filename];
                extension = WDDrawingFileExtension;
                mimeType = @"application/x-cusack";
            } else if ([format isEqualToString:@"SVG"]) {
                data = [drawing SVGRepresentation];
                extension = @"svg";
                mimeType = @"image/svg+xml";
            } else if ([format isEqualToString:@"SVGZ"]) {
                data = [[drawing SVGRepresentation] compress];
                extension = @"svgz";
                mimeType = @"image/svg+xml";
            } else if ([format isEqualToString:@"PNG"]) {
                data = UIImagePNGRepresentation([drawing image]);
                extension = @"png";
                mimeType = @"image/png";
            } else if ([format isEqualToString:@"JPEG"]) {
                data = UIImageJPEGRepresentation([drawing image], [AppDelegate deliverMapsCompressionRatio]);
                extension = @"jpeg";
                mimeType = @"image/jpeg";
            } else if ([format isEqualToString:@"PDF"]) {
                data = [drawing PDFRepresentation];
                extension = @"pdf";
                mimeType = @"image/pdf";
            }
            [picker addAttachmentData:data mimeType:mimeType fileName:[[filename stringByDeletingPathExtension] stringByAppendingPathExtension:extension]];
            
            [[NSNotificationCenter defaultCenter] postNotificationName:WDAttachmentNotification object:email userInfo:@{@"path": filename}];
        }];
    }
}

- (void) emailAttached:(NSNotification *)aNotification {
    WDEmail *email = aNotification.object;
    NSString *path = [aNotification.userInfo valueForKey:@"path"];
    id thumbnail = [self getThumbnail:path];
    [thumbnail stopActivity];
    if (++email.completeAttachments == email.expectedAttachments) {
        [self.navigationController presentViewController:email.picker animated:YES completion:nil];
    }
}

-(void) showEmailPanel:(id)sender {
    if (exportController_ && exportController_.mode == kWDExportViaEmailMode) {
        [self dismissPopover];
        return;
    }
    
    [self dismissPopover];
    
    exportController_ = [[WDExportController alloc] initWithNibName:nil bundle:nil];
    exportController_.mode = kWDExportViaEmailMode;
    exportController_.action = @selector(emailDrawings:);
    exportController_.target = self;
    
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:exportController_];
    
    if([[UIDevice currentDevice].model isEqualToString:@"iPhone"]) {
        [self presentViewController:navController animated:YES completion:nil];
    } else {
        popoverController_ = [[UIPopoverController alloc] initWithContentViewController:navController];
        popoverController_.delegate = self;
        [popoverController_ presentPopoverFromBarButtonItem:sender permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
    }
}

-(void) reallyShowBoxImportPanel:(id)sender {
    if (importController_) {
		[self dismissPopover];
		return;
	}
	
	BOXContentClient *contentClient = [BOXContentClient defaultClient];
    BOXSampleFolderViewController *boxFolderController = [[BOXSampleFolderViewController alloc] initWithClient:contentClient folderID:[AppDelegate boxTemplatesPage]];
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:boxFolderController];
    navController.modalPresentationStyle = UIModalPresentationPopover;
    navController.popoverPresentationController.sourceView = sender;
    navController.preferredContentSize = self.view.bounds.size;
    
    [self presentViewController:navController animated:YES completion:nil];
}

#pragma mark -

- (void) showImportErrorMessage:(NSString *)filename {
    NSString *format = NSLocalizedString(@"Could not import “%@”. It may be corrupt or in a format that's not supported.",
                                         @"Could not import “%@”. It may be corrupt or in a format that's not supported.");
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Import Problem", @"Import Problem")
                                                        message:[NSString stringWithFormat:format, filename]
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"OK", @"OK")
                                              otherButtonTitles:nil];
    [alertView show];
}

- (void) showImportMemoryWarningMessage:(NSString *)filename {
    NSString *format = NSLocalizedString(@"Could not import “%@”. There is not enough available memory.",
                                         @"Could not import “%@”. There is not enough available memory.");
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Import Problem", @"Import Problem")
                                                        message:[NSString stringWithFormat:format, filename]
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"OK", @"OK")
                                              otherButtonTitles:nil];
    [alertView show];
}

- (void) showImportBeginMessage {
    NSString *format = NSLocalizedString(@"Executing first time cloud import to your gallery...",
                                         @"Executing first time cloud import to your gallery...");
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Flow->Through->Process", @"Flow->Through->Process")
                                                        message:[NSString stringWithFormat:format]
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"OK", @"OK")
                                              otherButtonTitles:nil];
    [alertView show];
}

#pragma mark -

- (NSString*) appFolderPath {
    NSString* appFolderPath = @"TechAssistant";
    if (![appFolderPath isAbsolutePath]) {
        appFolderPath = [@"/" stringByAppendingString:appFolderPath];
    }
    
    return appFolderPath;
}

#pragma mark import drawing
- (void)installPDFs:(void (^)(void))completionBlock {
    NSString* downloadPath = [[WDDrawingManager drawingPath] stringByAppendingPathComponent:@"/Downloads"];
    NSArray *dirFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:downloadPath error:NULL];
    NSArray *pdfURLs = [dirFiles filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self ENDSWITH[c] '.pdf'"]];
    
    if (pdfURLs.count == 0) {
        if (completionBlock) {
            completionBlock();
        }
        return;
    }
    [self installPDFs:pdfURLs index:0 completion:completionBlock];
}

- (void)installPDFs:(NSArray *)pdfURLs index:(NSInteger)index completion:(void (^)(void))completionBlock {
    int printInt = ((int)index + 1);
    NSLog(@"File %d: %@", printInt, [pdfURLs objectAtIndex:index]);
    
    NSString* downloadPath = [[WDDrawingManager drawingPath] stringByAppendingPathComponent:@"/Downloads"];
    NSString* filePath = [downloadPath stringByAppendingPathComponent:pdfURLs[index]];
    [[WDDrawingManager sharedInstance] createNewDrawingWithPDFAtURL:[NSURL fileURLWithPath:filePath]];
    
    NSError *error = nil;
    [[NSFileManager defaultManager] removeItemAtPath:filePath error:&error];
    if(error) {
        NSLog(@"Error deleting input file: %@, error:%@", filePath, [error localizedDescription]);
    }
    
    if (pdfURLs.count == index + 1) {
        NSLog(@"PDF COUNT %d.", pdfURLs.count);
        if (completionBlock) {
            completionBlock();
        }
        [self fullProgressView];
        return;
    }
    [self updateProgressView:printInt];
    [AppDelegate playSave];
    [self installPDFs:pdfURLs index:index + 1 completion:completionBlock];
}

- (void)installSVGs:(void (^)(void))completionBlock {
    NSString* downloadPath = [[WDDrawingManager drawingPath] stringByAppendingPathComponent:@"/Downloads"];
    NSArray *dirFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:downloadPath error:NULL];
    NSArray *svgURLs = [dirFiles filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self ENDSWITH[c] '.svg'"]];
    
    if (svgURLs.count == 0) {
        if (completionBlock)
            completionBlock();
        return;
    }
    [self installSVGs:svgURLs index:0 completion:completionBlock];
}

- (void)installSVGs:(NSArray *)svgURLs index:(NSInteger)index completion:(void (^)(void))completionBlock {
    int printInt = ((int)index + 1);
    NSLog(@"File %d: %@", printInt, [svgURLs objectAtIndex:index]);
    
    NSString* downloadPath = [[WDDrawingManager drawingPath] stringByAppendingPathComponent:@"/Downloads"];
    NSString* filePath = [downloadPath stringByAppendingPathComponent:svgURLs[index]];
    [[WDDrawingManager sharedInstance] importSVGAtURL:[NSURL fileURLWithPath:filePath] errorBlock:^{
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Broken File", @"Broken File")
                                                            message:NSLocalizedString(@"TechAssistant© has detected a corruption in the file.", @"TechAssistant© has detected a corruption in the file.")
                                                           delegate:nil
                                                  cancelButtonTitle:NSLocalizedString(@"OK", @"OK")
                                                  otherButtonTitles:nil];
        [alertView show];
    } withCompletionHandler:^() {
        NSError *error = nil;
        [[NSFileManager defaultManager] removeItemAtPath:filePath error:&error];
        if(error) {
            NSLog(@"Error deleting input file: %@, error:%@", filePath, [error localizedDescription]);
        }
    }];
    
    if (svgURLs.count == index + 1) {
        NSLog(@"SVG COUNT %d.", svgURLs.count);
        if (completionBlock) {
            completionBlock();
        }
        [self fullProgressView];
        return;
    }
    [self updateProgressView:printInt];
    [AppDelegate playSave];
    [self installSVGs:svgURLs index:index + 1 completion:completionBlock];
}

- (void)installPictureFiles:(void (^)(void))completionBlock {
    NSString* downloadPath = [[WDDrawingManager drawingPath] stringByAppendingPathComponent:@"/Downloads"];
    NSArray *dirFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:downloadPath error:NULL];
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        return [evaluatedObject hasSuffix:@".jpg"] || [evaluatedObject hasSuffix:@".jpeg"] ||[evaluatedObject hasSuffix:@"png"];
    }];
    
    NSArray *imgURLs = [dirFiles filteredArrayUsingPredicate:predicate];
    if (imgURLs.count == 0) {
        if (completionBlock)
            completionBlock();
        return;
    }
    [self installPictureFiles:imgURLs index:0 completion:completionBlock];
}

- (void)installPictureFiles:(NSArray *)imgURLs index:(NSInteger)index completion:(void (^)(void))completionBlock {
    int printInt = ((int)index + 1);
    NSLog(@"File %d: %@", printInt, [imgURLs objectAtIndex:index]);
    
    NSString* downloadPath = [[WDDrawingManager drawingPath] stringByAppendingPathComponent:@"/Downloads"];
    NSString* filePath = [downloadPath stringByAppendingPathComponent:imgURLs[index]];
    [[WDDrawingManager sharedInstance] createNewDrawingWithImageAtURL:[NSURL fileURLWithPath:filePath]];
    [[WDDrawingManager sharedInstance] importDrawingAtURL:[NSURL fileURLWithPath:filePath] errorBlock:^{
    } withCompletionHandler:^(WDDocument *document) {
        NSError *error = nil;
        [[NSFileManager defaultManager] removeItemAtPath:filePath error:&error];
        if(error) {
            NSLog(@"Error deleting input file: %@, error:%@", filePath, [error localizedDescription]);
        }
    }];
    
    if (imgURLs.count == index + 1) {
        if (completionBlock) {
            completionBlock();
        }
        [self fullProgressView];
        return;
    }
    [self updateProgressView:printInt];
    [AppDelegate playSave];
    [self installPictureFiles:imgURLs index:index + 1 completion:completionBlock];
}

#pragma mark - Storyboard / Collection View

- (BOOL) shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender {
    return !self.isEditing;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([[segue identifier] isEqualToString:@"editDrawing"]) {
        WDCanvasController *canvasController = [segue destinationViewController];
        NSUInteger index = [[WDDrawingManager sharedInstance] indexPathForFilename:((WDThumbnailView *)sender).filename].item;
        WDDocument *document = [[WDDrawingManager sharedInstance] openDocumentAtIndex:index withCompletionHandler:nil];
        [canvasController setDocument:document];
    }
}

- (BOOL)collectionView:(UICollectionView *)collectionView shouldSelectItemAtIndexPath:(NSIndexPath *)indexPath; {
    WDThumbnailView *thumbnailView = (WDThumbnailView *) [collectionView cellForItemAtIndexPath:indexPath];
    thumbnailView.shouldShowSelectionIndicator = self.isEditing;
    
    return YES;
}

- (void) updateSelectionTitle {
    NSUInteger count = selectedDrawings_.count;
    NSString*format;
    
    if (count == 0) {
        self.title = NSLocalizedString(@"Select File(s)", @"Select File(s)");
    } else if (count == 1) {
        self.title = NSLocalizedString(@"1 File Selected", @"1 File Selected");
    } else {
        format = NSLocalizedString(@"%lu Files Selected", @"%lu Files Selected");
        self.title = [NSString stringWithFormat:format, count];
    }
}

- (void) collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    NSString *filename = [[WDDrawingManager sharedInstance] fileAtIndex:indexPath.item];
    
    if (self.isEditing) {
        [selectedDrawings_ addObject:filename];
        
        [self updateSelectionTitle];
        [self properlyEnableToolbarItems];
    } else {
        [self getThumbnail:filename].selected = NO;
    }
}

- (void) collectionView:(UICollectionView *)collectionView didDeselectItemAtIndexPath:(NSIndexPath *)indexPath {
    if (self.isEditing) {
        NSString *filename = [[WDDrawingManager sharedInstance] fileAtIndex:indexPath.item];
        [selectedDrawings_ removeObject:filename];
        
        [self updateSelectionTitle];
        [self properlyEnableToolbarItems];
    }
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section; {
    return [[WDDrawingManager sharedInstance] numberOfDrawings];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath; {
    WDThumbnailView *thumbnail = [collectionView dequeueReusableCellWithReuseIdentifier:@"cellID" forIndexPath:indexPath];
    NSArray *drawings = [[WDDrawingManager sharedInstance] drawingNames];
    
    thumbnail.filename = drawings[indexPath.item];
    thumbnail.tag = indexPath.item;
    thumbnail.delegate = self;
    
    if (self.isEditing) {
        thumbnail.shouldShowSelectionIndicator = YES;
        thumbnail.selected = [selectedDrawings_ containsObject:thumbnail.filename] ? YES : NO;
    }
    
    thumbnail.layer.shouldRasterize = YES;
    thumbnail.layer.rasterizationScale = [UIScreen mainScreen].scale;
    
    return thumbnail;
}

- (void) saveStringData: (NSString*)obj forKey:(NSString*)key {
    NSMutableDictionary *dicData = [(AppDelegate *) [UIApplication sharedApplication].delegate surveyDataDictionary];
    if(obj != nil)
        [dicData setObject:obj forKey: key];
}

- (IBAction)goToPolePage:(id)sender {
    UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"Poles" bundle: nil];
    PolePage *surveyViewController = (PolePage*)[mainStoryboard instantiateViewControllerWithIdentifier: @"polePage0"];
    [self.navigationController pushViewController:surveyViewController animated:YES];
}

@end
