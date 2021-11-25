/*
 * Copyright (c) 2000-2019 University of Utah and the Flux Group.
 * 
 * {{{EMULAB-LICENSE
 * 
 * This file is part of the Emulab network testbed software.
 * 
 * This file is free software: you can redistribute it and/or modify it
 * under the terms of the GNU Affero General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or (at
 * your option) any later version.
 * 
 * This file is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public
 * License for more details.
 * 
 * You should have received a copy of the GNU Affero General Public License
 * along with this file.  If not, see <http://www.gnu.org/licenses/>.
 * 
 * }}}
 */

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/moduleparam.h>
#include <linux/kthread.h>
#include <linux/sched.h>
#include <linux/reboot.h>
#include <linux/sysctl.h>
#include <linux/netfilter.h>
#include <linux/netfilter_ipv4.h>
#include <linux/skbuff.h>
#include <linux/udp.h>
#include <linux/ip.h>
#include <linux/icmp.h>
#include <net/ip.h>
#include <net/net_namespace.h>
#include <linux/version.h>
#include <linux/limits.h>

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Flux Research Group");
MODULE_VERSION("3.3.0");

#if defined(__aarch64__) || defined(__powerpc64__)
#define IPOD_QUEUE_RESTART
#endif

#ifdef IPOD_QUEUE_RESTART
#include <linux/workqueue.h>

static struct workqueue_struct *restart_queue;

static void restart_work_func(struct work_struct *work)
{
        printk(KERN_CRIT "IPOD: restarting (delayed)...\n");
        emergency_restart();
}

DECLARE_WORK(restart_work,restart_work_func);
#endif

#define IPOD_ICMP_TYPE 6
#define IPOD_ICMP_CODE 6

int sysctl_ipod_version = 3;
int sysctl_ipod_enabled = 0;
u32 sysctl_ipod_host = 0xffffffff;
u32 sysctl_ipod_mask = 0xffffffff;
char sysctl_ipod_key[32+1] = { "SETMETOSOMETHINGTHIRTYTWOBYTES!!" };

#define IPOD_CHECK_KEY() \
        (sysctl_ipod_key[0] != 0)
#define IPOD_VALID_KEY(d) \
        (strncmp(sysctl_ipod_key,(char *)(d),sizeof(sysctl_ipod_key) - 1) == 0)

#if LINUX_VERSION_CODE < KERNEL_VERSION(2,6,33)
#define __PHP &
#else
#define __PHP
#endif

/*
 * Register the simple icmp table in /proc/sys/net/ipv4 .  This way, if
 * somebody else ever adds a net.ipv4.icmp table, like net.ipv6.icmp, we
 * can just add directly to that.
 *
 * Then register the ipod table inside the just-registered icmp table.
 */
static struct ctl_table ipod_table[] = {
    { .procname = "icmp_ipod_version",
      .data = &sysctl_ipod_version,
      .maxlen = sizeof(int),
      .mode = 0444,
      .proc_handler = __PHP proc_dointvec,
    },
    { .procname = "icmp_ipod_enabled",
      .data = &sysctl_ipod_enabled,
      .maxlen = sizeof(int),
      .mode = 0644,
      .proc_handler = __PHP proc_dointvec,
    },
    { .procname = "icmp_ipod_host",
      .data = &sysctl_ipod_host,
      .maxlen = sizeof(u32),
      .mode = 0644,
      .proc_handler = __PHP proc_dointvec,
    },
    { .procname = "icmp_ipod_mask",
      .data = &sysctl_ipod_mask,
      .maxlen = sizeof(u32),
      .mode = 0644,
      .proc_handler = __PHP proc_dointvec,
    },
    { .procname = "icmp_ipod_key",
      .data = &sysctl_ipod_key,
      .maxlen = sizeof(sysctl_ipod_key),
      .mode = 0600,
      .proc_handler = __PHP proc_dostring,
    },
    { .procname = NULL,
      .data = NULL,
      .proc_handler = NULL,
    },
};

#if LINUX_VERSION_CODE < KERNEL_VERSION(3,5,0)
static struct ctl_path ipod_path[] = {
    {
	.procname = "net",
#if LINUX_VERSION_CODE < KERNEL_VERSION(2,6,33)
	.ctl_name = CTL_NET,
#endif
    },
    {
	.procname = "ipv4",
#if LINUX_VERSION_CODE < KERNEL_VERSION(2,6,33)
	.ctl_name = NET_IPV4,
#endif
    },
    { },
};
#endif

static struct ctl_table_header *ipod_table_header;


static unsigned int ipod_hook_fn(
#if LINUX_VERSION_CODE < KERNEL_VERSION(3,13,0)
				 unsigned int hooknum,
#elif LINUX_VERSION_CODE < KERNEL_VERSION(4,4,0)
				 const struct nf_hook_ops *ops,
#else
				 void *priv,
#endif
				 struct sk_buff *skb,
#if LINUX_VERSION_CODE < KERNEL_VERSION(4,1,0)
				 const struct net_device *in,
				 const struct net_device *out,
				 int (*okfn)(struct sk_buff *)
#else
				 const struct nf_hook_state *state
#endif
				 );

static struct nf_hook_ops ipod_hook_ops = {
    .hook = ipod_hook_fn,
#if LINUX_VERSION_CODE < KERNEL_VERSION(4,1,0)
    .owner = THIS_MODULE,
#endif
    .hooknum = NF_INET_LOCAL_IN,
    .pf = PF_INET,
    .priority = NF_IP_PRI_FIRST,
};

static unsigned int ipod_hook_fn(
#if LINUX_VERSION_CODE < KERNEL_VERSION(3,13,0)
				 unsigned int hooknum,
#elif LINUX_VERSION_CODE < KERNEL_VERSION(4,4,0)
				 const struct nf_hook_ops *ops,
#else
				 void *priv,
#endif
				 struct sk_buff *skb,
#if LINUX_VERSION_CODE < KERNEL_VERSION(4,1,0)
				 const struct net_device *in,
				 const struct net_device *out,
				 int (*okfn)(struct sk_buff *)
#else
				 const struct nf_hook_state *state
#endif
				 ) {
    struct iphdr *iph;
    struct icmphdr *icmph;
    int doit = 0;
    int hlen = 0;
    char *data;

    if (!sysctl_ipod_enabled) 
	return NF_ACCEPT;

    hlen = sizeof(*iph);
    if (!pskb_may_pull(skb,hlen))
	return NF_ACCEPT;

    iph = (struct iphdr *)skb_network_header(skb);

    if (iph->protocol != IPPROTO_ICMP)
	return NF_ACCEPT;

    /* Check again based on the IP header length. */
    hlen = iph->ihl * 4 + sizeof(*icmph);
    if (!pskb_may_pull(skb,hlen))
	return NF_ACCEPT;

    /* Grab this again to guard against skb linearization in pskb_may_pull . */
    iph = (struct iphdr *)skb_network_header(skb);

    /*
     * icmp_hdr(skb) seems invalid (yet) since the hook is
     * pre-transport; calculate it manually.
     */
    icmph = (struct icmphdr *)((char *)iph + iph->ihl * 4);

    if (!icmph)
	return NF_ACCEPT;

    if (icmph->type != IPOD_ICMP_TYPE || icmph->code != IPOD_ICMP_CODE) 
	return NF_ACCEPT;

    printk(KERN_INFO "IPOD: got type=%d, code=%d, iplen=%d, host=%pI4\n",
	   icmph->type,icmph->code,ntohs(iph->tot_len),&iph->saddr);

    if (sysctl_ipod_host != 0xffffffff &&
	(ntohl(iph->saddr) & sysctl_ipod_mask) == sysctl_ipod_host) {
	/*
	 * Now check the key if enabled.  If packet doesn't contain
	 * enough data or key is otherwise invalid, ignore.
	 */
	if (IPOD_CHECK_KEY()) {
	    if (pskb_may_pull(skb,hlen + sizeof(sysctl_ipod_key) - 1)) {
		/* Guard against linearization, again. */
		iph = (struct iphdr *)skb_network_header(skb);
		icmph = (struct icmphdr *)((char *)iph + iph->ihl * 4);
		data = (char *)((char *)icmph + sizeof(*icmph));

		if ((IPOD_VALID_KEY(data)))
		    doit = 1;
	    }
	}
	else 
	    doit = 1;
    }

    if (doit) {
	sysctl_ipod_enabled = 0;
	printk(KERN_CRIT "IPOD: reboot forced by %pI4...\n",&iph->saddr);
#ifdef IPOD_QUEUE_RESTART
	queue_work(restart_queue,&restart_work);
#else
	emergency_restart();
#endif
	return NF_DROP;
    }
    else {
	printk(KERN_WARNING "IPOD: from %pI4 rejected\n",&iph->saddr);
	return NF_DROP;
    }

    return NF_ACCEPT;
}

static int __init ipod_init_module(void) {
    int rc;

    printk(KERN_INFO "initializing IPOD\n");

    /*
     * Register our sysctls.
     */
#if LINUX_VERSION_CODE < KERNEL_VERSION(3,5,0)
    ipod_table_header = register_net_sysctl_table(&init_net,ipod_path,ipod_table);
#else
    ipod_table_header = register_net_sysctl(&init_net,"net/ipv4",ipod_table);
#endif
    if (!ipod_table_header) {
	printk(KERN_ERR "could not register net.ipv4.icmp[.ipod.*]!\n");
	return -1;
    }

    /*
     * Register our netfilter hook function.
     */
#if LINUX_VERSION_CODE >= KERNEL_VERSION(4,13,0)
    rc = nf_register_net_hooks(&init_net,&ipod_hook_ops,1);
#else
    rc = nf_register_hooks(&ipod_hook_ops,1);
#endif
    if (rc) {
	printk(KERN_ERR "netfilter registration failed (%d)!\n",rc);
	unregister_net_sysctl_table(ipod_table_header);
	return -1;
    }

#ifdef IPOD_QUEUE_RESTART
    restart_queue = create_singlethread_workqueue("ipod_restart_queue");
#endif

    return 0;
}

static void __exit ipod_cleanup_module(void) {
    printk(KERN_INFO "removing IPOD\n");

#ifdef IPOD_QUEUE_RESTART
    cancel_work_sync(&restart_work);
    destroy_workqueue(restart_queue);
#endif

#if LINUX_VERSION_CODE >= KERNEL_VERSION(4,13,0)
    nf_unregister_net_hooks(&init_net,&ipod_hook_ops,1);
#else
    nf_unregister_hooks(&ipod_hook_ops,1);
#endif
    unregister_net_sysctl_table(ipod_table_header);
}

module_init(ipod_init_module);
module_exit(ipod_cleanup_module);
