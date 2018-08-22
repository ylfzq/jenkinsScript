#!/bin/bash

function printEnv() {
    echo "============================================================"
    case "$(uname -s)" in
        "Darwin")   #Mac
            uname -a
            awk -version
        ;;
        "Linux")    #Linux
            lsb_release -a 2>/dev/null | grep "Description:" | awk -F\\t '{print $2}'
            awk -W version
        ;;
        *)
            echo "Unknown kernel name $(uname -s)"
        ;;
    esac
    curl --version
    git --version
    which python >/dev/null && python -V
    echo "Current user: $USER"
    echo "JAVA_HOME=$JAVA_HOME"
    echo "ANDROID_HOME=$ANDROID_HOME"
    echo "PATH=$PATH"
    curl myip.ipip.net 2>/dev/null
    echo "============================================================"
}

### ======================================================================== ###

function preCompile() {
    export gitCommitId="$(git rev-parse HEAD)"
    echo "Git commit id: $gitCommitId" >dependencies.txt
    echo "Generating dependency tree..."
    ./gradlew $additionalGradleOptions -q app:dependencies --configuration ${buildType}CompileClasspath >>dependencies.txt && cat dependencies.txt
}

### ======================================================================== ###

function _capital_() {
    while read line; do
        echo "$(echo ${line:0:1} | tr '[:lower:]' '[:upper:]')${line:1:${#line}-1}"
    done
}

function compile() {
    ./gradlew $additionalGradleOptions clean assemble$(echo ${buildType} | _capital_) || { echo "Build failed"; return 1; }
}

### ======================================================================== ###

function getJsonValues() {
    local key="$2"
    local defaultValue="$3"
    echo "$1" | python -c "
import json,sys;
def printf(text):
    if isinstance(text, list) or isinstance(text, dict): 
        sys.stdout.write(json.dumps(text) + '\n')
    elif str(type(text)) == \"<type 'unicode'>\":
        printf(text.encode('utf-8')) # text.encode() return str
    elif isinstance(text, str):
        sys.stdout.write('\"' + text + '\"\n')
    elif isinstance(text, bool):
        sys.stdout.write('true' if text else 'false' + '\n')
    else:
        sys.stdout.write(str(text) + '\n')
def findKey(obj, key):
    count = 0
    for (k,v) in obj.items():
        if k == key:
            count += 1
            printf(v)
        elif isinstance(v, dict):
            count += findKey(v, key)
    return count
if findKey(json.load(sys.stdin), '$key') == 0:
    sys.stdout.write('$defaultValue\n')
    "
}

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

function apiUploadToReiko() {
    local appFile="$1"
    local apiToken="$2"
    local apiIsMine="$3"
    local appChangelog="$4"
    local appPassword="$5"

    unset REIKO_RESULT
    unset REIKO_APP_NAME
    unset REIKO_APP_BUILD
    unset REIKO_APP_VERSION
    unset REIKO_APP_PACKAGE_NAME
    unset REIKO_APP_ICON_URL
    unset REIKO_SHORT_URL
    unset REIKO_QRCODE_URL

    local resultJson=$(curl -k --progress-bar -H "x-reiko-api-token:${apiToken}" -F "file=@${appFile}" -F "isMine=${apiIsMine}" -F "extraInfo=[{\"key\": \"changelog\", \"value\": \"${appChangelog}\"}]" https://reiko.souche-inc.com/api/v2/package/upload)
    
    if [[ "$(getJsonValues "$resultJson" "code" | trim '"')" == "200" ]]; then
        export REIKO_RESULT="true"
        export REIKO_APP_NAME="$(getJsonValues "$resultJson" "appName" | trim '"')"
        export REIKO_APP_BUILD="$(getJsonValues "$resultJson" "versionCode" | trim '"')"
        export REIKO_APP_VERSION="$(getJsonValues "$resultJson" "versionName" | trim '"')"
        export REIKO_APP_PACKAGE_NAME="$(getJsonValues "$resultJson" "packageName" | trim '"')"
        export REIKO_APP_ICON_URL="$(getJsonValues "$resultJson" "icon" | trim '"')"
        export REIKO_SHORT_URL="$(getJsonValues "$resultJson" "packageDownLoadPage" | trim '"')"
        export REIKO_QRCODE_URL="$(getJsonValues "$resultJson" "qrcode" | trim '"')"
        return 0;
    else
        export REIKO_RESULT="$resultJson"
        return 1;
    fi
}

function uploadApkFile() {
    local tmp=""
    local apkFile=""
    while read tmp; do
        echo "found apk: $tmp"
        [ -n "$apkFile" ] && { echo "发现了多个匹配的apk文件，停止上传"; return 1; }
        local apkFile="$tmp"
    done

    local appChangelog="$1"
    local reikoToken="$2"
    local reikoIsMine="$3"

    [ -z "$reikoToken" ] && { echo "未指定reiko的上传token或格式不正确，放弃上传"; return 0; }

    echo "Uploading apk to reiko.souche-inc.com..."
    apiUploadToReiko "$apkFile" \
    "$reikoToken" \
    "$reikoIsMine" \
    "$appChangelog"

    [[ "$REIKO_RESULT" != "true" ]] && { echo "上传reiko失败：$REIKO_RESULT"; return 3; }

    echo "==============================================================================="
    echo "appName             $REIKO_APP_NAME"
    echo "packageName         $REIKO_APP_PACKAGE_NAME"
    echo "appBuild            $REIKO_APP_BUILD"
    echo "appVersion          $REIKO_APP_VERSION"

    echo "reiko_icon_url      $REIKO_APP_ICON_URL"
    echo "reiko_short_url     $REIKO_SHORT_URL"
    echo "reiko_qrcode_url    $REIKO_QRCODE_URL"
    echo "==============================================================================="
    return 0
}

function postCompile() {
    [[ "$REIKO_TOKEN" =~ \(([0-9a-zA-Z]{32})\) ]] && REIKO_TOKEN="${BASH_REMATCH[1]}"
    find "$PWD" -path "*/build/*.apk" | uploadApkFile "#${BUILD_NUMBER}_${BUILD_USER}_${buildType}@${branch}-${gitCommitId}: ${CHANGELOG}" "$REIKO_TOKEN" "$REIKO_IS_MINE" || return 1
    echo "SetBuildDescription: <a href='$REIKO_SHORT_URL' target='_blank'><img src='$REIKO_QRCODE_URL' alt='在当前页打开apk下载页' width='200'/></a><br/><a href='$REIKO_SHORT_URL' target='_blank'>$REIKO_SHORT_URL</a><br/>"
}

printEnv
preCompile && compile && postCompile
