//
//  USBMuxDevice.m
//  Tether
//
//  Created by Christopher Ballinger on 11/30/13.
//  Copyright (c) 2013 Christopher Ballinger. All rights reserved.
//

#import "USBMuxDevice.h"

@interface USBMuxDevice()

@end

@implementation USBMuxDevice
@synthesize udid, productID, handle, isVisible;

- (id) init {
    if (self = [super init]) {
        self.connections = [NSMutableSet set];
    }
    return self;
}


@end