//
//  USBMuxDeviceConnection.m
//  Tether
//
//  Created by Christopher Ballinger on 11/30/13.
//  Copyright (c) 2013 Christopher Ballinger. All rights reserved.
//

#import "USBMuxDeviceConnection.h"

@implementation USBMuxDeviceConnection

- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (id) init {
    if (self = [super init]) {
        _socketFileDescriptor = 0;
        _networkQueue = dispatch_queue_create("USBMuxDevice Network Queue", 0);
        _callbackQueue = dispatch_queue_create("USBMuxDevice Callback Queue", 0);
    }
    return self;
}

- (void) sendData:(NSData *)data {
    if (!_fileHandle) {
        NSLog(@"file handle is nil!");
        return;
    }
    dispatch_async(_networkQueue, ^{
        NSLog(@"Writing data to device socket %d: %@", _socketFileDescriptor, data);
        [_fileHandle writeData:data];
    });
}

- (void) setSocketFileDescriptor:(int)newSocketFileDescriptor {
    _socketFileDescriptor = newSocketFileDescriptor;

    self.fileHandle = [[NSFileHandle alloc] initWithFileDescriptor:_socketFileDescriptor closeOnDealloc:NO];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dataAvailableNotification:) name:NSFileHandleDataAvailableNotification object:_fileHandle];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(readCompleteNotification:) name:NSFileHandleReadCompletionNotification object:_fileHandle];
    [_fileHandle waitForDataInBackgroundAndNotify];
}

- (void) readCompleteNotification:(NSNotification*)notification {
    NSLog(@"read complete notification: %@", notification.userInfo);
    NSData *data = [notification.userInfo objectForKey:NSFileHandleNotificationDataItem];
    NSError *error = [notification.userInfo objectForKey:@"NSFileHandleError"];
    if (error) {
        NSLog(@"Error reading data from socket: %@", error.userInfo);
        return;
    }
    if (_delegate) {
        dispatch_async(_callbackQueue, ^{
            [_delegate connection:self didReceiveData:data];
        });
    }
}

- (void) dataAvailableNotification:(NSNotification*)notification {
    NSLog(@"Received data available notification: %@", notification.userInfo);
    [_fileHandle readInBackgroundAndNotify];
}


- (void) disconnect {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    self.device = nil;
    _socketFileDescriptor = 0;
}

@end
