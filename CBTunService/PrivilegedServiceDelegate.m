//
//  PrivilegedServiceDelegate.m
//  SMJobBless
//
//  Created by Ludovic Delaveau on 8/5/12.
//
//

#import "PrivilegedServiceDelegate.h"
#import "Actions.h"
#import "PrivilegedAgent.h"

@implementation PrivilegedServiceDelegate

- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection {
    newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(TunHandler)];
    newConnection.exportedObject = [[PrivilegedAgent alloc] init];
    [newConnection resume];
    
    return YES;
}

@end
