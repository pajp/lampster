//
//  RHSAppDelegate.m
//  Lampster
//
//  Created by Rasmus Sten on 2014-07-15.
//  Copyright (c) 2014 Rasmus Sten. All rights reserved.
//

#import "RHSAppDelegate.h"

@implementation RHSAppDelegate

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
    if (!self.lamps) return 0;
    return self.lamps.count;
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
    return self.lamps[rowIndex][aTableColumn.identifier];
}

- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
    self.lamps[rowIndex][aTableColumn.identifier] = anObject;
    NSMutableString* idListString = [NSMutableString stringWithString:@"select-bulbs"];
    [self.lamps enumerateObjectsUsingBlock:^(NSDictionary* lamp, NSUInteger idx, BOOL *stop) {
        if (((NSNumber*)lamp[@"enabled"]).boolValue) {
            [idListString appendString:@" "];
            [idListString appendString:lamp[@"id"]];
        }
    }];
    [self.lifxClient send:idListString andExpect:@"OK"];
}

- (IBAction)toggleBulbWindow:(id)sender {
    [self.bulbWindow setIsVisible:!self.bulbWindow.isVisible];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    DDHotKeyCenter* hkc = [DDHotKeyCenter sharedHotKeyCenter];
    [hkc registerHotKey:[DDHotKey hotKeyWithKeyCode:37 modifierFlags:NSShiftKeyMask|NSCommandKeyMask task:^(NSEvent *event) {
        NSLog(@"Got hot key event! %@", event);
        [NSApp activateIgnoringOtherApps:YES];
    }]];
    self.table.dataSource = self;
    self.lifxClient = [RHSLIFXClient new];
    __weak RHSAppDelegate* _self = self;
    self.lifxClient.dataHandler = ^void(NSDictionary* data) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (data[@"bulb_count"]) {
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
