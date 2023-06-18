Create a new paertition with 'fdisk /dev/sda'

daniel@k8s-template ~ $ df -h
Filesystem                         Size  Used Avail Use% Mounted on
tmpfs                              1.2G  1.7M  1.2G   1% /run
/dev/mapper/ubuntu--vg-ubuntu--lv   18G   18G     0 100% /
tmpfs                              5.9G     0  5.9G   0% /dev/shm
tmpfs                              5.0M     0  5.0M   0% /run/lock
tmpfs                              5.9G     0  5.9G   0% /run/qemu
/dev/sda2                          1.8G  153M  1.5G  10% /boot
tmpfs                              1.2G  4.0K  1.2G   1% /run/user/1000

daniel@k8s-template ~ $ sudo lsblk
NAME                      MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
loop0                       7:0    0  63.5M  1 loop /snap/core20/1891
loop1                       7:1    0 106.9M  1 loop /snap/multipass/8465
loop2                       7:2    0  53.3M  1 loop /snap/snapd/19361
sda                         8:0    0    40G  0 disk 
├─sda1                      8:1    0     1M  0 part 
├─sda2                      8:2    0   1.8G  0 part /boot
├─sda3                      8:3    0  18.2G  0 part 
│ └─ubuntu--vg-ubuntu--lv 253:0    0  18.2G  0 lvm  /
└─sda4                      8:4    0    20G  0 part 
sr0                        11:0    1   1.8G  0 rom  

daniel@k8s-template ~ $ sudo pvcreate  /dev/sda4
  Physical volume "/dev/sda4" successfully created.

daniel@k8s-template ~ $ sudo pvs
  PV         VG        Fmt  Attr PSize  PFree 
  /dev/sda3  ubuntu-vg lvm2 a--  18.22g     0 
  /dev/sda4            lvm2 ---  20.00g 20.00g

daniel@k8s-template ~ $ sudo vgextend ubuntu-vg /dev/sda4
  Volume group "ubuntu-vg" successfully extended

daniel@k8s-template ~ $ sudo vgs
  VG        #PV #LV #SN Attr   VSize   VFree  
  ubuntu-vg   2   1   0 wz--n- <38.22g <20.00g

daniel@k8s-template ~ $ sudo lvextend -l +100%FREE /dev/ubuntu-vg/ubuntu-lv
  Size of logical volume ubuntu-vg/ubuntu-lv changed from 18.22 GiB (4665 extents) to <38.22 GiB (9784 extents).
  Logical volume ubuntu-vg/ubuntu-lv successfully resized.

daniel@k8s-template ~ $ sudo resize2fs  /dev/mapper/ubuntu--vg-ubuntu--lv
resize2fs 1.46.5 (30-Dec-2021)
Filesystem at /dev/mapper/ubuntu--vg-ubuntu--lv is mounted on /; on-line resizing required
old_desc_blocks = 3, new_desc_blocks = 5
The filesystem on /dev/mapper/ubuntu--vg-ubuntu--lv is now 10018816 (4k) blocks long.

daniel@k8s-template ~ $ df -h
Filesystem                         Size  Used Avail Use% Mounted on
tmpfs                              1.2G  1.7M  1.2G   1% /run
/dev/mapper/ubuntu--vg-ubuntu--lv   38G   18G   19G  50% /
tmpfs                              5.9G     0  5.9G   0% /dev/shm
tmpfs                              5.0M     0  5.0M   0% /run/lock
tmpfs                              5.9G     0  5.9G   0% /run/qemu
/dev/sda2                          1.8G  153M  1.5G  10% /boot
tmpfs                              1.2G  4.0K  1.2G   1% /run/user/1000
