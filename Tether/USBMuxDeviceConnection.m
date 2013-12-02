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

- (id) init {
    if (self = [super init]) {
        _networkReadQueue = dispatch_queue_create("USBMuxDevice Network Read Queue", 0);
        _networkWriteQueue = dispatch_queue_create("USBMuxDevice Network Write Queue", 0);
        _delegateQueue = dispatch_get_main_queue();
    }
    return self;
}

- (id) initWithDevice:(USBMuxDevice*)device socketFileDescriptor:(int)socketFileDescriptor {
    if (self = [self init]) {
        _device = device;
        _socketFileDescriptor = socketFileDescriptor;
    }
    return self;
}

- (void) writeData:(NSData*)data tag:(long)tag {
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
        if (_delegate && [_delegate respondsToSelector:@selector(connection:didWriteDataToLength:tag:)]) {
            dispatch_async(_delegateQueue, ^{
                [_delegate connection:self didWriteDataToLength:sentBytes tag:tag];
            });
        }
    });
}

- (void) readDataWithTimeout:(NSTimeInterval)timeout tag:(long)tag {
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
        if (_delegate && [_delegate respondsToSelector:@selector(connection:didReadData:tag:)]) {
            dispatch_async(_delegateQueue, ^{
                [_delegate connection:self didReadData:receivedData tag:tag];
            });
        }
    });
}

- (void) disconnect {
    self.device = nil;
    self.delegate = nil;
    _socketFileDescriptor = 0;
}

@end
