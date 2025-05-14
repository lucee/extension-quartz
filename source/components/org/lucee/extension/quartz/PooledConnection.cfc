component implementsJava="org.quartz.utils.ConnectionProvider" {
    
    /**
     * Initialize the connection provider with properties
     */
    public void function initialize(properties={}) {
        variables.datasourceName = properties.datasource?:"";
    }

    public void function setLog(logName) {
        variables.logName=arguments.logName;
    }
    
    /**
     * Get a connection from Lucee's connection pool
     */
    public function getConnection() {
        var datasourceName="ldev_4889_web_missing_dsn";
        var pc=getPageContext();
        var manager = pc.getDataSourceManager();
        var dc = manager.getConnection(pc, datasourceName, nullValue(), nullValue());
        return dc.getConnection();
    }
    
    /**
     * Shutdown the connection provider
     */
    public void function shutdown() {
        // Nothing to do - Lucee manages the connection pool
        //log log=variables.logName type="info" text="LuceeConnectionProvider shutdown";
    }
}