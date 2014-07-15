//
//  RHSLIFXClient.h
//  Lampster
//
//  Created by Rasmus Sten on 2014-07-15.
//  Copyright (c) 2014 Rasmus Sten. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DDFileReader.h"

@interface RHSLIFXClient : NSObject
{
    NSTask* rubyclient;
    NSPipe* clientinput;
    DDFileReader* reader;
}
-(void) lightsOn;
-(void) lightsOff;
-(void) waitForOK;
@end
