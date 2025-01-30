component implementsJava="org.quartz.JobListener" {
    public String function getName() { 
        // SystemOutput("getName() " ,1,1);
        return "CustomJobListener";
    }

    public void function jobToBeExecuted( context) {
       //  SystemOutput("jobToBeExecuted() " ,1,1);
        //  SystemOutput("Job to be executed: " & context.getJobDetail().getKey().toString() & "<br>",1,1);
    }

    public void function jobExecutionVetoed( context) {
        // SystemOutput("jobExecutionVetoed() " ,1,1);
       //  SystemOutput("Job execution vetoed: " & context.getJobDetail().getKey().toString() & "<br>",1,1);
    }

    public void function jobWasExecuted( context,  jobException) {
        // SystemOutput("jobExecutionVetoed() " ,1,1);
        // SystemOutput("Job was executed: " & context.getJobDetail().getKey().toString() & "<br>",1,1);
        if (!isNull(jobException)) {
            // SystemOutput("Exception during job execution: " & jobException.getMessage() & "<br>",1,1);
        }
    }
    public void function onMissingMethod( ) {
        // SystemOutput("onMissingMethod() " ,1,1);
    }
}