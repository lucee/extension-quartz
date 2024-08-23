component implementsJava="org.quartz.JobListener" {
    variables.stream="out";

    public String function init(properties) { 
        variables.stream=properties.stream?:"out";
    }
    
    public String function getName() { 
        return "ConsoleListener";
    }

    public void function jobToBeExecuted( context) {
        SystemOutput("Job to be executed: " & getLabel(context), true, variables.stream=="err");
    }

    public void function jobExecutionVetoed( context) {
        SystemOutput("Job execution vetoed: " & getLabel(context),true,variables.stream=="err");
    }

    public void function jobWasExecuted( context,  jobException) {
        SystemOutput("Job was executed: " & getLabel(context),true,variables.stream=="err");
        if (!isNull(jobException)) {
             SystemOutput("Exception during job execution: " & jobException.getMessage(),true,variables.stream=="err");
        }
    }

    private static function getLabel(context) {
        var job=context.getJobDetail();
        var dataMap=job.getJobDataMap();
        return dataMap["label"]?:job.getKey().toString();
    }
}