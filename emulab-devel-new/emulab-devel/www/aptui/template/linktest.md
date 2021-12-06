#### What is Linktest?

Linktest is an online validation test of the network characteristics
of your experiment. It is a check to make sure that we have set up the
network as you requested, within certain limitations listed below.

There are four levels of linktest you can choose:

  1. Connectivity and Latency
  1. Plus Static Routing
  1. Plus Link Loss
  1. Plus Bandwidth

It should be obvious what each one does, although it is important to
understand that bandwidth tests can take up to 20 seconds per link, so it
can take a long time to run linktest on a large experiment (one that has
many links).

#### Limitations

  * Not all bandwidths can be accurately measured, and linktest will skip
    links that it knows will give false results (e.g., slow or lossy
    links). Please check the output, and *be sure to test those links
    yourself* if your results depend on total accuracy.
  * As with any automated testing procedure, we have to balance the desire
    for accuracy with the possibility of false positives. To reduce the
    number of false positives, we allow for a small amount of fudge on any
    link. If your results are dependent on total accuracy, then you should
    *test your links yourself!*
  * Linktest can take a long time on large experiments. Even on very small
    experiments (5-10 nodes), doing the full bandwidth test can add 2-3
    minutes. If you decide you have waited long enough, you can use the
    Stop Linktest button on the topology tab.
  * Linktest does not yet work on links or lans that span clusters.

#### Finally

Linktest is a convenient tool intended to do coarse grained testing of your
links to find obvious problems. As mentioned above, if your application or
the paper you are writing depends on absolute fidelity, then you should
*test your links yourself!*
