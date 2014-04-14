//
//  CBDeviceWindowController.m
//  Tether
//
//  Created by Christopher Ballinger on 11/9/13.
//  Copyright (c) 2013 Christopher Ballinger. All rights reserved.
//

#import "CBDeviceWindowController.h"
#import "USBMuxClient.h"
#import "USBMuxDevice.h"
#import "CBDeviceConnection.h"
#import <ServiceManagement/ServiceManagement.h>
#import <Security/Authorization.h>
#import "Actions.h"

const static uint16_t kDefaultLocalPortNumber = 8000;
const static uint16_t kDefaultRemotePortNumber = 8123;

@interface CBDeviceWindowController ()
@end

@implementation CBDeviceWindowController
@synthesize devices, deviceTableView, listeningSocket, remotePortField, localPortField, deviceConnections;

- (void) device:(USBMuxDevice *)device statusDidChange:(USBDeviceStatus)deviceStatus {
    NSLog(@"device: %@ status: %d", device.udid, deviceStatus);
    if (deviceStatus == kUSBMuxDeviceStatusAdded) {
        [devices addObject:device];
    } else if (deviceStatus == kUSBMuxDeviceStatusRemoved) {
        [self setConnections:nil forDevice:device];
    }
    [self refreshSelectedDevice];
}

- (NSMutableSet*) connectionsForDevice:(USBMuxDevice*)device {
    NSString *udid = [device.udid copy];
    NSMutableSet *connections = [deviceConnections objectForKey:udid];
    if (!connections) {
        connections = [NSMutableSet set];
        [deviceConnections setObject:connections forKey:udid];
    }
    return [deviceConnections objectForKey:device.udid];
}

- (void) setConnections:(NSMutableSet*)connections forDevice:(USBMuxDevice*)device {
    if (!connections) {
        NSMutableSet *connections = [self.deviceConnections objectForKey:device.udid];
        [connections enumerateObjectsUsingBlock:^(CBDeviceConnection *connection, BOOL *stop) {
            [connection disconnect];
        }];
        [self.deviceConnections removeObjectForKey:device.udid];
        return;
    }
    [self.deviceConnections setObject:connections forKey:device.udid];
}

- (void) disconnectConnectionsForDevice:(USBMuxDevice*)device {
    [self setConnections:nil forDevice:device];
}

- (void) refreshSelectedDevice {
    [deviceTableView reloadData];
    if (self.deviceTableView.numberOfSelectedRows == 0 && self.devices.count > 0) {
        self.selectedDevice = devices[0];
    }
    if (self.selectedDevice) {
        NSUInteger selectedIndex = [devices indexOfObject:self.selectedDevice];
        NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:selectedIndex];
        [deviceTableView selectRowIndexes:indexSet byExtendingSelection:NO];
    }
}


- (NSString*) windowNibName {
    return NSStringFromClass([self class]);
}

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        self.devices = [NSMutableOrderedSet orderedSetWithCapacity:1];
        self.deviceConnections = [NSMutableDictionary dictionary];
        self.totalBytesRead = 0;
        self.totalBytesWritten = 0;
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
    
    NSString *helperLabel = @"com.chrisballinger.CBTunService";
    
    NSError *error = nil;
	if (![self blessHelperWithLabel:helperLabel error:&error]) {
        NSLog(@"Failed to bless helper. Error: %@", error);
    }
    
    NSXPCConnection *connection = [[NSXPCConnection alloc] initWithMachServiceName:helperLabel options:NSXPCConnectionPrivileged];
    connection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(TunHandler)];
    [connection resume];
    
    [[connection remoteObjectProxyWithErrorHandler:^(NSError *error) {
        NSLog(@"Something bad happened, %@", [error description]);
    }] openTun:^(NSFileHandle *tun, NSError *error) {
        if (tun) {
            NSLog(@"Got handle: %@\nfd: %d", tun, tun.fileDescriptor);
        } else {
            NSLog(@"Couldn't get handle: %@", error);
        }
    }];
}

- (BOOL)blessHelperWithLabel:(NSString *)label
                       error:(NSError **)error {
    
	BOOL result = NO;
    
    /* Always remove the job if we've previously submitted it. This is to help with versioning (we always install the latest tool). It also avoids conflicts where the installed tool was signed with a different key (i.e. someone building Hex Fiend while also having run the signed distribution). A potentially negative consequence is that we have to authenticate every launch, but that is actually a benefit, because it serves as a sort of notification that user's action requires elevated privileges, instead of just (potentially silently) doing it. */
    BOOL helperIsAlreadyInstalled = NO;
    CFDictionaryRef existingJob = SMJobCopyDictionary(kSMDomainSystemLaunchd, (__bridge CFStringRef)(label));
    if (existingJob) {
        helperIsAlreadyInstalled = YES;
        CFRelease(existingJob);
    }
    
	AuthorizationItem authItems[2] = {{ kSMRightBlessPrivilegedHelper, 0, NULL, 0 }, { kSMRightModifySystemDaemons, 0, NULL, 0 }};
	AuthorizationRights authRights = { (helperIsAlreadyInstalled ? 2 : 1), authItems };
	AuthorizationFlags flags		=	kAuthorizationFlagDefaults				|
    kAuthorizationFlagInteractionAllowed	|
    kAuthorizationFlagPreAuthorize			|
    kAuthorizationFlagExtendRights;
    
	AuthorizationRef authRef = NULL;
	
	/* Obtain the right to install privileged helper tools (kSMRightBlessPrivilegedHelper). */
	OSStatus status = AuthorizationCreate(&authRights, kAuthorizationEmptyEnvironment, flags, &authRef);
	if (status != errAuthorizationSuccess) {
        if (error) {
            if (status == errAuthorizationCanceled) {
                *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:nil];
            } else {
                NSString *description = [NSString stringWithFormat:@"Failed to create AuthorizationRef (error code %ld).", (long)status];
                *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadNoPermissionError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:description, NSLocalizedDescriptionKey, nil]];
            }
        }
        return NO;
    }
    
    /* This does all the work of verifying the helper tool against the application
     * and vice-versa. Once verification has passed, the embedded launchd.plist
     * is extracted and placed in /Library/LaunchDaemons and then loaded. The
     * executable is placed in /Library/PrivilegedHelperTools.
     */
    
    /* Remove the existing helper. If this fails it's not a fatal error (SMJobBless can handle the case when a job is already installed). */
    if (helperIsAlreadyInstalled) {
        CFErrorRef localError = NULL;
        SMJobRemove(kSMDomainSystemLaunchd, (__bridge CFStringRef)(label), authRef, true /* wait */, &localError);
        if (localError) {
            NSLog(@"SMJobRemove() failed with error %@", localError);
            CFRelease(localError);
        }
    }
    
    
    CFErrorRef localError = NULL;
    result = SMJobBless(kSMDomainSystemLaunchd, (__bridge CFStringRef)label, authRef, (CFErrorRef *)&localError);
    if (localError) {
        if (error) {
            *error = (__bridge NSError*)localError;
        }
        CFRelease(localError);
    }
	
	return result;
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

- (IBAction)refreshButtonPressed:(id)sender {
    if (self.listeningSocket) {
        NSLog(@"Disconnecting local socket");
        [self.listeningSocket disconnect];
        self.listeningSocket.delegate = nil;
        self.listeningSocket = nil;
    }
    [USBMuxClient getDeviceListWithCompletion:^(NSArray *deviceList, NSError *error) {
        if (error) {
            NSLog(@"Error getting device list: %@", error.userInfo);
        }
        for (USBMuxDevice *device in deviceList) {
            [devices addObject:device];
        }
        [self refreshSelectedDevice];

        USBMuxDevice *device = self.selectedDevice;
        if (!device) {
            NSLog(@"No devices selected, aborting the start of local socket");
            return;
        }
        
        self.listeningSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
        error = nil;
        uint16_t localPort = [self customOrDefaultLocalPort];
        [listeningSocket acceptOnPort:localPort error:&error];
        if (error) {
            NSLog(@"Error listening on port %d", localPort);
        }
        NSLog(@"Listening on local port %d for new connections", localPort);
    }];
}

- (uint16_t) customOrDefaultLocalPort {
    uint16_t localPort = kDefaultLocalPortNumber;
    uint16_t localPortFieldValue = (uint16_t)localPortField.integerValue;
    if (localPortFieldValue > 0) {
        localPort = localPortFieldValue;
    }
    return localPort;
}

- (uint16_t) customOrDefaultRemotePort {
    uint16_t remotePort = kDefaultRemotePortNumber;
    uint16_t remotePortFieldValue = (uint16_t)remotePortField.integerValue;
    if (remotePortFieldValue > 0) {
        remotePort = remotePortFieldValue;
    }
    return remotePort;
}

- (void) socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket {
    if (!self.selectedDevice.isVisible) {
        NSLog(@"selected device no longer visible, aborting connection");
        [sock disconnect];
        [newSocket disconnect];
        return;
    }
    NSLog(@"new local connection accepted on %@:%d", [newSocket localHost], [newSocket localPort]);
    uint16_t remotePort = [self customOrDefaultRemotePort];
    NSString *deviceUUID = [self.selectedDevice.udid copy];
    
    [_selectedDevice connectToPort:remotePort completionBlock:^(USBMuxDeviceConnection *connection, NSError *error) {
        if (connection) {
            NSLog(@"New device connection to %@ on port %d", deviceUUID, remotePort);
            CBDeviceConnection *deviceConnection = [[CBDeviceConnection alloc] initWithDeviceConnection:connection socket:newSocket];
            deviceConnection.delegate = self;
            NSMutableSet *connections = [self connectionsForDevice:connection.device];
            [connections addObject:deviceConnection];
        } else {
            NSLog(@"Error connecting to device %@ on port %d: %@", deviceUUID, remotePort, error);
        }
    }];
}

- (void) connection:(CBDeviceConnection *)connection didReadData:(NSData *)data {
    _totalBytesRead += data.length;
    //NSLog(@"total bytes read: %lu", (unsigned long)_totalBytesRead);
}

- (void) connection:(CBDeviceConnection *)connection didWriteDataToLength:(NSUInteger)length {
    _totalBytesWritten += length;
    //NSLog(@"total bytes written: %lu", (unsigned long)_totalBytesWritten);
}

@end
