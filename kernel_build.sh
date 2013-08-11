#!/bin/bash
#
# script to automate stable kernel building process
# keep .kernel_config in ~/

date=`date`
cd ~
version=`cat ~/.kernel_version`
wget https://www.kernel.org/pub/linux/kernel/v3.x/linux-3.10.${version}.tar.xz
if [ $? -ne 0 ]; then
    echo "kernel 3.10.${version} download failed -- ${date}"
    rm -rf linux-3*
    exit 1
fi
tar xf linux-3*.tar.xz
cp ~/.kernel_config ~/linux-3*/.config
cd ~/linux-3*/
yes "" | make oldconfig
fakeroot make-kpkg -j60 --initrd --append-to-version=-xubuntu kernel_image kernel_headers modules_image > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "kernel build failed"
    exit 1
fi
version=$((version+1))
rm ~/.kernel_version
echo $version > ~/.kernel_version
cd ~
rm -rf linux-3*
ping -c 1 -t 10 10.142.50.208
if [ $? -eq 0 ]; then
    scp ~/*.deb varun@10.142.50.208:~/
fi
