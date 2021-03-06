# MongoDB Enterprise Security Integration

This project demos how MongoDB Enterprise server uses Kerberos for authentication and LDAP for authorization.  Examples include:

- Install and configure Kerberos 5 on CentOS 7
- Install and configure OpenLDAP on CentOS 7
  - Users and Group creations
  - Enable TLS
- Install and configure MongoDB Enterprise
  - Kerberos *keytab* files creation
  - Kerberos GSSAPI authentication
  - LDAP configurations
  - Transport encryption using x509 certificates
- Authentication Mechanism
  - SCRAM-SHA-256
  - MONGODB-X509
  - GSSAPI
  - PLAIN
- Authorization runs against ldap.simagix.com

## History

- 04/25/2020: updated with MongoDB v4.2

## 1 Commands

### 1.1 build

```bash
./build.sh
```

### 1.2 startup

```bash
docker-compose up
```

### 1.3 shutdown

```bash
docker-compose down
```

### 1.4 ldapsearch

```bash
ldapsearch -x cn=mdb -b dc=simagix,dc=local -H ldaps://ldap.simagix.com
```

### 1.5 mongoldap

```bash
mongoldap --config /etc/mongod.conf --user mdb@SIMAGIX.COM --password secret
```

## 2 Security Playpen

### 2.1 attach to the `mongodb-security_test_1` container

```bash
docker exec -it mongodb-security_test_1 /bin/bash
```

### 2.2 SCRAM-SHA-256

```bash
mongo "mongodb://admin:secret@mongo.simagix.com/?authSource=admin" \
  --tls --tlsCAFile /ca.pem --tlsCertificateKeyFile /client.pem
```

### 2.3 MONGODB-X509

```bash
export login="CN=ken.chen%40simagix.com,OU=Users,O=Simagix,L=Atlanta,ST=Georgia,C=US"
mongo "mongodb://$login:xxx@mongo.simagix.com/?authMechanism=MONGODB-X509&authSource=\$external" \
  --tls --tlsCAFile /ca.pem --tlsCertificateKeyFile /client.pem
```

### 2.4 PLAIN (LDAP)

```bash
mongo "mongodb://mdb:secret@mongo.simagix.com/?authMechanism=PLAIN&authSource=\$external" \
  --tls --tlsCAFile /ca.pem --tlsCertificateKeyFile /client.pem
```

### 2.5 GSSAPI (Kerberos)

```bash
kinit mdb@SIMAGIX.COM -kt /repo/mongodb.keytab
mongo "mongodb://mdb%40$REALM:xxx@mongo.simagix.com/?authMechanism=GSSAPI&authSource=\$external" \
  --tls --tlsCAFile /ca.pem --tlsCertificateKeyFile /client.pem
```

### 2.6 mongo connection status

```bash
db.runCommand({connectionStatus : 1})
```

## 3 Misc

### 3.1 certificates creation

```bash
source certs.env
create_certs.sh ldap.simagix.com mongo.simagix.com

certs
├── ca.pem
├── certs.env
├── client.pem
├── ldap.simagix.com.pem
└── mongo.simagix.com.pem
```

For additional certificates, use [create_certs.sh](https://github.com/simagix/mongo-x509/blob/master/create_certs.sh)
to sign using *master-certs.pem*.

### 3.2 enable LDAP TLS

Lines added to */etc/openldap/ldap.conf* on both ldap.simagix.com and mongo.simagix.com.

```bash
TLS_CACERT /server.pem
TLS_REQCERT never # self-signed certs
```

## 4 Troubleshoot

Attach to *mongo* container and execute the command:

```bash
docker exec -it mongodb-security_mongo_1 bash
```

Test with `mongoldap` command:

```bash
mongoldap -f /etc/mongod.conf --user admin --password secret
```

### 4.1 Correct Configuration

```text
Running MongoDB LDAP authorization validation checks...
Version: 4.2.9

Checking that an LDAP server has been specified...
[OK] LDAP server(s) provided in configuration

Connecting to LDAP server...
2020-09-29T20:27:46.961+0000 W  ACCESS   [main] LDAP library does not advertise support for thread safety. All access will be serialized and connection pooling will be disabled. Link mongod against libldap_r to enable concurrent use of LDAP.
[OK] Connected to LDAP server

Parsing MongoDB to LDAP DN mappings...
[OK] MongoDB to LDAP DN mappings appear to be valid

Attempting to authenticate against the LDAP server...
[OK] Successful authentication performed

Checking if LDAP authorization has been enabled by configuration...
[OK] LDAP authorization enabled

Parsing LDAP query template...
[OK] LDAP query configuration template appears valid

Executing query against LDAP server...
[OK] Successfully acquired the following roles on the 'admin' database:

  * cn=Reporting,ou=Groups,dc=simagix,dc=local
```

### 4.2 Authentication Failed

Incorrect password in the *security.ldap.bin.queryUser* and/or *security.ldap.bin.queryPassword*.

```text
Running MongoDB LDAP authorization validation checks...
Version: 4.2.9

Checking that an LDAP server has been specified...
[OK] LDAP server(s) provided in configuration

Connecting to LDAP server...
2020-09-29T20:34:31.844+0000 W  ACCESS   [main] LDAP library does not advertise support for thread safety. All access will be serialized and connection pooling will be disabled. Link mongod against libldap_r to enable concurrent use of LDAP.
2020-09-29T20:34:31.920+0000 E  ACCESS   [main] OperationFailed: LDAP operation <ldap_sasl_bind_s>, failed to bind to LDAP server at default. (49/Invalid credentials): No error could be retrieved from the LDAP server.. Bind parameters were: {BindDN: cn=ldapadm,dc=simagix,dc=local, authenticationType: simple}
[FAIL] Could not connect to any of the specified LDAP servers
  * Error: OperationFailed: LDAP bind failed with error: Invalid credentials
  * The server may be down, or 'security.ldap.servers' or 'security.ldap.transportSecurity' may be incorrectly configured.
  * Alternatively the server may not allow anonymous access to the RootDSE.
```

### 4.3 userToDNMapping Failed on Nonexisting User

The rule expects a user *cn=admin,ou=Admin,ou=Users,dc=simagix,dc=local*, but the user in the LDAP server is *cn=admin,ou=Users,dc=simagix,dc=local*.  The extra *ou=Admin* fails the inquiry.

```text
Running MongoDB LDAP authorization validation checks...
Version: 4.2.9

Checking that an LDAP server has been specified...
[OK] LDAP server(s) provided in configuration

Connecting to LDAP server...
2020-09-29T20:59:11.242+0000 W  ACCESS   [main] LDAP library does not advertise support for thread safety. All access will be serialized and connection pooling will be disabled. Link mongod against libldap_r to enable concurrent use of LDAP.
[OK] Connected to LDAP server

Parsing MongoDB to LDAP DN mappings...
[OK] MongoDB to LDAP DN mappings appear to be valid

Attempting to authenticate against the LDAP server...
[FAIL] Failed to authenticate admin to LDAP server
  * FailedToParse: Failed to transform authentication user name to LDAP DN :: caused by :: Failed to transform user 'admin'. No matching transformation out of 1 available transformations. Results: { rule: { match: "(.+)" ldapQuery: "ou=Admin,ou=Users,dc=simagix,dc=local??sub?(uid={0})" } error: "OperationFailed: LDAP operation <ldap_search_ext_s>, Failed to perform query: No such object' Query was: 'BaseDN: "ou=Admin,ou=Users,dc=simagix,dc=local", Scope: "sub", Filter: "(uid=admin)", Context: userToDNMapping'". (32/No such object): No error could be retrieved from the LDAP server." },
```

### 4.4 userToDNMapping Failed on Rule

Under *security.ldap.userToDNMapping*, expect to swap a value of *ldapQuery* ({0}) with a matched *match* ("(.+)")

```text
Running MongoDB LDAP authorization validation checks...
Version: 4.2.9

Checking that an LDAP server has been specified...
[OK] LDAP server(s) provided in configuration

Connecting to LDAP server...
2020-09-29T20:41:35.425+0000 W  ACCESS   [main] LDAP library does not advertise support for thread safety. All access will be serialized and connection pooling will be disabled. Link mongod against libldap_r to enable concurrent use of LDAP.
[OK] Connected to LDAP server

Parsing MongoDB to LDAP DN mappings...
[OK] MongoDB to LDAP DN mappings appear to be valid

Attempting to authenticate against the LDAP server...
[FAIL] Failed to authenticate admin to LDAP server
  * FailedToParse: Failed to transform authentication user name to LDAP DN :: caused by :: Failed to transform user 'admin'. No matching transformation out of 1 available transformations. Results: { rule: { match: "(.+)" ldapQuery: "cn=mdb,ou=Users,dc=simagix,dc=local" } error: "FailedToParse: Failed to substitute component into filter. Every capture group must be consumed, token #0 is missing." },
```

### 4.5 authz Failed

Incorrect password in the *security.ldap.bin.queryUser* and/or *security.ldap.bin.queryPassword*.

```text
Running MongoDB LDAP authorization validation checks...
Version: 4.2.9

Checking that an LDAP server has been specified...
[OK] LDAP server(s) provided in configuration

Connecting to LDAP server...
2020-09-29T20:37:26.277+0000 W  ACCESS   [main] LDAP library does not advertise support for thread safety. All access will be serialized and connection pooling will be disabled. Link mongod against libldap_r to enable concurrent use of LDAP.
[OK] Connected to LDAP server

Parsing MongoDB to LDAP DN mappings...
[OK] MongoDB to LDAP DN mappings appear to be valid

Attempting to authenticate against the LDAP server...
[OK] Successful authentication performed

Checking if LDAP authorization has been enabled by configuration...
[OK] LDAP authorization enabled

Parsing LDAP query template...
[FAIL] Unable to parse the LDAP query configuration template
  * When a user authenticates to MongoDB, the username they authenticate with will be substituted into this URI. The resulting query will be executed against the LDAP server to obtain that user's roles.
  * Make sure your query template is an RFC 4516 relative URI. This will look something like <baseDN>[?<attributes>[?<scope>[?<filter>]]], where all bracketed placeholders are replaced with their proper values.
  * Error message: FailedToParse: Unrecognized query scope 'basex'. Options are 'base', 'one', and 'sub'
  ```
