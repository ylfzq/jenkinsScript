#!/bin/bash

### 方法简要说明：
### 1. 是先查找一个字符串：带双引号的key。如果没找到，则直接返回defaultValue。
### 2. 查找最近的冒号，找到后认为值的部分开始了，直到在层数上等于0时找到这3个字符：,}]。
### 3. 如果有多个同名key，则依次全部打印（不论层级，只按出现顺序）
### @author lux feary
###
### 3 params: json, key, defaultValue
function getJsonValuesByAwk() {
    awk -v json="${1//\\/\\\\}" -v key="$2" -v defaultValue="$3" 'BEGIN{
        if (length(key) == 0) decodeAndPrintText(json);

        foundKeyCount = 0
        while (length(json) > 0) {
            # pos = index(json, "\""key"\""); ## 这行更快一些，但是如果有value是字符串，且刚好与要查找的key相同，会被误认为是key而导致值获取错误
            pos = match(json, "\""key"\"[ \\t]*?:[ \\t]*");
            if (pos == 0) {if (foundKeyCount == 0) {decodeAndPrintText(defaultValue);} exit 0;}

            ++foundKeyCount;
            start = 0; stop = 0; layer = 0;
            for (i = pos + length(key) + 1; i <= length(json); ++i) {
                lastChar = substr(json, i - 1, 1)
                currChar = substr(json, i, 1)

                if (start <= 0) {
                    if (lastChar == ":") {
                        start = currChar == " " ? i + 1: i;
                        if (currChar == "{" || currChar == "[") {
                            layer = 1;
                        }
                    }
                } else {
                    if (currChar == "{" || currChar == "[") {
                        ++layer;
                    }
                    if (currChar == "}" || currChar == "]") {
                        --layer;
                    }
                    if ((currChar == "," || currChar == "}" || currChar == "]") && layer <= 0) {
                        stop = currChar == "," ? i : i + 1 + layer;
                        break;
                    }
                }
            }

            if (start <= 0 || stop <= 0 || start > length(json) || stop > length(json) || start >= stop) {
                if (foundKeyCount == 0) {decodeAndPrintText(defaultValue);} exit 0;
            } else {
                decodeAndPrintText(substr(json, start, stop - start))
            }

            json = substr(json, stop + 1, length(json) - stop)
        }
    }
    function decodeAndPrintText(text) {
        decodeAndPrintText_len = length(text);
        for (decodeAndPrintText_i = 1; decodeAndPrintText_i <= decodeAndPrintText_len; ++decodeAndPrintText_i) {
            if (substr(text, decodeAndPrintText_i, 1) == "\\") {
                if (substr(text, decodeAndPrintText_i + 1, 1) == "u") {
                    unicodeToChar(hexToDec(substr(text, decodeAndPrintText_i + 2, 4)));
                    decodeAndPrintText_i += 5;
                } else {
                    decodeAndPrintText_i += 1;
                    printf("%s", substr(text, decodeAndPrintText_i, 1));
                }
            } else {
                printf("%s", substr(text, decodeAndPrintText_i, 1));
            }
        }
        printf("\n");
    }
    function unicodeToChar(c) {
        if (c < hexToDec("80")) { 
            printf("%c", c);
            return;
        }

        ### encode to UTF-8
        unicodeToChar_o=hexToDec("3f")    # Ceiling
        unicodeToChar_p=hexToDec("80")    # Accum. bits
        unicodeToChar_s=""                # Output string
        while (c > unicodeToChar_o) {
            unicodeToChar_s = sprintf("%c%s", or(hexToDec("80"), and(c, hexToDec("3f"))), unicodeToChar_s);
            c = rshift(c, 6); 
            unicodeToChar_p += unicodeToChar_o + 1; 
            unicodeToChar_o = rshift(unicodeToChar_o, 1);
        }
        printf("%c%s", or(unicodeToChar_p, c), unicodeToChar_s);
    }
    function hexToDec(hexStr) {
        hextodec["0"]=0;  hextodec["1"]=1;  hextodec["2"]=2;  hextodec["3"]=3;
        hextodec["4"]=4;  hextodec["5"]=5;  hextodec["6"]=6;  hextodec["7"]=7;
        hextodec["8"]=8;  hextodec["9"]=9;  hextodec["a"]=10; hextodec["b"]=11;
        hextodec["c"]=12; hextodec["d"]=13; hextodec["e"]=14; hextodec["f"]=15;
        hextodec["A"]=10; hextodec["B"]=11; hextodec["C"]=12; hextodec["D"]=13;
        hextodec["E"]=14; hextodec["F"]=15;

        hexToDec_result = 0;
        for (hexToDec_i = 1; hexToDec_i <= length(hexStr); hexToDec_i++) {
            hexToDec_c = substr(hexStr, hexToDec_i, 1);
            if (hexToDec_c in hextodec) {
                hexToDec_result = hexToDec_result * 16 + hextodec[hexToDec_c];
            } else {
                print "illegal hex number"hexStr;
                exit 1;
            }
        }
        return hexToDec_result;
    }
    function rshift(num, count) {
        return int(num / 2^count)
    }
    function and(num1, num2) {
        T["0", "0"]=0; T["0", "1"]=0;
        T["1", "0"]=0; T["1", "1"]=1;
        return bitTransform(num1, num2, T);
    }
    function or(num1, num2) {
        T["0", "0"]=0; T["0", "1"]=1;
        T["1", "0"]=1; T["1", "1"]=1;
        return bitTransform(num1, num2, T);
    }
    function bitTransform(num1, num2, table) {
        bitTransform_result = 0;
        bitTransform_factor = 1;
        while (num1 > 0 || num2 > 0) {
            bitTransform_result += table[num1 % 2, num2 % 2] * bitTransform_factor;
            num1 = int(num1 / 2);
            num2 = int(num2 / 2);
            bitTransform_factor *= 2;
        }
        return bitTransform_result;
    }
    '
}

### Trim prefix and suffix space chars, you can specify trim chars by yourself
### @author lux feary
###
### 1 param: trimChars
function trim() {
    awk -v trimChars="$1" 'BEGIN{if (length(trimChars) == 0) trimChars=" ";} {
        line = $0
        for (startPos = 1; startPos <= length(line); ++startPos) {
            if (index(trimChars, substr(line, startPos, 1)) == 0) break;
        }

        for (endPos = length(line); endPos >= 1; --endPos) {
            if (index(trimChars, substr(line, endPos, 1)) == 0) break;
        }

        print substr(line, startPos, endPos - startPos + 1);
    }'
}

### 说明：当前只支持Android
### 说明：APP_ID, APP_NAME, APP_VERSION, APP_BUILD实际上可以根据apk自动读取，但因脚本无外部依赖，因此还需要外部传入
### 说明：APP_NAME, APP_VERSION, APP_BUILD, APP_CHANGELOG只用于展示，如果不填写，不影响使用，只不过下载页会缺少这些信息
### @author lux feary
###
### 8 params: APP_FILE, FIR_API_TOKEN, APP_ID, APP_NAME, APP_VERSION, APP_BUILD, APP_ICON, APP_CHANGELOG
### output variable: 
###     - FIR_RESULT
###     - FIR_SHORT_URL
###     - FIR_DIRECT_URL
function apiUploadToFir() {
    local APP_FILE=$1
    local FIR_API_TOKEN=$2

    local APP_ID="$3"
    local APP_NAME="${4:-$3}"
    local APP_VERSION="${5:-1.0.0}"
    local APP_BUILD="${6:-1}"
    local APP_ICON="$7"
    local APP_CHANGELOG="${8}"

    unset FIR_RESULT
    unset FIR_SHORT_URL
    unset FIR_DIRECT_URL

    local FIR_APP_TYPE="android"

    [ "${APP_FILE:${#APP_FILE}-4}" == ".apk" ] || { echo "only Android is supported now"; return 1; }

    echo "Fetching fir.im upload token..."
    local resultJson=$(curl -X "POST" "https://api.fir.im/apps" -H "Content-Type: application/json" -d "{\"type\":\"${FIR_APP_TYPE}\", \"bundle_id\":\"${APP_ID}\", \"api_token\":\"${FIR_API_TOKEN}\"}" 2>/dev/null)

    ### parse the 1st layer
    local formMethod=$(getJsonValuesByAwk "$resultJson" "form_method" "POST" | trim '"')
    local shortUrl=$(getJsonValuesByAwk "$resultJson" "short" | trim '"')
    local cert="$(getJsonValuesByAwk "$resultJson" "cert")"

    [ -n "$shortUrl" ] || { 
        echo "Fetch upload token failed, please check your fir api token: $FIR_API_TOKEN"
        export FIR_RESULT="$resultJson"
        return 1
    }
    local shortUrl="https://fir.im/$shortUrl"

    ### parse the cert layer
    local cert_prefix=$(getJsonValuesByAwk "$cert" "prefix" | trim '"')
    local cert_binary="$(getJsonValuesByAwk "$cert" "binary")"
    local cert_icon="$(getJsonValuesByAwk "$cert" "icon")"

    ### get icon upload params
    local icon_key=$(getJsonValuesByAwk "$cert_icon" "key" | trim '"')
    local icon_token=$(getJsonValuesByAwk "$cert_icon" "token" | trim '"')
    local icon_uploadUrl=$(getJsonValuesByAwk "$cert_icon" "upload_url" | trim '"')

    ### get binary upload params
    local binary_key=$(getJsonValuesByAwk "$cert_binary" "key" | trim '"')
    local binary_token=$(getJsonValuesByAwk "$cert_binary" "token" | trim '"')
    local binary_uploadUrl=$(getJsonValuesByAwk "$cert_binary" "upload_url" | trim '"')

    if [ -n "$APP_ICON" ]; then
        echo "Uploading icon to ${icon_uploadUrl}..."
        local resultJson=$(curl "$APP_ICON" 2>/dev/null | curl --progress-bar -X "$formMethod" -F "key=${icon_key}" -F "token=${icon_token}" -F "file=@-" ${icon_uploadUrl})
        local isCompleted="$(getJsonValuesByAwk "$resultJson" "is_completed")"
        if [[ "$isCompleted" == "true" ]]; then
            echo "Upload icon success: $APP_ICON"
        else
            echo "Upload icon failed, it doesn't matter much that only the icon is default"
        fi
    elif which unzip > /dev/null; then
        echo "Uploading icon to ${icon_uploadUrl}..."
        local checkIcons=(
            "res/mipmap-xxhdpi-v4/ic_launcher.png"
            "res/mipmap-xhdpi-v4/ic_launcher.png"
            "res/drawable-xxhdpi-v4/ic_launcher.png"
            "res/drawable-xhdpi-v4/ic_launcher.png"
            ""
        )

        local checkIconPath;
        for checkIconPath in ${checkIcons[@]}; do
            unzip -l "$APP_FILE" "$checkIconPath" >/dev/null && break;
        done

        if [ -n "$checkIconPath" ]; then
            local resultJson=$(unzip -p ${APP_FILE} "$checkIconPath" | curl --progress-bar -X "$formMethod" -F "key=${icon_key}" -F "token=${icon_token}" -F "file=@-" ${icon_uploadUrl})
            local isCompleted="$(getJsonValuesByAwk "$resultJson" "is_completed")"
            if [[ "$isCompleted" == "true" ]]; then
                echo "Upload icon success: $checkIconPath"
            else
                echo "Upload icon failed, it doesn't matter much that only the icon is default"
            fi
        fi
    else
        echo "skip uploading icon"
    fi

    echo "Uploading Apk to ${binary_uploadUrl}..."
    local resultJson="$(curl --progress-bar -X "$formMethod" -F "key=${binary_key}" -F "token=${binary_token}" -F "file=@${APP_FILE}" -F "${cert_prefix}name=${APP_NAME}" -F "${cert_prefix}version=${APP_VERSION}" -F "${cert_prefix}build=${APP_BUILD}" -F "${cert_prefix}changelog=${APP_CHANGELOG}" ${binary_uploadUrl})"
    local isCompleted=$(getJsonValuesByAwk "$resultJson" "is_completed")
    if [[ "$isCompleted" == "true" ]]; then
        export FIR_RESULT="true"
        export FIR_SHORT_URL="$shortUrl"
        export FIR_DIRECT_URL="$(getJsonValuesByAwk "$resultJson" "download_url" | trim '"')"
        return 0
    else
        export FIR_RESULT="$resultJson"
        return 1
    fi
}

### 4 params: APP_FILE, API_KEY, APP_CHANGELOG, APP_PASSOWRD
### output variable: 
###     - PGYER_RESULT
###     - PGYER_APP_NAME
###     - PGYER_APP_VERSION_NO
###     - PGYER_APP_VERSION
###     - PGYER_APP_PACKAGE_NAME
###     - PGYER_APP_ICON_URL
###     - PGYER_SHORT_URL
###     - PGYER_QRCODE_URL
function apiUploadToPgyer() {
    local APP_FILE="$1"
    local API_KEY="$2"
    local APP_CHANGELOG="$3"
    local APP_PASSOWRD="$4"

    unset PGYER_RESULT
    unset PGYER_APP_NAME
    unset PGYER_APP_VERSION_NO
    unset PGYER_APP_VERSION
    unset PGYER_APP_PACKAGE_NAME
    unset PGYER_APP_ICON_URL
    unset PGYER_SHORT_URL
    unset PGYER_QRCODE_URL

    local resultJson=$(curl --progress-bar -F "_api_key=${API_KEY}" -F "file=@${APP_FILE}" -F "buildInstallType=2" -F "buildPassword=${APP_PASSOWRD}" -F "buildUpdateDescription=${APP_CHANGELOG}" https://www.pgyer.com/apiv2/app/upload)

    ### example resultJson
    # local resultJson='{
    #     "code":0,
    #     "message":"",
    #     "data":{
    #         "buildKey":"49af40xxxxeb03xxec126d36314xx249",    // Build Key是唯一标识应用的索引ID
    #         "buildType":"2",                                  // 应用类型（1:iOS; 2:Android）
    #         "buildIsFirst":"0",                               // 是否是第一个App（1:是; 2:否）
    #         "buildIsLastest":"1",                             // 是否是最新版（1:是; 2:否）
    #         "buildFileKey":"04d67f7d1xxxx59ad25xxxxd333104ea.apk",    
    #         "buildFileName":"app-dev-official-debug.apk",
    #         "buildFileSize":"2827486",                        // App 文件大小
    #         "buildName":"ZqDemo",                             // 应用名称
    #         "buildVersion":"1.0",                             // 版本号, 默认为1.0 (是应用向用户宣传时候用到的标识，例如：1.1、8.2.1等。)
    #         "buildVersionNo":"1",                             // 上传包的版本编号，默认为1 (即编译的版本号，一般来说，编译一次会变动一次这个版本号, 在 Android 上叫 Version Code。对于 iOS 来说，是字符串类型；对于 Android 来说是一个整数。例如：1001，28等。)
    #         "buildBuildVersion":"1",                          // 蒲公英生成的用于区分历史版本的build号
    #         "buildIdentifier":"zq.library.zqdemo",            // 应用程序包名，iOS为BundleId，Android为包名
    #         "buildIcon":"fae387940a1xxxxc22c3bxxxxcce0007",   // 应用的Icon图标key，访问地址为 https://www.pgyer.com/image/view/app_icons/[应用的Icon图标key]
    #         "buildDescription":"",                            // 应用介绍
    #         "buildUpdateDescription":"uploaded by shell script",  // 应用更新说明
    #         "buildScreenshots":"",                            // 应用截图的key，获取地址为 https://www.pgyer.com/image/view/app_screenshots/[应用截图的key]
    #         "buildShortcutUrl":"xxxx",                        // 应用短链接
    #         "buildCreated":"2018-01-16 12:57:38",             // 应用上传时间
    #         "buildUpdated":"2018-01-16 12:57:38",             // 应用更新时间
    #         "buildQRCodeURL":"https:\/\/www.pgyer.com\/app\/qrcodeHistory\/9a5e3f712e679ef704af6ea808d297d18a603a49d3113b309510151e523ab990"  // 应用二维码地址
    #     }
    # }'
    
    if [[ "$(getJsonValuesByAwk "$resultJson" "code" | trim '"')" == "0" ]]; then
        export PGYER_RESULT="true"
        export PGYER_APP_NAME="$(getJsonValuesByAwk "$resultJson" "buildName" | trim '"')"
        export PGYER_APP_VERSION_NO="$(getJsonValuesByAwk "$resultJson" "buildVersionNo" | trim '"')"
        export PGYER_APP_VERSION="$(getJsonValuesByAwk "$resultJson" "buildVersion" | trim '"')"
        export PGYER_APP_PACKAGE_NAME="$(getJsonValuesByAwk "$resultJson" "buildIdentifier" | trim '"')"
        export PGYER_APP_ICON_URL="https://www.pgyer.com/image/view/app_icons/$(getJsonValuesByAwk "$resultJson" "buildIcon" | trim '"')"
        export PGYER_SHORT_URL="https://www.pgyer.com/$(getJsonValuesByAwk "$resultJson" "buildShortcutUrl" | trim '"')"
        export PGYER_QRCODE_URL="$(getJsonValuesByAwk "$resultJson" "buildQRCodeURL" | trim '"')"
        return 0;
    else
        export PGYER_RESULT="$resultJson"
        return 1;
    fi
}

### 必须要定义PGYER_TOKEN，会先上传pgyer.com。上传成功后，如果有FIR_TOKEN的定义，则再上传fir.im。
### 为什么先上传pgyer.com？ -因为fir.im需要的上传参数太多，脚本很难自动获取，而pgyer.com上传成功后刚好会返回所需上传参数。
function uploadApkFile() {
    local apkFile="$1"
    local appChangelog="$2"
    local PGYER_TOKEN="$3"
    local FIR_TOKEN="$4"

    [[ -z "$PGYER_TOKEN" ]] && { echo "PGYER_TOKEN can't be empty"; return 1; }

    echo "APK file path: $apkFile"

    echo "Uploading apk to pgyer.com..."
    apiUploadToPgyer "$apkFile" \
    "$PGYER_TOKEN" \
    "$appChangelog"

    [[ "$PGYER_RESULT" == "true" ]] || { echo "Upload to pgyer failed: $PGYER_RESULT"; return 1; }

    if [ -z "$FIR_TOKEN" ]; then
        ### 不存在FIR_TOKEN，就不上传fir，仍认为是成功
        echo "FIR_TOKEN不存在或格式不对：$FIR_TOKEN"
    else
        echo "Uploading apk to fir.im..."
        apiUploadToFir "$apkFile" \
        "$FIR_TOKEN" \
        "$PGYER_APP_PACKAGE_NAME" \
        "$PGYER_APP_NAME" \
        "$PGYER_APP_VERSION" \
        "$PGYER_APP_VERSION_NO" \
        "$PGYER_APP_ICON_URL" \
        "$appChangelog"

        if [[ "$FIR_RESULT" != "true" ]]; then
            ### 虽然上传fir失败，但因为上传pgyer已经成功，仍认为是成功
            echo "上传fir失败：$FIR_RESULT"
        fi
    fi

    echo "==============================================================================="
    echo "appName             $PGYER_APP_NAME"
    echo "appVersionNo        $PGYER_APP_VERSION_NO"
    echo "appVersion          $PGYER_APP_VERSION"
    echo "packageName         $PGYER_APP_PACKAGE_NAME"
    echo "pgyer_icon_url      $PGYER_APP_ICON_URL"
    echo "pgyer_short_url     $PGYER_SHORT_URL"
    echo "pgyer_qrcode_url    $PGYER_QRCODE_URL"
    echo "fir_short_url       $FIR_SHORT_URL"
    echo "fir_direct_url      $FIR_DIRECT_URL"
    echo "==============================================================================="
    return 0
}

function listFiles(){
    local currDir="${1:-.}"
    local namePattern="$2"
    ls -A "$currDir" | while read file; do
        if [ -d "$currDir/$file" ]; then
            listFiles "$currDir/$file" "$namePattern"
        else
            if [ -n "$namePattern" ]; then
                case "$currDir/$file" in
                    $namePattern)
                        echo "$currDir/$file"
                    ;;
                esac
            else
                echo "$currDir/$file"
            fi
        fi
    done
}

function findAndUploadApk() {
    local projectDir="$1"
    local CHANGELOG="${2:-uploaded by shell script}"
    local PGYER_TOKEN="$3"
    local FIR_TOKEN="$4"

    ### the $projectDir self is a file
    if [ -f "$projectDir" ]; then
        if [[ "${projectDir:${#projectDir}-4}" != ".apk" ]]; then
            echo "Not a apk file"
            return 1;
        fi
        uploadApkFile "$projectDir" "${CHANGELOG}" "$PGYER_TOKEN" "$FIR_TOKEN"
        return 0;
    fi

    ### the $projectDir is a directory
    if [ -d "$projectDir" ]; then
        echo "Finding apk files...."
        local apkFileList="$(listFiles "$projectDir" "*/build/*.apk")"
        apkFileList=($apkFileList)
        for apkFile in ${apkFileList[@]}; do
            uploadApkFile "$apkFile" "${CHANGELOG}" "$PGYER_TOKEN" "$FIR_TOKEN"
            [[ $? != 0 ]] && echo "upload apk failed: ${apkFile}" && return 1
        done
        return 0
    fi
    
    return 1
}

function _capital_() {
    while read line; do
        echo "$(echo ${line:0:1} | tr '[:lower:]' '[:upper:]')${line:1:${#line}-1}"
    done
}

function mainOfJenkinsCompile() {
    echo "============================================================"
    curl myip.ipip.net 2>/dev/null
    echo "Current user: $USER"
    echo "============================================================"
    
    local projectName="$(ls)"
    if [ -n "$projectName" ]; then
        echo "Found old source dir($projectName), removing it..."
        rm -rf $projectName
    fi
    
    git clone -b $branch "https://${GIT_AUTH}@${gitRepoUrl}" || { echo "git clone failed"; return 1; }
    
    local projectName=$(ls)
    pushd "$projectName" >/dev/null
    echo "Generating dependency tree..."
    ./gradlew -q app:dependencies --configuration ${buildType}CompileClasspath >dependencies.txt
    cat dependencies.txt
    ./gradlew clean assemble$(echo ${buildType} | _capital_) || { echo "Build failed"; return 4; }
    
    [[ "$PGYER_TOKEN" =~ \(([0-9a-zA-Z]{32})\) ]] && PGYER_TOKEN="${BASH_REMATCH[1]}"
    [[ "$FIR_TOKEN" =~ \(([0-9a-zA-Z]{32})\) ]] && FIR_TOKEN="${BASH_REMATCH[1]}"

    findAndUploadApk "$PWD" "#${BUILD_NUMBER}_${BUILD_USER}_${buildType}@${branch}: ${CHANGELOG}" "$PGYER_TOKEN" "$FIR_TOKEN"
    local result="$?"
    popd >/dev/null

    echo "SetBuildDescription: <a href='$FIR_SHORT_URL' target='_blank'>$FIR_SHORT_URL</a><br/><a href='$PGYER_SHORT_URL' target='_blank'><img src='$PGYER_QRCODE_URL' alt='在当前页打开apk下载页'/></a><br/>"
    return $result
}

[[ "$1" == "-uploadOnly" ]] && {
    [[ "$PGYER_TOKEN" =~ \(([0-9a-zA-Z]{32})\) ]] && PGYER_TOKEN="${BASH_REMATCH[1]}"
    [[ "$FIR_TOKEN" =~ \(([0-9a-zA-Z]{32})\) ]] && FIR_TOKEN="${BASH_REMATCH[1]}"
    findAndUploadApk "$2" "${3:-uploaded by shell script}" "$PGYER_TOKEN" "$FIR_TOKEN"
    exit $?
}

# export JAVA_HOME="path to your JAVA_HOME"
# export ANDROID_HOME="path to your ANDROID_HOME"
# export GIT_AUTH="your_git_username:your_git_password"
# export PGYER_TOKEN=""

# ### Parameters begin ###
# # git仓库地址
# export gitRepoUrl=""
# # git分支名：master develop
# export branch=""
# # 构建类型/渠道
# export buildType=""
# # fir.im token，如果要上传到自己的fir上，换成自己的token就好。不想上传，则使此字段留空即可
# export FIR_TOKEN=""
# # changelog，会出现在下载页上的版本更新说明。支持中文。
# export CHANGELOG="uploaded by shell script"
# ### Parameters end ###

mainOfJenkinsCompile
exit $?