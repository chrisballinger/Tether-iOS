//
//  CBDeviceConnection.h
//  Tether
//
//  Created by Christopher Ballinger on 11/10/13.
//  Copyright (c) 2013 Christopher Ballinger. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "USBMuxClient.h"
#import "USBMuxDeviceConnection.h"
#import "GCDAsyncSocket.h"

@class CBDeviceConnection;

@protocol CBDeviceConnectionDelegate <NSObject>
@optional
- (void) connection:(CBDeviceConnection*)connection didWriteDataToLength:(NSUInteger)length;
- (void) connection:(CBDeviceConnection*)connection didReadData:(NSData*)data;
@end

@interface CBDeviceConnection : NSObject <GCDAsyncSocketDelegate, USBMuxDeviceConnectionDelegate>

@property (nonatomic, strong) USBMuxDeviceConnection *deviceConnection;
@property (nonatomic, strong) GCDAsyncSocket *socket;
@property (nonatomic, weak) id<CBDeviceConnectionDelegate> delegate;
@property (nonatomic) dispatch_queue_t delegateQueue;

- (id) initWithDeviceConnection:(USBMuxDeviceConnection*)connection socket:(GCDAsyncSocket*)socket;

- (void) disconnect;

@end
