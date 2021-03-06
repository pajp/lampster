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
    NSPipe* clientinput;
    NSString* lastCommand;
    NSString* lastExpect;
    void (^lastCompletionHandler)(NSError*);
    dispatch_queue_t lifxqueue;
}
@property NSTask* rubyclient;
@property (retain) NSDictionary* lastData;
@property (nonatomic, copy) void (^errorHandler)(NSError*);
@property (nonatomic, copy) void (^dataHandler)(NSDictionary*);
@property (copy) void (^waitStateChangeHandler)(BOOL);
-(void) setColor:(NSColor*) color forBulbID:(NSString*) bulbId completionHandler:(void (^)(NSError*)) completionHandler;
-(void) setColor:(NSColor*) color completionHandler:(void (^)(NSError*)) completionHandler;
-(void) setColorHue:(CGFloat)hue saturation:(CGFloat)saturation brightness:(CGFloat)brightness completionHandler:(void (^)(NSError*)) completionHandler;
-(id) initWithErrorHandler:(void (^)(NSError*)) errorHandler;
-(void) lightSet:(NSString*) lampId toState:(BOOL) state completionHandler:(void (^)(NSError*)) completionHandler;
-(void) lightsStatus:(void (^)(NSError*, NSArray*)) completionHandler;
-(void) lightsOn:(void (^)(NSError*)) completionHandler;
-(void) lightsOff:(void (^)(NSError*)) completionHandler;
-(void) waitForReady:(void (^)(NSError*)) completionHandler;
-(void) selectBulbs:(NSArray*) bulbs;
@end
