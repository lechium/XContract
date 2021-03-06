//
//  XContract.m
//  XContract
//
//  Created by Kevin Bradley on 12/10/14.
//  Copyright (c) 2014 Kevin Bradley. All rights reserved.
//

#import "XContract.h"

#define autoCheckInterval 3600
#define autoSaveInterval 600

static XContract *sharedPlugin;

@interface XContract()

@property (nonatomic, strong) XContractWindowController* windowController;
@property (nonatomic, strong, readwrite) NSBundle *bundle;
@end

@implementation XContract

+ (void)initialize
{
    NSDictionary *appDefaults = @{ kXContractHeartbeatTimer: [NSNumber numberWithBool:TRUE] };
    [[NSUserDefaults standardUserDefaults] registerDefaults:appDefaults];
}

+ (void)pluginDidLoad:(NSBundle *)plugin
{
    static dispatch_once_t onceToken;
    NSString *currentApplicationName = [[NSBundle mainBundle] infoDictionary][@"CFBundleName"];
    if ([currentApplicationName isEqual:@"Xcode"]) {
        dispatch_once(&onceToken, ^{
            sharedPlugin = [[self alloc] initWithBundle:plugin];
        });
    }
}

+ (instancetype)sharedPlugin
{
    return sharedPlugin;
}

- (void)XContractDelayedSetup
{
    
    NSMenuItem *menuItem = [[NSApp mainMenu] itemWithTitle:@"Product"];
    if (menuItem) {
        [[menuItem submenu] addItem:[NSMenuItem separatorItem]];
        
        NSMenuItem *xcMenuItem = [[NSMenuItem alloc] init];
        [xcMenuItem setTitle:@"XContract"];
        
        NSMenu *xcontractMenu = [[NSMenu alloc] initWithTitle:@""];
        
        //for now this window doesn't do anything, could potentially be used to
        //add more info per project, current paid hours, hourly rate, etc...
        
        /*
         
         NSMenuItem *windowMenuItem = [[NSMenuItem alloc] initWithTitle:@"Show XContract window" action:@selector(showWindow) keyEquivalent:@""];
         // [actionMenuItem setKeyEquivalentModifierMask:NSControlKeyMask];
         [windowMenuItem setTarget:self];
         
         [xcontractMenu addItem:windowMenuItem];
         
         */
        
        NSMenuItem *startTimerItem = [[NSMenuItem alloc] initWithTitle:@"Start timer for current project" action:@selector(startTimerForProject:) keyEquivalent:@""];
        //  [trelloItem setKeyEquivalentModifierMask:NSControlKeyMask];
        [startTimerItem setTarget:self];
        [xcontractMenu addItem:startTimerItem];
        NSMenuItem *stopTimerItem = [[NSMenuItem alloc] initWithTitle:@"Stop timer for current project" action:@selector(stopTimerForProject) keyEquivalent:@""];
        [stopTimerItem setTarget:self];
        [xcontractMenu addItem:stopTimerItem];
        
        NSMenuItem *exportExcelItem = [[NSMenuItem alloc] initWithTitle:@"Export hours for current project" action:@selector(createExcelFile:) keyEquivalent:@""];
        [exportExcelItem setTarget:self];
        [xcontractMenu addItem:exportExcelItem];
        
        [xcontractMenu addItem:[NSMenuItem separatorItem]];
        
        NSMenuItem *showPreferencesWindowItem = [[NSMenuItem alloc] initWithTitle:@"Preferences..." action:@selector(showPreferenceWindow) keyEquivalent:@""];
        [showPreferencesWindowItem setTarget:self];
        [xcontractMenu addItem:showPreferencesWindowItem];
        
        [xcMenuItem setSubmenu:xcontractMenu];
        [[menuItem submenu] addItem:xcMenuItem];
    }
    static dispatch_once_t onceToken2;
    dispatch_once(&onceToken2, ^{
        
        
        //override application termination to make sure we stop any save any unsaved progress hours
        [self swizzleScience];
    });
}

- (id)initWithBundle:(NSBundle *)plugin
{
    if (self = [super init]) {
        // reference to plugin's bundle, for resource access
        self.bundle = plugin;
        
        if (self.windowController == nil) {
            XContractWindowController* wc = [[XContractWindowController alloc] initWithWindowNibName:@"XContractWindowController"];
            self.windowController = wc;
            wc.delegate = self;
            
        }
        
        // Create menu items, initialize UI, etc.
       
    }
    
    
    NSUserDefaults* prefs = [NSUserDefaults standardUserDefaults];
    
    [prefs addObserver:self
            forKeyPath:kXContractHeartbeatTimer
               options:NSKeyValueObservingOptionNew
               context:NULL];
    
    //you only swizzle once!
    
    
    
    //NSWorkspaceWillSleepNotification
    //NSWorkspaceDidWakeNotification
    
    //monitor sleep / wake to start / stop hours.
    
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(didWake:) name:NSWorkspaceDidWakeNotification object:nil];
    
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(willSleep:) name:NSWorkspaceWillSleepNotification object:nil];
    
    promptOnWake = FALSE;
    [NSTimer scheduledTimerWithTimeInterval:8 target:self selector:@selector(XContractDelayedSetup) userInfo:nil repeats:FALSE];
    return self;
}

#pragma mark core timer stop / start methods

/**
 
 this method is where we handle starting a timer for frontmost project.
 
 */

- (void)startTimerForProject:(NSString *)theProject
{
    LOG_SELF;
    
    //can only track one project at at time, show alert if we are already tracking one
    
    if (self.currentTrackedProject != nil)
    {
        NSAlert *alreadyTrackingProject = [NSAlert alertWithMessageText:@"Timer Active" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Currently only one project can be tracked at a time."];
        
        [alreadyTrackingProject runModal];
        return;
    }
    
    //this method can be called manually with our prior project (only done when waking from sleep)
    //when this is called from a menu item the passed in parameter is NSMenuItem, we don't use that.
    
    if (![theProject isKindOfClass:[NSString class]])
        self.currentTrackedProject = [XCModel currentProjectName]; //called from menu item, choose frontmost project
    else
        self.currentTrackedProject = theProject;
    
    
    if (self.currentTrackedProject.length == 0) //we have no project, query for it manually
    {
        if ([self setManualProjectName] == FALSE) //if they dont enter text for project name we are going to bail.
        {
            NSAlert *noNameAlert = [NSAlert alertWithMessageText:@"No project name detected!" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Still no name chosen (blank entry) aborting start timer."];
            [noNameAlert runModal];
            return;
        }
        
    }
    //if we got this far we should have a project name, now check the contract plist for any details on this project
    
    //get the current time worked for our current day
    self.priorElapsedTime = [XCModel currentTimeFromProjectName:self.currentTrackedProject];
    
    //we will use the start date to find an interval in seconds when we stop to save updated time worked
    
    self.startDate = [NSDate date];
    NSLog(@"### starting timer for project name: %@ start date: %@ prior time: %li", self.currentTrackedProject, self.startDate, self.priorElapsedTime);
    
    //fire the timer that autosaves every 10 minutes
    
    autoSaveTimer = [NSTimer scheduledTimerWithTimeInterval:autoSaveInterval target:self selector:@selector(autoSaveTimer) userInfo:nil repeats:TRUE];
    
    //user can toggle whether or not to be prompted hourly if they are still working
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kXContractHeartbeatTimer] == TRUE)
    {
        stillWorkingTimer = [NSTimer scheduledTimerWithTimeInterval:autoCheckInterval target:self selector:@selector(stillWorkingHeartbeat) userInfo:nil repeats:TRUE];
    }
    
    
}

/**
 
 This might be fired upon xcode shutting down, computer going to sleep or manually from the user. will figure out
 the elapsed time since we started tracking and update the proper section of our contract dictionary datasource.
 
 */

- (void)stopTimerForProject
{
    //idiot proofing
    if (self.currentTrackedProject == nil) return;
    
    //how much time has passed since we started tacking
    
    NSTimeInterval elapsedTimeSinceStart = [[NSDate date] timeIntervalSinceDate:self.startDate];
    
    //add that time to any time tracked prior for the current day and get a full count of time worked today.
    
    NSInteger totalElapsedTimeForDate = self.priorElapsedTime + elapsedTimeSinceStart;
    
    NSLog(@"### stopping timer for project name: %@ start date: %@ new elapsed time: %li", self.currentTrackedProject, self.startDate, totalElapsedTimeForDate);
    
    //update our datamodel
    [XCModel updateTime:totalElapsedTimeForDate forProject:self.currentTrackedProject];
    
    //invalidate all the auto save timers and reset to default non - tracking phase.
    self.currentTrackedProject = nil;
    self.startDate = nil;
    self.priorElapsedTime = 0;
    [autoSaveTimer invalidate];
    autoSaveTimer = nil;
    [stillWorkingTimer invalidate];
    stillWorkingTimer = nil;
}

/**
 
 if project name can't be detected for some reason (maybe there isnt a project window as frontmost)
 this will allow the user to manually type in a name in an NSAlert with an aux text field view
 
 */

- (BOOL)setManualProjectName
{
    NSAlert *alertWithAux = [NSAlert alertWithMessageText:@"No project name detected!" defaultButton:@"OK" alternateButton:nil otherButton:@"Cancel" informativeTextWithFormat:@"No project name detected, please enter the project name you are tracking for."];
    
    manualProjectNameField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 300, 44)];
    [manualProjectNameField setEditable:TRUE];
    [manualProjectNameField setBordered:TRUE];
    
    
    NSView *viewTextEntry = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 340, 44)];
    [viewTextEntry addSubview:manualProjectNameField];
    [alertWithAux setAccessoryView:viewTextEntry];
    
    
    NSModalResponse modalResp = [alertWithAux runModal];
    switch (modalResp) {
        case NSAlertDefaultReturn: //ok
            self.currentTrackedProject = manualProjectNameField.stringValue;
            if (self.currentTrackedProject.length == 0)
                return FALSE;
            else
                return TRUE;
            
        case NSAlertOtherReturn: //cancel
            return FALSE;
    }
    
    return FALSE;
}


#pragma mark Sleep Handling

- (void)willSleep:(NSNotification *)c
{
    LOG_SELF;
    if (self.currentActiveProject != nil)
    {
        lastTrackedProject = self.currentActiveProject;
        [self stopTimerForProject];
        promptOnWake = TRUE;
    }
}


- (void)didWake:(NSNotification *)c
{
    LOG_SELF;
    if (promptOnWake == TRUE)
    {
        [self bringXcodeToFront];
        NSAlert *alreadyTrackingProject = [NSAlert alertWithMessageText:@"Restart timer?" defaultButton:@"Yes" alternateButton:@"No" otherButton:nil informativeTextWithFormat:@"We automatically stopped the timer upon sleep, do you want to restart it for the project: %@?", lastTrackedProject];
        
        NSModalResponse theResponse = [alreadyTrackingProject runModal];
        switch (theResponse) {
            case NSAlertDefaultReturn:
                
                [self startTimerForProject:lastTrackedProject];
                lastTrackedProject = nil;
                promptOnWake = false;
                break;
                
            case NSAlertAlternateReturn:
                lastTrackedProject = nil;
                promptOnWake = false;
                break;
                
            default:
                break;
        }
    }
}

#pragma mark swizzles

//heres where the swizzling takes place to override applicationWillTerminate: to make sure any changes are saved before xcode closes.

- (void)swizzleScience
{
    Class xcAppClass = objc_getClass("IDEApplicationController");
    NSError *theError = nil;
    
    Method terminateReplacement = class_getInstanceMethod([self class], @selector(ourApplicationWillTerminate:));
    class_addMethod(xcAppClass, @selector(ourApplicationWillTerminate:), method_getImplementation(terminateReplacement), method_getTypeEncoding(terminateReplacement));
    
    BOOL swizzleScience = FALSE;
    
    swizzleScience = [xcAppClass jr_swizzleMethod:@selector(applicationWillTerminate:) withMethod:@selector(ourApplicationWillTerminate:) error:&theError];
    
    if (swizzleScience == TRUE)
    {
        NSLog(@"IDEApplicationController applicationWillTerminate: replaced!");
    } else {
        
        NSLog(@"IDEApplicationController applicationWillTerminate: failed to replace with error: %@", theError);
        
    }
    
    //- (void)applicationWillTerminate:(id)arg1
}

//make sure if we have an active timer to save its settings!

- (void)ourApplicationWillTerminate:(id)arg1
{
    LOG_SELF;
    
    [self ourApplicationWillTerminate:arg1]; // call the original method
    
    //used sharedPlugin rather than self, we are technically inside IDEApplicationController
    if ([sharedPlugin currentTrackedProject] != nil)
    {
        //we are tracking, save changes!
        [sharedPlugin stopTimerForProject];
    }
    
    
}

//unused, was just an example of how to pull an application to the front.
+ (void)bringAppToFront:(NSString *)appID
{
    NSRunningApplication *theApp = [[NSRunningApplication runningApplicationsWithBundleIdentifier:appID] lastObject];
    if (theApp != nil)
    {
        [@"" stringByReplacingOccurrencesOfString:@"" withString:@""];
        [theApp activateWithOptions:NSApplicationActivateAllWindows];
    }
}

//if we display an alert that is timing out the user better see it before we disable the timer!!
- (void)bringXcodeToFront
{
    [[NSApplication sharedApplication] activateIgnoringOtherApps:TRUE];
}

#pragma mark heartbeat & auto save timers

/**
 
 This method will be fired once an hour (if the user hasn't turned it off) to see if the user is still actively working
 on a project.
 
 
 */

- (void)stillWorkingHeartbeat
{
    LOG_SELF;
    
    //its an ivar because we are going to update the message text in the auto dismiss countdown.
    
    heartBeatAlert = [NSAlert alertWithMessageText:@"Still working?" defaultButton:@"Yes" alternateButton:@"No" otherButton:nil informativeTextWithFormat:@"Are you still working on the project: %@?\n\nAuto dismissed choosing 'No' in 20 seconds...\n", self.currentTrackedProject];
    [heartBeatAlert setAlertStyle: NSInformationalAlertStyle];
    
    //since we automatically choose 'no' in 20 seconds, you dont want it automatically dismissed if the user isnt alerted!
    
    //maybe they are reseaching something on stackoverflow! ;)
    
    [self bringXcodeToFront];
    
    //set up a timer to automatically dimiss the alert in 20 seconds (i feel like this should be built in somehow!!)
    
    NSTimer *myTimer = [NSTimer timerWithTimeInterval: 20 target:self selector: @selector(killWindow:) userInfo:nil repeats:NO];
    autoDismissTime = 20;
    
    //need to add to runloop for modal panel mode, otherwise the timer wont fire while the modal alert is blocking.
    [[NSRunLoop currentRunLoop] addTimer:myTimer forMode:NSModalPanelRunLoopMode];
    
    //create another timer to update the message text with how many seconds until we dimiss
    
    NSTimer *updateCountdownTimer = [NSTimer timerWithTimeInterval: 1 target:self selector: @selector(updateStillWorkingTimer) userInfo:nil repeats:TRUE];
    
    //this timer also needs to be processed in the modal runloop mode
    [[NSRunLoop currentRunLoop] addTimer:updateCountdownTimer forMode:NSModalPanelRunLoopMode];
    
    //show alert and process response
    
    NSModalResponse modalResp = [heartBeatAlert runModal];
    
    switch (modalResp) {
        case NSAlertAlternateReturn: //no was selected
            
            //stop project and invalidate our timers
            [self stopTimerForProject];
            [myTimer invalidate];
            myTimer = nil;
            [updateCountdownTimer invalidate];
            updateCountdownTimer = nil;
            break;
            
        default:
            
            //still need to invalidate our timers
            [myTimer invalidate];
            myTimer = nil;
            [updateCountdownTimer invalidate];
            updateCountdownTimer = nil;
            break;
    }
}

//update the alert to count down from 20
- (void)updateStillWorkingTimer
{
    autoDismissTime--;
    NSString *informativeText = [NSString stringWithFormat:@"Are you still working on the project: %@?\n\nAuto dismissed choosing 'No' in %li seconds...\n", self.currentTrackedProject, (long)autoDismissTime];
    [heartBeatAlert setInformativeText:informativeText];
}

//this is fired when we automatically choose no after 20 seconds has elapsed
-(void)killWindow:(NSTimer *)theTimer
{
    LOG_SELF;
    //choose alernatereturn which is equivalent of clicking no on the alert
    [[NSApplication sharedApplication] stopModalWithCode:NSAlertAlternateReturn];
}

//gets fired by autoSaveTimer every 10 minutes to update our time worked.
- (void)autoSaveTimer
{
    LOG_SELF;
    NSTimeInterval elapsedTimeSinceStart = [[NSDate date] timeIntervalSinceDate:self.startDate];
    NSInteger totalElapsedTimeForDate = self.priorElapsedTime + elapsedTimeSinceStart;
    
    NSLog(@"### auto saving timer for project name: %@ start date: %@ new elapsed time: %li", self.currentTrackedProject, self.startDate, totalElapsedTimeForDate);
    
    [XCModel updateTime:totalElapsedTimeForDate forProject:self.currentTrackedProject];
   
    //need to reset prior elapsed time to be what we just saved and set a new start date to check interval from.
    self.priorElapsedTime = totalElapsedTimeForDate;
    self.startDate = [NSDate date];
}
/*
 
 this doesnt really create an excel file, it just creates an unformatted html file with a really basic table in it
 
 http://stackoverflow.com/questions/3587004/is-there-a-library-or-example-for-creating-excel-xlsx-files
 
 based on that example, there IS a libxl library, but it cost money so it could obviously never be part of a plugin
 
 there is probably some better way to do this, for now on an initial version this will have to do.
 
 
 */
- (IBAction)createExcelFile:(id)sender
{
    LOG_SELF;
    NSString *activeProject = [XCModel currentProjectName];
    NSLog(@"activeProject: %@", activeProject);
    if (activeProject != nil)
    {
        NSURL * documentsDirectory = [NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].lastObject;
        NSString *fileName = [NSString stringWithFormat:@"%@.xls", activeProject];
        NSURL *file = [documentsDirectory URLByAppendingPathComponent:fileName];
        NSMutableString *string = [[NSMutableString alloc] initWithString:@"<table><tr><td>Day</td><td>Hours</td></tr>"];
        //NSString* string = @"<table><tr><td>Day</td><td>Hours</td></tr></table>";
        
        NSDictionary *projectDict = [XCModel projectDictionaryForProject:activeProject];
        NSEnumerator *dictEnum = [projectDict keyEnumerator];
        NSString *currentKey = nil;
        while (currentKey = [dictEnum nextObject])
        {
            float seconds = [[projectDict objectForKey:currentKey] floatValue];
            float hours = seconds / 3600;
            [string appendFormat:@"<tr><td>%@</td><td>%f</td>", currentKey, hours];
        }
        [string appendString:@"</table>"];
        
        // NSLog(@"string: %@ to file: %@", string, file.path);
        
        [string writeToFile:file.path atomically:YES encoding:NSUTF8StringEncoding error:nil];
        
        [[NSWorkspace sharedWorkspace] openFile:file.path];
    }
    
}


#pragma mark window control & window delegate methods

- (void)showPreferenceWindow
{
    if (self.windowController == nil) {
        XContractWindowController* wc = [[XContractWindowController alloc] initWithWindowNibName:@"XContractWindowController"];
        self.windowController = wc;
        wc.delegate = self;
    }
    
    
    if (self.windowController.preferenceWindow == nil) //kludge, if the other window hasnt been show pref window is null.
    {
        [self.windowController.window makeKeyAndOrderFront:nil];
        [self.windowController.window close];
    }
    
    [self.windowController.preferenceWindow makeKeyAndOrderFront:nil];
}

//currently unused
- (void)showWindow
{
    if (self.windowController.window.isVisible) {
        [self.windowController.window close];
        
    } else {
        if (self.windowController == nil) {
            XContractWindowController* wc = [[XContractWindowController alloc] initWithWindowNibName:@"XContractWindowController"];
            self.windowController = wc;
            wc.delegate = self;
        }
        [self.windowController.window makeKeyAndOrderFront:nil];
        
    }
}

//delegate method from when we tried to create "excel" spreadsheet from main window.
- (NSString *)currentActiveProject
{
    return self.currentTrackedProject;
}

//observe whether auto check has been chosen or not so we can invalidate or fire the timer
- (void)observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context
{
    if (object == [NSUserDefaults standardUserDefaults]) {
        if ([keyPath isEqualToString:kXContractHeartbeatTimer]) {
            
            BOOL autoCheck = [change[NSKeyValueChangeNewKey] boolValue];
            if (autoCheck == true)
            {
                NSLog(@"changed to auto check on");
                
                stillWorkingTimer = [NSTimer scheduledTimerWithTimeInterval:autoCheckInterval target:self selector:@selector(stillWorkingHeartbeat) userInfo:nil repeats:TRUE];
                
            } else {
                
                NSLog(@"changed to auto check off");
                
                [stillWorkingTimer invalidate];
                stillWorkingTimer = nil;
            }
            
        }
    }
}


- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
