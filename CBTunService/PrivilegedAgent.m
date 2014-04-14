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


// the below C functions have been adapted from OpenVPN's tun.c

/* Helper functions that tries to open utun device
 return -2 on early initialization failures (utun not supported
 at all (old OS X) and -1 on initlization failure of utun
 device (utun works but utunX is already used */
static
int utun_open_helper (struct ctl_info ctlInfo, int utunnum)
{
    struct sockaddr_ctl sc;
    int fd;
    
    fd = socket(PF_SYSTEM, SOCK_DGRAM, SYSPROTO_CONTROL);
    
    if (fd < 0)
    {
        NSLog(@"Opening utun (%s): %s", "socket(SYSPROTO_CONTROL)",
             strerror (errno));
        return -2;
    }
    
    if (ioctl(fd, CTLIOCGINFO, &ctlInfo) == -1)
    {
        close (fd);
        NSLog(@"Opening utun (%s): %s", "ioctl(CTLIOCGINFO)",
             strerror (errno));
        return -2;
    }
    
    
    sc.sc_id = ctlInfo.ctl_id;
    sc.sc_len = sizeof(sc);
    sc.sc_family = AF_SYSTEM;
    sc.ss_sysaddr = AF_SYS_CONTROL;
    
    sc.sc_unit = utunnum+1;
    
    
    /* If the connect is successful, a utun%d device will be created, where "%d"
     * is (sc.sc_unit - 1) */
    
    if (connect (fd, (struct sockaddr *)&sc, sizeof(sc)) < 0)
    {
        NSLog(@"Opening utun (%s): %s", "connect(AF_SYS_CONTROL)",
             strerror (errno));
        close(fd);
        return -1;
    }
    
    fcntl (fd, F_SETFL, O_NONBLOCK);
    fcntl (fd, F_SETFD, FD_CLOEXEC); /* don't pass fd to scripts */
    
    return fd;
}

@implementation PrivilegedAgent

- (NSFileHandle*) openUtun {
    struct ctl_info ctlInfo;
    int fd = -1;
    int utunnum =-1;
    
    memset(&(ctlInfo), 0, sizeof(ctlInfo));
    
    if (strlcpy(ctlInfo.ctl_name, UTUN_CONTROL_NAME, sizeof(ctlInfo.ctl_name)) >=
        sizeof(ctlInfo.ctl_name))
    {
        NSLog(@"Opening utun: UTUN_CONTROL_NAME too long");
    }
    
    /* try to open first available utun device if no specific utun is requested */
    if (utunnum == -1)
    {
        for (utunnum=0; utunnum<255; utunnum++)
        {
            fd = utun_open_helper (ctlInfo, utunnum);
            /* Break if the fd is valid,
             * or if early initalization failed (-2) */
            if (fd !=-1)
                break;
        }
    }
    else
    {
        fd = utun_open_helper (ctlInfo, utunnum);
    }
    
    /* opening an utun device failed */
    if (fd < 0) {
        return nil;
    }
    
    NSFileHandle *fileHandle = [[NSFileHandle alloc] initWithFileDescriptor:fd closeOnDealloc:YES];
    return fileHandle;
}

- (NSString*) getHandleInterfaceName:(NSFileHandle*)fileHandle {
    int fd = fileHandle.fileDescriptor;
    char utunname[20];
    socklen_t utunname_len = sizeof(utunname);
    
    NSString *interfaceName = nil;
    /* Retrieve the assigned interface name. */
    if (getsockopt (fd, SYSPROTO_CONTROL, UTUN_OPT_IFNAME, utunname, &utunname_len)) {
        NSLog(@"Error retrieving utun interface name");
    } else {
        interfaceName = [[NSString alloc] initWithBytes:utunname length:utunname_len encoding:NSUTF8StringEncoding];
    }
    return interfaceName;
}

- (void)openTun:(void (^)(NSFileHandle *tun, NSError *error))reply {
    [self closeTun];
    self.tunHandle = [self openUtun];
    NSError *error = nil;
    if (!self.tunHandle) {
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
