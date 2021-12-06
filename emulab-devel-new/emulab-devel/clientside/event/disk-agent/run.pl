#system("../../../pubsub/pubsubd -v -d -p 4001");
system("./disk-agent -E utahstud/stap3 -s event-server -u disk -p 16505");
#-k /var/emulab/boot/eventkey

