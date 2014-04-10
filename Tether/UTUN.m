//
//  UTUN.m
//  Tether
//
//  Created by Christopher Ballinger on 12/8/13.
//  Copyright (c) 2013 Christopher Ballinger. All rights reserved.
//

#import "UTUN.h"
#import <sys/kern_control.h>
#import <sys/sys_domain.h>
#import <sys/ioctl.h>
#import <sys/uio.h>
#import <netinet/ip.h>
#import <netinet6/in6.h>
#import <net/if_utun.h>

/*
 * Allocate a string
 */
char *
string_alloc (const char *str)
{
    if (str)
    {
        const long n = strlen (str) + 1;
        char *ret;
        
        ret = calloc(1, n);

        memcpy (ret, str, n);
        return ret;
    }
    else
        return NULL;
}

#define DEV_TYPE_TUN   2    /* point-to-point IP tunnel */


struct tuntap_options {
    /* --ip-win32 options */
    bool ip_win32_defined;
    
# define IPW32_SET_MANUAL       0  /* "--ip-win32 manual" */
# define IPW32_SET_NETSH        1  /* "--ip-win32 netsh" */
# define IPW32_SET_IPAPI        2  /* "--ip-win32 ipapi" */
# define IPW32_SET_DHCP_MASQ    3  /* "--ip-win32 dynamic" */
# define IPW32_SET_ADAPTIVE     4  /* "--ip-win32 adaptive" */
# define IPW32_SET_N            5
    int ip_win32_type;
    
    /* --ip-win32 dynamic options */
    bool dhcp_masq_custom_offset;
    int dhcp_masq_offset;
    int dhcp_lease_time;
    
    /* --tap-sleep option */
    int tap_sleep;
    
    /* --dhcp-option options */
    
    bool dhcp_options;
    
    const char *domain;        /* DOMAIN (15) */
    
    const char *netbios_scope; /* NBS (47) */
    
    int netbios_node_type;     /* NBT 1,2,4,8 (46) */
    
#define N_DHCP_ADDR 4        /* Max # of addresses allowed for
DNS, WINS, etc. */
    
    /* DNS (6) */
    in_addr_t dns[N_DHCP_ADDR];
    int dns_len;
    
    /* WINS (44) */
    in_addr_t wins[N_DHCP_ADDR];
    int wins_len;
    
    /* NTP (42) */
    in_addr_t ntp[N_DHCP_ADDR];
    int ntp_len;
    
    /* NBDD (45) */
    in_addr_t nbdd[N_DHCP_ADDR];
    int nbdd_len;
    
    /* DISABLE_NBT (43, Vendor option 001) */
    bool disable_nbt;
    
    bool dhcp_renew;
    bool dhcp_pre_release;
    bool dhcp_release;
    
    bool register_dns;
};

/*
 * Define a TUN/TAP dev.
 */

struct tuntap
{
# define TUNNEL_TYPE(tt) ((tt) ? ((tt)->type) : DEV_TYPE_UNDEF)
    int type; /* DEV_TYPE_x as defined in proto.h */
    
# define TUNNEL_TOPOLOGY(tt) ((tt) ? ((tt)->topology) : TOP_UNDEF)
    int topology; /* one of the TOP_x values */
    
    bool did_ifconfig_setup;
    bool did_ifconfig_ipv6_setup;
    bool did_ifconfig;
    
    bool ipv6;
    
    bool persistent_if;		/* if existed before, keep on program end */
    
    struct tuntap_options options; /* options set on command line */
    
    char *actual_name; /* actual name of TUN/TAP dev, usually including unit number */
    
    /* number of TX buffers */
    int txqueuelen;
    
    /* ifconfig parameters */
    in_addr_t local;
    in_addr_t remote_netmask;
    in_addr_t broadcast;
    
    struct in6_addr local_ipv6;
    struct in6_addr remote_ipv6;
    int netbits_ipv6;
    
    int fd;   /* file descriptor for TUN/TAP dev */
    
    bool is_utun;
    /* used for printing status info only */
    unsigned int rwflags_debug;
    
    /* Some TUN/TAP drivers like to be ioctled for mtu
     after open */
    int post_open_mtu;
};


/*
 * OpenBSD and Mac OS X when using utun
 * have a slightly incompatible TUN device from
 * the rest of the world, in that it prepends a
 * uint32 to the beginning of the IP header
 * to designate the protocol (why not just
 * look at the version field in the IP header to
 * determine v4 or v6?).
 *
 * We strip off this field on reads and
 * put it back on writes.
 *
 * I have not tested TAP devices on OpenBSD,
 * but I have conditionalized the special
 * TUN handling code described above to
 * go away for TAP devices.
 */


static inline long
header_modify_read_write_return (long len)
{
    if (len > 0)
        return len > sizeof (u_int32_t) ? len - sizeof (u_int32_t) : 0;
    else
        return len;
}

long
write_tun (struct tuntap* tt, uint8_t *buf, int len)
{
    if (tt->type == DEV_TYPE_TUN)
    {
        u_int32_t type;
        struct iovec iv[2];
        struct ip *iph;
        
        iph = (struct ip *) buf;
        
        if (tt->ipv6 && iph->ip_v == 6)
            type = htonl (AF_INET6);
        else
            type = htonl (AF_INET);
        
        iv[0].iov_base = &type;
        iv[0].iov_len = sizeof (type);
        iv[1].iov_base = buf;
        iv[1].iov_len = len;
        
        return header_modify_read_write_return (writev (tt->fd, iv, 2));
    }
    else
        return write (tt->fd, buf, len);
}

long
read_tun (struct tuntap* tt, uint8_t *buf, int len)
{
    if (tt->type == DEV_TYPE_TUN)
    {
        u_int32_t type;
        struct iovec iv[2];
        
        iv[0].iov_base = &type;
        iv[0].iov_len = sizeof (type);
        iv[1].iov_base = buf;
        iv[1].iov_len = len;
        
        return header_modify_read_write_return (readv (tt->fd, iv, 2));
    }
    else
        return read (tt->fd, buf, len);
}

/* Darwin (MacOS X) is mostly "just use the generic stuff", but there
 * is always one caveat...:
 *
 * If IPv6 is configured, and the tun device is closed, the IPv6 address
 * configured to the tun interface changes to a lingering /128 route
 * pointing to lo0.  Need to unconfigure...  (observed on 10.5)
 */

/*
 * utun is the native Darwin tun driver present since at least 10.7
 * Thanks goes to Jonathan Levin for providing an example how to utun
 * (http://newosxbook.com/src.jl?tree=listings&file=17-15-utun.c)
 */

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
        NSLog (@"Opening utun (%s): %s", "socket(SYSPROTO_CONTROL)",
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
        NSLog (@"Opening utun (%s): %s", "connect(AF_SYS_CONTROL)",
             strerror (errno));
        close(fd);
        return -1;
    }
    
    fcntl (fd, F_SETFL, O_NONBLOCK);
    fcntl (fd, F_SETFD, FD_CLOEXEC); /* don't pass fd to scripts */
    
    return fd;
}

void
open_darwin_utun (const char *dev, const char *dev_type, const char *dev_node, struct tuntap *tt)
{
    struct ctl_info ctlInfo;
    int fd;
    char utunname[20];
    int utunnum =-1;
    socklen_t utunname_len = sizeof(utunname);
    
    /* dev_node is simply utun, do the normal dynamic utun
     * otherwise try to parse the utun number */
    if (dev_node && !strcmp ("utun", dev_node)==0)
    {
        if (!sscanf (dev_node, "utun%d", &utunnum)==1)
            NSLog(@"Cannot parse 'dev-node %s' please use 'dev-node utunX'"
                 "to use a utun device number X", dev_node);
    }
    
    
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
    tt->fd = fd;
    
    if (fd < 0)
        return;
    
    /* Retrieve the assigned interface name. */
    if (getsockopt (fd, SYSPROTO_CONTROL, UTUN_OPT_IFNAME, utunname, &utunname_len))
        NSLog(@"Error retrieving utun interface name");
    
    tt->actual_name = string_alloc (utunname);
    
    NSLog(@"Opened utun device %s", utunname);
    tt->is_utun = true;
}

void
open_tun (const char *dev, const char *dev_type, const char *dev_node, struct tuntap *tt)
{
    /* Try utun first and fall back to normal tun if utun fails
         and dev_node is not specified */
    open_darwin_utun(dev, dev_type, dev_node, tt);
    
    if (!tt->is_utun)
    {
        NSLog(@"Cannot open utun device");
    }
}

static void
clear_tuntap (struct tuntap *tuntap)
{
    memset(tuntap, 0, sizeof(*tuntap));
    tuntap->fd = -1;
    tuntap->ipv6 = false;
}

static void
close_tun_generic (struct tuntap *tt)
{
    if (tt->fd >= 0)
    close (tt->fd);
    if (tt->actual_name)
        free (tt->actual_name);
    clear_tuntap (tt);
}

bool
is_dev_type (const char *dev, const char *dev_type, const char *match_type)
{
    if (!dev)
        return false;
    if (dev_type)
        return !strcmp (dev_type, match_type);
    else
        return !strncmp (dev, match_type, strlen (match_type));
}

int
dev_type_enum (const char *dev, const char *dev_type)
{
    if (is_dev_type (dev, dev_type, "tun"))
        return DEV_TYPE_TUN;
    else
        return 0;
}

const char *
dev_type_string (const char *dev, const char *dev_type)
{
    switch (dev_type_enum (dev, dev_type))
    {
        case DEV_TYPE_TUN:
            return "tun";
        default:
            return "[unknown-dev-type]";
    }
}

void
close_tun (struct tuntap* tt)
{
    if (tt)
    {
        if ( tt->ipv6 && tt->did_ifconfig_ipv6_setup )
        {
            /*
            const char * ifconfig_ipv6_local =
            print_in6_addr (tt->local_ipv6, 0, &gc);
            
            argv_printf (&argv, "%s delete -inet6 %s",
                         ROUTE_PATH, ifconfig_ipv6_local );
            argv_msg (M_INFO, &argv);
            openvpn_execve_check (&argv, NULL, 0, "MacOS X 'remove inet6 route' failed (non-critical)");
            */
        }
        close_tun_generic (tt);
        free (tt);
    }
}

/*
 * Init tun/tap object.
 *
 * Set up tuntap structure for ifconfig,
 * but don't execute yet.
 */
struct tuntap *
init_tun (const char *dev,       /* --dev option */
          const char *dev_type,  /* --dev-type option */
          int topology,          /* one of the TOP_x values */
          const char *ifconfig_local_parm,          /* --ifconfig parm 1 */
          const char *ifconfig_remote_netmask_parm, /* --ifconfig parm 2 */
          const char *ifconfig_ipv6_local_parm,     /* --ifconfig parm 1 IPv6 */
          int         ifconfig_ipv6_netbits_parm,
          const char *ifconfig_ipv6_remote_parm,    /* --ifconfig parm 2 IPv6 */
          in_addr_t local_public,
          in_addr_t remote_public,
          const bool strict_warn)
{
    struct tuntap *tt;
    
    tt = malloc (sizeof (struct tuntap));
    clear_tuntap (tt);
    
    tt->type = dev_type_enum (dev, dev_type);
    tt->topology = topology;
    
    if (ifconfig_local_parm && ifconfig_remote_netmask_parm)
    {
        bool tun = false;
        const char *ifconfig_local = NULL;
        const char *ifconfig_remote_netmask = NULL;
        const char *ifconfig_broadcast = NULL;
        
        /*
         * We only handle TUN/TAP devices here, not --dev null devices.
         */
        tun = is_tun_p2p (tt);
        
        /*
         * Convert arguments to binary IPv4 addresses.
         */
        
        tt->local = getaddr (
                             GETADDR_RESOLVE
                             | GETADDR_HOST_ORDER
                             | GETADDR_FATAL_ON_SIGNAL
                             | GETADDR_FATAL,
                             ifconfig_local_parm,
                             0,
                             NULL,
                             NULL);
        
        tt->remote_netmask = getaddr (
                                      (tun ? GETADDR_RESOLVE : 0)
                                      | GETADDR_HOST_ORDER
                                      | GETADDR_FATAL_ON_SIGNAL
                                      | GETADDR_FATAL,
                                      ifconfig_remote_netmask_parm,
                                      0,
                                      NULL,
                                      NULL);
        
        /*
         * Look for common errors in --ifconfig parms
         */
        if (strict_warn)
        {
            ifconfig_sanity_check (tt->type == DEV_TYPE_TUN, tt->remote_netmask, tt->topology);
            
            /*
             * If local_public or remote_public addresses are defined,
             * make sure they do not clash with our virtual subnet.
             */
            
            check_addr_clash ("local",
                              tt->type,
                              local_public,
                              tt->local,
                              tt->remote_netmask);
            
            check_addr_clash ("remote",
                              tt->type,
                              remote_public,
                              tt->local,
                              tt->remote_netmask);
            
            if (tt->type == DEV_TYPE_TAP || (tt->type == DEV_TYPE_TUN && tt->topology == TOP_SUBNET))
                check_subnet_conflict (tt->local, tt->remote_netmask, "TUN/TAP adapter");
            else if (tt->type == DEV_TYPE_TUN)
                check_subnet_conflict (tt->local, IPV4_NETMASK_HOST, "TUN/TAP adapter");
        }
        
        
        
        tt->did_ifconfig_setup = true;
    }
    
    if (ifconfig_ipv6_local_parm && ifconfig_ipv6_remote_parm)
    {
        const char *ifconfig_ipv6_local = NULL;
        const char *ifconfig_ipv6_remote = NULL;
        
        /*
         * Convert arguments to binary IPv6 addresses.
         */
        
        if ( inet_pton( AF_INET6, ifconfig_ipv6_local_parm, &tt->local_ipv6 ) != 1 ||
            inet_pton( AF_INET6, ifconfig_ipv6_remote_parm, &tt->remote_ipv6 ) != 1 )
        {
            msg( M_FATAL, "init_tun: problem converting IPv6 ifconfig addresses %s and %s to binary", ifconfig_ipv6_local_parm, ifconfig_ipv6_remote_parm );
        }
        tt->netbits_ipv6 = ifconfig_ipv6_netbits_parm;
        
        /*
         * Set ifconfig parameters
         */
        ifconfig_ipv6_local = print_in6_addr (tt->local_ipv6, 0, &gc);
        ifconfig_ipv6_remote = print_in6_addr (tt->remote_ipv6, 0, &gc);
        
        /*
         * Set environmental variables with ifconfig parameters.
         */
        if (es)
        {
            setenv_str (es, "ifconfig_ipv6_local", ifconfig_ipv6_local);
            setenv_int (es, "ifconfig_ipv6_netbits", tt->netbits_ipv6);
            setenv_str (es, "ifconfig_ipv6_remote", ifconfig_ipv6_remote);
        }
        tt->did_ifconfig_ipv6_setup = true;
    }
    
    gc_free (&gc);
    return tt;
}

/*
 * Platform specific tun initializations
 */
void
init_tun_post (struct tuntap *tt,
               const struct frame *frame,
               const struct tuntap_options *options)
{
    tt->options = *options;
}

/* some of the platforms will auto-add a "network route" pointing
 * to the interface on "ifconfig tunX 2001:db8::1/64", others need
 * an extra call to "route add..."
 * -> helper function to simplify code below
 */
void add_route_connected_v6_net(struct tuntap * tt,
                                const struct env_set *es)
{
    struct route_ipv6 r6;
    
    r6.defined = true;
    r6.network = tt->local_ipv6;
    r6.netbits = tt->netbits_ipv6;
    r6.gateway = tt->local_ipv6;
    r6.metric  = 0;			/* connected route */
    r6.metric_defined = true;
    add_route_ipv6 (&r6, tt, 0, es);
}

void delete_route_connected_v6_net(struct tuntap * tt,
                                   const struct env_set *es)
{
    struct route_ipv6 r6;
    
    r6.defined = true;
    r6.network = tt->local_ipv6;
    r6.netbits = tt->netbits_ipv6;
    r6.gateway = tt->local_ipv6;
    r6.metric  = 0;			/* connected route */
    r6.metric_defined = true;
    delete_route_ipv6 (&r6, tt, 0, es);
}

/*
 * Open tun/tap device, ifconfig, call up script, etc.
 */

static bool
do_open_tun ()
{
    bool ret = false;
    
    c->c2.ipv4_tun = (!c->options.tun_ipv6
                      && is_dev_type (c->options.dev, c->options.dev_type, "tun"));
    
#ifndef TARGET_ANDROID
    if (!c->c1.tuntap)
    {
#endif
        
#ifdef TARGET_ANDROID
        /* If we emulate persist-tun on android we still have to open a new tun and
         then close the old */
        int oldtunfd=-1;
        if (c->c1.tuntap)
            oldtunfd = c->c1.tuntap->fd;
#endif
        
        /* initialize (but do not open) tun/tap object */
        do_init_tun (c);
        
        /* allocate route list structure */
        do_alloc_route_list (c);
        
        /* parse and resolve the route option list */
        if (c->options.routes && c->c1.route_list && c->c2.link_socket)
            do_init_route_list (&c->options, c->c1.route_list, &c->c2.link_socket->info, false, c->c2.es);
        if (c->options.routes_ipv6 && c->c1.route_ipv6_list )
            do_init_route_ipv6_list (&c->options, c->c1.route_ipv6_list, false, c->c2.es);
        
        /* do ifconfig */
        if (!c->options.ifconfig_noexec
            && ifconfig_order () == IFCONFIG_BEFORE_TUN_OPEN)
        {
            /* guess actual tun/tap unit number that will be returned
             by open_tun */
            const char *guess = guess_tuntap_dev (c->options.dev,
                                                  c->options.dev_type,
                                                  c->options.dev_node,
                                                  &gc);
            do_ifconfig (c->c1.tuntap, guess, TUN_MTU_SIZE (&c->c2.frame), c->c2.es);
        }
        
        /* possibly add routes */
        if (route_order() == ROUTE_BEFORE_TUN) {
            /* Ignore route_delay, would cause ROUTE_BEFORE_TUN to be ignored */
            do_route (&c->options, c->c1.route_list, c->c1.route_ipv6_list,
                      c->c1.tuntap, c->plugins, c->c2.es);
        }
        
        /* open the tun device */
        open_tun (c->options.dev, c->options.dev_type, c->options.dev_node,
                  c->c1.tuntap);
#ifdef TARGET_ANDROID
        if (oldtunfd>=0)
            close(oldtunfd);
#endif
        /* set the hardware address */
        if (c->options.lladdr)
            set_lladdr(c->c1.tuntap->actual_name, c->options.lladdr, c->c2.es);
        
        /* do ifconfig */
        if (!c->options.ifconfig_noexec
            && ifconfig_order () == IFCONFIG_AFTER_TUN_OPEN)
        {
            do_ifconfig (c->c1.tuntap, c->c1.tuntap->actual_name, TUN_MTU_SIZE (&c->c2.frame), c->c2.es);
        }
        
        /* run the up script */
        run_up_down (c->options.up_script,
                     c->plugins,
                     OPENVPN_PLUGIN_UP,
                     c->c1.tuntap->actual_name,
                     dev_type_string (c->options.dev, c->options.dev_type),
                     TUN_MTU_SIZE (&c->c2.frame),
                     EXPANDED_SIZE (&c->c2.frame),
                     print_in_addr_t (c->c1.tuntap->local, IA_EMPTY_IF_UNDEF, &gc),
                     print_in_addr_t (c->c1.tuntap->remote_netmask, IA_EMPTY_IF_UNDEF, &gc),
                     "init",
                     NULL,
                     "up",
                     c->c2.es);
        
        /* possibly add routes */
        if ((route_order() == ROUTE_AFTER_TUN) && (!c->options.route_delay_defined))
            do_route (&c->options, c->c1.route_list, c->c1.route_ipv6_list,
                      c->c1.tuntap, c->plugins, c->c2.es);
        
        /*
         * Did tun/tap driver give us an MTU?
         */
        if (c->c1.tuntap->post_open_mtu)
            frame_set_mtu_dynamic (&c->c2.frame,
                                   c->c1.tuntap->post_open_mtu,
                                   SET_MTU_TUN | SET_MTU_UPPER_BOUND);
        
        ret = true;
        static_context = c;
#ifndef TARGET_ANDROID
    }
    else
    {
        msg (M_INFO, "Preserving previous TUN/TAP instance: %s",
             c->c1.tuntap->actual_name);
        
        /* run the up script if user specified --up-restart */
        if (c->options.up_restart)
            run_up_down (c->options.up_script,
                         c->plugins,
                         OPENVPN_PLUGIN_UP,
                         c->c1.tuntap->actual_name,
                         dev_type_string (c->options.dev, c->options.dev_type),
                         TUN_MTU_SIZE (&c->c2.frame),
                         EXPANDED_SIZE (&c->c2.frame),
                         print_in_addr_t (c->c1.tuntap->local, IA_EMPTY_IF_UNDEF, &gc),
                         print_in_addr_t (c->c1.tuntap->remote_netmask, IA_EMPTY_IF_UNDEF, &gc),
                         "restart",
                         NULL,
                         "up",
                         c->c2.es);
    }
#endif
    gc_free (&gc);
    return ret;
}

/*
 * Close TUN/TAP device
 */

static void
do_close_tun_simple (struct context *c)
{
    msg (D_CLOSE, "Closing TUN/TAP interface");
    close_tun (c->c1.tuntap);
    c->c1.tuntap = NULL;
    c->c1.tuntap_owned = false;
#if P2MP
    save_pulled_options_digest (c, NULL); /* delete C1-saved pulled_options_digest */
#endif
}

static void
do_close_tun (struct context *c, bool force)
{
    struct gc_arena gc = gc_new ();
    if (c->c1.tuntap && c->c1.tuntap_owned)
    {
        const char *tuntap_actual = string_alloc (c->c1.tuntap->actual_name, &gc);
        const in_addr_t local = c->c1.tuntap->local;
        const in_addr_t remote_netmask = c->c1.tuntap->remote_netmask;
        
        if (force || !(c->sig->signal_received == SIGUSR1 && c->options.persist_tun))
        {
            static_context = NULL;
            
#ifdef ENABLE_MANAGEMENT
            /* tell management layer we are about to close the TUN/TAP device */
            if (management)
            {
                management_pre_tunnel_close (management);
                management_up_down (management, "DOWN", c->c2.es);
            }
#endif
            
            /* delete any routes we added */
            if (c->c1.route_list || c->c1.route_ipv6_list )
            {
                run_up_down (c->options.route_predown_script,
                             c->plugins,
                             OPENVPN_PLUGIN_ROUTE_PREDOWN,
                             tuntap_actual,
                             NULL,
                             TUN_MTU_SIZE (&c->c2.frame),
                             EXPANDED_SIZE (&c->c2.frame),
                             print_in_addr_t (local, IA_EMPTY_IF_UNDEF, &gc),
                             print_in_addr_t (remote_netmask, IA_EMPTY_IF_UNDEF, &gc),
                             "init",
                             signal_description (c->sig->signal_received,
                                                 c->sig->signal_text),
                             "route-pre-down",
                             c->c2.es);
                
                delete_routes (c->c1.route_list, c->c1.route_ipv6_list,
                               c->c1.tuntap, ROUTE_OPTION_FLAGS (&c->options), c->c2.es);
            }
            
            /* actually close tun/tap device based on --down-pre flag */
            if (!c->options.down_pre)
                do_close_tun_simple (c);
            
            /* Run the down script -- note that it will run at reduced
             privilege if, for example, "--user nobody" was used. */
            run_up_down (c->options.down_script,
                         c->plugins,
                         OPENVPN_PLUGIN_DOWN,
                         tuntap_actual,
                         NULL,
                         TUN_MTU_SIZE (&c->c2.frame),
                         EXPANDED_SIZE (&c->c2.frame),
                         print_in_addr_t (local, IA_EMPTY_IF_UNDEF, &gc),
                         print_in_addr_t (remote_netmask, IA_EMPTY_IF_UNDEF, &gc),
                         "init",
                         signal_description (c->sig->signal_received,
                                             c->sig->signal_text),
                         "down",
                         c->c2.es);
            
            /* actually close tun/tap device based on --down-pre flag */
            if (c->options.down_pre)
                do_close_tun_simple (c);
        }
        else
        {
            /* run the down script on this restart if --up-restart was specified */
            if (c->options.up_restart)
                run_up_down (c->options.down_script,
                             c->plugins,
                             OPENVPN_PLUGIN_DOWN,
                             tuntap_actual,
                             NULL,
                             TUN_MTU_SIZE (&c->c2.frame),
                             EXPANDED_SIZE (&c->c2.frame),
                             print_in_addr_t (local, IA_EMPTY_IF_UNDEF, &gc),
                             print_in_addr_t (remote_netmask, IA_EMPTY_IF_UNDEF, &gc),
                             "restart",
                             signal_description (c->sig->signal_received,
                                                 c->sig->signal_text),
                             "down",
                             c->c2.es);
        }
    }
    gc_free (&gc);
}

void
tun_abort()
{
    struct context *c = static_context;
    if (c)
    {
        static_context = NULL;
        do_close_tun (c, true);
    }
}

@implementation UTUN

@end
