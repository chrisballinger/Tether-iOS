//
//  CBDeviceWindowController.m
//  Tether
//
//  Created by Christopher Ballinger on 11/9/13.
//  Copyright (c) 2013 Christopher Ballinger. All rights reserved.
//

#import "CBDeviceWindowController.h"
#import "USBMuxClient.h"
#import "CBDeviceConnection.h"
#import "SOCKSProxy.h"

const static uint16_t kDefaultLocalPortNumber = 8000;
const static uint16_t kDefaultRemotePortNumber = 8123;

@interface CBDeviceWindowController ()
@property (nonatomic, strong) SOCKSProxy *proxyServer;
@end

@implementation CBDeviceWindowController
@synthesize devices, deviceTableView, listeningSocket, remotePortField, localPortField, deviceConnections;

- (void) device:(USBMuxDevice *)device statusDidChange:(USBDeviceStatus)deviceStatus {
    NSLog(@"device: %@ status: %d", device.udid, deviceStatus);
    if (deviceStatus == kUSBMuxDeviceStatusAdded) {
        [devices addObject:device];
    }
    [deviceTableView reloadData];
}


- (NSString*) windowNibName {
    return NSStringFromClass([self class]);
}

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        self.devices = [NSMutableOrderedSet orderedSetWithCapacity:1];
        self.deviceConnections = [NSMutableSet set];
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    self.deviceTableView.dataSource = self;
    self.deviceTableView.delegate = self;
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    [USBMuxClient sharedClient].delegate = self;
    [self performSelector:@selector(refreshButtonPressed:) withObject:nil afterDelay:0.1]; // for whatever reason
    self.proxyServer = [[SOCKSProxy alloc] init];
    [self.proxyServer startProxyOnPort:9050];
}


// The only essential/required tableview dataSource method
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return devices.count;
}

// This method is optional if you use bindings to provide the data
- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    // Group our "model" object, which is a dictionary
    USBMuxDevice *device = [devices objectAtIndex:row];
    
    // In IB the tableColumn has the identifier set to the same string as the keys in our dictionary
    NSString *identifier = [tableColumn identifier];
    NSTableCellView *cellView = [tableView makeViewWithIdentifier:identifier owner:self];
    NSColor *textColor = [NSColor textColor];
    if (!device.isVisible) {
        textColor = [NSColor lightGrayColor];
    }
    cellView.textField.textColor = textColor;
    if ([identifier isEqualToString:@"ProductIDCell"]) {
        // We pass us as the owner so we can setup target/actions into this main controller object
        // Then setup properties on the cellView based on the column
        cellView.textField.stringValue = [NSString stringWithFormat:@"%d", device.productID];
        return cellView;
    } else if ([identifier isEqualToString:@"UDIDCell"]) {
        cellView.textField.stringValue = device.udid;
    } else {
        NSAssert1(NO, @"Unhandled table column identifier %@", identifier);
        return nil;
    }
    return cellView;
}

- (IBAction)connectButtonPressed:(id)sender {
    NSUInteger selectedRow = self.deviceTableView.selectedRow;
    if (selectedRow >= devices.count) {
        return;
    }
    USBMuxDevice *device = [devices objectAtIndex:self.deviceTableView.selectedRow];
    self.selectedDevice = device;
    uint16_t remotePort = kDefaultRemotePortNumber;
    uint16_t remotePortFieldValue = (uint16_t)remotePortField.integerValue;
    if (remotePortFieldValue > 0) {
        remotePort = remotePortFieldValue;
    }
    
    [USBMuxClient connectDevice:device port:remotePort completionCallback:^(BOOL success, NSError *error) {
        if (success) {
            NSLog(@"connected %@ on remote port %d", device.udid, remotePort);
        } else {
            NSLog(@"error connecting to remote port %d", remotePort);
        }
    }];
    self.listeningSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    NSError *error = nil;
    uint16_t localPort = kDefaultLocalPortNumber;
    uint16_t localPortFieldValue = (uint16_t)localPortField.integerValue;
    if (localPortFieldValue > 0) {
        localPort = localPortFieldValue;
    }
    [listeningSocket acceptOnPort:localPort error:&error];
    if (error) {
        NSLog(@"Error listening on port %d", localPort);
    }
}

- (IBAction)refreshButtonPressed:(id)sender {
    [USBMuxClient getDeviceListWithCompletion:^(NSArray *deviceList, NSError *error) {
        if (error) {
            NSLog(@"Error getting device list: %@", error.userInfo);
            return;
        }
        for (USBMuxDevice *device in deviceList) {
            [devices addObject:device];
        }
        [deviceTableView reloadData];
    }];
}

- (void) socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket {
    NSLog(@"new socket accepted");
    CBDeviceConnection *deviceConnection = [[CBDeviceConnection alloc] initWithDevice:self.selectedDevice socket:newSocket];
    [deviceConnections addObject:deviceConnection];
}
@end
