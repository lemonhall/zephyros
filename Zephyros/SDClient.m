//
//  SDClientInterface.m
//  Zephyros
//
//  Created by Steven on 8/11/13.
//  Copyright (c) 2013 Giant Robot Software. All rights reserved.
//

#import "SDClient.h"

#import "SDLogWindowController.h"

#import "SDTopLevelRef.h"
#import "SDAppRef.h"
#import "SDWindowRef.h"
#import "SDScreenRef.h"

#import "SDClient.h"

@interface SDClient ()

@property SDTopLevelRef* topLevel;

@end


@implementation SDClient

- (id) init {
    if (self = [super init]) {
        self.refCache = [[SDRefCache alloc] init];
        
        self.topLevel = [[SDTopLevelRef alloc] init];
        self.topLevel.client = self;
        
        self.undoManager = [[NSUndoManager alloc] init];
        
        [self.refCache store:self.topLevel withKey:[NSNull null]];
        [self.refCache store:self.topLevel withKey:@0]; // backwards compatibility :'(
    }
    return self;
}

- (void) destroy {
    [self.topLevel destroy];
}

- (void) handleRequest:(NSArray*)msg {
    if ([msg count] < 3) {
        SDLogError(@"API error: invalid message: %@", msg);
        return;
    }
    
    id msgID = [msg objectAtIndex:0];
    
    if ([msgID isEqual:[NSNull null]]) {
        SDLogError(@"API error: invalid message id: %@", msgID);
        [self sendResponse:[NSNull null] forID:msgID];
        return;
    }
    
    id recvID = [msg objectAtIndex:1];
    
    NSString* meth = [msg objectAtIndex:2];
    
    if (![meth isKindOfClass:[NSString self]] || [[meth stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length] == 0) {
        SDLogError(@"API error: invalid method name: %@", meth);
        [self sendResponse:[NSNull null] forID:msgID];
        return;
    }
    
    NSArray* args = [msg subarrayWithRange:NSMakeRange(3, [msg count] - 3)];
    SDReference* recv = [self.refCache refForKey: recvID];
    [recv retainRef];
    [recv releaseRef];
    
    if (recv == nil) {
        SDLogError(@"API Error: Could not find resource with ID %@", recvID);
        [self sendResponse:[NSNull null] forID:msgID];
        return;
    }
    
    SEL sel = NSSelectorFromString([[meth stringByReplacingOccurrencesOfString:@"?" withString:@"_q"] stringByAppendingString:@":msgID:"]);
    
    if (![recv respondsToSelector:sel]) {
        SDLogError(@"API Error: Could not find method %@.%@", [recv className], meth);
        [self sendResponse:[NSNull null] forID:msgID];
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        id result = nil;
        @try {
            IMP meth = [recv methodForSelector:sel];
            result = meth(recv, sel, args, msgID);
        }
        @catch (NSException *exception) {
            SDLogError([exception description]);
        }
        @finally {
            [self sendResponse:result forID:msgID];
        }
    });
}

- (void) sendResponse:(id)result forID:(NSNumber*)msgID {
    [self.delegate sendResponse:@[msgID, result]];
}

@end
