//
//  CBTunDevice.m
//  Tether
//
//  Created by Christopher Ballinger on 3/8/14.
//  Copyright (c) 2014 Christopher Ballinger. All rights reserved.
//

#import "CBTunDevice.h"
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
	sc.sc_unit = 2;	/* Only have one, in this example... */
	
    
	// If the connect is successful, a tun%d device will be created, where "%d"
 	// is our unit number -1
    
	if (connect(fd, (struct sockaddr *)&sc, sizeof(sc)) == -1) {
		perror ("connect(AF_SYS_CONTROL)");
		close(fd);
		return -1;
	}
	return fd;
}

@interface CBTunDevice()
@property (nonatomic) int utunFileDescriptor;
@end


@implementation CBTunDevice

- (void) dealloc {
    [self closeTun];
}

- (void) closeTun {
    if (!_utunFileDescriptor) {
        return;
    }
    close(_utunFileDescriptor);
    _utunFileDescriptor = 0;
}

- (void) openTun {
    [self closeTun];
    self.utunFileDescriptor = tun ();
    
    if (_utunFileDescriptor == -1)
	{
		fprintf(stderr,"Unable to establish UTUN descriptor - aborting\n");
        [self closeTun];
		return;
	}
    
    fprintf(stderr,"Utun interface is up.. Configure IPv4 using \"ifconfig utun1 _ipA_ _ipB_\"\n");
    fprintf(stderr,"                       Configure IPv6 using \"ifconfig utun1 inet6 _ip6_\"\n");
    fprintf(stderr,"Then (e.g.) ping _ipB_ (IPv6 will automatically generate ND messages)\n");
    
    
    // PoC - Just dump the packets...
    for (;;)
	{
		unsigned char 	c[1500];
		ssize_t     len;
		int	i;
        
		len = read (_utunFileDescriptor,c, 1500);
        
		// First 4 bytes of read data are the AF: 2 for AF_INET, 1E for AF_INET6, etc..
		for (i = 4; i< len; i++)
		{
            printf ("%02x ", c[i]);
            if ( (i-4)%16 ==15) printf("\n");
		}
		printf ("\n");
	}
}

@end
