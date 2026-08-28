
# RFC: Toroidal Engine Integration for Enroot/Pyxis

This patch proposes bypassing the 2 MB OS thread overhead of standard slurmd/Enroot executions by integrating the Dragrush Toroidal Engine (2 KB baseline). 

Full architecture and k6 benchmarks demonstrating the 2,000% throughput gain (10k -> 200k req/s) can be reviewed here: https://bit.ly/4gq3CaJ
