//
//  PrivilegedActions.m
//  SMJobBless
//
//  Created by Ludovic Delaveau on 8/5/12.
//
//

#import <syslog.h>
#import <unistd.h>
#import "PrivilegedAgent.h"

#include <sys/types.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <sys/sys_domain.h>
#include <sys/kern_control.h>
#include <net/if_utun.h>
#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <syslog.h>
#include <unistd.h>

#include <stdlib.h> // exit, etc.

int
tun(void)
{
    struct sockaddr_ctl sc;
    struct ctl_info ctlInfo;
    int fd;
    
    
    memset(&ctlInfo, 0, sizeof(ctlInfo));
    if (strlcpy(ctlInfo.ctl_name, UTUN_CONTROL_NAME, sizeof(ctlInfo.ctl_name)) >=
        sizeof(ctlInfo.ctl_name)) {
        fprintf(stderr,"UTUN_CONTROL_NAME too long");
        return -1;
    }
    fd = socket(PF_SYSTEM, SOCK_DGRAM, SYSPROTO_CONTROL);
    
    if (fd == -1) {
        perror ("socket(SYSPROTO_CONTROL)");
        return -1;
    }
    if (ioctl(fd, CTLIOCGINFO, &ctlInfo) == -1) {
        perror ("ioctl(CTLIOCGINFO)");
        close(fd);
        return -1;
    }
    
    sc.sc_id = ctlInfo.ctl_id;
    sc.sc_len = sizeof(sc);
    sc.sc_family = AF_SYSTEM;
    sc.ss_sysaddr = AF_SYS_CONTROL;
    sc.sc_unit = 2; /* Only have one, in this example... */
    
    
    // If the connect is successful, a tun%d device will be created, where "%d"
    // is our unit number -1
    
    if (connect(fd, (struct sockaddr *)&sc, sizeof(sc)) == -1) {
        perror ("connect(AF_SYS_CONTROL)");
        close(fd);
        return -1;
    }
    return fd;
}

@implementation PrivilegedAgent

- (void)openTun:(void (^)(NSFileHandle *tun, NSError *error))reply {
    [self closeTun];
    int utunfd = tun();
    
    NSError * error = nil;
    
    if (utunfd != -1) {
        self.tunHandle = [[NSFileHandle alloc] initWithFileDescriptor:utunfd closeOnDealloc:YES];
    } else {
        error = [NSError errorWithDomain:@"com.chrisballinger.CBTunService" code:100 userInfo:@{NSLocalizedDescriptionKey: @"Error opening TUN fd"}];
    }
    
    if (reply) {
        reply(self.tunHandle, error);
    }
}

- (void)closeTun {
    self.tunHandle = nil;
}

@end
