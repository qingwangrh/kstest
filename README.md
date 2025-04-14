# kstest
## Kubesan test

### Usage
<pre>
./svg_test.sh <-t testname> <-v vgname> <-d devname> 
 [ -r log rootdir] [-w worker] [-n lvnum ]
 [ -u stage unit]  [-s lvsize] [-i] [-e function]

#####################
-t testname: The test name, log file and count file can be generated with this.
-v vgname  : The VG name for testing.
-d devname : The LNU devices name.
-r logrootdir: The root path of log files. if no logdir defined, this vaule
               may help to build logdir.
####################
-l logdir : The path of log files. It can be build by log rootdir 
            if it is not specified. 
-w worker  : The worker node name. It helps to distinguish host resource
-s lvsize : The size (Megabyte) of a LV or pool.
            optional. default is 16.
-n lvnum  : The number of LV/pool. optional. default is auto calc.
            If specify it, the final value is min(lvnum, auto).
-u stage unit : When the operation reaches a certain 
                number of times(stage), the log is rotated 
                and the duration is counted. default is 1000
-i : Re-init content of log file and count file. default 0

Example : 
 ./svg_test.sh -t lvcreate -e "svg_lv_create  -v ksvg1 -n 2000 -s 0 -o '-an' -u 1000"
 ./svg_test.sh -t lvchange -e "svg_lv_change  -v ksvg1 -n 2000 -s 0 -o '-ay' -u 1000"
 ./svg_test.sh -t lvextend -e "svg_lv_extend  -v ksvg1 -n 2000 -s 0  -u 1000"
</pre>
***
### Result Analysis
After test finish, you may run the script to get result

./svg_data_analysis.sh $TEST_NAME [logdir]

***
