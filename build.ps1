# ============================================================
#  MCPE 0.4.0 Android Build Script  —  improved
#  - auto‑detects NDK / SDK
#  - patches Android.mk if TextBox.cpp is missing
#  - builds C++, Java, packages APK (optionally installs)
#
#  Usage:
#    .\build.ps1           # full build
#    .\build.ps1 -NoCpp    # skip NDK rebuild
#    .\build.ps1 -NoJava   # skip Java recompile
#    .\build.ps1 -NoBuild  # repackage + install only
# ============================================================
param(
    [switch]$NoCpp,
    [switch]$NoJava,
    [switch]$NoBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Path detection ───────────────────────────────────────────
function Get-ToolPath([string]$tool, [string]$fallbackPath) {
    if (Test-Path $fallbackPath) { return $fallbackPath }
    $found = Get-Command $tool -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Source
    if ($found) { return $found }
    # try common locations
    $common = @(
        "C:\android-ndk-r14b\ndk-build.cmd",
        "C:\android-ndk-r14b\ndk-build"
    )
    foreach ($c in $common) { if (Test-Path $c) { return $c } }
    throw "$tool not found. Please set $($tool.ToUpper())_HOME environment variable."
}

function Get-SdkTool([string]$tool) {
    $sdkRoot = $env:ANDROID_HOME
    if (-not $sdkRoot) { $sdkRoot = "$env:LOCALAPPDATA\Android\Sdk" }
    $buildTools = Get-ChildItem "$sdkRoot\build-tools" -ErrorAction SilentlyContinue |
                  Sort-Object -Descending | Select-Object -First 1
    if (-not $buildTools) { throw "No build-tools found in $sdkRoot\build-tools" }
    $toolPath = Join-Path $buildTools.FullName "$tool.exe"
    if (-not (Test-Path $toolPath)) { $toolPath = Join-Path $buildTools.FullName "$tool.bat" }
    if (Test-Path $toolPath) { return $toolPath }
    throw "$tool not found in $buildTools"
}

# ── Set up paths ─────────────────────────────────────────────
$repoRoot = $PSScriptRoot
$buildDir = "$repoRoot\build"
$apkbuild = "$buildDir\apk"
$ndkBuild = if ($env:ANDROID_NDK_HOME) { "$env:ANDROID_NDK_HOME\ndk-build.cmd" } else { "C:\android-ndk-r14b\ndk-build.cmd" }
if (-not (Test-Path $ndkBuild)) { $ndkBuild = Get-ToolPath "ndk-build" $ndkBuild }

$sdkRoot = $env:ANDROID_HOME
if (-not $sdkRoot) { $sdkRoot = "$env:LOCALAPPDATA\Android\Sdk" }
if (-not (Test-Path $sdkRoot)) { throw "Android SDK not found. Set ANDROID_HOME." }
$androidJar = "$sdkRoot\platforms\android-36\android.jar"
if (-not (Test-Path $androidJar)) {
    # try latest platform
    $platforms = Get-ChildItem "$sdkRoot\platforms" -ErrorAction SilentlyContinue | Sort-Object -Descending
    if ($platforms) { $androidJar = Join-Path $platforms[0].FullName "android.jar" }
    if (-not (Test-Path $androidJar)) { throw "android.jar not found. Install platform 36 or newer." }
}

$aapt = Get-SdkTool "aapt"
$zipalign = Get-SdkTool "zipalign"
$apksigner = Get-SdkTool "apksigner"
$d8 = Get-SdkTool "d8"
$adb = if (Test-Path "$sdkRoot\platform-tools\adb.exe") { "$sdkRoot\platform-tools\adb.exe" } else { $null }

# keytool
$keytool = if ($env:JAVA_HOME) { "$env:JAVA_HOME\bin\keytool.exe" } else {
    $found = Get-ChildItem "C:\Program Files\Java","C:\Program Files\Eclipse Adoptium" `
        -Filter keytool.exe -Recurse -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending | Select-Object -First 1 -ExpandProperty FullName
    if (-not $found) { throw "keytool not found. Set JAVA_HOME or install a JDK." }
    $found
}

# ── Project paths ─────────────────────────────────────────────
$jniDir     = "$repoRoot\project\android\jni"
$libSrc     = "$repoRoot\project\android\libs\arm64-v8a\libminecraftpe.so"
$libDst     = "$apkbuild\lib\arm64-v8a\libminecraftpe.so"
$manifest   = "$repoRoot\project\android_java\AndroidManifest.xml"
$res        = "$repoRoot\project\android_java\res"
$javaSrc    = "$repoRoot\project\android_java\src"
$stubsDir   = "$apkbuild\stubs"
$rJava      = "$apkbuild\gen\R.java"
$classesDir = "$apkbuild\classes"
$dexOut     = "$apkbuild\classes.dex"
$dataDir    = "$repoRoot\data"
$keystore   = "$apkbuild\debug.keystore"

$unsigned   = "$apkbuild\minecraftpe-unsigned.apk"
$aligned    = "$apkbuild\minecraftpe-aligned.apk"
$signed     = "$apkbuild\minecraftpe-debug.apk"

$pkg        = "com.mojang.minecraftpe"

Add-Type -Assembly "System.IO.Compression.FileSystem"

function Write-Step([string]$msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Assert-ExitCode([string]$step) {
    if ($LASTEXITCODE -ne 0) { Write-Host "FAILED: $step (exit $LASTEXITCODE)" -ForegroundColor Red; exit 1 }
}
function New-Dir([string]$path) { New-Item $path -ItemType Directory -Force | Out-Null }
function Write-Stub([string]$rel, [string]$content) {
    $full = "$stubsDir\$rel"
    New-Dir (Split-Path $full -Parent)
    if (-not (Test-Path $full)) { [System.IO.File]::WriteAllText($full, $content); Write-Host "  stub: $rel" }
}

# ── 0. Bootstrap ─────────────────────────────────────────────
Write-Step "Bootstrap"
New-Dir $apkbuild
New-Dir "$apkbuild\lib\arm64-v8a"
New-Dir "$apkbuild\gen"
New-Dir $stubsDir

if (-not (Test-Path $keystore)) {
    Write-Host "  generating debug.keystore..."
    & $keytool -genkeypair `
        -keystore $keystore -storepass android -keypass android `
        -alias androiddebugkey -keyalg RSA -keysize 2048 -validity 10000 `
        -dname "CN=Android Debug,O=Android,C=US" 2>&1 | Out-Null
    Assert-ExitCode "keytool"
    Write-Host "  keystore created"
} else { Write-Host "  keystore OK" }

# Stub files (as before)...
Write-Stub "com\mojang\android\StringValue.java" "package com.mojang.android;`npublic interface StringValue { String getStringValue(); }`n"
Write-Stub "com\mojang\android\licensing\LicenseCodes.java" "package com.mojang.android.licensing;`npublic class LicenseCodes { public static final int LICENSE_OK = 0; }`n"
Write-Stub "com\mojang\android\EditTextAscii.java" @"
package com.mojang.android;
import android.content.Context;
import android.text.Editable;
import android.text.TextWatcher;
import android.util.AttributeSet;
import android.widget.EditText;
public class EditTextAscii extends EditText implements TextWatcher {
    public EditTextAscii(Context c) { super(c); addTextChangedListener(this); }
    public EditTextAscii(Context c, AttributeSet a) { super(c,a); addTextChangedListener(this); }
    public EditTextAscii(Context c, AttributeSet a, int d) { super(c,a,d); addTextChangedListener(this); }
    @Override public void onTextChanged(CharSequence s,int st,int b,int co){}
    public void beforeTextChanged(CharSequence s,int st,int co,int aft){}
    public void afterTextChanged(Editable e){
        String s=e.toString(),san=sanitize(s);
        if(!s.equals(san))e.replace(0,e.length(),san);
    }
    static public String sanitize(String s){
        StringBuilder sb=new StringBuilder();
        for(int i=0;i<s.length();i++){char c=s.charAt(i);if(c<128)sb.append(c);}
        return sb.toString();
    }
}
"@
Write-Stub "com\mojang\android\preferences\SliderPreference.java" @"
package com.mojang.android.preferences;
import android.content.Context;
import android.content.res.Resources;
import android.preference.DialogPreference;
import android.util.AttributeSet;
import android.view.Gravity;
import android.view.View;
import android.widget.LinearLayout;
import android.widget.SeekBar;
import android.widget.TextView;
public class SliderPreference extends DialogPreference implements SeekBar.OnSeekBarChangeListener {
    private static final String NS="http://schemas.android.com/apk/res/android";
    private Context _ctx; private TextView _tv; private SeekBar _sb;
    private String _suf; private int _def,_max,_val,_min;
    public SliderPreference(Context ctx,AttributeSet a){
        super(ctx,a); _ctx=ctx;
        _suf=gStr(a,NS,"text",""); _def=gInt(a,NS,"defaultValue",0);
        _max=gInt(a,NS,"max",100); _min=gInt(a,null,"min",0);
        setDefaultValue(_def);
    }
    @Override protected View onCreateDialogView(){
        LinearLayout l=new LinearLayout(_ctx); l.setOrientation(LinearLayout.VERTICAL); l.setPadding(6,6,6,6);
        _tv=new TextView(_ctx); _tv.setGravity(Gravity.CENTER_HORIZONTAL); _tv.setTextSize(32);
        l.addView(_tv,new LinearLayout.LayoutParams(-1,-2));
        _sb=new SeekBar(_ctx); _sb.setOnSeekBarChangeListener(this);
        l.addView(_sb,new LinearLayout.LayoutParams(-1,-2));
        if(shouldPersist())_val=getPersistedInt(_def);
        _sb.setMax(_max); _sb.setProgress(_val); return l;
    }
    @Override protected void onSetInitialValue(boolean r,Object d){
        super.onSetInitialValue(r,d);
        _val=r?(shouldPersist()?getPersistedInt(_def):0):(Integer)d;
    }
    public void onProgressChanged(SeekBar s,int v,boolean f){
        _val=v+_min; _tv.setText(_val+_suf);
        if(shouldPersist())persistInt(_val); callChangeListener(Integer.valueOf(_val));
    }
    public void onStartTrackingTouch(SeekBar s){}
    public void onStopTrackingTouch(SeekBar s){}
    private int gInt(AttributeSet a,String ns,String n,int d){int id=a.getAttributeResourceValue(ns,n,0);return id!=0?getContext().getResources().getInteger(id):a.getAttributeIntValue(ns,n,d);}
    private String gStr(AttributeSet a,String ns,String n,String d){int id=a.getAttributeResourceValue(ns,n,0);if(id!=0)return getContext().getResources().getString(id);String v=a.getAttributeValue(ns,n);return v!=null?v:d;}
}
"@
Write-Stub "com\mojang\minecraftpe\MainMenuOptionsActivity.java" @"
package com.mojang.minecraftpe;
import android.app.Activity;
public class MainMenuOptionsActivity extends Activity {
    public static final String Internal_Game_DifficultyPeaceful="internal_game_difficulty_peaceful";
    public static final String Game_DifficultyLevel="game_difficulty";
    public static final String Controls_Sensitivity="controls_sensitivity";
}
"@
Write-Stub "com\mojang\minecraftpe\Minecraft_Market.java" @"
package com.mojang.minecraftpe;
import android.app.Activity; import android.content.Intent; import android.os.Bundle;
public class Minecraft_Market extends Activity {
    @Override protected void onCreate(Bundle s){super.onCreate(s);startActivity(new Intent(this,MainActivity.class));finish();}
}
"@
Write-Stub "com\mojang\minecraftpe\Minecraft_Market_Demo.java" @"
package com.mojang.minecraftpe;
import android.content.Intent; import android.net.Uri;
public class Minecraft_Market_Demo extends MainActivity {
    @Override public void buyGame(){startActivity(new Intent(Intent.ACTION_VIEW,Uri.parse("market://details?id=com.mojang.minecraftpe")));}
    @Override protected boolean isDemo(){return true;}
}
"@
Write-Stub "com\mojang\minecraftpe\GameModeButton.java" @"
package com.mojang.minecraftpe;
import com.mojang.android.StringValue;
import android.content.Context; import android.util.AttributeSet;
import android.view.View; import android.view.View.OnClickListener;
import android.widget.TextView; import android.widget.ToggleButton;
public class GameModeButton extends ToggleButton implements OnClickListener,StringValue {
    static final int Creative=0,Survival=1;
    private int _type=0; private boolean _attached=false;
    public GameModeButton(Context c,AttributeSet a){super(c,a);setOnClickListener(this);}
    public void onClick(View v){_update();}
    @Override protected void onFinishInflate(){super.onFinishInflate();_update();}
    @Override protected void onAttachedToWindow(){if(!_attached){_update();_attached=true;}}
    private void _update(){_set(isChecked()?Survival:Creative);}
    private void _set(int i){
        _type=i<Creative?Creative:(i>Survival?Survival:i);
        int id=_type==Survival?R.string.gamemode_survival_summary:R.string.gamemode_creative_summary;
        String desc=getContext().getString(id);
        View v=getRootView().findViewById(R.id.labelGameModeDesc);
        if(desc!=null&&v instanceof TextView)((TextView)v).setText(desc);
    }
    public String getStringValue(){return new String[]{"creative","survival"}[_type];}
    static public String getStringForType(int i){int c=i<Creative?Creative:(i>Survival?Survival:i);return new String[]{"creative","survival"}[c];}
}
"@

Write-Host "  stubs OK"

# ── 1. Patch Android.mk (if missing TextBox.cpp) ────────────
$mkPath = "$jniDir\Android.mk"
if (Test-Path $mkPath) {
    $content = Get-Content $mkPath -Raw
    if ($content -notmatch "TextBox\.cpp") {
        Write-Host "  patching Android.mk to add TextBox.cpp..."
        $lines = Get-Content $mkPath
        $newLines = @()
        $inserted = $false
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $newLines += $lines[$i]
            if ($lines[$i] -match "^\s*LOCAL_SRC_FILES\s*[+:]?=" -and -not $inserted) {
                $newLines += "LOCAL_SRC_FILES += ../../../src/client/gui/components/TextBox.cpp"
                $inserted = $true
            }
        }
        if (-not $inserted) {
            $newLines += ""
            $newLines += "LOCAL_SRC_FILES += ../../../src/client/gui/components/TextBox.cpp"
        }
        Set-Content $mkPath -Value $newLines
        Write-Host "  Android.mk patched."
    } else {
        Write-Host "  TextBox.cpp already in Android.mk"
    }
} else {
    Write-Host "  Warning: Android.mk not found, skipping patch."
}

# ── 2. NDK build ─────────────────────────────────────────────
if (-not $NoCpp -and -not $NoBuild) {
    Write-Step "NDK build (arm64-v8a)"
    Push-Location $jniDir
    # Use short path to avoid 32K command line limit – set NDK_PROJECT_PATH to parent
    $projectDir = Resolve-Path "$jniDir\.."  # project\android
    $ndkCmd = "$ndkBuild NDK_PROJECT_PATH=`"$projectDir`" APP_BUILD_SCRIPT=`"$jniDir\Android.mk`""
    Write-Host "  Running: $ndkCmd"
    $ndkOutput = Invoke-Expression "& $ndkCmd 2>&1" | Tee-Object -Variable ndkOutput
    Write-Host "---- NDK BUILD OUTPUT BEGIN ----"
    $ndkOutput | ForEach-Object { Write-Host $_ }
    Write-Host "---- NDK BUILD OUTPUT END ----"
    Pop-Location
    Assert-ExitCode "ndk-build"
    if (Test-Path $libSrc) {
        Copy-Item $libSrc $libDst -Force
        Write-Host "  .so  ->  $libDst"
    } else {
        throw "libminecraftpe.so not built. Check NDK output."
    }
}

# ── 3. Java compile ──────────────────────────────────────────
if (-not $NoJava -and -not $NoBuild) {
    Write-Step "Java compile"
    New-Dir (Split-Path $rJava -Parent)
    & $aapt package -f -M $manifest -S $res -I $androidJar -J "$apkbuild\gen" -F "$apkbuild\_rgen.apk" 2>&1 | Out-Null
    Assert-ExitCode "aapt R.java"
    Remove-Item "$apkbuild\_rgen.apk" -ea SilentlyContinue

    $srcs = @(
        Get-ChildItem $javaSrc  -Recurse -Filter "*.java" | Select-Object -Exp FullName
        Get-ChildItem $stubsDir -Recurse -Filter "*.java" | Select-Object -Exp FullName
        $rJava
    )
    Remove-Item $classesDir -Recurse -Force -ea SilentlyContinue
    New-Dir $classesDir
    $javacOut = & javac --release 8 -cp $androidJar -d $classesDir @srcs 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "javac errors:" -ForegroundColor Red
        $javacOut | Where-Object { $_ -match "error:" } | ForEach-Object { Write-Host $_ -ForegroundColor Red }
        exit 1
    }
    Write-Host "  javac OK"

    $classFiles = Get-ChildItem $classesDir -Recurse -Filter "*.class" | Select-Object -Exp FullName
    & $d8 --min-api 21 --output $apkbuild $classFiles
    Assert-ExitCode "d8"
    Write-Host "  d8  ->  $dexOut"
}

# ── 4. Package APK ───────────────────────────────────────────
if (-not $NoBuild) {
    Write-Step "Package APK"
    Remove-Item $unsigned,$aligned,$signed -ea SilentlyContinue

    & $aapt package -f -M $manifest -S $res -I $androidJar -F $unsigned
    Assert-ExitCode "aapt package"

    $zip = [System.IO.Compression.ZipFile]::Open($unsigned, 'Update')
    try {
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,$dexOut,"classes.dex",[System.IO.Compression.CompressionLevel]::Fastest) | Out-Null
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,$libDst,"lib/arm64-v8a/libminecraftpe.so",[System.IO.Compression.CompressionLevel]::NoCompression) | Out-Null
        Get-ChildItem $dataDir -Recurse -File | ForEach-Object {
            $rel = $_.FullName.Substring("$dataDir\".Length).Replace('\','/')
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,$_.FullName,"assets/$rel",[System.IO.Compression.CompressionLevel]::NoCompression) | Out-Null
        }
    } finally { $zip.Dispose() }
    Write-Host "  APK assembled"

    & $zipalign -p 4 $unsigned $aligned; Assert-ExitCode "zipalign"
    & $apksigner sign --ks $keystore --ks-pass pass:android --key-pass pass:android --out $signed $aligned
    Assert-ExitCode "apksigner"
    Write-Host "  signed  ->  $signed"
}

# ── 5. Install (if adb available) ───────────────────────────
if ($adb -and (Test-Path $adb) -and -not $NoBuild) {
    Write-Step "Install"
    & $adb shell am force-stop $pkg 2>$null
    & $adb uninstall $pkg 2>$null
    & $adb install --no-incremental $signed
    if ($LASTEXITCODE -eq 0) { Write-Host "  Installed successfully." }
    else { Write-Host "  Install failed (device may not be connected)." -ForegroundColor Yellow }
}

Write-Host "`nDone." -ForegroundColor Green
