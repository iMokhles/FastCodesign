# أسرع اداة لتوثيق التطبيقات و تكرارها

# اسم شهادة المطورين
Certificate_Name="iPhone Developer: cheap1@totoateam.com (75WM8K376R)"

# مسار بروفايل
Profile_Path="/Users/imokhles/Downloads/FastCodesign/profile1.mobileprovision"

#مسار ملفات التطبيقات
IPAS_FOLDER="/Users/imokhles/Downloads/FastCodesign/files"

#عدد التكرارات المرادة
DUPLICATS_NUMBER="2"

# مسار استخراج الملفات بعد التوقيع
OUTPUT_DIR="/Users/imokhles/Downloads/FastCodesign/files_out"

logit() {

    echo "FastCodesign: [`date`] - ${*}"

}

WORKING_PATH="$OUTPUT_DIR/WorkingPath"
EXTRACTED_IPA_PATH="$WORKING_PATH/EXTRACTED_IPA"
TEMP_PATH="$OUTPUT_DIR/temp"
FRAMEWORKS_DIRS_FILE="$TEMP_PATH/dirs.txt"
DYLIBS_DIRS_FILE="$TEMP_PATH/dylibs_dirs.txt"
OTA_IPA_PATH="$OUTPUT_DIR/ipa/"

CURRENT_TIME_EPOCH=$(date +"%s")

createWantedDirs() {

logit "Create Directories"

rm -Rf "$WORKING_PATH"

if [ -d "$TEMP_PATH" ];then
    logit "Removing Dir: $TEMP_PATH"
    rm -Rf "$TEMP_PATH"
fi
    logit "Creating Dir: $TEMP_PATH"
    mkdir -p "$TEMP_PATH" || true

if [ -d "$EXTRACTED_IPA_PATH" ];then
    logit "Removing Dir: $EXTRACTED_IPA_PATH"
    rm -Rf "$EXTRACTED_IPA_PATH"
fi
    logit "Creating Dir: $EXTRACTED_IPA_PATH"
    mkdir -p "$EXTRACTED_IPA_PATH" || true

if [ -d "$OTA_IPA_PATH" ];then
    logit "Removing Dir: $OTA_IPA_PATH"
fi
    logit "Creating Dir: $OTA_IPA_PATH"
    mkdir -p "$OTA_IPA_PATH" || true

}

# $1 password
# $2 path
# usage = unlockKeychain password path.keychain

unlockKeychain() {
    security unlock-keychain -p "$1" "$2"
}

# $1 = ipa file
# $2 = extracted ipa path
unzipIPAFile() {
    logit "Unzipping IPA File: $1"
    logit "Unzipping Output Dir: $2"
    unzip -oqq "$1" -d "$2"
}

makeBinaryExecutable() {
    logit "Make App Binary Executable"
    chmod +x "$1"
}


setupVariables() {

    AppPath=$(set -- "$EXTRACTED_IPA_PATH/Payload/"*.app; echo "$1")

    val=$(/usr/libexec/PlistBuddy -c "Print CFBundleDisplayName"  "$AppPath/Info.plist" 2>/dev/null)
    exitCode=$?

if (( exitCode == 0 )); then
    HOOKED_APP_NAME=$(/usr/libexec/PlistBuddy -c "Print CFBundleDisplayName"  "$AppPath/Info.plist")

else
    /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string" "$AppPath/Info.plist"
    HOOKED_APP_NAME=$(/usr/libexec/PlistBuddy -c "Print CFBundleName"  "$AppPath/Info.plist")
fi

    HOOKED_APP_BUNDLE_NAME=$(/usr/libexec/PlistBuddy -c "Print CFBundleName"  "$AppPath/Info.plist")
    HOOKED_EXECUTABLE=$(/usr/libexec/PlistBuddy -c "Print CFBundleExecutable"  "$AppPath/Info.plist")
    HOOKED_EXE_PATH="$AppPath/$HOOKED_EXECUTABLE"

    filename=$(basename "$HOOKED_EXE_PATH")
    extension="${filename##*.}"
    filename="${filename%.*}"

    HOOKED_APP_BUNDLE_NAME="$HOOKED_APP_BUNDLE_NAME"
    HOOKED_APP_BUNDLE_NAME=${HOOKED_APP_BUNDLE_NAME// /_}

    HOOKED_APP_NAME="$HOOKED_APP_NAME"
    HOOKED_APP_NAME=${HOOKED_APP_NAME// /_}


}

# $1 = app name
# $2 = app bundle
addNewEntries() {

    AppPath=$(set -- "$EXTRACTED_IPA_PATH/Payload/"*.app; echo "$1")

    /usr/libexec/PlistBuddy -c "Add ::UIDeviceFamily:0 integer 1" "$AppPath/Info.plist"
    /usr/libexec/PlistBuddy -c "Add ::UIDeviceFamily:1 integer 2" "$AppPath/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :MinimumOSVersion 8.0" "$AppPath/Info.plist"

    /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $1" "$AppPath/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $2" "$AppPath/Info.plist"
}

getCorrectEntitlements() {

    TEMP_PLIST="$TEMP_PATH/temp.plist"
    REAL_CODE_SIGN_ENTITLEMENTS="$TEMP_PATH/app.entitlements"
    security cms -D -i "$Profile_Path" -o "$TEMP_PLIST"
    /usr/libexec/PlistBuddy -c "Print Entitlements" "$TEMP_PLIST" -x > "$REAL_CODE_SIGN_ENTITLEMENTS"

}

resignDYlibs() {

    AppEntitlements="$TEMP_PATH/app.entitlements"

    find -d "$AppPath" \( -name "*.dylib" -o -name "*cycript" -o -name "*cynject" -o -name "*cycc" -o -name "*cydiasubstrate" \) > $DYLIBS_DIRS_FILE

    while IFS='' read -r line || [[ -n "$line" ]]; do
        codesign -fs "$Certificate_Name" --entitlements "$AppEntitlements"  "$line"
    done < $DYLIBS_DIRS_FILE

}

resignPlugins() {
    AppPath=$(set -- "$EXTRACTED_IPA_PATH/Payload/"*.app; echo "$1")
    APP_PLUGINS_PATH="$AppPath/PlugIns"
    rm -rf "$APP_PLUGINS_PATH"
}

resignWatchPlugin() {
    AppPath=$(set -- "$EXTRACTED_IPA_PATH/Payload/"*.app; echo "$1")
    APP_WATCH_PATH="$AppPath/Watch"
    rm -rf "$APP_WATCH_PATH"
}

resignFrameworks() {

    AppEntitlements="$TEMP_PATH/app.entitlements"

    find -d "$AppPath" \( -name "*.framework" \) > $FRAMEWORKS_DIRS_FILE

    while IFS='' read -r line || [[ -n "$line" ]]; do
        codesign -fs "$Certificate_Name" --entitlements "$AppEntitlements"  "$line"
    done < $FRAMEWORKS_DIRS_FILE
}

resignMainBundle() {
    logit "sign app main bundle"

    AppPath=$(set -- "$EXTRACTED_IPA_PATH/Payload/"*.app; echo "$1")
    AppEntitlements="$TEMP_PATH/app.entitlements"

    cp "$Profile_Path" "$AppPath/embedded.mobileprovision"
    codesign -fs "$Certificate_Name" --entitlements "$AppEntitlements" --timestamp=none "$AppPath"
}

# $1 = app name
archiveAppAgainToIPA() {

    logit "archiveAppAgainToIPA: $1"
    cd "$EXTRACTED_IPA_PATH"
    zip -qry "$1.ipa" Payload/ >/dev/null 2>&1
    cd ../../
    cp "$EXTRACTED_IPA_PATH/$1.ipa" "$OUTPUT_DIR/ipa"

    logit "done"
}

if [ "$DUPLICATS_NUMBER" -eq "0" ];then
# resign without duplicates

for IPA_FILE in "$IPAS_FOLDER/"*
do

    createWantedDirs

    unzipIPAFile "$IPA_FILE" "$EXTRACTED_IPA_PATH"

    getCorrectEntitlements

    setupVariables

    makeBinaryExecutable "$HOOKED_EXE_PATH"

    addNewEntries "$HOOKED_APP_NAME" "$HOOKED_APP_BUNDLE_NAME"

    resignDYlibs

    resignPlugins

    resignWatchPlugin

    resignFrameworks

    resignMainBundle

    archiveAppAgainToIPA "$HOOKED_APP_NAME"

    rm -rf "$WORKING_PATH" || true
    rm -rf "$TEMP_PATH" || true

done


else
# resign with duplicates

for IPA_FILE in "$IPAS_FOLDER/"*
do

for (( dupNUM=1; dupNUM<=DUPLICATS_NUMBER; dupNUM++ ))
do

createWantedDirs

unzipIPAFile "$IPA_FILE" "$EXTRACTED_IPA_PATH"

getCorrectEntitlements

setupVariables

makeBinaryExecutable "$HOOKED_EXE_PATH"

addNewEntries "$HOOKED_APP_NAME-$dupNUM" "$HOOKED_APP_BUNDLE_NAME-$dupNUM"

resignDYlibs

resignPlugins

resignWatchPlugin

resignFrameworks

resignMainBundle

archiveAppAgainToIPA "$HOOKED_APP_NAME-$dupNUM"

rm -rf "$WORKING_PATH" || true
rm -rf "$TEMP_PATH" || true

if [ "$dupNUM" -eq "$DUPLICATS_NUMBER" ];then
echo "Finished"
fi

done

done

fi
