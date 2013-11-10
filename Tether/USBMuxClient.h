//
//  USBMuxClient.h
//  Tether
//
//  Created by Christopher Ballinger on 11/10/13.
//  Copyright (c) 2013 Christopher Ballinger. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(int16_t, USBDeviceStatus) {
    kUSBMuxDeviceStatusAdded = 1,
    kUSBMuxDeviceStatusRemoved = 2,
};

@interface USBMuxDevice : NSObject

@property (nonatomic) NSString *udid;
@property (nonatomic) int productID;
@property (nonatomic) uint32_t handle;

@end

@protocol USBMuxClientDelegate <NSObject>
@optional
- (void) device:(USBMuxDevice*)device statusDidChange:(USBDeviceStatus)deviceStatus;
@end

@interface USBMuxClient : NSObject

@property (nonatomic, weak) id<USBMuxClientDelegate> delegate;

+ (USBMuxClient*) sharedClient;

@end
