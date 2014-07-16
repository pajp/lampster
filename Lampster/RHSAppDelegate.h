//
//  RHSAppDelegate.h
//  Lampster
//
//  Created by Rasmus Sten on 2014-07-15.
//  Copyright (c) 2014 Rasmus Sten. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "RHSLIFXClient.h"

@interface RHSAppDelegate : NSObject <NSApplicationDelegate>
@property (weak) IBOutlet NSButton *onButton;
@property (weak) IBOutlet NSButton *offButton;

@property (assign) IBOutlet NSWindow *window;
@property (retain) RHSLIFXClient* lifxClient;
@property (weak) IBOutlet NSProgressIndicator *spinner;
@property (weak) IBOutlet NSLevelIndicator *levelIndicator;
@end
