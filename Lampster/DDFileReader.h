//DDFileReader.h

#import <Foundation/NSFileHandle.h>

@interface DDFileReader : NSObject {
    
    
    NSString * lineDelimiter;
    NSUInteger chunkSize;
}
@property (retain) NSFileHandle* fileHandle;
@property (nonatomic, copy) NSString * lineDelimiter;
@property (nonatomic) NSUInteger chunkSize;

- (id) initWithHandle:(NSFileHandle *)aHandle;

- (void) setFileHandle:(NSFileHandle*) handle;
- (NSString *) readLine;
- (NSString *) readTrimmedLine;

#if NS_BLOCKS_AVAILABLE
- (void) enumerateLinesUsingBlock:(void(^)(NSString*, BOOL *))block;
#endif

@end
