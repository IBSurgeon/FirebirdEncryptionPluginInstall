# FirebirdEncryptionPluginInstall
Installation scripts for IBSurgeon encryption plugin for Firebird

## For Windows
Download Powershell script inst-crypt-plugin.ps1 and bat file install-Firebird-encryption-plugin.bat, run bat-file as Administrator.

Installation script will search Windows registry to find installed versions of vanilla Firebird (HQbird is ignored since it is already has encryption plugin), check their versions, and then install plugin.

Script will do the following:

1. It copies necessary dll files and configuration files
2. adds parameter for KeyHolder=KeyHolderPlugin into firebird.conf
3. restarts Firebird. *Important! Restart will disconnect all connected users!*
4. copies empployee.fdb and then performs test encryption for it.
5. performs test gbak.exe with -KeyHolder to demonstrate test backup

Please note - when KeyHolder.conf is renamed or removed from plugins, automatic server-level encryption/decryption is off, it means that you must supply key when accessing encrypted databases.

