#!/usr/bin/env python3
"""يُشغَّل بعد `flutter create` : ينسخ الأيقونات ويضبط إعدادات أندرويد المطلوبة.
آمن للتكرار (idempotent)."""
import glob, os, re, shutil, sys

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(root)

# 1) نسخ الأيقونات (أندرويد + ويندوز) فوق ما ولّده flutter create
shutil.copytree('native_overlay/android', 'android', dirs_exist_ok=True)
shutil.copytree('native_overlay/windows', 'windows', dirs_exist_ok=True)

# 2) صلاحية البصمة في AndroidManifest
mf = 'android/app/src/main/AndroidManifest.xml'
s = open(mf, encoding='utf-8').read()
if 'USE_BIOMETRIC' not in s:
    s = re.sub(r'(<manifest[^>]*>)',
               r'\1\n    <uses-permission android:name="android.permission.USE_BIOMETRIC"/>', s, count=1)
    open(mf, 'w', encoding='utf-8').write(s)

# 3) MainActivity يرث FlutterFragmentActivity (شرط local_auth)
acts = glob.glob('android/app/src/main/kotlin/**/MainActivity.kt', recursive=True)
if not acts:
    sys.exit('MainActivity.kt غير موجود')
a = open(acts[0], encoding='utf-8').read()
if 'FlutterFragmentActivity' not in a:
    a = a.replace('import io.flutter.embedding.android.FlutterActivity',
                  'import io.flutter.embedding.android.FlutterFragmentActivity')
    a = a.replace(': FlutterActivity()', ': FlutterFragmentActivity()')
    open(acts[0], 'w', encoding='utf-8').write(a)
assert 'FlutterFragmentActivity()' in open(acts[0], encoding='utf-8').read(), 'فشل تعديل MainActivity'

# 4) minSdk = 23
for g in glob.glob('android/app/build.gradle*'):
    t = open(g, encoding='utf-8').read()
    n = re.sub(r'minSdk(Version)?(\s*=\s*|\s+)flutter\.minSdkVersion',
               lambda m: f"minSdk{m.group(1) or ''}{m.group(2)}23", t)
    if n != t:
        open(g, 'w', encoding='utf-8').write(n)
        print('minSdk=23 في', g)

# 5) اسم التطبيق الظاهر على أندرويد
if os.path.exists(mf):
    s = open(mf, encoding='utf-8').read()
    s = re.sub(r'android:label="[^"]*"', 'android:label="الإعلام الحربي اليمني"', s, count=1)
    open(mf, 'w', encoding='utf-8').write(s)
# 6) عنوان نافذة ويندوز (إن وُجد windows/runner/main.cpp)
wm = 'windows/runner/main.cpp'
if os.path.exists(wm):
    w = open(wm, encoding='utf-8').read()
    n = re.sub(r'(window\.Create\(L)"[^"]*"', r'\1"MMY.YE - Media Admin"', w, count=1)
    if n != w:
        open(wm, 'w', encoding='utf-8').write(n)
print('تم تطبيق الإعدادات الأصلية')
