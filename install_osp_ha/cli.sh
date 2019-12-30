# show ip in netns
#!/bin/bash
netns=`ip netns`
for i in $netns
do
if [[ $i = *"qdhcp"* ]]; then
echo $i
ip netns exec $i ip -4 a |grep -v -E "valid_lft|1:|127."
fi
if [[ $i = *"qrouter"* ]]; then
echo $i
ip netns exec $i ip -4 a |grep -v -E "valid_lft|1:|127."
fi
done

# show vm port
#!/bin/bash
lsvm=`virsh list --all |grep inst|tr -s " " | cut -f2 -d" "` 
for i in $lsvm
do
virsh dumpxml $i |grep tap | cut -f2 -d"'"
done

# show openflow info
ovs-ofctl show br-int | grep -v -E "REPLY|n_tables|capabilities:|actions:|config:|state:|speed:|current:" \r
ovs-ofctl show br-tun | grep -v -E "REPLY|n_tables|capabilities:|actions:|config:|state:|speed:|current:" \r

ovs-ofctl dump-flows br-int | wc -l \r
ovs-ofctl dump-flows br-tun | wc -l \r

ovs-ofctl show br-int | grep -v -E "REPLY|n_tables|capabilities:|actions:|config:|state:|speed:|current:" | wc -l \r
ovs-ofctl show br-tun | grep -v -E "REPLY|n_tables|capabilities:|actions:|config:|state:|speed:|current:" | wc -l \r



