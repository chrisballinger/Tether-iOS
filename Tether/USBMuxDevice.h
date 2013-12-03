//
//  USBMuxDevice.h
//  Tether
//
//  Created by Christopher Ballinger on 11/30/13.
//  Copyright (c) 2013 Christopher Ballinger. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "USBMuxDeviceConnection.h"

@interface USBMuxDevice : NSObject <USBMuxDeviceConnectionDelegate>

@property (nonatomic) NSString *udid;
@property (nonatomic) int productID;
@property (nonatomic) uint32_t handle;
@property (nonatomic) BOOL isVisible;
@property (nonatomic) dispatch_queue_t callbackQueue;

/**
 * If successful creates a new USBMuxDeviceConnection and adds it to the set of active connections
**/
- (void) connectToPort:(uint16_t)port completionBlock:(void(^)(USBMuxDeviceConnection *connection, NSError *error))completionBlock;
- (void) disconnect;

@end