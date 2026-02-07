نسخة تجربة احترافية (Flutter) — Test Pack v0.2

✅ الهدف: تطلع APK "تجربة" بسهولة.
الـAPK النهائي يطلع بطريقتين:

========================
(1) على جهازك (ويندوز)
========================
1) فك الضغط.
2) افتح PowerShell داخل نفس الفولدر.
3) شغّل:
   .\create_project.ps1 -ProjectName aluupvc_trial -Package com.mohamed.aluupvc

4) للتجربة:
   cd aluupvc_trial
   flutter run

5) لإخراج APK:
   flutter build apk --release

الـAPK هنا:
aluupvc_trial\build\app\outputs\flutter-apk\app-release.apk

========================
(2) من GitHub (من غير Android Studio)
========================
1) اعمل Repo جديد على GitHub.
2) ارفع كل محتويات هذا الـZIP للـRepo.
3) افتح تبويب Actions.
4) شغّل Workflow: "Build Android APK"
5) نزّل Artifact: app-release-apk
   جواه app-release.apk — نزّله وجرّبه.

ملاحظات:
- القواعد: app_files/assets/rules_default.json
- تقدر تعدّلها من داخل التطبيق (Rules JSON) وتعمل Save
