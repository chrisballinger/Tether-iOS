//
//  CBAppDelegate.m
//  Tether
//
//  Created by Christopher Ballinger on 11/9/13.
//  Copyright (c) 2013 Christopher Ballinger. All rights reserved.
//

#import "CBAppDelegate.h"
#import "CBDeviceWindowController.h"



@implementation CBAppDelegate
@synthesize deviceWindowController;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    self.deviceWindowController = [[CBDeviceWindowController alloc] init];
    [self.deviceWindowController.window makeKeyAndOrderFront:self];
}

@end
