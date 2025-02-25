#!/bin/bash

if [ "$#" -ne 1 ]; then
  echo "This script requires the product parameter: pxb24, pxb80!"
  echo "Usage: ./$0 <product>"
  exit 1
fi

SCRIPT_PWD=$(cd `dirname $0` && pwd)
#SCRIPT_PWD="$HOME/package-testing"
log="/tmp/binary_check.log"
>${log}

source "${SCRIPT_PWD}"/VERSIONS

if [ "$1" = "pxb80" ]; then
    product=pxb80
    version=${PXB80_VER}
    major_version="${PXB80_VER}"
    minor_version="${PXB80PKG_VER}"
    echo "Downloading ${1} latest version..." >> "${log}"
    wget https://www.percona.com/downloads/Percona-XtraBackup-LATEST/Percona-XtraBackup-${major_version}-${minor_version}/binary/tarball/percona-xtrabackup-${major_version}-${minor_version}-Linux-x86_64.glibc2.17.tar.gz
    tarball_dir="percona-xtrabackup-${major_version}-${minor_version}-Linux-x86_64.glibc2.17"

    echo "Extracting binary" >> "${log}"
    tar -xf percona-xtrabackup-${major_version}-${minor_version}-Linux-x86_64.glibc2.17.tar.gz
    mv ${tarball_dir} ${product}
    tarball_dir=${product}

    exec_files="xbcloud xbcrypt xbstream xtrabackup"

elif [ $1 = "pxb24" ]; then
    product="pxb24"
    version="${PXB24_VER}"

    echo "Downloading ${1} latest version..." >> "${log}"
    wget https://www.percona.com/downloads/Percona-XtraBackup-2.4/Percona-XtraBackup-${version}/binary/tarball/percona-xtrabackup-${version}-Linux-x86_64.glibc2.12.tar.gz
    tarball_dir="percona-xtrabackup-${version}-Linux-x86_64.glibc2.12"

    echo "Extracting binary" >> "${log}"
    tar -xf percona-xtrabackup-${version}-Linux-x86_64.glibc2.12.tar.gz
    mv ${tarball_dir} ${product}
    tarball_dir=${product}

    exec_files="xbcloud xbcrypt xbstream xtrabackup innobackupex"

elif [ $1 = "psmdb40" -o $1 = "psmdb42" ]; then
    product=$1
    if [ $1 = "psmdb40" ]; then
        version=${PSMDB40_VER}
    elif [ $1 = "psmdb42" ]; then
        version=${PSMDB42_VER}
    fi
    major_version=$(echo ${version}| cut -f1-2 -d.)
    if [ -f /etc/redhat-release ]; then
        centos_version=$(cat /etc/redhat-release | grep -o "[0-9]" | head -n 1)
        if [ "${centos_version}" -eq 6 ]; then
            dist="centos6"
        elif [ "${centos_version}" -eq 7 ]; then
            dist="centos7"
        elif [ "${centos_version}" -eq 8 ]; then
            dist="centos8"
        fi
    else
        debian_version=$(lsb_release -d |cut -f1 -d.|grep -oE "[0-9]+" | head -n 1)
        if [ "${debian_version}" -eq 9 ]; then
            dist="stretch"
        elif [ "${debian_version}" -eq 16 ]; then
            dist="xenial"
        elif [ "${debian_version}" -eq 18 ]; then
            dist="bionic"
        elif [ "${debian_version}" -eq 19 ]; then
            dist="disco"
        fi
    fi

    echo "Downloading ${1} latest version..." >> "${log}"
    wget https://www.percona.com/downloads/percona-server-mongodb-${major_version}/percona-server-mongodb-${version}/binary/tarball/percona-server-mongodb-${version}-${dist}-x86_64.tar.gz
    tarball_dir="percona-server-mongodb-${version}"

    echo "Extracting binary" >> "${log}"
    tar -xf percona-server-mongodb-${version}-${dist}-x86_64.tar.gz
    mv ${tarball_dir} ${product}
    tarball_dir=${product}

    exec_files="mongo mongod mongoexport mongoimport mongorestore mongostat perconadecrypt bsondump mongobridge mongodump mongofiles mongoreplay mongos mongotop"
else
  echo "Incorrect product selected!"
  exit 1
fi

echo "Check symlinks for all executables" >> "${log}"
for binary in $exec_files; do
    if [ -f ${tarball_dir}/bin/${binary} ]; then
        echo "Check ${tarball_dir}/bin/${binary}" >> "${log}"
        ldd ${tarball_dir}/bin/${binary} | grep "not found"
        if [ "$?" -eq 0 ]; then
            echo "Err: Binary $binary in version ${version} has an incorrect linked library"
            exit 1
        else
            echo "Binary $binary check passed" >> "${log}"
        fi
    else
        echo "Err: The binary ${tarball_dir}/bin/${binary} was not found"
        exit 1
    fi
done

echo "Check version for binaries in tarball: ${tarball_dir}" >> "${log}"
if [ ${product} = "pxb24" -o ${product} = "pxb80" ]; then
  version_check=$(${tarball_dir}/bin/xtrabackup --version 2>&1|grep -c ${version})
    if [ ${version_check} -eq 0 ]; then
      echo "xtrabackup version is incorrect! Expected version: ${version}"
      exit 1
    else
      echo "xtrabackup version is correctly displayed as: ${version}" >> "${log}"
    fi

    if [ ${product} = "pxb80" ]; then
        for i in xbstream xbcloud xbcrypt; do
            version_check=$(${tarball_dir}/bin/$i --help | grep -c "${version}")
            if [ "${version_check}" -eq 0 ]; then
                echo "${i} version is incorrect! Expected version: ${version}"
                exit 1
            else
                echo "${i} version is correctly displayed as: ${version}" >> "${log}"
            fi
        done
    fi
fi

if [ ${product} = "psmdb40" -o ${product} = "psmdb42" ]; then
    for binary in $exec_files; do
        if [ "${binary}" = "perconadecrypt" -o "${binary}" = "mongobridge" ]; then
            echo "The ${binary} binary does not have a version attached to it" >> "${log}"
            continue
        fi
        version_check=$(${tarball_dir}/bin/${binary} --version 2>&1|grep -c ${version})
        if [ ${version_check} -eq 0 ]; then
            echo "${binary} version is incorrect! Expected version: ${version}"
            exit 1
        else
            echo "${binary} version is correctly displayed as: ${version}" >> "${log}"
        fi
    done
fi
