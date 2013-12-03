//
//  USBMuxDevice.m
//  Tether
//
//  Created by Christopher Ballinger on 11/30/13.
//  Copyright (c) 2013 Christopher Ballinger. All rights reserved.
//

#import "USBMuxDevice.h"

@interface USBMuxDevice()
@property (nonatomic, strong) NSMutableSet *activeConnections;
@property (nonatomic) dispatch_queue_t connectionQueue;
@end

@implementation USBMuxDevice

- (id) init {
    if (self = [super init]) {
        _activeConnections = [NSMutableSet set];
        _connectionQueue = dispatch_queue_create("USBMuxDevice connection queue", 0);
        _callbackQueue = dispatch_get_main_queue();
    }
    return self;
}

- (void) connectToPort:(uint16_t)port completionBlock:(void(^)(USBMuxDeviceConnection *connection, NSError *error))completionBlock {
    USBMuxDeviceConnection *connection = [[USBMuxDeviceConnection alloc] initWithDevice:self];
    connection.callbackQueue = _connectionQueue;
    connection.delegate = self;
    [connection connectToPort:port completionBlock:^(BOOL success, NSError *error) {
        if (success) {
            [_activeConnections addObject:connection];
            if (completionBlock) {
                dispatch_async(_callbackQueue, ^{
                    completionBlock(connection, nil);
                });
            }
        } else {
            if (completionBlock) {
                dispatch_async(_callbackQueue, ^{
                    completionBlock(nil, error);
                });
            }
        }
    }];
}

- (void) connectionDidDisconnect:(USBMuxDeviceConnection *)connection withError:(NSError *)error {
    dispatch_async(_connectionQueue, ^{
        if (error) {
            NSLog(@"%@ did disconnect with error: %@", connection, error);
        }
        [_activeConnections removeObject:connection];
    });
}

- (void) disconnect {
    [_activeConnections enumerateObjectsUsingBlock:^(USBMuxDeviceConnection *connection, BOOL *stop) {
        [connection disconnect];
    }];
}

@end