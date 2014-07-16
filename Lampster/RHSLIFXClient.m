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
    if (self) {
        rubyclient = [[NSTask alloc] init];
        rubyclient.launchPath = [[NSBundle bundleForClass:self.class] pathForResource:@"lifxclient" ofType:@"rb"];
        [rubyclient setEnvironment:@{@"GEM_HOME" : [[NSBundle bundleForClass:self.class] pathForResource:@"gems" ofType:@""]}];
        rubyclient.standardInput = clientinput = [NSPipe pipe];
        NSPipe* stdout = [NSPipe pipe];
        rubyclient.standardOutput = stdout;
        reader = [[DDFileReader alloc] initWithHandle:stdout.fileHandleForReading];
        [rubyclient launch];
        [self send:@"ping"];
    }
    return [super init];
}

- (void) waitForOK {
    [self waitFor:@"OK"];
}

-(void) waitFor:(NSString*) escape {
    [reader enumerateLinesUsingBlock:^(NSString *str, BOOL *stop) {
        if ([str isEqualToString:[NSString stringWithFormat:@"%@\n", escape]]) {
            *stop = YES;
            NSLog(@"%@ received", escape);
        }
    }];
}

-(void) send:(NSString*) command {
    [clientinput.fileHandleForWriting writeData:[[NSString stringWithFormat:@"%@\n", command] dataUsingEncoding:NSUTF8StringEncoding]];
}

-(void) lightsOn {
    [self send:@"lights-on"];
}

-(void) lightsOff {
    [self send:@"lights-off"];
}

-(void) dealloc {
    [self send:@"exit"];
    [self waitForOK];
}


@end
