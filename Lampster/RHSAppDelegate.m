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
    if ([aTableColumn.identifier isEqualToString:@"power"]) {
            [self.lifxClient lightSet:self.lamps[rowIndex][@"id"] toState:((NSNumber*) anObject).boolValue completionHandler:^(NSError *error) {
                if (!error) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        self.lamps[rowIndex][aTableColumn.identifier] = anObject;
                        [aTableView reloadData];
                    });
                } else {
                    NSLog(@"An error occurred trying to set lamp status: %@", error);
                }
            }];
    }
}

- (BOOL) applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag {
    [self.bulbWindow setIsVisible:YES];
    return YES;
}

- (IBAction)toggleBulbWindow:(id)sender {
    [self.bulbWindow setIsVisible:!self.bulbWindow.isVisible];
}

- (IBAction)toggleBulkWindow:(id)sender {
    [self.window setIsVisible:!self.window.isVisible];
}

- (void) toggleLampFromDockMenu:(NSMenuItem*) sender {
    NSLog(@"hullo %@", sender);
    NSDictionary* lamp = sender.representedObject;
    BOOL newState = [lamp[@"power"] isEqualTo:@( 1 )] ? 0 : 1;
    [self.lifxClient lightSet:lamp[@"id"] toState:newState completionHandler:^(NSError *error) {
        if (error) {
            NSLog(@"Error toggling lamp: %@", error);
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self updateLampStatus];
        });
    }];
}

- (NSMenu*) applicationDockMenu:(NSApplication *)sender {
    NSMenu* dockMenu = [NSMenu new];
    [self.lamps enumerateObjectsUsingBlock:^(NSDictionary* obj, NSUInteger idx, BOOL *stop) {
        NSMenuItem* item = [NSMenuItem new];
        item.title = [NSString stringWithFormat:@"%@ %@", obj[@"label"], [obj[@"power"] isEqualTo:@(1)] ? @"💡" : @""];
        [item setEnabled:YES];
        [item setRepresentedObject:obj];
        [item setAction:@selector(toggleLampFromDockMenu:)];
        [dockMenu addItem:item];
    }];
    NSMenuItem* separator = [NSMenuItem separatorItem];
    [dockMenu addItem:separator];
    NSMenuItem* item = [NSMenuItem new];
    item.title = @"Refresh bulbs";
    [item setEnabled:YES];
    item.action = @selector(updateLampStatus);
    [dockMenu addItem:item];
    return dockMenu;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    DDHotKeyCenter* hkc = [DDHotKeyCenter sharedHotKeyCenter];
    [hkc registerHotKey:[DDHotKey hotKeyWithKeyCode:37 modifierFlags:NSShiftKeyMask|NSCommandKeyMask task:^(NSEvent *event) {
        NSLog(@"Got hot key event! %@", event);
        [NSApp activateIgnoringOtherApps:YES];
        [self.bulbWindow setIsVisible:YES];
    }]];
    BOOL firstRun = ![[NSUserDefaults standardUserDefaults] boolForKey:@"run-once"];
    self.firstBulbDiscovered = NO;
    self.table.dataSource = self;
    self.table.delegate = self;
    self.lifxClient = [RHSLIFXClient new];
    __weak RHSAppDelegate* _self = self;
    self.lifxClient.dataHandler = ^void(NSDictionary* data) {
        NSLog(@"Received data object: %@", data);
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
                    [lampArray addObject:lamp];
                }];
                 _self.lamps = lampArray;
                [_self updateLampStatus:YES];
                if (firstRun) {
                    if (!_self.bulbWindow.isVisible) [_self toggleBulkWindow:nil];
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
                self.bulbWindow.title = @"LIFX bulbs";
            });
        } else {
            NSLog(@"Error waiting for LIFX readiness: %@", error);
            [self.lifxClient waitForReady:restartingCompletionHandler];
        }
        
    };

    [self.bulbWindow setOpaque:NO];
    [self.bulbWindow setAlphaValue:0.9];

    /* For some reason drop shadow disappears when I try to fade in the main
       window, so I'll leave it out for now */
//    [self.window setOpaque:NO];
//    [self.window setAlphaValue:0.0];
//    [self fadeInWindow:self.window];
//    [self.window setIsVisible:YES];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self.lifxClient waitForReady:restartingCompletionHandler];
    });
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
    NSColor* normalizedColor = [sender.color colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];
    [self.lifxClient setColor:normalizedColor completionHandler:^(NSError *error) {
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

- (void)updateLampStatus {
    [self updateLampStatus:NO];
}

- (void)updateLampStatus:(BOOL) refreshed {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.bulbWindow.title = @"Updating bulb status…";
    });
    [self.lifxClient lightsStatus:^(NSError *error, NSArray *lights) {
        if (error) {
            NSLog(@"Error getting bulb status: %@", error);
            return;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            self.bulbWindow.title = @"LIFX bulbs";
            [self.lamps enumerateObjectsUsingBlock:^(NSMutableDictionary* lampsObj, NSUInteger idx, BOOL *stop) {
                [lights enumerateObjectsUsingBlock:^(NSDictionary* statusObj, NSUInteger idx, BOOL *stop) {
                    if ([lampsObj[@"id"] isEqualToString:statusObj[@"id"]]) {
                        [lampsObj addEntriesFromDictionary:statusObj];
                    }
                }];
                lampsObj[@"power"] = [lampsObj[@"power"] isEqualToString:@"on"] ? @( 1 ) : @( 0 );
                NSLog(@"Lamp %@ power: %@", lampsObj[@"id"], lampsObj[@"power"]);
            }];
            [self.table reloadData];
            if (!refreshed) {
                /* It seems we often (always?) need several refresh request before power state is actually
                 * update. Schedule 3, one second apart.
                 */
                for (int seconds = 1; seconds <= 3; seconds++) {
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(seconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        [self updateLampStatus:YES];
                    });
                }
            }
            
        });
    }];
}

- (IBAction)lightsOn:(id)sender {
    [self startSpin];
    [self.levelIndicator setDoubleValue:0.0];
    [self.lifxClient lightsOn:^(NSError *error) {
        [self stopSpin];
        [self updateLampStatus];
    }];
}

- (IBAction)lightsOff:(id)sender {
    [self startSpin];
    [self.levelIndicator setDoubleValue:0.0];
    [self.lifxClient lightsOff:^(NSError *error) {
        [self stopSpin];
        [self updateLampStatus];
    }];
}

@end
