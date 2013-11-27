//
//  CBDeviceConnection.m
//  Tether
//
//  Created by Christopher Ballinger on 11/10/13.
//  Copyright (c) 2013 Christopher Ballinger. All rights reserved.
//

#import "CBDeviceConnection.h"

@implementation CBDeviceConnection
@synthesize device, socket;

- (id) initWithDevice:(USBMuxDevice *)newDevice socket:(GCDAsyncSocket *)newSocket {
    if (self = [super init]) {
        self.device = newDevice;
        self.device.delegate = self;
        self.socket = newSocket;
        self.socket.delegate = self;
        [self.socket readDataWithTimeout:-1 tag:0];
    }
    return self;
}

- (void) socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    NSString *dataString = [[NSString alloc] initWithData:data
                                                 encoding:NSUTF8StringEncoding];
    NSLog(@"did read data: %@ tag: %ld", dataString, tag);
    [device sendData:data];
    [sock readDataWithTimeout:-1 tag:0];
}

- (void) socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag {
    NSLog(@"did write data with tag: %ld", tag);
}

- (void) device:(USBMuxDevice *)device didReceiveData:(NSData *)data {
    NSString *dataString = [[NSString alloc] initWithData:data
                                                 encoding:NSUTF8StringEncoding];

    NSLog(@"did receive data: %@", dataString);
    [socket writeData:data withTimeout:5 tag:0];
}

@end
