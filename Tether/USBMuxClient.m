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
@property (nonatomic, strong) NSFileHandle *fileHandle;
@end

@implementation USBMuxDevice
@synthesize udid, productID, handle, socketFileDescriptor, isVisible, delegate, fileHandle;

- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (id) init {
    if (self = [super init]) {
        self.socketFileDescriptor = 0;
        self.networkQueue = dispatch_queue_create("USBMuxDevice Network Queue", 0);
        self.callbackQueue = dispatch_queue_create("USBMuxDevice Callback Queue", 0);
    }
    return self;
}

- (void) sendData:(NSData *)data {
    if (!fileHandle) {
        return;
    }
    dispatch_async(self.networkQueue, ^{
        [fileHandle writeData:data];
    });
}



- (void) setSocketFileDescriptor:(int)newSocketFileDescriptor {
    socketFileDescriptor = newSocketFileDescriptor;
    CFReadStreamRef readStreamRef = NULL;
    CFWriteStreamRef writeStreamRef = NULL;
    CFStreamCreatePairWithSocket(kCFAllocatorDefault, socketFileDescriptor, &readStreamRef, &writeStreamRef);
    NSInputStream *inputStream = objc_unretainedObject(readStreamRef);
    NSOutputStream *outputStream = objc_unretainedObject(writeStreamRef);
    /*self.fileHandle = [[NSFileHandle alloc] initWithFileDescriptor:socketFileDescriptor closeOnDealloc:NO];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [fileHandle waitForDataInBackgroundAndNotify];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dataAvailableNotification:) name:NSFileHandleDataAvailableNotification object:fileHandle];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(readCompleteNotification:) name:NSFileHandleReadCompletionNotification object:fileHandle];
     */
}

- (void) readCompleteNotification:(NSNotification*)notification {
    NSLog(@"read complete notification: %@", notification.userInfo);
    NSData *data = [notification.userInfo objectForKey:NSFileHandleNotificationDataItem];
    NSError *error = [notification.userInfo objectForKey:@"NSFileHandleError"];
    if (error) {
        NSLog(@"Error reading data from socket: %@", error.userInfo);
        return;
    }
    if (self.delegate && [self.delegate respondsToSelector:@selector(device:didReceiveData:)]) {
        dispatch_async(self.callbackQueue, ^{
            [self.delegate device:self didReceiveData:data];
        });
    }
}

- (void) dataAvailableNotification:(NSNotification*)notification {
    NSLog(@"Received data available notification: %@", notification.userInfo);
    [self.fileHandle readInBackgroundAndNotify];
}


@end

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


+ (void) connectDevice:(USBMuxDevice *)device port:(unsigned short)port completionCallback:(USBMuxDeviceCompletionBlock)completionCallback {
    dispatch_async([USBMuxClient sharedClient].networkQueue, ^{
        int socketFileDescriptor = usbmuxd_connect(device.handle, port);
        if (socketFileDescriptor == -1) {
            if (completionCallback) {
                dispatch_async([USBMuxClient sharedClient].callbackQueue, ^{
                    completionCallback(NO, [self errorWithDescription:@"Couldn't connect device." code:100]);
                });
            }
            return;
        }
        device.socketFileDescriptor = socketFileDescriptor;
        device.isConnected = YES;
        if (completionCallback) {
            dispatch_async([USBMuxClient sharedClient].callbackQueue, ^{
                completionCallback(YES, nil);
            });
        }
    });
}

+ (void) disconnectDevice:(USBMuxDevice *)device completionCallback:(USBMuxDeviceCompletionBlock)completionCallback {
    dispatch_async([USBMuxClient sharedClient].networkQueue, ^{
        int disconnectValue = usbmuxd_disconnect(device.socketFileDescriptor);
        if (disconnectValue == -1) {
            if (completionCallback) {
                dispatch_async([USBMuxClient sharedClient].callbackQueue, ^{
                    completionCallback(NO, [self errorWithDescription:@"Couldn't disconnect device." code:101]);
                });
            }
            return;
        }
        device.socketFileDescriptor = 0;
        device.isConnected = NO;
        if (completionCallback) {
            dispatch_async([USBMuxClient sharedClient].callbackQueue, ^{
                completionCallback(YES, nil);
            });
        }
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
