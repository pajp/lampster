//
//  RHSAppDelegate.m
//  Lampster
//
//  Created by Rasmus Sten on 2014-07-15.
//  Copyright (c) 2014 Rasmus Sten. All rights reserved.
//

#import "RHSAppDelegate.h"

@implementation RHSAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    self.lifxClient = [RHSLIFXClient new];
    [self spinUntilOK];
}

- (void)spinUntilOK {
    [self.spinner startAnimation:nil];
    [self.onButton setEnabled:NO];
    [self.offButton setEnabled:NO];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self.lifxClient waitForOK];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.onButton setEnabled:YES];
            [self.offButton setEnabled:YES];
            [self.spinner stopAnimation:nil];
        });
    });
}

- (IBAction)lightsOn:(id)sender {
    [self.lifxClient lightsOn];
    [self spinUntilOK];
}

- (IBAction)lightsOff:(id)sender {
    [self.lifxClient lightsOff];
    [self spinUntilOK];
}

@end
