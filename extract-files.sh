#!/bin/bash
#
# Copyright (C) 2016 The CyanogenMod Project
# Copyright (C) 2017-2023 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

DEVICE=GS5
VENDOR=gigaset

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "${MY_DIR}" ]]; then MY_DIR="${PWD}"; fi

ANDROID_ROOT="${MY_DIR}/../../.."

HELPER="${ANDROID_ROOT}/tools/extract-utils/extract_utils.sh"
if [ ! -f "${HELPER}" ]; then
    echo "Unable to find helper script at ${HELPER}"
    exit 1
fi
source "${HELPER}"

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true

ONLY_FIRMWARE=
KANG=
SECTION=

while [ "${#}" -gt 0 ]; do
    case "${1}" in
        --only-firmware )
                ONLY_FIRMWARE=true
                ;;
        -n | --no-cleanup )
                CLEAN_VENDOR=false
                ;;
        -k | --kang )
                KANG="--kang"
                ;;
        -s | --section )
                SECTION="${2}"; shift
                CLEAN_VENDOR=false
                ;;
        * )
                SRC="${1}"
                ;;
    esac
    shift
done

function blob_fixup {
    case "$1" in
        system_ext/lib64/libsource.so)
            "${PATCHELF}" --add-needed "libui_shim.so" "${2}"
            ;;
        vendor/bin/hw/mtkfusionrild)
        "${PATCHELF}" --add-needed "libutils-v32.so" "${2}"
            ;;
        vendor/lib64/libwifi-hal-mtk.so)
            "${PATCHELF}" --set-soname "libwifi-hal-mtk.so" "${2}"
            ;;
        vendor/bin/hw/vendor.mediatek.hardware.mtkpower@1.0-service)
            "${PATCHELF}" --replace-needed "android.hardware.power-V2-ndk_platform.so" "android.hardware.power-V2-ndk.so" "${2}"
            ;;
        vendor/bin/hw/android.hardware.gnss-service.mediatek | vendor/lib64/hw/android.hardware.gnss-impl-mediatek.so)
            "${PATCHELF}" --replace-needed "android.hardware.gnss-V1-ndk_platform.so" "android.hardware.gnss-V1-ndk.so" "${2}"
            ;;
        vendor/lib*/hw/vendor.mediatek.hardware.pq@2.15-impl.so)
            "${PATCHELF}" --replace-needed "libutils.so" "libutils-v32.so" "${2}"
            ;;
        vendor/lib64/libmtkcam_stdutils.so|\
        vendor/lib64/hw/android.hardware.camera.provider@2.6-impl-mediatek.so)
            "${PATCHELF}" --replace-needed "libutils.so" "libutils-v32.so" "${2}"
            ;;
        vendor/etc/gnss/agps_profiles_conf2.xml)
            sed -i 's|imsi_enable="true"|imsi_enable="false"|' "${2}"
            ;;
        vendor/bin/factory)
            "${PATCHELF}" --replace-needed "android.hardware.light-V1-ndk_platform.so" "android.hardware.light-V1-ndk.so" "${2}"
            ;;
        vendor/lib64/libwvhidl.so)
            "${PATCHELF}" --replace-needed "libprotobuf-cpp-lite-3.9.1.so" "libprotobuf-cpp-full-3.9.1.so" "${2}"
            ;;
        vendor/lib64/mediadrm/libwvdrmengine.so)
            "${PATCHELF}" --replace-needed "libprotobuf-cpp-lite-3.9.1.so" "libprotobuf-cpp-full-3.9.1.so" "${2}"
            ;;
        vendor/bin/mnld)
            ;&
        vendor/lib64/libcam.utils.sensorprovider.so)
            "${PATCHELF}" --replace-needed "libsensorndkbridge.so" "libsensorndkbridge-v30.so" "${2}"
            ;;
        vendor/bin/hw/android.hardware.media.c2@1.2-mediatek)
            "${PATCHELF}" --add-needed "libstagefright_foundation-v33.so" "${2}"
            ;;
        vendor/lib64/hw/hwcomposer.mt6768.so)
            grep -q "libprocessgroup_shim.so" "${2}" || "${PATCHELF}" --add-needed "libprocessgroup_shim.so" "${2}"
            ;;
        vendor/bin/STFlashTool|\
        vendor/bin/hw/android.hardware.neuralnetworks@1.3-service-mtk-neuron|\
        vendor/bin/hw/android.hardware.usb@1.2-service-mediatekv2|\
        vendor/bin/hw/android.hardware.sensors@2.0-service.multihal-mediatek|\
        vendor/bin/nfcstackp-vendor|\
        vendor/bin/factory|\
        vendor/lib64/libnvram.so|\
        vendor/lib64/libsysenv.so|\
        vendor/lib64/libtflite_mtk.so|\
        vendor/lib/libnvram.so|\
        vendor/lib/libsysenv.so|\
        vendor/lib/libtflite_mtk.so)
            grep -q "libbase_shim.so" "${2}" || "${PATCHELF}" --add-needed "libbase_shim.so" "${2}"
            ;;
    esac
}

if [ -z "${SRC}" ]; then
    SRC="adb"
fi

# Initialize the helper
setup_vendor "${DEVICE}" "${VENDOR}" "${ANDROID_ROOT}" true "${CLEAN_VENDOR}"

if [ -z "${ONLY_FIRMWARE}" ]; then
    extract "${MY_DIR}/proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"
fi

if [ -z "${SECTION}" ]; then
    extract_firmware "${MY_DIR}/proprietary-firmware.txt" "${SRC}"
fi

"${MY_DIR}/setup-makefiles.sh"
