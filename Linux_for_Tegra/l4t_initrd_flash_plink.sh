#!/bin/bash

set -e;

LDK_DIR=$(cd $(dirname $0) && pwd);
LDK_ROOTFS_DIR="${LDK_DIR}/rootfs";
source ${1}.conf;

function update_fdt_line() {
        # Add FDT lines for multiple menus:
        # If FDT line does not exist in the extlinux.conf, add FDT lines into the
        # extlinux.conf for all menus.
        # If FDT lines exist in the extlinux.conf, delete the existed FDT lines first
        # in case of DTB file been changed or not all of the menus include FDT line,
        # then add new FDT lines into extlinux.conf for all menus.
        #local extlinux_conf="$1";
        local dtb_file="/boot/plink/${2}";
        local fdt_line;
        local linux_num;
        local fdt_num;
	extlinux_conf="${1}/extlinux/extlinux.conf"

        # Delete FDT lines if exist
        sed -i "/.*FDT/d" "${extlinux_conf}";

        # Add FDT lines for all menus: active line and comment line
        fdt_line="FDT ${dtb_file}";
        sed -i "/^[ \t]*LINUX/a\      ${fdt_line}" "${extlinux_conf}";
        sed -i "/^#.*LINUX/a\#    ${fdt_line}" "${extlinux_conf}";

        linux_num="$(grep -c "LINUX .*$" "${extlinux_conf}")";
        fdt_num="$(grep -c "FDT .*$" "${extlinux_conf}")";

        if [ "${fdt_num}" = "${linux_num}" ]; then
                echo -n -e "\tSetting \"FDT ${dtb_file}\" successfully in the extlinux.conf...\n";
        else
                echo -n -e "\tWarning: setting \"FDT ${dtb_file}\" in the extlinux.conf failed!\n";
        fi;
}

update_fdt_line ${LDK_ROOTFS_DIR}/boot ${DTB_FILE};

${LDK_DIR}/l4t_initrd_flash.sh $1 $2;
