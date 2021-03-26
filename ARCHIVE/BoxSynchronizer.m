//
//  BoxSynchronizer.m
//  TechAssistant
//
//  Copyright © 2013-2021 B2Innovation, L.L.C. All rights reserved
//  Created by Jason Cusack on 10/30/18
//

#import "BoxSynchronizer.h"

//#define NUMBER_FORMAT(X) [[BRANumberFormat alloc] initWithOpenXmlAttributes:@{@"_formatCode": X} inStyles:_spreadsheet.workbook.styles]

@interface BoxSynchronizer ()

@end

@implementation BoxSynchronizer

+ (BoxSynchronizer *)sharedSynchronizer {
    static BoxSynchronizer* synchronizer = nil;
    static dispatch_once_t queue;
    dispatch_once(&queue, ^{
        synchronizer = [[BoxSynchronizer alloc] init];
    });
    
    return synchronizer;
}

- (NSMutableDictionary *) getDictionaryOnMainThread {
    
    NSMutableDictionary *returnDictionary = [(AppDelegate *) [UIApplication sharedApplication].delegate surveyDataDictionary];
    
    return returnDictionary;
}

- (id)init {
    self = [super init];
    
    if (self) {
        [self setDocumentDirectory];
        [self createTechAssistantFolder];
        
        AppDelegate *delegate = (AppDelegate *) [UIApplication sharedApplication].delegate;
        delegate.surveyDataDictionary = [[NSMutableDictionary alloc] init];
        delegate.userJobsDictionary = [[NSMutableDictionary alloc] init];
        delegate.poleDataDictionary = [[NSMutableDictionary alloc] init];
        
        //pool all local files
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(bundleEverything:)
                                                     name:@"com.cusoft.bundleEverything"
                                                   object:nil];
        //thread rip through the xlsx generation
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(threadRipXlsx:)
                                                     name:@"com.cusoft.threadRipXlsx"
                                                   object:nil];
        //create the cloud folders
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(userTappedUpload:)
                                                     name:@"com.cusoft.userTappedUpload"
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(logout:)
                                                     name:@"com.cusoft.logout"
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(login:)
                                                     name:@"com.cusoft.login"
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(updateJobsList:)
                                                     name:@"com.cusoft.updateJobsList"
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(parseUsersList:)
                                                     name:@"com.cusoft.parseUsersList"
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(parseUserJobList:)
                                                     name:@"com.cusoft.parseUserJobList"
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(deleteCloudFolder:)
                                                     name:@"com.cusoft.deleteCloudFolder"
                                                   object:nil];
    }
    NSLog(@"BOX SYNCHRONIZER INIT");
    return self;
}

-(void) login:(NSNotification *)notification {
    AppDelegate *delegate = (AppDelegate *) [UIApplication sharedApplication].delegate;
    
    //working folder
    [self setJobDirectory];
    
    //spreadsheet name
    NSMutableDictionary *plistDict = delegate.surveyDataDictionary;
    NSString *nameInsert = [plistDict objectForKey:@"fullName"];
    self.spreadSheetName = [NSString stringWithFormat:@"%@ by %@ and B2Innovation.xlsx", delegate.selectedJob, nameInsert];
        
    //package path
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = paths[0];
    NSString *drawingsPath =  [[documentsDirectory stringByAppendingPathComponent:@"TechAssistant"] stringByAppendingPathComponent:delegate.selectedJob];
    NSString *uploadPath = [drawingsPath stringByAppendingPathComponent:@"Upload"];
    self.packagePath = [uploadPath stringByAppendingPathComponent:self.spreadSheetName];
        
    //completed path
    self.completedPath = [drawingsPath stringByAppendingPathComponent:@"Completed"];
        
    //temp path
    self.tempPath = [drawingsPath stringByAppendingPathComponent:@"Temp"];
        
    //upload path
    self.uploadPath = [drawingsPath stringByAppendingPathComponent:@"Upload"];
    
    //upload path
    self.xmlPath = [drawingsPath stringByAppendingPathComponent:@"XML"];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    self.searchLetter = nil;
    self.allPhotos = nil;
    self.allDrawings = nil;
    self.uploadPath = nil;
    self.completedPath = nil;
    self.tempPath = nil;
    self.packagePath = nil;
    self.spreadSheetName = nil;
    self.xmlPath = nil;
    self.documentsDirectory = nil;
    self.jobDirectory = nil;
    
    self.folderModelID = nil;
    self.polesFolderModelID = nil;
    self.photosFolderModelID = nil;

    self.totalNeededUploads = nil;
    self.totalCompletedUploads = nil;
}

- (void) logout: (NSNotification *)notification {
    NSLog(@"BOX SYNCHRONIZER ---LOGOUT---");
    ((AppDelegate *) [UIApplication sharedApplication].delegate).currentJobs = nil;
    ((AppDelegate *) [UIApplication sharedApplication].delegate).currentAddresses = nil;
    
    self.searchLetter = nil;
    self.allPhotos = nil;
    self.allDrawings = nil;
    self.uploadPath = nil;
    self.completedPath = nil;
    self.tempPath = nil;
    self.packagePath = nil;
    self.spreadSheetName = nil;
    self.jobDirectory = nil;
    self.xmlPath = nil;
    
    self.folderModelID = nil;
    self.polesFolderModelID = nil;
    self.photosFolderModelID = nil;
    
    self.totalNeededUploads = nil;
    self.totalCompletedUploads = nil;
}

- (void) updateJobsList:(NSNotification *)notification {
    BOXContentClient *contentClient = [BOXContentClient defaultClient];
    NSLog(@"Updating from Lists Folder");
    
    BOXFolderItemsRequest *folderItemsRequest = [contentClient folderItemsRequestWithID:[AppDelegate boxListsPage]];
    [folderItemsRequest performRequestWithCompletion:^(NSArray *verifiedItems, NSError *error) {
        if(verifiedItems) {
            //download xlsx files to local
            NSLog(@"Checking %lu items in Lists.", (unsigned long)verifiedItems.count);
            
            for(int j=0; j<verifiedItems.count; j++) {
                BOXItem *verifiedItem = verifiedItems[j];
                if (verifiedItem.isFolder) {
                    NSLog(@"Skipping BACKUP folder: %@.", verifiedItem);
                } else { //the two xlsx files we need
                    NSString *finalPath = [self.documentsDirectory stringByAppendingPathComponent:verifiedItem.name];
                    BOXFileDownloadRequest *boxRequest = [self fileDownloadRequestWithID:verifiedItem.modelID toLocalFilePath:finalPath];
                    [boxRequest performRequestWithProgress:^(long long totalBytesTransferred, long long totalBytesExpectedToTransfer) {
                        // Update a progress bar, etc.
                    } completion:^(NSError *error) {
                        // Download has completed. If it failed, error will contain reason (e.g. network connection)
                        if(error) {
                            NSLog(@"Failed the download of %@ to %@.", verifiedItem, finalPath);
                        }
                        else {
                            if([verifiedItem.name isEqualToString:[AppDelegate boxInputJobsFile]]) {
                                NSLog(@"JOBS FILE at %@ moved to %@.", verifiedItem, finalPath);
                                [[NSNotificationCenter defaultCenter] postNotificationName:@"com.cusoft.updateJobListComplete" object:nil];
                            } else if([verifiedItem.name isEqualToString:[AppDelegate boxOutputTemplateFile]]) {
                                NSLog(@"OUTPUT TEMPLATE at %@ moved to %@.", verifiedItem, finalPath);
                            } else {
                                NSLog(@"Downloaded %@ to %@.", verifiedItem, finalPath);
                            }
                        }
                    }];
                }
            }
        }
    }];
}

- (BOXFileDownloadRequest *)fileDownloadRequestWithID:(NSString *)fileID toLocalFilePath:(NSString *)localFilePath {
    BOXContentClient *contentClient = [BOXContentClient defaultClient];
    BOXFileDownloadRequest *request = [[BOXFileDownloadRequest alloc] initWithLocalDestination:localFilePath fileID:fileID];
    [contentClient prepareRequest:request];
    
    return request;
}

- (BOOL) isFileNotEmpty:(NSString*) path {
    BOOL fileNotEmpty = NO;
    NSFileManager *manager = [NSFileManager defaultManager];
    if ([manager fileExistsAtPath:path]) {
        NSDictionary *attributes = [manager attributesOfItemAtPath:path error:nil];
        unsigned long long size = [attributes fileSize];
        if (attributes && size != 0) {
            // file exists and not empty.
            fileNotEmpty = YES;
        }
    }
    return fileNotEmpty;
}

- (void) createTechAssistantFolder {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0]; // Get documents folder
    NSString *dataPath = [documentsDirectory stringByAppendingPathComponent:@"/TechAssistant"];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:dataPath])
        [[NSFileManager defaultManager] createDirectoryAtPath:dataPath withIntermediateDirectories:NO attributes:nil error:nil];
}

- (NSString *) copyFileToDocumentDirectory : (NSString *) fileName {
    NSError *error;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                         NSUserDomainMask,
                                                         YES);
    NSString *documentsDir = [paths objectAtIndex:0];
    NSString *documentDirPath = [documentsDir
                                 stringByAppendingPathComponent:fileName];
    
    NSArray *file = [fileName componentsSeparatedByString:@"."];
    NSString *filePath = [[NSBundle mainBundle]
                          pathForResource:[file objectAtIndex:0]
                          ofType:[file lastObject]];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL success = [fileManager fileExistsAtPath:documentDirPath];
    
    if (!success) {
        success = [fileManager copyItemAtPath:filePath
                                       toPath:documentDirPath
                                        error:&error];
        if (!success) {
            NSAssert1(0, @"Failed to create writable txt file file with message \
                      '%@'.", [error localizedDescription]);
        }
    }
    return documentDirPath;
}

- (void) generatePDFFile:(NSDictionary *)plistDict outputPath:(NSString *)filePath {
    NSMutableData *pdfData = [NSMutableData data];
    
    UIGraphicsBeginPDFContextToData(pdfData, [UIScreen mainScreen].bounds, nil);
    
    // Draw Page 1
    [self drawCoverSheet0:plistDict];
    [self drawCoverSheet1:plistDict];
    [self drawCoverSheet2:plistDict];
    
    // Draw Photo Page
    [self drawPhotoPage:plistDict];
    
    UIGraphicsEndPDFContext();
    
    // Write PDF cover sheet to cloud
    [pdfData writeToFile:filePath atomically:YES];
}

+ (void) resizeFontForLabel:(UILabel*)aLabel {
    // use font from provided label so we don't lose color, style, etc
    UIFont *font = aLabel.font;
    
    // start with maxSize and keep reducing until it doesn't clip
    for(int i = 18; i >= 4; i--) {
        font = [font fontWithSize:i];
        CGSize constraintSize = CGSizeMake(aLabel.frame.size.width, MAXFLOAT);
        
        // This step checks how tall the label would be with the desired font.
        CGSize labelSize = [aLabel.text sizeWithFont:font constrainedToSize:constraintSize lineBreakMode:NSLineBreakByWordWrapping];
        if(labelSize.height <= aLabel.frame.size.height)
            break;
    }
    // Set the UILabel's font to the newly adjusted font.
    aLabel.font = font;
}

- (void)drawCoverSheet0:(NSDictionary *)plistDict {
    UIGraphicsBeginPDFPage();
    
    UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"TechAssistant" bundle: nil];

    UIView *page0 = [[mainStoryboard instantiateViewControllerWithIdentifier:@"bluestreamOutput0"] view];
    
    UILabel *ATT0 = (UILabel *)[page0 viewWithTag:105];
    [ATT0 setText:[plistDict objectForKey:@"att0"]];
    
    UILabel *ATT1 = (UILabel *)[page0 viewWithTag:102];
    [ATT1 setText:[plistDict objectForKey:@"att1"]];
    
    UILabel *ATT2 = (UILabel *)[page0 viewWithTag:103];
    [ATT2 setText:[plistDict objectForKey:@"att2"]];
    
    UILabel *ATT3 = (UILabel *)[page0 viewWithTag:106];
    [ATT3 setText:[plistDict objectForKey:@"att3"]];
    
    UILabel *ATT4 = (UILabel *)[page0 viewWithTag:107];
    [ATT4 setText:[plistDict objectForKey:@"att4"]];
    
    UILabel *ATT8 = (UILabel *)[page0 viewWithTag:109];
    [ATT8 setText:[plistDict objectForKey:@"att8"]];
    
    UILabel *ATT9 = (UILabel *)[page0 viewWithTag:110];
    [ATT9 setText:[plistDict objectForKey:@"att9"]];
    
    UILabel *ATT10 = (UILabel *)[page0 viewWithTag:101];
    [ATT10 setText:[plistDict objectForKey:@"att10"]];
    
    UILabel *ATT11 = (UILabel *)[page0 viewWithTag:108];
    [ATT11 setText:[plistDict objectForKey:@"att11"]];
    
    UILabel *ATT12 = (UILabel *)[page0 viewWithTag:113];
    [ATT12 setText:[plistDict objectForKey:@"att12"]];
    
    UILabel *ATT13 = (UILabel *)[page0 viewWithTag:111];
    [ATT13 setText:[plistDict objectForKey:@"fullName"]];
    
    UILabel *ATT14 = (UILabel *)[page0 viewWithTag:112];
    [ATT14 setText:[plistDict objectForKey:@"att14"]];
    
    UILabel *ATT16 = (UILabel *)[page0 viewWithTag:104];
    [ATT16 setText:[plistDict objectForKey:@"att16"]];
    
    UILabel *ATT24 = (UILabel *)[page0 viewWithTag:117];
    [ATT24 setText:[plistDict objectForKey:@"att24"]];
    
    UILabel *ATT25 = (UILabel *)[page0 viewWithTag:118];
    [ATT25 setText:[plistDict objectForKey:@"att25"]];
    
    UILabel *ATT21 = (UILabel *)[page0 viewWithTag:114];
    [ATT21 setText:[plistDict objectForKey:@"att21"]];
    
    UILabel *ATT22 = (UILabel *)[page0 viewWithTag:115];
    [ATT22 setText:[plistDict objectForKey:@"att22"]];
    
    UILabel *ATT23 = (UILabel *)[page0 viewWithTag:116];
    [ATT23 setText:[plistDict objectForKey:@"att23"]];
    
    UILabel *ATT20 = (UILabel *)[page0 viewWithTag:1001];
    [ATT20 setText:[plistDict objectForKey:@"att20"]];
    [BoxSynchronizer resizeFontForLabel : ATT20];
    
    if(ATT20.text==nil||ATT20.text==NULL||[ATT20.text isEqual:@""]) {
        [ATT20 setText:@"No detailed description entered on this job."];
    }
    
    //TechAssistant Version
    NSString *version = [[NSBundle mainBundle] infoDictionary][(NSString *)kCFBundleVersionKey];
    UILabel *TechAssistant = (UILabel *)[page0 viewWithTag:999];
    [TechAssistant setText:[NSString stringWithFormat:@"PAGE 1 Generated by B2Innovation's TechAssistant Version: %@", version]];
    
    [page0 setNeedsDisplay];
    [page0.layer renderInContext:UIGraphicsGetCurrentContext()];
}

- (void)drawCoverSheet1:(NSDictionary *)plistDict {
    UIGraphicsBeginPDFPage();
    
    NSString *tempUse0 = [plistDict objectForKey:@"att1"];
    NSString *tempUse1 = [plistDict objectForKey:@"att12"];
    NSString *attCustomLocation = [NSString stringWithFormat:@"%@ : %@", tempUse0, tempUse1];
    
    //date
    NSDate *dateInsert = [SelectJob loadJobStartTime];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"cccc, MMM dd, yyyy - hh:mm a z"];
    NSString *dateInsertFinal = [formatter stringFromDate:dateInsert];
    
    UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"TechAssistant" bundle: nil];
    
    UIView *page1 = [[mainStoryboard instantiateViewControllerWithIdentifier:@"attOutput1"] view];
    
    UILabel *ATTdate = (UILabel *)[page1 viewWithTag:99];
    [ATTdate setText:dateInsertFinal];
    
    UILabel *ATT100 = (UILabel *)[page1 viewWithTag:100];
    [ATT100 setText:[plistDict objectForKey:@"att0"]];
    
    UILabel *ATT101 = (UILabel *)[page1 viewWithTag:101];
    [ATT101 setText:attCustomLocation];
    
    UILabel *ATT106 = (UILabel *)[page1 viewWithTag:106];
    [ATT106 setText:[plistDict objectForKey:@"smallAddress"]];
    
    UILabel *ATT107 = (UILabel *)[page1 viewWithTag:107];
    [ATT107 setText:[plistDict objectForKey:@"smallState"]];
    
    UILabel *ATT108 = (UILabel *)[page1 viewWithTag:108];
    [ATT108 setText:[plistDict objectForKey:@"smallCity"]];
    
    UILabel *ATT109 = (UILabel *)[page1 viewWithTag:109];
    [ATT109 setText:[plistDict objectForKey:@"smallZip"]];
    
    UILabel *ATT110 = (UILabel *)[page1 viewWithTag:110];
    [ATT110 setText:[plistDict objectForKey:@"sowAttField10"]];
    
    UILabel *ATT111 = (UILabel *)[page1 viewWithTag:111];
    [ATT111 setText:[plistDict objectForKey:@"sowAttField11"]];
    
    UILabel *ATT112 = (UILabel *)[page1 viewWithTag:112];
    [ATT112 setText:[plistDict objectForKey:@"sowAttField12"]];
    
    UILabel *ATT113 = (UILabel *)[page1 viewWithTag:113];
    [ATT113 setText:[plistDict objectForKey:@"sowAttField13"]];
    
    UILabel *ATT118 = (UILabel *)[page1 viewWithTag:118];
    [ATT118 setText:[plistDict objectForKey:@"sowAttField19"]];
    
    UILabel *ATT119 = (UILabel *)[page1 viewWithTag:119];
    [ATT119 setText:[plistDict objectForKey:@"sowAttField18"]];
    
    UILabel *ATT1000 = (UILabel *)[page1 viewWithTag:1000];
    [ATT1000 setText:[plistDict objectForKey:@"sowAttField17"]];
    
    UILabel *ATT1001 = (UILabel *)[page1 viewWithTag:1001];
    [ATT1001 setText:[plistDict objectForKey:@"sowAttView1"]];
    [BoxSynchronizer resizeFontForLabel : ATT1001];
    
    UILabel *ATT200 = (UILabel *)[page1 viewWithTag:200];
    [ATT200 setText:[plistDict objectForKey:@"sowAttView2"]];
    [BoxSynchronizer resizeFontForLabel : ATT200];
    
    //TechAssistant Version
    NSString *version = [[NSBundle mainBundle] infoDictionary][(NSString *)kCFBundleVersionKey];
    UILabel *TechAssistant = (UILabel *)[page1 viewWithTag:999];
    [TechAssistant setText:[NSString stringWithFormat:@"PAGE 2 Generated by B2Innovation's TechAssistant Version: %@", version]];
    
    [page1 setNeedsDisplay];
    [page1.layer renderInContext:UIGraphicsGetCurrentContext()];
}

- (void)drawCoverSheet2:(NSDictionary *)plistDict {
    AppDelegate* delegate = (AppDelegate*)[UIApplication sharedApplication].delegate;
    
    UIGraphicsBeginPDFPage();
    
    UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"TechAssistant" bundle: nil];
    
    UIView *page2 = [[mainStoryboard instantiateViewControllerWithIdentifier:@"bomOutput0"] view];
    NSMutableString *bomString=[NSMutableString string];//NSMutableString *str = [NSMutableString string];
    NSString *toAdd, *intSearch, *leftString, *rightString;
    //Bill of Materials
    
    for (int i=0; i<delegate.bomList.count; i++) {
        //unique = [NSString stringWithFormat:@"%d",mynumber];
        intSearch = ([NSString stringWithFormat:@"%@", delegate.bomList[i] ]);
        leftString=delegate.leftBomArray[i];
        rightString=delegate.rightBomArray[i];
        NSLog(@"intSearch found %@ at index %d", intSearch, i);
        if([intSearch isEqual:@"0"]||intSearch==0) {
            NSLog(@"Nothing to add to output at index: %d", i);
        } else {
            toAdd = ([NSString stringWithFormat:@"%@ ordered of item \"%@\" with description \"%@\" at the Client .XLSX file index: %d.\n\n", intSearch, leftString, rightString, (i+14)]);
            bomString = [bomString stringByAppendingString:toAdd];
        }
    }
    
    NSLog(@"BoM String for Page 3: %@", bomString);
    UITextView *ATT201 = (UITextView *)[page2 viewWithTag:201];
    if(bomString==nil||bomString==NULL||[bomString isEqual:@""])
        bomString=@"No Bill of Materials generated for this job by the user.\n \n \n ";
    
    [ATT201 setText:bomString];
    [BoxSynchronizer resizeFontForLabel : ATT201];
    
    //TechAssistant Version
    NSString *version = [[NSBundle mainBundle] infoDictionary][(NSString *)kCFBundleVersionKey];
    UILabel *TechAssistant = (UILabel *)[page2 viewWithTag:999];
    [TechAssistant setText:[NSString stringWithFormat:@"PAGE 3 Generated by B2Innovation's TechAssistant Version: %@", version]];
    
    [page2 setNeedsDisplay];
    [page2.layer renderInContext:UIGraphicsGetCurrentContext()];
}

- (void)drawPhotoPage:(NSDictionary *)plistDict {
    NSArray* tempMemoList = [(AppDelegate *) [UIApplication sharedApplication].delegate memoList];
    int fourCount, photoAdded=0, indexOfPhotoMemo=0, perPage=4, jpegFound;
    NSString *memoToSearch, *drawingsPath = [WDDrawingManager drawingPath], *photoName, *path, *photoString=@"Photo";
    NSString *photoFolderPath = [drawingsPath stringByAppendingPathComponent:@"PhotoCache"];
    NSArray *jpegFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:photoFolderPath error:nil];
    UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"TechAssistant" bundle: nil];
    UIView *photoPages = [[mainStoryboard instantiateViewControllerWithIdentifier:@"ATTPhotoOutput0"] view];
    UIImage* image, *blankImage = [UIImage imageNamed:@"BlankPNG"];
    UIImageView *imageView0=(UIImageView *)[photoPages viewWithTag:110], *imageView1=(UIImageView *)[photoPages viewWithTag:111], *imageView2=(UIImageView *)[photoPages viewWithTag:112], *imageView3=(UIImageView *)[photoPages viewWithTag:113];
    UILabel *attachmentLeft = (UILabel *)[photoPages viewWithTag:101], *attachmentRight = (UILabel *)[photoPages viewWithTag:102], *pageTotal = (UILabel *)[photoPages viewWithTag:108], *currentPage = (UILabel *)[photoPages viewWithTag:107], *memoUL = (UILabel *)[photoPages viewWithTag:103], *memoUR = (UILabel *)[photoPages viewWithTag:104], *memoLL = (UILabel *)[photoPages viewWithTag:105], *memoLR = (UILabel *)[photoPages viewWithTag:106], *dateLabel = (UILabel *)[photoPages viewWithTag:444], *nameLabel = (UILabel *)[photoPages viewWithTag:555];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateStyle:NSDateFormatterMediumStyle];
    [formatter setDateFormat:@"MMM dd, yyyy"];
    NSLog(@"\nDisplay date: %@\n", [formatter stringFromDate:[NSDate date]]);
    BOOL foundMemo;
    
    //search for "Photos"
    NSArray *allNames=[[WDDrawingManager sharedInstance] drawingNames];
    NSString *stringToSearch, *picLocation = @"upperLeft", *outputString, *finalPrintString;
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF contains %@", photoString];
    _allPhotos = [NSMutableArray arrayWithArray:[allNames filteredArrayUsingPredicate:predicate]];
    int totalPhoto = (int)[_allPhotos count];
    int totalPages = (totalPhoto+perPage-1)/perPage;
    int memoSize=(int)tempMemoList.count;
    NSLog(@"%@\n---------------------------------\nTotal Photo Pages: %d\n", tempMemoList, totalPages);
    [pageTotal setText:[NSString stringWithFormat:@"%d", totalPages+3]];
    
    for (int pagesAdded = 0; pagesAdded < totalPages; pagesAdded++) {
        fourCount=0;
        
        //init clean page values
        UIGraphicsBeginPDFPage();
        imageView0.image = blankImage;
        imageView1.image = blankImage;
        imageView2.image = blankImage;
        imageView3.image = blankImage;
        
        attachmentLeft.text=@" ";
        attachmentRight.text=@" ";
        memoLL.text=@"No Photo Memo Entered";
        memoLR.text=@"No Photo Memo Entered";
        memoUL.text=@"No Photo Memo Entered";
        memoUR.text=@"No Photo Memo Entered";
        
        //insert data
        [dateLabel setText:[formatter stringFromDate:[NSDate date]]];
        [nameLabel setText:[plistDict objectForKey:@"fullName"]];
        
        while (photoAdded < totalPhoto) {
            outputString=@"";
            finalPrintString=@"";
            indexOfPhotoMemo = -1;
            photoName = [_allPhotos[photoAdded] stringByDeletingPathExtension];
            stringToSearch = [NSString stringWithFormat: @"%@.jpeg", photoName];
            memoToSearch = _allPhotos[photoAdded];
            path = [photoFolderPath stringByAppendingPathComponent: stringToSearch ];
            image = [UIImage imageWithContentsOfFile:path];
            //location in JPEG array
            jpegFound = (int)[jpegFiles indexOfObject:stringToSearch];
            NSLog(@"%@ at index %d has been printed to page %d in the %@.", memoToSearch, jpegFound, pagesAdded, picLocation);
            
            //insert into PDF
            //memo insertion
            foundMemo=NO;
            for(int i=0; i<memoSize; i++) {
                if([tempMemoList[i] containsString: memoToSearch]) {
                    foundMemo=YES;
                    indexOfPhotoMemo = i;
                    NSLog(@"%@ was found in the memo list at index %d.", memoToSearch, indexOfPhotoMemo);
                    outputString = [NSString stringWithFormat:@"%@", tempMemoList[indexOfPhotoMemo]];
                }
            }
            if (foundMemo==NO) {
                finalPrintString = [NSString stringWithFormat:@"No Memo Entered For: %@", memoToSearch];
            }
            else {
                //remove TechAssistant leading characters
                NSRange range = [outputString rangeOfString:@": "];
                finalPrintString = [outputString substringFromIndex:range.location];
            }
            
            if([attachmentLeft.text isEqual:@" "]) {
                [attachmentLeft setText:[NSString stringWithFormat:@"%d", photoAdded+1]];
            }
            //photo insertion
            if ([picLocation isEqualToString:@"upperLeft"]) {
                [imageView0 setImage:image];
                [imageView0 setContentMode:UIViewContentModeScaleAspectFit];
                if(indexOfPhotoMemo>-1) {
                    [memoUL setText:finalPrintString];
                    memoUL.numberOfLines = 2;
                    [BoxSynchronizer resizeFontForLabel : memoUL];
                }
                picLocation=@"upperRight";
            }
            else if ([picLocation isEqualToString:@"upperRight"]) {
                [imageView1 setImage:image];
                [imageView1 setContentMode:UIViewContentModeScaleAspectFit];
                if(indexOfPhotoMemo>0) {
                    [memoUR setText:finalPrintString];
                    memoUR.numberOfLines = 2;
                    [BoxSynchronizer resizeFontForLabel : memoUR];
                }
                picLocation=@"lowerLeft";
            }
            else if ([picLocation isEqualToString:@"lowerLeft"]) {
                [imageView2 setImage:image];
                [imageView2 setContentMode:UIViewContentModeScaleAspectFit];
                if(indexOfPhotoMemo>0) {
                    [memoLL setText:finalPrintString];
                    memoLL.numberOfLines = 2;
                    [BoxSynchronizer resizeFontForLabel : memoLL];
                }
                picLocation=@"lowerRight";
            }
            else if ([picLocation isEqualToString:@"lowerRight"]) {
                [imageView3 setImage:image];
                [imageView3 setContentMode:UIViewContentModeScaleAspectFit];
                if(indexOfPhotoMemo>0) {
                    [memoLR setText:finalPrintString];
                    memoLR.numberOfLines = 2;
                    [BoxSynchronizer resizeFontForLabel : memoLR];
                }
                picLocation=@"upperLeft";
            }
            
            photoAdded++;
            [attachmentRight setText:[NSString stringWithFormat:@"%d", photoAdded]];
            //create new page if 4 have printed
            fourCount++;
            if(fourCount==4) {
                break;
            }
        }
        //output
        
        [currentPage setText:[NSString stringWithFormat:@"%d", pagesAdded+4]];
        
        //TechAssistant Version
        NSString *version = [[NSBundle mainBundle] infoDictionary][(NSString *)kCFBundleVersionKey];
        UILabel *TechAssistant = (UILabel *)[photoPages viewWithTag:999];
        [TechAssistant setText:[NSString stringWithFormat:@"Generated in Partnership with B2Innovation's TechAssistant Version: %@", version]];
        
        [photoPages setNeedsDisplay];
        [photoPages.layer renderInContext:UIGraphicsGetCurrentContext()];
    }
}

- (NSString *) convertXML : (NSString * ) myString {
    NSString * issue0 = @"</Data><NamedCell";
    NSString * issue1 = @"<Cell><Data ss:Type=\"String\">";
    NSString * issue2 = @"ss:Name=\"_FilterDatabase\"/></Cell>\n";
    NSString * issue3 = @"<Cell ss:StyleID=\"s65\"><Data ss:Type=\"DateTime\">";
    NSString * issue4 = @"<Cell ss:StyleID=\"s63\"><Data ss:Type=\"String\">";
    NSMutableString * temp = [myString mutableCopy];
    
    [temp replaceOccurrencesOfString:@"&amp;"
                          withString:@"&"
                             options:0
                               range:NSMakeRange(0, [temp length])];
    [temp replaceOccurrencesOfString:@"&lt;"
                          withString:@"<"
                             options:0
                               range:NSMakeRange(0, [temp length])];
    [temp replaceOccurrencesOfString:@"&gt;"
                          withString:@">"
                             options:0
                               range:NSMakeRange(0, [temp length])];
    [temp replaceOccurrencesOfString:@"&quot;"
                          withString:@"\""
                             options:0
                               range:NSMakeRange(0, [temp length])];
    [temp replaceOccurrencesOfString:@"&apos;"
                          withString:@"'"
                             options:0
                               range:NSMakeRange(0, [temp length])];
    [temp replaceOccurrencesOfString:issue0
                          withString:@""
                             options:0
                               range:NSMakeRange(0, [temp length])];
    [temp replaceOccurrencesOfString:issue1
                          withString:@""
                             options:0
                               range:NSMakeRange(0, [temp length])];
    [temp replaceOccurrencesOfString:issue2
                          withString:@""
                             options:0
                               range:NSMakeRange(0, [temp length])];
    [temp replaceOccurrencesOfString:issue3
                          withString:@""
                             options:0
                               range:NSMakeRange(0, [temp length])];
    [temp replaceOccurrencesOfString:issue4
                          withString:@""
                             options:0
                               range:NSMakeRange(0, [temp length])];
    [temp replaceOccurrencesOfString:@"     "
                          withString:@""
                             options:0
                               range:NSMakeRange(0, [temp length])];
    [temp replaceOccurrencesOfString:@"    "
                          withString:@""
                             options:0
                               range:NSMakeRange(0, [temp length])];
    [temp replaceOccurrencesOfString:@"<Row>"
                          withString:@""
                             options:0
                               range:NSMakeRange(0, [temp length])];
    [temp replaceOccurrencesOfString:@"</Row>"
                          withString:@""
                             options:0
                               range:NSMakeRange(0, [temp length])];
    [temp replaceOccurrencesOfString:@"\n\n"
                          withString:@"\n"
                             options:0
                               range:NSMakeRange(0, [temp length])];
    
    return temp;
}

- (void)parseUsersList: (NSNotification *)notification {
    NSString *usersPath = [self.documentsDirectory stringByAppendingPathComponent:[AppDelegate boxInputJobsFile]];
    self.searchLetter=@"A";
    BOOL usefulData=true;
    int searchNumber=1;
    AppDelegate* delegate = (AppDelegate *) [UIApplication sharedApplication].delegate;
    NSString *searchCell;
    BRAOfficeDocumentPackage *spreadsheet = [BRAOfficeDocumentPackage open : usersPath];
    BRAWorksheet *mainSheet = spreadsheet.workbook.worksheets[1];
    delegate.fieldEngineerDictionary = [NSMutableDictionary dictionary];
    
    if (![self isFileNotEmpty:usersPath])
        return;
    
    while (usefulData) {
        searchNumber++;
        FieldEngineer* fieldEngineer = [[FieldEngineer alloc] init];
        fieldEngineer.assignedJobs = [[NSMutableArray alloc] init];
    
        searchCell = [NSString stringWithFormat:@"%@%d", self.searchLetter, searchNumber];
        fieldEngineer.appUserName = [[mainSheet cellForCellReference:searchCell]stringValue];
        if(fieldEngineer.appUserName == nil)
            usefulData=false;
        
        [self incrementAscii];
        searchCell = [NSString stringWithFormat:@"%@%d", self.searchLetter, searchNumber];
        fieldEngineer.password = [[mainSheet cellForCellReference:searchCell]stringValue];
        
        [self incrementAscii];
        searchCell = [NSString stringWithFormat:@"%@%d", self.searchLetter, searchNumber];
        fieldEngineer.phoneNumber = [[mainSheet cellForCellReference:searchCell]stringValue];
        
        [self incrementAscii];
        searchCell = [NSString stringWithFormat:@"%@%d", self.searchLetter, searchNumber];
        fieldEngineer.email = [[mainSheet cellForCellReference:searchCell]stringValue];
        
        [self incrementAscii];
        searchCell = [NSString stringWithFormat:@"%@%d", self.searchLetter, searchNumber];
        fieldEngineer.fullName = [[mainSheet cellForCellReference:searchCell]stringValue];
        
        self.searchLetter=@"A";
        
        if(usefulData)
            [delegate.fieldEngineerDictionary setObject:fieldEngineer forKey:fieldEngineer.appUserName];
    }
    NSLog(@"Parsing of full user list COMPLETE.");
    //NSLog(@"FIELD ENGINEER DICTIONARY:\n%@", delegate.fieldEngineerDictionary);
}

- (void)parseUserJobList: (NSNotification *)notification {
    NSString *inputFile = [AppDelegate boxInputJobsFile];
    NSString *jobsPath = [self.documentsDirectory stringByAppendingPathComponent: inputFile];
    BOOL usefulData=true;
    int searchNumber=1;
    AppDelegate* delegate = (AppDelegate *) [UIApplication sharedApplication].delegate;
    NSString *addressCell, *singleJobToEnter, *singleAddressToEnter, *engineerCell, *jobCell, *enterEngineer;
    BRAOfficeDocumentPackage *spreadSheet = [BRAOfficeDocumentPackage open : jobsPath];
    BRAWorksheet *jobsWorkSheet = spreadSheet.workbook.worksheets[0];
    delegate.userJobsDictionary = [NSMutableDictionary dictionary];
    delegate.userAddressesDictionary = [NSMutableDictionary dictionary];
    NSMutableDictionary* dicJobs;
    NSMutableArray* jobs;
    NSMutableDictionary* dicAddresses;
    NSMutableArray* addresses;
    
    if (![self isFileNotEmpty:jobsPath])
        return;
    
    while (usefulData) {
        searchNumber++;
        FieldEngineer *fieldEngineer = [[FieldEngineer alloc] init];
        fieldEngineer.assignedJobs = [[NSMutableArray alloc] init];
        fieldEngineer.assignedAddresses = [[NSMutableArray alloc] init];
        
        enterEngineer = [NSString stringWithFormat:@"P%d", searchNumber];
        engineerCell = [[jobsWorkSheet cellForCellReference:enterEngineer]stringValue];
        if (engineerCell==nil)
            engineerCell = @"";
        FieldEngineer* engineer = [delegate.fieldEngineerDictionary objectForKey:engineerCell];
        if (engineer == nil)
            engineer = [delegate.fieldEngineerDictionary objectForKey:@"admin"];
        
        singleJobToEnter = [NSString stringWithFormat:@"E%d", searchNumber];
        jobCell = [[jobsWorkSheet cellForCellReference:singleJobToEnter]stringValue];
        if(jobCell==nil) {
            usefulData=false;
        } else {
            jobCell = [jobCell stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        }
        
        dicJobs = delegate.userJobsDictionary;
        jobs = [dicJobs objectForKey:engineerCell];
        if(jobs == nil && usefulData) {
            jobs = [NSMutableArray array];
            [jobs addObject:jobCell];
            if(jobs!=nil)
                [dicJobs setObject:jobs forKey:engineerCell];
            else
                usefulData=FALSE;
        }
        else if (usefulData){
            [jobs addObject:jobCell];
            [dicJobs setObject:jobs forKey:engineerCell];
        }
        if(usefulData)
            [engineer.assignedJobs addObject:jobCell];
        
        singleAddressToEnter = [NSString stringWithFormat:@"K%d", searchNumber];
        addressCell = [[jobsWorkSheet cellForCellReference:singleAddressToEnter]stringValue];
        if(addressCell==NULL ||addressCell==nil)
            addressCell=@"NO ADDRESS ENTERED";
        dicAddresses = delegate.userAddressesDictionary;
        addresses = [dicAddresses objectForKey:engineerCell];
        if(addresses == nil && usefulData) {
            addresses = [NSMutableArray array];
            [addresses addObject:addressCell];
            [dicAddresses setObject:addresses forKey:jobCell];
        }
        else if (usefulData){
            [addresses addObject:addressCell];
            [dicAddresses setObject:addresses forKey:jobCell];
        }
        if(usefulData)
            [engineer.assignedAddresses addObject:addressCell];
    }
    NSLog(@"Parsing of full jobs list COMPLETE.");
    //NSLog(@"FULL JOBS LIST:\n%@", delegate.userJobsDictionary);
    //NSLog(@"FULL ADDRESSES LIST:\n%@", delegate.userAddressesDictionary);
    [[NSNotificationCenter defaultCenter] postNotificationName:@"com.cusoft.logInReady" object:nil];
}

- (void)incrementAscii {
    if ([self.searchLetter isEqual: @"A"])
        self.searchLetter=@"B";
    else if ([self.searchLetter isEqual: @"B"])
        self.searchLetter=@"C";
    else if ([self.searchLetter isEqual: @"C"])
        self.searchLetter=@"D";
    else if ([self.searchLetter isEqual: @"D"])
        self.searchLetter=@"E";
    else if ([self.searchLetter isEqual: @"E"])
        self.searchLetter=@"F";
    else if ([self.searchLetter isEqual: @"F"])
        self.searchLetter=@"G";
    else if ([self.searchLetter isEqual: @"G"])
        self.searchLetter=@"H";
    else if ([self.searchLetter isEqual: @"H"])
        self.searchLetter=@"I";
    else if ([self.searchLetter isEqual: @"I"])
        self.searchLetter=@"J";
    else if ([self.searchLetter isEqual: @"J"])
        self.searchLetter=@"K";
    else if ([self.searchLetter isEqual: @"K"])
        self.searchLetter=@"L";
    else if ([self.searchLetter isEqual: @"L"])
        self.searchLetter=@"M";
    else if ([self.searchLetter isEqual: @"M"])
        self.searchLetter=@"N";
    else if ([self.searchLetter isEqual: @"N"])
        self.searchLetter=@"O";
    else if ([self.searchLetter isEqual: @"O"])
        self.searchLetter=@"P";
    else if ([self.searchLetter isEqual: @"P"])
        self.searchLetter=@"Q";
    else if ([self.searchLetter isEqual: @"Q"])
        self.searchLetter=@"R";
    else if ([self.searchLetter isEqual: @"R"])
        self.searchLetter=@"S";
    else if ([self.searchLetter isEqual: @"S"])
        self.searchLetter=@"T";
    else if ([self.searchLetter isEqual: @"T"])
        self.searchLetter=@"U";
    else if ([self.searchLetter isEqual: @"U"])
        self.searchLetter=@"V";
    else if ([self.searchLetter isEqual: @"V"])
        self.searchLetter=@"W";
    else if ([self.searchLetter isEqual: @"W"])
        self.searchLetter=@"X";
    else if ([self.searchLetter isEqual: @"X"])
        self.searchLetter=@"Y";
    else if ([self.searchLetter isEqual: @"Y"])
        self.searchLetter=@"Z";
    else if ([self.searchLetter isEqual: @"Z"])
        self.searchLetter=@"A";
    else
        self.searchLetter=@"ERROR";
}

- (NSString *)incrementAscii:(NSString *)toConvert {
    //created originally with ascii to string binary conversion, but hard coding seems more reliable
    //http://www.binaryhexconverter.com/binary-to-ascii-text-converter
    NSString * convertedDone;
    
    if ([toConvert isEqual: @"A"]) {
        convertedDone=@"B";
    }
    else if ([toConvert isEqual: @"B"]) {
        convertedDone=@"C";
    }
    else if ([toConvert isEqual: @"C"]) {
        convertedDone=@"D";
    }
    else if ([toConvert isEqual: @"D"]) {
        convertedDone=@"E";
    }
    else if ([toConvert isEqual: @"E"]) {
        convertedDone=@"F";
    }
    else if ([toConvert isEqual: @"F"]) {
        convertedDone=@"G";
    }
    else if ([toConvert isEqual: @"G"]) {
        convertedDone=@"H";
    }
    else if ([toConvert isEqual: @"H"]) {
        convertedDone=@"I";
    }
    else if ([toConvert isEqual: @"I"]) {
        convertedDone=@"J";
    }
    else if ([toConvert isEqual: @"J"]) {
        convertedDone=@"K";
    }
    else if ([toConvert isEqual: @"K"]) {
        convertedDone=@"L";
    }
    else if ([toConvert isEqual: @"L"]) {
        convertedDone=@"M";
    }
    else if ([toConvert isEqual: @"M"]) {
        convertedDone=@"N";
    }
    else if ([toConvert isEqual: @"N"]) {
        convertedDone=@"O";
    }
    else if ([toConvert isEqual: @"O"]) {
        convertedDone=@"P";
    }
    else if ([toConvert isEqual: @"P"]) {
        convertedDone=@"Q";
    }
    else if ([toConvert isEqual: @"Q"]) {
        convertedDone=@"R";
    }
    else if ([toConvert isEqual: @"R"]) {
        convertedDone=@"S";
    }
    else if ([toConvert isEqual: @"S"]) {
        convertedDone=@"T";
    }
    else if ([toConvert isEqual: @"T"]) {
        convertedDone=@"U";
    }
    else if ([toConvert isEqual: @"U"]) {
        convertedDone=@"V";
    }
    else if ([toConvert isEqual: @"V"]) {
        convertedDone=@"W";
    }
    else if ([toConvert isEqual: @"W"]) {
        convertedDone=@"X";
    }
    else if ([toConvert isEqual: @"X"]) {
        convertedDone=@"Y";
    }
    else if ([toConvert isEqual: @"Y"]) {
        convertedDone=@"Z";
    }
    else {
        convertedDone=@"ERROR";
    }
    return convertedDone;
}

-(void)stopTheTimer {
    dispatch_async(dispatch_get_main_queue(), ^{
        ((AppDelegate *) [UIApplication sharedApplication].delegate).jobTimer = nil;
    });
}

- (void) bundleEverything:(NSNotification *)notification {
    static dispatch_queue_t __serialQueue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __serialQueue = dispatch_queue_create("com.cusoft.bundleUpTheJobSerialQueue", DISPATCH_QUEUE_SERIAL);
    });

    //stop the timer
    dispatch_async(__serialQueue, ^{
        NSLog(@"bundleEverything: BEGIN");
        [self stopTheTimer];
    });
    
    //folders
    dispatch_async(__serialQueue, ^{
        //create the upload folder if it does not exist and wipe out ALL pre-existing files
        NSFileManager *fm = [NSFileManager defaultManager];
        BOOL isDirectory = NO;
        if (![fm fileExistsAtPath:self.tempPath isDirectory:&isDirectory] || !isDirectory) {
            NSLog(@"Creating a local temp folder.");
            [fm createDirectoryAtPath:self.tempPath withIntermediateDirectories:YES attributes:nil error:NULL];
        } else {
            NSLog(@"Deleting local temp folder and starting new.");
            [fm removeItemAtPath:self.tempPath error:NULL];
            [fm createDirectoryAtPath:self.tempPath withIntermediateDirectories:YES attributes:nil error:NULL];
        }
        
        isDirectory = NO;
        if (![fm fileExistsAtPath:self.uploadPath isDirectory:&isDirectory] || !isDirectory) {
            NSLog(@"Creating an upload folder.");
            [fm createDirectoryAtPath:self.uploadPath withIntermediateDirectories:YES attributes:nil error:NULL];
        } else {
            NSLog(@"Deleting upload folder and starting new.");
            [fm removeItemAtPath:self.uploadPath error:NULL];
            [fm createDirectoryAtPath:self.uploadPath withIntermediateDirectories:YES attributes:nil error:NULL];
        }
        
        isDirectory = NO;
        if (![fm fileExistsAtPath:self.completedPath isDirectory:&isDirectory] || !isDirectory) {
            NSLog(@"Creating a completed folder.");
            [fm createDirectoryAtPath:self.completedPath withIntermediateDirectories:YES attributes:nil error:NULL];
        } else {
            NSLog(@"Deleting completed folder and starting new.");
            [fm removeItemAtPath:self.completedPath error:NULL];
            [fm createDirectoryAtPath:self.completedPath withIntermediateDirectories:YES attributes:nil error:NULL];
        }
    });
    
    //xlsx file
    dispatch_async(__serialQueue, ^{
        NSString *outputFile = [AppDelegate boxOutputTemplateFile];
        NSString *originalFile = [self.documentsDirectory stringByAppendingPathComponent:outputFile];
        NSFileManager *fm = [NSFileManager defaultManager];
        [fm copyItemAtPath:originalFile toPath: self.packagePath error:NULL];
    });
    
    //gallery drawings for upload
    dispatch_async(__serialQueue, ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [[WDDrawingManager sharedInstance] exportAllDrawingsToPDF: self.uploadPath];
        });
    });
    
    //gallery photos for upload
    dispatch_async(__serialQueue, ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [[WDDrawingManager sharedInstance] exportAllPhotosToJPEG: self.uploadPath];
        });
    });
    
    //photo module pics for upload
    dispatch_async(__serialQueue, ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [InfinitePhotosController sendPhotoFilesToUpload];
        });
    });
    
    //poles for upload
    dispatch_async(__serialQueue, ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [PolePage sendPhotoFilesToUpload];
        });
    });
    
    //activate user
    dispatch_async(__serialQueue, ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"com.cusoft.allowUser" object:nil];
        });
    });
    
    //learn how long to process uploads
    dispatch_async(__serialQueue, ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self countUploads];
        });
    });
}

-(void) countUploads {
    NSString *drawingsPath = [WDDrawingManager drawingPath];
    NSString *filesFolderPath = [drawingsPath stringByAppendingPathComponent:@"Upload"];
    NSArray *allFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:filesFolderPath error:nil];
        
    self.totalNeededUploads = [NSString stringWithFormat:@"%d", allFiles.count];
    self.totalCompletedUploads = @"0";
}

-(void) userTappedUpload:(NSNotification *)notification {
    //beginning upload process
    [self newCloudFolder];
}

- (void) threadRipXlsx: (NSNotification *)notification {
    static dispatch_queue_t __serialQueue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __serialQueue = dispatch_queue_create("com.cusoft.saveXlsxSerialQueue", DISPATCH_QUEUE_SERIAL);
    });

    dispatch_async(__serialQueue, ^{
        NSLog(@"XLSX SAVE");
        [[NSNotificationCenter defaultCenter] postNotificationName:@"com.cusoft.updateLabelNotification" object:@"-BUNDLING POLE DATA-"];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self writeXlsxPoles];
        });
    });
    
    dispatch_async(__serialQueue, ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"com.cusoft.updateLabelNotification" object:@"-BUNDLING SURVEY DATA-"];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self writeXlsxData];
        });
    });
    
    dispatch_async(__serialQueue, ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"com.cusoft.updateLabelNotification" object:@"-BUNDLING PHOTO DATA-"];
        dispatch_async(dispatch_get_main_queue(), ^{
            //[self writeXlsxPhotos];
        });
    });
    
    dispatch_async(__serialQueue, ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"com.cusoft.updateLabelNotification" object:@"-BUNDLING GALLERY DATA-"];
        dispatch_async(dispatch_get_main_queue(), ^{
            //[self writeXlsxDrawings];
        });
    });
    
    dispatch_async(__serialQueue, ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"com.cusoft.updateLabelNotification" object:@"-BUNDLING BoM DATA-"];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self writeXlsxBom];
        });
    });
    
    dispatch_async(__serialQueue, ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"com.cusoft.updateLabelNotification" object:@"-FINAL SPREADSHEET CHECK-"];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"com.cusoft.finalCheckAlert" object:nil];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self finalSave];
        });
    });
}

- (void) testXlsxPackage {
    BRAOfficeDocumentPackage *xlsxPackage = [BRAOfficeDocumentPackage open: self.packagePath];
    
    BRAWorksheet *testSheet;
     for(int i=0; i<10; i++) {
        testSheet = xlsxPackage.workbook.worksheets[i];
        
        NSLog(@"Page found at %d, testing save function for sheet now.", i);
        [testSheet save];
    }
}

- (void) writeXlsxMduMf {
    NSMutableDictionary *plistDict = [self getDictionaryOnMainThread];
    BRAOfficeDocumentPackage *xlsxPackage = [BRAOfficeDocumentPackage open: self.packagePath];
    BRAWorksheet *dataSheet = xlsxPackage.workbook.worksheets[2];
    
    //MDU DATA
    NSString *mdu0 = [plistDict objectForKey:@"field18"];
    if(![mdu0 isEqual:nil])
        [[dataSheet cellForCellReference: @"C19" shouldCreate: YES] setStringValue: mdu0];
    
    NSString *mdu1 = [plistDict objectForKey:@"field19"];
    if(![mdu1 isEqual:nil])
        [[dataSheet cellForCellReference: @"C20" shouldCreate: YES] setStringValue: mdu1];
    
    NSString *mdu2 = [plistDict objectForKey:@"field20"];
    if(![mdu2 isEqual:nil])
        [[dataSheet cellForCellReference: @"C21" shouldCreate: YES] setStringValue: mdu2];
    
    NSString *mdu3 = [plistDict objectForKey:@"button40"];
    NSLog(@"mdu3 and button 40: %@", mdu3);
    if(![mdu3 isEqual:nil])
        [[dataSheet cellForCellReference: @"C22" shouldCreate: YES] setStringValue: mdu3];
    
    NSString *mdu4 = [plistDict objectForKey:@"field21"];
    if(![mdu4 isEqual:nil])
        [[dataSheet cellForCellReference: @"C23" shouldCreate: YES] setStringValue: mdu4];
    
    NSString *mdu5 = [plistDict objectForKey:@"field22"];
    if(![mdu5 isEqual:nil])
        [[dataSheet cellForCellReference: @"C24" shouldCreate: YES] setStringValue: mdu5];
    
    //MF & MIXED DATA
    NSString *mf0 = [plistDict objectForKey:@"button0"];
    if(![mf0 isEqual:nil])
        [[dataSheet cellForCellReference: @"C3" shouldCreate: YES] setStringValue: mf0];
    
    NSString *mf1 = [plistDict objectForKey:@"button1"];
    if(![mf1 isEqual:nil])
        [[dataSheet cellForCellReference: @"C4" shouldCreate: YES] setStringValue: mf1];
    
    NSString *mf2 = [plistDict objectForKey:@"button2"];
    if(![mf2 isEqual:nil])
        [[dataSheet cellForCellReference: @"C5" shouldCreate: YES] setStringValue: mf2];
    
    NSString *mf3 = [plistDict objectForKey:@"field0"];
    if([mf3 isEqual:@""])
        mf3 = [plistDict objectForKey:@"button3"];
    if(![mf3 isEqual:nil])
        [[dataSheet cellForCellReference: @"C6" shouldCreate: YES] setStringValue: mf3];
    
    NSString *mf4 = [plistDict objectForKey:@"field1"];
    if([mf4 isEqual:@""])
        mf4 = [plistDict objectForKey:@"button4"];
    if(![mf4 isEqual:nil])
        [[dataSheet cellForCellReference: @"C7" shouldCreate: YES] setStringValue: mf4];
    
    NSString *mf5 = [plistDict objectForKey:@"button38"];
    if(![mf5 isEqual:nil])
        [[dataSheet cellForCellReference: @"C8" shouldCreate: YES] setStringValue: mf5];
    
    NSString *mf6 = [plistDict objectForKey:@"field23"];
    if([mf6 isEqual:@""])
        mf6 = [plistDict objectForKey:@"button39"];
    if(![mf6 isEqual:nil])
        [[dataSheet cellForCellReference: @"C9" shouldCreate: YES] setStringValue: mf6];
    
    NSString *mf7 = [plistDict objectForKey:@"field24"];
    if(![mf7 isEqual:nil])
        [[dataSheet cellForCellReference: @"C10" shouldCreate: YES] setStringValue: mf7];
    
    NSString *mf8 = [plistDict objectForKey:@"field25"];
    if(![mf8 isEqual:nil])
        [[dataSheet cellForCellReference: @"C11" shouldCreate: YES] setStringValue: mf8];
    
    NSString *mf9 = [plistDict objectForKey:@"field26"];
    if(![mf9 isEqual:nil])
        [[dataSheet cellForCellReference: @"C12" shouldCreate: YES] setStringValue: mf9];
    
    NSString *mf10 = [plistDict objectForKey:@"field27"];
    if(![mf10 isEqual:nil])
        [[dataSheet cellForCellReference: @"C13" shouldCreate: YES] setStringValue: mf10];
   
    NSString *mf11 = [plistDict objectForKey:@"button35"];
    if(![mf11 isEqual:nil])
        [[dataSheet cellForCellReference: @"C14" shouldCreate: YES] setStringValue: mf11];
    
    NSString *mf12 = [plistDict objectForKey:@"button36"];
    if(![mf12 isEqual:nil])
        [[dataSheet cellForCellReference: @"C15" shouldCreate: YES] setStringValue: mf12];
    
    NSString *mf13 = [plistDict objectForKey:@"button37"];
    if(![mf13 isEqual:nil])
        [[dataSheet cellForCellReference: @"C16" shouldCreate: YES] setStringValue: mf13];
    
    [xlsxPackage save];
}

- (NSMutableDictionary *) getSelectedPoleDictionary :(int) poleNumber{
    NSString *selectedPole, *jobNum = [(AppDelegate *) [UIApplication sharedApplication].delegate selectedJob];
    
    if(poleNumber<10) {
        selectedPole = [NSString stringWithFormat: @"%@ pole 00%d", jobNum, poleNumber];
    } else if(poleNumber<100) {
        selectedPole = [NSString stringWithFormat: @"%@ pole 0%d", jobNum, poleNumber];
    } else {
        selectedPole = [NSString stringWithFormat:@"%@ pole %d", jobNum, poleNumber];
    }
        
    NSMutableDictionary *allPoleData = [(AppDelegate *) [UIApplication sharedApplication].delegate poleDataDictionary];
    NSMutableDictionary *returnDictionary = [allPoleData objectForKey:selectedPole];
    
    return returnDictionary;
}

- (void) writeXlsxPoles {
    NSMutableDictionary *plistDict = [self getDictionaryOnMainThread];
    NSMutableDictionary *allPoleData = [self getPoleDictionaryOnMainThread];
    NSMutableDictionary *currentPoleDict = [[NSMutableDictionary alloc] init];
    NSString *testFilled, *poleInsert, *cellPath;
    BRAOfficeDocumentPackage *xlsxPackage = [BRAOfficeDocumentPackage open: self.packagePath];
    BRAWorksheet *dataSheet = xlsxPackage.workbook.worksheets[6];
    int found = 0, totalPoles = [[plistDict objectForKey:@"totalForPolePage"] intValue];
    NSLog(@"POLES: %@. Entering output loop for %d poles.", allPoleData, totalPoles);
    
    for (int polesAdded = 0; polesAdded < totalPoles; polesAdded++) {
        currentPoleDict = [self getSelectedPoleDictionary:polesAdded];
        testFilled = [currentPoleDict objectForKey:@"activePole"];
        
        if([testFilled isEqualToString:@"TRUE"]) {
            NSLog(@"Inserting pole %d.", polesAdded);
            int cellLocation = (found*28);
            cellLocation++;
            found++;
            NSString *insertLocation, *insertString1=@"", *insertString0=@"", *poleNumber = [NSString stringWithFormat:@"-POLE %d-", polesAdded];
            
            //A1
            NSString *field19 = [currentPoleDict objectForKey:@"poleField19"];
            if(field19!=nil&&![field19 isEqualToString:@""]) {
                field19 = [NSString stringWithFormat:@"From Previous Pole: %@             ", field19];
                insertString0 = [insertString0 stringByAppendingString:field19];
            }
            NSString *field20 = [currentPoleDict objectForKey:@"poleField20"];
            if(field20!=nil&&![field20 isEqualToString:@""]) {
                field20 = [NSString stringWithFormat:@"To Next Pole: %@             ", field20];
                insertString0 = [insertString0 stringByAppendingString:field20];
            }
            NSString *field21 = [currentPoleDict objectForKey:@"poleField21"];
            if(field21!=nil&&![field21 isEqualToString:@""]) {
                field21 = [NSString stringWithFormat:@"Owner: %@             ", field21];
                insertString0 = [insertString0 stringByAppendingString:field21];
            }
            NSString *field22 = [currentPoleDict objectForKey:@"poleField22"];
            if(field22!=nil&&![field22 isEqualToString:@""]) {
                field22 = [NSString stringWithFormat:@"PM Tool #: %@", field22];
                insertString0 = [insertString0 stringByAppendingString:field22];
            }
            if([insertString0 isEqualToString:@""])
                insertString0 = @"No previous, next pole, owner or pm tool data entered by user.";
            
            //A2
            NSString *field23 = [currentPoleDict objectForKey:@"poleField23"];
            if(field23!=nil&&![field23 isEqualToString:@""]) {
                field23 = [NSString stringWithFormat:@"Name: %@             ", field23];
                insertString1 = [insertString1 stringByAppendingString:field23];
            }
            NSString *field24 = [currentPoleDict objectForKey:@"poleField24"];
            if(field24!=nil&&![field24 isEqualToString:@""]) {
                field24 = [NSString stringWithFormat:@"Class: %@             ", field24];
                insertString1 = [insertString1 stringByAppendingString:field24];
            }
            NSString *field25 = [currentPoleDict objectForKey:@"poleField25"];
            if(field25!=nil&&![field25 isEqualToString:@""]) {
                field25 = [NSString stringWithFormat:@"Length: %@             ", field25];
                insertString1 = [insertString1 stringByAppendingString:field25];
            }
            NSString *field26 = [currentPoleDict objectForKey:@"poleField26"];
            if(field26!=nil&&![field26 isEqualToString:@""]) {
                field26 = [NSString stringWithFormat:@"Species: %@             ", field26];
                insertString1 = [insertString1 stringByAppendingString:field26];
            }
            NSString *field27 = [currentPoleDict objectForKey:@"poleField27"];
            if(field27!=nil&&![field27 isEqualToString:@""]) {
                field27 = [NSString stringWithFormat:@"Address Tag: %@", field27];
                insertString1 = [insertString1 stringByAppendingString:field27];
            }
            if([insertString1 isEqualToString:@""])
                insertString1 = @"No name, class, length, species or address data entered by user.";
            
            cellPath = [NSString stringWithFormat:@"A%d", cellLocation];
            [[dataSheet cellForCellReference: cellPath shouldCreate: YES] setStringValue: poleNumber];
            
            cellPath = [NSString stringWithFormat:@"A%d", cellLocation+1];
            [[dataSheet cellForCellReference: cellPath shouldCreate: YES] setStringValue: insertString0];
            cellPath = [NSString stringWithFormat:@"A%d", cellLocation+2];
            [[dataSheet cellForCellReference: cellPath shouldCreate: YES] setStringValue: insertString1];
            
            cellPath = [NSString stringWithFormat:@"A%d", cellLocation+4];
            [[dataSheet cellForCellReference: cellPath shouldCreate: YES] setStringValue: @"DESCRIPTION"];
            cellPath = [NSString stringWithFormat:@"B%d", cellLocation+4];
            [[dataSheet cellForCellReference: cellPath shouldCreate: YES] setStringValue: @"DATA"];
            cellPath = [NSString stringWithFormat:@"C%d", cellLocation+4];
            [[dataSheet cellForCellReference: cellPath shouldCreate: YES] setStringValue: @"QTY"];
            cellPath = [NSString stringWithFormat:@"D%d", cellLocation+4];
            [[dataSheet cellForCellReference: cellPath shouldCreate: YES] setStringValue: @"HEIGHT"];
            
            insertLocation = [NSString stringWithFormat:@"A%d", cellLocation+23];
            [[dataSheet cellForCellReference: insertLocation shouldCreate: YES] setStringValue: @"Transformer, kVa:"];
            cellPath = [NSString stringWithFormat:@"D%d", cellLocation+23];
            poleInsert = [currentPoleDict objectForKey:@"poleField0"];
            if(![poleInsert isEqualToString:@""])
                [[dataSheet cellForCellReference: cellPath shouldCreate: YES] setStringValue: poleInsert];
            
            insertLocation = [NSString stringWithFormat:@"A%d", cellLocation+5];
            [[dataSheet cellForCellReference: insertLocation shouldCreate: YES] setStringValue: @"AT&T Cable:"];
            cellPath = [NSString stringWithFormat:@"D%d", cellLocation+5];
            poleInsert = [currentPoleDict objectForKey:@"poleField1"];
            if(![poleInsert isEqualToString:@""])
                [[dataSheet cellForCellReference: cellPath shouldCreate: YES] setStringValue: poleInsert];
            
            insertLocation = [NSString stringWithFormat:@"A%d", cellLocation+6];
            [[dataSheet cellForCellReference: insertLocation shouldCreate: YES] setStringValue: @"AT&T Drops:"];
            cellPath = [NSString stringWithFormat:@"C%d", cellLocation+6];
            poleInsert = [currentPoleDict objectForKey:@"poleField2"];
            if(![poleInsert isEqualToString:@""])
                [[dataSheet cellForCellReference: cellPath shouldCreate: YES] setStringValue: poleInsert];
            
            insertLocation = [NSString stringWithFormat:@"A%d", cellLocation+7];
            [[dataSheet cellForCellReference: insertLocation shouldCreate: YES] setStringValue: @"AT&T Terminal #:"];
            cellPath = [NSString stringWithFormat:@"C%d", cellLocation+7];
            poleInsert = [currentPoleDict objectForKey:@"poleField3"];
            if(![poleInsert isEqualToString:@""])
                [[dataSheet cellForCellReference: cellPath shouldCreate: YES] setStringValue: poleInsert];
            
            insertLocation = [NSString stringWithFormat:@"A%d", cellLocation+8];
            [[dataSheet cellForCellReference: insertLocation shouldCreate: YES] setStringValue: @"AT&T Placement:"];
            cellPath = [NSString stringWithFormat:@"B%d", cellLocation+8];
            poleInsert = [currentPoleDict objectForKey:@"poleField4"];
            if(![poleInsert isEqualToString:@""])
                [[dataSheet cellForCellReference: cellPath shouldCreate: YES] setStringValue: poleInsert];
            
            insertLocation = [NSString stringWithFormat:@"A%d", cellLocation+9];
            [[dataSheet cellForCellReference: insertLocation shouldCreate: YES] setStringValue: @"AT&T X-box:"];
            cellPath = [NSString stringWithFormat:@"B%d", cellLocation+9];
            poleInsert = [currentPoleDict objectForKey:@"poleField5"];
            if(![poleInsert isEqualToString:@""])
                [[dataSheet cellForCellReference: cellPath shouldCreate: YES] setStringValue: poleInsert];
            
            insertLocation = [NSString stringWithFormat:@"A%d", cellLocation+10];
            [[dataSheet cellForCellReference: insertLocation shouldCreate: YES] setStringValue: @"AT&T Down Guy:"];
            cellPath = [NSString stringWithFormat:@"B%d", cellLocation+10];
            poleInsert = [currentPoleDict objectForKey:@"poleField6"];
            if(![poleInsert isEqualToString:@""]) {
                if(poleInsert==nil)
                    poleInsert=@"";
                else
                    poleInsert = [NSString stringWithFormat:@"LEAD: %@'", poleInsert];
                [[dataSheet cellForCellReference: cellPath shouldCreate: YES] setStringValue: poleInsert];
            }
            
            cellPath = [NSString stringWithFormat:@"D%d", cellLocation+10];
            poleInsert = [currentPoleDict objectForKey:@"poleField7"];
            if(![poleInsert isEqualToString:@""])
                [[dataSheet cellForCellReference: cellPath shouldCreate: YES] setStringValue: poleInsert];
            
            insertLocation = [NSString stringWithFormat:@"A%d", cellLocation+11];
            [[dataSheet cellForCellReference: insertLocation shouldCreate: YES] setStringValue: @"CATV Cable:"];
            cellPath = [NSString stringWithFormat:@"C%d", cellLocation+11];
            poleInsert = [currentPoleDict objectForKey:@"poleField8"];
            if(![poleInsert isEqualToString:@""])
                [[dataSheet cellForCellReference: cellPath shouldCreate: YES] setStringValue: poleInsert];
            
            insertLocation = [NSString stringWithFormat:@"A%d", cellLocation+12];
            [[dataSheet cellForCellReference: insertLocation shouldCreate: YES] setStringValue: @"CATV Drops:"];
            cellPath = [NSString stringWithFormat:@"C%d", cellLocation+12];
            poleInsert = [currentPoleDict objectForKey:@"poleField9"];
            if(![poleInsert isEqualToString:@""])
                [[dataSheet cellForCellReference: cellPath shouldCreate: YES] setStringValue: poleInsert];
            
            insertLocation = [NSString stringWithFormat:@"A%d", cellLocation+14];
            [[dataSheet cellForCellReference: insertLocation shouldCreate: YES] setStringValue: @"CATV Laterals:"];
            cellPath = [NSString stringWithFormat:@"C%d", cellLocation+14];
            poleInsert = [currentPoleDict objectForKey:@"poleField10"];
            if(![poleInsert isEqualToString:@""])
                [[dataSheet cellForCellReference: cellPath shouldCreate: YES] setStringValue: poleInsert];
            
            insertLocation = [NSString stringWithFormat:@"A%d", cellLocation+15];
            [[dataSheet cellForCellReference: insertLocation shouldCreate: YES] setStringValue: @"CATV Down Guy:"];
            cellPath = [NSString stringWithFormat:@"B%d", cellLocation+15];
            poleInsert = [currentPoleDict objectForKey:@"poleField11"];
            if(![poleInsert isEqualToString:@""]){
                if(poleInsert==nil)
                    poleInsert=@"";
                else
                    poleInsert = [NSString stringWithFormat:@"LEAD: %@'", poleInsert];
                [[dataSheet cellForCellReference: cellPath shouldCreate: YES] setStringValue: poleInsert];
            }
            
            cellPath = [NSString stringWithFormat:@"D%d", cellLocation+15];
            poleInsert = [currentPoleDict objectForKey:@"poleField12"];
            if(![poleInsert isEqualToString:@""])
                [[dataSheet cellForCellReference: cellPath shouldCreate: YES] setStringValue: poleInsert];
            
            insertLocation = [NSString stringWithFormat:@"A%d", cellLocation+16];
            [[dataSheet cellForCellReference: insertLocation shouldCreate: YES] setStringValue: @"CE Neutral:"];
            cellPath = [NSString stringWithFormat:@"D%d", cellLocation+16];
            poleInsert = [currentPoleDict objectForKey:@"poleField13"];
            if(![poleInsert isEqualToString:@""])
                [[dataSheet cellForCellReference: cellPath shouldCreate: YES] setStringValue: poleInsert];
            
            insertLocation = [NSString stringWithFormat:@"A%d", cellLocation+17];
            [[dataSheet cellForCellReference: insertLocation shouldCreate: YES] setStringValue: @"CE Drops:"];
            cellPath = [NSString stringWithFormat:@"C%d", cellLocation+17];
            poleInsert = [currentPoleDict objectForKey:@"poleField14"];
            if(![poleInsert isEqualToString:@""])
                [[dataSheet cellForCellReference: cellPath shouldCreate: YES] setStringValue: poleInsert];
            
            insertLocation = [NSString stringWithFormat:@"A%d", cellLocation+18];
            [[dataSheet cellForCellReference: insertLocation shouldCreate: YES] setStringValue: @"CE Primary:"];
            cellPath = [NSString stringWithFormat:@"D%d", cellLocation+18];
            poleInsert = [currentPoleDict objectForKey:@"poleField15"];
            if(![poleInsert isEqualToString:@""])
                [[dataSheet cellForCellReference: cellPath shouldCreate: YES] setStringValue: poleInsert];
            
            insertLocation = [NSString stringWithFormat:@"A%d", cellLocation+19];
            [[dataSheet cellForCellReference: insertLocation shouldCreate: YES] setStringValue: @"CE Secondary:"];
            cellPath = [NSString stringWithFormat:@"D%d", cellLocation+19];
            poleInsert = [currentPoleDict objectForKey:@"poleField16"];
            if(![poleInsert isEqualToString:@""])
                [[dataSheet cellForCellReference: cellPath shouldCreate: YES] setStringValue: poleInsert];
            
            insertLocation = [NSString stringWithFormat:@"A%d", cellLocation+20];
            [[dataSheet cellForCellReference: insertLocation shouldCreate: YES] setStringValue: @"CE Down Guy:"];
            cellPath = [NSString stringWithFormat:@"B%d", cellLocation+20];
            poleInsert = [currentPoleDict objectForKey:@"poleField17"];
            if(![poleInsert isEqualToString:@""]) {
                if(poleInsert==nil)
                    poleInsert=@"";
                else
                    poleInsert = [NSString stringWithFormat:@"LEAD: %@'", poleInsert];
                [[dataSheet cellForCellReference: cellPath shouldCreate: YES] setStringValue: poleInsert];
            }
            
            cellPath = [NSString stringWithFormat:@"D%d", cellLocation+20];
            poleInsert = [currentPoleDict objectForKey:@"poleField18"];
            if(![poleInsert isEqualToString:@""])
                [[dataSheet cellForCellReference: cellPath shouldCreate: YES] setStringValue: poleInsert];
            
            insertLocation = [NSString stringWithFormat:@"A%d", cellLocation+22];
            [[dataSheet cellForCellReference: insertLocation shouldCreate: YES] setStringValue: @"Street Light, Arm:"];
            cellPath = [NSString stringWithFormat:@"D%d", cellLocation+22];
            poleInsert = [currentPoleDict objectForKey:@"poleField28"];
            if(![poleInsert isEqualToString:@""])
                [[dataSheet cellForCellReference: cellPath shouldCreate: YES] setStringValue: poleInsert];
            
            insertLocation = [NSString stringWithFormat:@"A%d", cellLocation+21];
            [[dataSheet cellForCellReference: insertLocation shouldCreate: YES] setStringValue: @"Other Features:"];
            cellPath = [NSString stringWithFormat:@"B%d", cellLocation+21];
            poleInsert = [currentPoleDict objectForKey:@"poleView0"];
            if(![poleInsert isEqualToString:@""])
                [[dataSheet cellForCellReference: cellPath shouldCreate: YES] setStringValue: poleInsert];
            
            insertLocation = [NSString stringWithFormat:@"A%d", cellLocation+13];
            [[dataSheet cellForCellReference: insertLocation shouldCreate: YES] setStringValue: @"CATV Alpha Box:"];
            cellPath = [NSString stringWithFormat:@"B%d", cellLocation+13];
            poleInsert = [currentPoleDict objectForKey:@"poleButton0"];
            if(![poleInsert isEqualToString:@""])
                [[dataSheet cellForCellReference: cellPath shouldCreate: YES] setStringValue: poleInsert];
            
            insertLocation = [NSString stringWithFormat:@"A%d", cellLocation+24];
            [[dataSheet cellForCellReference: insertLocation shouldCreate: YES] setStringValue: @"MGNV:"];
            cellPath = [NSString stringWithFormat:@"B%d", cellLocation+24];
            poleInsert = [currentPoleDict objectForKey:@"poleButton1"];
            if(![poleInsert isEqualToString:@""])
                [[dataSheet cellForCellReference: cellPath shouldCreate: YES] setStringValue: poleInsert];
            
            insertLocation = [NSString stringWithFormat:@"A%d", cellLocation+25];
            [[dataSheet cellForCellReference: insertLocation shouldCreate: YES] setStringValue: @"Coordinates:"];
            cellPath = [NSString stringWithFormat:@"B%d", cellLocation+25];
            NSString *xString = [currentPoleDict objectForKey:@"xCoordinate"];
            NSString *yString = [currentPoleDict objectForKey:@"yCoordinate"];
            poleInsert = [NSString stringWithFormat:@"%@, %@", xString, yString];
            if(![poleInsert isEqualToString:@""])
                [[dataSheet cellForCellReference: cellPath shouldCreate: YES] setStringValue: poleInsert];
        }
    }
    [xlsxPackage save];
    dataSheet = nil;
    xlsxPackage = nil;
}

- (void) writeXlsxTelemetry {
    NSMutableDictionary *plistDict = [self getDictionaryOnMainThread];
    NSString *insertLocation, *gpsIcon, *insertCoordinates;
    BRAOfficeDocumentPackage *xlsxPackage = [BRAOfficeDocumentPackage open:self.packagePath];
    BRAWorksheet *dataSheet = xlsxPackage.workbook.worksheets[2];
    BOOL validData=YES;
    
    for (int i=1; validData; i++) {
        insertLocation = [NSString stringWithFormat:@"B%d", i+1];
        gpsIcon = [NSString stringWithFormat:@"GPS Icon %d", i];
        [[dataSheet cellForCellReference: insertLocation shouldCreate: YES] setStringValue: gpsIcon];
        insertLocation = [NSString stringWithFormat:@"C%d", i+1];
        insertCoordinates = [plistDict objectForKey:gpsIcon];
        
        if([insertCoordinates isEqual:nil])
            validData=FALSE;
        else
            [[dataSheet cellForCellReference: insertLocation shouldCreate: YES] setStringValue: insertCoordinates];
    }
    
    [xlsxPackage save];
}

- (void) writeXlsxCheckList {
    NSMutableDictionary *plistDict = [self getDictionaryOnMainThread];
    NSString *checklist0;
    BRAOfficeDocumentPackage *xlsxPackage = [BRAOfficeDocumentPackage open: self.packagePath];
    BRAWorksheet *dataSheet = xlsxPackage.workbook.worksheets[2];
    
    checklist0 = [plistDict objectForKey:@"button22"];
    if(![checklist0 isEqual:nil])
        [[dataSheet cellForCellReference: @"D3" shouldCreate: YES] setStringValue: checklist0];
    
    checklist0 = [plistDict objectForKey:@"button23"];
    if(![checklist0 isEqual:nil])
        [[dataSheet cellForCellReference: @"D4" shouldCreate: YES] setStringValue: checklist0];
    
    checklist0 = [plistDict objectForKey:@"button24"];
    if(![checklist0 isEqual:nil])
        [[dataSheet cellForCellReference: @"D5" shouldCreate: YES] setStringValue: checklist0];
    
    checklist0 = [plistDict objectForKey:@"button25"];
    if(![checklist0 isEqual:nil])
        [[dataSheet cellForCellReference: @"D6" shouldCreate: YES] setStringValue: checklist0];
    
    checklist0 = [plistDict objectForKey:@"button26"];
    if(![checklist0 isEqual:nil])
        [[dataSheet cellForCellReference: @"D7" shouldCreate: YES] setStringValue: checklist0];
    
    checklist0 = [plistDict objectForKey:@"button27"];
    if(![checklist0 isEqual:nil])
        [[dataSheet cellForCellReference: @"D8" shouldCreate: YES] setStringValue: checklist0];
    
    checklist0 = [plistDict objectForKey:@"button28"];
    if(![checklist0 isEqual:nil])
        [[dataSheet cellForCellReference: @"D9" shouldCreate: YES] setStringValue: checklist0];
    
    checklist0 = [plistDict objectForKey:@"button29"];
    if(![checklist0 isEqual:nil])
        [[dataSheet cellForCellReference: @"D10" shouldCreate: YES] setStringValue: checklist0];
    
    checklist0 = [plistDict objectForKey:@"button30"];
    if(![checklist0 isEqual:nil])
        [[dataSheet cellForCellReference: @"D11" shouldCreate: YES] setStringValue: checklist0];
    
    checklist0 = [plistDict objectForKey:@"button31"];
    if(![checklist0 isEqual:nil])
        [[dataSheet cellForCellReference: @"D12" shouldCreate: YES] setStringValue: checklist0];
    
    checklist0 = [plistDict objectForKey:@"button32"];
    if(![checklist0 isEqual:nil])
        [[dataSheet cellForCellReference: @"D13" shouldCreate: YES] setStringValue: checklist0];
    
    checklist0 = [plistDict objectForKey:@"button33"];
    if(![checklist0 isEqual:nil])
        [[dataSheet cellForCellReference: @"D14" shouldCreate: YES] setStringValue: checklist0];
    
    checklist0 = [plistDict objectForKey:@"button34"];
    if(![checklist0 isEqual:nil])
        [[dataSheet cellForCellReference: @"D15" shouldCreate: YES] setStringValue: checklist0];
    
    [xlsxPackage save];
}

- (void) writeXlsxBom {
    NSLog(@"Beginning BOM process to XLSX file above now.");
    NSString *demoOutputCell;
    NSMutableArray *bomList = [self getBomOnMainThread];
    BRAOfficeDocumentPackage *xlsxPackage = [BRAOfficeDocumentPackage open: self.packagePath];
    BRAWorksheet *bomSheet = xlsxPackage.workbook.worksheets[3];
    demoOutputCell=[[bomSheet cellForCellReference:@"G2"] stringValue];
    
    int totalBom=(int) bomList.count;
    if(totalBom>0) {
        NSLog(@"Manufacturer Part Number : %@\ntotalBom : %d\nbomList : %@", demoOutputCell, totalBom, bomList);
    } else {
        NSLog(@"Skipping BoM function due to a total entered value of %d.", totalBom);
        return;
    }
    
    for (int i=0; i<totalBom; i++) {
        int intSearch = [bomList[i] intValue];
        if(intSearch!=0) {
            if(i==3||i==12||i==13||i==14||i==15) {
                //divide by 1500 feet and round up
                int tempValue = intSearch;
                intSearch = (tempValue+1500-1)/1500;
                NSLog(@"BoM user total: %d at index: %d is being divided by 1500 feet and rounded up to: %d", tempValue, i, intSearch);
            }
            if(i==27) {
                int tempValue = intSearch;
                intSearch = (tempValue+2000-1)/2000;
                NSLog(@"BoM user total: %d at index: %d is being divided by 1500 feet and rounded up to: %d", tempValue, i, intSearch);
            }
            if(i==74) {
                int tempValue = intSearch;
                intSearch = (tempValue+150-1)/150;
                NSLog(@"BoM user total: %d at index: %d is being divided by 1500 feet and rounded up to: %d", tempValue, i, intSearch);
            }
            NSString *cellReference = ([NSString stringWithFormat:@"I%d", i+4]);
            NSLog(@"Inserting data: %d at %@.", intSearch, cellReference);
            [[bomSheet cellForCellReference: cellReference shouldCreate: YES] setFloatValue:intSearch];
            [[bomSheet cellForCellReference: cellReference] setNumberFormat:@"0"];
        }
    }
    
    if(xlsxPackage == nil) {
        NSLog(@"XLSX Package was released incorrectly!!!");
    }
    else {
        NSLog(@"XLSX Package was retained correctly. Beginning write phase now to: %@.", xlsxPackage);
        [xlsxPackage save];
        //xlsxPackage = nil;
    }
}

- (void) writeXlsxDrawings {
    NSLog(@"Writing DRAWINGS to XLSX file above now.");
    NSString *sheetName, *dateInsert, *stringToSearch, *foundPath;
    NSMutableDictionary *plistDict = [self getDictionaryOnMainThread];
    BRAOfficeDocumentPackage *xlsxPackage = [BRAOfficeDocumentPackage open:self.packagePath];
    BRAWorksheet *mainSheet = xlsxPackage.workbook.worksheets[7];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateStyle:NSDateFormatterMediumStyle];
    [formatter setDateFormat:@"MMM dd, yyyy"];
    dateInsert = [formatter stringFromDate:[NSDate date]];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"NOT (SELF contains %@)", @"Photo"];
    NSArray *allNames=[[WDDrawingManager sharedInstance] drawingNames];
    _allDrawings = [NSMutableArray arrayWithArray:[allNames filteredArrayUsingPredicate:predicate]];
    NSString *nameInsert = [plistDict objectForKey:@"fullName"];
    if(_allDrawings.count>0) {
        NSLog(@"Entering output loop for %d DRAWINGS.", _allDrawings.count);
    } else {
        NSLog(@"Exiting output loop due to %d DRAWINGS.", _allDrawings.count);
        return;
    }
    
    for (int pagesAdded = 0; pagesAdded < _allDrawings.count; pagesAdded++) {
        //prep data
        sheetName = [NSString stringWithFormat:@"Drawing %d", pagesAdded+1];
        BRAWorksheet *newSheet = [xlsxPackage.workbook createWorksheetNamed:sheetName byCopyingWorksheet:mainSheet];
        stringToSearch = _allDrawings[pagesAdded];
        stringToSearch = [stringToSearch stringByDeletingPathExtension];
        foundPath = [self.tempPath stringByAppendingPathComponent: stringToSearch];
        foundPath = [NSString stringWithFormat:@"%@.jpeg", foundPath];
        UIImage *image = [UIImage imageWithContentsOfFile:foundPath];
        
        //insert data
        [[newSheet cellForCellReference:@"C48" shouldCreate:YES]setStringValue:stringToSearch];
        [[newSheet cellForCellReference:@"Z48" shouldCreate:YES]setStringValue:dateInsert];
        [[newSheet cellForCellReference:@"AG48" shouldCreate:YES]setStringValue:nameInsert];
        BRAWorksheetDrawing *drawing = [newSheet addImage:image betweenCellsReferenced:@"C3" and:@"AN46"withInsets:UIEdgeInsetsZero preserveTransparency:NO];
        //drawing.insets = UIEdgeInsetsMake(0., 0., .5, .5);
        NSLog(@"Inserted %@ which is image %@ at page Drawing %d.", foundPath, image, pagesAdded+1);
        
        [xlsxPackage save];
    }
}

- (void) writeXlsxPhotos {
    NSLog(@"Writing PHOTOS to XLSX file above now.");
    NSMutableDictionary *plistDict = [self getDictionaryOnMainThread];
    NSMutableArray *memoList = [self getMemosOnMainThread];
    NSString *nameInsert = [plistDict objectForKey:@"fullName"], *outputString, *finalPrintString, *searchString;
    NSString *drawingsPath = [WDDrawingManager drawingPath];
    NSString *photoLocation = [drawingsPath stringByAppendingPathComponent:@"CameraCache"];
    NSString *path, *dateInsert;
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateStyle:NSDateFormatterMediumStyle];
    [formatter setDateFormat:@"MMM dd, yyyy"];
    dateInsert = [formatter stringFromDate:[NSDate date]];
    BRAOfficeDocumentPackage *xlsxPackage = [BRAOfficeDocumentPackage open: self.packagePath];
    BRAWorksheetDrawing *insertPhoto;
    NSError *error;
    NSArray *photoLocationArray = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:photoLocation error:&error];
    int totalPhotos = photoLocationArray.count, photoNumber = 1;
    NSString *jobNum = [(AppDelegate *) [UIApplication sharedApplication].delegate selectedJob];
    NSLog(@"%d photos.", totalPhotos);
    BRAWorksheet *originalSheet = xlsxPackage.workbook.worksheets[8];
    BOOL remainingPhotos = FALSE;
    if (totalPhotos>0) {
        remainingPhotos = TRUE;
    } else {
        return;
    }
    
    for(int pageNumber = 1; remainingPhotos; pageNumber++) {
        NSString *printSheetName = [NSString stringWithFormat:@"Pictures %d", pageNumber];
        BRAWorksheet *photoSheet;
        
        //UPPER LEFT
        //image
        searchString = [NSString stringWithFormat:@"%@ photo %d.jpeg", jobNum ,photoNumber];
        path = [photoLocation stringByAppendingPathComponent: searchString];
        UIImage *image = [UIImage imageNamed:path];
        if(image) {
            photoSheet = [xlsxPackage.workbook createWorksheetNamed:printSheetName byCopyingWorksheet:originalSheet];
            insertPhoto = [photoSheet addImage:image betweenCellsReferenced:@"C3" and:@"V18" withInsets:UIEdgeInsetsZero preserveTransparency:NO];
            insertPhoto.insets = UIEdgeInsetsMake(0., 0., .5, .5);
            NSLog(@"Inserted upper left photo %@ at %@.", image, path);
        } else {
            NSLog(@"Skipped upper left photo %@ at %@.", image, path);
            remainingPhotos = FALSE;
            return;
        }
        //memo
        finalPrintString = @"";
        
        for(int i=0; i<memoList.count; i++) {
            if([memoList[i] containsString: searchString]) {
                outputString = memoList[i];
                NSRange range = [outputString rangeOfString:@": "];
                finalPrintString = [outputString substringFromIndex:range.location];
                finalPrintString = [finalPrintString substringFromIndex:2];
            }
        }
        [[photoSheet cellForCellReference:@"C18" shouldCreate:YES]setStringValue:finalPrintString];
        photoNumber++;
        
        //UPPER RIGHT
        searchString = [NSString stringWithFormat:@"%@ photo %d.jpeg", jobNum ,photoNumber];
        path = [photoLocation stringByAppendingPathComponent: searchString];
        image = [UIImage imageWithContentsOfFile:path];
        if(image) {
            insertPhoto = [photoSheet addImage:image betweenCellsReferenced:@"V3" and:@"AO18" withInsets:UIEdgeInsetsZero preserveTransparency:NO];
            NSLog(@"Inserted upper right photo %@ at %@.", image, path);
        } else {
            remainingPhotos = FALSE;
            NSLog(@"Skipped upper right photo %@ at %@.", image, path);
        }
        finalPrintString = @"";
        
        for(int i=0; i<memoList.count; i++) {
            if([memoList[i] containsString: searchString]) {
                outputString = memoList[i];
                NSRange range = [outputString rangeOfString:@": "];
                finalPrintString = [outputString substringFromIndex:range.location];
                finalPrintString = [finalPrintString substringFromIndex:2];
            }
        }
        [[photoSheet cellForCellReference:@"V18" shouldCreate:YES]setStringValue:finalPrintString];
        photoNumber++;
        
        //LOWER LEFT
        searchString = [NSString stringWithFormat:@"%@ photo %d.jpeg", jobNum ,photoNumber];
        path = [photoLocation stringByAppendingPathComponent: searchString];
        image = [UIImage imageWithContentsOfFile:path];
        if(image)
            insertPhoto = [photoSheet addImage:image betweenCellsReferenced:@"C20" and:@"V35" withInsets:UIEdgeInsetsZero preserveTransparency:NO];
        else
            remainingPhotos = FALSE;
        finalPrintString = @"";
        
        for(int i=0; i<memoList.count; i++) {
            if([memoList[i] containsString: searchString]) {
                outputString = memoList[i];
                NSRange range = [outputString rangeOfString:@": "];
                finalPrintString = [outputString substringFromIndex:range.location];
                finalPrintString = [finalPrintString substringFromIndex:2];
            }
        }
        [[photoSheet cellForCellReference:@"C35" shouldCreate:YES]setStringValue:finalPrintString];
        photoNumber++;
        
        //LOWER RIGHT
        searchString = [NSString stringWithFormat:@"%@ photo %d.jpeg", jobNum ,photoNumber];
        path = [photoLocation stringByAppendingPathComponent: searchString];
        image = [UIImage imageWithContentsOfFile:path];
        if(image)
            insertPhoto = [photoSheet addImage:image betweenCellsReferenced:@"V20" and:@"AO35" withInsets:UIEdgeInsetsZero preserveTransparency:NO];
        else
            remainingPhotos = FALSE;
        finalPrintString = @"";
        
        for(int i=0; i<memoList.count; i++) {
            if([memoList[i] containsString: searchString]) {
                outputString = memoList[i];
                NSRange range = [outputString rangeOfString:@": "];
                finalPrintString = [outputString substringFromIndex:range.location];
                finalPrintString = [finalPrintString substringFromIndex:2];
            }
        }
        [[photoSheet cellForCellReference:@"V35" shouldCreate:YES]setStringValue:finalPrintString];
        photoNumber++;
        
        //data
        [[photoSheet cellForCellReference:@"Z48" shouldCreate:YES]setStringValue:dateInsert];
        [[photoSheet cellForCellReference:@"AG48" shouldCreate:YES]setStringValue:nameInsert];
        
        [xlsxPackage save];
    }
}

- (void) writeDataPage {
    NSString *dataInsert;
    NSMutableDictionary *plistDict = [self getDictionaryOnMainThread];
    BRAOfficeDocumentPackage *xlsxPackage = [BRAOfficeDocumentPackage open: self.packagePath];
    BRAWorksheet *dataSheet = xlsxPackage.workbook.worksheets[0];
    NSDate *date = [SelectJob loadJobStartTime];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"cccc, MMM dd, yyyy - hh:mm a z"];
    
    dataInsert = [formatter stringFromDate:date];
    if(![dataInsert isEqual:nil])
        [[dataSheet cellForCellReference: @"C2" shouldCreate: YES] setStringValue: dataInsert];
    dataInsert = [(AppDelegate *) [UIApplication sharedApplication].delegate selectedJob];
    if(![dataInsert isEqual:nil])
        [[dataSheet cellForCellReference: @"C3" shouldCreate: YES] setStringValue: dataInsert];
    dataInsert = [plistDict objectForKey:@"Address"];
    if(![dataInsert isEqual:nil])
        [[dataSheet cellForCellReference: @"C4" shouldCreate: YES] setStringValue: dataInsert];
    dataInsert = [plistDict objectForKey:@"fullName"];
    if(![dataInsert isEqual:nil])
        [[dataSheet cellForCellReference: @"C5" shouldCreate: YES] setStringValue: dataInsert];
    dataInsert = [plistDict objectForKey:@"Field Engineer Email"];
    if(![dataInsert isEqual:nil])
        [[dataSheet cellForCellReference: @"C6" shouldCreate: YES] setStringValue: dataInsert];
    dataInsert = [plistDict objectForKey:@"EngineerPhone"];
    if(![dataInsert isEqual:nil])
        [[dataSheet cellForCellReference: @"C7" shouldCreate: YES] setStringValue: dataInsert];
    
    [xlsxPackage save];
}

- (void) finalSave {
    NSLog(@"FINAL SAVE");
    static dispatch_queue_t __serialQueue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __serialQueue = dispatch_queue_create("com.cusoft.uploadFinalSerialQueue", DISPATCH_QUEUE_SERIAL);
    });

    dispatch_async(__serialQueue, ^{
        //@autoreleasepool {
            BRAOfficeDocumentPackage *xlsxPackage = [BRAOfficeDocumentPackage open: self.packagePath];
            [xlsxPackage.workbook removeWorksheetNamed: @"Pictures"];
            [xlsxPackage.workbook removeWorksheetNamed: @"Optional Drawing"];
            [xlsxPackage save];
            xlsxPackage=nil;
            NSLog(@"DONE SAVING XLSX");
            //[[NSNotificationCenter defaultCenter] postNotificationName:@"com.cusoft.totalFileUploadChanged" object:nil];
        //}
    });
    
    dispatch_async(__serialQueue, ^{
        NSLog(@"SEND XLSX");
        [self uploadSpreadsheetToBOX];
    });
}

- (void) writeXlsxData {
    NSLog(@"Writing DATA Page 0 to XLSX file above now.");
    [self writeDataPage0];
    NSLog(@"Writing DATA Page 1 to XLSX file above now.");
    [self writeDataPage1];
    NSLog(@"Writing DATA Page 2 to XLSX file above now.");
    [self writeDataPage2];
}

- (void) writeDataPage0 {
    //Customer Information
    NSMutableDictionary *plistDict = [self getDictionaryOnMainThread];
    BRAOfficeDocumentPackage *xlsxPackage = [BRAOfficeDocumentPackage open: self.packagePath];
    BRAWorksheet *dataSheet = xlsxPackage.workbook.worksheets[1];
    
    NSString *projectDescription0 = [plistDict objectForKey:@"sowAttField4"];
    NSString *projectDescription1 = [plistDict objectForKey:@"sowAttField5"];
    NSString *projectComplete = [NSString stringWithFormat:@"%@ - %@", projectDescription0, projectDescription1];
    if(![projectComplete isEqual:nil])
        [[dataSheet cellForCellReference: @"E3" shouldCreate: YES] setStringValue: projectComplete];
    
    NSString *addressInsert = [plistDict objectForKey:@"smallAddress"];
    if(![addressInsert isEqual:nil])
        [[dataSheet cellForCellReference: @"E22" shouldCreate: YES] setStringValue: addressInsert];
    NSString *cityInsert = [plistDict objectForKey:@"smallCity"];
    if(![cityInsert isEqual:nil])
        [[dataSheet cellForCellReference: @"E23" shouldCreate: YES] setStringValue: cityInsert];
    NSString *stateInsert = [plistDict objectForKey:@"smallState"];
    if(![stateInsert isEqual:nil])
        [[dataSheet cellForCellReference: @"E24" shouldCreate: YES] setStringValue: stateInsert];
    NSString *zipInsert = [plistDict objectForKey:@"smallZip"];
    if(![zipInsert isEqual:nil])
        [[dataSheet cellForCellReference: @"E25" shouldCreate: YES] setStringValue: zipInsert];
    NSString *nameInsert = [plistDict objectForKey:@"sowAttField10"];
    if(![nameInsert isEqual:nil])
        [[dataSheet cellForCellReference: @"E27" shouldCreate: YES] setStringValue: nameInsert];
    NSString *phoneInsert = [plistDict objectForKey:@"sowAttField11"];
    if(![phoneInsert isEqual:nil])
        [[dataSheet cellForCellReference: @"E28" shouldCreate: YES] setStringValue: phoneInsert];
    NSString *faxInsert = [plistDict objectForKey:@"sowAttField13"];
    if(![faxInsert isEqual:nil])
        [[dataSheet cellForCellReference: @"E29" shouldCreate: YES] setStringValue: faxInsert];
    NSString *emailInsert = [plistDict objectForKey:@"sowAttField12"];
    if(![emailInsert isEqual:nil])
        [[dataSheet cellForCellReference: @"E30" shouldCreate: YES] setStringValue: emailInsert];
    
    [xlsxPackage save];
    //xlsxPackage=nil;
}

- (void) writeDataPage1 {
    //Account Information
    NSMutableDictionary *plistDict = [self getDictionaryOnMainThread];
    BRAOfficeDocumentPackage *xlsxPackage = [BRAOfficeDocumentPackage open: self.packagePath];
    BRAWorksheet *dataSheet = xlsxPackage.workbook.worksheets[2];
    
    NSString *romeNumber = [plistDict objectForKey:@"att0"];
    [[dataSheet cellForCellReference: @"C3" shouldCreate: YES] setStringValue: romeNumber];
    
    [xlsxPackage save];
    //xlsxPackage=nil;
}

- (void) writeDataPage2 {
    //SoW
    NSMutableDictionary *plistDict = [self getDictionaryOnMainThread];
    BRAOfficeDocumentPackage *xlsxPackage = [BRAOfficeDocumentPackage open: self.packagePath];
    BRAWorksheet *sowSheet = xlsxPackage.workbook.worksheets[4];
    
    NSString *value101 = [plistDict objectForKey:@"sowText1"];
    NSString *value201 = [plistDict objectForKey:@"sowView2"];
    NSString *value202 = [plistDict objectForKey:@"sowView21"];
    NSString *value301 = [plistDict objectForKey:@"sowView3"];
    NSString *value302 = [plistDict objectForKey:@"sowView31"];
    NSString *value401 = [plistDict objectForKey:@"sowView4"];
    NSString *value501 = [plistDict objectForKey:@"sowView5"];
    NSString *value601 = [plistDict objectForKey:@"sowView6"];
    NSString *value701 = [plistDict objectForKey:@"sowView7"];
    
    if(![value101 isEqual:nil])
        [[sowSheet cellForCellReference: @"C3" shouldCreate: YES] setStringValue: value101];
    if(![value201 isEqual:nil])
        [[sowSheet cellForCellReference: @"C9" shouldCreate: YES] setStringValue: value201];
    if(![value202 isEqual:nil])
        [[sowSheet cellForCellReference: @"C10" shouldCreate: YES] setStringValue: value202];
    if(![value301 isEqual:nil])
        [[sowSheet cellForCellReference: @"C13" shouldCreate: YES] setStringValue: value301];
    if(![value302 isEqual:nil])
        [[sowSheet cellForCellReference: @"C14" shouldCreate: YES] setStringValue: value302];
    if(![value401 isEqual:nil])
        [[sowSheet cellForCellReference: @"C17" shouldCreate: YES] setStringValue: value401];
    if(![value501 isEqual:nil])
        [[sowSheet cellForCellReference: @"C20" shouldCreate: YES] setStringValue: value501];
    if(![value601 isEqual:nil])
        [[sowSheet cellForCellReference: @"C23" shouldCreate: YES] setStringValue: value601];
    if(![value701 isEqual:nil])
        [[sowSheet cellForCellReference: @"C26" shouldCreate: YES] setStringValue: value701];
    
    [xlsxPackage save];
    //xlsxPackage=nil;
}

#pragma BOX UPLOAD
- (void)saveFolderID {
    AppDelegate* delegate = (AppDelegate*)[UIApplication sharedApplication].delegate;
    NSMutableDictionary *plistDict = delegate.surveyDataDictionary;
    [plistDict setObject:self.folderModelID forKey:@"folderModelID"];
        
    NSLog(@"Saved folderModelID %@ to local.", self.folderModelID);
}

-(void)deleteCloudFolder: (NSNotification *)notification {
    AppDelegate* delegate = (AppDelegate*)[UIApplication sharedApplication].delegate;
    NSMutableDictionary *dicData = [(AppDelegate *) [UIApplication sharedApplication].delegate surveyDataDictionary];
    NSString *jobName = [NSString stringWithFormat:@"%@_%@", delegate.selectedJob, [dicData objectForKey:@"engName"]];
    BOXContentClient *contentClient = [BOXContentClient defaultClient];
    self.folderModelID = @"";
    
    //check for previous folder at range x
    int rangeInt=100000;
    BOXSearchRequest *searchRequest = [contentClient searchRequestWithQuery:delegate.selectedJob inRange:NSMakeRange(0, rangeInt)];
    searchRequest.ancestorFolderIDs = @[[AppDelegate boxOutputPage]]; // only items in these folders will be returned
    NSLog(@"Searching for folder with range %d to begin deletion process of %@.", rangeInt, jobName);
    [searchRequest performRequestWithCompletion:^(NSArray *items, NSUInteger totalCount, NSRange range, NSError *error) {
        // If successful, items will be non-nil and contain BOXItem model objects; otherwise, error will be non-nil.
        NSLog(@"SEARCH COMPLETE WITH %d ITEMS: %@ ERROR: %@ RANGE: %d.", totalCount, items, error, rangeInt);
        if(totalCount==0) {
            [[NSNotificationCenter defaultCenter] postNotificationName:@"com.cusoft.deleteFailed" object:nil];
        }
        
        if(items) {
            for(int i=0; i<items.count; i++) {
                BOXItem *item = items[i];
                NSLog(@"FOUND %@ AT %d FOR %d.", item.name, i+1, totalCount);
                if (item.isFolder) {
                    if([item.name isEqualToString:jobName]) {
                        NSLog(@"Succesfully found pre-existing cloud folder %@!", item.name);
                        i=items.count;
                        
                        BOXFolderDeleteRequest *folderDeleteRequest = [contentClient folderDeleteRequestWithID:item.modelID];
                        [folderDeleteRequest performRequestWithCompletion:^(NSError *error) {
                            // If successful, error will be nil.
                            if(!error) {
                                NSLog(@"Succesfully removed cloud folder %@!", item.name);
                                [self newCloudFolder];
                                return;
                            } else {
                                NSLog(@"Succesfully found folder, but ERROR in deleting folder %@!", item.name);
                                return;
                            }
                        }];
                    }
                } else {
                    NSLog(@"Found a file, not a folder at %@.", item.name);
                }
            }
        } else {
            NSLog(@"NOTHING FOUND DURING DELETION %@.", error);
        }
    }];
}

-(void) newCloudFolder {
    NSLog(@"BOX SYNCHRONIZER: Creating cloud folder.");
    AppDelegate* delegate = (AppDelegate*)[UIApplication sharedApplication].delegate;
    //NSMutableDictionary *dicData = [self getDictionaryOnMainThread];
    //NSString *jobName = [NSString stringWithFormat:@"%@_%@", delegate.selectedJob, [dicData objectForKey:@"engName"]];
    BOXContentClient *contentClient = [BOXContentClient defaultClient];
    self.folderModelID = @"";
    
    //new folder
    BOXFolderCreateRequest *folderCreateRequest = [contentClient folderCreateRequestWithName:delegate.selectedJob parentFolderID:[AppDelegate boxOutputPage]];
    [folderCreateRequest performRequestWithCompletion:^(BOXFolder *folder, NSError *error) {
        // If successful, folder will be non-nil and represent the newly created folder on Box; otherwise, error will be non-nil.
        if(folder) {//first upload
            NSLog(@"Successfully created new cloud folder %@.", delegate.selectedJob);
            self.folderModelID = folder.modelID;
            [self saveFolderID];//for email
            [self accessoryCloudFolders];
            [self uploadMapsToBOX];
        } else {//revised upload - error will contain the existing folder modelID
            NSLog(@"There was an issue creating the folder for %@. Error: %@. Deleting %@...", delegate.selectedJob, error, folder);
            [[NSNotificationCenter defaultCenter] postNotificationName:@"com.cusoft.deleteCloudFolderAlert" object:nil];
        }
    }];
}

-(void) accessoryCloudFolders {
    //check all files in "Uploads" for photos and create those respective folders as well, as needed
    BOOL photosExist = FALSE, polesExist = FALSE;
    NSString *poleCheckString = [NSString stringWithFormat:@"%@ Pole Photo", [(AppDelegate *)[UIApplication sharedApplication].delegate selectedJob]];
    NSString *photoCheckString = [NSString stringWithFormat:@"%@ Reference Photo", [(AppDelegate *)[UIApplication sharedApplication].delegate selectedJob]];
    NSString *drawingsPath = [WDDrawingManager drawingPath];
    NSString *uploadsFolderPath = [drawingsPath stringByAppendingPathComponent:@"Upload"];
    NSArray *uploadsFolder = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:uploadsFolderPath error:nil];
        
    for(int j=0; j<uploadsFolder.count; j++) {
        if([uploadsFolder[j] containsString:poleCheckString]) {
            if(!polesExist) {
                polesExist = TRUE;
                [self newPolesCloudFolder];
            }
        } else if([uploadsFolder[j] containsString:photoCheckString]) {
            if(!photosExist) {
                photosExist = TRUE;
                [self newPhotosCloudFolder];
            }
        }
        if(photosExist && polesExist) {
            break;
        }
    }
}

-(void) newPolesCloudFolder {
    NSLog(@"BOX SYNCHRONIZER: Creating POLES cloud folder.");
    AppDelegate *delegate = (AppDelegate*)[UIApplication sharedApplication].delegate;
    NSString *poleFolderName = [NSString stringWithFormat:@"%@_Pole_PICS", delegate.selectedJob];
    BOXContentClient *contentClient = [BOXContentClient defaultClient];
    self.polesFolderModelID = @"";
    
    BOXFolderCreateRequest *folderCreateRequest = [contentClient folderCreateRequestWithName:poleFolderName parentFolderID:self.folderModelID];
    [folderCreateRequest performRequestWithCompletion:^(BOXFolder *folder, NSError *error) {
        if(folder) {
            NSLog(@"Successfully created new POLES cloud folder %@.", poleFolderName);
            self.polesFolderModelID = folder.modelID;
            [self uploadPolesToBOX];
        }
    }];
}

-(void) newPhotosCloudFolder {
    NSLog(@"BOX SYNCHRONIZER: Creating PHOTOS cloud folder.");
    AppDelegate *delegate = (AppDelegate*)[UIApplication sharedApplication].delegate;
    NSString *photosFolderName = [NSString stringWithFormat:@"%@_Reference_PICS", delegate.selectedJob];
    BOXContentClient *contentClient = [BOXContentClient defaultClient];
    self.photosFolderModelID = @"";
    
    BOXFolderCreateRequest *folderCreateRequest = [contentClient folderCreateRequestWithName:photosFolderName parentFolderID:self.folderModelID];
    [folderCreateRequest performRequestWithCompletion:^(BOXFolder *folder, NSError *error) {
        if(folder) {
            NSLog(@"Successfully created new PHOTOS cloud folder %@.", photosFolderName);
            self.photosFolderModelID = folder.modelID;
            [self uploadPhotosToBOX];
        }
    }];
}

-(void) uploadMapsToBOX {
    NSString *photoCheckString = [NSString stringWithFormat:@"%@ Reference Photo", [(AppDelegate *)[UIApplication sharedApplication].delegate selectedJob]];
    NSString *poleCheckString = [NSString stringWithFormat:@"%@ Pole Photo", [(AppDelegate *)[UIApplication sharedApplication].delegate selectedJob]];
    BOXContentClient *contentClient = [BOXContentClient defaultClient];
    NSArray *dirFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.uploadPath error:NULL];
    
    for (int j=0; j<dirFiles.count; j++) {
        NSString *filePath = [self.uploadPath stringByAppendingPathComponent:dirFiles[j]];
        
        //send maps to default folder
        if (![dirFiles[j] isEqualToString: self.spreadSheetName] && ![dirFiles[j] containsString: photoCheckString] && ![dirFiles[j] containsString: poleCheckString]) {
            NSLog(@"Uploading %d file of %d. File name: %@.", j, dirFiles.count, filePath);
            BOXFileUploadRequest *uploadRequest = [contentClient fileUploadRequestToFolderWithID:self.folderModelID fromLocalFilePath:filePath];
            
            [uploadRequest performRequestWithProgress:^(long long totalBytesTransferred, long long totalBytesExpectedToTransfer) {
            } completion:^(BOXFile *file, NSError *error) {
                if(error) {
                    NSLog(@"Upload failed on %@ at %@.", file, filePath);
                } else {
                    [self moveCompletedFile:file.name];
                    NSLog(@"Upload success on %@ at %@.", file, filePath);
                }
                
                [self checkIfFinished];
            }];
        }
    }
}

-(void) uploadPhotosToBOX {
    NSString *photoCheckString = [NSString stringWithFormat:@"%@ Reference Photo", [(AppDelegate *)[UIApplication sharedApplication].delegate selectedJob]];
    BOXContentClient *contentClient = [BOXContentClient defaultClient];
    NSArray *dirFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.uploadPath error:NULL];
    
    for (int j=0; j<dirFiles.count; j++) {
        NSString *filePath = [self.uploadPath stringByAppendingPathComponent:dirFiles[j]];
        
        if([dirFiles[j] containsString: photoCheckString]) {
            NSLog(@"Uploading %d file of %d. File name: %@.", j, dirFiles.count, filePath);
            BOXFileUploadRequest *uploadRequest = [contentClient fileUploadRequestToFolderWithID:self.photosFolderModelID fromLocalFilePath:filePath];
            
            [uploadRequest performRequestWithProgress:^(long long totalBytesTransferred, long long totalBytesExpectedToTransfer) {
            } completion:^(BOXFile *file, NSError *error) {
                if(error) {
                    NSLog(@"Upload failed on %@ at %@.", file, filePath);
                } else {
                    [self moveCompletedFile:file.name];
                    NSLog(@"Upload success on %@ at %@.", file, filePath);
                }
                
                [self checkIfFinished];
            }];
        }
    }
}

-(void) uploadPolesToBOX {
    NSString *poleCheckString = [NSString stringWithFormat:@"%@ Pole Photo", [(AppDelegate *)[UIApplication sharedApplication].delegate selectedJob]];
    BOXContentClient *contentClient = [BOXContentClient defaultClient];
    NSArray *dirFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.uploadPath error:NULL];
    
    for (int j=0; j<dirFiles.count; j++) {
        NSString *filePath = [self.uploadPath stringByAppendingPathComponent:dirFiles[j]];
        
        if([dirFiles[j] containsString: poleCheckString]) {
            NSLog(@"Uploading %d file of %d. File name: %@.", j, dirFiles.count, filePath);
            BOXFileUploadRequest *uploadRequest = [contentClient fileUploadRequestToFolderWithID:self.polesFolderModelID fromLocalFilePath:filePath];
            
            [uploadRequest performRequestWithProgress:^(long long totalBytesTransferred, long long totalBytesExpectedToTransfer) {
            } completion:^(BOXFile *file, NSError *error) {
                if(error) {
                    NSLog(@"Upload failed on %@ at %@.", file, filePath);
                } else {
                    [self moveCompletedFile:file.name];
                    NSLog(@"Upload success on %@ at %@.", file, filePath);
                }
                
                [self checkIfFinished];
            }];
        }
    }
}

-(void) checkIfFinished {
    int totalCompletedInt = [self.totalCompletedUploads intValue];
    totalCompletedInt++;
    self.totalCompletedUploads = [NSString stringWithFormat:@"%d", totalCompletedInt];
    
    int totalNeededInt = [self.totalNeededUploads intValue];
    totalNeededInt--;
    
    NSLog(@"BOX SYNCHRONIZER: check if finished: %d==%d?", totalCompletedInt, totalNeededInt);
    if (totalCompletedInt == totalNeededInt) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"com.cusoft.threadRipXlsx" object:nil];
    }
}

-(void) uploadSpreadsheetToBOX {
    BOXContentClient *contentClient = [BOXContentClient defaultClient];
    BOXFileUploadRequest *uploadRequest = [contentClient fileUploadRequestToFolderWithID:self.folderModelID fromLocalFilePath: self.packagePath];
    [uploadRequest performRequestWithProgress:^(long long totalBytesTransferred, long long totalBytesExpectedToTransfer) {
    
    } completion:^(BOXFile *file, NSError *error) {
        if(error) {
            NSLog(@"Upload failed on %@ at %@.", file, self.packagePath);
        } else {
            NSLog(@"Upload success on %@ at %@.", file, self.packagePath);
            
            [self moveCompletedFile:file.name];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"com.cusoft.saveDataComplete" object:nil];
        }
    }];
}

-(void) moveCompletedFile:(NSString *)fileName {
    NSError *error;
    NSString *originalPath = [self.uploadPath stringByAppendingPathComponent:fileName];
    NSString *newPath = [self.completedPath stringByAppendingPathComponent:fileName];
    
    [[NSFileManager defaultManager] copyItemAtPath:originalPath toPath:newPath error:&error];
    if(error) {
        
    } else {
        //NSLog(@"Moved %@ to %@.", originalPath, newPath);
        [[NSNotificationCenter defaultCenter] postNotificationName:@"com.cusoft.totalFileUploadChanged" object:nil];
    }
}

-(void) setDocumentDirectory {
    dispatch_async(dispatch_get_main_queue(), ^ {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        self.documentsDirectory = paths[0];
        NSLog(@"document directory: %@", self.documentsDirectory);
    });
}

-(void) setJobDirectory {
    dispatch_async(dispatch_get_main_queue(), ^ {
        AppDelegate *delegate = (AppDelegate *) [UIApplication sharedApplication].delegate;
        self.jobDirectory = [[self.documentsDirectory stringByAppendingPathComponent:@"TechAssistant"] stringByAppendingPathComponent:delegate.selectedJob];
    });
}

@end
