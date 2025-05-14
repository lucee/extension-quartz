component implementsJava="org.quartz.JobListener" {
    variables.stream="out";

    public String function init(properties) { 
        //variables.datasourceName=properties.datasource?:(properties.name);
    }
    
    public String function getName() { 
        return getComponentMetadata(this).fullname;
    } 

    public String function getDescription() { 
        return "Logs all job execution details directly to the console, providing real-time feedback for monitoring and debugging purposes.";
    }

    public void function jobToBeExecuted( context) {
    }

    public void function jobExecutionVetoed( context) {
    }

    public void function jobWasExecuted( context,  jobException) {
        if (!isNull(jobException)) {
        }
    }

    private static function getLabel(context) {
        var job=context.getJobDetail();
        var dataMap=job.getJobDataMap();
        return dataMap["label"]?:job.getKey().toString();
    }
}