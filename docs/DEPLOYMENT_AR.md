# دليل النشر — مكتبة الكون

## GitHub
أنشئ مستودعاً فارغاً باسم `kawn-library` ثم نفّذ من مجلد المشروع:

```bash
git init
git add .
git commit -m "Add Kawn Library app with Supabase authentication"
git branch -M main
git remote add origin https://github.com/USERNAME/kawn-library.git
git push -u origin main
```

سيعمل GitHub Actions على فحص خادم Node وتحليل/اختبار Flutter وبناء APK تجريبي عند كل push إلى `main`.

## Render
1. اربط مستودع GitHub في Render.
2. اختر New → Blueprint واختر `render.yaml`.
3. أضف `SUPABASE_URL` و`SUPABASE_SERVICE_ROLE_KEY` كمتغيرات سرية في Render فقط.
4. انتظر نجاح Deploy ثم اختبر `/health`.

Render يستضيف API وليس ملف APK نفسه. التطبيق المحمول يُبنى عبر GitHub Actions أو Flutter محلياً. لا تضع مفاتيح Supabase السرية في تطبيق الهاتف.

## إعداد تطبيق Flutter
راجع `AUTH_SETUP_AR.md` لإعداد البريد وGoogle OAuth وروابط العودة. لا يعتبر تسجيل Google مكتملاً حتى تضاف بيانات OAuth الصحيحة وتُختبر على Android وiOS.
