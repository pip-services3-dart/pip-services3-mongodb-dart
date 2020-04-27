# Configuration Guide <br/>

Configuration structure follows the 
[standard configuration](https://github.com/pip-services/pip-services3-container-node/doc/Configuration.md) 
structure. 

### <a name="persistence_mongodb"></a> MongoDB
MongoDB persistence has the following configuration properties:
- connection(s): object - MongoDB connection properties
- options: object - (optional) MongoDB connection options.
- debug: boolean - (optional) Enables or disables connection debugging

Example:
```yaml
- descriptor: "pip-services-clusters:persistence:mongodb:default:1.0"
  collection: "clusters"
  connection:
    uri: "mongodb://localhost/pipservicestest"
    host: "localhost"
    port: 27017
    database: "pipservicestest"
  credential:
    username: "user_db"
    password: "passwd_db"
```

For more information on this section read 
[Pip.Services Configuration Guide](https://github.com/pip-services/pip-services3-container-node/doc/Configuration.md#deps)