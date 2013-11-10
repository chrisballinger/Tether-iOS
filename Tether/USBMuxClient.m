//
//  USBMuxClient.m
//  Tether
//
//  Created by Christopher Ballinger on 11/10/13.
//  Copyright (c) 2013 Christopher Ballinger. All rights reserved.
//

#import "USBMuxClient.h"
#import <usbmuxd.h>

static NSString * const kUSBMuxDeviceErrorDomain = @"kUSBMuxDeviceErrorDomain";


@interface USBMuxDevice()
@property (nonatomic) int socketFileDescriptor;
@end

@implementation USBMuxDevice
@synthesize udid, productID, handle, socketFileDescriptor;

- (id) init {
    if (self = [super init]) {
        self.socketFileDescriptor = 0;
    }
    return self;
}

@end

static void usbmuxdEventCallback(const usbmuxd_event_t *event, void *user_data) {
    usbmuxd_device_info_t device = event->device;
    
    NSMutableDictionary *devices = (NSMutableDictionary*)[USBMuxClient sharedClient].devices;
    NSString *udid = [NSString stringWithUTF8String:device.udid];
    
    USBMuxDevice *nativeDevice = [devices objectForKey:udid];
    if (!nativeDevice) {
        nativeDevice = [[USBMuxDevice alloc] init];
        nativeDevice.udid = [NSString stringWithUTF8String:device.udid];
        nativeDevice.productID = device.product_id;
    }
    nativeDevice.handle = device.handle;
    
    USBDeviceStatus deviceStatus = -1;
    if (event->event == UE_DEVICE_ADD) {
        [devices setObject:nativeDevice forKey:nativeDevice.udid];
        deviceStatus = kUSBMuxDeviceStatusAdded;
    } else if (event->event == UE_DEVICE_REMOVE) {
        [devices removeObjectForKey:nativeDevice.udid];
        deviceStatus = kUSBMuxDeviceStatusRemoved;
    }
    
    id<USBMuxClientDelegate> delegate = [USBMuxClient sharedClient].delegate;
    if (delegate && [delegate respondsToSelector:@selector(device:statusDidChange:)]) {
        dispatch_async([USBMuxClient sharedClient].callbackQueue, ^{
            [delegate device:nativeDevice statusDidChange:deviceStatus];
        });
    }
}

@interface USBMuxClient(Private)
@property (nonatomic, strong) NSMutableDictionary *devices;
@end

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


+ (void) connectDevice:(USBMuxDevice *)device port:(unsigned short)port completionCallback:(USBMuxDeviceCompletionBlock)completionCallback {
    dispatch_async([USBMuxClient sharedClient].networkQueue, ^{
        int socketFileDescriptor = usbmuxd_connect(device.handle, port);
        if (socketFileDescriptor == -1 && completionCallback) {
            dispatch_async([USBMuxClient sharedClient].callbackQueue, ^{
                completionCallback(NO, [self errorWithDescription:@"Couldn't connect device." code:100]);
            });
            
            return;
        }
        device.socketFileDescriptor = socketFileDescriptor;
        device.isConnected = YES;
        dispatch_async([USBMuxClient sharedClient].callbackQueue, ^{
            completionCallback(YES, nil);
        });
    });
}

+ (void) disconnectDevice:(USBMuxDevice *)device completionCallback:(USBMuxDeviceCompletionBlock)completionCallback {
    dispatch_async([USBMuxClient sharedClient].networkQueue, ^{
        int disconnectValue = usbmuxd_disconnect(device.socketFileDescriptor);
        if (disconnectValue == -1 && completionCallback) {
            dispatch_async([USBMuxClient sharedClient].callbackQueue, ^{
                completionCallback(NO, [self errorWithDescription:@"Couldn't disconnect device." code:101]);
            });
            
            return;
        }
        device.socketFileDescriptor = 0;
        device.isConnected = NO;
        dispatch_async([USBMuxClient sharedClient].callbackQueue, ^{
            completionCallback(YES, nil);
        });
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
