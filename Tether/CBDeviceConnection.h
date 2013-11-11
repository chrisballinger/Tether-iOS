//
//  CBDeviceConnection.h
//  Tether
//
//  Created by Christopher Ballinger on 11/10/13.
//  Copyright (c) 2013 Christopher Ballinger. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "USBMuxClient.h"
#import "GCDAsyncSocket.h"

@interface CBDeviceConnection : NSObject <GCDAsyncSocketDelegate, USBMuxDeviceDelegate>

@property (nonatomic, strong) USBMuxDevice *device;
@property (nonatomic, strong) GCDAsyncSocket *socket;

- (id) initWithDevice:(USBMuxDevice*)device socket:(GCDAsyncSocket*)socket;

@end
