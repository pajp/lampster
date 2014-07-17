//
//  RHSAppDelegate.h
//  Lampster
//
//  Created by Rasmus Sten on 2014-07-15.
//  Copyright (c) 2014 Rasmus Sten. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "RHSLIFXClient.h"
#import "DDHotKeyCenter.h"
@interface RHSAppDelegate : NSObject <NSApplicationDelegate, NSTableViewDataSource>
@property (weak) IBOutlet NSButton *onButton;
@property (weak) IBOutlet NSButton *offButton;
@property (retain) NSArray* lamps;
@property (assign) IBOutlet NSWindow *window;
@property (retain) RHSLIFXClient* lifxClient;
@property (weak) IBOutlet NSProgressIndicator *spinner;
@property (weak) IBOutlet NSLevelIndicator *levelIndicator;
@property (weak) IBOutlet NSTableView *table;
@property (unsafe_unretained) IBOutlet NSPanel *bulbWindow;
@end
