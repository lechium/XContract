//
//  XContract.m
//  XContract
//
//  Created by Kevin Bradley on 12/10/14.
//  Copyright (c) 2014 Kevin Bradley. All rights reserved.
//

#import "XContract.h"

static XContract *sharedPlugin;

@interface XContract()

@property (nonatomic, strong) XContractWindowController* windowController;
@property (nonatomic, strong, readwrite) NSBundle *bundle;
@end

@implementation XContract

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
            
            [xcMenuItem setSubmenu:xcontractMenu];
            [[menuItem submenu] addItem:xcMenuItem];
        }
    }
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
        case 0: //ok
            self.currentTrackedProject = manualProjectNameField.stringValue;
            if (self.currentTrackedProject.length == 0)
                return FALSE;
            else
                return TRUE;
            
        case -1: //cancel
            return FALSE;
    }
    
    return FALSE;
}

- (void)startTimerForProject
{
    if (self.currentTrackedProject != nil)
    {
        NSAlert *alreadyTrackingProject = [NSAlert alertWithMessageText:@"Timer Active" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Currently only one project can be tracked at a time."];
        
        [alreadyTrackingProject runModal];
        return;
    }
    
    self.currentTrackedProject = [XCModel currentProjectName];
    if (self.currentTrackedProject.length == 0)
    {
        BOOL projectNameSet = [self setManualProjectName];
        if (projectNameSet == FALSE)
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
