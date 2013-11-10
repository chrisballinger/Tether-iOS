//
//  CBDeviceWindowController.h
//  Tether
//
//  Created by Christopher Ballinger on 11/9/13.
//  Copyright (c) 2013 Christopher Ballinger. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "USBMuxClient.h"
#import "GCDAsyncSocket.h"

@interface CBDeviceWindowController : NSWindowController <NSTableViewDataSource, NSTableViewDelegate, USBMuxClientDelegate>

@property (strong) IBOutlet NSTableView *deviceTableView;
@property (nonatomic, strong) NSMutableOrderedSet *devices;
@property (strong) IBOutlet NSButton *connectButton;
@property (strong) IBOutlet NSButton *refreshButton;
@property (nonatomic, strong) GCDAsyncSocket *socket;

- (IBAction)connectButtonPressed:(id)sender;
- (IBAction)refreshButtonPressed:(id)sender;

@end
