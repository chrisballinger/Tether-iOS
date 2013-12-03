//
//  USBMuxClient.h
//  Tether
//
//  Created by Christopher Ballinger on 11/10/13.
//  Copyright (c) 2013 Christopher Ballinger. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(int16_t, USBDeviceStatus) {
    kUSBMuxDeviceStatusRemoved = 0,
    kUSBMuxDeviceStatusAdded = 1
};

@class USBMuxDevice, USBMuxDeviceConnection;

typedef void(^USBMuxDeviceCompletionBlock)(BOOL success, NSError *error);
typedef void(^USBMuxDeviceDeviceListBlock)(NSArray *deviceList, NSError *error);


@protocol USBMuxClientDelegate <NSObject>
@optional
- (void) device:(USBMuxDevice*)device statusDidChange:(USBDeviceStatus)deviceStatus;
@end

@interface USBMuxClient : NSObject

/**
 Queue for all network calls. (defaults to global default background queue)
 */
@property (nonatomic) dispatch_queue_t networkQueue;

/**
 Queue for all callbacks. (defaults to main queue)
 */
@property (nonatomic) dispatch_queue_t callbackQueue;


@property (nonatomic, strong) NSDictionary *devices;

@property (nonatomic, weak) id<USBMuxClientDelegate> delegate;

+ (void) getDeviceListWithCompletion:(USBMuxDeviceDeviceListBlock)completionBlock;

+ (USBMuxClient*) sharedClient;

@end
