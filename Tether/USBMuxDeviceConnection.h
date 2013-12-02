//
//  USBMuxDeviceConnection.h
//  Tether
//
//  Created by Christopher Ballinger on 11/30/13.
//  Copyright (c) 2013 Christopher Ballinger. All rights reserved.
//

#import <Foundation/Foundation.h>

@class USBMuxDeviceConnection, USBMuxDevice;

@protocol USBMuxDeviceConnectionDelegate <NSObject>
- (void) connection:(USBMuxDeviceConnection*)connection didReceiveData:(NSData*)data;
@end

@interface USBMuxDeviceConnection : NSObject

@property (nonatomic, strong) USBMuxDevice *device;
@property (nonatomic) int socketFileDescriptor;
@property (nonatomic, strong) NSFileHandle *fileHandle;
@property (nonatomic, weak) id<USBMuxDeviceConnectionDelegate> delegate;
@property (nonatomic) dispatch_queue_t networkReadQueue;
@property (nonatomic) dispatch_queue_t networkWriteQueue;
@property (nonatomic) dispatch_queue_t callbackQueue;
@property (nonatomic) uint16_t port;

- (void) sendData:(NSData*)data;

- (void) disconnect;

@end
