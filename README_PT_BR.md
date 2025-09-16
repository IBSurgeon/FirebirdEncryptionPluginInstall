# Como instalar e usar o IBSurgeon Firebird Encryption para Windows

Nesta instrução consideraremos 2 fases: a) implantação e configuração básica do plugin, que é um passo universal necessário para distribuir suas aplicações com bancos de dados criptografados, e b) passos opcionais necessários para o desenvolvedor da aplicação
Note que este script é para versões vanilla do Firebird, já que o HQbird já inclui os arquivos necessários.

## Fase 1 (Obrigatória): Implantação e configuração básica do IBSurgeon Encryption para Firebird no Windows

### Baixar o instalador de 1 passo

Baixe 2 arquivos de https://github.com/IBSurgeon/FirebirdEncryptionPluginInstall: 
install-Firebird-encryption-plugin.bat e inst-crypt-plugin.ps1

### Executar o instalador de 1 passo

Execute install-Firebird-encryption-plugin.bat como administrador, ele iniciará o script PowerShell inst-crypt-plugin.ps1 que realmente executa a instalação.

O que o instalador de 1 passo fará:

#### Procurar por instâncias do Firebird instaladas

O instalador procura por Firebird instalado no registro e oferece para escolher em qual instância o plugin deve ser instalado. Ele verifica se há uma versão compatível do Firebird (3.0.3+, 4.0.x, 5.0.x).

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

#### Baixar arquivos automaticamente

O instalador baixa os arquivos necessários (dlls, arquivos de configuração e licença de teste), depois os armazena na pasta do Firebird selecionada.

#### Altera o firebird.conf

O instalador altera o firebird.conf - adiciona a linha *KeyHolderPlugin = KeyHolder*

#### Reinicia o Firebird (cuidado em produção!)

O instalador reinicia a instância do Firebird. Neste passo o Firebird está pronto para criptografar bancos de dados, usando a licença de teste e chaves de exemplo no arquivo KeyHolder.conf.

#### Verifica se a instalação funciona

O instalador verifica o funcionamento da criptografia:

a) Cria uma cópia do banco de dados employee.fdb de %Firebird_Root%\examples\empbuild\employee.fdb -> emp_crypted.fdb

b) Criptografa o banco de dados emp_crypted.fdb usando a chave do KeyHolder.conf

c) Em caso de criptografia bem-sucedida, conecta ao banco de dados com isql e executa o comando show database; para demonstrar que a criptografia foi bem-sucedida.

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

#### Renomeia KeyHolder.conf

O instalador renomeia o arquivo KeyHolder.conf com chaves de exemplo para _KeyHolder.conf para prevenir acesso do lado do servidor a elas. Isso simula o modo de produção, quando não há chaves no lado do servidor, apenas nas aplicações.

#### Verifica se backup criptografado pode ser criado

O instalador verifica a criação de backup criptografado com gbak.exe

Gbak cria arquivo de backup com chave passada através do plugin KeyHolderStdin (nas versões Firebird 5.0 e 4.0) ou com opções -Key (na versão Firebird 3.0).
Como resultado, o arquivo emp_crypted.fbk na pasta Firebird_Root\examples\empbuild\ será criado.

#### Cria pastas com arquivos para aplicações cliente

O instalador cria pasta com arquivos cliente na pasta onde foi iniciado: Client\32bit e Client\64bit.

Estes arquivos podem ser usados para desenvolvimento da aplicação que usará acesso criptografado: copie e cole todos os arquivos desta pasta para a pasta onde reside o binário da sua aplicação. É muito importante usar o fbclient.dll fornecido.

#### Licença de teste é instalada - não esqueça de atualizá-la

Importante! Note que o script instala arquivo de licença de teste DbCrypt.conf: é limitado por tempo e em produção deve ser substituído pelo arquivo de licença real.

## Fase 2 (opcional): Desenvolvendo banco de dados criptografado e aplicações para ele

No final do trabalho do instalador, temos a seguinte situação: Firebird está configurado para trabalhar com criptografia, banco de dados de teste criptografado e backup criptografado foram criados, arquivo com chaves de exemplo KeyHolder.conf é renomeado para simular modo de produção.

Como você pode criptografar seu banco de dados?

### Tente criptografar seu próprio banco de dados na linha de comando

Vamos criptografar seu banco de dados com os mesmos passos que o instalador fez.

#### Renomeie _KeyHolder.conf de volta para KeyHolder.conf

Se você renomear KeyHolder.conf para o nome original, será possível usar chaves dele para operações de criptografia/descriptografia.

#### Criptografe seu banco de dados na linha de comando

Abra seu banco de dados com isql.exe e execute comando de criptografia para criptografar seu banco de dados com a chave de exemplo Red (que está listada no KeyHolder.conf). Certifique-se de usar string de conexão TCP (com localhost ou inet://), como no exemplo abaixo:

```
isql localhost/3050:C:\Temp\mydatabase.fdb -user SYSDBA -pass masterkey

alter database encrypt with dbcrypt key red;
```

Note - no Windows você pode especificar nome da chave e nomes de plugin de forma case-insensitive.

Depois disso, execute o comando "show database;" para ver o status do banco de dados:

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

Parabéns, agora você tem seu banco de dados criptografado!

#### Faça backup criptografado do seu banco de dados criptografado com gbak.exe

Inicie cmd.exe e execute o seguinte comando para criar backup criptografado do banco de dados criptografado com gbak.exe:

```
echo Key=Red 0xec,0xa1,0x52,0xf6,0x4d,0x27,0xda,0x93,0x53,0xe5,0x48,0x86,0xb9,0x7d,0xe2,0x8f,0x3b,0xfa,0xb7,0x91,0x22,0x5b,0x59,0x15,0x82,0x35,0xf5,0x30,0x1f,0x04,0xdc,0x75, | gbak.exe -user SYSDBA -password masterkey -KeyHolder KeyHolderStdin -Z -b localhost/3050:C:\Temp\mydatabase.fdb C:\Temp\myencrypted.fbk
```

### Desenvolvimento de aplicação para acessar banco de dados criptografado

Agora você pode começar a desenvolver a aplicação para acessar banco de dados criptografado.
Para isso, você precisa baixar aplicações de exemplo de https://ib-aid.com/download/crypt/v2024/ExampleApplications.zip, escolher que linguagem você usa e implementar o acesso adequadamente.

#### Onde obter chaves para sua aplicação?

Você pode ver no KeyHolder.conf que há exemplos de chaves nomeadas - Red, Green, etc, que consistem de 32 valores hex separados por vírgula.

```
Key=Red 0xec,0xa1,0x52,0xf6,0x4d,0x27,0xda,0x93,0x53,0xe5,0x48,0x86,0xb9,0x7d,0xe2,0x8f,0x3b,0xfa,0xb7,0x91,0x22,0x5b,0x59,0x15,0x82,0x35,0xf5,0x30,0x1f,0x04,0xdc,0x75,
Key=Green 0xab,0xd7,0x34,0x63,0xae,0x19,0x52,0x00,0xb8,0x84,0xa3,0x44,0xbd,0x11,0x9f,0x72,0xe0,0x04,0x68,0x4f,0xc4,0x89,0x3b,0x20,0x8d,0x2a,0xa7,0x07,0x32,0x3b,0x5e,0x74,
```

Para implantação em produção você precisa usar suas próprias chaves (não exemplos do KeyHolder.conf) para criptografar bancos de dados. IBSurgeon fornece gerador de chaves (aesKeyGen.exe) que pode gerar chaves aleatórias como parte do pacote de licença completo, veja exemplo do seu uso abaixo:

```
C:\Temp\crypt1>aesKeyGen.exe
const unsigned char aes256[] = {
0x35,0xa1,0xe2,0x86,0xb4,0xc6,0x4c,0xc4,0xdc,0xb5,0xd2,0x9e,0x72,0x6d,0xf7,0xfc,0x40,0x79,0x50,0xdb,0xe6,0x75,0xaf,0xc5,0x75,0x65,0x1d,0xcd,0xee,0x65,0x3f,0x1e,
};
```

e pode ser formada como MyKey1:

```
Key=MyKey1 0x35,0xa1,0xe2,0x86,0xb4,0xc6,0x4c,0xc4,0xdc,0xb5,0xd2,0x9e,0x72,0x6d,0xf7,0xfc,0x40,0x79,0x50,0xdb,0xe6,0x75,0xaf,0xc5,0x75,0x65,0x1d,0xcd,0xee,0x65,0x3f,0x1e,
```

Claro, você deve manter as chaves de produção em um local seguro e não perdê-las, já que chaves de criptografia perdidas não podem ser recuperadas.

Para fins de teste você pode copiar e colar e modificar chaves do KeyHolder.conf.

# Duvidas?

Envia email para support@ib-aid.com


