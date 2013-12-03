//
//  USBMuxDeviceConnection.h
//  Tether
//
//  Created by Christopher Ballinger on 11/30/13.
//  Copyright (c) 2013 Christopher Ballinger. All rights reserved.
//

#import <Foundation/Foundation.h>

@class USBMuxDeviceConnection, USBMuxDevice;

@protocol USBMuxDeviceConnectionDelegate <NSObject>
@optional
- (void) connection:(USBMuxDeviceConnection*)connection didReadData:(NSData *)data tag:(long)tag;
- (void) connection:(USBMuxDeviceConnection*)connection didWriteDataToLength:(NSUInteger)length tag:(long)tag;
- (void) connection:(USBMuxDeviceConnection*)connection didConnectToPort:(uint16_t)port;
- (void) connectionDidDisconnect:(USBMuxDeviceConnection*)connection withError:(NSError*)error;
@end

@interface USBMuxDeviceConnection : NSObject

@property (nonatomic, weak) USBMuxDevice *device;
@property (nonatomic) uint16_t port;
@property (nonatomic, weak) id<USBMuxDeviceConnectionDelegate> delegate;
@property (nonatomic) dispatch_queue_t callbackQueue;
@property (nonatomic) dispatch_queue_t networkReadQueue;
@property (nonatomic) dispatch_queue_t networkWriteQueue;
@property (nonatomic, readonly) BOOL isConnected;

- (id) initWithDevice:(USBMuxDevice*)device;

- (void) writeData:(NSData*)data tag:(long)tag;
- (void) readDataWithTimeout:(NSTimeInterval)timeout tag:(long)tag;
- (void) connectToPort:(uint16_t)port completionBlock:(void(^)(BOOL success, NSError *error))completionBlock;
- (void) disconnect;

@end
