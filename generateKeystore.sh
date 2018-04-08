#!/bin/bash

function randomString() {
	## simplest way: $(date +%s | sha256sum | base64 | head -c 32 ; echo)
	local charset=${2:-'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-+_=`~@#%^&'}
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
	-storepass "$password" -keypass "$password"
	# -dname "CN=名字与姓氏, OU=组织单位名称, O=组织名称, L=所在的城市或区域名称, ST=省/市/自治区名称, C=单位的双字母国家/地区代码" \
	
	echo ""
	echo "[Cert SHA1]"
	local keystoreInfo="$($JAVA_HOME/bin/keytool -v -list -keystore "$keystoreName.jks" -storepass "$password" -keypass "$password")"
	echo "$keystoreInfo" | grep "SHA1" | awk '{print $2}'

	echo "New keystore:   $PWD/$keystoreName.jks" > "$keystoreName.secret.txt"
	echo "Key alias:      $keystoreName" >> "$keystoreName.secret.txt"
	echo "Storepass:      $password" >> "$keystoreName.secret.txt"
	echo "Keypass:        $password" >> "$keystoreName.secret.txt"
	echo "" >> "$keystoreName.secret.txt"
	echo "" >> "$keystoreName.secret.txt"
	echo "=== Detailed Info ===" >> "$keystoreName.secret.txt"
	echo "password='$password'; keytool -v -list -keystore '$keystoreName.jks' -storepass '$password' -keypass '$password'; unset password" >> "$keystoreName.secret.txt"
	echo "$keystoreInfo" >> "$keystoreName.secret.txt"
	echo "" >> "$keystoreName.secret.txt"
	echo "" >> "$keystoreName.secret.txt"
	echo "$($JAVA_HOME/bin/keytool -list -rfc -keystore "$keystoreName.jks" -storepass "$password" -keypass "$password")" >> "$keystoreName.secret.txt"

}

keysotrepass="$(randomString 12)"
generateKeyStore keystore "$keysotrepass"
