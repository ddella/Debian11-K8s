# BGP peering not established
After checking the BGP peering with Calico, I found that the nodes hadn't established a BGP connection. See the output of the command `sudo kubectl calico node status` below:

The `INFO` column should be `Established`:
```
Calico process is running.

IPv4 BGP status
+---------------+-------------------+-------+----------+-------------+
| PEER ADDRESS  |     PEER TYPE     | STATE |  SINCE   |    INFO     |
+---------------+-------------------+-------+----------+-------------+
| 10.250.12.185 | node-to-node mesh | start | 17:37:59 | Connect     |
| 10.250.12.186 | node-to-node mesh | start | 17:37:59 | Connect     |
| 10.250.12.187 | node-to-node mesh | start | 17:37:59 | Connect     |
| 10.250.12.1   | node specific     | up    | 17:38:13 | Established |
+---------------+-------------------+-------+----------+-------------+

IPv6 BGP status
No IPv6 peers found.
```

>We see that BGP sessions have a status of `Connect` which is not established.

## Check Calico nodes logs
Check the Calico node logs for any BGP errors:
```sh
kubectl get pods -n calico-system
```

The output will look like this:
```
NAME                                       READY   STATUS    RESTARTS        AGE
calico-kube-controllers-656675bd4f-t6lcr   1/1     Running   1 (17d ago)     17d
calico-node-gw7h4                          1/1     Running   0               3m54s
calico-node-hksbf                          1/1     Running   0               5m17s
calico-node-s79mm                          1/1     Running   0               3m13s
calico-node-zglkc                          1/1     Running   0               4m36s
calico-typha-5d9685f8d6-552l4              1/1     Running   6 (3d6h ago)    17d
calico-typha-5d9685f8d6-f4nmk              1/1     Running   11 (3d6h ago)   17d
csi-node-driver-6nb9l                      2/2     Running   6 (3d6h ago)    17d
csi-node-driver-89t5b                      2/2     Running   6 (3d6h ago)    17d
csi-node-driver-cwnbq                      2/2     Running   4 (3d6h ago)    17d
csi-node-driver-zs8q7                      2/2     Running   2 (17d ago)     17d
```

    ```sh
    kubectl logs -n calico-system calico-node-gw7h4 | grep -i BIRD
    ```

    Output:
    ```
    [...]
    bird: Mesh_10_4_0_1: State changed to start
    2023-06-22 11:25:26.414 [INFO][81] confd/resource.go 277: Target config /etc/calico/confd/config/bird.cfg has been updated due to change in key: /calico/bgp/v1/host
    bird: Mesh_10_250_12_180: State changed to down
    bird: Reconfigured
    bird: Next hop address 10.255.108.128 resolvable through recursive route for 10.255.108.128/26
    bird: Next hop address 10.255.108.128 resolvable through recursive route for 10.255.108.128/26
    bird: BGP: Unexpected connect from unknown address 10.250.12.180 (port 60008)
    ```

## Describe Pods
I checked the Pod on the control plane with `describe`:
```sh
kubectl describe pods -n calico-system calico-node-gw7h4
```

Something was wrong here:
```
[...]
calico/node is not ready: BIRD is not ready: BGP not established with 10.4.0.1
[...]
```

This Pod gave me a bit of a different message. It happned to be the control plane. According to the message above the IP address is wrong:
```sh
kubectl describe pods -n calico-system calico-node-hksbf
```

Something was wrong here:
```
[...]
calico/node is not ready: BIRD is not ready: BGP not established with 10.250.12.185,10.250.12.186,10.250.12.187
[...]
```

## Check that nodes
Check that nodes listen to port TCP/179 with the command:
```sh
sudo ss -tunlp | grep 179
```

Output of `ss`:
```
tcp   LISTEN 0      8            0.0.0.0:179        0.0.0.0:*    users:(("bird",pid=479605,fd=7))             
```

>Use `sudo` as it will give you a bit more information


```sh
sudo lsof -nP -iTCP:179 -sTCP:LISTEN
```

Output of `lsof`:
```
COMMAND    PID USER   FD   TYPE   DEVICE SIZE/OFF NODE NAME
bird    479605 root    7u  IPv4 41993722      0t0  TCP *:179 (LISTEN)
```

## BIRD peering config
Check the BIRD peering config that Calico has generated, to see if it is using the IPs that you intend:
```sh
kubectl exec calico-node-hksbf -n calico-system cat /etc/calico/confd/config/bird.cfg
```

Didn't seemed right for the `control-plane`. The source should have been `10.250.12.180`
```
[...]
router id 10.4.0.1;
[...]
# For peer /bgp/v1/host/s666dan4051/ip_addr_v4
# Skipping ourselves (10.4.0.1)
[...]
```

## How to Change the Default Setting for `nodeAddressAutodetectionV4` in Calico
Validate current install settings for `nodeAddressAutodetectionV4` with the command:
```sh
kubectl get installations default -o yaml
```

```
[...]
spec:
    nodeAddressAutodetectionV4:
      firstFound: true
[...]
status:
      nodeAddressAutodetectionV4:
        firstFound: true
[...]
```

Get all the nodes:
```sh
sudo -E calicoctl get node
```

Output:
```
NAME          
s666dan4051   
s666dan4151   
s666dan4152   
s666dan4153   
```

Check the control plane node for the BGP IP address:
```sh
sudo -E calicoctl get node s666dan4051 -o yaml
```

In the output below, we see that the address `10.4.0.1/24` is wrong:
```
spec:
  addresses:
  - address: 10.4.0.1/24
    type: CalicoNodeIP
  - address: 10.250.12.180
    type: InternalIP
  bgp:
    ipv4Address: 10.4.0.1/24
```

We need to modify the Calico Operator Installation with the command:
```sh
kubectl edit installation default
```

Modify the `nodeAddressAutodetectionV4` for `kubernetes: NodeInternalIP`. The command above is opens the configuration file in `vi`. Your configuration should look like the one below. Replace the line `firstFound: true` with `kubernetes: NodeInternalIP`:

```
spec:
[...]
    multiInterfaceMode: None
    nodeAddressAutodetectionV4:
    # The following also worked for me since my interface is 'ens160'
      # interface: ens.*
      kubernetes: NodeInternalIP
[...]
```

>After saving the file (:wq), you should see the all the Pods `calico-node-xxxx` restarting. When it's done, check the BGP peering. Be patient, in could take up to 1-2 minutes 😀

```sh
kubectl set env daemonset/calico-node -n calico-system --list | grep IP_AUTODETECTION_METHOD
```

Output as expected:
```
IP_AUTODETECTION_METHOD=kubernetes-internal-ip
```

## Verification
Check the BGP peer status with the command:
```sh
sudo kubectl calico node status
```

In my case, the modification fixed my problem, see the output:
```
Calico process is running.

IPv4 BGP status
+---------------+-------------------+-------+----------+-------------+
| PEER ADDRESS  |     PEER TYPE     | STATE |  SINCE   |    INFO     |
+---------------+-------------------+-------+----------+-------------+
| 10.250.12.185 | node-to-node mesh | up    | 17:16:49 | Established |
| 10.250.12.186 | node-to-node mesh | up    | 17:16:39 | Established |
| 10.250.12.187 | node-to-node mesh | up    | 17:17:02 | Established |
| 10.250.12.1   | node specific     | up    | 17:16:29 | Established |
+---------------+-------------------+-------+----------+-------------+

IPv6 BGP status
No IPv6 peers found.
```

Check the control plane node for the BGP IP address:
```sh
sudo -E calicoctl get node s666dan4051 -o yaml
```

In the output below, we see that the address `10.4.0.1/24` has been replaced by the real interface IP:
```
spec:
  addresses:
  - address: 10.250.12.180/24
    type: CalicoNodeIP
  - address: 10.250.12.180
    type: InternalIP
  bgp:
    ipv4Address: 10.250.12.180/24
```


Check the logs of the Pods. You shouldn't see anymore error messages:
```sh
kubectl logs -f --tail=15 --namespace=calico-system calico-node-bhjqf
```

You can also check BIRD’s running state, as regards establishing those peerings:
```sh
kubectl exec calico-node-6d8lc -n calico-system -- birdcl -s /var/run/calico/bird.ctl show protocols all
```

This is a lengthy output:
```
Defaulted container "calico-node" out of: calico-node, flexvol-driver (init), install-cni (init)
BIRD v0.3.3+birdv1.6.8 ready.
name     proto    table    state  since       info
static1  Static   master   up     18:12:19    
  Preference:     200
  Input filter:   ACCEPT
  Output filter:  REJECT
  Routes:         2 imported, 0 exported, 2 preferred
  Route change stats:     received   rejected   filtered    ignored   accepted
    Import updates:              2          0          0          0          2
    Import withdraws:            0          0        ---          0          0
    Export updates:              0          0          0        ---          0
    Export withdraws:            0        ---        ---        ---          0

kernel1  Kernel   master   up     18:12:19    
  Preference:     10
  Input filter:   ACCEPT
  Output filter:  calico_kernel_programming
  Routes:         11 imported, 0 exported, 7 preferred
  Route change stats:     received   rejected   filtered    ignored   accepted
    Import updates:             11          0          0          0         11
    Import withdraws:            0          0        ---          0          0
    Export updates:             15         10          5        ---          0
    Export withdraws:            0        ---        ---        ---          0

device1  Device   master   up     18:12:19    
  Preference:     240
  Input filter:   ACCEPT
  Output filter:  REJECT
  Routes:         0 imported, 0 exported, 0 preferred
  Route change stats:     received   rejected   filtered    ignored   accepted
    Import updates:              0          0          0          0          0
    Import withdraws:            0          0        ---          0          0
    Export updates:              0          0          0        ---          0
    Export withdraws:            0        ---        ---        ---          0

direct1  Direct   master   up     18:12:19    
  Preference:     240
  Input filter:   ACCEPT
  Output filter:  REJECT
  Routes:         3 imported, 0 exported, 3 preferred
  Route change stats:     received   rejected   filtered    ignored   accepted
    Import updates:              3          0          0          0          3
    Import withdraws:            0          0        ---          0          0
    Export updates:              0          0          0        ---          0
    Export withdraws:            0        ---        ---        ---          0

Mesh_10_250_12_180 BGP      master   up     18:12:31    Established   
  Description:    Connection to BGP peer
  Preference:     100
  Input filter:   ACCEPT
  Output filter:  (unnamed)
  Routes:         5 imported, 6 exported, 3 preferred
  Route change stats:     received   rejected   filtered    ignored   accepted
    Import updates:             10          0          0          5          5
    Import withdraws:            0          0        ---          0          0
    Export updates:             62         30         20        ---         12
    Export withdraws:            0        ---        ---        ---          0
  BGP state:          Established
    Neighbor address: 10.250.12.180
    Neighbor AS:      65001
    Neighbor ID:      10.250.12.180
    Neighbor caps:    refresh enhanced-refresh restart-able llgr-aware AS4 add-path-rx add-path-tx
    Session:          internal multihop AS4 add-path-rx add-path-tx
    Source address:   10.250.12.186
    Hold timer:       172/240
    Keepalive timer:  67/80

Mesh_10_250_12_185 BGP      master   up     18:12:21    Established   
  Description:    Connection to BGP peer
  Preference:     100
  Input filter:   ACCEPT
  Output filter:  (unnamed)
  Routes:         5 imported, 6 exported, 0 preferred
  Route change stats:     received   rejected   filtered    ignored   accepted
    Import updates:              5          0          0          0          5
    Import withdraws:            0          0        ---          0          0
    Export updates:             31         15         10        ---          6
    Export withdraws:            0        ---        ---        ---          0
  BGP state:          Established
    Neighbor address: 10.250.12.185
    Neighbor AS:      65001
    Neighbor ID:      10.250.12.185
    Neighbor caps:    refresh enhanced-refresh restart-able llgr-aware AS4 add-path-rx add-path-tx
    Session:          internal multihop AS4 add-path-rx add-path-tx
    Source address:   10.250.12.186
    Hold timer:       179/240
    Keepalive timer:  3/80

Mesh_10_250_12_187 BGP      master   up     18:12:44    Established   
  Description:    Connection to BGP peer
  Preference:     100
  Input filter:   ACCEPT
  Output filter:  (unnamed)
  Routes:         5 imported, 6 exported, 0 preferred
  Route change stats:     received   rejected   filtered    ignored   accepted
    Import updates:             10          0          0          5          5
    Import withdraws:            0          0        ---          0          0
    Export updates:             62         30         20        ---         12
    Export withdraws:            0        ---        ---        ---          0
  BGP state:          Established
    Neighbor address: 10.250.12.187
    Neighbor AS:      65001
    Neighbor ID:      10.250.12.187
    Neighbor caps:    refresh enhanced-refresh restart-able llgr-aware AS4 add-path-rx add-path-tx
    Session:          internal multihop AS4 add-path-rx add-path-tx
    Source address:   10.250.12.186
    Hold timer:       150/240
    Keepalive timer:  31/80
```

# Reference
https://tigeraio.my.site.com/help/s/article/How-to-disable
https://stackoverflow.com/questions/54465963/calico-node-is-not-ready-bird-is-not-ready-bgp-not-established
