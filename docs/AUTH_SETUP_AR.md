# إعداد تسجيل الدخول — مكتبة الكون

## 1) إعداد Supabase
1. أنشئ مشروع Supabase (أو استخدم مشروعاً تملك صلاحية إدارته).
2. افتح SQL Editor ونفّذ `backend/sql/001_initial_schema.sql` على قاعدة بيانات جديدة/اختبارية أولاً.
3. من Project Settings → API انسخ Project URL وPublishable key (أو anon key القديم).
4. لا تستخدم `service_role` داخل Flutter مطلقاً. يبقى هذا المفتاح في خادم موثوق فقط.

## 2) إعداد البريد والتحقق
1. Authentication → Providers → Email: فعّل Email provider وConfirm email.
2. اضبط SMTP موثوقاً للإنتاج؛ خدمة البريد الافتراضية محدودة ومناسبة للاختبار فقط.
3. Authentication → URL Configuration: أضف `com.kawn.library://login-callback/` إلى Redirect URLs.
4. عدّل Site URL إلى عنوان موقعك الفعلي عند توفره.

## 3) إعداد Google OAuth
1. أنشئ OAuth Client من Google Cloud Console لنوع Android وiOS، واضبط package/bundle IDs وبصمات SHA-1/SHA-256 الخاصة بتطبيقك.
2. فعّل Google provider من Supabase Authentication → Providers → Google.
3. أدخل Client ID/Secret الخاصين بخادم OAuth في Supabase، واضبط Authorized redirect URI كما يعرضه Supabase في صفحة المزود.
4. أضف redirect URL الخاص بالتطبيق `com.kawn.library://login-callback/` إلى قائمة Redirect URLs في Supabase.
5. أضف deep-link scheme إلى ملفات AndroidManifest.xml وios/Runner/Info.plist بعد توليد مجلدات المنصات بواسطة `flutter create`.

### Android intent filter
داخل `<activity android:name=".MainActivity" ...>` أضف:

```xml
<intent-filter>
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="com.kawn.library" android:host="login-callback" />
</intent-filter>
```

### iOS URL scheme
داخل `ios/Runner/Info.plist` أضف ضمن `<dict>`:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array><string>com.kawn.library</string></array>
  </dict>
</array>
```

## 4) بناء التطبيق
من مجلد `flutter_app`:

```bash
flutter create --platforms=android,ios --org com.kawn.library .
flutter pub get
dart run flutter_launcher_icons
flutter analyze
flutter test
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_OR_ANON_KEY
```

لـ iOS استخدم جهاز macOS مع Xcode:

```bash
flutter build ipa --release \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_OR_ANON_KEY
```

## 5) الأدوار والصلاحيات
- يختار المستخدم قارئاً أو كاتباً عند التسجيل.
- دور اللجنة لا يظهر كخيار تسجيل ذاتي. يطلب المستخدم الانضمام عبر طلب منفصل، وتعيّن الإدارة الدور بعد التحقق من الشخص.
- لا تغيّر `profiles.role` من التطبيق. منح دور لجنة يتم من SQL Editor أو أداة إدارية موثوقة فقط، بعد التحقق من الهوية.
- مثال منح دور مدقق لغوي لمستخدم موثوق (استبدل UUID):

```sql
update public.profiles
set role = 'proofreader', updated_at = now()
where id = '00000000-0000-0000-0000-000000000000';
```

الأدوار المسموحة: `reader`, `writer`, `proofreader`, `critic`, `editor`, `committee_chair`, `admin`.

## 6) ما يلزم قبل الإطلاق العام
- إعداد SMTP فعلي، Google OAuth credentials، Redirect URLs وSHA fingerprints.
- إعداد سياسات الخصوصية وشروط الاستخدام وحقوق المؤلفين.
- اختبار RLS بحساب قارئ وكاتب ومدقق ورئيس لجنة منفصلين.
- اختبار روابط العودة OAuth على أجهزة Android وiOS حقيقية.
- إضافة آلية إدارة موثوقة لتعيين اللجنة ومراجعة المحتوى وتسجيل كل قرار.
