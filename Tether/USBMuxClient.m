//
//  USBMuxClient.m
//  Tether
//
//  Created by Christopher Ballinger on 11/10/13.
//  Copyright (c) 2013 Christopher Ballinger. All rights reserved.
//

#import "USBMuxClient.h"
#import "USBMuxDevice.h"
#import "USBMuxDeviceConnection.h"
#import <usbmuxd.h>

static NSString * const kUSBMuxDeviceErrorDomain = @"kUSBMuxDeviceErrorDomain";


@interface USBMuxClient(Private)
@property (nonatomic, strong) NSMutableDictionary *devices;
+ (USBMuxDevice*) nativeDeviceForDevice:(usbmuxd_device_info_t)device;
@end

static void usbmuxdEventCallback(const usbmuxd_event_t *event, void *user_data) {
    usbmuxd_device_info_t device = event->device;
        
    USBMuxDevice *nativeDevice = [USBMuxClient nativeDeviceForDevice:device];
    
    USBDeviceStatus deviceStatus = -1;
    if (event->event == UE_DEVICE_ADD) {
        deviceStatus = kUSBMuxDeviceStatusAdded;
        nativeDevice.isVisible = YES;
    } else if (event->event == UE_DEVICE_REMOVE) {
        deviceStatus = kUSBMuxDeviceStatusRemoved;
        nativeDevice.isVisible = NO;
        [nativeDevice disconnect];
    }
    
    id<USBMuxClientDelegate> delegate = [USBMuxClient sharedClient].delegate;
    if (delegate && [delegate respondsToSelector:@selector(device:statusDidChange:)]) {
        dispatch_async([USBMuxClient sharedClient].callbackQueue, ^{
            [delegate device:nativeDevice statusDidChange:deviceStatus];
        });
    }
}

@implementation USBMuxClient
@synthesize delegate, callbackQueue, networkQueue, devices;

- (void) dealloc {
    usbmuxd_unsubscribe();
}

- (id) init {
    if (self = [super init]) {
        self.devices = [NSMutableDictionary dictionary];
        self.networkQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        self.callbackQueue = dispatch_get_main_queue();
        usbmuxd_subscribe(usbmuxdEventCallback, NULL);
    }
    return self;
}

+ (NSError*) errorWithDescription:(NSString*)description code:(NSInteger)code {
    return [NSError errorWithDomain:kUSBMuxDeviceErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey:description}];
}

+ (USBMuxDevice*) nativeDeviceForDevice:(usbmuxd_device_info_t)device {
    NSMutableDictionary *devices = (NSMutableDictionary*)[USBMuxClient sharedClient].devices;
    NSString *udid = [NSString stringWithUTF8String:device.udid];
    USBMuxDevice *nativeDevice = [devices objectForKey:udid];
    if (!nativeDevice) {
        nativeDevice = [[USBMuxDevice alloc] init];
        nativeDevice.udid = [NSString stringWithUTF8String:device.udid];
        nativeDevice.productID = device.product_id;
        [devices setObject:nativeDevice forKey:nativeDevice.udid];
    }
    nativeDevice.handle = device.handle;
    return nativeDevice;
}

+ (void) getDeviceListWithCompletion:(USBMuxDeviceDeviceListBlock)completionBlock {
    dispatch_async([USBMuxClient sharedClient].networkQueue, ^{
        usbmuxd_device_info_t *deviceList = NULL;
        int deviceListCount = usbmuxd_get_device_list(&deviceList);
        if (deviceListCount < 0 || !deviceList) {
            if (completionBlock) {
                dispatch_async([USBMuxClient sharedClient].callbackQueue, ^{
                    completionBlock(nil, [self errorWithDescription:@"Couldn't get device list." code:102]);
                });
            }
            return;
        }
        NSMutableArray *devices = [NSMutableArray arrayWithCapacity:deviceListCount];
        for (int i = 0; i < deviceListCount; i++) {
            usbmuxd_device_info_t device = deviceList[i];
            USBMuxDevice *nativeDevice = [USBMuxClient nativeDeviceForDevice:device];
            nativeDevice.isVisible = YES;
            [devices addObject:nativeDevice];
        }
        
        if (completionBlock) {
            dispatch_async([USBMuxClient sharedClient].callbackQueue, ^{
                completionBlock(devices, nil);
            });
        }
        free(deviceList);
    });
}

+ (USBMuxClient*) sharedClient {
    static dispatch_once_t onceToken;
    static USBMuxClient *_sharedClient = nil;
    dispatch_once(&onceToken, ^{
        _sharedClient = [[USBMuxClient alloc] init];
    });
    return _sharedClient;
}



@end
