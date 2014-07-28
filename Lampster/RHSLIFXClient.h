//
//  RHSLIFXClient.h
//  Lampster
//
//  Created by Rasmus Sten on 2014-07-15.
//  Copyright (c) 2014 Rasmus Sten. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RHSLIFXClient : NSObject
{
    NSTask* rubyclient;
    NSPipe* clientinput;
    NSString* lastCommand;
    NSString* lastExpect;
    void (^lastCompletionHandler)(NSError*);
    dispatch_queue_t lifxqueue;
}
@property (retain) NSDictionary* lastData;
@property (nonatomic, copy) void (^errorHandler)(NSError*);
@property (nonatomic, copy) void (^dataHandler)(NSDictionary*);
-(id) initWithErrorHandler:(void (^)(NSError*)) errorHandler;
-(void) lightsStatus:(void (^)(NSError*, NSArray*)) completionHandler;
-(void) lightsOn:(void (^)(NSError*)) completionHandler;
-(void) lightsOff:(void (^)(NSError*)) completionHandler;
-(void) waitForReady:(void (^)(NSError*)) completionHandler;
-(void) selectBulbs:(NSArray*) bulbs;
@end
