//
//  RHSLIFXClientTest.m
//  Lampster
//
//  Created by Rasmus Sten on 2014-07-26.
//  Copyright (c) 2014 Rasmus Sten. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "RHSLIFXClient.h"
#import "RHSAppDelegate.h"

@interface RHSLIFXClientTest : XCTestCase
@property (retain) RHSLIFXClient* client;
@end

@implementation RHSLIFXClientTest

- (void)setUp
{
    [super setUp];
//    NSApplication* myApp = [NSApplication sharedApplication];
//    RHSAppDelegate* d = (RHSAppDelegate*) [myApp delegate];
//    self.client = d.lifxClient;
    self.client = [[RHSLIFXClient alloc] initWithErrorHandler:^(NSError *error) {
        //NSLog(@"ERROR: %@", error);
        XCTFail(@"LIFX client error %@", error);
    }];
    NSColor* white = [[NSColor whiteColor] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];
    [self.client setColor:white completionHandler:nil];
    [self.client lightsOn:nil];
}

- (void)tearDown
{
    NSColor* white = [[NSColor whiteColor] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];
    [self.client setColor:white completionHandler:nil];
    [super tearDown];
}

- (void)testWaitForReady
{
    [self invokeAndWaitForHandler:@selector(waitForReady:) onClient:self.client];
}

- (void)invokeAndWaitForHandler:(SEL) selector onClient:(RHSLIFXClient*) client
{
    __block NSError* error = nil;
    __block BOOL handlerCalled = NO;
    void (^handler)(NSError*) = ^void(NSError* _error) {
        handlerCalled = YES;
        XCTAssert(_error == nil, @"Error happened: %@", _error);
        error = _error;
    };
    ((void (*)(id, SEL, id))[client methodForSelector:selector])(client, selector, handler);

    [self waitFor:^BOOL { return handlerCalled; } seconds:10];
    XCTAssert(error == nil, @"Error happened: %@", error);
}

- (NSArray*)invokeAndWaitForArrayHandler:(SEL) selector onClient:(RHSLIFXClient*) client
{
    __block NSError* error = nil;
    __block NSArray* array = nil;
    __block BOOL handlerCalled = NO;
    void (^handler)(NSError*,NSArray*) = ^void(NSError* _error, NSArray* _array) {
        handlerCalled = YES;
        XCTAssert(_error == nil, @"Error happened: %@", _error);
        error = _error;
        array = _array;
    };
    ((void (*)(id, SEL, id))[client methodForSelector:selector])(client, selector, handler);
    [self waitFor:^BOOL { return handlerCalled; } seconds:10];
    XCTAssert(error == nil, @"Error happened: %@", error);
    XCTAssert(array != nil, @"Returned nil array: %@", error);
    return array;
}

- (BOOL) waitFor:(BOOL (^)())block seconds:(NSTimeInterval)timeout
{
    time_t starttime = time(NULL);
    while (time(NULL) - starttime < timeout) {
        if (block()) {
            return YES;
        }
        usleep(100000);
    }
    return NO;
}
#define ON_STATE YES
#define OFF_STATE NO
- (BOOL)allBulbsAtState:(BOOL)desiredStateIsOn
{
    NSArray* lights = [self invokeAndWaitForArrayHandler:@selector(lightsStatus:) onClient:self.client];
    __block BOOL allLightsAtState = YES;
    [lights enumerateObjectsUsingBlock:^(NSDictionary* obj, NSUInteger idx, BOOL *stop) {
        if ([obj[@"power"] isEqualToString:desiredStateIsOn ? @"off": @"on"]) {
            allLightsAtState= NO;
        }
    }];
    return allLightsAtState;
}

- (void)testBulbHue
{
    [self invokeAndWaitForHandler:@selector(lightsOn:) onClient:self.client];
    XCTAssert([self waitFor:^BOOL{
        return [self allBulbsAtState:ON_STATE];
    } seconds:5], @"Not all lights on");

    for (CGFloat n = 0.0; n <= 7; n++) {
        __block BOOL handlerCalled = NO;
        CGFloat hue = 45.0 * n;
        [self.client setColorHue:hue saturation:1.0 brightness:1.0 completionHandler:^(NSError *error) {
            handlerCalled = YES;
           // XCTAssertNotNil(error, @"There was an error setting color: %@", error);
        }];
        XCTAssertTrue([self waitFor:^BOOL{
            return handlerCalled;
        } seconds:10], @"Timeout waiting for setCololorHue… command to return");

        BOOL success = [self waitFor:^BOOL{
            BOOL bulbsAtTarget = YES;
            NSArray* array = [self invokeAndWaitForArrayHandler:@selector(lightsStatus:) onClient:self.client];
            XCTAssertTrue(array != nil, @"Lights-status return nil array");
            XCTAssertTrue(array.count > 0, @"Lights-status array is empty");
            for (NSDictionary* light in array) {
                CGFloat currentHue = ((NSNumber*)light[@"hue"]).doubleValue;
                if (round(currentHue) != hue) {
                    bulbsAtTarget = NO;
                    NSLog(@"Bulb %@ is not yet at target (current: %f, target: %f)", light[@"id"], currentHue, hue);
                }
            }
            return bulbsAtTarget;
        } seconds:10];
        XCTAssert(success, @"All bulbs not at target hue (%f) after 10 seconds", hue);
    }
}

- (void)testBulbsOn
{
    [self invokeAndWaitForHandler:@selector(lightsOn:) onClient:self.client];
    XCTAssert([self waitFor:^BOOL{
        return [self allBulbsAtState:ON_STATE];
    } seconds:5], @"Not all lights on");
}

- (void)testBulbsOff
{
    [self invokeAndWaitForHandler:@selector(lightsOff:) onClient:self.client];
    XCTAssert([self waitFor:^BOOL{
        return [self allBulbsAtState:OFF_STATE];
    } seconds:5], @"Not all lights off");
}

@end
