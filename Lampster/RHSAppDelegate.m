//
//  RHSAppDelegate.m
//  Lampster
//
//  Created by Rasmus Sten on 2014-07-15.
//  Copyright (c) 2014 Rasmus Sten. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "RHSAppDelegate.h"
#import "DDHotKeyCenter.h"

@implementation RHSAppDelegate

- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
    return ![aTableColumn.identifier isEqualToString:@"label"];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
    if (!self.lamps) return 0;
    return self.lamps.count;
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
    return self.lamps[rowIndex][aTableColumn.identifier];
}

- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
    self.lamps[rowIndex][aTableColumn.identifier] = anObject;
    NSMutableArray* selectedBulbIds = [NSMutableArray new];
    [self.lamps enumerateObjectsUsingBlock:^(NSDictionary* lamp, NSUInteger idx, BOOL *stop) {
        if (((NSNumber*)lamp[@"enabled"]).boolValue) {
            [selectedBulbIds addObject:lamp[@"id"]];
        }
    }];
    [self.lifxClient selectBulbs:selectedBulbIds];
}

- (IBAction)toggleBulbWindow:(id)sender {
    [self.bulbWindow setAlphaValue:0.0];
    [self.bulbWindow setIsVisible:!self.bulbWindow.isVisible];
    if ([self.bulbWindow isVisible]) {
        [self fadeInWindow:self.bulbWindow];
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    DDHotKeyCenter* hkc = [DDHotKeyCenter sharedHotKeyCenter];
    [hkc registerHotKey:[DDHotKey hotKeyWithKeyCode:37 modifierFlags:NSShiftKeyMask|NSCommandKeyMask task:^(NSEvent *event) {
        NSLog(@"Got hot key event! %@", event);
        [NSApp activateIgnoringOtherApps:YES];
    }]];
    BOOL firstRun = ![[NSUserDefaults standardUserDefaults] boolForKey:@"run-once"];
    self.firstBulbDiscovered = NO;
    self.table.dataSource = self;
    self.table.delegate = self;
    self.lifxClient = [RHSLIFXClient new];
    __weak RHSAppDelegate* _self = self;
    self.lifxClient.dataHandler = ^void(NSDictionary* data) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (data[@"bulb_count"]) {
                double bulb_count = ((NSNumber*) data[@"bulb_count"]).intValue;
                if (!_self.firstBulbDiscovered && bulb_count > 0) {
                    _self.firstBulbDiscovered = YES;
                    [_self enableControls];
                    [_self fadeIn];
                }
                _self.levelIndicator.maxValue = [(NSNumber*) data[@"bulb_count"] intValue];
                [_self.levelIndicator setDoubleValue:_self.levelIndicator.maxValue];
            }
            if (data[@"lights"]) {
                NSMutableDictionary* lamps = data[@"lights"];
                NSMutableArray* lampArray = [NSMutableArray new];
                [lamps.allKeys enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    NSMutableDictionary* lamp = [NSMutableDictionary dictionaryWithDictionary:lamps[obj]];
                    lamp[@"enabled"] = @( 1 );
                    [lampArray addObject:lamp];
                }];
                 _self.lamps = lampArray;
                if (firstRun) {
                    if (!_self.bulbWindow.isVisible) [_self toggleBulbWindow:nil];
                    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"run-once"];
                }
            }
            [_self.table reloadData];
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

    [self.bulbWindow setOpaque:NO];
    [self.bulbWindow setAlphaValue:0.0];

    /* For some reason drop shadow disappears when I try to fade in the main
       window, so I'll leave it out for now */
//    [self.window setOpaque:NO];
//    [self.window setAlphaValue:0.0];
//    [self fadeInWindow:self.window];
//    [self.window setIsVisible:YES];

    [self.lifxClient waitForReady:restartingCompletionHandler];
}

- (void)fadeInWindow:(NSWindow*) window {
    NSDictionary *f = @{NSViewAnimationTargetKey : window,
                        NSViewAnimationEffectKey : NSViewAnimationFadeInEffect};
    NSViewAnimation *a = [[NSViewAnimation alloc] initWithViewAnimations:@[f]];
    a.duration = 1.0;
    a.animationBlockingMode = NSAnimationNonblocking;
    [a startAnimation];
}
- (IBAction)colorAction:(NSColorWell*)sender {
    CGFloat hue, saturation, brightness, alpha;
    [sender.color getHue:&hue saturation:&saturation brightness:&brightness alpha:&alpha];
    hue *= 360.0;
    NSLog(@"%s: %f %f %f", __func__, hue, saturation, brightness);
    [self.lifxClient setColorHue:hue saturation:saturation brightness:brightness completionHandler:^(NSError *error) {
        if (error) {
            NSLog(@"Error setting color: %@", error);
        }
    }];
}

- (void)fadeIn {
    CABasicAnimation* a = [CABasicAnimation animation];
    a.keyPath = @"opacity";
    a.fromValue = [NSNumber numberWithFloat:0];
    a.toValue = [NSNumber numberWithFloat:1];
    a.duration = 3.0;
    [@[self.levelIndicator.layer, self.onButton.layer, self.offButton.layer] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [obj addAnimation:a forKey:nil];
        [obj setOpacity:1.0];
    }];
}

- (void)enableControls {
    [self.onButton setEnabled:YES];
    [self.offButton setEnabled:YES];
}

- (void)startSpin {
    [self.spinner startAnimation:nil];
    [self.onButton setEnabled:NO];
    [self.offButton setEnabled:NO];
}

- (void)stopSpin {
    dispatch_async(dispatch_get_main_queue()
                   , ^{
                       [self enableControls];
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
