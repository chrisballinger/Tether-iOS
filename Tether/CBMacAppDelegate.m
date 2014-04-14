//
//  CBMacAppDelegate.m
//  Tether
//
//  Created by Christopher Ballinger on 11/9/13.
//  Copyright (c) 2013 Christopher Ballinger. All rights reserved.
//

#import "CBMacAppDelegate.h"
#import "CBDeviceWindowController.h"

@implementation CBMacAppDelegate
@synthesize deviceWindowController;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    self.deviceWindowController = [[CBDeviceWindowController alloc] init];
    [self.deviceWindowController.window makeKeyAndOrderFront:self];
}

- (void) applicationWillTerminate:(NSNotification *)notification {
    NSLog(@"Application will terminate");
}

@end