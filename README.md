# Turquan Site Survey (Android)
APK almak için (bilgisayarda kurulum gerekmez):
1. github.com'da yeni bir repo aç, bu klasörün içeriğini yükle (.github klasörü dahil).
2. Repo > Actions > build-apk > Run workflow.
3. Bitince "turquan-survey-apk" artifact'ını indir, içindeki app-release.apk'yı telefona kur.
Yerelde: Flutter kuruluysa `flutter create . --platforms=android`, manifeste 3 izni ekle, `flutter build apk`.
