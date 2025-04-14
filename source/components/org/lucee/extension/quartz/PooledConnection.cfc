component implementsJava="org.quartz.utils.ConnectionProvider" {
    
    /**
     * Initialize the connection provider with properties
     */
    public void function initialize(properties={}) {
        systemOutput("xxxxxxxxx initialize xxxxxxxxxx",1,1);
        systemOutput(properties,1,1);
        systemOutput(variables,1,1);
        variables.datasourceName = properties.datasource?:"";
        //variables.logName = props.log?:"application";
        
        /*if (isNull(variables.datasourceName) || trim(variables.datasourceName) == "") {
            throw(
                type="java.sql.SQLException",
                message="The property 'datasource' is required"
            );
        }
        
        log log=variables.logName type="info" text="LuceeConnectionProvider initialized with datasource: #variables.datasourceName#";
        */
    }

    public void function setLog(logName) {
        variables.logName=arguments.logName;
        systemOutput("xxxxxxxxx setLog xxxxxxxxxx",1,1);
        systemOutput(arguments,1,1);
    }
    
    /**
     * Get a connection from Lucee's connection pool
     */
    public function getConnection() {
        systemOutput("xxxxxxxxx getConnection xxxxxxxxxx",1,1);
        var datasourceName="ldev_4889_web_missing_dsn";
        //try {
            var pc=getPageContext();
            var manager = pc.getDataSourceManager();
            var dc = manager.getConnection(pc, datasourceName, nullValue(), nullValue());
            return dc.getConnection();
        
        // manager.releaseConnection(pageContext, dc);
        
            /*} 
        catch (e) {
            log log=variables.logName type="error" text="Error getting connection: #e.message#" exception=e;
            
            // Rethrow as SQLException for Quartz
            throw(
                type="java.sql.SQLException",
                message="Error getting connection from Lucee datasource: #e.message#"
            );
        }*/
    }
    
    /**
     * Shutdown the connection provider
     */
    public void function shutdown() {
        // Nothing to do - Lucee manages the connection pool
        //log log=variables.logName type="info" text="LuceeConnectionProvider shutdown";
    }
}