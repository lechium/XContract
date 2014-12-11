//
//  XContract.m
//  XContract
//
//  Created by Kevin Bradley on 12/10/14.
//  Copyright (c) 2014 Kevin Bradley. All rights reserved.
//

#import "XContract.h"

#define autoCheckInterval 3600

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
        
        NSMenuItem *menuItem = [[NSApp mainMenu] itemWithTitle:@"Product"];
        if (menuItem) {
            [[menuItem submenu] addItem:[NSMenuItem separatorItem]];
            
            NSMenuItem *xcMenuItem = [[NSMenuItem alloc] init];
            [xcMenuItem setTitle:@"XContract"];
            
            NSMenu *xcontractMenu = [[NSMenu alloc] initWithTitle:@""];
            
            
            NSMenuItem *windowMenuItem = [[NSMenuItem alloc] initWithTitle:@"Show XContract window" action:@selector(showWindow) keyEquivalent:@""];
            // [actionMenuItem setKeyEquivalentModifierMask:NSControlKeyMask];
            [windowMenuItem setTarget:self];
            
            [xcontractMenu addItem:windowMenuItem];
            NSMenuItem *startTimerItem = [[NSMenuItem alloc] initWithTitle:@"Start timer for current project" action:@selector(startTimerForProject) keyEquivalent:@""];
            //  [trelloItem setKeyEquivalentModifierMask:NSControlKeyMask];
            [startTimerItem setTarget:self];
            [xcontractMenu addItem:startTimerItem];
            NSMenuItem *stopTimerItem = [[NSMenuItem alloc] initWithTitle:@"Stop timer for current project" action:@selector(stopTimerForProject) keyEquivalent:@""];
            [stopTimerItem setTarget:self];
            [xcontractMenu addItem:stopTimerItem];
            
            NSMenuItem *showPreferencesWindowItem = [[NSMenuItem alloc] initWithTitle:@"Preferences..." action:@selector(showPreferenceWindow) keyEquivalent:@""];
            [showPreferencesWindowItem setTarget:self];
            [xcontractMenu addItem:showPreferencesWindowItem];
            
            [xcMenuItem setSubmenu:xcontractMenu];
            [[menuItem submenu] addItem:xcMenuItem];
        }
    }
    
    NSUserDefaults* prefs = [NSUserDefaults standardUserDefaults];
    
    [prefs addObserver:self
            forKeyPath:kXContractHeartbeatTimer
               options:NSKeyValueObservingOptionNew
               context:NULL];
    return self;
}

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

+ (void)bringAppToFront:(NSString *)appID
{
    NSRunningApplication *theApp = [[NSRunningApplication runningApplicationsWithBundleIdentifier:appID] lastObject];
    if (theApp != nil)
    {
        [theApp activateWithOptions:NSApplicationActivateAllWindows];
    }
}


- (void)bringXcodeToFront
{
    [[NSApplication sharedApplication] activateIgnoringOtherApps:TRUE];
}

- (void)stillWorkingHeartbeat
{
    LOG_SELF;
    heartBeatAlert = [NSAlert alertWithMessageText:@"Still working?" defaultButton:@"Yes" alternateButton:@"No" otherButton:nil informativeTextWithFormat:@"Are you still working on the project: %@?\n\nAuto dismissed choosing 'No' in 20 seconds...\n", self.currentTrackedProject];
    [heartBeatAlert setAlertStyle: NSInformationalAlertStyle];
    [self bringXcodeToFront];
    NSTimer *myTimer = [NSTimer timerWithTimeInterval: 20 target:self selector: @selector(killWindow:) userInfo:nil repeats:NO];
    autoDismissTime = 20;
    [[NSRunLoop currentRunLoop] addTimer:myTimer forMode:NSModalPanelRunLoopMode];
    NSTimer *updateCountdownTimer = [NSTimer timerWithTimeInterval: 1 target:self selector: @selector(updateStillWorkingTimer) userInfo:nil repeats:TRUE];
    [[NSRunLoop currentRunLoop] addTimer:updateCountdownTimer forMode:NSModalPanelRunLoopMode];
    NSModalResponse modalResp = [heartBeatAlert runModal];
    
    switch (modalResp) {
        case NSAlertAlternateReturn:
            
            [self stopTimerForProject];
            [myTimer invalidate];
              [updateCountdownTimer invalidate];
            break;
          
        default:
            
            [myTimer invalidate];
            [updateCountdownTimer invalidate];
            break;
    }
}

- (void)updateStillWorkingTimer
{
    autoDismissTime--;
    NSString *informativeText = [NSString stringWithFormat:@"Are you still working on the project: %@?\n\nAuto dismissed choosing 'No' in %li seconds...\n", self.currentTrackedProject, (long)autoDismissTime];
    [heartBeatAlert setInformativeText:informativeText];
}

-(void)killWindow:(NSTimer *)theTimer
{
    LOG_SELF;

    [[NSApplication sharedApplication] stopModalWithCode:NSAlertAlternateReturn];
}

- (void)startTimerForProject
{
    LOG_SELF;
    if (self.currentTrackedProject != nil)
    {
        NSAlert *alreadyTrackingProject = [NSAlert alertWithMessageText:@"Timer Active" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Currently only one project can be tracked at a time."];
        
        [alreadyTrackingProject runModal];
        return;
    }
    
    self.currentTrackedProject = [XCModel currentProjectName];
    if (self.currentTrackedProject.length == 0)
    {
        if ([self setManualProjectName] == FALSE)
        {
            NSAlert *noNameAlert = [NSAlert alertWithMessageText:@"No project name detected!" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Still no name chosen (blank entry) aborting start timer."];
            [noNameAlert runModal];
            return;
        }
        
    }
    //if we got this far we should have a project name, now check the contract plist for any details on this project
    self.priorElapsedTime = [XCModel currentTimeFromProjectName:self.currentTrackedProject];
    self.startDate = [NSDate date];
    NSLog(@"### starting timer for project name: %@ start date: %@ prior time: %li", self.currentTrackedProject, self.startDate, self.priorElapsedTime);
    autoSaveTimer = [NSTimer scheduledTimerWithTimeInterval:1800 target:self selector:@selector(autoSaveTimer) userInfo:nil repeats:TRUE];
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kXContractHeartbeatTimer] == TRUE)
    {
        stillWorkingTimer = [NSTimer scheduledTimerWithTimeInterval:autoCheckInterval target:self selector:@selector(stillWorkingHeartbeat) userInfo:nil repeats:TRUE];
    }
    
    
}

- (void)observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context
{
    if (object == [NSUserDefaults standardUserDefaults]) {
        if ([keyPath isEqualToString:kXContractHeartbeatTimer]) {
            
            NSLog(@"change: %@", change);
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

- (void)autoSaveTimer
{
    LOG_SELF;
    NSTimeInterval elapsedTimeSinceStart = [[NSDate date] timeIntervalSinceDate:self.startDate];
    NSInteger totalElapsedTimeForDate = self.priorElapsedTime + elapsedTimeSinceStart;
    
    NSLog(@"### auto saving timer for project name: %@ start date: %@ new elapsed time: %li", self.currentTrackedProject, self.startDate, totalElapsedTimeForDate);
    
    [XCModel updateTime:totalElapsedTimeForDate forProject:self.currentTrackedProject];
    self.priorElapsedTime = totalElapsedTimeForDate;
    self.startDate = [NSDate date];
}

- (void)stopTimerForProject
{
    NSTimeInterval elapsedTimeSinceStart = [[NSDate date] timeIntervalSinceDate:self.startDate];
    NSInteger totalElapsedTimeForDate = self.priorElapsedTime + elapsedTimeSinceStart;
    
    NSLog(@"### stopping timer for project name: %@ start date: %@ new elapsed time: %li", self.currentTrackedProject, self.startDate, totalElapsedTimeForDate);
    
    [XCModel updateTime:totalElapsedTimeForDate forProject:self.currentTrackedProject];
    self.currentTrackedProject = nil;
    self.startDate = nil;
    self.priorElapsedTime = 0;
    [autoSaveTimer invalidate];
    autoSaveTimer = nil;
    [stillWorkingTimer invalidate];
    stillWorkingTimer = nil;
}

- (void)showPreferenceWindow
{
    if (self.windowController == nil) {
        XContractWindowController* wc = [[XContractWindowController alloc] initWithWindowNibName:@"XContractWindowController"];
        self.windowController = wc;
        wc.delegate = self;
    }
    
    NSLog(@"pref window: %@", self.windowController.preferenceWindow);
    
    if (self.windowController.preferenceWindow == nil)
    {
        [self.windowController.window makeKeyAndOrderFront:nil];
        [self.windowController.window close];
    }
    
    [self.windowController.preferenceWindow makeKeyAndOrderFront:nil];
}

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


- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
