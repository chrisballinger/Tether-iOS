//
//  CBTunDevice.h
//  Tether
//
//  Created by Christopher Ballinger on 3/8/14.
//  Copyright (c) 2014 Christopher Ballinger. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CBTunDevice : NSObject

- (void) openTun;
- (void) closeTun;

@end
