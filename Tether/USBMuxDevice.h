//
//  USBMuxDevice.h
//  Tether
//
//  Created by Christopher Ballinger on 11/30/13.
//  Copyright (c) 2013 Christopher Ballinger. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface USBMuxDevice : NSObject

@property (nonatomic) NSString *udid;
@property (nonatomic) int productID;
@property (nonatomic) uint32_t handle;
@property (nonatomic, strong) NSMutableSet *connections;
@property (nonatomic) BOOL isVisible;

@end