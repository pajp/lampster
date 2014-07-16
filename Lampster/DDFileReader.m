//DDFileReader.m

#import "DDFileReader.h"

@interface NSData (DDAdditions)

- (NSRange) rangeOfData_dd:(NSData *)dataToFind;

@end

@implementation NSData (DDAdditions)

- (NSRange) rangeOfData_dd:(NSData *)dataToFind {
    
    const void * bytes = [self bytes];
    NSUInteger length = [self length];
    
    const void * searchBytes = [dataToFind bytes];
    NSUInteger searchLength = [dataToFind length];
    NSUInteger searchIndex = 0;
    
    NSRange foundRange = {NSNotFound, searchLength};
    for (NSUInteger index = 0; index < length; index++) {
        if (((char *)bytes)[index] == ((char *)searchBytes)[searchIndex]) {
            //the current character matches
            if (foundRange.location == NSNotFound) {
                foundRange.location = index;
            }
            searchIndex++;
            if (searchIndex >= searchLength) { return foundRange; }
        } else {
            searchIndex = 0;
            foundRange.location = NSNotFound;
        }
    }
    return foundRange;
}

@end

@implementation DDFileReader
@synthesize lineDelimiter, chunkSize;

- (id) initWithHandle:(NSFileHandle *)aHandle {
    if (self = [super init]) {
        self.fileHandle = aHandle;
        if (self.fileHandle == nil) {
            return nil;
        }
        
        lineDelimiter = @"\n";
        chunkSize = 1;
    }
    return self;
}

- (void) dealloc {
    [self.fileHandle closeFile];
    //self.fileHandle = nil;
}

- (NSString *) readLine {
    
    NSData * newLineData = [lineDelimiter dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableData * currentData = [[NSMutableData alloc] init];
    BOOL shouldReadMore = YES;

    while (shouldReadMore) {
        @autoreleasepool {
            NSData * chunk = nil;
            @try {
                chunk = [self.fileHandle readDataOfLength:chunkSize];
            } @catch (NSException* e) {
                NSLog(@"Read exception: %@", e);
                return nil;
            }
            if (chunk == nil) {
                return nil;
            }
            NSRange newLineRange = [chunk rangeOfData_dd:newLineData];
            if (newLineRange.location != NSNotFound) {
                
                //include the length so we can include the delimiter in the string
                chunk = [chunk subdataWithRange:NSMakeRange(0, newLineRange.location+[newLineData length])];
                shouldReadMore = NO;
            }
            [currentData appendData:chunk];
        }
    }
    
    NSString * line = [[NSString alloc] initWithData:currentData encoding:NSUTF8StringEncoding];
    return line;
}

- (NSString *) readTrimmedLine {
    return [[self readLine] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

#if NS_BLOCKS_AVAILABLE
- (void) enumerateLinesUsingBlock:(void(^)(NSString*, BOOL*))block {
    NSString * line = nil;
    BOOL stop = NO;
    while (stop == NO && (line = [self readLine])) {
        block(line, &stop);
    }
}
#endif

@end