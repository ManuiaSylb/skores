# Skull King – Score Tracker

Cette application Flutter permet de suivre les scores des parties de Skull King.  
Pour l'instant, **seule la version Android** est disponible.

---

## Prérequis

Avant de commencer, assurez-vous d'avoir installé :

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (version stable recommandée)

---

## Installation

1. **Cloner le dépôt**

```bash
git clone <URL_DU_DEPOT>
cd skullking_score
```

2.	**Récupérer les dépendances Flutter**

```bash
flutter pub get
```

3. **Vérifier que Flutter et Android sont prêts**

```bash
flutter doctor
```

Assurez-vous qu’il n’y a pas d’erreurs majeures et que votre device (émulateur ou téléphone) est détecté.

4. **Build APK**

```bash
flutter clean
flutter pub get
flutter build apk --release
```

L’APK généré se trouvera dans : `build/app/outputs/apk/release/app-release.apk`

5. **Installer l'application**

Sur un appareil Android branché
a.	Connectez votre téléphone via USB et activez le mode développeur et USB debugging.
b.	Vérifiez que le téléphone est détecté :

```bash
flutter devices
```

La sortie devrait ressembler ainsi :
```bash
2 connected devices:

iPhone 16 Plus (mobile) • 3CE9F0EF-2DF8-4A42-BA98-4408BC920D96 • ios • com.apple.CoreSimulator.SimRuntime.iOS-18-0 (simulator)
SM A546B (mobile) • A2RJB5SCIEJ • android-arm64  • Android 15 (API 35)
```

Le `device_id` de l'iPhone 16 Plus est celui-ci : `3CE9F0EF-2DF8-4A42-BA98-4408BC920D96`.

c.	Lancez l’installation de l’application :

```bash
flutter install -d <device_id>
```

## Auteur 

Manuia Sylvestre-Baron © 2025