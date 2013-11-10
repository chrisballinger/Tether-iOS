//
//  CBAppDelegate.h
//  Tether
//
//  Created by Christopher Ballinger on 11/9/13.
//  Copyright (c) 2013 Christopher Ballinger. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "CBDeviceWindowController.h"

@interface CBAppDelegate : NSObject <NSApplicationDelegate>

@property (nonatomic, strong) CBDeviceWindowController *deviceWindowController;

@end
