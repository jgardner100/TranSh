#!/bin/bash
OPTIONS=""

diff.sh $OPTIONS sdwrptest1 sdwrpperf1
diff.sh $OPTIONS fsgtst8 fsgperf8
diff.sh $OPTIONS saasdev15 fsgperf2

