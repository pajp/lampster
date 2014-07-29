//
//  RHSLIFXClient.m
//  Lampster
//
//  Created by Rasmus Sten on 2014-07-15.
//  Copyright (c) 2014 Rasmus Sten. All rights reserved.
//

#import "RHSLIFXClient.h"

@implementation RHSLIFXClient

-(id) init {
    return [self initWithErrorHandler:nil];
}


-(void) setupLifxHelper {
//    if (reader) {
//        [reader setFileHandle:[NSFileHandle fileHandleWithNullDevice]];
//    }
    rubyclient = [[NSTask alloc] init];
    NSString* launchPath = [[NSBundle bundleForClass:self.class] pathForResource:@"lifxclient" ofType:@"rb"];
    NSLog(@"Ruby client launch path: %@", launchPath);
    rubyclient.launchPath = launchPath;
    [rubyclient setEnvironment:@{@"GEM_HOME" : [[NSBundle bundleForClass:self.class] pathForResource:@"gems" ofType:@""]}];
    rubyclient.standardInput = clientinput = [NSPipe pipe];
    NSPipe* stdout = [NSPipe pipe];
    NSPipe* stderr = [NSPipe pipe];
    rubyclient.standardOutput = stdout;
    rubyclient.standardError = stderr;
    [rubyclient launch];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        NSData* stderrData = [[stderr fileHandleForReading] readDataToEndOfFile];
        if (stderrData.length > 0) {
            NSString* clientError = [[NSString alloc] initWithData:stderrData encoding:NSUTF8StringEncoding];
            NSLog(@"LIFX client error: %@", clientError);
            if (!self.errorHandler) return;
            
            self.errorHandler([[NSError alloc] initWithDomain:@"nu.dll.lifxclient" code:1 userInfo:@{NSLocalizedDescriptionKey:clientError}]);
        }
    });
}

-(id) initWithErrorHandler:(void (^)(NSError*)) errorHandler {
    if (self) {
        lastCommand = nil;
        lastExpect = nil;
        lastCompletionHandler = nil;
        lifxqueue = dispatch_queue_create("lifx-command-queue", DISPATCH_QUEUE_SERIAL);
        if (errorHandler) {
            self.errorHandler = errorHandler;
        } else {
            __weak RHSLIFXClient* _self = self; // need weak ref to prevent retain cycle
            self.errorHandler = ^void(NSError* error) {
                NSLog(@"Helper failure: %@", error);
                [_self setupLifxHelper];
                [_self resendLastCommand];
            };
        }
        [self setupLifxHelper];
    }
    return [super init];
}

-(void) resendLastCommand {
    if (lastCommand) {
        NSLog(@"Resending %@ expecting %@, completing with %@", lastCommand,
              lastExpect, lastCompletionHandler);
        [self send:lastCommand andExpect:lastExpect completionHandler:lastCompletionHandler];
    } else {
        NSLog(@"%s: No last command to resend", __func__);
    }

}

-(void) waitForReady:(void (^)(NSError*)) completionHandler {
    [self waitFor:@"Ready." completionHandler:completionHandler];
}

-(void) waitFor:(NSString*) escape completionHandler:(void (^)(NSError*)) completionHandler {
    dispatch_async(lifxqueue, ^{
        NSError* error = nil;
        if (![self waitFor:escape]) {
            error = [NSError errorWithDomain:@"nu.dll.lifxclient" code:2 userInfo:@{ NSLocalizedDescriptionKey : [NSString stringWithFormat:@"Gave up waiting for \"%@\" reply", escape ]}];
        }
        if (completionHandler) completionHandler(error);
    });
}

-(void) scanData:(NSString*) jsonData {
    NSError* error = nil;
    NSDictionary* dict = [NSJSONSerialization JSONObjectWithData:[jsonData dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&error];
    if (!error) {
        self.lastData = dict;
        if (self.dataHandler) {
            self.dataHandler(dict);
        }
    } else {
        NSLog(@"JSON parse error: %@", error);
    }
}

- (void) readClientLinesUsingBlock:(void(^)(NSString*, BOOL*))block {
    int fd = ((NSPipe*) rubyclient.standardOutput).fileHandleForReading.fileDescriptor;
    uint8_t byte;
    size_t readcount = 0;
    BOOL stop = NO;
    NSMutableData* buffer = [NSMutableData data];
    while (!stop && (readcount = read(fd, &byte, 1)) != -1) {
        if (readcount != 1) {
            NSLog(@"Error: read %zu bytes instead of 1", readcount);
            return;
        }
        [buffer appendBytes:&byte length:1];
        if (byte == '\n') {
            NSString* row = [[NSString alloc] initWithData:buffer encoding:NSUTF8StringEncoding];
            buffer = [NSMutableData data];
            block(row, &stop);
        }
    }
    if (readcount == -1) {
        NSLog(@"read() error: errno=%d", errno);
    }
}

-(BOOL) waitFor:(NSString*) escape {
    __block BOOL found = NO;
    [self readClientLinesUsingBlock:^(NSString *str, BOOL *stop) {
        NSString* line = [str stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
        if ([line hasPrefix:@": "]) {
            [self scanData:[line substringFromIndex:2]];
        }
        if ([escape isEqualToString:line]) {
            *stop = YES;
            found = YES;
            NSLog(@"! %@", escape);
        } else {
            NSLog(@"… %@", line);
        }
    }];
    return found;
}

-(void) send:(NSString*) command andExpect:(NSString*) reply completionHandler:(void (^)(NSError*)) completionHandler {
    dispatch_async(lifxqueue, ^{
        lastCommand = command;
        lastExpect = reply;
        lastCompletionHandler = completionHandler;
        if ([self send:command andExpect:reply]) {
            lastCommand = nil;
            lastExpect = nil;
            lastCompletionHandler = nil;
            if (completionHandler) completionHandler(nil);
        }
    });
}

-(BOOL) send:(NSString*) command andExpect:(NSString*) reply {
    NSLog(@"-> sending \"%@\"", command);
    [clientinput.fileHandleForWriting writeData:[[NSString stringWithFormat:@"%@\n", command] dataUsingEncoding:NSUTF8StringEncoding]];
    return [self waitFor:reply];
}

-(void) send:(NSString*) command {
    [clientinput.fileHandleForWriting writeData:[[NSString stringWithFormat:@"%@\n", command] dataUsingEncoding:NSUTF8StringEncoding]];
}
-(void) setColor:(NSColor*) color completionHandler:(void (^)(NSError*)) completionHandler {
    CGFloat hue, saturation, brightness, alpha;
    [color getHue:&hue saturation:&saturation brightness:&brightness alpha:&alpha];
    hue *= 360.0;

    [self setColorHue:hue saturation:saturation brightness:brightness completionHandler:completionHandler];
}

-(void) setColorHue:(CGFloat)hue saturation:(CGFloat)saturation brightness:(CGFloat)brightness completionHandler:(void (^)(NSError*)) completionHandler {
    [self send:[NSString stringWithFormat:@"set-color %f %f %f", hue, saturation, brightness] andExpect:@"OK" completionHandler:completionHandler];
}

-(void) lightsStatus:(void (^)(NSError*, NSArray*)) completionHandler {
    [self send:@"lights-status" andExpect:@"OK" completionHandler:^(NSError *error) {
        if (error) {
            completionHandler(error, nil);
        } else {
            completionHandler(nil, self.lastData[@"lights-status"]);
        }
    }];
}

-(void) lightsOn:(void (^)(NSError*)) completionHandler {
    [self send:@"lights-on" andExpect:@"OK" completionHandler:completionHandler];
}

-(void) lightsOff:(void (^)(NSError*)) completionHandler {
    [self send:@"lights-off" andExpect:@"OK" completionHandler:completionHandler];
}

-(void) selectBulbs:(NSArray*) bulbs {
    dispatch_async(lifxqueue, ^{
        NSString* command = [NSString stringWithFormat:@"select-bulbs %@", [bulbs componentsJoinedByString:@" "]];
        [self send:command andExpect:@"OK"];
    });
}

-(void) dealloc {
    [self send:@"exit"];
}


@end
