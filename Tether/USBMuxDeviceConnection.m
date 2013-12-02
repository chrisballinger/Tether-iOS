//
//  USBMuxDeviceConnection.m
//  Tether
//
//  Created by Christopher Ballinger on 11/30/13.
//  Copyright (c) 2013 Christopher Ballinger. All rights reserved.
//

#import "USBMuxDeviceConnection.h"
#import "usbmuxd.h"
#import <sys/ioctl.h>

@implementation USBMuxDeviceConnection

- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (id) init {
    if (self = [super init]) {
        _socketFileDescriptor = 0;
        _networkReadQueue = dispatch_queue_create("USBMuxDevice Network Read Queue", 0);
        _networkWriteQueue = dispatch_queue_create("USBMuxDevice Network Write Queue", 0);
        _callbackQueue = dispatch_queue_create("USBMuxDevice Callback Queue", 0);
    }
    return self;
}

- (void) sendData:(NSData *)data {
    if (!_fileHandle) {
        NSLog(@"file handle is nil!");
        return;
    }
    dispatch_async(_networkWriteQueue, ^{
        NSLog(@"Writing data to device socket %d: %@", _socketFileDescriptor, data);
        uint32_t sentBytes = 0;
        uint32_t totalBytes = (uint32_t)data.length;
        int sendValue = usbmuxd_send(_socketFileDescriptor, [data bytes], totalBytes, &sentBytes);
        if (sendValue == 0) {
            NSLog(@"Wrote %d / %d of %@", sentBytes, totalBytes, data);
        } else {
            NSLog(@"Error %d occurred while writing %d / %d of %@", sendValue, sentBytes, totalBytes, data);
        }
        [self readDataFromDeviceWithTimeout:-1];
    });
}

- (void) readDataFromDeviceWithTimeout:(NSTimeInterval)timeout {
    if (_socketFileDescriptor == 0) {
        NSLog(@"read canceled, socket is 0");
        return;
    }
    dispatch_async(_networkReadQueue, ^{
        uint32_t bytesAvailable = 0;
        uint32_t totalBytesReceived = 0;
        ioctl(_socketFileDescriptor, FIONREAD, &bytesAvailable);
        if (bytesAvailable == 0) {
            NSLog(@"no bytes available for read");
            bytesAvailable = 4096;
        }
        uint8_t *buffer = malloc(bytesAvailable * sizeof(uint8_t));
        int readValue = -1;
        if (timeout == -1) {
            readValue = usbmuxd_recv(_socketFileDescriptor, (char*)buffer, bytesAvailable, &totalBytesReceived);
        } else {
            readValue = usbmuxd_recv_timeout(_socketFileDescriptor, (char*)buffer, bytesAvailable, &totalBytesReceived, (int)(timeout * 1000));
        }
        if (readValue != 0 || totalBytesReceived == 0) {
            NSLog(@"Error reading on socket %d: %d", _socketFileDescriptor, readValue);
            free(buffer);
            return;
        }
        NSData *receivedData = [[NSData alloc] initWithBytesNoCopy:buffer length:totalBytesReceived freeWhenDone:YES];
        if (_delegate) {
            dispatch_async(_callbackQueue, ^{
                [_delegate connection:self didReceiveData:receivedData];
            });
        }
        
        [self readDataFromDeviceWithTimeout:timeout];
    });
}

- (void) setSocketFileDescriptor:(int)newSocketFileDescriptor {
    _socketFileDescriptor = newSocketFileDescriptor;

    self.fileHandle = [[NSFileHandle alloc] initWithFileDescriptor:_socketFileDescriptor closeOnDealloc:NO];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dataAvailableNotification:) name:NSFileHandleDataAvailableNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(readCompleteNotification:) name:NSFileHandleReadCompletionNotification object:nil];
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
    self.delegate = nil;
    _socketFileDescriptor = 0;
}

@end
