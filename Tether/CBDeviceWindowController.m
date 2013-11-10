//
//  CBDeviceWindowController.m
//  Tether
//
//  Created by Christopher Ballinger on 11/9/13.
//  Copyright (c) 2013 Christopher Ballinger. All rights reserved.
//

#import "CBDeviceWindowController.h"
#import "USBMuxClient.h"

@interface CBDeviceWindowController ()

@end

@implementation CBDeviceWindowController
@synthesize devices, deviceTableView;


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
    NSUInteger port = 8123;
    [USBMuxClient connectDevice:device port:port completionCallback:^(BOOL success, NSError *error) {
        NSLog(@"connecting %@ on port %lu", device.udid, (unsigned long)port);
    }];
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
@end
