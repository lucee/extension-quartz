component implementsJava="org.quartz.Job" {
    
    public void function execute( context) {
        var dataMap = context.getJobDetail().getJobDataMap();
        var path = dataMap.getString("path");
        include path;
    }
}