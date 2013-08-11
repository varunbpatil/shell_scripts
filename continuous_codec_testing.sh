#!/bin/bash
#
# run codec tests continuously and report errors along with
# system-trunk-main commit that caused the error

if [ $# -ne 2 ]; then
    echo "Usage : $(basename $0) <path_to_tc_repo> <ip_addr_drishti>"
    exit 1
fi

TC_REPO_PATH=$1
IP_ADDR=$2
commit_sha1=
last_tested=
TESTS_TRANSFERRED=0

mkdir -p ~/enc_tests_log
mkdir -p ~/dec_tests_log

ping -c 1 -w 10 $IP_ADDR &>/dev/null
if [ $? -ne 0 ]; then
    echo "unable to connect to Drishti at ${IP_ADDR}"
    exit 1
fi

while true; do

# get latest commit id from system-trunk-main
echo "updating system-trunk-main"
cd $TC_REPO_PATH
git stash &>/dev/null
git reset --hard &>/dev/null
git pull --rebase &>/dev/null
last_tested=$commit_sha1
commit_sha1=`git rev-parse HEAD`
if [ "$last_tested" == "$commit_sha1" ]; then
    continue
fi
echo "testing codecs with system-trunk-main commit id = $commit_sha1"

# download corresponding drishti-testapps.pkg from matchbox
rm -rf drishti-testapps.pkg &>/dev/null
dir=$(echo $commit_sha1 | awk '{ printf "%s", substr($1,1,2) }')
echo "waiting for availability of drishti-testapps.pkg on matchbox for commit id = $commit_sha1"
while true; do
wget --spider "http://matchboxrepo2.rd.tandberg.com/images/git/lys-git.cisco.com:_projects_system-trunk-main/master/$dir/$commit_sha1/drishti-testapps.pkg" &>/dev/null
if [ $? -eq 0 ]; then
    break
fi
sleep 10
done
echo "downloading drishti-testapps.pkg from matchbox"
curl "http://matchboxrepo2.rd.tandberg.com/images/git/lys-git.cisco.com:_projects_system-trunk-main/master/$dir/$commit_sha1/drishti-testapps.pkg" -o 'drishti-testapps.pkg' &>/dev/null

# binst
echo "binst in progress"
bin/binst -v -t drishti.testapps $IP_ADDR -f drishti-testapps.pkg &>/dev/null

# wait till reboot done
echo "waiting till Drishti reboots"
DRISHTI_ONLINE=0
for i in {1..600}
do
    ping -c 1 -w 1 $IP_ADDR &>/dev/null
    if [ $? -eq 0 ]; then
        DRISHTI_ONLINE=1
        break
    fi
done

if [ $DRISHTI_ONLINE -eq 0 ]; then
    echo "waited for 10 min. could not connect to Drishti"
    exit 1
fi
sleep 20

# transfer test streams
if [ $TESTS_TRANSFERRED -eq 0 ]; then
ssh root@$IP_ADDR 'rm -rf /mnt/base/{enc_test_streams,dec_test_streams}' &>/dev/null
echo "transfer of test streams to Drishti in progress"
scp -r /export/home/varupati/enc_test_streams root@$IP_ADDR:/mnt/base/ &>/dev/null
if [ $? -ne 0 ]; then
    echo "failed to transfer encoder test streams to Drishti"
    exit 1
fi
scp -r /export/home/varupati/dec_test_streams root@$IP_ADDR:/mnt/base/ &>/dev/null
if [ $? -ne 0 ]; then
    echo "failed to transfer decoder test streams to Drishti"
    exit 1
fi

# verify md5sum match for tranferred encoder test streams
cd ~
diff <(ssh root@$IP_ADDR 'cd /mnt/base/enc_test_streams; md5sum *') /export/home/varupati/enc_test_streams_md5sum &>/dev/null
if [ $? -ne 0 ]; then
    echo "encoder test streams md5sums on src and dest do not match"
    continue
fi
TESTS_TRANSFERRED=1
fi

# test vidcodec encoder
ENC_TESTS_PASSED=1
echo "encoder tests in progress"
for i in $(ssh root@$IP_ADDR "ls /mnt/base/enc_test_streams"); do

    # extract width of test stream from name
    width=`echo $i | awk -F"_" '{print $2}' | awk -F"x" '{print $1}'`

    # extract height of test stream from name
    height=`echo $i | awk -F"_" '{print $2}' | awk -F"x" '{print $2}'`

    # extract filename without extension
    filename=`echo $i | awk -F"." '{print $1}'`

    # test h264 encoder
    ssh root@$IP_ADDR "LD_LIBRARY_PATH=:/extra/lib /apps/vidcodec.elf enc -e ttvenc_h264_dce -s $width $height -f YUV420SemiPlanar -P 1000000 /mnt/base/enc_test_streams/$i $filename.264 &>/dev/null" &>/dev/null

    # check exit status of h264 encoder
    if [ $? -eq 0 ]
    then
            # h264 md5sum verification
            new_md5=`ssh root@$IP_ADDR "md5sum $filename.264" | awk '{print $1}'`
            orig_md5=`awk "/$filename.264/"'{print $1}' /export/home/varupati/enc_md5sums`
            if [ "$new_md5" != "$orig_md5" ]; then
                    echo "h264 enc : md5sum mismatch for input stream $i" >> ~/enc_tests_log/log.$commit_sha1
                    ENC_TESTS_PASSED=0
            else
                    echo "h264enc passed with stream $i" >> ~/enc_tests_log/log.$commit_sha1
            fi
    else
            echo "h264enc failed with stream $i" >> ~/enc_tests_log/log.$commit_sha1
            ENC_TESTS_PASSED=0
    fi

    sleep 2

    # test h263 encoder
    ssh root@$IP_ADDR "LD_LIBRARY_PATH=:/extra/lib /apps/vidcodec.elf enc -e ttvenc_h263_dce -s $width $height -f YUV420SemiPlanar -B 2048000 -P 1000000 /mnt/base/enc_test_streams/$i $filename.263 &>/dev/null" &>/dev/null

    # check exit status of h263 encoder
    if [ $? -eq 0 ]
    then
            # h263 md5sum verification
            new_md5=`ssh root@$IP_ADDR "md5sum $filename.263" | awk '{print $1}'`
            orig_md5=`awk "/$filename.263/"'{print $1}' /export/home/varupati/enc_md5sums`
            if [ "$new_md5" != "$orig_md5" ]; then
                    echo "h263 enc : md5sum mismatch for input stream $i" >> ~/enc_tests_log/log.$commit_sha1
                    ENC_TESTS_PASSED=0
            else
                    echo "h263enc passed with stream $i" >> ~/enc_tests_log/log.$commit_sha1
            fi
    else
            echo "h263enc failed with stream $i" >> ~/enc_tests_log/log.$commit_sha1
            ENC_TESTS_PASSED=0
    fi

    sleep 2

    comment ()
    {
    # test mjpeg encoder
    ssh root@$IP_ADDR "LD_LIBRARY_PATH=:/extra/lib /apps/vidcodec.elf enc -e ttvenc_mjpeg_dce -s $width $height -f YUV420SemiPlanar -B 2048000 -P 1000000 /mnt/base/enc_test_streams/$i $filename.mjpeg &>/dev/null" &>/dev/null

    # check exit status of mjpeg encoder
    if [ $? -eq 0 ]
    then
            # mjpeg md5sum verification
            new_md5=`ssh root@$IP_ADDR "md5sum $filename.mjpeg" | awk '{print $1}'`
            orig_md5=`awk "/$filename.mjpeg/"'{print $1}' /export/home/varupati/enc_md5sums`
            if [ "$new_md5" != "$orig_md5" ]; then
                    echo "mjpeg enc : md5sum mismatch for input stream $i" >> ~/enc_tests_log/log.$commit_sha1
                    ENC_TESTS_PASSED=0
            else
                    echo "mjpegenc passed with stream $i" >> ~/enc_tests_log/log.$commit_sha1
            fi
    else
            echo "mjpegenc failed with stream $i" >> ~/enc_tests_log/log.$commit_sha1
            ENC_TESTS_PASSED=0
    fi

    sleep 2
    }

done
if [ ${ENC_TESTS_PASSED} -eq 0 ]; then
    echo "one or more encoder tests have failed"
fi

# test vidcodec decoder
DEC_TESTS_PASSED=1
echo "decoder tests in progress"
ssh root@$IP_ADDR "cd /mnt/base/dec_test_streams; cp /apps/vidcodec.elf ./vidcodec; LD_LIBRARY_PATH=:/extra/lib /extra/bin/python ./codectest.py --xml-file=test_cases.xml vidcodec 'Drishti H.264 Decode Conformance'; rm -rf /tmp/root-2013-*; rm ./vidcodec" > $HOME/dec_tests_log/log.$commit_sha1 2>&1
if [ $? -ne 0 ]; then
    echo "could not execute decoder tests on Drishti"
    DEC_TESTS_PASSED=0
else
    grep Failed $HOME/dec_tests_log &>/dev/null
    if [ $? -eq 0 ]; then
        echo "one or more decoder tests have failed"
        DEC_TESTS_PASSED=0
    fi
fi

# send mail to user regarding informing result of codec tests
if [ ${ENC_TESTS_PASSED} -eq 0 ]; then
    mail -s "enc tests : failed [$commit_sha1] last tested [$last_tested]" $(basename $HOME)@cisco.com < ~/enc_tests_log
fi
if [ ${DEC_TESTS_PASSED} -eq 0 ]; then
    mail -s "dec tests : failed [$commit_sha1] last tested [$last_tested]" $(basename $HOME)@cisco.com < ~/dec_tests_log
fi

echo "-----------------------------------------------------------------------------------------------------------"

done
