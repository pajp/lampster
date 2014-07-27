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
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
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
    time_t starttime = time(NULL);
    while (time(NULL) - starttime < 10) {
        if (handlerCalled && !error) {
            return;
        }
        NSLog(@"Waiting for completion handler…");
        usleep(100000);
    }
    XCTAssert(error == nil, @"Error happened: %@", error);
}

- (void)testBulbsOn
{
    [self invokeAndWaitForHandler:@selector(lightsOn:) onClient:self.client];
}

- (void)testBulbsOff
{
    [self invokeAndWaitForHandler:@selector(lightsOff:) onClient:self.client];
}

@end
