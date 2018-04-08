#!/bin/bash

function randomString() {
	## simplest way: $(date +%s | sha256sum | base64 | head -c 32 ; echo)
	local charset=${2:-'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-+_=`~!@#$%^&./|\?'}
	local str=""
	for i in $(seq 1 ${1:-8}); do local str="$str${charset:$RANDOM%${#charset}:1}"; done
	echo $str
}

function generateKeyStore() {
	local keystoreName=${1:-keystore}
	local password=${2:-123456}
	$JAVA_HOME/bin/keytool -v -genkey -keyalg RSA -keysize 2048 -validity 13325 \
	-keystore "$keystoreName.jks" \
	-alias "$keystoreName" \
	-dname "CN=Repack, OU=OU, O=O, L=L, ST=ST, C=CN" \
	-storepass "$password" -keypass "$password"
	# "CN=名字与姓氏, OU=组织单位名称, O=组织名称, L=所在的城市或区域名称, ST=省/市/自治区名称, C=单位的双字母国家/地区代码"
	# "CN=英菲尼迪, OU=大搜车汽车服务有限公司, O=无线架构组, L=杭州, ST=浙江, C=CN"
}

function signApk() {
	local apkFile="$1"
	local keystoreName=${2:-keystore}
	local password=${3:-123456}

	([ -f "$apkFile" ] && [ "${apkFile:${#apkFile}-4}" == ".apk" ]) || (echo "Not a apk file" && return 1)
	local signedApk="${apkFile:0:${#apkFile}-4}_signed.apk"

	$JAVA_HOME/bin/jarsigner -verbose \
	-keystore "$keystoreName.jks" \
	-storepass "$password" \
	-keypass "$password" \
	-signedjar "$signedApk" "$apkFile" "$keystoreName" >/dev/null
	echo "$signedApk"
}

function zipalign() {
	local apkFile="$1"

	([ -f "$apkFile" ] && [ "${apkFile:${#apkFile}-4}" == ".apk" ]) || (echo "Not a apk file" && return 1)
	local alignedApk="${apkFile:0:${#apkFile}-4}_aligned.apk"

	local A=$(ls $ANDROID_HOME/build-tools/) && local A=($A)
	local latestVersion=${A[${#A[@]}-1]}
	$ANDROID_HOME/build-tools/$latestVersion/zipalign 4 "$apkFile" "$alignedApk" >/dev/null
	echo "$alignedApk"
}

function main() {
	apkFile="$1"
	keystoreName="${2:-keystore}"
	password="${3:-123456}"

	([ -f "$apkFile" ] && [ "${apkFile:${#apkFile}-4}" == ".apk" ]) || (echo "Not a apk file" && exit 1)

	[ -f "$keystoreName.jks" ] || generateKeyStore "$keystoreName" "$password" || (echo "generate keystore failed" && exit 1)

	sinedApk=$(signApk "$apkFile" "$keystoreName" "$password")
	[ -n "$sinedApk" ] || (echo "Sign apk failed" && exit 1)

	alignedApk=$(zipalign "$sinedApk")
	[ -n "$alignedApk" ] || (echo "align apk failed" && exit 1)

	echo "===== === === apk has signed and aligned === === ====="
	echo "$alignedApk"
	echo "======================================================"
}

main "$1" "$2" "$3"
