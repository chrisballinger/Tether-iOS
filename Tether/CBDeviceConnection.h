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

@interface CBDeviceConnection : NSObject <GCDAsyncSocketDelegate, USBMuxDeviceConnectionDelegate>

@property (nonatomic, strong) USBMuxDeviceConnection *deviceConnection;
@property (nonatomic, strong) GCDAsyncSocket *socket;

- (id) initWithDeviceConnection:(USBMuxDeviceConnection*)connection socket:(GCDAsyncSocket*)socket;

- (void) disconnect;

@end
