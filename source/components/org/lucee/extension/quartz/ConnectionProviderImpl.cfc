component implementsJava="org.quartz.utils.ConnectionProvider"  accessors="true" {
    // TODO log
    property name="log" type="string";
    property name="datasource" type="string";

    /**
     * Initialize the connection provider with properties
     */
    public void function initialize(properties={}) {
    }

    /**
     * Get a connection from Lucee's connection pool
     */
    public function getConnection() {
        if(isEmpty(variables.datasource?:"")) {
            throw "datasource is not defined!";
        }
        
        var pc=getPageContext();
        var manager = pc.getDataSourceManager();
        var dc = manager.getConnection(pc, datasource, nullValue(), nullValue());
        
        return dc;
    }
    
    /**
     * Shutdown the connection provider
     */
    public void function shutdown() {
        // Nothing to do - Lucee manages the connection pool
        //log log=variables.logName type="info" text="LuceeConnectionProvider shutdown";
    }
}