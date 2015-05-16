//
//  RHSNetMonitor.m
//  Lampster
//
//  Based on code from
//  https://developer.apple.com/library/mac/technotes/tn1145/_index.html#//apple_ref/doc/uid/DTS10002984-CH1-SECWHENGOODIPSGOBAD
//
//  Created by Rasmus Sten on 17-05-2015.
//  Copyright (c) 2015 Rasmus Sten. All rights reserved.
//

#import "RHSNetMonitor.h"
@implementation RHSNetMonitor

-(id) initWithHandler:(void (^)(NSArray*))handler {
    self = [super init];
    if (self) {
        self.handler = handler;
        SCDynamicStoreRef dynamicStore = NULL;
        CFRunLoopSourceRef sourceRef = NULL;
        OSStatus ret = CreateIPAddressListChangeCallbackSCF(systemConfigurationCallback, (__bridge void *)(self), &dynamicStore, &sourceRef);
        if (ret != 0) {
            NSLog(@"Error setting up SC callback (error=%d)", ret);
            return self;
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), sourceRef, kCFRunLoopCommonModes);
        self.dynamicStore = dynamicStore;
    }
    return self;
}

- (void) dealloc
{
    CFQRelease(self.dynamicStore);
}

void systemConfigurationCallback(SCDynamicStoreRef store, CFArrayRef changedKeys, void* info) {
    RHSNetMonitor* _self = (__bridge RHSNetMonitor*)(info);
    CFIndex serviceCount = CFArrayGetCount(changedKeys);
    NSMutableArray* changedServices = [NSMutableArray arrayWithCapacity:serviceCount];
    for (CFIndex i=0; i < serviceCount; i++) {
        CFStringRef key = CFArrayGetValueAtIndex(changedKeys, i);
        NSDictionary* service = CFBridgingRelease(SCDynamicStoreCopyValue(store, key));
        if (service) {
            [changedServices addObject:service];
        }
    }
    if (_self.handler) {
        _self.handler(changedServices);
    }
}

static OSStatus CreateIPAddressListChangeCallbackSCF(
                                                     SCDynamicStoreCallBack callback,
                                                     void *contextPtr,
                                                     SCDynamicStoreRef *storeRef,
                                                     CFRunLoopSourceRef *sourceRef)
// Create a SCF dynamic store reference and a
// corresponding CFRunLoop source. If you add the
// run loop source to your run loop then the supplied
// callback function will be called when local IP
// address list changes.
{
    OSStatus                err;
    SCDynamicStoreContext   context = {0, NULL, NULL, NULL, NULL};
    SCDynamicStoreRef       ref;
    CFStringRef             pattern;
    CFArrayRef              patternList;
    CFRunLoopSourceRef      rls;

    assert(callback   != NULL);
    assert( storeRef  != NULL);
    assert(*storeRef  == NULL);
    assert( sourceRef != NULL);
    assert(*sourceRef == NULL);

    ref = NULL;
    pattern = NULL;
    patternList = NULL;
    rls = NULL;

    // Create a connection to the dynamic store, then create
    // a search pattern that finds all IPv4 entities.
    // The pattern is "State:/Network/Service/[^/]+/IPv4".

    context.info = contextPtr;
    ref = SCDynamicStoreCreate( NULL,
                               CFSTR("Lampster"),
                               callback,
                               &context);
    err = MoreSCError(ref);
    if (err == noErr) {
        pattern = SCDynamicStoreKeyCreateNetworkServiceEntity(
                                                              NULL,
                                                              kSCDynamicStoreDomainState,
                                                              kSCCompAnyRegex,
                                                              kSCEntNetIPv4);
        err = MoreSCError(pattern);
    }

    // Create a pattern list containing just one pattern,
    // then tell SCF that we want to watch changes in keys
    // that match that pattern list, then create our run loop
    // source.

    if (err == noErr) {
        patternList = CFArrayCreate(NULL,
                                    (const void **) &pattern, 1,
                                    &kCFTypeArrayCallBacks);
        err = CFQError(patternList);
    }
    if (err == noErr) {
        err = MoreSCErrorBoolean(
                                 SCDynamicStoreSetNotificationKeys(
                                                                   ref,
                                                                   NULL,
                                                                   patternList)
                                 );
    }
    if (err == noErr) {
        rls = SCDynamicStoreCreateRunLoopSource(NULL, ref, 0);
        err = MoreSCError(rls);
    }

    // Clean up.

    CFQRelease(pattern);
    CFQRelease(patternList);
    if (err != noErr) {
        CFQRelease(ref);
        ref = NULL;
    }
    *storeRef = ref;
    *sourceRef = rls;

    assert( (err == noErr) == (*storeRef  != NULL) );
    assert( (err == noErr) == (*sourceRef != NULL) );

    return err;
}

static OSStatus MoreSCErrorBoolean(Boolean success)
{
    OSStatus err;
    int scErr;

    err = noErr;
    if ( ! success ) {
        scErr = SCError();
        if (scErr == kSCStatusOK) {
            scErr = kSCStatusFailed;
        }
        // Return an SCF error directly as an OSStatus.
        // That's a little cheesy. In a real program
        // you might want to do some mapping from SCF
        // errors to a range within the OSStatus range.
        err = scErr;
    }
    return err;
}

static OSStatus MoreSCError(const void *value)
{
    return MoreSCErrorBoolean(value != NULL);
}

static OSStatus CFQError(CFTypeRef cf)
// Maps Core Foundation error indications (such as they
// are) to the OSStatus domain.
{
    OSStatus err;

    err = noErr;
    if (cf == NULL) {
        err = coreFoundationUnknownErr;
    }
    return err;
}

static void CFQRelease(CFTypeRef cf)
// A version of CFRelease that's tolerant of NULL.
{
    if (cf != NULL) {
        CFRelease(cf);
    }
}

@end
