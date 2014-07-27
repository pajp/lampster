//
//  LampsterTests.m
//  LampsterTests
//
//  Created by Rasmus Sten on 2014-07-15.
//  Copyright (c) 2014 Rasmus Sten. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "RHSAppDelegate.h"

@interface LampsterTests : XCTestCase

@end

@implementation LampsterTests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testLightsOn
{
    NSApplication* myApp = [NSApplication sharedApplication];
    RHSAppDelegate* d = (RHSAppDelegate*) [myApp delegate];
    [d lightsOn:nil];
    // TODO: check that lights were turned on
}

@end
