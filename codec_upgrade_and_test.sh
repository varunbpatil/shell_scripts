#!/bin/bash
#
# Drishti : shell script to update codec binaries and test
# Example usage :
# codec_upgrade_and_test.sh <tc_repo_path> <ducati_repo_path> <ip_addr_drishti>


# some colors for echo output
readonly GREEN='\e[0;32m'
readonly RED='\e[0;31m'
readonly NC='\e[0m'


printUsage() {
cat <<USAGE

SYNOPSIS
    "$(basename $0)" [OPTION] <TC_REPO_PATH> <DUCATI_REPO_PATH> <IP_ADDR_DRISHTI>

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
UPDATE_TEST_ENC=false
UPDATE_TEST_DEC=false
COMMIT=false
ENC_TESTS_PASSED=true
DEC_TESTS_PASSED=true


# command options
OPTERR=0
while getopts "edch" option; do
    case "$option" in
        e) UPDATE_TEST_ENC=true ;;
        d) UPDATE_TEST_DEC=true ;;
        c) COMMIT=true ;;
        h) printUsage; exit 0 ;;
        *) printUsage; exit 1 ;;
    esac
done
shift $((OPTIND - 1))
readonly UPDATE_TEST_DEC
readonly UPDATE_TEST_ENC
readonly COMMIT


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
readonly TC_REPO_PATH
readonly DUCATI_REPO_PATH
readonly IP_ADDR
readonly ENC_TEST_STREAMS_PATH
readonly DEC_TEST_STREAMS_PATH


# sanity checks
if ! ${UPDATE_TEST_ENC} && ! ${UPDATE_TEST_DEC}; then
    echo -e "\n${RED}atleast one of the options -e or -d must be enabled${NC}\n" >&2
    exit 1
fi

if [ ! -d  "${TC_REPO_PATH}" ]; then
    echo -e "\n${RED}no such file or directory ${TC_REPO_PATH}${NC}\n" >&2
    exit 1
fi

if [ ! -d  "${DUCATI_REPO_PATH}" ]; then
    echo -e "\n${RED}no such file or directory ${DUCATI_REPO_PATH}${NC}\n" >&2
    exit 1
fi

if ! (cd "${TC_REPO_PATH}"; git remote -v) | grep system-trunk-main &>/dev/null; then
    echo -e "\n${RED}${TC_REPO_PATH} is not the correct system-trunk-main repo${NC}\n" >&2
    exit 1
fi

if ! (cd "${DUCATI_REPO_PATH}"/ducati-mm; git remote -v) | grep ducati-mm &>/dev/null; then
    echo -e "\n${RED}${DUCATI_REPO_PATH} is not the correct ducati repo${NC}\n" >&2
    exit 1
fi

if ! ping -c 1 -w 10 "${IP_ADDR}" &>/dev/null; then
    echo -e "\n${RED}unable to connect to Drishti at ${IP_ADDR}${NC}\n" >&2
    exit 1
fi

#if ! ssh root@"${IP_ADDR}" "ls "${ENC_TEST_STREAMS_PATH}" &>/dev/null"; then
#    echo -e "\n${RED}invalid encoder test streams path ${ENC_TEST_STREAMS_PATH}${NC}\n" >&2
#    exit 1
#fi

#if ! ssh root@"${IP_ADDR}" "ls "${DEC_TEST_STREAMS_PATH}" &>/dev/null"; then
#    echo -e "\n${RED}invalid decoder test streams path ${DEC_TEST_STREAMS_PATH}${NC}\n" >&2
#    exit 1
#fi
echo -e "\n${GREEN}sanity checks complete...${NC}"


# build latest codec binaries
echo -e "\n${GREEN}building latest codec binaries...${NC}"
cd "${TC_REPO_PATH}"
git stash &>/dev/null
git pull --rebase &>/dev/null
if ! ./build/build -t drishti.testapps -j50 &>/dev/null; then
    echo -e "\n${RED}system-trunk-main drishti.testapps build failed${NC}\n" >&2
    exit 1
fi
echo -e "\n${GREEN}built latest codec binaries...${NC}"


# clear any local ducati changes
cd "${DUCATI_REPO_PATH}"/ducati-mm
git stash &>/dev/null
git reset --hard &>/dev/null
git pull --rebase &>/dev/null
cd "${DUCATI_REPO_PATH}"/ducati-dce
git stash &>/dev/null
git reset --hard &>/dev/null
git pull --rebase &>/dev/null
cd "${DUCATI_REPO_PATH}"
./ducati-scripts/ducati-build --clean &>/dev/null
echo -e "\n${GREEN}cleaned up ducati repo...${NC}"


# cp latest codec binaries to local ducati repo
if ${UPDATE_TEST_ENC}; then
# H264ENC
cp "${TC_REPO_PATH}"/functional/video/codec/codecs/ivahd_api/_build/drishti.testapps/slaveapps/vcodec/ivahd_api_host_git.a \
   "${DUCATI_REPO_PATH}"/ducati-mm/WTSD_DucatiMMSW/ext_rel/ivahd_codecs/packages/ti/sdo/codecs/h264enc/lib/

cp "${TC_REPO_PATH}"/functional/video/codec/codecs/ivahd_h264enc/_build/drishti.testapps/slaveapps/vcodec/ivahd_h264e_m3_api_git.a \
   "${DUCATI_REPO_PATH}"/ducati-mm/WTSD_DucatiMMSW/ext_rel/ivahd_codecs/packages/ti/sdo/codecs/h264enc/lib/

cp "${TC_REPO_PATH}"/functional/video/codec/resilience/framesetup/_build/drishti.testapps/slaveapps/vcodec/vidframesetup.a \
   "${DUCATI_REPO_PATH}"/ducati-mm/WTSD_DucatiMMSW/ext_rel/ivahd_codecs/packages/ti/sdo/codecs/h264enc/lib/

# H263ENC
cp "${TC_REPO_PATH}"/functional/video/codec/codecs/ivahd_api/_build/drishti.testapps/slaveapps/vcodec/ivahd_api_host_git.a \
   "${DUCATI_REPO_PATH}"/ducati-mm/WTSD_DucatiMMSW/ext_rel/ivahd_codecs/packages/ti/sdo/codecs/mpeg4enc/lib/

cp "${TC_REPO_PATH}"/functional/video/codec/codecs/ivahd_h263enc/_build/drishti.testapps/slaveapps/vcodec/ivahd_h263e_m3_api_git.a \
   "${DUCATI_REPO_PATH}"/ducati-mm/WTSD_DucatiMMSW/ext_rel/ivahd_codecs/packages/ti/sdo/codecs/mpeg4enc/lib/

comment () {
# MJPEGENC
cp "${TC_REPO_PATH}"/functional/video/codec/codecs/ivahd_api/_build/drishti.testapps/slaveapps/vcodec/ivahd_api_host_git.a \
   "${DUCATI_REPO_PATH}"/ducati-mm/WTSD_DucatiMMSW/ext_rel/ivahd_codecs/packages/ti/sdo/codecs/jpegvenc/lib/

cp "${TC_REPO_PATH}"/functional/video/codec/codecs/ivahd_mjpegenc/_build/drishti.testapps/slaveapps/vcodec/ivahd_mjpege_m3_api_git.a \
   "${DUCATI_REPO_PATH}"/ducati-mm/WTSD_DucatiMMSW/ext_rel/ivahd_codecs/packages/ti/sdo/codecs/jpegvenc/lib/
}
fi


if ${UPDATE_TEST_DEC}; then
# H264DEC
cp "${TC_REPO_PATH}"/functional/video/codec/codecs/ivahd_api/_build/drishti.testapps/slaveapps/vcodec/ivahd_api_host_git.a \
   "${DUCATI_REPO_PATH}"/ducati-mm/WTSD_DucatiMMSW/ext_rel/ivahd_codecs/packages/ti/sdo/codecs/h264dec/lib/

cp "${TC_REPO_PATH}"/functional/video/codec/codecs/ivahd_h264dec/_build/drishti.testapps/slaveapps/vcodec/ivahd_h264d_m3_api_git.a \
   "${DUCATI_REPO_PATH}"/ducati-mm/WTSD_DucatiMMSW/ext_rel/ivahd_codecs/packages/ti/sdo/codecs/h264dec/lib/

cp "${TC_REPO_PATH}"/functional/video/vidlibs/gdr/_build/drishti.testapps/slaveapps/vcodec/vidlib_gdr.a \
   "${DUCATI_REPO_PATH}"/ducati-mm/WTSD_DucatiMMSW/ext_rel/ivahd_codecs/packages/ti/sdo/codecs/h264dec/lib/

# H263DEC
cp "${TC_REPO_PATH}"/functional/video/codec/codecs/ivahd_api/_build/drishti.testapps/slaveapps/vcodec/ivahd_api_host_git.a \
   "${DUCATI_REPO_PATH}"/ducati-mm/WTSD_DucatiMMSW/ext_rel/ivahd_codecs/packages/ti/sdo/codecs/mpeg4dec/lib/

cp "${TC_REPO_PATH}"/functional/video/codec/codecs/ivahd_h263dec/_build/drishti.testapps/slaveapps/vcodec/ivahd_h263d_m3_api_git.a \
   "${DUCATI_REPO_PATH}"/ducati-mm/WTSD_DucatiMMSW/ext_rel/ivahd_codecs/packages/ti/sdo/codecs/mpeg4dec/lib/

comment () {
# MJPEGDEC
cp "${TC_REPO_PATH}"/functional/video/codec/codecs/ivahd_api/_build/drishti.testapps/slaveapps/vcodec/ivahd_api_host_git.a \
   "${DUCATI_REPO_PATH}"/ducati-mm/WTSD_DucatiMMSW/ext_rel/ivahd_codecs/packages/ti/sdo/codecs/jpegvdec/lib/

cp "${TC_REPO_PATH}"/functional/video/codec/codecs/ivahd_mjpegdec/_build/drishti.testapps/slaveapps/vcodec/mjpegd_icont1/jpegvdec_ti_icont1_static_data_generated.h/mjpegd_icont1/ivahd_mjpegd_errorconceal_eclib_git.a \
   "${DUCATI_REPO_PATH}"/ducati-mm/WTSD_DucatiMMSW/ext_rel/ivahd_codecs/packages/ti/sdo/codecs/jpegvdec/lib/

cp "${TC_REPO_PATH}"/functional/video/codec/codecs/ivahd_mjpegdec/_build/drishti.testapps/slaveapps/vcodec/ivahd_mjpegd_m3_api_git.a \
   "${DUCATI_REPO_PATH}"/ducati-mm/WTSD_DucatiMMSW/ext_rel/ivahd_codecs/packages/ti/sdo/codecs/jpegvdec/lib/
}
fi
echo -e "\n${GREEN}copied codec binaries to ducati repo...${NC}"


# cp header files to ttvenc_dce and ttvdec_dce
if ${UPDATE_TEST_ENC}; then
# H264ENC
cp "${TC_REPO_PATH}"/functional/video/codec/codecs/ivahd_h264enc/_build/drishti.testapps/git@lys-git_cisco_com_projects_video_ivahd_h264e/Inc/ih264enc.h \
   "${TC_REPO_PATH}"/functional/video/codec/codecs/ttvenc_dce/

# H263ENC
cp "${TC_REPO_PATH}"/functional/video/codec/codecs/ivahd_h263enc/_build/drishti.testapps/git@lys-git_cisco_com_projects_video_ivahd_h263e/Inc/impeg4enc.h \
   "${TC_REPO_PATH}"/functional/video/codec/codecs/ttvenc_dce/

comment () {
# MJPEGENC
cp "${TC_REPO_PATH}"/functional/video/codec/codecs/ivahd_mjpegenc/_build/drishti.testapps/git@lys-git_cisco_com_projects_video_ivahd_mjpege/inc/ijpegenc.h \
   "${TC_REPO_PATH}"/functional/video/codec/codecs/ttvenc_dce/
}
fi


if ${UPDATE_TEST_DEC}; then
# H264DEC
cp "${TC_REPO_PATH}"/functional/video/codec/codecs/ivahd_h264dec/_build/drishti.testapps/git@lys-git_cisco_com_projects_video_ivahd_h264d/Inc/ih264vdec.h \
   "${TC_REPO_PATH}"/functional/video/codec/codecs/ttvdec_dce/

# H263DEC
cp "${TC_REPO_PATH}"/functional/video/codec/codecs/ivahd_h263dec/_build/drishti.testapps/git@lys-git_cisco_com_projects_video_ivahd_h263d/Inc/impeg4vdec.h \
   "${TC_REPO_PATH}"/functional/video/codec/codecs/ttvdec_dce/
sed -i '/ires_hdvicp2.h/d' "${TC_REPO_PATH}"/functional/video/codec/codecs/ttvdec_dce/impeg4vdec.h

comment () {
# MJPEGDEC
cp "${TC_REPO_PATH}"/functional/video/codec/codecs/ivahd_mjpegdec/_build/drishti.testapps/git@lys-git_cisco_com_projects_video_ivahd_mjpegd/inc/ijpegvdec.h \
   "${TC_REPO_PATH}"/functional/video/codec/codecs/ttvdec_dce/
}
fi
echo -e "\n${GREEN}copied header files to tc main...${NC}"


# rebuild tc in parallel
echo -e "\n${GREEN}building system-trunk-main with changed codec headers...${NC}"
(cd "${TC_REPO_PATH}"; ./build/build -t drishti.testapps -j24 &>/dev/null; echo "$?" > /tmp/tc_exit_status_"${USER}") &
tc_build_pid=$(echo $!)


# build ducati firmware in parallel
echo -e "\n${GREEN}ducati build with new codec binaries in progress...${NC}"
(cd "${DUCATI_REPO_PATH}"; ./ducati-scripts/ducati-build --drishti &>/dev/null; echo "$?" > /tmp/ducati_exit_status_"${USER}") &


# wait for tc build to complete and check for errors and binst
wait "${tc_build_pid}" &>/dev/null
tc_build_status=$(cat /tmp/tc_exit_status_$USER)
if [ "${tc_build_status}" -ne 0 ]; then
    echo -e "\n${RED}system-trunk-main drishti.testapps build failed${NC}\n" >&2
    exit 1
fi
echo -e "\n${GREEN}built system-trunk-main with changed codec headers...${NC}"

echo -e "\n${GREEN}binst in progress...${NC}"
(cd "${TC_REPO_PATH}"; bin/binst -v -t drishti.testapps "${IP_ADDR}" &>/dev/null; echo "$?" > /tmp/binst_exit_status_"${USER}") &


# wait for binst and ducati build to complete and check for errors
wait &>/dev/null
binst_status=$(cat /tmp/binst_exit_status_"${USER}")
ducati_build_status=$(cat /tmp/ducati_exit_status_"${USER}")
if [ "${binst_status}" -ne 0 ]; then
    echo -e "\n${RED}binst failed${NC}\n" >&2
    exit 1
fi
if [ "${ducati_build_status}" -ne 0 ]; then
    echo -e "\n${RED}ducati build failed${NC}\n" >&2
    exit 1
fi
echo -e "\n${GREEN}binst completed...${NC}"
echo -e "\n${GREEN}ducati build completed...${NC}"


# wait until Drishti is back online after reboot
DRISHTI_ONLINE=false
echo -e "\n${GREEN}waiting for Drishti to come online after reboot...${NC}"
for i in {1..600}; do
    if ping -c 1 -w 1 "${IP_ADDR}" &>/dev/null; then
        DRISHTI_ONLINE=true
        break
    fi
done

if ! ${DRISHTI_ONLINE}; then
    echo -e "\n${RED}waited for 10 min. could not connect to Drishti${NC}\n" >&2
    exit 1
fi
sleep 20


# backup original ducati firmware on Drishti and copy newly build ducati firmware to Drishti
ssh root@"${IP_ADDR}" "cp /mnt/base/active/ti-firmware-ipu-mm.xem3{,_orig}"
if ! scp "${DUCATI_REPO_PATH}"/install/ducati-mm/ti-firmware-ipu-mm.xem3 root@"${IP_ADDR}":/mnt/base/active/ &>/dev/null; then
    echo -e "\n${RED}failed to copy ducati firmware to Drishti${NC}\n" >&2
    exit 1
fi


# reload ducati w/o rebooting
ssh root@"${IP_ADDR}" '/apps/ducati-crash.sh' &>/dev/null
sleep 10
echo -e "\n${GREEN}updated ducati firmware on Drishti...${NC}"


# transfer test streams to Drishti
echo -e "\n${GREEN}transfer of test streams to Drishti in progress...${NC}"
if ${UPDATE_TEST_ENC}; then
    if ! scp -r /export/home/varupati/enc_test_streams root@"${IP_ADDR}":/mnt/base/ &>/dev/null; then
        echo -e "\n${RED}failed to transfer encoder test streams to Drishti${NC}\n" >&2
        exit 1
    fi
fi
if ${UPDATE_TEST_DEC}; then
    if scp -r /export/home/varupati/dec_test_streams root@"${IP_ADDR}":/mnt/base/ &>/dev/null; then
        echo -e "\n${RED}failed to transfer decoder test streams to Drishti${NC}\n" >&2
        exit 1
    fi
fi
echo -e "\n${GREEN}transfer of test streams to Drishti completed...${NC}"


# test vidcodec encoder
if ${UPDATE_TEST_ENC}; then
for i in $(ssh root@"${IP_ADDR}" "ls ${ENC_TEST_STREAMS_PATH}"); do

    # extract width of test stream from name
    width=$(echo $i | awk -F"_" '{print $2}' | awk -F"x" '{print $1}')

    # extract height of test stream from name
    height=$(echo $i | awk -F"_" '{print $2}' | awk -F"x" '{print $2}')

    # extract filename without extension
    filename=$(echo $i | awk -F"." '{print $1}')

    # test h264 encoder

    # check exit status of h264 encoder
    if ssh root@"${IP_ADDR}" "LD_LIBRARY_PATH=:/extra/lib /apps/vidcodec.elf enc -e ttvenc_h264_dce -s ${width} ${height} -f YUV420SemiPlanar -P 1000000 ${ENC_TEST_STREAMS_PATH}/${i} ${filename}.264 &>/dev/null" &>/dev/null; then
        # h264 md5sum verification
        new_md5=$(ssh root@"${IP_ADDR}" "md5sum ${filename.264}" | awk '{print $1}')
        orig_md5=$(awk "/${filename}.264/"'{print $1}' /export/home/varupati/enc_md5sums)
        if [ "${new_md5}" != "${orig_md5}" ]; then
            echo -e "\n${RED}h264 enc : md5sum mismatch for input stream $i${NC}" >&2
            ENC_TESTS_PASSED=false
            #exit 1
        else
            echo -e "\n${GREEN}h264enc passed with stream $i${NC}"
        fi
    else
        echo -e "\n${RED}h264enc failed with stream $i${NC}"
        ENC_TESTS_PASSED=false
        #exit 1
    fi

    sleep 2

    # test h263 encoder

    # check exit status of h263 encoder
    if ssh root@"${IP_ADDR}" "LD_LIBRARY_PATH=:/extra/lib /apps/vidcodec.elf enc -e ttvenc_h263_dce -s ${width} ${height} -f YUV420SemiPlanar -B 2048000 -P 1000000 ${ENC_TEST_STREAMS_PATH}/${i} ${filename}.263 &>/dev/null" &>/dev/null; then
        # h263 md5sum verification
        new_md5=$(ssh root@"${IP_ADDR}" "md5sum ${filename}.263" | awk '{print $1}')
        orig_md5=$(awk "/${filename}.263/"'{print $1}' /export/home/varupati/enc_md5sums)
        if [ "$new_md5" != "$orig_md5" ]; then
            echo -e "\n${RED}h263 enc : md5sum mismatch for input stream $i${NC}" >&2
            ENC_TESTS_PASSED=false
            #exit 1
        else
            echo -e "\n${GREEN}h263enc passed with stream $i${NC}"
        fi
    else
        echo -e "\n${RED}h263enc failed with stream $i${NC}" >&2
        ENC_TESTS_PASSED=false
        #exit 1
    fi

    sleep 2

    comment () {
    # test mjpeg encoder

    # check exit status of mjpeg encoder
    if ssh root@"${IP_ADDR}" "LD_LIBRARY_PATH=:/extra/lib /apps/vidcodec.elf enc -e ttvenc_mjpeg_dce -s ${width} ${height} -f YUV420SemiPlanar -B 2048000 -P 1000000 ${ENC_TEST_STREAMS_PATH}/${i} ${filename}.mjpeg &>/dev/null" &>/dev/null; then
        # mjpeg md5sum verification
        new_md5=$(ssh root@"${IP_ADDR}" "md5sum ${filename}.mjpeg" | awk '{print $1}')
        orig_md5=$(awk "/${filename}.mjpeg/"'{print $1}' /export/home/varupati/enc_md5sums)
        if [ "$new_md5" != "$orig_md5" ]; then
            echo -e "\n${RED}mjpeg enc : md5sum mismatch for input stream $i${NC}" >&2
            ENC_TESTS_PASSED=false
            #exit 1
        else
            echo -e "\n${GREEN}mjpegenc passed with stream $i${NC}"
        fi
    else
        echo -e "\n${RED}mjpegenc failed with stream $i${nc}" >&2
        ENC_TESTS_PASSED=false
        #exit 1
    fi

    sleep 2
    }

done
echo -e "\n${GREEN}all encoder tests completed...${NC}"
if ! ${ENC_TESTS_PASSED}; then
    echo -e "\n${RED}one or more encoder tests have failed${NC}" >&2
fi
else
    ENC_TESTS_PASSED=false
fi


# test vidcodec decoder
if ${UPDATE_TEST_DEC}; then
echo -e "\n${GREEN}decoder tests in progress...${NC}"
if ssh root@"${IP_ADDR}" "cd ${DEC_TEST_STREAMS_PATH}; cp /apps/vidcodec.elf ./vidcodec; LD_LIBRARY_PATH=:/extra/lib /extra/bin/python ./codectest.py --xml-file=test_cases.xml vidcodec 'Drishti H.264 Decode Conformance'; rm -rf /tmp/root-2013-*; rm ./vidcodec" > $HOME/dec_tests_log 2>&1; then
    echo -e "\n${RED}could not execute decoder tests on Drishti${NC}" >&2
    DEC_TESTS_PASSED=false
    #exit 1
else
    echo -e "\n${GREEN}all decoder tests completed... see ~/dec_tests_log for a detailed report${NC}"

    if grep Failed "${HOME}"/dec_tests_log &>/dev/null; then
        echo -e "\n${RED}one or more decoder tests have failed. see ~/dec_tests_log for a detailed report${NC}"
        DEC_TESTS_PASSED=false
    fi
fi
else
    DEC_TESTS_PASSED=false
fi


# send mail to user regarding informing result of codec tests
if ! ${ENC_TESTS_PASSED}; then
    mail -s "codec_upgrade_and_test.sh : one or more encoder tests have failed" "$(basename "${HOME}")"@cisco.com < /dev/null &>/dev/null
fi
if ! ${DEC_TESTS_PASSED}; then
    mail -s "codec_upgrade_and_test.sh : one or more decoder tests have failed" "$(basename "${HOME}")"@cisco.com < /dev/null &>/dev/null
fi


# commit ducati repo changes for encoder
if ${COMMIT} && ${ENC_TESTS_PASSED}; then
    cd "${DUCATI_REPO_PATH}"/ducati-mm
    git add WTSD_DucatiMMSW/ext_rel/ivahd_codecs/packages/ti/sdo/codecs/*enc &>/dev/null
    date="$(date)"
    git commit -m "updating encoder binaries - ${date}" &>/dev/null
    ducati_commit_id="$(git rev-parse HEAD)"


    # commit encoder header file changes
    cd "${TC_REPO_PATH}"
    git add functional/video/codec/codecs/ttvenc_dce &>/dev/null
    git commit -m "updating encoder header files to comply with updated encoder binaries" &>/dev/null


    # update ducati tag in tc repo for encoder update
    cd "${TC_REPO_PATH}"/product/drishti/target/ducati
    sed -ri "7c \
    \ \ \ \ ducati_mm_version = '${ducati_commit_id}'" genmake.def &>/dev/null
    git add "${TC_REPO_PATH}"/product/drishti/target/ducati/genmake.def &>/dev/null
    git commit -m "updating ducati tag" &>/dev/null

    echo -e "\n${GREEN}encoder changes have been committed...${NC}"
fi


# commit ducati repo changes for decoder
if ${COMMIT} && ${DEC_TESTS_PASSED}; then
    cd "${DUCATI_REPO_PATH}"/ducati-mm
    git add WTSD_DucatiMMSW/ext_rel/ivahd_codecs/packages/ti/sdo/codecs/*dec &>/dev/null
    date="$(date)"
    git commit -m "updating decoder binaries - ${date}" &>/dev/null
    ducati_commit_id="$(git rev-parse HEAD)"


    # commit decoder header file changes
    cd "${TC_REPO_PATH}"
    git add functional/video/codec/codecs/ttvdec_dce &>/dev/null
    git commit -m "updating decoder header files to comply with updated decoder binaries" &>/dev/null


    # update ducati tag in tc repo for decoder update
    cd "${TC_REPO_PATH}"/product/drishti/target/ducati
    sed -ri "7c \
    \ \ \ \ ducati_mm_version = '${ducati_commit_id}'" genmake.def &>/dev/null
    git add "${TC_REPO_PATH}"/product/drishti/target/ducati/genmake.def &>/dev/null
    git commit -m "updating ducati tag" &>/dev/null

    echo -e "\n${GREEN}decoder changes have been committed...${NC}"
fi

echo ""
# exit shell script with proper return value
if ! ${ENC_TESTS_PASSED} || ! ${DEC_TESTS_PASSED}; then exit 1; fi
exit 0
