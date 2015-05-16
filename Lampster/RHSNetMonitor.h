//
//  RHSNetMonitor.h
//  Lampster
//
//  Created by Rasmus Sten on 17-05-2015.
//  Copyright (c) 2015 Rasmus Sten. All rights reserved.
//

#import <Foundation/Foundation.h>
@import SystemConfiguration;

@interface RHSNetMonitor : NSObject
-(id) initWithHandler:(void (^)(NSArray*))handler;
@property (nonatomic, copy) void (^handler)(NSArray*);
@property SCDynamicStoreRef dynamicStore;
@end
