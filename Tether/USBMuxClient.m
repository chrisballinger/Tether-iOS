//
//  USBMuxClient.m
//  Tether
//
//  Created by Christopher Ballinger on 11/10/13.
//  Copyright (c) 2013 Christopher Ballinger. All rights reserved.
//

#import "USBMuxClient.h"
#import <usbmuxd.h>

@implementation USBMuxDevice
@synthesize udid, productID, handle;
@end

static void usbmuxdEventCallback(const usbmuxd_event_t *event, void *user_data) {
    usbmuxd_device_info_t device = event->device;
    
    USBMuxDevice *nativeDevice = [[USBMuxDevice alloc] init];
    nativeDevice.udid = [NSString stringWithUTF8String:device.udid];
    nativeDevice.productID = device.product_id;
    nativeDevice.handle = device.handle;
    
    USBDeviceStatus deviceStatus = -1;
    if (event->event == UE_DEVICE_ADD) {
        deviceStatus = kUSBMuxDeviceStatusAdded;
    } else if (event->event == UE_DEVICE_REMOVE) {
        deviceStatus = kUSBMuxDeviceStatusRemoved;
    }
    
    id<USBMuxClientDelegate> delegate = [USBMuxClient sharedClient].delegate;
    if (delegate && [delegate respondsToSelector:@selector(device:statusDidChange:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [delegate device:nativeDevice statusDidChange:deviceStatus];
        });
    }
}

@implementation USBMuxClient
@synthesize delegate;

- (void) dealloc {
    usbmuxd_unsubscribe();
}

+ (USBMuxClient*) sharedClient {
    static dispatch_once_t onceToken;
    static USBMuxClient *_sharedClient = nil;
    dispatch_once(&onceToken, ^{
        _sharedClient = [[USBMuxClient alloc] init];
    });
    return _sharedClient;
}

- (id) init {
    if (self = [super init]) {
        usbmuxd_subscribe(usbmuxdEventCallback, NULL);
    }
    return self;
}

@end
