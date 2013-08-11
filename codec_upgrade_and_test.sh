#!/bin/bash
#
# Drishti : shell script to update codec binaries and test
# Example usage :
# codec_upgrade_and_test.sh <tc_repo_path> <ducati_repo_path> <ip_addr_drishti>


# some colors for echo output
green='\e[0;32m'
red='\e[0;31m'
nc='\e[0m'


function printUsage() {
cat <<USAGE

SYNOPSIS
    `basename $0` [OPTION] <TC_REPO_PATH> <DUCATI_REPO_PATH> <IP_ADDR_DRISHTI>

DESCRIPTION
    Automatically update codecs and test.

OPTIONS
    -e
        update and test encoder

    -d
        update and test decoder

    -c
        commit changes if tests pass

    -h
        print help

USAGE
}


# default values
UPDATE_TEST_ENC=0
UPDATE_TEST_DEC=0
COMMIT=0
ENC_TESTS_PASSED=1
DEC_TESTS_PASSED=1


# command options
OPTERR=0
while getopts "edch" option; do
    case "$option" in
        e) UPDATE_TEST_ENC=1 ;;
        d) UPDATE_TEST_DEC=1 ;;
        c) COMMIT=1 ;;
        h) printUsage; exit 0 ;;
        *) printUsage; exit 1 ;;
    esac
done
shift $((OPTIND - 1))


# setup paths with user input
if [ $# -ne 3 ]; then
    printUsage
    exit 1
else
    TC_REPO_PATH=$1
    DUCATI_REPO_PATH=$2
    IP_ADDR=$3
    ENC_TEST_STREAMS_PATH="/mnt/base/enc_test_streams"
    DEC_TEST_STREAMS_PATH="/mnt/base/dec_test_streams"
fi


# sanity checks
if [[ (${UPDATE_TEST_ENC} -eq 0) && (${UPDATE_TEST_DEC} -eq 0) ]]; then
    echo -e "\n${red}atleast one of the options -e or -d must be enabled${nc}\n"
    exit 1
fi
if [ ! -d  $TC_REPO_PATH ]; then
    echo -e "\n${red}no such file or directory ${TC_REPO_PATH}${nc}\n"
    exit 1
fi
if [ ! -d  $DUCATI_REPO_PATH ]; then
    echo -e "\n${red}no such file or directory ${DUCATI_REPO_PATH}${nc}\n"
    exit 1
fi
(cd ${TC_REPO_PATH}; git remote -v) | grep system-trunk-main &>/dev/null
if [ $? -eq 1 ]; then
    echo -e "\n${red}${TC_REPO_PATH} is not the correct system-trunk-main repo${nc}\n"
    exit 1
fi
(cd ${DUCATI_REPO_PATH}/ducati-mm; git remote -v) | grep ducati-mm &>/dev/null
if [ $? -eq 1 ]; then
    echo -e "\n${red}${DUCATI_REPO_PATH} is not the correct ducati repo${nc}\n"
    exit 1
fi
ping -c 1 -w 10 $IP_ADDR &>/dev/null
if [ $? -ne 0 ]; then
    echo -e "\n${red}unable to connect to Drishti at ${IP_ADDR}${nc}\n"
    exit 1
fi
#ssh root@$IP_ADDR "ls $ENC_TEST_STREAMS_PATH &>/dev/null"
#if [ $? -ne 0 ]; then
#    echo -e "\n${red}invalid encoder test streams path ${ENC_TEST_STREAMS_PATH}${nc}\n"
#    exit 1
#fi
#ssh root@$IP_ADDR "ls $DEC_TEST_STREAMS_PATH &>/dev/null"
#if [ $? -ne 0 ]; then
#    echo -e "\n${red}invalid decoder test streams path ${DEC_TEST_STREAMS_PATH}${nc}\n"
#    exit 1
#fi
echo -e "\n${green}sanity checks complete...${nc}"


# build latest codec binaries
echo -e "\n${green}building latest codec binaries...${nc}"
cd $TC_REPO_PATH
git stash &>/dev/null
git pull --rebase &>/dev/null
./build/build -t drishti.testapps -j50 &>/dev/null
if [ $? -ne 0 ]; then
    echo -e "\n${red}system-trunk-main drishti.testapps build failed${nc}\n"
    exit 1
fi
echo -e "\n${green}built latest codec binaries...${nc}"


# clear any local ducati changes
cd $DUCATI_REPO_PATH/ducati-mm
git stash &>/dev/null
git reset --hard &>/dev/null
git pull --rebase &>/dev/null
cd $DUCATI_REPO_PATH/ducati-dce
git stash &>/dev/null
git reset --hard &>/dev/null
git pull --rebase &>/dev/null
cd $DUCATI_REPO_PATH
./ducati-scripts/ducati-build --clean &>/dev/null
echo -e "\n${green}cleaned up ducati repo...${nc}"


# cp latest codec binaries to local ducati repo
if [ ${UPDATE_TEST_ENC} -eq 1 ]; then
# H264ENC
cp $TC_REPO_PATH/functional/video/codec/codecs/ivahd_api/_build/drishti.testapps/slaveapps/vcodec/ivahd_api_host_git.a \
   $DUCATI_REPO_PATH/ducati-mm/WTSD_DucatiMMSW/ext_rel/ivahd_codecs/packages/ti/sdo/codecs/h264enc/lib/

cp $TC_REPO_PATH/functional/video/codec/codecs/ivahd_h264enc/_build/drishti.testapps/slaveapps/vcodec/ivahd_h264e_m3_api_git.a \
   $DUCATI_REPO_PATH/ducati-mm/WTSD_DucatiMMSW/ext_rel/ivahd_codecs/packages/ti/sdo/codecs/h264enc/lib/

cp $TC_REPO_PATH/functional/video/codec/resilience/framesetup/_build/drishti.testapps/slaveapps/vcodec/vidframesetup.a \
   $DUCATI_REPO_PATH/ducati-mm/WTSD_DucatiMMSW/ext_rel/ivahd_codecs/packages/ti/sdo/codecs/h264enc/lib/

# H263ENC
cp $TC_REPO_PATH/functional/video/codec/codecs/ivahd_api/_build/drishti.testapps/slaveapps/vcodec/ivahd_api_host_git.a \
   $DUCATI_REPO_PATH/ducati-mm/WTSD_DucatiMMSW/ext_rel/ivahd_codecs/packages/ti/sdo/codecs/mpeg4enc/lib/

cp $TC_REPO_PATH/functional/video/codec/codecs/ivahd_h263enc/_build/drishti.testapps/slaveapps/vcodec/ivahd_h263e_m3_api_git.a \
   $DUCATI_REPO_PATH/ducati-mm/WTSD_DucatiMMSW/ext_rel/ivahd_codecs/packages/ti/sdo/codecs/mpeg4enc/lib/

comment ()
{
# MJPEGENC
cp $TC_REPO_PATH/functional/video/codec/codecs/ivahd_api/_build/drishti.testapps/slaveapps/vcodec/ivahd_api_host_git.a \
   $DUCATI_REPO_PATH/ducati-mm/WTSD_DucatiMMSW/ext_rel/ivahd_codecs/packages/ti/sdo/codecs/jpegvenc/lib/

cp $TC_REPO_PATH/functional/video/codec/codecs/ivahd_mjpegenc/_build/drishti.testapps/slaveapps/vcodec/ivahd_mjpege_m3_api_git.a \
   $DUCATI_REPO_PATH/ducati-mm/WTSD_DucatiMMSW/ext_rel/ivahd_codecs/packages/ti/sdo/codecs/jpegvenc/lib/
}
fi


if [ ${UPDATE_TEST_DEC} -eq 1 ]; then
# H264DEC
cp $TC_REPO_PATH/functional/video/codec/codecs/ivahd_api/_build/drishti.testapps/slaveapps/vcodec/ivahd_api_host_git.a \
   $DUCATI_REPO_PATH/ducati-mm/WTSD_DucatiMMSW/ext_rel/ivahd_codecs/packages/ti/sdo/codecs/h264dec/lib/

cp $TC_REPO_PATH/functional/video/codec/codecs/ivahd_h264dec/_build/drishti.testapps/slaveapps/vcodec/ivahd_h264d_m3_api_git.a \
   $DUCATI_REPO_PATH/ducati-mm/WTSD_DucatiMMSW/ext_rel/ivahd_codecs/packages/ti/sdo/codecs/h264dec/lib/

cp $TC_REPO_PATH/functional/video/vidlibs/gdr/_build/drishti.testapps/slaveapps/vcodec/vidlib_gdr.a \
   $DUCATI_REPO_PATH/ducati-mm/WTSD_DucatiMMSW/ext_rel/ivahd_codecs/packages/ti/sdo/codecs/h264dec/lib/

# H263DEC
cp $TC_REPO_PATH/functional/video/codec/codecs/ivahd_api/_build/drishti.testapps/slaveapps/vcodec/ivahd_api_host_git.a \
   $DUCATI_REPO_PATH/ducati-mm/WTSD_DucatiMMSW/ext_rel/ivahd_codecs/packages/ti/sdo/codecs/mpeg4dec/lib/

cp $TC_REPO_PATH/functional/video/codec/codecs/ivahd_h263dec/_build/drishti.testapps/slaveapps/vcodec/ivahd_h263d_m3_api_git.a \
   $DUCATI_REPO_PATH/ducati-mm/WTSD_DucatiMMSW/ext_rel/ivahd_codecs/packages/ti/sdo/codecs/mpeg4dec/lib/

comment ()
{
# MJPEGDEC
cp $TC_REPO_PATH/functional/video/codec/codecs/ivahd_api/_build/drishti.testapps/slaveapps/vcodec/ivahd_api_host_git.a \
   $DUCATI_REPO_PATH/ducati-mm/WTSD_DucatiMMSW/ext_rel/ivahd_codecs/packages/ti/sdo/codecs/jpegvdec/lib/

cp $TC_REPO_PATH/functional/video/codec/codecs/ivahd_mjpegdec/_build/drishti.testapps/slaveapps/vcodec/mjpegd_icont1/jpegvdec_ti_icont1_static_data_generated.h/mjpegd_icont1/ivahd_mjpegd_errorconceal_eclib_git.a \
$DUCATI_REPO_PATH/ducati-mm/WTSD_DucatiMMSW/ext_rel/ivahd_codecs/packages/ti/sdo/codecs/jpegvdec/lib/

cp $TC_REPO_PATH/functional/video/codec/codecs/ivahd_mjpegdec/_build/drishti.testapps/slaveapps/vcodec/ivahd_mjpegd_m3_api_git.a \
   $DUCATI_REPO_PATH/ducati-mm/WTSD_DucatiMMSW/ext_rel/ivahd_codecs/packages/ti/sdo/codecs/jpegvdec/lib/
}
fi
echo -e "\n${green}copied codec binaries to ducati repo...${nc}"


# cp header files to ttvenc_dce and ttvdec_dce
if [ ${UPDATE_TEST_ENC} -eq 1 ]; then
# H264ENC
cp $TC_REPO_PATH/functional/video/codec/codecs/ivahd_h264enc/_build/drishti.testapps/git@lys-git_cisco_com_projects_video_ivahd_h264e/Inc/ih264enc.h \
$TC_REPO_PATH/functional/video/codec/codecs/ttvenc_dce/

# H263ENC
cp $TC_REPO_PATH/functional/video/codec/codecs/ivahd_h263enc/_build/drishti.testapps/git@lys-git_cisco_com_projects_video_ivahd_h263e/Inc/impeg4enc.h \
$TC_REPO_PATH/functional/video/codec/codecs/ttvenc_dce/

comment ()
{
# MJPEGENC
cp $TC_REPO_PATH/functional/video/codec/codecs/ivahd_mjpegenc/_build/drishti.testapps/git@lys-git_cisco_com_projects_video_ivahd_mjpege/inc/ijpegenc.h \
$TC_REPO_PATH/functional/video/codec/codecs/ttvenc_dce/
}
fi


if [ ${UPDATE_TEST_DEC} -eq 1 ]; then
# H264DEC
cp $TC_REPO_PATH/functional/video/codec/codecs/ivahd_h264dec/_build/drishti.testapps/git@lys-git_cisco_com_projects_video_ivahd_h264d/Inc/ih264vdec.h \
$TC_REPO_PATH/functional/video/codec/codecs/ttvdec_dce/

# H263DEC
cp $TC_REPO_PATH/functional/video/codec/codecs/ivahd_h263dec/_build/drishti.testapps/git@lys-git_cisco_com_projects_video_ivahd_h263d/Inc/impeg4vdec.h \
$TC_REPO_PATH/functional/video/codec/codecs/ttvdec_dce/
sed -i '/ires_hdvicp2.h/d' $TC_REPO_PATH/functional/video/codec/codecs/ttvdec_dce/impeg4vdec.h

comment ()
{
# MJPEGDEC
cp $TC_REPO_PATH/functional/video/codec/codecs/ivahd_mjpegdec/_build/drishti.testapps/git@lys-git_cisco_com_projects_video_ivahd_mjpegd/inc/ijpegvdec.h \
$TC_REPO_PATH/functional/video/codec/codecs/ttvdec_dce/
}
fi
echo -e "\n${green}copied header files to tc main...${nc}"


# rebuild tc in parallel
echo -e "\n${green}building system-trunk-main with changed codec headers...${nc}"
(cd $TC_REPO_PATH; ./build/build -t drishti.testapps -j24 &>/dev/null; echo "$?" > /tmp/tc_exit_status) &
tc_build_pid=$(echo $!)


# build ducati firmware in parallel
echo -e "\n${green}ducati build with new codec binaries in progress...${nc}"
(cd $DUCATI_REPO_PATH; ./ducati-scripts/ducati-build --drishti &>/dev/null; echo "$?" > /tmp/ducati_exit_status) &


# wait for tc build to complete and check for errors and binst
wait $tc_build_pid &>/dev/null
tc_build_status=$(cat /tmp/tc_exit_status)
if [ $tc_build_status -ne 0 ]; then
    echo -e "\n${red}system-trunk-main drishti.testapps build failed${nc}\n"
    exit 1
fi
echo -e "\n${green}built system-trunk-main with changed codec headers...${nc}"

echo -e "\n${green}binst in progress...${nc}"
(cd $TC_REPO_PATH; bin/binst -v -t drishti.testapps $IP_ADDR &>/dev/null; echo "$?" > /tmp/binst_exit_status) &


# wait for binst and ducati build to complete and check for errors
wait &>/dev/null
binst_status=$(cat /tmp/binst_exit_status)
ducati_build_status=$(cat /tmp/ducati_exit_status)
if [ $binst_status -ne 0 ]; then
    echo -e "\n${red}binst failed${nc}\n"
    exit 1
fi
if [ $ducati_build_status -ne 0 ]; then
    echo -e "\n${red}ducati build failed${nc}\n"
    exit 1
fi
echo -e "\n${green}binst completed...${nc}"
echo -e "\n${green}ducati build completed...${nc}"


# wait until Drishti is back online after reboot
DRISHTI_ONLINE=0
echo -e "\n${green}waiting for Drishti to come online after reboot...${nc}"
for i in {1..600}
do
    ping -c 1 -w 1 $IP_ADDR &>/dev/null
    if [ $? -eq 0 ]; then
        DRISHTI_ONLINE=1
        break
    fi
done

if [ $DRISHTI_ONLINE -eq 0 ]; then
    echo -e "\n${red}waited for 10 min. could not connect to Drishti${nc}\n"
    exit 1
fi
sleep 20


# backup original ducati firmware on Drishti and copy newly build ducati firmware to Drishti
ssh root@$IP_ADDR "cp /mnt/base/active/ti-firmware-ipu-mm.xem3{,_orig}"
scp $DUCATI_REPO_PATH/install/ducati-mm/ti-firmware-ipu-mm.xem3 root@$IP_ADDR:/mnt/base/active/ &>/dev/null
if [ $? -ne 0 ]; then
    echo -e "\n${red}failed to copy ducati firmware to Drishti${nc}\n"
    exit 1
fi


# reload ducati w/o rebooting
ssh root@$IP_ADDR '/apps/ducati-crash.sh' &>/dev/null
sleep 10
echo -e "\n${green}updated ducati firmware on Drishti...${nc}"


# transfer test streams to Drishti
ssh root@$IP_ADDR 'rm -rf /mnt/base/{enc_test_streams,dec_test_streams}' &>/dev/null
echo -e "\n${green}transfer of test streams to Drishti in progress...${nc}"
if [ ${UPDATE_TEST_ENC} -eq 1 ]; then
    scp -r /export/home/varupati/enc_test_streams root@$IP_ADDR:/mnt/base/ &>/dev/null
    if [ $? -ne 0 ]; then
        echo -e "\n${red}failed to transfer encoder test streams to Drishti${nc}\n"
        exit 1
    fi
fi
if [ ${UPDATE_TEST_DEC} -eq 1 ]; then
    scp -r /export/home/varupati/dec_test_streams root@$IP_ADDR:/mnt/base/ &>/dev/null
    if [ $? -ne 0 ]; then
        echo -e "\n${red}failed to transfer decoder test streams to Drishti${nc}\n"
        exit 1
    fi
fi
echo -e "\n${green}transfer of test streams to Drishti completed...${nc}"


# verify md5sum match for tranferred encoder test streams
cd ~
diff <(ssh root@$IP_ADDR 'cd /mnt/base/enc_test_streams; md5sum *') /export/home/varupati/enc_test_streams_md5sum &>/dev/null
if [ $? -ne 0 ]; then
    echo -e "\n${red}encoder test streams md5sums on src and dest do not match${nc}\n"
    exit 1
fi


# test vidcodec encoder
if [ ${UPDATE_TEST_ENC} -eq 1 ]; then
for i in $(ssh root@$IP_ADDR "ls $ENC_TEST_STREAMS_PATH"); do

    # extract width of test stream from name
    width=`echo $i | awk -F"_" '{print $2}' | awk -F"x" '{print $1}'`

    # extract height of test stream from name
    height=`echo $i | awk -F"_" '{print $2}' | awk -F"x" '{print $2}'`

    # extract filename without extension
    filename=`echo $i | awk -F"." '{print $1}'`

    # test h264 encoder
    ssh root@$IP_ADDR "LD_LIBRARY_PATH=:/extra/lib /apps/vidcodec.elf enc -e ttvenc_h264_dce -s $width $height -f YUV420SemiPlanar -P 1000000 $ENC_TEST_STREAMS_PATH/$i $filename.264 &>/dev/null" &>/dev/null

    # check exit status of h264 encoder
    if [ $? -eq 0 ]
    then
            # h264 md5sum verification
            new_md5=`ssh root@$IP_ADDR "md5sum $filename.264" | awk '{print $1}'`
            orig_md5=`awk "/$filename.264/"'{print $1}' /export/home/varupati/enc_md5sums`
            if [ "$new_md5" != "$orig_md5" ]; then
                    echo -e "\n${red}h264 enc : md5sum mismatch for input stream $i${nc}"
                    ENC_TESTS_PASSED=0
                    #exit 1
            else
                    echo -e "\n${green}h264enc passed with stream $i${nc}"
            fi
    else
            echo -e "\n${red}h264enc failed with stream $i${nc}"
            ENC_TESTS_PASSED=0
            #exit 1
    fi

    sleep 2

    # test h263 encoder
    ssh root@$IP_ADDR "LD_LIBRARY_PATH=:/extra/lib /apps/vidcodec.elf enc -e ttvenc_h263_dce -s $width $height -f YUV420SemiPlanar -B 2048000 -P 1000000 $ENC_TEST_STREAMS_PATH/$i $filename.263 &>/dev/null" &>/dev/null

    # check exit status of h263 encoder
    if [ $? -eq 0 ]
    then
            # h263 md5sum verification
            new_md5=`ssh root@$IP_ADDR "md5sum $filename.263" | awk '{print $1}'`
            orig_md5=`awk "/$filename.263/"'{print $1}' /export/home/varupati/enc_md5sums`
            if [ "$new_md5" != "$orig_md5" ]; then
                    echo -e "\n${red}h263 enc : md5sum mismatch for input stream $i${nc}"
                    ENC_TESTS_PASSED=0
                    #exit 1
            else
                    echo -e "\n${green}h263enc passed with stream $i${nc}"
            fi
    else
            echo -e "\n${red}h263enc failed with stream $i${nc}"
            ENC_TESTS_PASSED=0
            #exit 1
    fi

    sleep 2

    comment ()
    {
    # test mjpeg encoder
    ssh root@$IP_ADDR "LD_LIBRARY_PATH=:/extra/lib /apps/vidcodec.elf enc -e ttvenc_mjpeg_dce -s $width $height -f YUV420SemiPlanar -B 2048000 -P 1000000 $ENC_TEST_STREAMS_PATH/$i $filename.mjpeg &>/dev/null" &>/dev/null

    # check exit status of mjpeg encoder
    if [ $? -eq 0 ]
    then
            # mjpeg md5sum verification
            new_md5=`ssh root@$IP_ADDR "md5sum $filename.mjpeg" | awk '{print $1}'`
            orig_md5=`awk "/$filename.mjpeg/"'{print $1}' /export/home/varupati/enc_md5sums`
            if [ "$new_md5" != "$orig_md5" ]; then
                    echo -e "\n${red}mjpeg enc : md5sum mismatch for input stream $i${nc}"
                    ENC_TESTS_PASSED=0
                    #exit 1
            else
                    echo -e "\n${green}mjpegenc passed with stream $i${nc}"
            fi
    else
            echo -e "\n${red}mjpegenc failed with stream $i${nc}"
            ENC_TESTS_PASSED=0
            #exit 1
    fi

    sleep 2
    }

done
echo -e "\n${green}all encoder tests completed...${nc}"
if [ ${ENC_TESTS_PASSED} -eq 0 ]; then
    echo -e "\n${red}one or more encoder tests have failed${nc}"
fi
else
    ENC_TESTS_PASSED=0
fi


# test vidcodec decoder
if [ ${UPDATE_TEST_DEC} -eq 1 ]; then
echo -e "\n${green}decoder tests in progress...${nc}"
ssh root@$IP_ADDR "cd $DEC_TEST_STREAMS_PATH; cp /apps/vidcodec.elf ./vidcodec; LD_LIBRARY_PATH=:/extra/lib /extra/bin/python ./codectest.py --xml-file=test_cases.xml vidcodec 'Drishti H.264 Decode Conformance'; rm -rf /tmp/root-2013-*; rm ./vidcodec" > $HOME/dec_tests_log 2>&1
if [ $? -ne 0 ]; then
    echo -e "\n${red}could not execute decoder tests on Drishti${nc}"
    DEC_TESTS_PASSED=0
    #exit 1
else
    echo -e "\n${green}all decoder tests completed... see ~/dec_tests_log for a detailed report${nc}"
    grep Failed $HOME/dec_tests_log &>/dev/null
    if [ $? -eq 0 ]; then
        echo -e "\n${red}one or more decoder tests have failed. see ~/dec_tests_log for a detailed report${nc}"
        DEC_TESTS_PASSED=0
    fi
fi
else
    DEC_TESTS_PASSED=0
fi


# send mail to user regarding informing result of codec tests
if [ ${ENC_TESTS_PASSED} -eq 0 ]; then
    mail -s "codec_upgrade_and_test.sh : one or more encoder tests have failed" $(basename $HOME)@cisco.com < /dev/null
fi
if [ ${DEC_TESTS_PASSED} -eq 0 ]; then
    mail -s "codec_upgrade_and_test.sh : one or more decoder tests have failed" $(basename $HOME)@cisco.com < /dev/null
fi


# commit ducati repo changes for encoder
if [[ (${COMMIT} -eq 1) && (${ENC_TESTS_PASSED} -eq 1) ]]; then
    cd $DUCATI_REPO_PATH/ducati-mm
    git add WTSD_DucatiMMSW/ext_rel/ivahd_codecs/packages/ti/sdo/codecs/*enc &>/dev/null
    date=`date`
    git commit -m "updating encoder binaries - $date" &>/dev/null
    ducati_commit_id=`git rev-parse HEAD`


    # commit encoder header file changes
    cd $TC_REPO_PATH
    git add functional/video/codec/codecs/ttvenc_dce &>/dev/null
    git commit -m "updating encoder header files to comply with updated encoder binaries" &>/dev/null


    # update ducati tag in tc repo for encoder update
    cd $TC_REPO_PATH/product/drishti/target/ducati
    sed -ri "7c \
    \ \ \ \ ducati_mm_version = '$ducati_commit_id'" genmake.def &>/dev/null
    git add $TC_REPO_PATH/product/drishti/target/ducati/genmake.def &>/dev/null
    git commit -m "updating ducati tag" &>/dev/null

    echo -e "\n${green}encoder changes have been committed...${nc}"
fi


# commit ducati repo changes for decoder
if [[ (${COMMIT} -eq 1) && (${DEC_TESTS_PASSED} -eq 1) ]]; then
    cd $DUCATI_REPO_PATH/ducati-mm
    git add WTSD_DucatiMMSW/ext_rel/ivahd_codecs/packages/ti/sdo/codecs/*dec &>/dev/null
    date=`date`
    git commit -m "updating decoder binaries - $date" &>/dev/null
    ducati_commit_id=`git rev-parse HEAD`


    # commit decoder header file changes
    cd $TC_REPO_PATH
    git add functional/video/codec/codecs/ttvdec_dce &>/dev/null
    git commit -m "updating decoder header files to comply with updated decoder binaries" &>/dev/null


    # update ducati tag in tc repo for decoder update
    cd $TC_REPO_PATH/product/drishti/target/ducati
    sed -ri "7c \
    \ \ \ \ ducati_mm_version = '$ducati_commit_id'" genmake.def &>/dev/null
    git add $TC_REPO_PATH/product/drishti/target/ducati/genmake.def &>/dev/null
    git commit -m "updating ducati tag" &>/dev/null

    echo -e "\n${green}decoder changes have been committed...${nc}"
fi

echo ""
# exit shell script with proper return value
if [[ (${ENC_TESTS_PASSED} -eq 0) || (${DEC_TESTS_PASSED} -eq 0) ]]; then
    exit 1
else
    exit 0
fi
