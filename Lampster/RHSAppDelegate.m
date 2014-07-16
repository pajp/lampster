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
    __weak RHSAppDelegate* _self = self;
    self.lifxClient.dataHandler = ^void(NSDictionary* data) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (data[@"bulb_count"]) {
                _self.levelIndicator.maxValue = [(NSNumber*) data[@"bulb_count"] intValue];
                [_self.levelIndicator setDoubleValue:_self.levelIndicator.maxValue];
            }
            if (data[@"toggle_count"]) {
                [_self.levelIndicator setDoubleValue:[(NSNumber*) data[@"toggle_count"] doubleValue]];
            }
        });
    };
    [self startSpin];
    void (^restartingCompletionHandler)(NSError*) = ^void(NSError* error) {
        if (!error) {
            [self stopSpin];
            dispatch_async(dispatch_get_main_queue(), ^{
            });
        } else {
            NSLog(@"Error waiting for LIFX readiness: %@", error);
            [self.lifxClient waitForReady:restartingCompletionHandler];
        }
        
    };
    [self.lifxClient waitForReady:restartingCompletionHandler];
}

- (void)startSpin {
    [self.spinner startAnimation:nil];
    [self.onButton setEnabled:NO];
    [self.offButton setEnabled:NO];
}

- (void)stopSpin {
    dispatch_async(dispatch_get_main_queue()
                   , ^{
                       [self.onButton setEnabled:YES];
                       [self.offButton setEnabled:YES];
                       [self.spinner stopAnimation:nil];
                   });
}

- (IBAction)lightsOn:(id)sender {
    [self startSpin];
    [self.levelIndicator setDoubleValue:0.0];
    [self.lifxClient lightsOn:^(NSError *error) {
        [self stopSpin];
    }];
}

- (IBAction)lightsOff:(id)sender {
    [self startSpin];
    [self.levelIndicator setDoubleValue:0.0];
    [self.lifxClient lightsOff:^(NSError *error) {
        [self stopSpin];
    }];
}

@end
