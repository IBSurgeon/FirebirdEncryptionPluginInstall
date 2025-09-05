# How to install and use IBSurgeon Firebird Encryption for Windows

In this instruction we will consider 2 phases: a) deployment and basic setup of plugin, which is a universal step required to distribute your applications with encrypted databases, and b) optional steps needed for developer of the application
Please note that this script is for vanilla Firebird versions, since HQbird already includes necessary files.


## Phase 1 (Mandatory):  Deployment and basic setup of IBSurgeon Encryption for Firebird on Windows

### Download 1-step installer

Download 2 files from https://github.com/IBSurgeon/FirebirdEncryptionPluginInstall: 
install-Firebird-encryption-plugin.bat and inst-crypt-plugin.ps1


### Run 1-step installer

Run install-Firebird-encryption-plugin.bat as administrator, it will start PowerShell script inst-crypt-plugin.ps1 which actually performs the installation. 

What 1-step installer will do:
  
1) Installer searches for installed Firebird in registry and offers to choose to what instance the plugin should be installed. It verifies if there is compatible version of Firebird (3.0.3, 4.0.x, 5.0.x). 

```
D:\Firebird\FirebirdEncryptionPluginInstall-main\ForWindows>install-Firebird-encryption-plugin.bat
This script will install Firebird crypt plugin.
Now script will scan OS registry for Firebird installations.
You can run script silently adding --crypt="c:\path\to\firebird" parameter
(Do not forget double-quotes in path like "C:\Program Files", etc...)
Press Enter to continue or Ctrl+C to exit script.


== Choose from installed instances ==
============= WARNING! ==============
If you select service that is running
it will be restarted to install plugin
 -------------------------------------
1) Service Name: FirebirdServerDefaultInstance (Stopped, OK)
Installed in: C:\Program Files\Firebird\Firebird_3_0
Version: 3.0.13.33818
 -------------------------------------
0) Exit script
Enter number (0-1) and press Enter:
```

2) Installer downloads necessary files (dlls and conf and trial license), then stores them to the selected Firebird folder.

3) Installer changes firebird.conf - it adds line KeyHolderPlugin = KeyHolder

4) Installer restarts Firebird instance (be careful on production). At that step Firebird is ready to encrypt databases, using the trial license and sample keys in file KeyHolder.conf.

5) Installer checks the work of the encryption:

  a) It creates a copy of employee.fdb database from %Firebird_Root%\examples\empbuild\employee.fdb -> emp_crypted.fdb
  b) It encrypts database emp_crypted.fdb using key from KeyHolder.conf
  с) In case of successful encryption, it connects to the database with isql and runs command show database; to demonstrate that encryption is successful.

```
Downloading plugin...
Extracting plugin...
Copying plugin files to C:\Program Files\Firebird\Firebird_3_0
Adding KeyHolderPlugin to firebird.conf
Trying to encrypt employee database...
Database: C:\Program Files\Firebird\Firebird_3_0\examples\empbuild\emp_crypted.fdb, User: SYSDBA
SQL> SQL> Database: C:\Program Files\Firebird\Firebird_3_0\examples\empbuild\emp_crypted.fdb
        Owner: SYSDBA
PAGE_SIZE 8192
Number of DB pages allocated = 326
Number of DB pages used = 300
Number of DB pages free = 26
Sweep interval = 20000
Forced Writes are OFF
Transaction - oldest = 159
Transaction - oldest active = 160
Transaction - oldest snapshot = 160
Transaction - Next = 164
ODS = 12.0
Database encrypted, crypt thread not complete
Creation date: Jul 14, 2025 14:03:43
Default Character set: NONE
SQL>
Employee database encryption and backup completed.
Skipping restore test for Firebird 3.0
Copying client files...

```
6) Installer renames file KeyHolder.conf with example keys to _KeyHolder.conf in order to prevent server-side access to them. It simulates the production mode, when there are no keys on the server side, only in applications.

7) Installer checks the creation of encrypted backup with gbak.exe

Gbak creates backup file with key passed through KeyHolderStdin plugin (in versions Firebird 5.0 and 4.0) or with -Key options (in version Firebird 3.0). 
As a result, file emp_crypted.fbk in the folder Firebird_Root\examples\empbuild\ will be created.


8) Installer creates folder with client files  in the folder where it was started: Client\32bit and Client\64bit. 

These files can be used for development of the application which will use encryption access: copy paste all files from that folder to the folder where your application's binary resides. It is very important to use the provided fbclient.dll.


9) Important! Please note that script installs trial license file DbCrypt.conf: it is time-limited and in production must be replaced with the actual license file.


## Phase 2 (optional): Developing encrypted database and applications for it

At the end of the installer's work, we have the following situation: Firebird is configured for work with encryption, test encrypted database and encrypted backup were created, file with example keys KeyHolder.conf is renamed to simulate production mode.

How can you encrypt your database?


### Try to encrypt your own database in command line

Let's encrypt your database with the same steps as installer did.

#### Rename _KeyHolder.conf back to KeyHolder.conf

If you rename KeyHolder.conf to the original name, it will be possible to use keys from it for encrypt/decrypt operations.

#### Encrypt your database in command-line

Open your database with isql.exe and run encryption command to encrypt your database with example key Red (which is listed in KeyHolder.conf). Make sure to use TCP connection string (with localhost or inet://), as in the example below:


```
isql localhost/3050:C:\Temp\mydatabase.fdb -user SYSDBA -pass masterkey

alter database encrypt with dbcrypt key red;
```

Please note - on Windows you can specify key name and plugin names in case-insensitive way.

After that, run command "show database;" to see the status of the database:

```
Database: C:\Temp\mydatabase.fdb
        Owner: SYSDBA
PAGE_SIZE 8192
Number of DB pages allocated = 326
Number of DB pages used = 300
Number of DB pages free = 26
Sweep interval = 20000
Forced Writes are OFF
Transaction - oldest = 159
Transaction - oldest active = 160
Transaction - oldest snapshot = 160
Transaction - Next = 164
ODS = 12.0
Database encrypted, crypt thread not complete
Creation date: Jul 14, 2025 14:03:43
Default Character set: NONE
SQL>
```

Congratulations, now you have your database encrypted!


#### Make encrypted backup of your encrypted database with gbak.exe

Start cmd.exe and run the following command to create encrypted backup of encrypted database with gbak.exe:


```
echo Key=Red 0xec,0xa1,0x52,0xf6,0x4d,0x27,0xda,0x93,0x53,0xe5,0x48,0x86,0xb9,0x7d,0xe2,0x8f,0x3b,0xfa,0xb7,0x91,0x22,0x5b,0x59,0x15,0x82,0x35,0xf5,0x30,0x1f,0x04,0xdc,0x75, | gbak.exe -user SYSDBA -password masterkey -KeyHolder KeyHolderStdin -Z -b localhost/3050:C:\Temp\mydatabase.fdb C:\Temp\myencrypted.fbk
```

### Development of application to access encrypted database

Now you can start developing the application to access encrypted database.
For this, you need to download example applications from https://ib-aid.com/download/crypt/v2024/ExampleApplications.zip, choose what language do you use and implement access accordingly.

#### Where to get keys for your application?

You can see in KeyHolder.conf there are examples of named keys - Red, Green, etc, which consist of 32 comma-separated hex values.

```
Key=Red 0xec,0xa1,0x52,0xf6,0x4d,0x27,0xda,0x93,0x53,0xe5,0x48,0x86,0xb9,0x7d,0xe2,0x8f,0x3b,0xfa,0xb7,0x91,0x22,0x5b,0x59,0x15,0x82,0x35,0xf5,0x30,0x1f,0x04,0xdc,0x75,
Key=Green 0xab,0xd7,0x34,0x63,0xae,0x19,0x52,0x00,0xb8,0x84,0xa3,0x44,0xbd,0x11,0x9f,0x72,0xe0,0x04,0x68,0x4f,0xc4,0x89,0x3b,0x20,0x8d,0x2a,0xa7,0x07,0x32,0x3b,0x5e,0x74,
```

For production deployment you need to use own keys (not examples from KeyHolder.conf) for encrypting databases. IBSurgeon provides key generator (aesKeyGen.exe) which can generate random keys as part of the full license package, see example of its usage below:

```
C:\Temp\crypt1>aesKeyGen.exe
const unsigned char aes256[] = {
0x35,0xa1,0xe2,0x86,0xb4,0xc6,0x4c,0xc4,0xdc,0xb5,0xd2,0x9e,0x72,0x6d,0xf7,0xfc,0x40,0x79,0x50,0xdb,0xe6,0x75,0xaf,0xc5,0x75,0x65,0x1d,0xcd,0xee,0x65,0x3f,0x1e,
};
```

and it can be formed as MyKey1:

```
Key=MyKey1 0x35,0xa1,0xe2,0x86,0xb4,0xc6,0x4c,0xc4,0xdc,0xb5,0xd2,0x9e,0x72,0x6d,0xf7,0xfc,0x40,0x79,0x50,0xdb,0xe6,0x75,0xaf,0xc5,0x75,0x65,0x1d,0xcd,0xee,0x65,0x3f,0x1e,
```

Of course, you should keep the production keys in a secure location and do not lose them, since lost encryption keys cannot be recovered.

For test purposes you can copy-paste and modify keys from KeyHolder.conf.









